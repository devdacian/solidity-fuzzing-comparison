// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {VotingNftProperties} from "./VotingNftProperties.sol";
import {CryticAsserts} from "@chimera/CryticAsserts.sol";

// run from base project directory with:
// echidna --config test/04-voting-nft/VotingNftBasicEchidna.yaml ./ --contract VotingNftBasicCrytic
// medusa --config test/04-voting-nft/VotingNftBasicMedusa.json fuzz
contract VotingNftBasicCrytic is VotingNftProperties, CryticAsserts {
    constructor() payable {
       setup();
    }
}
