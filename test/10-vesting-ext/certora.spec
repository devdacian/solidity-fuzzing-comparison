// run from base folder:
// certoraRun test/10-vesting-ext/certora.conf
methods {
    // `envfree` definitions to call functions without explicit `env`
    function getUserTokenAllocation(uint24) external returns (uint96) envfree;
    function getUserMaxPreclaimable(uint96) external returns (uint96) envfree;
}

// a user shouldn't be able to preclaim after transferring
// points if they have already preclaimed
rule preclaimed_cant_preclaim_after_transfer(address user, address newAddr) {
    // enforce that user has some allocated points
    uint24 userPointsPre = currentContract.allocations[user].points;
    require userPointsPre > 0;

    // enforce that user hasn't claimed but has preclaimed
    require !currentContract.allocations[user].claimed;

    // enforce user has preclaimed
    uint96 userPreclaimedPre = currentContract.allocations[user].preclaimed;
    require userPreclaimedPre == getUserMaxPreclaimable(getUserTokenAllocation(userPointsPre));

    // new address has no previous allocation
    require currentContract.allocations[newAddr].points == 0 &&
            currentContract.allocations[newAddr].preclaimed == 0 &&
            !currentContract.allocations[newAddr].claimed;

    // user transfers their points to new address
    env e1;
    require e1.msg.sender == user;
    transferPoints(e1, newAddr, userPointsPre);

    // attempt to preclaim again should revert
    env e2;
    require e2.msg.sender == newAddr;
    preclaim@withrevert(e2);

    assert lastReverted;
}