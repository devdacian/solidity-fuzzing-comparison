// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./NaiveReceiverBasicFoundry.t.sol";

// run from base project directory with:
// forge test --match-contract NaiveReceiverAdvancedFoundry
//
// get coverage report (see https://medium.com/@rohanzarathustra/forge-coverage-overview-744d967e112f):
// 1) forge coverage --report lcov --report-file test/01-naive-receiver/coverage-foundry-advanced.lcov --match-contract NaiveReceiverAdvancedFoundry
// 2) genhtml test/01-naive-receiver/coverage-foundry-advanced.lcov -o test/01-naive-receiver/coverage-foundry-advanced
// 3) open test/01-naive-receiver/coverage-foundry-advanced/index.html in your browser and
//    navigate to the relevant source file to see line-by-line execution records
contract NaiveReceiverAdvancedFoundry is NaiveReceiverBasicFoundry {

    function setUp() public override {
        // call parent first to setup test environment
        super.setUp();

        // advanced test with guiding of the fuzzer
        //
        // make this contract into a handler to wrap the pool's flashLoan()
        // function and instruct foundry to call it passing receiver's
        // address as the parameter. This significantly reduces
        // the amount of useless fuzz runs
        //
        // advanced foundry is able to break both invariants
        targetContract(address(this));

        // functions to target during invariant tests
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = this.flashLoanWrapper.selector;

        targetSelector(FuzzSelector({
            addr: address(this),
            selectors: selectors
        }));
    }

    // wrapper around pool.flashLoan() to "guide" the fuzz test
    function flashLoanWrapper(uint256 borrowAmount) public {
        // instruct fuzzer to cap borrowAmount under pool's
        // available amount to prevent wasted runs
        vm.assume(borrowAmount <= INIT_ETH_POOL);

        // call underlying function being tested with the receiver address
        // to prevent wasted runs. Initially tried it with address as fuzz
        // input parameter but this was unable to break the harder invariant
        pool.flashLoan(address(receiver), borrowAmount);
    }

    // invariants inherited from base contract
}
