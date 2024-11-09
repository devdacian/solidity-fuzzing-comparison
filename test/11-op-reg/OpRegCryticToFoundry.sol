// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { TargetFunctions } from "./TargetFunctions.sol";
import { FoundryAsserts } from "@chimera/FoundryAsserts.sol";
import { Test } from "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract OpRegCryticToFoundry
// (if an invariant fails add -vvvvv on the end to see what failed)
//
// get coverage report (see https://medium.com/@rohanzarathustra/forge-coverage-overview-744d967e112f):
//
// 1) forge coverage --report lcov --report-file test/11-op-reg/coverage-foundry.lcov --match-contract OpRegCryticToFoundry
// 2) genhtml test/11-op-reg/coverage-foundry.lcov -o test/11-op-reg/coverage-foundry
// 3) open test/11-op-reg/coverage-foundry/index.html in your browser and
//    navigate to the relevant source file to see line-by-line execution records

contract OpRegCryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
      setup();

      // Foundry doesn't use config files but does
      // the setup programmatically here

      // target the fuzzer on this contract as it will
      // contain the handler functions
      targetContract(address(this));

      // handler functions to target during invariant tests
      bytes4[] memory selectors = new bytes4[](2);
      selectors[0] = this.handler_register.selector;
      selectors[1] = this.handler_updateAddress.selector;

      targetSelector(FuzzSelector({ addr: address(this), selectors: selectors }));
    }

    // wrap every "property_*" invariant function into
    // a Foundry-style "invariant_*" function
    function invariant_operator_ids_have_unique_addresses() public {
      t(property_operator_ids_have_unique_addresses(), "Operator ids have unique addresses");
    }

    // TODO: wrap new "property_*" invariant into Foundry-style invariant
}