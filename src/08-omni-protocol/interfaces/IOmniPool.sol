// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

/**
 * @title IOmniPool Interface
 * @dev This interface outlines the functions available in the OmniPool contract.
 */
interface IOmniPool {
    /// Events
    event ClearedMarkets(bytes32 indexed account);
    event EnteredIsolatedMarket(bytes32 indexed account, address market);
    event EnteredMarkets(bytes32 indexed account, address[] markets);
    event EnteredMode(bytes32 indexed account, uint256 modeId);
    event ExitedMarket(bytes32 indexed account, address market);
    event ExitedMode(bytes32 indexed account);
    event Liquidated(
        address indexed liquidator,
        bytes32 indexed targetAccount,
        bytes32 liquidatorAccount,
        address liquidateMarket,
        address collateralMarket,
        uint256 amount
    );
    event PausedTranche(uint8 trancheId);
    event UnpausedTranche();
    event SetMarketConfiguration(address indexed market, MarketConfiguration marketConfig);
    event RemovedMarketConfiguration(address indexed market);
    event SetModeConfiguration(uint256 indexed modeId, ModeConfiguration modeConfig);
    event SocializedLoss(address indexed market, uint8 trancheId, bytes32 account);

    // Structs
    /**
     * @dev Structure to hold market configuration data.
     */
    struct MarketConfiguration {
        uint32 collateralFactor;
        uint32 borrowFactor; // Set to 0 if not borrowable.
        uint32 expirationTimestamp;
        uint8 riskTranche;
        bool isIsolatedCollateral; // If this is false, riskTranche must be 0
    }

    /**
     * @dev Structure to hold mode configuration data.
     */
    struct ModeConfiguration {
        uint32 collateralFactor;
        uint32 borrowFactor;
        uint8 modeTranche;
        uint32 expirationTimestamp; // Only prevents people from entering a mode, does not affect users already in existing mode
        address[] markets;
    }

    /**
     * @dev Structure to hold account specific data.
     */
    struct AccountInfo {
        uint8 modeId;
        address isolatedCollateralMarket;
        uint32 softThreshold;
    }

    /**
     * @dev Structure to hold evaluation data for an account.
     */
    struct Evaluation {
        uint256 depositTrueValue;
        uint256 borrowTrueValue;
        uint256 depositAdjValue;
        uint256 borrowAdjValue;
        uint64 numDeposit; // To combine into 1 storage slot
        uint64 numBorrow;
        bool isExpired;
    }

    /**
     * @dev Structure to hold liquidation bonus configuration data.
     */
    struct LiquidationBonusConfiguration {
        uint64 start; // 1e9 precision
        uint64 end; // 1e9 precision
        uint64 kink; // 1e9 precision
        uint32 expiredBonus; // 1e9 precision
        uint32 softThreshold; // 1e9 precision
    }

    /**
     * @dev Structure to hold liquidation arguments.
     */
    struct LiquidationParams {
        bytes32 targetAccountId; // The unique identifier of the target account to be liquidated.
        bytes32 liquidatorAccountId; // The unique identifier of the account initiating the liquidation.
        address liquidateMarket; // The address of the market from which to repay the borrow.
        address collateralMarket; // The address of the market from which to seize collateral.
        uint256 amount; // The amount of the target account's borrow balance to repay. If _amount is 0, liquidator will repay the entire borrow balance, and will error if the repayment is too large.
    }

    // Function Signatures
    /**
     * @dev Returns the address of the oracle contract.
     * @return The address of the oracle.
     */
    function oracle() external view returns (address);

    /**
     * @dev Returns the pause tranche value.
     * @return The pause tranche value.
     */
    function pauseTranche() external view returns (uint8);

    /**
     * @dev Returns the reserve receiver.
     * @return The reserve receiver identifier.
     */
    function reserveReceiver() external view returns (bytes32);

    /**
     * @dev Allows a user to enter an isolated market, the market configuration must be for isolated collateral.
     * @param _subId The identifier of the sub-account.
     * @param _isolatedMarket The address of the isolated market to enter.
     */
    function enterIsolatedMarket(uint96 _subId, address _isolatedMarket) external;

    /**
     * @dev Allows a user to enter multiple unique markets, none of them are isolated collateral markets.
     * @param _subId The identifier of the sub-account.
     * @param _markets The addresses of the markets to enter.
     */
    function enterMarkets(uint96 _subId, address[] calldata _markets) external;

    /**
     * @dev Allows a user to exit a single market including their isolated market. There must be no borrows active on the subaccount to exit a market.
     * @param _subId The identifier of the sub-account.
     * @param _market The addresses of the markets to exit.
     */
    function exitMarket(uint96 _subId, address _market) external;

    /**
     * @dev Clears all markets for a user. The subaccount must have no active borrows to clear markets.
     * @param _subId The identifier of the sub-account.
     */
    function clearMarkets(uint96 _subId) external;

    /**
     * @dev Sets a mode for a sub-account.
     * @param _subId The identifier of the sub-account.
     * @param _modeId The identifier of the mode to enter.
     */
    function enterMode(uint96 _subId, uint8 _modeId) external;

    /**
     * @dev Exits the mode currently set for a sub-account.
     * @param _subId The identifier of the sub-account.
     */
    function exitMode(uint96 _subId) external;

