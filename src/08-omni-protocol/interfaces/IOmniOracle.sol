// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IOmniOracle Interface
 * @notice Interface for the OmniOracle contract.
 */
interface IOmniOracle {
    /// Events
    event SetOracle(
        address indexed underlying,
        address indexed oracle,
        Provider provider,
        uint32 delay,
        uint32 delayQuote,
        uint8 underlyingDecimals
    );
    event RemoveOracle(address indexed underlying);

    /// Structs
    enum Provider {
        Invalid,
        Band,
        Chainlink,
        Other // Must implement the ICustomOmniOracle interface, use very carefully should return 1 full unit price multiplied by 1e18
    }

    struct OracleConfig {
        // One storage slot
        address oracleAddress; // 160 bits
        Provider provider; // 8 bits
        uint32 delay; // 32 bits, because this is time-based in unix
        uint32 delayQuote; // 32 bits, for Band quote delay
        uint8 underlyingDecimals; // 8 bits, decimals of underlying token
    }

    /**
     * @notice Fetches the price of the specified asset.
     * @param _underlying The address of the asset.
     * @return The price of the asset, normalized to 1e18.
     */
    function getPrice(address _underlying) external view returns (uint256);
}
