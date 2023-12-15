// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title ICustomOmniOracle Interface
 * @notice Interface for the custom oracle used by OmniOracle contract.
 */
interface ICustomOmniOracle {
    /**
     * @notice Fetches the price of the specified asset.
     * @param _underlying The address of the asset.
     * @return The price of the asset, normalized to 1e18.
     */
    function getPrice(address _underlying) external view returns (uint256);
}
