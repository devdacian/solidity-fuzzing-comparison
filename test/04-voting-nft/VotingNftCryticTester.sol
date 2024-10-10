// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Properties} from "./Properties.sol";
import {CryticAsserts} from "@chimera/CryticAsserts.sol";

// run from base project directory with:
// echidna --config test/04-voting-nft/echidna.yaml ./ --contract VotingNftCryticTester
// medusa --config test/04-voting-nft/medusa.json fuzz
contract VotingNftCryticTester is Properties, CryticAsserts {
    constructor() payable {
       setup();
    }
}
