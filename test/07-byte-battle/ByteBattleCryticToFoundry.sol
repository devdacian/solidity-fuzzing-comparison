// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {TargetFunctions} from "./TargetFunctions.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";
import {Test} from "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract ByteBattleCryticToFoundry
//
// get coverage report ( can be imported into https://lcov-viewer.netlify.app/ )
// forge coverage --report lcov --report-file test/07-byte-battle/coverage-foundry-basic.lcov --match-contract ByteBattleCryticToFoundry
contract ByteBattleCryticToFoundry is Test, TargetFunctions, FoundryAsserts {

}
