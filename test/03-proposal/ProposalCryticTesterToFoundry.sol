// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Properties} from "./Properties.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";
import {Test} from "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract ProposalCryticTesterToFoundry -vvv
//
// get coverage report (see https://medium.com/@rohanzarathustra/forge-coverage-overview-744d967e112f):
// 1) forge coverage --report lcov --report-file test/03-proposal/coverage-foundry-basic.lcov --match-contract ProposalCryticTesterToFoundry
// 2) genhtml test/03-proposal/coverage-foundry-basic.lcov -o test/03-proposal/coverage-foundry-basic
// 3) open test/03-proposal/coverage-foundry-basic/index.html in your browser and
//    navigate to the relevant source file to see line-by-line execution records
contract ProposalCryticTesterToFoundry is Test, Properties, FoundryAsserts {
    function setUp() public virtual {
        setup();

        // constrain fuzz test senders to the set of allowed voting addresses
        for(uint256 i; i<voters.length; ++i) {
            targetSender(voters[i]);
        }
    }

    // wrap common invariants for foundry
    function invariant_proposal_complete_all_rewards_distributed() external {
        t(property_proposal_complete_all_rewards_distributed(), "All rewards distributed when proposal completed");
    }

}
