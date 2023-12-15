// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.23;

import "../interfaces/ICustomOmniOracle.sol";
import "../interfaces/IChainlinkAggregator.sol";


interface ILidoETH {
    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);
}

contract WstETHCustomOracle is ICustomOmniOracle {
    address public immutable stETH;
    address public immutable wstETH;
    address public immutable chainlinkStETHUSD;
    uint256 private constant MAX_DELAY = 1 days;

    /**
     * @notice Constructor for the WstETHCustomOracle
     * @param _stETH The address of the stETH contract.
     * @param _wstETH The address of the wstETH contract. 
     * @param _chainlinkStETHUSD The address of the Chainlink aggregator contract.
     */
    constructor(address _stETH, address _wstETH, address _chainlinkStETHUSD) {
        stETH = _stETH;
        wstETH = _wstETH;
        chainlinkStETHUSD = _chainlinkStETHUSD;
    }

    /**
     * @notice Fetches the price of the specified asset.
     * @param _underlying The address of the asset.
     * @return The price of the asset, normalized to 1e18.
     */
    function getPrice(address _underlying) external view returns (uint256) {
        require(_underlying == wstETH, "Invalid address for oracle");
        (, int256 stETHPrice,,uint256 updatedAt,) = IChainlinkAggregator(chainlinkStETHUSD).latestRoundData();
        if (stETHPrice <= 0) return 0;
        require(updatedAt >= block.timestamp - MAX_DELAY, "Stale price for stETH");

        uint256 stEthPerWstETH = ILidoETH(stETH).getPooledEthByShares(1e18);

        return (stEthPerWstETH * uint256(stETHPrice)) / (10 ** IChainlinkAggregator(chainlinkStETHUSD).decimals());
    }
}
