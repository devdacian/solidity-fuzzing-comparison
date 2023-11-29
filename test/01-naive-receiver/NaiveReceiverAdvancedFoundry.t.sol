pragma solidity ^0.8.23;

import "./NaiveReceiverBasicFoundry.t.sol";

// run from base project directory with:
// forge test --match-contract NaiveReceiverAdvancedFoundry
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

        // call underlying function being tested with
        // the receiver address to prevent wasted runs
        pool.flashLoan(address(receiver), borrowAmount);
    }

    // invariants inherited from base contract
}
