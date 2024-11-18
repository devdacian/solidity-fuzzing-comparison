// run from base folder:
// certoraRun test/03-proposal/certora.conf
methods {
    // `envfree` definitions to call functions without explicit `env`
    function isActive() external returns (bool) envfree;
}

// define constants and require them later to prevent HAVOC into invalid state
definition MIN_FUNDING() returns uint256 = 1000000000000000000;
definition MIN_VOTERS()  returns uint256 = 3;
definition MAX_VOTERS()  returns uint256 = 9;

// Proposal state must be:
// 1) active with balance >= min_funding OR
// 2) not active with balance == 0
invariant proposal_complete_all_rewards_distributed()
    (isActive()  && nativeBalances[currentContract] >= MIN_FUNDING()) ||
    (!isActive() && nativeBalances[currentContract] == 0)
{
    // enforce state requirements to prevent HAVOC into invalid state
    preserved {
        // enforce valid total allowed voters
        require(currentContract.s_totalAllowedVoters >= MIN_VOTERS() &&
                currentContract.s_totalAllowedVoters <= MAX_VOTERS() &&
                // must be odd number
                currentContract.s_totalAllowedVoters % 2 == 1);

        // enforce valid for/against votes matches total current votes
        require(currentContract.s_votersFor.length +
                currentContract.s_votersAgainst.length
                == currentContract.s_totalCurrentVotes);

        // enforce that when a proposal is active, the total number of current
        // votes must be at maximum half the total allowed voters, since proposal
        // is automatically finalized once >= 51% votes are cast
        require(!isActive() || 
                    (isActive() && 
                    currentContract.s_totalCurrentVotes <= currentContract.s_totalAllowedVoters/2)
                );
    }
}