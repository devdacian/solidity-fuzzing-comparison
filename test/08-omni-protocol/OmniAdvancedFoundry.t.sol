// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../src/MockERC20.sol";
import "./MockOracle.sol";
import "../../src/08-omni-protocol/IRM.sol";
import "../../src/08-omni-protocol/OmniPool.sol";
import "../../src/08-omni-protocol/OmniToken.sol";
import "../../src/08-omni-protocol/OmniTokenNoBorrow.sol";
import "../../src/08-omni-protocol/interfaces/IOmniToken.sol";
import "../../src/08-omni-protocol/interfaces/IOmniPool.sol";
import "../../src/08-omni-protocol/SubAccount.sol";

import "forge-std/Test.sol";

//
// Foundry Fuzzer Info:
//
// run from base project directory with:
// forge test --match-contract OmniAdvancedFoundry
//
// get coverage report (see https://medium.com/@rohanzarathustra/forge-coverage-overview-744d967e112f):
// 1) forge coverage --report lcov --report-file test/08-omni-protocol/coverage-foundry-advanced.lcov --match-contract OmniAdvancedFoundry
// 2) genhtml test/08-omni-protocol/coverage-foundry-advanced.lcov -o test/08-omni-protocol/coverage-foundry-advanced
// 3) open test/08-omni-protocol/coverage-foundry-advanced/index.html in your browser and
//    navigate to the relevant source file to see line-by-line execution records
//
// Foundry is unable to break any invariants even when Foundry.toml
// is configured with "runs = 40000" which takes ~5min to run.
//
// In contrast Echidna can sometimes break 1 invariant within 5 minutes and
// Medusa can almost always break 2 invariants within 2 minutes, often
// much faster.
//
contract OmniAdvancedFoundry is Test {
    using SubAccount for address;

    // make these constant to match Echidna & Medusa configs, left same for Foundry
    address public constant ALICE = address(0x1000000000000000000000000000000000000000);
    address public constant BOB   = address(0x2000000000000000000000000000000000000000);

    // used for input restriction during fuzzing
    uint8  public constant MAX_TRANCH_ID  = 1; // only 2 tranches
    uint8  public constant MIN_MODE_ID    = 1;
    uint8  public constant MAX_MODE_ID    = 2;
    uint96 public constant MAX_SUB_ID     = 2;

    // used for price oracle
    uint8  public constant PRICES_COUNT   = 3;
    // maximum price move % each time for Oracle assets
    uint8  public constant MIN_PRICE_MOVE = 2;
    uint8  public constant MAX_PRICE_MOVE = 10;

    // misc constants
    uint256 public constant USER_TOKENS   = 1_000_000; // multiplied by token decimals
    uint256 public constant BORROW_CAP    = 1_000_000; // multiplied by token decimals

    OmniPool pool;
    OmniToken oToken;
    OmniToken oToken2;
    OmniTokenNoBorrow oToken3;
    OmniTokenNoBorrow oToken4;

    IRM irm;
    MockERC20 uToken;
    MockERC20 uToken2;
    MockERC20 uToken3;
    MockOracle oracle;

    // used to update oracle prices
    address[] underlyings = new address[](PRICES_COUNT);
    uint256[] prices      = new uint256[](PRICES_COUNT);

    // ghost variables used to verify invariants
    struct SubAccountGhost {
        uint8 numEnteredIsolatedMarkets;
        uint8 numEnteredMarkets;
        uint8 numEnteredModes;
        bool  enteredIsolatedMarketWithActiveBorrows;
        bool  exitedMarketOrModeWithActiveBorrows;
        bool  enteredModeWithEnteredMarkets;
        bool  enteredExpiredMarketOrMode;
        bool  depositReceivedZeroShares;
        bool  depositReceivedIncorrectAmount;
        bool  withdrawReceivedIncorrectAmount;
        bool  withdrawDecreasedZeroShares;
        bool  repayDidntDecreaseBorrowShares;
        bool  repayIncorrectBorrowAmountDecrease;
        bool  borrowIncorrectBorrowAmountIncrease;
        bool  borrowDidntIncreaseBorrowShares;
    }

    mapping(bytes32 accountId => SubAccountGhost) ghost_subAccount;

    // changed from constructor() to setUp() for Foundry
    function setUp() public {
        // Init contracts
        oracle = new MockOracle();
        irm = new IRM();
        irm.initialize(address(this));
        pool = new OmniPool();
        pool.initialize(address(oracle), address(this), address(this));
        uToken = new MockERC20('USD Coin', 'USDC');
        uToken2 = new MockERC20('Wrapped Ethereum', 'WETH');
        uToken3 = new MockERC20('Shiba Inu', 'SHIB');

        // Initial Oracle configs
        underlyings[0] = address(uToken);
        prices[0]      = 1e18; // USDC

        underlyings[1] = address(uToken2);
        prices[1]      = 2000e18; // WETH

        underlyings[2] = address(uToken3);
        prices[2]      = 0.00001e18; // SHIB
        
        oracle.setPrices(underlyings, prices);

        // Configs for oTokens
        IIRM.IRMConfig[] memory configs = new IIRM.IRMConfig[](MAX_TRANCH_ID+1);
        configs[0] = IIRM.IRMConfig(0.9e9, 0.01e9, 0.035e9, 0.635e9);
        configs[1] = IIRM.IRMConfig(0.8e9, 0.03e9, 0.1e9, 1.2e9);
        IIRM.IRMConfig[] memory configs2 = new IIRM.IRMConfig[](MAX_TRANCH_ID+1);
        configs2[0] = IIRM.IRMConfig(0.85e9, 0.02e9, 0.055e9, 0.825e9);
        configs2[1] = IIRM.IRMConfig(0.75e9, 0.04e9, 0.12e9, 1.2e9);
        uint8[] memory tranches = new uint8[](MAX_TRANCH_ID+1);
        tranches[0] = 0;
        tranches[1] = 1;
        uint256[] memory borrowCaps = new uint256[](MAX_TRANCH_ID+1);
        borrowCaps[0] = BORROW_CAP * (10 ** uToken.decimals());
        borrowCaps[1] = BORROW_CAP * (10 ** uToken.decimals());

        // Init oTokens
        oToken = new OmniToken();
        oToken.initialize(address(pool), address(uToken), address(irm), borrowCaps);
        oToken2 = new OmniToken();
        oToken2.initialize(address(pool), address(uToken2), address(irm), borrowCaps);
        oToken3 = new OmniTokenNoBorrow();
        oToken3.initialize(address(pool), address(uToken3), borrowCaps[0]);
        oToken4 = new OmniTokenNoBorrow();
        oToken4.initialize(address(pool), address(uToken3), borrowCaps[0]);
        irm.setIRMForMarket(address(oToken), tranches, configs);
        irm.setIRMForMarket(address(oToken2), tranches, configs2);

        // Set MarketConfigs for Pool
        // expiration times made lower to trigger more liquidations
        IOmniPool.MarketConfiguration memory mConfig1 =
            IOmniPool.MarketConfiguration(0.9e9, 0.9e9, uint32(block.timestamp + 100 days), 0, false);
        IOmniPool.MarketConfiguration memory mConfig2 =
            IOmniPool.MarketConfiguration(0.8e9, 0.8e9, uint32(block.timestamp + 100 days), 0, false);
        IOmniPool.MarketConfiguration memory mConfig3 =
            IOmniPool.MarketConfiguration(0.4e9, 0, uint32(block.timestamp + 5 days), 1, true);
        IOmniPool.MarketConfiguration memory mConfig4 =
            IOmniPool.MarketConfiguration(0.4e9, 0, uint32(block.timestamp + 2 days), 1, true);
        pool.setMarketConfiguration(address(oToken), mConfig1);
        pool.setMarketConfiguration(address(oToken2), mConfig2);
        pool.setMarketConfiguration(address(oToken3), mConfig3);
        pool.setMarketConfiguration(address(oToken4), mConfig4);

        // Set ModeConfigs for Pool
        address[] memory modeMarkets = new address[](2);
        modeMarkets[0] = address(oToken);
        modeMarkets[1] = address(oToken2);
        IOmniPool.ModeConfiguration memory modeStableMode =
            IOmniPool.ModeConfiguration(0.95e9, 0.95e9, 0, uint32(block.timestamp + 7 days), modeMarkets);
        pool.setModeConfiguration(modeStableMode);
        pool.setModeConfiguration(modeStableMode);

        // mint user tokens
        uToken.mint(address(ALICE), USER_TOKENS * (10 ** uToken.decimals()));
        uToken.mint(address(BOB), USER_TOKENS * (10 ** uToken.decimals()));
        uToken2.mint(address(ALICE), USER_TOKENS * (10 ** uToken2.decimals()));
        uToken2.mint(address(BOB), USER_TOKENS * (10 ** uToken2.decimals()));
        uToken3.mint(address(ALICE), USER_TOKENS * (10 ** uToken3.decimals()));
        uToken3.mint(address(BOB), USER_TOKENS * (10 ** uToken3.decimals()));

        // setup user token approvals
        vm.startPrank(ALICE);
        uToken.approve(address(oToken), type(uint256).max);
        uToken2.approve(address(oToken2), type(uint256).max);
        uToken3.approve(address(oToken3), type(uint256).max);
        uToken3.approve(address(oToken4), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(BOB);
        uToken.approve(address(oToken), type(uint256).max);
        uToken2.approve(address(oToken2), type(uint256).max);
        uToken3.approve(address(oToken3), type(uint256).max);
        uToken3.approve(address(oToken4), type(uint256).max);
        vm.stopPrank();

        // foundry-specific sender setup
        targetSender(ALICE);
        targetSender(BOB);

        // foundry-specific fuzz targeting
        targetContract(address(this));

        bytes4[] memory selectors = new bytes4[](13);
        selectors[0]  = this.enterIsolatedMarket.selector;
        selectors[1]  = this.enterMarkets.selector;
        selectors[2]  = this.exitMarket.selector;
        selectors[3]  = this.clearMarkets.selector;
        selectors[4]  = this.enterMode.selector;
        selectors[5]  = this.exitMode.selector;
        selectors[6]  = this.borrow.selector;
        selectors[7]  = this.repay.selector;
        selectors[8]  = this.liquidate.selector;
        selectors[9]  = this.deposit.selector;
        selectors[10] = this.withdraw.selector;
        selectors[11] = this.transfer.selector;
        selectors[12] = this.updateOraclePrice.selector;
        
        targetSelector(FuzzSelector({
            addr: address(this),
            selectors: selectors
        }));
    }

    /* DEFINE INVARIANTS HERE */
    //
    // changed invariants to use assertions for Foundry
    //
    // INVARIANT 1) tranche should never reach a state where:
    // `tranche.totalBorrowShare > 0 && tranche.totalBorrowAmount == 0` or
    // `tranche.totalDepositShare > 0 && tranche.totalDepositAmount == 0`
    //
    // if these states are reached borrows/deposits in that tranche will permanently
    // be bricked. Either both == 0 or both > 0
    function _getTranchBorrowDepositShareIntegrity(address _token, uint8 _tranche) private view returns(bool) {
        OmniToken.OmniTokenTranche memory trancheData = _getOmniTokenTranche(_token, _tranche);
        
        return ((trancheData.totalBorrowShare  == 0 && trancheData.totalBorrowAmount  == 0) ||
                (trancheData.totalBorrowShare  >  0 && trancheData.totalBorrowAmount  >  0)) &&
               ((trancheData.totalDepositShare == 0 && trancheData.totalDepositAmount == 0) ||
                (trancheData.totalDepositShare >  0 && trancheData.totalDepositAmount >  0));
    }
    function invariant_tranche_borrow_deposit_shares_integrity() public view {
        assert(_getTranchBorrowDepositShareIntegrity(address(oToken),  0) &&
               _getTranchBorrowDepositShareIntegrity(address(oToken),  1) &&
               _getTranchBorrowDepositShareIntegrity(address(oToken2), 0) &&
               _getTranchBorrowDepositShareIntegrity(address(oToken2), 1));
    }

    // INVARIANT 2) each subaccount may only enter max 1 isolated market at the same time
    function _inMoreThanOneIsolatedMarket(address account) private view returns(bool) {
        for(uint96 subId; subId<=MAX_SUB_ID; ++subId) {
            bytes32 accountId = account.toAccount(subId);

            if(ghost_subAccount[accountId].numEnteredIsolatedMarkets >= 2) return true;
        }

        return false;
    }
    function invariant_subaccount_one_isolated_market() public view {
        assert(!_inMoreThanOneIsolatedMarket(ALICE) &&
               !_inMoreThanOneIsolatedMarket(BOB));
    }


    // INVARIANT 3) each subaccount many only enter max 1 mode at the same time
    function _inMoreThanOneMode(address account) private view returns(bool) {
        for(uint96 subId; subId<=MAX_SUB_ID; ++subId) {
            bytes32 accountId = account.toAccount(subId);

            if(ghost_subAccount[accountId].numEnteredModes >= 2) return true;
        }

        return false;
    }
    function invariant_subaccount_one_mode() public view {
        assert(!_inMoreThanOneMode(ALICE) &&
               !_inMoreThanOneMode(BOB));
    }


    // INVARIANT 4) subaccount can't enter isolated collateral market with active borrows
    function _hasEnteredIsolatedMarketWithActiveBorrows(address account) private view returns(bool) {
        for(uint96 subId; subId<=MAX_SUB_ID; ++subId) {
            bytes32 accountId = account.toAccount(subId);

            if(ghost_subAccount[accountId].enteredIsolatedMarketWithActiveBorrows) return true;
        }

        return false;
    }
    function invariant_cant_enter_isolated_market_with_active_borrows() public view {
        assert(!_hasEnteredIsolatedMarketWithActiveBorrows(ALICE) &&
               !_hasEnteredIsolatedMarketWithActiveBorrows(BOB));
    }


    // INVARIANT 5) subaccount can't exit market or mode with active borrows
    function _hasExitedMarketOrModeWithActiveBorrows(address account) private view returns(bool) {
        for(uint96 subId; subId<=MAX_SUB_ID; ++subId) {
            bytes32 accountId = account.toAccount(subId);

            if(ghost_subAccount[accountId].exitedMarketOrModeWithActiveBorrows) return true;
        }

        return false;
    }
    function invariant_cant_exit_market_or_mode_with_active_borrows() public view {
        assert(!_hasExitedMarketOrModeWithActiveBorrows(ALICE) &&
               !_hasExitedMarketOrModeWithActiveBorrows(BOB));
    }


    // INVARIANT 6) subaccount can't enter a mode when it has already entered a market
    function _hasEnteredModeWithEnteredMarkets(address account) private view returns(bool) {
        for(uint96 subId; subId<=MAX_SUB_ID; ++subId) {
            bytes32 accountId = account.toAccount(subId);

            if(ghost_subAccount[accountId].enteredModeWithEnteredMarkets) return true;
        }

        return false;
    }
    function invariant_cant_enter_mode_with_entered_markets() public view {
        assert(!_hasEnteredModeWithEnteredMarkets(ALICE) &&
               !_hasEnteredModeWithEnteredMarkets(BOB));
    }


    // INVARIANT 7) subaccount can't enter an expired market or mode
    function _hasEnteredExpiredMarketOrMode(address account) private view returns(bool) {
        for(uint96 subId; subId<=MAX_SUB_ID; ++subId) {
            bytes32 accountId = account.toAccount(subId);

            if(ghost_subAccount[accountId].enteredExpiredMarketOrMode) return true;
        }

        return false;
    }
    function invariant_cant_enter_expired_market_or_mode() public view {
        assert(!_hasEnteredExpiredMarketOrMode(ALICE) &&
               !_hasEnteredExpiredMarketOrMode(BOB));
    }

    
    // INVARIANT 8) subaccount must have entered market/mode to take a loan
    function _hasLoanWithoutEnteringMarketOrMode(address account) private view returns(bool) {
        for(uint96 subId; subId<=MAX_SUB_ID; ++subId) {
            bytes32 accountId = account.toAccount(subId);

            if(_hasActiveBorrows(accountId) && 
               ghost_subAccount[accountId].numEnteredModes   == 0 &&
               ghost_subAccount[accountId].numEnteredMarkets == 0) return true;
        }

        return false;
    }
    function invariant_cant_borrow_without_entering_market_or_mode() public view {
        assert(!_hasLoanWithoutEnteringMarketOrMode(ALICE) &&
               !_hasLoanWithoutEnteringMarketOrMode(BOB));
    }

    
    // INVARIANT 9) subaccount should receive shares when making a deposit
    // Medusa is able to break this invariant when the fuzzer does small deposits 
    // due to a rounding-down-to-zero precision loss at:
    // https://github.com/beta-finance/Omni-Protocol/blob/main/src/OmniToken.sol#L172
    // Foundry is unable to break it
    function _hasDepositWhichReceivedZeroShares(address account) private view returns(bool) {
        for(uint96 subId; subId<=MAX_SUB_ID; ++subId) {
            bytes32 accountId = account.toAccount(subId);

            if(ghost_subAccount[accountId].depositReceivedZeroShares) return true;
        }

        return false;
    }
    function invariant_deposit_receives_shares() public view {
        assert(!_hasDepositWhichReceivedZeroShares(ALICE) &&
               !_hasDepositWhichReceivedZeroShares(BOB));
    }


    // INVARIANT 10) subaccount should receive amount when making a deposit
    function _hasDepositWhichReceivedIncorrectAmount(address account) private view returns(bool) {
        for(uint96 subId; subId<=MAX_SUB_ID; ++subId) {
            bytes32 accountId = account.toAccount(subId);

            if(ghost_subAccount[accountId].depositReceivedIncorrectAmount) return true;
        }

        return false;
    }
    function invariant_deposit_receives_correct_amount() public view {
        assert(!_hasDepositWhichReceivedIncorrectAmount(ALICE) &&
               !_hasDepositWhichReceivedIncorrectAmount(BOB));
    }


    // INVARIANT 11) subaccount should have shares decreased when withdrawing
    function _hasWithdrawWhichDecreasedZeroShares(address account) private view returns(bool) {
        for(uint96 subId; subId<=MAX_SUB_ID; ++subId) {
            bytes32 accountId = account.toAccount(subId);

            if(ghost_subAccount[accountId].withdrawDecreasedZeroShares) return true;
        }

        return false;
    }
    function invariant_withdraw_decreases_shares() public view {
        assert(!_hasWithdrawWhichDecreasedZeroShares(ALICE) &&
               !_hasWithdrawWhichDecreasedZeroShares(BOB));
    }
    

    // INVARIANT 12) subaccount should receive correct amount when withdrawing
    function _hasWithdrawWhichReceivedIncorrectAmount(address account) private view returns(bool) {
        for(uint96 subId; subId<=MAX_SUB_ID; ++subId) {
            bytes32 accountId = account.toAccount(subId);

            if(ghost_subAccount[accountId].withdrawReceivedIncorrectAmount) return true;
        }

        return false;
    }
    function invariant_withdraw_receives_correct_amount() public view {
        assert(!_hasWithdrawWhichReceivedIncorrectAmount(ALICE) &&
               !_hasWithdrawWhichReceivedIncorrectAmount(BOB));
    }
    

    // INVARIANT 13) repay should decrease borrow shares
    // Medusa is able to break this invariant when the fuzzer does small repayments
    // due to a rounding-down-to-zero precision loss at:
    // https://github.com/beta-finance/Omni-Protocol/blob/main/src/OmniToken.sol#L265
    // Foundry is unable to break it
    function _hasRepayWhichDidntDecreaseBorrowShares(address account) private view returns(bool) {
        for(uint96 subId; subId<=MAX_SUB_ID; ++subId) {
            bytes32 accountId = account.toAccount(subId);

            if(ghost_subAccount[accountId].repayDidntDecreaseBorrowShares) return true;
        }

        return false;
    }
    function invariant_repay_decreases_borrow_shares() public view {
        assert(!_hasRepayWhichDidntDecreaseBorrowShares(ALICE) &&
               !_hasRepayWhichDidntDecreaseBorrowShares(BOB));
    }


    // INVARIANT 14) repay should decrease borrow amount by correct amount
    function _hasRepayWhichIncorrectlyDecreasedBorrowAmount(address account) private view returns(bool) {
        for(uint96 subId; subId<=MAX_SUB_ID; ++subId) {
            bytes32 accountId = account.toAccount(subId);

            if(ghost_subAccount[accountId].repayIncorrectBorrowAmountDecrease) return true;
        }

        return false;
    }
    function invariant_repay_correctly_decreases_borrow_amount() public view {
        assert(!_hasRepayWhichIncorrectlyDecreasedBorrowAmount(ALICE) &&
               !_hasRepayWhichIncorrectlyDecreasedBorrowAmount(BOB));
    }


    // INVARIANT 15) borrow should increase borrow shares
    function _hasBorrowWhichDidntIncreaseBorrowShares(address account) private view returns(bool) {
        for(uint96 subId; subId<=MAX_SUB_ID; ++subId) {
            bytes32 accountId = account.toAccount(subId);

            if(ghost_subAccount[accountId].borrowDidntIncreaseBorrowShares) return true;
        }

        return false;
    }
    function invariant_borrow_increases_borrow_shares() public view {
        assert(!_hasBorrowWhichDidntIncreaseBorrowShares(ALICE) &&
               !_hasBorrowWhichDidntIncreaseBorrowShares(BOB));
    }


    // INVARIANT 16) borrow should increase borrow amount by correct amount
    function _hasBorrowWhichIncorrectlyIncreasedBorrowAmount(address account) private view returns(bool) {
        for(uint96 subId; subId<=MAX_SUB_ID; ++subId) {
            bytes32 accountId = account.toAccount(subId);

            if(ghost_subAccount[accountId].borrowIncorrectBorrowAmountIncrease) return true;
        }

        return false;
    }
    function invariant_borrow_correctly_increases_borrow_amount() public view {
        assert(!_hasRepayWhichIncorrectlyDecreasedBorrowAmount(ALICE) &&
               !_hasRepayWhichIncorrectlyDecreasedBorrowAmount(BOB));
    }


    /* OmniPool HANDLER FUNCTIONS */
    //
    // Handlers use input filtering to reduce but *not* to completely
    // eliminate invalid runs; there is still an element of randomness
    // where some inputs will be invalid
    function enterIsolatedMarket(uint96 _subId, uint8 _market) public {
        _subId         = _clampBetweenU96(_subId, 0, MAX_SUB_ID);
        address market = _getMarketIncIsolated(_market);

        vm.prank(msg.sender);
        pool.enterIsolatedMarket(_subId, market);

        // update ghost variables
        bytes32 accountId = msg.sender.toAccount(_subId);

        ghost_subAccount[accountId].numEnteredMarkets++;

        if(_isIsolatedMarket(market)) {
            ghost_subAccount[accountId].numEnteredIsolatedMarkets++;

            if(_hasActiveBorrows(accountId)) {
                ghost_subAccount[accountId].enteredIsolatedMarketWithActiveBorrows = true;
            }
        }

        if(_marketExpired(market)) {
            ghost_subAccount[accountId].enteredExpiredMarketOrMode = true;
        }
    }

    function enterMarkets(uint96 _subId, uint8 _market) public {
        _subId         = _clampBetweenU96(_subId, 0, MAX_SUB_ID);
        address market = _getMarketIncIsolated(_market);

        address[] memory markets = new address[](1);
        markets[0] = market;

        vm.prank(msg.sender);
        pool.enterMarkets(_subId, markets);

        // update ghost variables
        bytes32 accountId = msg.sender.toAccount(_subId);

        ghost_subAccount[accountId].numEnteredMarkets++;

        if(_isIsolatedMarket(market)) {
            ghost_subAccount[accountId].numEnteredIsolatedMarkets++;

            if(_hasActiveBorrows(accountId)) {
                ghost_subAccount[accountId].enteredIsolatedMarketWithActiveBorrows = true;
            }
        }

        if(_marketExpired(market)) {
            ghost_subAccount[accountId].enteredExpiredMarketOrMode = true;
        }
    }

    function exitMarket(uint96 _subId, uint8 _market) public {
        _subId         = _clampBetweenU96(_subId, 0, MAX_SUB_ID);
        address market = _getMarketIncIsolated(_market);

        vm.prank(msg.sender);
        pool.exitMarket(_subId, market);

        // update ghost variables
        bytes32 accountId = msg.sender.toAccount(_subId);

        ghost_subAccount[accountId].numEnteredMarkets--;

        if(_hasActiveBorrows(accountId)) {
            ghost_subAccount[accountId].exitedMarketOrModeWithActiveBorrows = true;
        }

        if(_isIsolatedMarket(market)) {
            ghost_subAccount[accountId].numEnteredIsolatedMarkets--;
        }
    }

    function clearMarkets(uint96 _subId) public {
        _subId = _clampBetweenU96(_subId, 0, MAX_SUB_ID);

        vm.prank(msg.sender);
        pool.clearMarkets(_subId);

        // update ghost variables
        bytes32 accountId = msg.sender.toAccount(_subId);

        ghost_subAccount[accountId].numEnteredMarkets         = 0;
        ghost_subAccount[accountId].numEnteredIsolatedMarkets = 0;

        if(_hasActiveBorrows(accountId)) {
            ghost_subAccount[accountId].exitedMarketOrModeWithActiveBorrows = true;
        }
    }

    function enterMode(uint96 _subId, uint8 _modeId) public {
        _subId  = _clampBetweenU96(_subId, 0, MAX_SUB_ID);
        _modeId = _clampBetweenU8(_modeId, MIN_MODE_ID, MAX_MODE_ID);

        vm.prank(msg.sender);
        pool.enterMode(_subId, _modeId);

        // update ghost variables
        bytes32 accountId = msg.sender.toAccount(_subId);

        ghost_subAccount[accountId].numEnteredModes++;

        if(ghost_subAccount[accountId].numEnteredMarkets > 0) {
            ghost_subAccount[accountId].enteredModeWithEnteredMarkets = true;
        }

        if(_modeExpired(_modeId)) {
            ghost_subAccount[accountId].enteredExpiredMarketOrMode = true;
        }
    }

    function exitMode(uint96 _subId) public {
        _subId = _clampBetweenU96(_subId, 0, MAX_SUB_ID);

        vm.prank(msg.sender);
        pool.exitMode(_subId);

        // update ghost variables
        bytes32 accountId = msg.sender.toAccount(_subId);

        ghost_subAccount[accountId].numEnteredModes--;

        if(_hasActiveBorrows(accountId)) {
            ghost_subAccount[accountId].exitedMarketOrModeWithActiveBorrows = true;
        }
    }

    function borrow(uint96 _subId, uint8 _market, uint256 _amount) public {
        _subId         = _clampBetweenU96(_subId, 0, MAX_SUB_ID);
        address market = _getMarketExcIsolated(_market);

        // save borrow amount & shares before calling borrow, used in invariant checks
        OmniToken token   = OmniToken(market);

        // accrue() first so it cant change storage during the next txn 
        token.accrue();

        bytes32 accountId = msg.sender.toAccount(_subId);
        uint8 trancheId   = pool.getAccountBorrowTier(_getAccountInfo(accountId));

        ( , uint256 totalBorrowAmountPrev, , uint256 totalBorrowSharePrev) = token.tranches(trancheId);

        vm.prank(msg.sender);
        pool.borrow(_subId, market, _amount);

        ( , uint256 totalBorrowAmountAfter, , uint256 totalBorrowShareAfter) = token.tranches(trancheId);

        // update ghost variables
        uint256 borrowIncrease = totalBorrowAmountAfter - totalBorrowAmountPrev;

        if(_amount > 0) {
            if(borrowIncrease != _amount) {
                ghost_subAccount[accountId].borrowIncorrectBorrowAmountIncrease = true;
            }

            if(totalBorrowShareAfter == totalBorrowSharePrev) {
                ghost_subAccount[accountId].borrowDidntIncreaseBorrowShares = true;
            }
        }
    }

    function repay(uint96 _subId, uint8 _market, uint256 _amount) public {
        _subId         = _clampBetweenU96(_subId, 0, MAX_SUB_ID);
        address market = _getMarketExcIsolated(_market);

        // save borrow amount & shares before calling repay, used in invariant checks
        OmniToken token   = OmniToken(market);

        // accrue() first so it cant change storage during the next txn 
        token.accrue();

        bytes32 accountId = msg.sender.toAccount(_subId);
        uint8 trancheId   = pool.getAccountBorrowTier(_getAccountInfo(accountId));

        ( , uint256 totalBorrowAmountPrev, , uint256 totalBorrowSharePrev) = token.tranches(trancheId);

        vm.prank(msg.sender);
        pool.repay(_subId, market, _amount);

        ( , uint256 totalBorrowAmountAfter, , uint256 totalBorrowShareAfter) = token.tranches(trancheId);

        // update ghost variables
        uint256 borrowReduction = totalBorrowAmountPrev-totalBorrowAmountAfter;

        if(_amount > 0) { 
            if(borrowReduction != _amount) {
                ghost_subAccount[accountId].repayIncorrectBorrowAmountDecrease = true;
            }

            if(totalBorrowShareAfter == totalBorrowSharePrev) {
                ghost_subAccount[accountId].repayDidntDecreaseBorrowShares = true;
            }
        }
    }

    function liquidate(uint96 _targetSubId, uint96 _liquidatorSubId, uint8 _targetAccount, 
                       uint8 _liquidateMarket, uint8 _collateralMarket, uint256 _amount, 
                       bool giveTokens) public {
        _targetSubId      = _clampBetweenU96(_targetSubId, 0, MAX_SUB_ID);
        _liquidatorSubId  = _clampBetweenU96(_liquidatorSubId, 0, MAX_SUB_ID);
        address liqMarket = _getMarketExcIsolated(_liquidateMarket);
        address colMarket = _getMarketIncIsolated(_collateralMarket);

        bytes32 targetAccountId = (_getActor(_targetAccount)).toAccount(_targetSubId);
        bytes32 liqAccountId    = msg.sender.toAccount(_liquidatorSubId);

        // introduce some randomness into whether the test ensures account
        // has sufficent tokens to liquidate or not. This allows some invalid runs through
        // where account won't have enough tokens to liquidate but also helps ensure
        // there will be some valid liquidations
        if(giveTokens) {
            (MockERC20((OmniToken(liqMarket)).underlying())).mint(msg.sender, _amount);
        }

        vm.prank(msg.sender);
        pool.liquidate(
            IOmniPool.LiquidationParams(targetAccountId, liqAccountId, liqMarket, colMarket, _amount));

        // no prank here, has to be called by admin. If it fails don't worry, just
        // trying to call it after liquidation to get some more coverage if liquidation
        // totally liquidates a user. Not fully working yet
        try pool.socializeLoss(liqMarket, targetAccountId) {} catch {}
    }


    /* OmniToken HANDLER FUNCTIONS */
    //
    function deposit(uint96 _subId, uint8 _trancheId, uint256 _amount, 
                     uint8 _token, bool giveTokens) public {
        _subId          = _clampBetweenU96(_subId   , 0, MAX_SUB_ID);
        _trancheId      = _clampBetweenU8(_trancheId, 0, MAX_TRANCH_ID);
        OmniToken token = OmniToken(_getMarketIncIsolated(_token));

        // introduce some randomness into whether the test ensures account
        // has sufficent tokens to deposit or not. This allows some invalid
        // runs through where account won't have enough tokens to deposit.
        // Accounts can also have their tokens replenished this way
        if(giveTokens) {
            (MockERC20(token.underlying())).mint(msg.sender, _amount);
        }

        // accrue() first so it cant change storage during the next txn 
        token.accrue();

        // save deposit amount & shares before calling deposit, used in invariant checks
        (uint256 totalDepositAmountPrev, , uint256 totalDepositSharePrev, ) = token.tranches(_trancheId);

        vm.prank(msg.sender);
        token.deposit(_subId, _trancheId, _amount);

        // update ghost variables
        bytes32 accountId = msg.sender.toAccount(_subId);

        (uint256 totalDepositAmountAfter, , uint256 totalDepositShareAfter, ) = token.tranches(_trancheId);

        if(_amount > 0 && totalDepositShareAfter == totalDepositSharePrev) {
            ghost_subAccount[accountId].depositReceivedZeroShares = true;
        }

        if(totalDepositAmountAfter-totalDepositAmountPrev != _amount) {
            ghost_subAccount[accountId].depositReceivedIncorrectAmount = true;
        }
    }

    function withdraw(uint96 _subId, uint8 _trancheId, 
                      uint256 _share, uint8 _token) public {
        _subId          = _clampBetweenU96(_subId   , 0, MAX_SUB_ID);
        _trancheId      = _clampBetweenU8(_trancheId, 0, MAX_TRANCH_ID);
        OmniToken token = OmniToken(_getMarketIncIsolated(_token)); 

        // accrue() first so it cant change storage during the next txn 
        token.accrue();

        // save deposit amount & shares before calling withdraw, used in invariant checks
        (uint256 totalDepositAmountPrev, , uint256 totalDepositSharePrev, ) = token.tranches(_trancheId);

        vm.prank(msg.sender);
        uint256 amount = token.withdraw(_subId, _trancheId, _share);

        // update ghost variables
        bytes32 accountId = msg.sender.toAccount(_subId);

        (uint256 totalDepositAmountAfter, , uint256 totalDepositShareAfter, ) = token.tranches(_trancheId);

        uint256 actualDifference = totalDepositAmountPrev-totalDepositAmountAfter;

        if(_share > 0 && (actualDifference == 0 || actualDifference != amount)) {
            ghost_subAccount[accountId].withdrawReceivedIncorrectAmount = true;
        }

        if(_share > 0 && totalDepositShareAfter == totalDepositSharePrev) {
            ghost_subAccount[accountId].withdrawDecreasedZeroShares = true;
        }
    }

    function transfer(uint96 _subId, bytes32 _to, uint8 _trancheId, 
                      uint256 _shares, uint8 _token) public {
        _subId           = _clampBetweenU96(_subId   , 0, MAX_SUB_ID);
        _trancheId       = _clampBetweenU8(_trancheId, 0, MAX_TRANCH_ID);
        IOmniToken token = IOmniToken(_getMarketIncIsolated(_token)); 

        vm.prank(msg.sender);
        token.transfer(_subId, _to, _trancheId, _shares);
    }


    /* Price Oracle UTILITY FUNCTION */
    //
    // function which changes oracle pricing of underlying tokens
    // will be called randomly by fuzzer. This enables positions to become
    // subject to liquidation enabling greater coverage
    function updateOraclePrice(uint8 _priceIndex, uint8 _percentMove, 
                               bool _increasePrice) public {
        _priceIndex  = _clampBetweenU8(_priceIndex, 0, PRICES_COUNT-1);

        // price can move in a set % range
        _percentMove = _clampBetweenU8(_percentMove, MIN_PRICE_MOVE, MAX_PRICE_MOVE);

        // calculate price delta
        uint256 priceDelta = prices[_priceIndex] * _percentMove / 100;

        // apply direction
        if(_increasePrice) prices[_priceIndex] += priceDelta;
        else prices[_priceIndex] -= priceDelta;

        // save new pricing
        oracle.setPrices(underlyings, prices);
    }


    /* Helper functions to fetch data used in invariant checks */
    // 
    function _getOmniTokenTranche(address _market, uint8 _tranche) private view
        returns (OmniToken.OmniTokenTranche memory)
    {
        (uint256 totalDeposit, uint256 totalBorrow, uint256 totalDepositShares, uint256 totalBorrowShares) =
            OmniToken(_market).tranches(_tranche);
        return OmniToken.OmniTokenTranche(totalDeposit, totalBorrow, totalDepositShares, totalBorrowShares);
    }
    function _getAccountInfo(bytes32 account) internal view returns (IOmniPool.AccountInfo memory) {
        (uint8 modeId, address isolatedCollateralMarket, uint32 softThreshold) = pool.accountInfos(account);
        return IOmniPool.AccountInfo(modeId, isolatedCollateralMarket, softThreshold);
    }
    function _marketExpired(address _market) private view returns(bool) {
        ( , , uint32 expirationTimestamp, , ) = pool.marketConfigurations(_market);

        return block.timestamp >= expirationTimestamp;
    }
    function _modeExpired(uint8 _modeId) private view returns(bool) {
        ( , , , uint32 expirationTimestamp ) = pool.modeConfigurations(_modeId);

        return block.timestamp >= expirationTimestamp;
    }
    function _hasActiveBorrows(bytes32 accountId) private view returns(bool) {

        return (oToken.getAccountBorrowInUnderlying(accountId,  0) + 
                oToken.getAccountBorrowInUnderlying(accountId,  1) +
                oToken2.getAccountBorrowInUnderlying(accountId, 0) + 
                oToken2.getAccountBorrowInUnderlying(accountId, 1)) > 0;
    }


    /* Helper functions to choose between valid entities to interact with */
    // 
    function _getMarketExcIsolated(uint8 _market) private view returns (address marketOut) {
        _market = _clampBetweenU8(_market, 0, 1);
        if(_market == 0)      marketOut = address(oToken);
        else if(_market == 1) marketOut = address(oToken2);
    }
    function _getMarketIncIsolated(uint8 _market) private view returns (address marketOut) {
        _market = _clampBetweenU8(_market, 0, 3);
        if(_market == 0)      marketOut = address(oToken);
        else if(_market == 1) marketOut = address(oToken2);
        else if(_market == 2) marketOut = address(oToken3);
        else if(_market == 3) marketOut = address(oToken4);
    }
    function _getMarketOnlyIsolated(uint8 _market) private view returns (address marketOut) {
        _market = _clampBetweenU8(_market, 0, 1);
        if(_market == 0)      marketOut = address(oToken3);
        else if(_market == 1) marketOut = address(oToken4);
    }
    function _getActor(uint8 _actor) private pure returns (address actorOut) {
        _actor = _clampBetweenU8(_actor, 0, 1);
        if(_actor == 0)      actorOut = ALICE;
        else if(_actor == 1) actorOut = BOB;
    }
    function _isIsolatedMarket(address _market) private view returns(bool) {
        if(_market == address(oToken3) || _market == address(oToken4)) return true;
        return false;
    }


    /* Helper functions for platform-agnostic input restriction */
    // 
    function _clampBetweenU256(uint256 value, uint256 low, uint256 high) private pure returns (uint256) {
        if (value < low || value > high) {
            return (low + (value % (high - low + 1)));
        }
        return value;
    }
    function _clampBetweenU96(uint96 value, uint96 low, uint96 high) private pure returns (uint96) {
        if (value < low || value > high) {
            return (low + (value % (high - low + 1)));
        }
        return value;
    }
    function _clampBetweenU8(uint8 value, uint8 low, uint8 high) private pure returns (uint8) {
        if (value < low || value > high) {
            return (low + (value % (high - low + 1)));
        }
        return value;
    }
}