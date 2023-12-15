// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IOmniOracle.sol";
import "./interfaces/IOmniPool.sol";
import "./interfaces/IOmniToken.sol";
import "./interfaces/IOmniTokenNoBorrow.sol";
import "./interfaces/IWithUnderlying.sol";
import "./SubAccount.sol";

/**
 * @title OmniPool
 * @notice This contract implements a manager for handling loans, protocol market, mode, and account configurations, and liquidations.
 * @dev This contract implements a lending pool with various modes and market configurations.
 * It utilizes different structs to keep track of market, mode, account configurations, evaluations,
 * and liquidation bonuses. It has a variety of external and public functions to manage and interact with
 * the lending pool, along with internal utility functions. Includes AccessContral, Pausable, and ReentrancyGuardUpgradeable (includes Initializable)
 * from OpenZeppelin.
 */
contract OmniPool is IOmniPool, AccessControlUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SubAccount for address;

    bytes32 public constant SOFT_LIQUIDATION_ROLE = keccak256("SOFT_LIQUIDATION_ROLE");
    bytes32 public constant MARKET_CONFIGURATOR_ROLE = keccak256("MARKET_CONFIGURATOR_ROLE");

    uint256 public constant SELF_COLLATERALIZATION_FACTOR = 0.96e9; // 0.96
    uint256 public constant FACTOR_PRECISION_SCALE = 1e9;
    uint256 public constant LIQ_BONUS_PRECISION_SCALE = 1e9;
    uint256 public constant HEALTH_FACTOR_SCALE = 1e9;
    uint256 public constant MAX_BASE_SOFT_LIQUIDATION = 1.4e9;
    uint256 public constant MAX_LIQ_KINK = 0.2e9; // Borrow value exceeds deposit value by 20%
    uint256 public constant PRICE_SCALE = 1e18; // Must match up with PRICE_SCALE in OmniOracle
    uint256 public constant MAX_MARKETS_PER_ACCOUNT = 9; // Will be 10 including isolated collateral market

    mapping(bytes32 => AccountInfo) public accountInfos;
    mapping(bytes32 => address[]) public accountMarkets;

    uint256 public modeCount;
    mapping(uint256 => ModeConfiguration) public modeConfigurations;
    mapping(address => MarketConfiguration) public marketConfigurations;
    mapping(address => LiquidationBonusConfiguration) public liquidationBonusConfigurations;

    address public oracle;
    uint8 public pauseTranche;
    bytes32 public reserveReceiver;

    /**
     * @notice Initializes a new instance of the contract, setting up the oracle, reserve receiver, pause tranche, and various roles.
     * This constructor sets the oracle address, initializes the pause tranche to its maximum value, and sets the reserve receiver to the provided address.
     * It also sets up the DEFAULT_ADMIN_ROLE, SOFT_LIQUIDATION_ROLE, and MARKET_CONFIGURATOR_ROLE, assigning them to the account deploying the contract.
     * @param _oracle The address of the oracle contract to be used for price information.
     * @param _reserveReceiver The address of the reserve receiver. This address will be converted to an account with a subId of 0.
     * @param _admin The address of the multisig admin
     */
    function initialize(address _oracle, address _reserveReceiver, address _admin) external initializer {
        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        oracle = _oracle;
        pauseTranche = type(uint8).max;
        reserveReceiver = _reserveReceiver.toAccount(0);
        _setupRole(DEFAULT_ADMIN_ROLE, _admin); // Additionally set up other roles?
        _setupRole(SOFT_LIQUIDATION_ROLE, _admin);
        _setupRole(MARKET_CONFIGURATOR_ROLE, _admin);
    }

    /**
     * @notice Allows a user to enter an isolated market, the market configuration must be for isolated collateral.
     * @dev The function checks whether the market is valid for isolation and updates the account's isolatedCollateralMarket field.
     * A subaccount is only allowed to have 1 isolated collateral market at a time.
     * @param _subId The sub-account identifier.
     * @param _isolatedMarket The address of the isolated market to enter.
     */
    function enterIsolatedMarket(uint96 _subId, address _isolatedMarket) external {
        bytes32 accountId = msg.sender.toAccount(_subId);
        AccountInfo memory account = accountInfos[accountId];
        require(account.modeId == 0, "OmniPool::enterIsolatedMarket: Already in a mode.");
        require(
            account.isolatedCollateralMarket == address(0),
            "OmniPool::enterIsolatedMarket: Already has isolated collateral."
        );
        MarketConfiguration memory marketConfig = marketConfigurations[_isolatedMarket];
        if (marketConfig.expirationTimestamp <= block.timestamp || !marketConfig.isIsolatedCollateral) {
            revert("OmniPool::enterIsolatedMarket: Isolated market invalid.");
        }
        Evaluation memory eval = evaluateAccount(accountId);
        require(eval.numBorrow == 0, "OmniPool::enterIsolatedMarket: Non-zero borrow count.");
        accountInfos[accountId].isolatedCollateralMarket = _isolatedMarket;
        emit EnteredIsolatedMarket(accountId, _isolatedMarket);
    }

    /**
     * @notice Allows a user to enter multiple unique markets, none of them are isolated collateral markets.
     * @dev The function checks the validity of each market and updates the account's market list. Markets must not already be entered.
     * @param _subId The sub-account identifier.
     * @param _markets The addresses of the markets to enter.
     */
    function enterMarkets(uint96 _subId, address[] calldata _markets) external {
        bytes32 accountId = msg.sender.toAccount(_subId);
        require(accountInfos[accountId].modeId == 0, "OmniPool::enterMarkets: Already in a mode.");
        address[] memory existingMarkets = accountMarkets[accountId];
        address[] memory newMarkets = new address[](existingMarkets.length + _markets.length);
        require(newMarkets.length <= MAX_MARKETS_PER_ACCOUNT, "OmniPool::enterMarkets: Too many markets.");
        for (uint256 i = 0; i < existingMarkets.length; ++i) {
            // Copy over existing markets
            newMarkets[i] = existingMarkets[i];
        }
        for (uint256 i = 0; i < _markets.length; ++i) {
            address market = _markets[i];
            MarketConfiguration memory marketConfig = marketConfigurations[market];
            require(
                marketConfig.expirationTimestamp > block.timestamp && !marketConfig.isIsolatedCollateral,
                "OmniPool::enterMarkets: Market invalid."
            );
            require(!_contains(newMarkets, market), "OmniPool::enterMarkets: Already in the market.");
            require(
                IOmniToken(market).getBorrowCap(0) > 0,
                "OmniPool::enterMarkets: Market has no borrow cap for 0 tranche."
            );
            newMarkets[i + existingMarkets.length] = market;
        }
        accountMarkets[accountId] = newMarkets;
        emit EnteredMarkets(accountId, _markets);
    }

    /**
     * @notice Allows a user to exit multiple markets including their isolated market. There must be no borrows active on the subaccount to exit a market.
     * @dev The function removes the specified markets from the account's market list after ensuring the account has no outstanding borrows.
     * @param _subId The sub-account identifier.
     * @param _market The address of the market to exit.
     */
    function exitMarket(uint96 _subId, address _market) external {
        bytes32 accountId = msg.sender.toAccount(_subId);
        AccountInfo memory account = accountInfos[accountId];
        require(account.modeId == 0, "OmniPool::exitMarkets: In a mode, need to call exitMode.");
        address[] memory markets_ = getAccountPoolMarkets(accountId, account);
        Evaluation memory eval = _evaluateAccountInternal(accountId, markets_, account);
        require(eval.numBorrow == 0, "OmniPool::exitMarkets: Non-zero borrow count.");
        if (_market == account.isolatedCollateralMarket) {
            accountInfos[accountId].isolatedCollateralMarket = address(0);
        } else {
            require(markets_.length > 0, "OmniPool::exitMarkets: No markets to exit");
            require(_contains(markets_, _market), "OmniPool::exitMarkets: Market not entered");
            uint256 newMarketsLength = markets_.length - 1;
            if (newMarketsLength > 0) {
                address[] memory newMarkets = new address[](markets_.length - 1);
                uint256 newIndex = 0;
                for (uint256 i = 0; i < markets_.length; ++i) {
                    if (markets_[i] != _market) {
                        newMarkets[newIndex] = markets_[i];
                        ++newIndex;
                    }
                }
                delete accountMarkets[accountId]; // Gas refund?
                accountMarkets[accountId] = newMarkets;
            } else {
                delete accountMarkets[accountId];
            }
        }
        emit ExitedMarket(accountId, _market);
    }

    /**
     * @notice Clears all markets for a user including isolated collateral. The subaccount must have no active borrows to clear markets.
     * @dev The function checks that the account has no outstanding borrows before clearing all markets.
     * @param _subId The sub-account identifier.
     */
    function clearMarkets(uint96 _subId) external {
        bytes32 accountId = msg.sender.toAccount(_subId);
        AccountInfo memory account = accountInfos[accountId];
        require(account.modeId == 0, "OmniPool::clearMarkets: Already in a mode.");
        Evaluation memory eval = evaluateAccount(accountId);
        require(eval.numBorrow == 0, "OmniPool::clearMarkets: Non-zero borrow count.");
        accountInfos[accountId].isolatedCollateralMarket = address(0);
        delete accountMarkets[accountId];
        emit ClearedMarkets(accountId);
    }

    /**
     * @notice Allows a user to enter a mode. The subaccount must not already be in a mode. The mode must not have expired.
     * @dev The function sets the modeId field in the account's info and emits an EnteredMode event.
     * @param _subId The sub-account identifier.
     * @param _modeId The mode identifier to enter.
     */
    function enterMode(uint96 _subId, uint8 _modeId) external {
        bytes32 accountId = msg.sender.toAccount(_subId);
        require(_modeId > 0 && _modeId <= modeCount, "OmniPool::enterMode: Invalid mode ID.");
        AccountInfo memory account = accountInfos[accountId];
        require(account.modeId == 0, "OmniPool::enterMode: Already in a mode.");
        require(
            accountMarkets[accountId].length == 0 && account.isolatedCollateralMarket == address(0),
            "OmniPool::enterMode: Non-zero market count."
        );
        require(modeConfigurations[_modeId].expirationTimestamp > block.timestamp, "OmniPool::enterMode: Mode expired.");
        account.modeId = _modeId;
        accountInfos[accountId] = account;
        emit EnteredMode(accountId, _modeId);
    }

    /**
     * @notice Allows a user to exit a mode. There must be no active borrows in the subaccount to exit.
     * @dev The function resets the modeId field in the account's info and emits an ExitedMode event.
     * @param _subId The sub-account identifier.
     */
    function exitMode(uint96 _subId) external {
        bytes32 accountId = msg.sender.toAccount(_subId);
        AccountInfo memory account = accountInfos[accountId];
        require(account.modeId != 0, "OmniPool::exitMode: Not in a mode.");
        Evaluation memory eval = evaluateAccount(accountId);
        require(eval.numBorrow == 0, "OmniPool::exitMode: Non-zero borrow count.");
        account.modeId = 0;
        accountInfos[accountId] = account;
        emit ExitedMode(accountId);
    }

    /**
     * @notice Evaluates an account's deposits and borrows values.
     * @dev The function computes the true and adjusted values of deposits and borrows for the account.
     * @param _accountId The account identifier.
     * @return eval An Evaluation struct containing the account's financial information.
     */
    function evaluateAccount(bytes32 _accountId) public returns (Evaluation memory eval) {
        AccountInfo memory account = accountInfos[_accountId];
        address[] memory poolMarkets = getAccountPoolMarkets(_accountId, account);
        return _evaluateAccountInternal(_accountId, poolMarkets, account);
    }

    /**
     * @notice Evaluates an account's financial standing within a lending pool.
     * @dev This function accrues interest, computes market prices, deposit and borrow balances, and calculates the adjusted values of
     * deposits and borrows based on the account's mode and market configurations.
     * @param _accountId The unique identifier of the account to be evaluated.
     * @param _poolMarkets An array of addresses representing the markets in which the account has activity. Excludes the isolated collateral market if it exists.
     * @param _account The AccountInfo struct containing the account's mode, isolated collateral market, and other relevant data.
     * @return eval An Evaluation struct containing data on the account's deposit and borrow balances, both true and adjusted values.
     */
    function _evaluateAccountInternal(bytes32 _accountId, address[] memory _poolMarkets, AccountInfo memory _account)
        internal
        returns (Evaluation memory eval)
    {
        ModeConfiguration memory mode;
        if (_account.modeId != 0) mode = modeConfigurations[_account.modeId];
        for (uint256 i = 0; i < _poolMarkets.length; ++i) {
            // Accrue interest for all borrowable markets
            IOmniToken(_poolMarkets[i]).accrue();
        }
        uint256 marketCount = _poolMarkets.length;
        if (_account.isolatedCollateralMarket != address(0)) {
            ++marketCount;
        }
        for (uint256 i = 0; i < marketCount; ++i) {
            address market;
            // A market is either a pool market or the isolated collateral market (last index).
            if (i < _poolMarkets.length) {
                market = _poolMarkets[i];
            } else {
                market = _account.isolatedCollateralMarket;
            }
            MarketConfiguration memory marketConfiguration_ = marketConfigurations[market];
            if (marketConfiguration_.expirationTimestamp <= block.timestamp) {
                eval.isExpired = true; // Must repay all debts and exit market to get rid of unhealthy account status if expired
            }
            address underlying = IWithUnderlying(market).underlying();
            uint256 price = IOmniOracle(oracle).getPrice(underlying); // Returns price in base units multiplied by 1e36
            uint256 depositAmount = IOmniTokenBase(market).getAccountDepositInUnderlying(_accountId);
            if (depositAmount != 0) {
                ++eval.numDeposit;
                uint256 depositValue = (depositAmount * price) / PRICE_SCALE; // Rounds down
                eval.depositTrueValue += depositValue;
                uint256 collateralFactor = marketCount == 1
                    ? SELF_COLLATERALIZATION_FACTOR
                    : _account.modeId == 0 ? uint256(marketConfiguration_.collateralFactor) : uint256(mode.collateralFactor);
                eval.depositAdjValue += (depositValue * collateralFactor) / FACTOR_PRECISION_SCALE; // Rounds down
            }
            if (i >= _poolMarkets.length) {
                // Isolated collateral market. No borrow.
                continue;
            }
            uint8 borrowTier = getAccountBorrowTier(_account);
            uint256 borrowAmount = IOmniToken(market).getAccountBorrowInUnderlying(_accountId, borrowTier);
            if (borrowAmount != 0) {
                ++eval.numBorrow;
                uint256 borrowValue = (borrowAmount * price) / PRICE_SCALE; // Rounds down
                eval.borrowTrueValue += borrowValue;
                uint256 borrowFactor = marketCount == 1
                    ? SELF_COLLATERALIZATION_FACTOR
                    : _account.modeId == 0 ? uint256(marketConfiguration_.borrowFactor) : uint256(mode.borrowFactor);
                eval.borrowAdjValue += (borrowValue * FACTOR_PRECISION_SCALE) / borrowFactor; // Rounds down
            }
        }
    }

    /**
     * @notice Allows an account to borrow funds from a specified market the subaccount has entered, provided the account remains in a healthy financial standing post-borrow.
     * @param _subId The sub-account identifier from which to borrow.
     * @param _market The address of the market from which to borrow.
     * @param _amount The amount of funds to borrow.
     */
    function borrow(uint96 _subId, address _market, uint256 _amount) external nonReentrant whenNotPaused {
        bytes32 accountId = msg.sender.toAccount(_subId);
        AccountInfo memory account = accountInfos[accountId];
        address[] memory poolMarkets = getAccountPoolMarkets(accountId, account);
        require(_contains(poolMarkets, _market), "OmniPool::borrow: Not in pool markets.");
        uint8 borrowTier = getAccountBorrowTier(account);
        IOmniToken(_market).borrow(accountId, borrowTier, _amount);
        Evaluation memory eval = _evaluateAccountInternal(accountId, poolMarkets, account);
        require(
            eval.depositAdjValue >= eval.borrowAdjValue && !eval.isExpired,
            "OmniPool::borrow: Not healthy after borrow."
        );
    }

    /**
     * @notice Allows an account to repay borrowed funds to a specified market the subaccount has entered.
     * @param _subId The sub-account identifier from which to repay.
     * @param _market The address of the market to which to repay.
     * @param _amount The amount of funds to repay. If _amount is 0, the contract will repay the entire borrow balance.
     */
    function repay(uint96 _subId, address _market, uint256 _amount) external {
        bytes32 accountId = msg.sender.toAccount(_subId);
        AccountInfo memory account = accountInfos[accountId];
        address[] memory poolMarkets = getAccountPoolMarkets(accountId, account);
        require(_contains(poolMarkets, _market), "OmniPool::repay: Not in pool markets.");
        uint8 borrowTier = getAccountBorrowTier(account);
        IOmniToken(_market).repay(accountId, msg.sender, borrowTier, _amount);
    }

    /**
     * @notice Initiates the liquidation process on an undercollateralized or expired account, repaying some or all of the target account's borrow balance
     * while seizing a portion of the target's collateral. The amount of collateral seized is determined by the liquidation bonus and the price of the
     * assets involved. Soft liquidation is only allowed if there is no bad debt, otherwise if bad debt exists a full liquidation is bypassed.
     * @dev Liquidation configuration must be set for the _collateralMarket or else will revert.
     * The seized amount of shares is not guaranteed to compensate the value of the repayment during liquidation. Liquidators should check the returned value if they have a
     * minimum expectation of payout from liquidating, and perform necessary logic to revert if necessary.
     * @param _params The LiquidationParams struct containing the target account's identifier, the liquidator's identifier, the market to be liquidated,
     * @return seizedShares The amount of shares seized from the liquidated account.
     */
    function liquidate(LiquidationParams calldata _params)
        external
        whenNotPaused
        nonReentrant
        returns (uint256[] memory seizedShares)
    {
        AccountInfo memory targetAccount = accountInfos[_params.targetAccountId];
        address[] memory poolMarkets = getAccountPoolMarkets(_params.targetAccountId, targetAccount);
        require(
            _contains(poolMarkets, _params.liquidateMarket), "OmniPool::liquidate: LiquidateMarket not in pool markets."
        );
        require(
            _contains(poolMarkets, _params.collateralMarket)
                || targetAccount.isolatedCollateralMarket == _params.collateralMarket,
            "OmniPool::liquidate: CollateralMarket not available to seize."
        );
        Evaluation memory evalBefore = _evaluateAccountInternal(_params.targetAccountId, poolMarkets, targetAccount);
        require(evalBefore.numBorrow > 0, "OmniPool::liquidate: No borrow to liquidate.");
        require(
            (evalBefore.depositAdjValue < evalBefore.borrowAdjValue)
                || marketConfigurations[_params.collateralMarket].expirationTimestamp <= block.timestamp,
            "OmniPool::liquidate: Account still healthy."
        );
        uint8 borrowTier = getAccountBorrowTier(targetAccount);
        uint256 amount =
            IOmniToken(_params.liquidateMarket).repay(_params.targetAccountId, msg.sender, borrowTier, _params.amount);
        (uint256 liquidationBonus, uint256 softThreshold) = getLiquidationBonusAndThreshold(
            evalBefore.depositAdjValue, evalBefore.borrowAdjValue, _params.collateralMarket
        );
        {
            // Avoid stack too deep
            uint256 borrowPrice = IOmniOracle(oracle).getPrice(IWithUnderlying(_params.liquidateMarket).underlying());
            uint256 depositPrice = IOmniOracle(oracle).getPrice(IWithUnderlying(_params.collateralMarket).underlying());
            uint256 seizeAmount = Math.ceilDiv(
                Math.ceilDiv(amount * borrowPrice, depositPrice) * (LIQ_BONUS_PRECISION_SCALE + liquidationBonus), // Need to add base since liquidationBonus < LIQ_BONUS_PRECISION_SCALE
                LIQ_BONUS_PRECISION_SCALE
            ); // round up
            seizedShares = IOmniTokenBase(_params.collateralMarket).seize(
                _params.targetAccountId, _params.liquidatorAccountId, seizeAmount
            );
        }
        Evaluation memory evalAfter = _evaluateAccountInternal(_params.targetAccountId, poolMarkets, targetAccount);
        if (evalAfter.borrowTrueValue > evalAfter.depositTrueValue) {
            pauseTranche = borrowTier > pauseTranche ? pauseTranche : borrowTier;
            emit PausedTranche(pauseTranche);
        } else if (!evalAfter.isExpired) {
            // If expired, no liquidation threshold
            require(
                checkSoftLiquidation(evalAfter.depositAdjValue, evalAfter.borrowAdjValue, softThreshold, targetAccount),
                "OmniPool::liquidate: Too much has been liquidated."
            );
        }
        emit Liquidated(
            msg.sender,
            _params.targetAccountId,
            _params.liquidatorAccountId,
            _params.liquidateMarket,
            _params.collateralMarket,
            amount
        );
    }

    /**
     * @notice Checks whether a soft liquidation condition is met based on the account's adjusted deposit and borrow values.
     * @param _depositAdjValue The adjusted value of the account's deposits.
     * @param _borrowAdjValue The adjusted value of the account's borrows.
     * @param _softThreshold The threshold value for soft liquidation.
     * @param _account The AccountInfo struct containing the account's mode, isolated collateral market, and other relevant data.
     * @return A boolean indicating whether a soft liquidation condition is met.
     */
    function checkSoftLiquidation(
        uint256 _depositAdjValue,
        uint256 _borrowAdjValue,
        uint256 _softThreshold,
        AccountInfo memory _account
    ) public pure returns (bool) {
        if (_borrowAdjValue == 0) {
            return false;
        }
        uint256 healthFactor = (_depositAdjValue * HEALTH_FACTOR_SCALE) / _borrowAdjValue; // Round down
        uint256 threshold = _account.softThreshold != 0 ? _account.softThreshold : _softThreshold;
        return healthFactor <= threshold;
    }

    /**
     * @notice Initiates the process of socializing a fully liquidated account's remaining loss to the users of the specified market and tranche, discretion to admin.
     * @dev There is a separate call that must be made to unpause the tranches, discretion to admin. Due to potential problems w/ a full liquidation
     * allow for 0.1bps ($10 for $1M) difference in deposit and borrow values. However, it is expected that admin calls liquidate prior to calling socializeLoss in script.
     * @param _market The address of the market in which the loss is socialized.
     * @param _account The unique identifier of the fully liquidated account.
     */
    function socializeLoss(address _market, bytes32 _account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint8 borrowTier = getAccountBorrowTier(accountInfos[_account]);
        Evaluation memory eval = evaluateAccount(_account);
        uint256 percentDiff = eval.depositTrueValue * 1e18 / eval.borrowTrueValue;
        require(
            percentDiff < 0.00001e18,
            "OmniPool::socializeLoss: Account not fully liquidated, please call liquidate prior to fully liquidate account."
        );
        IOmniToken(_market).socializeLoss(_account, borrowTier);
        emit SocializedLoss(_market, borrowTier, _account);
    }

    /**
     * @notice Determines the risk tier associated with an subaccount's borrow activity. The tier is derived from the subaccount's isolated collateral market.
     * @param _account The AccountInfo struct containing the subaccount's mode, isolated collateral market, and other relevant data.
     * @return The risk tier associated with the subaccount's borrow activity.
     */
    function getAccountBorrowTier(AccountInfo memory _account) public view returns (uint8) {
        address isolatedCollateralMarket = _account.isolatedCollateralMarket;
        if (_account.modeId == 0) {
            if (isolatedCollateralMarket == address(0)) {
                // Account has no isolated collateral market. Use tier 0 (lowest risk).
                return 0;
            } else {
                // Account has isolated collateral market. Use the market's risk tranche.
                return marketConfigurations[isolatedCollateralMarket].riskTranche;
            }
        } else {
            // Account is in a mode. Use the mode's risk tranche.
            return modeConfigurations[_account.modeId].modeTranche;
        }
    }

    /**
     * @notice Retrieves all markets, except for the isolated collateral market, associated with an subaccount.
     * @param _accountId The unique identifier of the subaccount whose markets are to be retrieved.
     * @param _account The AccountInfo struct containing the subaccount's mode, isolated collateral market, and other relevant data.
     * @return An array of addresses representing the markets associated with the subaccount.
     */
    function getAccountPoolMarkets(bytes32 _accountId, AccountInfo memory _account)
        public
        view
        returns (address[] memory)
    {
        if (_account.modeId == 0) {
            // Account is not in a mode. Use the account's markets.
            return accountMarkets[_accountId];
        } else {
            // Account is in a mode. Use the mode's markets.
            assert(_account.modeId <= modeCount);
            return modeConfigurations[_account.modeId].markets;
        }
    }

    /**
     * @notice Computes the liquidation bonus and soft threshold values based on the account's adjusted deposit and borrow values and the specified collateral market.
     * @param _depositAdjValue The adjusted value of the account's deposits.
     * @param _borrowAdjValue The adjusted value of the account's borrows.
     * @param _collateralMarket The address of the collateral market.
     * @return bonus The computed liquidation bonus value.
     * @return softThreshold The computed soft threshold value.
     */
    function getLiquidationBonusAndThreshold(
        uint256 _depositAdjValue,
        uint256 _borrowAdjValue,
        address _collateralMarket
    ) public view returns (uint256 bonus, uint256 softThreshold) {
        if (_borrowAdjValue > _depositAdjValue) {
            // Prioritize unhealthiness over expiry in case where is expired and unhealthy is true
            LiquidationBonusConfiguration memory liquidationBonusConfiguration_ =
                liquidationBonusConfigurations[_collateralMarket];
            softThreshold = liquidationBonusConfiguration_.softThreshold;
            uint256 pctDiff =
                Math.ceilDiv(_borrowAdjValue * LIQ_BONUS_PRECISION_SCALE, _depositAdjValue) - LIQ_BONUS_PRECISION_SCALE; // Round up
            if (pctDiff <= liquidationBonusConfiguration_.kink) {
                bonus = liquidationBonusConfiguration_.start;
                bonus += Math.ceilDiv(
                    pctDiff * (liquidationBonusConfiguration_.end - liquidationBonusConfiguration_.start),
                    liquidationBonusConfiguration_.kink
                );
            } else {
                bonus = liquidationBonusConfiguration_.end;
            }
        } else if (marketConfigurations[_collateralMarket].expirationTimestamp <= block.timestamp) {
            LiquidationBonusConfiguration memory liquidationBonusConfiguration_ =
                liquidationBonusConfigurations[_collateralMarket];
            softThreshold = liquidationBonusConfiguration_.softThreshold;
            bonus = liquidationBonusConfiguration_.expiredBonus;
        } else {
            revert("OmniPool::getLiquidationBonus: No liquidation bonus, account is not liquidatable ");
        }
    }

    /**
     * @notice Determines if an account is healthy by comparing the factor adjusted price weighted values of deposits and borrows.
     * @dev The function evaluates the account and returns true if the account is healthy. Intentionally do not check expiration here.
     * @param _accountId The account identifier.
     * @return A boolean indicating whether the account is healthy.
     */
    function isAccountHealthy(bytes32 _accountId) external returns (bool) {
        Evaluation memory eval = evaluateAccount(_accountId);
        return eval.depositAdjValue >= eval.borrowAdjValue && !eval.isExpired;
    }

    /**
     * @notice Resets the pause tranche to its default value. This function should only be called after all bad debt is resolved.
     * Must be called by an account with the DEFAULT_ADMIN_ROLE.
     */
    function resetPauseTranche() public onlyRole(DEFAULT_ADMIN_ROLE) {
        pauseTranche = type(uint8).max;
        emit UnpausedTranche();
    }

    /**
     * @notice Configures a market with specific parameters. This function can only be called by an account with the MARKET_CONFIGURATOR_ROLE.
     * It validates the configuration provided especially focusing on isolated collateral settings, borrow factors and risk tranches.
     * Should never configure a IOmniTokenNoBorrow (non-borrwable) token with a borrowFactor > 0 and not as isolated, otherwise will break.
     * @dev Setting markets to the 0 riskTranche comes with special privileges and should be used carefully after strict risk analysis.
     * @param _market The address of the market to be configured.
     * @param _marketConfig The MarketConfiguration struct containing the market's configurations.
     */
    function setMarketConfiguration(address _market, MarketConfiguration calldata _marketConfig)
        external
        onlyRole(MARKET_CONFIGURATOR_ROLE)
    {
        // Set to block.timestamp value to have the market expire in that block for emergencies
        if (_marketConfig.expirationTimestamp <= block.timestamp) {
            revert("OmniPool::setMarketConfiguration: Bad expiration timestamp.");
        }
        if (_marketConfig.isIsolatedCollateral && (_marketConfig.borrowFactor > 0 || _marketConfig.riskTranche == 0)) {
            revert("OmniPool::setMarketConfiguration: Bad configuration for isolated collateral.");
        }
        if (
            _marketConfig.collateralFactor == 0
                && (_marketConfig.borrowFactor == 0 || _marketConfig.riskTranche != type(uint8).max)
        ) {
            revert("OmniPool::setMarketConfiguration: Invalid configuration for borrowable long tail asset.");
        }
        MarketConfiguration memory currentConfig = marketConfigurations[_market];
        if (currentConfig.collateralFactor != 0) {
            require(
                _marketConfig.isIsolatedCollateral == currentConfig.isIsolatedCollateral,
                "OmniPool::setMarketConfiguration: Cannot change isolated collateral status."
            );
        }
        marketConfigurations[_market] = _marketConfig;
        emit SetMarketConfiguration(_market, _marketConfig);
    }

    /**
     * @notice Removes the market configuration for a specified market.
     * @dev This function can only be called by an account with the `MARKET_CONFIGURATOR_ROLE` role.
     * It checks if the market's underlying asset balance is zero before allowing removal.
     * @param _market The address of the market whose configuration is to be removed.
     */
    function removeMarketConfiguration(address _market) external onlyRole(MARKET_CONFIGURATOR_ROLE) {
        require(
            IERC20(IWithUnderlying(_market).underlying()).balanceOf(_market) == 0,
            "OmniPool::removeMarketConfiguration: Market still has balance."
        );
        delete marketConfigurations[_market];
        emit RemovedMarketConfiguration(_market);
    }

    /**
     * @notice Sets the configurations for a mode. This function can only be called by an account with the MARKET_CONFIGURATOR_ROLE.
     * Each mode configuration overrides all borrow and collateral factors for markets within that mode and should be used cautiously.
     * @dev This is a privileged function that should be used carefully after strict risk analysis, as it overrides factors for all markets in the mode.
     * Modes should never include markets that are considered isolated assets.
     * @param _modeConfiguration A ModeConfiguration struct containing the configuration for the mode.
     */
    function setModeConfiguration(ModeConfiguration calldata _modeConfiguration)
        external
        onlyRole(MARKET_CONFIGURATOR_ROLE)
    {
        if (_modeConfiguration.expirationTimestamp <= block.timestamp) {
            revert("OmniPool::setModeConfiguration: Bad expiration timestamp.");
        }
        for (uint256 i = 0; i < _modeConfiguration.markets.length; ++i) {
            for (uint256 j = i + 1; j < _modeConfiguration.markets.length; j++) {
                if (_modeConfiguration.markets[i] == _modeConfiguration.markets[j]) {
                    revert("OmniPool:setModeConfiguration: No duplicate markets allowed.");
                }
            }
        }
        modeCount++;
        modeConfigurations[modeCount] = _modeConfiguration;
        emit SetModeConfiguration(modeCount, _modeConfiguration);
    }

    /**
     * @notice Sets the expiration timestamp for a specified mode. This expiration only signifies the mode can no longer be entered, but does not force exit exisitng subaccounts from the mode.
     * This function allows for updating the expiration timestamp of a specific mode, given its mode ID.
     * It reverts if the provided expiration timestamp is in the past or if the mode ID is invalid.
     * Only an account with the MARKET_CONFIGURATOR_ROLE can call this function.
     * @param _modeId The ID of the mode whose expiration timestamp is to be updated.
     * @param _expirationTimestamp The new expiration timestamp for the mode.
     */
    function setModeExpiration(uint256 _modeId, uint32 _expirationTimestamp)
        external
        onlyRole(MARKET_CONFIGURATOR_ROLE)
    {
        require(_expirationTimestamp > block.timestamp, "OmniPool::setModeExpiration: Bad expiration timestamp.");
        require(_modeId != 0 && _modeId <= modeCount, "OmniPool::setModeExpiration: Bad mode ID.");
        modeConfigurations[_modeId].expirationTimestamp = _expirationTimestamp;
    }

    /**
     * @notice Sets a specific soft liquidation threshold for an account. This function can only be called by an account with the SOFT_LIQUIDATION_ROLE.
     * The soft liquidation threshold determines the health factor below which an account is considered for soft liquidation.
     * @dev The soft liquidation role should only be assigned to the admin or a smart contract that implements a strategy for why a user should receive a special soft liquidation.
     * @param _accountId The unique identifier of the account for which to set the soft liquidation threshold.
     * @param _softThreshold The soft liquidation threshold to set for the account.
     */
    function setAccountSoftLiquidation(bytes32 _accountId, uint32 _softThreshold)
        external
        onlyRole(SOFT_LIQUIDATION_ROLE)
    {
        if (_softThreshold > MAX_BASE_SOFT_LIQUIDATION || _softThreshold < HEALTH_FACTOR_SCALE) {
            revert(
                "OmniPool::setSoftLiquidation: Soft liquidation health factor threshold cannot be greater than the standard max and must be greater than 1."
            );
        }
        accountInfos[_accountId].softThreshold = _softThreshold;
    }

    /**
     * @notice Sets the configuration for liquidation bonuses for a specific market. This function can only be called by an account with the MARKET_CONFIGURATOR_ROLE.
     * The configuration includes parameters that affect the calculation of liquidation bonuses during the liquidation process.
     * @param _market The address of the market for which to set the liquidation bonus configuration.
     * @param _config The LiquidationBonusConfiguration struct containing the configuration for liquidation bonuses.
     */
    function setLiquidationBonusConfiguration(address _market, LiquidationBonusConfiguration calldata _config)
        external
        onlyRole(MARKET_CONFIGURATOR_ROLE)
    {
        require(
            _config.kink <= MAX_LIQ_KINK,
            "OmniPool::setLiquidationBonusConfiguration: Bad kink for maximum liquidation."
        );
        require(
            _config.start <= _config.end && _config.end <= LIQ_BONUS_PRECISION_SCALE,
            "OmniPool::setLiquidationBonusConfiguration: Bad start and end bonus values."
        );
        if (_config.expiredBonus > LIQ_BONUS_PRECISION_SCALE) {
            revert("OmniPool::setLiquidationBonusConfiguration: Bad expired bonus value.");
        }
        if (_config.softThreshold > MAX_BASE_SOFT_LIQUIDATION || _config.softThreshold < HEALTH_FACTOR_SCALE) {
            revert(
                "OmniPool::setSoftLiquidation: Soft liquidation health factor threshold cannot be greater than the standard max and must be greater than 1."
            );
        }
        liquidationBonusConfigurations[_market] = _config;
    }

    /**
     * @notice Sets the tranche count for a specific market.
     * @dev This function allows to set the number of tranches for a given market.
     * It's an external function that can only be called by an account with the `MARKET_CONFIGURATOR_ROLE`.
     * @param _market The address of the market contract.
     * @param _trancheCount The number of tranches to be set for the market.
     */
    function setTrancheCount(address _market, uint8 _trancheCount) external onlyRole(MARKET_CONFIGURATOR_ROLE) {
        IOmniToken(_market).setTrancheCount(_trancheCount);
    }

    /**
     * @notice Sets the borrow cap for each tranche of a specific market.
     * @dev This function can only be called by an account with the MARKET_CONFIGURATOR_ROLE.
     * It invokes the setTrancheBorrowCaps function of the IOmniToken contract associated with the specified market.
     * @param _market The address of the market for which to set the borrow caps.
     * @param _borrowCaps An array of borrow cap values, one for each tranche of the market.
     */
    function setBorrowCap(address _market, uint256[] calldata _borrowCaps)
        external
        onlyRole(MARKET_CONFIGURATOR_ROLE)
    {
        for (uint256 i = 0; i < _borrowCaps.length - 1; ++i) {
            require(_borrowCaps[i] >= _borrowCaps[i + 1], "OmniPool::setBorrowCap: Invalid borrow cap.");
        }
        IOmniToken(_market).setTrancheBorrowCaps(_borrowCaps);
    }

    /**
     * @notice Sets the supply cap for a market that doesn't allow borrowing.
     * @dev This function can only be called by an account with the MARKET_CONFIGURATOR_ROLE.
     * It invokes the setSupplyCap function of the IOmniTokenNoBorrow contract associated with the specified market.
     * @param _market The address of the market for which to set the no-borrow supply cap.
     * @param _noBorrowSupplyCap The value of the no-borrow supply cap to set.
     */
    function setNoBorrowSupplyCap(address _market, uint256 _noBorrowSupplyCap)
        external
        onlyRole(MARKET_CONFIGURATOR_ROLE)
    {
        IOmniTokenNoBorrow(_market).setSupplyCap(_noBorrowSupplyCap);
    }

    /**
     * @notice Sets the reserve receiver's address. This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * @dev The reserve receiver's address is converted to a bytes32 account identifier using the toAccount function with a subId of 0.
     * @param _reserveReceiver The address of the reserve receiver to be set.
     */
    function setReserveReceiver(address _reserveReceiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        reserveReceiver = _reserveReceiver.toAccount(0);
    }

    /**
     * @notice Pauses the protocol, halting certain functionalities, i.e. withdraw, borrow, repay, liquidate.
     * @dev This function triggers the `_pause()` internal function and sets `pauseTranche` to 0.
     * It's an external function that can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * The function can only be executed when the contract is not already paused,
     * which is checked by the `whenNotPaused` modifier.
     */
    function pause() external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
        pauseTranche = 0;
        emit PausedTranche(0);
    }

    /**
     * @notice Unpauses the protocol, re-enabling certain functionalities, i.e. withdraw, borrow, repay, liquidate.
     * @dev This function triggers the `_unpause()` internal function and calls `resetPauseTranche()` to reset tranche pause state.
     * It's an external function that can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * The function can only be executed when the contract is paused,
     * which is checked by the `whenPaused` modifier.
     */
    function unpause() external whenPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
        resetPauseTranche();
    }

    /**
     * @dev Internal utility function to check if a specific value exists within an array of addresses.
     * @param _arr The array of addresses to search.
     * @param _value The address value to look for within the array.
     * @return A boolean indicating whether the value exists within the array.
     */
    function _contains(address[] memory _arr, address _value) internal pure returns (bool) {
        for (uint256 i = 0; i < _arr.length; ++i) {
            if (_arr[i] == _value) {
                return true;
            }
        }
        return false;
    }
}
