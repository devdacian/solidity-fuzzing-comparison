// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RarelyFalseTargetFunctions} from "./RarelyFalseTargetFunctions.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";
import {Test} from "forge-std/Test.sol";

// run from base project directory with:
// orge test --match-contract RarelyFalseBasicFoundry --fuzz-runs 2000000
//
// get coverage report ( can be imported into https://lcov-viewer.netlify.app/ )
// forge coverage --report lcov --report-file test/06-rarely-false/coverage-foundry-basic.lcov --match-contract RarelyFalseBasicFoundry
contract RarelyFalseBasicFoundry is Test, RarelyFalseTargetFunctions, FoundryAsserts {

}
