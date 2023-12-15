// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import "./IOmniTokenBase.sol";

/**
 * @title IOmniTokenNoBorrow
 * @notice Interface for the OmniTokenNoBorrow contract which provides deposit and withdrawal features, without borrowing features.
 */
interface IOmniTokenNoBorrow is IOmniTokenBase {
    /// Events
    event Deposit(bytes32 indexed account, uint256 amount);
    event Withdraw(bytes32 indexed account, uint256 amount);
    event Seize(bytes32 indexed account, bytes32 indexed to, uint256 amount, uint256[] seizeShares);
    event SetSupplyCap(uint256 supplyCap);
    event Transfer(bytes32 indexed from, bytes32 indexed to, uint256 amount);

    /**
     * @notice Deposits a specified amount to the account.
     * @param _subId The sub-account identifier.
     * @param _amount The amount to deposit.
     * @return amount The actual amount deposited.
     */
    function deposit(uint96 _subId, uint256 _amount) external returns (uint256 amount);

    /**
     * @notice Withdraws a specified amount from the account.
     * @param _subId The sub-account identifier.
     * @param _amount The amount to withdraw.
     * @return amount The actual amount withdrawn.
     */
    function withdraw(uint96 _subId, uint256 _amount) external returns (uint256 amount);

    /**
     * @notice Transfers a specified amount of tokens from the sender's account to another account.
     * @param _subId The subscription ID associated with the sender's account.
     * @param _to The account identifier to which the tokens are being transferred.
     * @param _amount The amount of tokens to transfer.
     * @return A boolean value indicating whether the transfer was successful.
     */
    function transfer(uint96 _subId, bytes32 _to, uint256 _amount) external returns (bool);

    /**
     * @notice Sets a new supply cap for the contract.
     * @param _supplyCap The new supply cap amount.
     */
    function setSupplyCap(uint256 _supplyCap) external;
}
