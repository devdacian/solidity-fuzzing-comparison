// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../src/03-proposal/Proposal.sol";

import "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract ProposalBasicFoundry -vvv
//
// get coverage report (see https://medium.com/@rohanzarathustra/forge-coverage-overview-744d967e112f):
// 1) forge coverage --report lcov --report-file test/03-proposal/coverage-foundry-basic.lcov --match-contract ProposalBasicFoundry
// 2) genhtml test/03-proposal/coverage-foundry-basic.lcov -o test/03-proposal/coverage-foundry-basic
// 3) open test/03-proposal/coverage-foundry-basic/index.html in your browser and
//    navigate to the relevant source file to see line-by-line execution records
contract ProposalBasicFoundry is Test {

    // eth reward
    uint256 constant ETH_REWARD = 10e18;

    // allowed voters
    address[] voters;

    // contracts required for test
    Proposal prop;

    function setUp() public virtual {
        // deal this contract the proposal reward
        deal(address(this), ETH_REWARD);

        // setup the allowed list of voters
        voters.push(address(0x1));
        voters.push(address(0x2));
        voters.push(address(0x3));
        voters.push(address(0x4));
        voters.push(address(0x5));
        
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
        for(uint256 i; i<voters.length; ++i) {
            targetSender(voters[i]);
        }

        // basic test with no advanced guiding of the fuzzer
        // Foundry is easily able to break the invariant!
    }

    // required to receive refund if proposal fails
    receive() external payable {}

    // event to raise if invariant broken to see interesting state
    event ProposalBalance(uint256 balance);

    // once the proposal has completed, all the eth should be distributed
    // either to the owner if the proposal failed or to the winners if
    // the proposal succeeded. no eth should remain forever stuck in the
    // contract
    function invariant_proposal_complete_all_rewards_distributed() public {
        uint256 proposalBalance = address(prop).balance;

        // only visible when invariant fails
        emit ProposalBalance(proposalBalance);

        assert(
            // either proposal is active and contract balance > 0 
            (prop.isActive() && proposalBalance > 0) ||

            // or proposal is not active and contract balance == 0
            (!prop.isActive() && proposalBalance == 0)
        );
    }
}
