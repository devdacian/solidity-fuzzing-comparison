// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

import "./interfaces/IBandReference.sol";
import "./interfaces/IChainlinkAggregator.sol";
import "./interfaces/ICustomOmniOracle.sol";
import "./interfaces/IOmniOracle.sol";

/**
 * @title OmniOracle contract
 * @notice This contract facilitates USD base price retrieval from Chainlink, Band, or a custom oracle integrating the IOmniOracle interface.
 * Special attention must be paid by the admin to ensure oracle configurations are valid given the below specifications.
 * @dev Inherits from AccessControl and implements IOmniOracle interface.
 * Makes assumptions about oracle feeds, e.g. the decimals, delay, and base currency. Configurator must pay special attention.
 * @dev This oracle contract does not handle Chainlink L2 Sequencer Uptime Feeds requirements, and should only be used for L1 deployments.
 */
contract OmniOracle is IOmniOracle, AccessControl, Initializable {
    uint256 public constant PRICE_SCALE = 1e36; // Gives enough precision for the price of one base unit of token, as most tokens have at most 18 decimals
    string private constant USD = "USD";

    mapping(address => OracleConfig) public oracleConfigs;
    mapping(address => string) public oracleSymbols;

    /**
     * @notice Initializes the admin role with the contract deployer/upgrader.
     * @param _admin The address of the multisig admin.
     */
    function initialize(address _admin) external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /**
     * @notice Fetches the price of the specified asset in USD for the base unit of the underlying token.
     * @dev Band oracle documentation says they always return price multiplied by 1e18 (https://docs.bandchain.org/products/band-standard-dataset/using-band-standard-dataset/contract#getreferencedata)
     * @param _underlying The address of the asset.
     * @return The price of the asset in USD, in the base unit of the underlying token.
     */
    function getPrice(address _underlying) external view returns (uint256) {
        OracleConfig memory config = oracleConfigs[_underlying];
        if (config.provider == Provider.Band) {
            IStdReference.ReferenceData memory data;
            data = IStdReference(config.oracleAddress).getReferenceData(oracleSymbols[_underlying], USD);
            require(
                data.lastUpdatedBase >= block.timestamp - config.delay, "OmniOracle::getPrice: Stale price for base."
            );
            require(
                data.lastUpdatedQuote >= block.timestamp - config.delayQuote,
                "OmniOracle::getPrice: Stale price for quote."
            );
            return data.rate * (PRICE_SCALE / 1e18) / (10 ** config.underlyingDecimals); // Price in one base unit with 1e36 precision
        } else if (config.provider == Provider.Chainlink) {
            (, int256 answer,, uint256 updatedAt,) = IChainlinkAggregator(config.oracleAddress).latestRoundData();
            require(
                answer > 0 && updatedAt >= block.timestamp - config.delay,
                "OmniOracle::getPrice: Invalid chainlink price."
            );
            return uint256(answer) * (PRICE_SCALE / (10 ** IChainlinkAggregator(config.oracleAddress).decimals()))
                / (10 ** config.underlyingDecimals);
        } else if (config.provider == Provider.Other) {
            return ICustomOmniOracle(config.oracleAddress).getPrice(_underlying) * (PRICE_SCALE / 1e18)
                / (10 ** config.underlyingDecimals);
        } else {
            revert("OmniOracle::getPrice: Invalid provider.");
        }
    }

    /**
     * @notice Sets the oracle configuration for the specified asset. Chainlink addresses must use the USD price feed.
     * @param _underlying The address of the asset.
     * @param _oracleConfig The oracle configuration for the asset. Must be Chainlink, Band, or implement the IOmniOracle interface.
     */
    function setOracleConfig(address _underlying, OracleConfig calldata _oracleConfig, string calldata _symbol)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _oracleConfig.oracleAddress != address(0) && _underlying != address(0),
            "OmniOracle::setOracleConfig: Can never use zero address."
        );
        require(_oracleConfig.provider != Provider.Invalid, "OmniOracle::setOracleConfig: Invalid provider.");
        require(_oracleConfig.delay > 0, "OmniOracle::setOracleConfig: Invalid delay.");
        require(_oracleConfig.delayQuote > 0, "OmniOracle::setOracleConfig: Invalid delay quote.");
        oracleConfigs[_underlying] = _oracleConfig;
        oracleSymbols[_underlying] = _symbol;
        emit SetOracle(
            _underlying,
            _oracleConfig.oracleAddress,
            _oracleConfig.provider,
            _oracleConfig.delay,
            _oracleConfig.delayQuote,
            _oracleConfig.underlyingDecimals
        );
    }

    /**
     * @notice Removes the oracle configuration for the specified asset.
     * @param _underlying The address of the asset.
     */
    function removeOracleConfig(address _underlying) external onlyRole(DEFAULT_ADMIN_ROLE) {
        delete oracleConfigs[_underlying];
        emit RemoveOracle(_underlying);
    }
}
