// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../src/02-unstoppable/UnstoppableLender.sol";
import "../../src/02-unstoppable/ReceiverUnstoppable.sol";

import "../../src/TestToken.sol";

// configure solc-select to use compiler version:
// solc-select use 0.8.23 
//
// run from base project directory with:
// echidna --config test/02-unstoppable/UnstoppableBasicEchidna.yaml ./ --contract UnstoppableBasicEchidna
// medusa --config test/02-unstoppable/UnstoppableBasicMedusa.json fuzz
contract UnstoppableBasicEchidna {
    
    // initial tokens in pool
    uint256 constant INIT_TOKENS_POOL     = 1000000e18;
    // initial tokens attacker
    uint256 constant INIT_TOKENS_ATTACKER = 100e18;

    // contracts required for test
    ERC20               token;
    UnstoppableLender   pool;
    ReceiverUnstoppable receiver;
    address             attacker = address(0x1337000000000000000000000000000000000000);

    // constructor has to be payable if balanceContract > 0 in yaml config
    constructor() payable {
        // setup contracts to be tested
        token    = new TestToken(INIT_TOKENS_POOL + INIT_TOKENS_ATTACKER, 18);
        pool     = new UnstoppableLender(address(token));
        receiver = new ReceiverUnstoppable(payable(address(pool)));

        // transfer deposit initial tokens into pool
        token.approve(address(pool), INIT_TOKENS_POOL);
        pool.depositTokens(INIT_TOKENS_POOL);

        // transfer remaining tokens to the attacker
        token.transfer(attacker, INIT_TOKENS_ATTACKER);

        // attacker configured as msg.sender in yaml config
    }

    // invariant #1 very generic but Echidna can still break it even
    // if this is the only invariant
    function invariant_receiver_can_take_flash_loan() public returns (bool) {
        receiver.executeFlashLoan(10);
        return true;
    }

    // invariant #2 is more specific and Echidna can easily break it
    function invariant_pool_bal_equal_token_pool_bal() public view returns(bool) {
        return(pool.poolBalance() == token.balanceOf(address(pool)));
    }
}
