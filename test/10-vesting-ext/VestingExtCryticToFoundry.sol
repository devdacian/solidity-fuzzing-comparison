// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { TargetFunctions } from "./TargetFunctions.sol";
import { FoundryAsserts } from "@chimera/FoundryAsserts.sol";
import { Test } from "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract VestingExtCryticToFoundry
// (if an invariant fails add -vvvvv on the end to see what failed)
//
// get coverage report (see https://medium.com/@rohanzarathustra/forge-coverage-overview-744d967e112f):
//
// 1) forge coverage --report lcov --report-file test/10-vesting-ext/coverage-foundry.lcov --match-contract VestingExtCryticToFoundry
// 2) genhtml test/10-vesting-ext/coverage-foundry.lcov -o test/10-vesting-ext/coverage-foundry
// 3) open test/10-vesting-ext/coverage-foundry/index.html in your browser and
//    navigate to the relevant source file to see line-by-line execution records

contract VestingExtCryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
      setup();

      // Foundry doesn't use config files but does
      // the setup programmatically here

      // target the fuzzer on this contract as it will
      // contain the handler functions
      targetContract(address(this));

      // handler functions to target during invariant tests
      bytes4[] memory selectors = new bytes4[](2);
      selectors[0] = this.handler_transferPoints.selector;
      selectors[1] = this.handler_preclaim.selector;

      targetSelector(FuzzSelector({ addr: address(this), selectors: selectors }));
    }

    // wrap every "property_*" invariant function into
    // a Foundry-style "invariant_*" function
    function invariant_users_points_sum_eq_total_points() public {
      t(property_users_points_sum_eq_total_points(), "User points sum total points");
    }

    function invariant_total_preclaimed_lt_eq_max_preclaimable() public {
      t(property_total_preclaimed_lt_eq_max_preclaimable(), "Total Preclaimed <= Max Preclaimable");
    }
}