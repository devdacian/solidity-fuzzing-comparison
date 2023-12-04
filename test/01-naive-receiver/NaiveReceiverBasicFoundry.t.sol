// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../src/01-naive-receiver/NaiveReceiverLenderPool.sol";
import "../../src/01-naive-receiver/FlashLoanReceiver.sol";

import "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract NaiveReceiverBasicFoundry
contract NaiveReceiverBasicFoundry is Test {

    // initial eth flash loan pool
    uint256 constant INIT_ETH_POOL     = 1000e18;
    // initial eth flash loan receiver
    uint256 constant INIT_ETH_RECEIVER = 10e18;

    // contracts required for test
    NaiveReceiverLenderPool pool;
    FlashLoanReceiver receiver;

    function setUp() public virtual {
        // setup contracts to be tested
        pool     = new NaiveReceiverLenderPool();
        receiver = new FlashLoanReceiver(payable(address(pool)));

        // set their initial eth balances
        deal(address(pool), INIT_ETH_POOL);
        deal(address(receiver), INIT_ETH_RECEIVER);

        // basic test with no advanced guiding of the fuzzer
        // most of the fuzz runs revert and are useless
        //
        // basic foundry is able to break invariant 2) but not 1)
    }

    // two possible invariants in order of importance:
    //
    // 1) receiver's balance is not 0
    // breaking this invariant is very valuable but much harder
    function invariant_receiver_balance_not_zero() public view {
        assert(address(receiver).balance != 0);
    }

    // 2) receiver's balance is not less than starting balance
    // breaking this invariant is less valuable but much easier
    function invariant_receiver_balance_not_less_initial() public view {
       assert(address(receiver).balance >= INIT_ETH_RECEIVER);
    }

}
