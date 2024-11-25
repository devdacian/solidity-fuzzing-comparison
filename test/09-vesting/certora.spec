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


// the same property can also be expressed in another way:
// that the sum of users' individual points should always remain equal to TOTAL_POINTS
// this solution was provided by https://x.com/alexzoid_eth
methods {
    function TOTAL_POINTS_PCT() external returns uint24 envfree => ALWAYS(100000);
}

// tracks the address of user whose points have increased
ghost address targetUser;

// ghost mapping to track points for each user address
ghost mapping (address => mathint) ghostPoints {
    axiom forall address user. ghostPoints[user] >= 0 && ghostPoints[user] <= max_uint24;
}

// hook to verify storage reads match ghost state
hook Sload uint24 val allocations[KEY address user].points {
    require(require_uint24(ghostPoints[user]) == val);
} 

// hook to update ghost state on storage writes
// also tracks first user to receive a points increase
hook Sstore allocations[KEY address user].points uint24 val {
    // Update targetUser only if not set and points are increasing
    targetUser = (targetUser == 0 && val > ghostPoints[user]) ? user : targetUser;
    ghostPoints[user] = val;
}

function initialize_constructor(address user1, address user2, address user3) {
    // Only user1, user2, and user3 can have non-zero points
    require(forall address user. user != user1 && user != user2 && user != user3 => ghostPoints[user] == 0);
    // Sum of their points must equal total allocation (100%)
    require(ghostPoints[user1] + ghostPoints[user2] + ghostPoints[user3] == TOTAL_POINTS_PCT());
}

function initialize_env(env e) {
    // Ensure message sender is a valid address
    require(e.msg.sender != 0);
}

function initialize_users(address user1, address user2, address user3) {
    // Validate user addresses:
    // - Must be non-zero addresses
    require(user1 != 0 && user2 != 0 && user3 != 0);
    // - Must be unique addresses
    require(user1 != user2 && user1 != user3 && user2 != user3);
    // Initialize targetUser to zero address
    require(targetUser == 0);
}

// Verify that total points always equal TOTAL_POINTS_PCT (100%)
rule users_points_sum_eq_total_points(env e, address user1, address user2, address user3) {
    // Set up initial state
    initialize_constructor(user1, user2, user3);
    initialize_env(e);
    initialize_users(user1, user2, user3);

    // Execute any method with any arguments
    method f;
    calldataarg args;
    f(e, args);

    // Calculate points for targetUser if it's not one of the initial users
    mathint targetUserPoints = targetUser != user1 && targetUser != user2 && targetUser != user3 ? ghostPoints[targetUser] : 0;
    
    // Assert total points remain constant at 100%
    assert(ghostPoints[user1] + ghostPoints[user2] + ghostPoints[user3] + targetUserPoints == TOTAL_POINTS_PCT());

    // All other addresses must have zero points
    assert(forall address user. user != user1 && user != user2 && user != user3 && user != targetUser
        => ghostPoints[user] == 0
    );
}