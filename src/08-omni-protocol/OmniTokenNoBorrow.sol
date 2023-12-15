// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IOmniPool.sol";
import "./interfaces/IOmniTokenNoBorrow.sol";
import "./SubAccount.sol";
import "./WithUnderlying.sol";

/**
 * @title OmniTokenNoBorrow
 * @notice This contract represents a token pool with deposit and withdrawal capabilities, without borrowing features. Should only be used for isolated collateral, never borrowable. There is only supply caps.
 * @dev It inherits functionalities from WithUnderlying, ReentrancyGuardUpgradeable (includes Initializable), and implements IOmniTokenNoBorrow interface.
 * The contract allows depositors to deposit and withdraw their funds, and for the OmniPool to seize funds if necessary.
 * It keeps track of the total supply and individual balances, and enforces a supply cap. This contract does not handle rebasing tokens.
 */
contract OmniTokenNoBorrow is IOmniTokenNoBorrow, WithUnderlying, ReentrancyGuardUpgradeable {
    using SubAccount for address;

    uint256 private constant MAX_VIEW_ACCOUNTS = 25;

    address public omniPool;
    uint256 public totalSupply;
    uint256 public supplyCap;
    mapping(bytes32 => uint256) public balanceOfAccount;

    /**
     * @notice Contract initializes the OmniTokenNoBorrow with required parameters.
     * @param _omniPool Address of the OmniPool contract.
     * @param _underlying Address of the underlying asset.
     * @param _supplyCap Initial supply cap.
     */
    function initialize(address _omniPool, address _underlying, uint256 _supplyCap) external initializer {
        __ReentrancyGuard_init();
        __WithUnderlying_init(_underlying);
        omniPool = _omniPool;
        supplyCap = _supplyCap;
    }

    /**
     * @notice Deposits a specified amount to the account associated with the message sender and the specified subId.
     * @param _subId The sub-account identifier.
     * @param _amount The amount to deposit.
     * @return amount The actual amount deposited.
     */
    function deposit(uint96 _subId, uint256 _amount) external nonReentrant returns (uint256 amount) {
        bytes32 account = msg.sender.toAccount(_subId);
        amount = _inflowTokens(msg.sender, _amount);
        require(totalSupply + amount <= supplyCap, "OmniTokenNoBorrow::deposit: Supply cap exceeded.");
        totalSupply += amount;
        balanceOfAccount[account] += amount;
        emit Deposit(account, amount);
    }

    /**
     * @notice Withdraws a specified amount from the account associated with the message sender and the specified subId.
     * @param _subId The sub-account identifier.
     * @param _amount The amount to withdraw.
     * @return amount The actual amount withdrawn.
     */
    function withdraw(uint96 _subId, uint256 _amount) external nonReentrant returns (uint256 amount) {
        bytes32 account = msg.sender.toAccount(_subId);
        if (_amount == 0) {
            _amount = balanceOfAccount[account];
        }
        balanceOfAccount[account] -= _amount;
        totalSupply -= _amount;
        amount = _outflowTokens(msg.sender, _amount);
        require(IOmniPool(omniPool).isAccountHealthy(account), "OmniTokenNoBorrow::withdraw: Not healthy.");
        emit Withdraw(account, amount);
    }

    /**
     * @notice Transfers a specified amount of tokens from the sender's account to another account.
     * The transfer operation is subject to the sender's account remaining healthy post-transfer.
     * @dev This function can only be called externally and is protected against reentrant calls.
     * @param _subId The subscription ID associated with the sender's account.
     * @param _to The account identifier to which the tokens are being transferred.
     * @param _amount The amount of tokens to transfer.
     * @return A boolean value indicating whether the transfer was successful.
     */
    function transfer(uint96 _subId, bytes32 _to, uint256 _amount) external nonReentrant returns (bool) {
        bytes32 from = msg.sender.toAccount(_subId);
        balanceOfAccount[from] -= _amount;
        balanceOfAccount[_to] += _amount;
        require(IOmniPool(omniPool).isAccountHealthy(from), "OmniTokenNoBorrow::transfer: Not healthy.");
        emit Transfer(from, _to, _amount);
        return true;
    }

    /**
     * @notice Allows the a liquidator to seize funds from a user's account. OmniPool is responsible for defining how this function is called. Should be called carefully, as it has strong privileges.
     * @param _account The account from which funds are seized.
     * @param _to The account to which funds are transferred.
     * @param _amount The amount of funds to seize.
     * @return seizedShares The shares corresponding to the seized amount.
     */
    function seize(bytes32 _account, bytes32 _to, uint256 _amount)
        external
        override
        nonReentrant
        returns (uint256[] memory)
    {
        require(msg.sender == omniPool, "OmniTokenNoBorrow::seize: Bad caller.");
        uint256 accountBalance = balanceOfAccount[_account];
        if (accountBalance < _amount) {
            _amount = accountBalance;
            balanceOfAccount[_account] = 0;
            balanceOfAccount[_to] += accountBalance;
        } else {
            balanceOfAccount[_account] -= _amount;
            balanceOfAccount[_to] += _amount;
        }
        uint256[] memory seizedShares = new uint256[](1);
        seizedShares[0] = _amount;
        emit Seize(_account, _to, _amount, seizedShares);
        return seizedShares;
    }

    /**
     * @notice Returns the deposit balance of a specific account.
     * @param _account The account identifier.
     * @return The deposit balance of the account.
     */
    function getAccountDepositInUnderlying(bytes32 _account) external view override returns (uint256) {
        return balanceOfAccount[_account];
    }

    /**
     * @notice Sets a new supply cap for the contract.
     * @param _supplyCap The new supply cap amount.
     */
    function setSupplyCap(uint256 _supplyCap) external {
        require(msg.sender == omniPool, "OmniTokenNoBorrow::setSupplyCap: Bad caller.");
        supplyCap = _supplyCap;
        emit SetSupplyCap(_supplyCap);
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
            totalDeposit += balanceOfAccount[_owner.toAccount(i)];
        }
        return totalDeposit;
    }
}
