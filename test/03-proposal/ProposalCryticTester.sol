// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Properties} from "./Properties.sol";
import {CryticAsserts} from "@chimera/CryticAsserts.sol";

// run from base project directory with:
// echidna --config test/03-proposal/echidna.yaml ./ --contract ProposalCryticTester
// medusa --config test/03-proposal/medusa.json fuzz
contract ProposalCryticTester is Properties, CryticAsserts {
    constructor() payable {
       setup();
    }
}
