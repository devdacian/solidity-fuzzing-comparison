// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { TargetFunctions } from "./TargetFunctions.sol";
import { CryticAsserts } from "@chimera/CryticAsserts.sol";

// configure solc-select to use compiler version:
// solc-select install 0.8.23
// solc-select use 0.8.23
//
// run from base project directory with:
// echidna . --contract StabilityPoolCryticTester --config test/13-stability-pool/echidna.yaml
// medusa --config test/13-stability-pool/medusa.json fuzz
contract StabilityPoolCryticTester is TargetFunctions, CryticAsserts {
  constructor() payable {
    setup();
  }
}