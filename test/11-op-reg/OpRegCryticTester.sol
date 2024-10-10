// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { TargetFunctions } from "./TargetFunctions.sol";
import { CryticAsserts } from "@chimera/CryticAsserts.sol";

// configure solc-select to use compiler version:
// solc-select install 0.8.23
// solc-select use 0.8.23
//
// run from base project directory with:
// echidna . --contract OpRegCryticTester --config test/11-op-reg/echidna.yaml
// medusa --config test/11-op-reg/medusa.json fuzz
contract OpRegCryticTester is TargetFunctions, CryticAsserts {
  constructor() payable {
    setup();
  }
}