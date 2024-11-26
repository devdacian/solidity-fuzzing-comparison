// run from base folder:
// certoraRun test/10-vesting-ext/certora.conf
//
// solution provided by https://x.com/alexzoid_eth
methods {
    // `envfree` definitions to call functions without explicit `env`
    function allocations(address) external returns (uint24, uint8, bool, uint96) envfree;
    function getUserTokenAllocation(uint24) external returns (uint96) envfree;
    function getUserMaxPreclaimable(uint96) external returns (uint96) envfree;
}

// reusable helper functions to get data from underlying contract
function userPointsCVL(address user) returns uint24 {
    uint24 points; uint8 vestingWeeks; bool claimed; uint96 preclaimed;
    (points, vestingWeeks, claimed, preclaimed) = allocations(user);
    return points;
}
function userPreclaimedCVL(address user) returns uint96 {
    uint24 points; uint8 vestingWeeks; bool claimed; uint96 preclaimed;
    (points, vestingWeeks, claimed, preclaimed) = allocations(user);
    return preclaimed;
}
function userMaxPreclaimableCVL(address user) returns uint96 {
    uint96 maxPreclaimable = getUserMaxPreclaimable(getUserTokenAllocation(userPointsCVL(user)));
    return maxPreclaimable;
}

// when a user who has preclaimed transfers their poinst to another
// address, the preclaimed amount should transfer over to prevent
// preclaiming more than allowed by transferring to new addresses
rule preclaimedTransferred(env e, address targetUser, uint24 points) {
    // enforce address sanity checks
    require e.msg.sender != currentContract && targetUser != currentContract &&
            e.msg.sender != 0 && targetUser != 0;

    // enforce sender already preclaimed
    require userPreclaimedCVL(e.msg.sender) == userMaxPreclaimableCVL(e.msg.sender);
    // enforce receiver has no points and not preclaimed
    require userPreclaimedCVL(targetUser) == 0 && userPointsCVL(targetUser) == 0;

    // perform successful points transfer transaction
    transferPoints(e, targetUser, points);

    // assert both sender and receiver have preclaimed correctly
    // updated from their updated points 
    assert userPreclaimedCVL(e.msg.sender) == userMaxPreclaimableCVL(e.msg.sender);
    assert userPreclaimedCVL(targetUser)   == userMaxPreclaimableCVL(targetUser);
}