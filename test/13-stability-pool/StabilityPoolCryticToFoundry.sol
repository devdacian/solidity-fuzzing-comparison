// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { TargetFunctions } from "./TargetFunctions.sol";
import { FoundryAsserts } from "@chimera/FoundryAsserts.sol";
import { Test } from "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract StabilityPoolCryticToFoundry
// (if an invariant fails add -vvvvv on the end to see what failed)
//
// get coverage report (see https://medium.com/@rohanzarathustra/forge-coverage-overview-744d967e112f):
//
// 1) forge coverage --report lcov --report-file test/13-stability-pool/coverage-foundry.lcov --match-contract LiquidateDosCryticToFoundry
// 2) genhtml test/13-stability-pool/coverage-foundry.lcov -o test/13-stability-pool/coverage-foundry
// 3) open test/13-stability-pool/coverage-foundry/index.html in your browser and
//    navigate to the relevant source file to see line-by-line execution records

contract StabilityPoolCryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
      setup();

      // Foundry doesn't use config files but does
      // the setup programmatically here

      // target the fuzzer on this contract as it will
      // contain the handler functions
      targetContract(address(this));

      // handler functions to target during invariant tests
      bytes4[] memory selectors = new bytes4[](3);
      selectors[0] = this.handler_provideToSP.selector;
      selectors[1] = this.handler_registerLiquidation.selector;
      selectors[2] = this.handler_claimCollateralGains.selector;

      targetSelector(FuzzSelector({ addr: address(this), selectors: selectors }));
    }

    function invariant_property_stability_pool_solvent() public {
      t(property_stability_pool_solvent(), "Stability pool solvent");
    }    
}