// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

/**
 * @title IOmniTokenBase
 * @notice Base interface shared by the IOmniToken and IOmniTokenNoBorrow interfaces.
 */
interface IOmniTokenBase {
    /**
     * @notice Retrieves the total deposit amount for a specific account.
     * @param _account The account identifier.
     * @return The total deposit amount.
     */
    function getAccountDepositInUnderlying(bytes32 _account) external view returns (uint256);

    /**
     * @notice Calculates the total deposited amount for a specific owner across sub-accounts. This funciton is for wallets and Etherscan to pick up balances.
     * @param _owner The address of the owner.
     * @return The total deposited amount.
     */
    function balanceOf(address _owner) external view returns (uint256);

    /**
     * @notice Seizes funds from a user's account in the event of a liquidation. This is a priveleged function only callable by the OmniPool and must be implemented carefully.
     * @param _account The account from which funds will be seized.
     * @param _to The account to which seized funds will be sent.
     * @param _amount The amount of funds to seize.
     * @return The shares seized from each tranche.
     */
    function seize(bytes32 _account, bytes32 _to, uint256 _amount) external returns (uint256[] memory);
}
