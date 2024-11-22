// run from base folder:
// certoraRun test/09-vesting/certora.conf
methods {
    // `envfree` definitions to call functions without explicit `env`
    function TOTAL_POINTS_PCT() external returns (uint24) envfree;
}

// ghost variable to track sum of individual user points
persistent ghost mathint g_sum_user_points {
    init_state axiom g_sum_user_points == 0;
}

// hook SSTORE opcode on `Vesting::allocations` to update ghost variable
// whenever the allocation points mapping is updated
hook Sstore currentContract.allocations[KEY address recipient].points uint24 new_value (uint24 old_value) {
    g_sum_user_points = g_sum_user_points + new_value - old_value;    
}

// this isn't working as expected since Certora HAVOC
// g_sum_user_points so that it isn't equal to the sum of allocations.points
// not sure how to fix this as in the underlying contract this is
// enforced in the constructor so the state Certora is getting to
// is actually impossible to reach
invariant users_points_sum_eq_total_points()
    g_sum_user_points == to_mathint(currentContract.TOTAL_POINTS_PCT());