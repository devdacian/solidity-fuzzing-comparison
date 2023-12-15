// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import "./IOmniTokenBase.sol";

/**
 * @title IOmniToken
 * @notice Interface for the OmniToken contract which manages deposits, withdrawals, borrowings, and repayments within the Omni protocol.
 */
interface IOmniToken is IOmniTokenBase {
    /// Events
    event Accrue();
    event Deposit(bytes32 indexed account, uint8 indexed trancheId, uint256 amount, uint256 share);
    event Withdraw(bytes32 indexed account, uint8 indexed trancheId, uint256 amount, uint256 share);
    event Borrow(bytes32 indexed account, uint8 indexed trancheId, uint256 amount, uint256 share);
    event Repay(bytes32 indexed account, address indexed payer, uint8 indexed trancheId, uint256 amount, uint256 share);
    event Seize(bytes32 indexed account, bytes32 indexed to, uint256 amount, uint256[] seizedShares);
    event SetTrancheCount(uint8 trancheCount);
    event SetTrancheBorrowCaps(uint256[] borrowCaps);
    event SocializedLoss(bytes32 indexed account, uint8 indexed trancheId, uint256 amount, uint256 share);
    event Transfer(bytes32 indexed from, bytes32 indexed to, uint8 indexed trancheId, uint256 share);

    /**
     * @notice Gets the address of the OmniPool contract.
     * @return The address of the OmniPool contract.
     */
    function omniPool() external view returns (address);

    /**
     * @notice Gets the address of the Interest Rate Model (IRM) contract.
     * @return The address of the IRM contract.
     */
    function irm() external view returns (address);

    /**
     * @notice Gets the last accrual time.
     * @return The timestamp of the last accrual time.
     */
    function lastAccrualTime() external view returns (uint256);

    /**
     * @notice Gets the count of tranches.
     * @return The total number of tranches.
     */
    function trancheCount() external view returns (uint8);

    /**
     * @notice Gets the reserve receiver.
     * @return The bytes32 identifier of the reserve receiver.
     */
    function reserveReceiver() external view returns (bytes32);

    /**
     * @notice Gets the borrow cap for a specific tranche.
     * @param _trancheId The ID of the tranche for which to retrieve the borrow cap.
     * @return The borrow cap for the specified tranche.
     */
    function getBorrowCap(uint8 _trancheId) external view returns (uint256);

    /**
     * @notice Accrues interest for all tranches, calculates and distributes the interest among the depositors and updates tranche balances.
     * The function also handles reserve payments. This method needs to be called before any deposit, withdrawal, borrow, or repayment actions to update the state of the contract.
     * @dev Interest is paid out proportionately to more risky tranche deposits per tranche
     */
    function accrue() external;

    /**
     * @notice Deposits a specified amount into a specified tranche.
     * @param _subId Sub-account identifier for the depositor.
     * @param _trancheId Identifier of the tranche to deposit into.
     * @param _amount Amount to deposit.
     * @return share Amount of deposit shares received in exchange for the deposit.
     */
    function deposit(uint96 _subId, uint8 _trancheId, uint256 _amount) external returns (uint256 share);

    /**
     * @notice Withdraws funds from a specified tranche.
     * @param _subId The ID of the sub-account.
     * @param _trancheId The ID of the tranche.
     * @param _share The share of the user in the tranche.
     * @return amount The amount of funds withdrawn.
     */
    function withdraw(uint96 _subId, uint8 _trancheId, uint256 _share) external returns (uint256 amount);

    /**
     * @notice Borrows funds from a specified tranche.
     * @param _account The account of the user.
     * @param _trancheId The ID of the tranche.
     * @param _amount The amount to borrow.
     * @return share The share of the borrowed amount in the tranche.
     */
    function borrow(bytes32 _account, uint8 _trancheId, uint256 _amount) external returns (uint256 share);

    /**
     * @notice Repays borrowed funds.
     * @param _account The account of the user.
     * @param _payer The account that will pay the borrowed amount.
     * @param _trancheId The ID of the tranche.
     * @param _amount The amount to repay.
     * @return amount The amount of the repaid amount in the tranche.
     */
    function repay(bytes32 _account, address _payer, uint8 _trancheId, uint256 _amount)
        external
        returns (uint256 amount);

    /**
     * @notice Transfers specified shares from one account to another within a specified tranche.
     * @param _subId The subscription ID related to the sender's account.
     * @param _to The account identifier to which shares are being transferred.
     * @param _trancheId The identifier of the tranche where the transfer is occurring.
     * @param _shares The amount of shares to transfer.
     * @return A boolean value indicating whether the transfer was successful.
     */
    function transfer(uint96 _subId, bytes32 _to, uint8 _trancheId, uint256 _shares) external returns (bool);

    /**
     * @notice Distributes the bad debt loss in a tranche among all tranche members. This function should only be called by the OmniPool.
     * @param _account The account that incurred a loss.
     * @param _trancheId The ID of the tranche.
     */
    function socializeLoss(bytes32 _account, uint8 _trancheId) external;

    /**
     * @notice Computes the borrowing amount of a specific account in the underlying asset for a given borrow tier.
     * @dev The division is ceiling division.
     * @param _account The account identifier for which the borrowing amount is to be computed.
     * @param _borrowTier The borrow tier identifier from which the borrowing amount is to be computed.
     * @return The borrowing amount of the account in the underlying asset for the given borrow tier.
     */
    function getAccountBorrowInUnderlying(bytes32 _account, uint8 _borrowTier) external view returns (uint256);

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
        returns (uint256 depositShare, uint256 borrowShare);

    /**
     * @notice Sets the borrow caps for each tranche.
     * @param _borrowCaps An array of borrow caps in the underlying's decimals.
     */
    function setTrancheBorrowCaps(uint256[] calldata _borrowCaps) external;

    /**
     * @notice Sets the number of tranches.
     * @param _trancheCount The new tranche count.
     */
    function setTrancheCount(uint8 _trancheCount) external;

    /**
     * @notice Fetches and updates the reserve receiver from the OmniPool contract.
     */
    function fetchReserveReceiver() external;
}
