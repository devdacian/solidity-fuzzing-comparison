// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../src/05-token-sale/TokenSale.sol";
import "../../src/TestToken.sol";

// configure solc-select to use compiler version:
// solc-select use 0.8.23 
//
// run from base project directory with:
// echidna --config test/05-token-sale/TokenSaleBasicEchidna.yaml ./ --contract TokenSaleBasicEchidna
// medusa --config test/05-token-sale/TokenSaleBasicMedusa.json fuzz

// used for HEVM cheat codes
// https://github.com/crytic/building-secure-contracts/blob/master/program-analysis/echidna/advanced/on-using-cheat-codes.md
// https://hevm.dev/controlling-the-unit-testing-environment.html#cheat-codes
interface IHevm {
    function prank(address) external;
}

contract TokenSaleBasicEchidna {
    IHevm hevm = IHevm(address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D));

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


    // constructor has to be payable if balanceContract > 0 in yaml config
    constructor() payable {
        sellToken = new TestToken(SELL_TOKENS, SELL_DECIMALS);
        buyToken  = new TestToken(BUY_TOKENS*NUM_BUYERS, BUY_DECIMALS);

        // setup the allowed list of buyers
        // make sure to use full address not just shorthand as Echidna
        // expands the address differently to Foundry & make sure to
        // use full addresses in yaml config `sender` list
        buyers.push(address(0x1000000000000000000000000000000000000000));
        buyers.push(address(0x2000000000000000000000000000000000000000));
        buyers.push(address(0x3000000000000000000000000000000000000000));
        buyers.push(address(0x4000000000000000000000000000000000000000));
        buyers.push(address(0x5000000000000000000000000000000000000000));

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
        // done in yaml config for echidna

        // distribute tokens to buyers
        for(uint256 i; i<buyers.length; ++i) {
            address buyer = buyers[i];

            // distribute buy tokens to buyer
            buyToken.transfer(buyer, BUY_TOKENS);
            assert(buyToken.balanceOf(buyer) == BUY_TOKENS);

            // buyer approves token sale contract to prevent reverts
            hevm.prank(buyer);
            buyToken.approve(address(tokenSale), type(uint256).max);
        }

        // no buy tokens yet received, all distributed to buyers
        assert(buyToken.balanceOf(address(this)) == 0);

        // basic test with no advanced guiding of the fuzzer
        // Echidna is able to break the first & most valuable invariant,
        // but can't break the second one as it gets distracted calling
        // functions on the 2 token contracts which don't help at all
        //
        // Basic Medusa is able to break both invariants!
    }


    // two possible invariants in order of importance:
    //
    // 1) the amount of tokens bought (received by this contract)
    //    should equal the amount of tokens sold as the exchange
    //    rate is 1:1, when accounted for precision difference
    function invariant_tokens_bought_eq_tokens_sold() public view returns(bool) {
        uint256 soldAmount = tokenSale.getSellTokenSoldAmount();
        uint256 boughtBal  = buyToken.balanceOf(address(this));

        // scale up `boughtBal` by the precision difference
        boughtBal *= 10 ** (SELL_DECIMALS - BUY_DECIMALS);

        // assert the equality; if this breaks that means something
        // has gone wrong with the buying and selling. In our private
        // audit there was a precision miscalculation that allowed
        // an attacker to buy the sale tokens without paying due to
        // rounding down to zero
        return(boughtBal == soldAmount);
    }


    // 2) amount each user has bought shouldn't exceed max token buy per user
    //    the code only checks on a per-transaction basis, so a user can
    //    buy over their limit through multiple smaller buys
    function invariant_max_token_buy_per_user() public view returns(bool) {
        for(uint256 i; i<buyers.length; ++i) {
            address buyer = buyers[i];
            
            if(sellToken.balanceOf(buyer) > MAX_TOKENS_PER_BUYER) {
                return false;
            }
        }

        return true;
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

        hevm.prank(buyer);
        tokenSale.buy(amount);

        // buyer still has all their tokens
        assertEq(buyToken.balanceOf(buyer), BUY_TOKENS);

        // buyer got some sell tokens for free!
        assertEq(sellToken.balanceOf(buyer), 200e6);
    }
    */
}
