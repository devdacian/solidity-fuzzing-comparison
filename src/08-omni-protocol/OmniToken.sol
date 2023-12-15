// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IIRM.sol";
import "./interfaces/IOmniPool.sol";
import "./interfaces/IOmniToken.sol";
import "./SubAccount.sol";
import "./WithUnderlying.sol";

/**
 * @title OmniToken Contract
 * @notice This contract manages deposits, withdrawals, borrowings, and repayments within the Omni protocol. There is only borrow caps, no supply caps.
 * @dev It has multiple tranches, each with its own borrowing and depositing conditions. This contract does not handle rebasing tokens.
 * Inherits from IOmniToken, WithUnderlying, and ReentrancyGuardUpgradeable (includes Initializable) from the OpenZeppelin library.
 * Utilizes the SafeERC20, SubAccount libraries for safe token transfers and account management.
 * Emits events for significant state changes like deposits, withdrawals, borrowings, repayments, and tranches updates.
 */
contract OmniToken is IOmniToken, WithUnderlying, ReentrancyGuardUpgradeable {
    struct OmniTokenTranche {
        uint256 totalDepositAmount;
        uint256 totalBorrowAmount;
        uint256 totalDepositShare;
        uint256 totalBorrowShare;
    }

    using SafeERC20 for IERC20;
    using SubAccount for address;
    using SubAccount for bytes32;

    uint256 public constant RESERVE_FEE = 0.1e9;
    uint256 public constant FEE_SCALE = 1e9;
    uint256 public constant IRM_SCALE = 1e9; // Must match IRM.sol
    uint256 private constant MAX_VIEW_ACCOUNTS = 25;

    address public omniPool;
    address public irm;
    uint256 public lastAccrualTime;
    uint8 public trancheCount;
    bytes32 public reserveReceiver;
    mapping(uint8 => mapping(bytes32 => uint256)) private trancheAccountDepositShares;
    mapping(uint8 => mapping(bytes32 => uint256)) private trancheAccountBorrowShares;
    uint256[] public trancheBorrowCaps;
    OmniTokenTranche[] public tranches;

    /**
     * @notice Contract initializes the OmniToken with required parameters.
     * @param _omniPool Address of the OmniPool contract.
     * @param _underlying Address of the underlying asset.
     * @param _irm Address of the Interest Rate Model contract.
     * @param _borrowCaps Initial borrow caps for each tranche.
     */
    function initialize(address _omniPool, address _underlying, address _irm, uint256[] calldata _borrowCaps)
        external
        initializer
    {
        __ReentrancyGuard_init();
        __WithUnderlying_init(_underlying);
        omniPool = _omniPool;
        irm = _irm;
        lastAccrualTime = block.timestamp;
        trancheBorrowCaps = _borrowCaps;
        trancheCount = uint8(_borrowCaps.length);
        for (uint8 i = 0; i < _borrowCaps.length; ++i) {
            tranches.push(OmniTokenTranche(0, 0, 0, 0));
        }
        reserveReceiver = IOmniPool(omniPool).reserveReceiver();
    }

    /**
     * @notice Accrues interest for all tranches, calculates and distributes the interest among the depositors and updates tranche balances.
     * The function also handles reserve payments. This method needs to be called before any deposit, withdrawal, borrow, or repayment actions to update the state of the contract.
     * @dev Interest is paid out proportionately to more risky tranche deposits per tranche
     */
    function accrue() public {
        uint256 timePassed = block.timestamp - lastAccrualTime;
        if (timePassed == 0) {
            return;
        }
        uint8 trancheIndex = trancheCount;
        uint256 totalBorrow = 0;
        uint256 totalDeposit = 0;
        uint256[] memory trancheDepositAmounts_ = new uint256[](trancheIndex); // trancheIndeex == trancheCount initially
        uint256[] memory trancheAccruedDepositCache = new uint256[](trancheIndex);
        uint256[] memory reserveFeeCache = new uint256[](trancheIndex);
        while (trancheIndex != 0) {
            unchecked {
                --trancheIndex;
            }
            OmniTokenTranche storage tranche = tranches[trancheIndex];
            uint256 trancheDepositAmount_ = tranche.totalDepositAmount;
            uint256 trancheBorrowAmount_ = tranche.totalBorrowAmount;
            totalBorrow += trancheBorrowAmount_;
            totalDeposit += trancheDepositAmount_;
            trancheDepositAmounts_[trancheIndex] = trancheDepositAmount_;
            trancheAccruedDepositCache[trancheIndex] = trancheDepositAmount_;

            if (trancheBorrowAmount_ == 0) {
                continue;
            }
            uint256 interestAmount;
            {
                uint256 interestRate = IIRM(irm).getInterestRate(address(this), trancheIndex, totalDeposit, totalBorrow);
                interestAmount = (trancheBorrowAmount_ * interestRate * timePassed) / 365 days / IRM_SCALE;
            }

            // Handle reserve payments
            uint256 reserveInterestAmount = interestAmount * RESERVE_FEE / FEE_SCALE;
            reserveFeeCache[trancheIndex] = reserveInterestAmount;

            // Handle deposit interest
            interestAmount -= reserveInterestAmount;
            {
                uint256 depositInterestAmount = 0;
                uint256 interestAmountProportion;
                for (uint8 ti = trancheCount; ti > trancheIndex;) {
                    unchecked {
                        --ti;
                    }
                    interestAmountProportion = interestAmount * trancheDepositAmounts_[ti] / totalDeposit;
                    trancheAccruedDepositCache[ti] += interestAmountProportion;
                    depositInterestAmount += interestAmountProportion;
                }
                tranche.totalBorrowAmount = trancheBorrowAmount_ + depositInterestAmount + reserveInterestAmount;
            }
        }
        for (uint8 ti = 0; ti < trancheCount; ++ti) {
            OmniTokenTranche memory tranche_ = tranches[ti];
            // Pay the reserve
            uint256 reserveShare;
            if (reserveFeeCache[ti] > 0) {
                if (trancheAccruedDepositCache[ti] == 0) {
                    reserveShare = reserveFeeCache[ti];
                } else {
                    reserveShare = (reserveFeeCache[ti] * tranche_.totalDepositShare) / trancheAccruedDepositCache[ti];
                }
                trancheAccruedDepositCache[ti] += reserveFeeCache[ti];
                trancheAccountDepositShares[ti][reserveReceiver] += reserveShare;
                tranche_.totalDepositShare += reserveShare;
            }
            tranche_.totalDepositAmount = trancheAccruedDepositCache[ti];
            tranches[ti] = tranche_;
        }
        lastAccrualTime = block.timestamp;
        emit Accrue();
    }

    /**
     * @notice Allows a user to deposit a specified amount into a specified tranche.
     * @param _subId Sub-account identifier for the depositor.
     * @param _trancheId Identifier of the tranche to deposit into.
     * @param _amount Amount to deposit.
     * @return share Amount of deposit shares received in exchange for the deposit.
     */
    function deposit(uint96 _subId, uint8 _trancheId, uint256 _amount) external nonReentrant returns (uint256 share) {
        require(_trancheId < IOmniPool(omniPool).pauseTranche(), "OmniToken::deposit: Tranche paused.");
        require(_trancheId < trancheCount, "OmniToken::deposit: Invalid tranche id.");
        accrue();
        bytes32 account = msg.sender.toAccount(_subId);
        uint256 amount = _inflowTokens(account.toAddress(), _amount);
        OmniTokenTranche storage tranche = tranches[_trancheId];
        uint256 totalDepositShare_ = tranche.totalDepositShare;
        uint256 totalDepositAmount_ = tranche.totalDepositAmount;
        if (totalDepositShare_ == 0) {
            share = amount;
        } else {
            assert(totalDepositAmount_ > 0);
            share = (amount * totalDepositShare_) / totalDepositAmount_;
        }
        tranche.totalDepositAmount = totalDepositAmount_ + amount;
        tranche.totalDepositShare = totalDepositShare_ + share;
        trancheAccountDepositShares[_trancheId][account] += share;
        emit Deposit(account, _trancheId, amount, share);
    }

    /**
     * @notice Allows a user to withdraw their funds from a specified tranche.
     * @param _subId The ID of the sub-account.
     * @param _trancheId The ID of the tranche.
     * @param _share The share of the user in the tranche.
     * @return amount The amount of funds withdrawn.
     */
    function withdraw(uint96 _subId, uint8 _trancheId, uint256 _share) external nonReentrant returns (uint256 amount) {
        require(_trancheId < IOmniPool(omniPool).pauseTranche(), "OmniToken::withdraw: Tranche paused.");
        require(_trancheId < trancheCount, "OmniToken::withdraw: Invalid tranche id.");
        accrue();
        bytes32 account = msg.sender.toAccount(_subId);
        OmniTokenTranche storage tranche = tranches[_trancheId];
        uint256 totalDepositAmount_ = tranche.totalDepositAmount;
        uint256 totalDepositShare_ = tranche.totalDepositShare;
        uint256 accountDepositShares_ = trancheAccountDepositShares[_trancheId][account];
        if (_share == 0) {
            _share = accountDepositShares_;
        }
        amount = (_share * totalDepositAmount_) / totalDepositShare_;
        tranche.totalDepositAmount = totalDepositAmount_ - amount;
        tranche.totalDepositShare = totalDepositShare_ - _share;
        trancheAccountDepositShares[_trancheId][account] = accountDepositShares_ - _share;
        require(_checkBorrowAllocationOk(), "OmniToken::withdraw: Insufficient withdrawals available.");
        _outflowTokens(account.toAddress(), amount);
        require(IOmniPool(omniPool).isAccountHealthy(account), "OmniToken::withdraw: Not healthy.");
        emit Withdraw(account, _trancheId, amount, _share);
    }

    /**
     * @notice Allows a user to borrow funds from a specified tranche.
     * @param _account The account of the user.
     * @param _trancheId The ID of the tranche.
     * @param _amount The amount to borrow.
     * @return share The share of the borrowed amount in the tranche.
     */
    function borrow(bytes32 _account, uint8 _trancheId, uint256 _amount)
        external
        nonReentrant
        returns (uint256 share)
    {
        require(_trancheId < IOmniPool(omniPool).pauseTranche(), "OmniToken::borrow: Tranche paused.");
        require(msg.sender == omniPool, "OmniToken::borrow: Bad caller.");
        accrue();
        OmniTokenTranche storage tranche = tranches[_trancheId];
        uint256 totalBorrowAmount_ = tranche.totalBorrowAmount;
        uint256 totalBorrowShare_ = tranche.totalBorrowShare;
        require(totalBorrowAmount_ + _amount <= trancheBorrowCaps[_trancheId], "OmniToken::borrow: Borrow cap reached.");
        if (totalBorrowShare_ == 0) {
            share = _amount;
        } else {
            assert(totalBorrowAmount_ > 0); // Should only happen if bad debt exists & all other debts repaid
            share = Math.ceilDiv(_amount * totalBorrowShare_, totalBorrowAmount_);
        }
        tranche.totalBorrowAmount = totalBorrowAmount_ + _amount;
        tranche.totalBorrowShare = totalBorrowShare_ + share;
        trancheAccountBorrowShares[_trancheId][_account] += share;
        require(_checkBorrowAllocationOk(), "OmniToken::borrow: Invalid borrow allocation.");
        _outflowTokens(_account.toAddress(), _amount);
        emit Borrow(_account, _trancheId, _amount, share);
    }

    /**
     * @notice Allows a user or another account to repay borrowed funds.
     * @param _account The account of the user.
     * @param _payer The account that will pay the borrowed amount.
     * @param _trancheId The ID of the tranche.
     * @param _amount The amount to repay.
     * @return amount The amount of the repaid amount in the tranche.
     */
    function repay(bytes32 _account, address _payer, uint8 _trancheId, uint256 _amount)
        external
        nonReentrant
        returns (uint256 amount)
    {
        require(msg.sender == omniPool, "OmniToken::repay: Bad caller.");
        accrue();
        OmniTokenTranche storage tranche = tranches[_trancheId];
        uint256 totalBorrowAmount_ = tranche.totalBorrowAmount;
        uint256 totalBorrowShare_ = tranche.totalBorrowShare;
        uint256 accountBorrowShares_ = trancheAccountBorrowShares[_trancheId][_account];
        if (_amount == 0) {
            _amount = Math.ceilDiv(accountBorrowShares_ * totalBorrowAmount_, totalBorrowShare_);
        }
        amount = _inflowTokens(_payer, _amount);
        uint256 share = (amount * totalBorrowShare_) / totalBorrowAmount_;    
        tranche.totalBorrowAmount = totalBorrowAmount_ - amount;
        tranche.totalBorrowShare = totalBorrowShare_ - share;
        trancheAccountBorrowShares[_trancheId][_account] = accountBorrowShares_ - share;
        emit Repay(_account, _payer, _trancheId, amount, share);
    }

    /**
     * @notice Transfers specified shares from one account to another within a specified tranche.
     * @dev This function can only be called externally and is protected against reentrancy.
     * Requires the tranche to be unpaused and the sender account to remain healthy post-transfer.
     * @param _subId The subscription ID related to the sender's account.
     * @param _to The account identifier to which shares are being transferred.
     * @param _trancheId The identifier of the tranche where the transfer is occurring.
     * @param _shares The amount of shares to transfer.
     * @return A boolean value indicating whether the transfer was successful.
     */
    function transfer(uint96 _subId, bytes32 _to, uint8 _trancheId, uint256 _shares)
        external
        nonReentrant
        returns (bool)
    {
        require(_trancheId < IOmniPool(omniPool).pauseTranche(), "OmniToken::transfer: Tranche paused.");
        accrue();
        bytes32 from = msg.sender.toAccount(_subId);
        trancheAccountDepositShares[_trancheId][from] -= _shares;
        trancheAccountDepositShares[_trancheId][_to] += _shares;
        require(IOmniPool(omniPool).isAccountHealthy(from), "OmniToken::transfer: Not healthy.");
        emit Transfer(from, _to, _trancheId, _shares);
        return true;
    }

    /**
     * @notice Allows the a liquidator to seize funds from a user's account. OmniPool is responsible for defining how this function is called.
     * Greedily seizes as much collateral as possible, does not revert if no more collateral is left to seize and _amount is nonzero.
     * @param _account The account from which funds will be seized.
     * @param _to The account to which seized funds will be sent.
     * @param _amount The amount of funds to seize.
     * @return seizedShares The shares seized from each tranche.
     */
    function seize(bytes32 _account, bytes32 _to, uint256 _amount)
        external
        override
        nonReentrant
        returns (uint256[] memory)
    {
        require(msg.sender == omniPool, "OmniToken::seize: Bad caller");
        accrue();
        uint256 amount_ = _amount;
        uint256[] memory seizedShares = new uint256[](trancheCount);
        for (uint8 ti = 0; ti < trancheCount; ++ti) {
            uint256 totalShare = tranches[ti].totalDepositShare;
            if (totalShare == 0) {
                continue;
            }
            uint256 totalAmount = tranches[ti].totalDepositAmount;
            uint256 share = trancheAccountDepositShares[ti][_account];
            uint256 amount = (share * totalAmount) / totalShare;
            if (amount_ > amount) {
                amount_ -= amount;
                trancheAccountDepositShares[ti][_account] = 0;
                trancheAccountDepositShares[ti][_to] += share;
                seizedShares[ti] = share;
            } else {
                uint256 transferShare = (share * amount_) / amount;
                trancheAccountDepositShares[ti][_account] = share - transferShare;
                trancheAccountDepositShares[ti][_to] += transferShare;
                seizedShares[ti] = transferShare;
                break;
            }
        }
        emit Seize(_account, _to, _amount, seizedShares);
        return seizedShares;
    }

    /**
     * @notice Distributes the bad debt loss in a tranche among all tranche members in cases of bad debt. OmniPool is responsible for defining how this function is called.
     * @dev This should only be called when the _account does not have any collateral left to seize.
     * @param _account The account that incurred a loss.
     * @param _trancheId The ID of the tranche.
     */
    function socializeLoss(bytes32 _account, uint8 _trancheId) external nonReentrant {
        require(msg.sender == omniPool, "OmniToken::socializeLoss: Bad caller");
        uint256 totalDeposits = 0;
        for (uint8 i = _trancheId; i < trancheCount; ++i) {
            totalDeposits += tranches[i].totalDepositAmount;
        }
        OmniTokenTranche storage tranche = tranches[_trancheId];
        uint256 share = trancheAccountBorrowShares[_trancheId][_account];
        uint256 amount = Math.ceilDiv(share * tranche.totalBorrowAmount, tranche.totalBorrowShare); // Represents amount of bad debt there still is (need to ensure user's account is emptied of collateral before this is called)
        uint256 leftoverAmount = amount;
        for (uint8 ti = trancheCount - 1; ti > _trancheId; --ti) {
            OmniTokenTranche storage upperTranche = tranches[ti];
            uint256 amountProp = (amount * upperTranche.totalDepositAmount) / totalDeposits;
            upperTranche.totalDepositAmount -= amountProp;
            leftoverAmount -= amountProp;
        }
        tranche.totalDepositAmount -= leftoverAmount;
        tranche.totalBorrowAmount -= amount;
        tranche.totalBorrowShare -= share;
        trancheAccountBorrowShares[_trancheId][_account] = 0;
        emit SocializedLoss(_account, _trancheId, amount, share);
    }

    /**
     * @notice Computes the borrowing amount of a specific account in the underlying asset for a given borrow tier.
     * @dev The division is ceiling division.
     * @param _account The account identifier for which the borrowing amount is to be computed.
     * @param _borrowTier The borrow tier identifier from which the borrowing amount is to be computed.
     * @return The borrowing amount of the account in the underlying asset for the given borrow tier.
     */
    function getAccountBorrowInUnderlying(bytes32 _account, uint8 _borrowTier) external view returns (uint256) {
        OmniTokenTranche storage tranche = tranches[_borrowTier];
        uint256 share = trancheAccountBorrowShares[_borrowTier][_account];
        if (share == 0) {
            return 0;
        } else {
            return Math.ceilDiv(share * tranche.totalBorrowAmount, tranche.totalBorrowShare);
        }
    }

    /**
     * @notice Retrieves the total deposit amount for a specific account across all tranches.
     * @param _account The account identifier.
     * @return The total deposit amount.
     */
    function getAccountDepositInUnderlying(bytes32 _account) public view returns (uint256) {
        uint256 totalDeposit = 0;
        for (uint8 trancheIndex = 0; trancheIndex < trancheCount; ++trancheIndex) {
            OmniTokenTranche storage tranche = tranches[trancheIndex];
            uint256 share = trancheAccountDepositShares[trancheIndex][_account];
            if (share > 0) {
                totalDeposit += (share * tranche.totalDepositAmount) / tranche.totalDepositShare;
            }
        }
        return totalDeposit;
    }

    /**
     * @notice Retrieves the deposit and borrow shares for a specific account in a specific tranche.
     * @param _account The account identifier.
     * @param _trancheId The tranche identifier.
     * @return depositShare The deposit share.
     * @return borrowShare The borrow share.
     */
    function getAccountSharesByTranche(bytes32 _account, uint8 _trancheId)
        external
        view
        returns (uint256 depositShare, uint256 borrowShare)
    {
        depositShare = trancheAccountDepositShares[_trancheId][_account];
        borrowShare = trancheAccountBorrowShares[_trancheId][_account];
    }

    /**
     * @notice Gets the borrow cap for a specific tranche.
     * @param _trancheId The ID of the tranche for which to retrieve the borrow cap.
     * @return The borrow cap for the specified tranche.
     */
    function getBorrowCap(uint8 _trancheId) external view returns (uint256) {
        return trancheBorrowCaps[_trancheId];
    }

    /**
     * @notice Sets the borrow caps for each tranche.
     * @param _borrowCaps An array of borrow caps in the underlying's decimals.
     */
    function setTrancheBorrowCaps(uint256[] calldata _borrowCaps) external {
        require(msg.sender == omniPool, "OmniToken::setTrancheBorrowCaps: Bad caller.");
        require(_borrowCaps.length == trancheCount, "OmniToken::setTrancheBorrowCaps: Invalid borrow caps length.");
        require(
            _borrowCaps[0] > 0, "OmniToken::setTrancheBorrowCaps: Invalid borrow caps, must always allow 0 to borrow."
        );
        trancheBorrowCaps = _borrowCaps;
        emit SetTrancheBorrowCaps(_borrowCaps);
    }

    /**
     * @notice Sets the number of tranches. Can only increase the number of tranches by one at a time, never decrease.
     * @param _trancheCount The new tranche count.
     */
    function setTrancheCount(uint8 _trancheCount) external {
        require(msg.sender == omniPool, "OmniToken::setTrancheCount: Bad caller.");
        require(_trancheCount == trancheCount + 1, "OmniToken::setTrancheCount: Invalid tranche count.");
        trancheCount = _trancheCount;
        OmniTokenTranche memory tranche = OmniTokenTranche(0, 0, 0, 0);
        tranches.push(tranche);
        emit SetTrancheCount(_trancheCount);
    }

    /**
     * @notice Fetches and updates the reserve receiver from the OmniPool contract. Anyone can call.
     */
    function fetchReserveReceiver() external {
        reserveReceiver = IOmniPool(omniPool).reserveReceiver();
    }

    /**
     * @notice Calculates the total deposited amount for a specific owner across MAX_VIEW_ACCOUNTS sub-accounts. Above will be excluded, function is imperfect.
     * @dev This is just for wallets and Etherscan to pick up the deposit balance of a user for the first MAX_VIEW_ACCOUNTS sub-accounts.
     * @param _owner The address of the owner.
     * @return The total deposited amount.
     */
    function balanceOf(address _owner) external view returns (uint256) {
        uint256 totalDeposit = 0;
        for (uint96 i = 0; i < MAX_VIEW_ACCOUNTS; ++i) {
            totalDeposit += getAccountDepositInUnderlying(_owner.toAccount(i));
        }
        return totalDeposit;
    }

    /**
     * @notice Checks if the borrow allocation is valid across all tranches, through the invariant cumulative totalBorrow <= totalDeposit from highest to lowest tranche.
     * @return A boolean value indicating the validity of the borrow allocation.
     */
    function _checkBorrowAllocationOk() internal view returns (bool) {
        uint8 trancheIndex = trancheCount;
        uint256 totalBorrow = 0;
        uint256 totalDeposit = 0;
        while (trancheIndex != 0) {
            unchecked {
                --trancheIndex;
            }
            totalBorrow += tranches[trancheIndex].totalBorrowAmount;
            totalDeposit += tranches[trancheIndex].totalDepositAmount;
            if (totalBorrow > totalDeposit) {
                return false;
            }
        }
        return true;
    }
}
