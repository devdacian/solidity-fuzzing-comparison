// run from base folder:
// certoraRun test/09-vesting/certora.conf
methods {
    // `envfree` definitions to call functions without explicit `env`
    function TOTAL_POINTS() external returns (uint24) envfree;
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

invariant users_points_sum_eq_total_points()
    g_sum_user_points == to_mathint(currentContract.TOTAL_POINTS());