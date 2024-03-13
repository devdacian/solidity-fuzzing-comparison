// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ByteBattleTargetFunctions} from "./ByteBattleTargetFunctions.sol";
import {CryticAsserts} from "@chimera/CryticAsserts.sol";

// configure solc-select to use compiler version:
// solc-select use 0.8.23 
//
// run from base project directory with:
// echidna --config test/07-byte-battle/ByteBattleBasicEchidna.yaml ./ --contract ByteBattleBasicCrytic
// medusa --config test/07-byte-battle/ByteBattleBasicMedusa.json fuzz
contract ByteBattleBasicCrytic is ByteBattleTargetFunctions, CryticAsserts {

}
