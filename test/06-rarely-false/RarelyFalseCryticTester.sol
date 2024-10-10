// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {TargetFunctions} from "./TargetFunctions.sol";
import {CryticAsserts} from "@chimera/CryticAsserts.sol";

// run from base project directory with:
// echidna --config test/06-rarely-false/echidna.yaml ./ --contract RarelyFalseCryticTester
// medusa --config test/06-rarely-false/medusa.json fuzz
contract RarelyFalseCryticTester is TargetFunctions, CryticAsserts {
    
}
