// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { TargetFunctions } from "./TargetFunctions.sol";
import { FoundryAsserts } from "@chimera/FoundryAsserts.sol";
import { Test } from "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract VestingCryticToFoundry
// (if an invariant fails add -vvvvv on the end to see what failed)
//
// get coverage report (see https://medium.com/@rohanzarathustra/forge-coverage-overview-744d967e112f):
//
// 1) forge coverage --report lcov --report-file test/09-vesting/coverage-foundry.lcov --match-contract VestingCryticToFoundry
// 2) genhtml test/09-vesting/coverage-foundry.lcov -o test/09-vesting/coverage-foundry
// 3) open test/09-vesting/coverage-foundry/index.html in your browser and
//    navigate to the relevant source file to see line-by-line execution records

contract VestingCryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
      setup();

      // Foundry doesn't use config files but does
      // the setup programmatically here

      // target the fuzzer on this contract as it will
      // contain the handler functions
      targetContract(address(this));

      // handler functions to target during invariant tests
      bytes4[] memory selectors = new bytes4[](1);
      selectors[0] = this.handler_transferPoints.selector;

      targetSelector(FuzzSelector({ addr: address(this), selectors: selectors }));
    }

    // wrap every "property_*" invariant function into
    // a Foundry-style "invariant_*" function
    function invariant_users_points_sum_eq_total_points() public {
      assertTrue(property_users_points_sum_eq_total_points());
    }
}