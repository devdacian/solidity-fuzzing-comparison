// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {TargetFunctions} from "./TargetFunctions.sol";
import {CryticAsserts} from "@chimera/CryticAsserts.sol";

// configure solc-select to use compiler version:
// solc-select use 0.8.23 
//
// run from base project directory with:
// echidna --config test/07-byte-battle/echidna.yaml ./ --contract ByteBattleCryticTester
// medusa --config test/07-byte-battle/medusa.json fuzz
contract ByteBattleCryticTester is TargetFunctions, CryticAsserts {

}
