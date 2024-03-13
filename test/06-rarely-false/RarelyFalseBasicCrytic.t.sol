// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RarelyFalseTargetFunctions} from "./RarelyFalseTargetFunctions.sol";
import {CryticAsserts} from "@chimera/CryticAsserts.sol";

// run from base project directory with:
// echidna --config test/06-rarely-false/RarelyFalseBasicEchidna.yaml ./ --contract RarelyFalseBasicCrytic
// medusa --config test/06-rarely-false/RarelyFalseBasicMedusa.json fuzz
contract RarelyFalseBasicCrytic is RarelyFalseTargetFunctions, CryticAsserts {
    
}
