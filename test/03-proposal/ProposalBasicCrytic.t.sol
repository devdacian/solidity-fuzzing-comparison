// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ProposalProperties} from "./ProposalProperties.sol";
import {CryticAsserts} from "@chimera/CryticAsserts.sol";

// run from base project directory with:
// echidna --config test/03-proposal/ProposalBasicEchidna.yaml ./ --contract ProposalBasicCrytic
// medusa --config test/03-proposal/ProposalBasicMedusa.json fuzz
contract ProposalBasicCrytic is ProposalProperties, CryticAsserts {
    constructor() payable {
       setup();
    }
}
