// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Asserts} from "@chimera/Asserts.sol";
import {Setup} from "./Setup.sol";

abstract contract Properties is Setup, Asserts {

    // event to raise if invariant broken to see interesting state
    event ProposalBalance(uint256 balance);

    // once the proposal has completed, all the eth should be distributed
    // either to the owner if the proposal failed or to the winners if
    // the proposal succeeded. no eth should remain forever stuck in the
    // contract
    function property_proposal_complete_all_rewards_distributed() public returns(bool) {
        uint256 proposalBalance = address(prop).balance;

        // only visible when invariant fails
        emit ProposalBalance(proposalBalance);

        return(
            // either proposal is active and contract balance > 0 
            (prop.isActive() && proposalBalance > 0) ||

            // or proposal is not active and contract balance == 0
            (!prop.isActive() && proposalBalance == 0)
        );
    }
}