    /**
     * @dev Evaluates an account's financial metrics.
     * @param _accountId The identifier of the account.
     * @return eval A struct containing the evaluated metrics of the account.
     */
    function evaluateAccount(bytes32 _accountId) external returns (Evaluation memory eval);

    /**
     * @dev Allows a sub-account to borrow assets from a specified market.
     * @param _subId The identifier of the sub-account.
     * @param _market The address of the market to borrow from.
     * @param _amount The amount of assets to borrow.
     */
    function borrow(uint96 _subId, address _market, uint256 _amount) external;

    /**
     * @dev Allows a sub-account to repay borrowed assets to a specified market.
     * @param _subId The identifier of the sub-account.
     * @param _market The address of the market to repay to.
     * @param _amount The amount of assets to repay.
     */
    function repay(uint96 _subId, address _market, uint256 _amount) external;

    /**
     * @dev Initiates a liquidation process to recover assets from an under-collateralized account.
     * @param _params The liquidation parameters.
     * @return seizedShares The amount of shares seized from the liquidated account.
     */
    function liquidate(LiquidationParams calldata _params) external returns (uint256[] memory seizedShares);

    /**
     * @dev Distributes loss incurred in a market to a specified tranche of accounts.
     * @param _market The address of the market where the loss occurred.
     * @param _account The account identifier to record the loss.
     */
    function socializeLoss(address _market, bytes32 _account) external;

    /**
     * @dev Retrieves the borrow tier of an account.
     * @param _account The account info struct containing the account's details.
     * @return The borrowing tier of the account.
     */
    function getAccountBorrowTier(AccountInfo memory _account) external view returns (uint8);

    /**
     * @dev Retrieves the market addresses associated with an account.
     * @param _accountId The identifier of the account.
     * @param _account The account info struct containing the account's details.
     * @return A list of market addresses associated with the account.
     */
    function getAccountPoolMarkets(bytes32 _accountId, AccountInfo memory _account)
        external
        view
        returns (address[] memory);

    /**
     * @dev Retrieves the liquidation bonus and soft threshold values for a market.
     * @param _depositAdjValue The adjusted value of deposits in the market.
     * @param _borrowAdjValue The adjusted value of borrows in the market.
     * @param _collateralMarket The address of the collateral market.
     * @return bonus The liquidation bonus value.
     * @return softThreshold The soft liquidation threshold value.
     */
    function getLiquidationBonusAndThreshold(
        uint256 _depositAdjValue,
        uint256 _borrowAdjValue,
        address _collateralMarket
    ) external view returns (uint256 bonus, uint256 softThreshold);

    /**
     * @dev Checks if an account is healthy based on its financial metrics.
     * @param _accountId The identifier of the account.
     * @return A boolean indicating whether the account is healthy.
     */
    function isAccountHealthy(bytes32 _accountId) external returns (bool);

    /**
     * @dev Resets the pause tranche to its initial state.
     */
    function resetPauseTranche() external;

    /**
     * @dev Updates the market configuration.
     * @param _market The address of the market.
     * @param _marketConfig The market configuration data.
     */
    function setMarketConfiguration(address _market, MarketConfiguration calldata _marketConfig) external;

    /**
     * @dev Updates mode configurations one at a time.
     * @param _modeConfiguration An single mode configuration.
     */
    function setModeConfiguration(ModeConfiguration calldata _modeConfiguration) external;

    /**
     * @dev Updates the soft liquidation threshold for an account.
     * @param _accountId The account identifier.
     * @param _softThreshold The soft liquidation threshold value.
     */
    function setAccountSoftLiquidation(bytes32 _accountId, uint32 _softThreshold) external;

    /**
     * @dev Updates the liquidation bonus configuration for a market.
     * @param _market The address of the market.
     * @param _config The liquidation bonus configuration data.
     */
    function setLiquidationBonusConfiguration(address _market, LiquidationBonusConfiguration calldata _config)
        external;

    /**
     * @notice Sets the tranche count for a specific market.
     * @dev This function allows to set the number of tranches for a given market.
     * It's an external function that can only be called by an account with the `MARKET_CONFIGURATOR_ROLE`.
     * @param _market The address of the market contract.
     * @param _trancheCount The number of tranches to be set for the market.
     */
    function setTrancheCount(address _market, uint8 _trancheCount) external;

    /**
     * @dev This function can only be called by an account with the MARKET_CONFIGURATOR_ROLE.
     * It invokes the setTrancheBorrowCaps function of the IOmniToken contract associated with the specified market.
     * @param _market The address of the market for which to set the borrow caps.
     * @param _borrowCaps An array of borrow cap values, one for each tranche of the market.
     */
    function setBorrowCap(address _market, uint256[] calldata _borrowCaps) external;

    /**
     * @dev This function can only be called by an account with the MARKET_CONFIGURATOR_ROLE.
     * It invokes the setSupplyCap function of the IOmniTokenNoBorrow contract associated with the specified market.
     * @param _market The address of the market for which to set the no-borrow supply cap.
     * @param _noBorrowSupplyCap The value of the no-borrow supply cap to set.
     */
    function setNoBorrowSupplyCap(address _market, uint256 _noBorrowSupplyCap) external;

    /**
     * @notice Sets the reserve receiver's address. This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * @dev The reserve receiver's address is converted to a bytes32 account identifier using the toAccount function with a subId of 0.
     * @param _reserveReceiver The address of the reserve receiver to be set.
     */
    function setReserveReceiver(address _reserveReceiver) external;
}
