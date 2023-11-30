// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/math/Math.sol";

//
// This contract is a simplified version of a real contract which
// was audited by Cyfrin in a private audit and contained the same bug.
//
// Your mission, should you choose to accept it, is to find that bug!
//
// This contract allows the creator to invite a select group of people
// to vote on something and provides an eth reward to the `for` voters
// if the proposal passes, otherwise refunds the reward to the creator.
// The creator of the contract is considered "Trusted".
//
// This contract has been intentionally simplified to remove much of
// the extra complexity in order to help you find the particular bug without
// other distractions. Please read the comments carefully as they note
// specific findings that are excluded as the implementation has been
// purposefully kept simple to help you focus on finding the harder
// to find and more interesting bug.
//
// This contract intentionally has no time-out period for the voting
// to complete; lack of a time-out period resulting in voting never
// completing is not a valid finding as this has been intentionally 
// omitted to simplify the codebase.
//
// This contract should only contain 1 intentional High finding, but
// if you find others they were not intentional :-) This contract should
// not be used in any live/production environment; it is purely an
// educational bug-hunting exercise based on a real-world example.
//
contract Proposal {
    // smallest amount proposal creator can fund contract with
    uint256 private constant MIN_FUNDING = 1 ether;

    // min/max number of voters
    uint256 private constant MIN_VOTERS  = 3;
    uint256 private constant MAX_VOTERS  = 9;

    // min quorum
    uint256 private constant MIN_QUORUM  = 51;

    // constants used for `voterState` in `s_voters` mapping
    uint8 private constant DISALLOWED    = 0;
    uint8 private constant ALLOWED       = 1;
    uint8 private constant VOTED         = 2;

    // only permitted addresses can vote, each address gets 1 vote
    mapping(address voter => uint8 voterState) private s_voters;

    // creator of this proposal. Any findings related to the creator
    // not being able to update this address are invalid; this has
    // intentionally been omitted to simplify the contract so you can
    // focus on finding the cool bug instead of lame/easy stuff. Proposal
    // creator is trusted to create the proposal from an address that
    // can receive eth
    address private s_creator;

    // total number of allowed voters
    uint256 private s_totalAllowedVoters;

    // total number of current votes
    uint256 private s_totalCurrentVotes;

    // list of users who voted for
    address[] private s_votersFor;

    // list of users who votes against
    address[] private s_votersAgainst;

    // whether voting has been completed
    bool private s_votingComplete;

    // create the contract
    constructor(address[] memory allowList) payable {
        // require minimum eth proposal reward
        require(msg.value >= MIN_FUNDING, "DP: Minimum 1 eth proposal reward required");

        // cache list length
        uint256 allowListLength = allowList.length;

        // perform some sanity checks. NOTE: checks for duplicate inputs
        // are performed by entity creating the proposal who is
        // supplying the eth and is trusted, so the contract intentionally
        // does not re-check for duplicate inputs. Findings related to
        // not checking for duplicate inputs are invalid.
        require(allowListLength >= MIN_VOTERS, "DP: Minimum 3 voters required");
        require(allowListLength <= MAX_VOTERS, "DP: Maximum 9 voters allowed");

        // odd number of voters required to simplify quorum check
        require(allowListLength % 2 != 0, "DP: Odd number of voters required");

        // cache total voters to prevent multiple storage writes
        uint256 totalVoters;

        // store addresses allowed to vote on this proposal
        for(; totalVoters<allowListLength; ++totalVoters) {
            // sanity check to prevent address(0) as a valid voter
            address voter = allowList[totalVoters];
            require(voter != address(0), "DP: address(0) not a valid voter");

            s_voters[voter] = ALLOWED;
        }

        // update storage of total voters only once
        s_totalAllowedVoters = totalVoters;

        // update the proposal creator
        s_creator = msg.sender;

        // eth stored in this contract to be distributed once
        // voting is complete
    }

    // record a vote
    function vote(bool voteInput) external {
        // prevent voting if already completed
        require(isActive(), "DP: voting has been completed on this proposal");

        // current voter
        address voter = msg.sender;

        // prevent voting if not allowed or already voted
        require(s_voters[voter] == ALLOWED, "DP: voter not allowed or already voted");

        // update storage to record that this user has voted
        s_voters[voter] = VOTED;

        // update storage to increment total current votes
        // and store new value on the stack
        uint256 totalCurrentVotes = ++s_totalCurrentVotes;

        // add user to either the `for` or `against` list
        if(voteInput) s_votersFor.push(voter);
        else s_votersAgainst.push(voter);

        // check if quorum has been reached. Quorum is reached
        // when at least 51% of the total allowed voters have cast
        // their vote. For example if there are 5 allowed voters:
        //
        // first votes For
        // second votes For
        // third votes Against
        //
        // Quorum has now been reached (3/5) and the vote will pass as
        // votesFor (2) > votesAgainst (1).
        //
        // This system of voting doesn't require a strict majority to
        // pass the proposal (it didn't require 3 For votes), it just
        // requires the quorum to be reached (enough people to vote)
        //
        if(totalCurrentVotes * 100 / s_totalAllowedVoters >= MIN_QUORUM) {
            // mark voting as having been completed
            s_votingComplete = true;

            // distribute the voting rewards
            _distributeRewards();
        }
    }

    // distributes rewards to the `for` voters if the proposal has
    // passed or refunds the rewards back to the creator if the proposal
    // failed
    function _distributeRewards() private {
        // get number of voters for & against
        uint256 totalVotesFor     = s_votersFor.length;
        uint256 totalVotesAgainst = s_votersAgainst.length;
        uint256 totalVotes        = totalVotesFor + totalVotesAgainst;

        // rewards to distribute or refund. This is guaranteed to be
        // greater or equal to the minimum funding amount by a check
        // in the constructor, and there is intentionally by design
        // no way to decrease or increase this amount. Any findings
        // related to not being able to increase/decrease the total
        // reward amount are invalid
        uint256 totalRewards = address(this).balance;

        // if the proposal was defeated refund reward back to the creator
        // for the proposal to be successful it must have had more `For` votes
        // than `Against` votes
        if(totalVotesAgainst >= totalVotesFor) {
            // proposal creator is trusted to create a proposal from an address
            // that can receive ETH. See comment before declaration of `s_creator`
            _sendEth(s_creator, totalRewards);
        }
        // otherwise the proposal passed so distribute rewards to the `For` voters
        else{
            uint256 rewardPerVoter = totalRewards / totalVotes;

            for(uint256 i; i<totalVotesFor; ++i) {
                // proposal creator is trusted when creating allowed list of voters,
                // findings related to gas griefing attacks or sending eth
                // to an address reverting thereby stopping the reward payouts are
                // invalid. Yes pull is to be preferred to push but this
                // has not been implemented in this simplified version to
                // reduce complexity & help you focus on finding the
                // harder to find bug

                // if at the last voter round up to avoid leaving dust; this means that
                // the last voter can get 1 wei more than the rest - this is not
                // a valid finding, it is simply how we deal with imperfect division
                if(i == totalVotesFor-1) {
                    rewardPerVoter = Math.mulDiv(totalRewards, 1, totalVotes, Math.Rounding.Up);
                }
                _sendEth(s_votersFor[i], rewardPerVoter);
            }
        }
    }

    // sends eth using low-level call as we don't care about returned data
    function _sendEth(address dest, uint256 amount) private {
        bool sendStatus;
        assembly {
            sendStatus := call(gas(), dest, amount, 0, 0, 0, 0)
        }
        require(sendStatus, "DP: failed to send eth");
    }

    // returns true if the proposal is active or false if finished,
    // used internally and also externally to validate setup
    function isActive() public view returns(bool) {
        return !s_votingComplete;
    }

    // returns total number of allowed voters, used externally to validate setup
    function getTotalAllowedVoters() external view returns(uint256) {
        return s_totalAllowedVoters;
    }
    
    // returns the proposal creator, used externally to validate setup
    function getCreator() external view returns(address) {
        return s_creator;
    }
}