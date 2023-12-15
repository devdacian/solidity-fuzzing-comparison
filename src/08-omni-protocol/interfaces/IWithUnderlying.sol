// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IWithUnderlying
 * @notice Interface for the WithUnderlying contract to handle the inflow and outflow of ERC20 tokens.
 */
interface IWithUnderlying {
    /**
     * @notice Gets the address of the underlying ERC20 token.
     * @return The address of the underlying ERC20 token.
     */
    function underlying() external view returns (address);
}
