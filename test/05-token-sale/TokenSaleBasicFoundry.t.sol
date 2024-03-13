// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../src/05-token-sale/TokenSale.sol";
import "../../src/TestToken.sol";

import "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract TokenSaleBasicFoundry
//
// get coverage report (see https://medium.com/@rohanzarathustra/forge-coverage-overview-744d967e112f):
// 1) forge coverage --report lcov --report-file test/05-token-sale/coverage-foundry-basic.lcov --match-contract TokenSaleBasicFoundry
// 2) genhtml test/05-token-sale/coverage-foundry-basic.lcov -o test/05-token-sale/coverage-foundry-basic
// 3) open test/05-token-sale/coverage-foundry-basic/index.html in your browser and
//    navigate to the relevant source file to see line-by-line execution records
contract TokenSaleBasicFoundry is Test {

    uint8 private constant SELL_DECIMALS = 18;
    uint8 private constant BUY_DECIMALS  = 6;

    // total tokens to sell
    uint256 private constant SELL_TOKENS = 1000e18;

    // buy tokens to give each buyer
    uint256 private constant BUY_TOKENS  = 500e6;

    // number of buyers allowed in the token sale
    uint8 private constant NUM_BUYERS    = 5;

    // max each buyer can buy
    uint256 private constant MAX_TOKENS_PER_BUYER = 200e18;

    // allowed buyers
    address[] buyers;

    // contracts required for test
    ERC20     sellToken;
    ERC20     buyToken;
    TokenSale tokenSale;

    function setUp() public virtual {
        sellToken = new TestToken(SELL_TOKENS, SELL_DECIMALS);
        buyToken  = new TestToken(BUY_TOKENS*NUM_BUYERS, BUY_DECIMALS);

        // setup the allowed list of buyers
        buyers.push(address(0x1));
        buyers.push(address(0x2));
        buyers.push(address(0x3));
        buyers.push(address(0x4));
        buyers.push(address(0x5));

        assert(buyers.length == NUM_BUYERS);

        // setup contract to be tested
        tokenSale = new TokenSale(buyers,
                                  address(sellToken),
                                  address(buyToken),
                                  MAX_TOKENS_PER_BUYER,
                                  SELL_TOKENS);

        // fund the contract
        sellToken.transfer(address(tokenSale), SELL_TOKENS);

        // verify setup
        //
        // token sale tokens & parameters
        assert(sellToken.balanceOf(address(tokenSale)) == SELL_TOKENS);
        assert(tokenSale.getSellTokenTotalAmount() == SELL_TOKENS);
        assert(tokenSale.getSellTokenAddress() == address(sellToken));
        assert(tokenSale.getBuyTokenAddress() == address(buyToken));
        assert(tokenSale.getMaxTokensPerBuyer() == MAX_TOKENS_PER_BUYER);
        assert(tokenSale.getTotalAllowedBuyers() == NUM_BUYERS);

        // no tokens have yet been sold
        assert(tokenSale.getRemainingSellTokens() == SELL_TOKENS);

        // this contract is the creator
        assert(tokenSale.getCreator() == address(this));

        // constrain fuzz test senders to the set of allowed buying addresses
        for(uint256 i; i<buyers.length; ++i) {
            address buyer = buyers[i];

            // add buyer to sender list
            targetSender(buyer);

            // distribute buy tokens to buyer
            buyToken.transfer(buyer, BUY_TOKENS);
            assert(buyToken.balanceOf(buyer) == BUY_TOKENS);

            // buyer approves token sale contract to prevent reverts
            vm.prank(buyer);
            buyToken.approve(address(tokenSale), type(uint256).max);
        }

        // no buy tokens yet received, all distributed to buyers
        assert(buyToken.balanceOf(address(this)) == 0);

        // basic test with no advanced guiding of the fuzzer
        // Foundry is able to break the first & most valuable invariant,
        // but can't break the second one as it gets distracted calling
        // functions on the 2 token contracts which don't help at all
    }


    // two possible invariants in order of importance:
    //
    // 1) the amount of tokens bought (received by this contract)
    //    should equal the amount of tokens sold as the exchange
    //    rate is 1:1, when accounted for precision difference
    function invariant_tokens_bought_eq_tokens_sold() public view {
        uint256 soldAmount = tokenSale.getSellTokenSoldAmount();
        uint256 boughtBal  = buyToken.balanceOf(address(this));

        // scale up `boughtBal` by the precision difference
        boughtBal *= 10 ** (SELL_DECIMALS - BUY_DECIMALS);

        // assert the equality; if this breaks that means something
        // has gone wrong with the buying and selling. In our private
        // audit there was a precision miscalculation that allowed
        // an attacker to buy the sale tokens without paying due to
        // rounding down to zero
        assert(boughtBal == soldAmount);
    }


    // 2) amount each user has bought shouldn't exceed max token buy per user
    //    the code only checks on a per-transaction basis, so a user can
    //    buy over their limit through multiple smaller buys
    function invariant_max_token_buy_per_user() public view {
        for(uint256 i; i<buyers.length; ++i) {
            address buyer = buyers[i];

            assert(sellToken.balanceOf(buyer) <= MAX_TOKENS_PER_BUYER);
        }
    }

    // this test case shows the major problem; the decimal precision
    // conversion code is assuming the input amount is formatted
    // with 18 decimals, even if the underlying token does not have
    // 18 decimals. Hence by sending a amount small enough the
    // conversion will round down to zero and the buyer can buy free
    // tokens from the token sale, since the conversion isn't checking
    // if the conversion of the buyer's input returned 0 & ERC20
    // will happily transfer 0 tokens!
    //
    /* commented out by default since the invariants are what we are
       testing, this is just here to more clearly show the major bug 
    function testBuy() public {
        address buyer  = buyers[0];
        uint256 amount = 200e6;

        vm.prank(buyer);
        tokenSale.buy(amount);

        // buyer still has all their tokens
        assertEq(buyToken.balanceOf(buyer), BUY_TOKENS);

        // buyer got some sell tokens for free!
        assertEq(sellToken.balanceOf(buyer), 200e6);
    }
    */
}
