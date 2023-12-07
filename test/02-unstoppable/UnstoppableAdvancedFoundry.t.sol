// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./UnstoppableBasicFoundry.t.sol";

// run from base project directory with:
// forge test --match-contract UnstoppableAdvancedFoundry
//
// get coverage report (see https://medium.com/@rohanzarathustra/forge-coverage-overview-744d967e112f):
// 1) forge coverage --report lcov --report-file test/02-unstoppable/coverage-foundry-advanced.lcov --match-contract UnstoppableAdvancedFoundry
// 2) genhtml test/02-unstoppable/coverage-foundry-advanced.lcov -o test/02-unstoppable/coverage-foundry-advanced
// 3) open test/02-unstoppable/coverage-foundry-advanced/index.html in your browser and
//    navigate to the relevant source file to see line-by-line execution records
contract UnstoppableAdvancedFoundry is UnstoppableBasicFoundry {

    function setUp() public override {
        // call parent first to setup test environment
        super.setUp();

        // advanced test with guiding of the fuzzer
        //
        // guide foundry to focus on the token contract
        //
        // targetContract(address(token));
        //
        // by itself this is still insufficient to break
        // either of the invariants. So instead use this
        // contract as a wrapper for the token contract's
        // transfer() function to put Foundry on target
        targetContract(address(this));

        // functions to target during invariant tests
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = this.tokenTransfer.selector;

        targetSelector(FuzzSelector({
            addr: address(this),
            selectors: selectors
        }));
        
        // advanced foundry is able to break both invariants,
        // with an insane amount of help and targetting
        // being fed to it
    }

    // wrapper around token.transfer() to "guide" the fuzz test
    function tokenTransfer(uint256 amount) public {        
        // instruct fuzzer to cap amount under attacker's
        // available balance and avoid 0 transfer
        amount = bound(amount, 1, token.balanceOf(attacker));

        // call underlying function being tested. Initially
        // `address to` was a parameter but Foundry failed to
        // break the invariants so had to hard-code `to` as the
        // pool address to finally get Foundry to break
        // the invariants
        vm.prank(attacker);
        token.transfer(address(pool), amount);
    } 

    // invariants inherited from base contract
}
