// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ByteBattleTargetFunctions} from "./ByteBattleTargetFunctions.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";
import {Test} from "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract ByteBattleBasicFoundry
//
// get coverage report ( can be imported into https://lcov-viewer.netlify.app/ )
// forge coverage --report lcov --report-file test/07-byte-battle/coverage-foundry-basic.lcov --match-contract ByteBattleBasicFoundry

contract ByteBattleBasicFoundry is Test, ByteBattleTargetFunctions, FoundryAsserts {

}
