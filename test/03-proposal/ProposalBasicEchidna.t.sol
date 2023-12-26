// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../src/03-proposal/Proposal.sol";

// configure solc-select to use compiler version:
// solc-select use 0.8.23 
//
// run from base project directory with:
// echidna --config test/03-proposal/ProposalBasicEchidna.yaml ./ --contract ProposalBasicEchidna
// medusa --config test/03-proposal/ProposalBasicMedusa.json fuzz
// note: medusa not working yet as it doesn't support configuring initial eth balance
contract ProposalBasicEchidna {

    // eth reward
    uint256 constant ETH_REWARD = 10e18;

    // allowed voters
    address[] voters;

    // contracts required for test
    Proposal prop;

    // constructor has to be payable if balanceContract > 0 in yaml config
    constructor() payable {
        // this contract given ETH_REWARD in yaml config

        // setup the allowed list of voters
        // make sure to use full address not just shorthand as Echidna
        // expands the address differently to Foundry & make sure to
        // use full addresses in yaml config `sender` list
        voters.push(address(0x1000000000000000000000000000000000000000));
        voters.push(address(0x2000000000000000000000000000000000000000));
        voters.push(address(0x3000000000000000000000000000000000000000));
        voters.push(address(0x4000000000000000000000000000000000000000));
        voters.push(address(0x5000000000000000000000000000000000000000));
        
        // setup contract to be tested
        prop = new Proposal{value:ETH_REWARD}(voters);

        // verify setup
        //
        // proposal has rewards
        assert(address(prop).balance == ETH_REWARD);
        // proposal is active
        assert(prop.isActive());
        // proposal has correct number of allowed voters
        assert(prop.getTotalAllowedVoters() == voters.length);
        // this contract is the creator
        assert(prop.getCreator() == address(this));

        // constrain fuzz test senders to the set of allowed voting addresses
        // done in yaml config

        // basic test with no advanced guiding of the fuzzer
        // Echidna is easily able to break the invariant!
    }

    // required to receive refund if proposal fails
    receive() external payable {}

    // event to raise if invariant broken to see interesting state
    event ProposalBalance(uint256 balance);

    // once the proposal has completed, all the eth should be distributed
    // either to the owner if the proposal failed or to the winners if
    // the proposal succeeded. no eth should remain forever stuck in the
    // contract
    function invariant_proposal_complete_all_rewards_distributed() public returns(bool) {
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
