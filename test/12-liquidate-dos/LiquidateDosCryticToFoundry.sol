// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { TargetFunctions } from "./TargetFunctions.sol";
import { FoundryAsserts } from "@chimera/FoundryAsserts.sol";
import { Test } from "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract LiquidateDosCryticToFoundry
// (if an invariant fails add -vvvvv on the end to see what failed)
//
// get coverage report (see https://medium.com/@rohanzarathustra/forge-coverage-overview-744d967e112f):
//
// 1) forge coverage --report lcov --report-file test/12-liquidate-dos/coverage-foundry.lcov --match-contract LiquidateDosCryticToFoundry
// 2) genhtml test/12-liquidate-dos/coverage-foundry.lcov -o test/12-liquidate-dos/coverage-foundry
// 3) open test/12-liquidate-dos/coverage-foundry/index.html in your browser and
//    navigate to the relevant source file to see line-by-line execution records

contract LiquidateDosCryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
      setup();

      // Foundry doesn't use config files but does
      // the setup programmatically here

      // target the fuzzer on this contract as it will
      // contain the handler functions
      targetContract(address(this));

      // handler functions to target during invariant tests
      bytes4[] memory selectors = new bytes4[](3);
      selectors[0] = this.handler_openPosition.selector;
      selectors[1] = this.handler_toggleLiquidations.selector;
      selectors[2] = this.handler_liquidate.selector;

      targetSelector(FuzzSelector({ addr: address(this), selectors: selectors }));
    }

    function invariant_user_active_markets_correct() public {
      t(property_user_active_markets_correct(), "User active markets correct");
    }

    // TODO: wrap new "property_*" invariant into Foundry-style invariant
}