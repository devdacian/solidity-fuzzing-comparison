// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {TargetFunctions} from "./TargetFunctions.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";
import {Test} from "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract RarelyFalseCryticToFoundry --fuzz-runs 2000000
//
// get coverage report ( can be imported into https://lcov-viewer.netlify.app/ )
// forge coverage --report lcov --report-file test/06-rarely-false/coverage-foundry-basic.lcov --match-contract RarelyFalseCryticToFoundry
contract RarelyFalseCryticToFoundry is Test, TargetFunctions, FoundryAsserts {

}
