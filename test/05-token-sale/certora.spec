// run from base folder:
// certoraRun test/05-token-sale/certora.conf
methods {
    // `envfree` definitions to call functions without explicit `env`
    function getSellTokenSoldAmount() external returns (uint256) envfree;
}

// define constants and require them later to prevent HAVOC into invalid state
definition MIN_PRECISION_BUY() returns uint256 = 6;
definition PRECISION_SELL()    returns uint256 = 18;
definition FUNDING_MIN()       returns uint256 = 100;
definition BUYERS_MIN()        returns uint256 = 3;

// currently this results in "Rule was successfully verified without running SMT solver"
// not sure why...
rule tokens_bought_eq_tokens_sold(uint256 amountToBuy) {
    env e1;

    uint8 sellTokenDecimals = currentContract.s_sellToken.decimals(e1);
    uint8 buyTokenDecimals  = currentContract.s_buyToken.decimals(e1);

    // enforce basic sanity checks on variables set during constructor
    require currentContract.s_sellToken != currentContract.s_buyToken &&
            sellTokenDecimals == PRECISION_SELL()    &&
            buyTokenDecimals  >= MIN_PRECISION_BUY() &&
            buyTokenDecimals  <= PRECISION_SELL()    &&
            currentContract.s_sellTokenTotalAmount >= FUNDING_MIN() * 10 ^ sellTokenDecimals &&
            currentContract.s_maxTokensPerBuyer <= currentContract.s_sellTokenTotalAmount &&
            currentContract.s_totalBuyers >= BUYERS_MIN();

    // enforce valid msg.sender
    require e1.msg.sender != currentContract.s_creator &&
            e1.msg.sender != currentContract.s_buyToken &&
            e1.msg.sender != currentContract.s_sellToken &&
            e1.msg.value == 0;

    // enforce buyer has not yet bought any tokens being sold
    require currentContract.s_sellToken.balanceOf(e1, e1.msg.sender) == 0 &&
            getSellTokenSoldAmount() == 0;

    // enforce buyer has tokens with which to buy tokens being sold
    uint256 buyerBuyTokenBalPre = currentContract.s_buyToken.balanceOf(e1, e1.msg.sender);
    require buyerBuyTokenBalPre > 0 && amountToBuy > 0;

    // perform a successful `buy` transaction
    buy(e1, amountToBuy);
    
    // buyer must have received some tokens from the sale
    assert getSellTokenSoldAmount() > 0;
    uint256 buyerSellTokensBalPost = currentContract.s_sellToken.balanceOf(e1, e1.msg.sender);
    assert buyerSellTokensBalPost > 0;

    uint256 buyerBuyTokenBalPost = currentContract.s_buyToken.balanceOf(e1, e1.msg.sender);

    // verify buyer paid 1:1 for the tokens they bought when accounting for decimal difference
    assert getSellTokenSoldAmount() == (buyerBuyTokenBalPre - buyerBuyTokenBalPost) 
                                       * 10 ^ (sellTokenDecimals - buyTokenDecimals);
}

// this rule was provided by https://x.com/alexzoid_eth
rule max_token_buy_per_user(env e1, env e2, uint256 amountToBuy1, uint256 amountToBuy2) {   
    // enforce valid initial state
    require(currentContract.s_maxTokensPerBuyer <= currentContract.s_sellTokenTotalAmount);

    // enforce same buyer in different calls
    require e1.msg.sender == e2.msg.sender;
    require e1.msg.sender != currentContract && e1.msg.sender != currentContract.s_creator;

    // save initial balance
    mathint balanceBefore = currentContract.s_sellToken.balanceOf(e1, e1.msg.sender);
    
    // prevent over-flow in ERC20 (otherwise totalSupply and balances synchronization required)
    require balanceBefore < max_uint128 && amountToBuy1 < max_uint128 && amountToBuy1 < max_uint128;

    // perform two separate buy transactions
    buy(e1, amountToBuy1);
    buy(e2, amountToBuy2);

    // save final balance
    mathint balanceAfter = currentContract.s_sellToken.balanceOf(e1, e1.msg.sender);

    // verify total bought by same user must not exceed max limit per user
    mathint totalBuy = balanceAfter > balanceBefore ? balanceAfter - balanceBefore : 0;
    assert totalBuy <= currentContract.s_maxTokensPerBuyer;
}