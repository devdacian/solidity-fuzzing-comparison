// run from base folder:
// certoraRun test/09-vesting/certora.conf

// there should exist no function f() that allows a user
// to increase their allocated points
rule user_cant_increase_points(address user) {
    // enforce that user has some allocated points
    uint24 userPointsPre = currentContract.allocations[user].points;
    require userPointsPre > 0;

    // user performs any arbitrary successful transaction f()
    env e;
    require e.msg.sender == user;
    method f;
    calldataarg args;
    f(e, args);

    // verify that no transaction exists which allows user to
    // increase their allocated points
    assert userPointsPre >= currentContract.allocations[user].points;
}