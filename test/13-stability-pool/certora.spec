// run from base folder:
// certoraRun test/13-stability-pool/certora.conf
methods {
    // `envfree` definitions to call functions without explicit `env`
    function getDepositorCollateralGain(address) external returns (uint256) envfree;
}

// stability pool depositors should not be able to drain the stability
// pool; the stability pool should always hold enough colleteral tokens
// to pay out rewards owed to depositors
rule stability_pool_solvent(address spDep1, address spDep2) {
    // enforce address sanity checks
    require spDep1 != spDep2 &&
            spDep1 != currentContract &&
            spDep1 != currentContract.debtToken &&
            spDep1 != currentContract.collateralToken &&
            spDep2 != currentContract &&
            spDep2 != currentContract.debtToken &&
            spDep2 != currentContract.collateralToken;

    // enforce neither user has active deposits or rewards
    require currentContract.accountDeposits[spDep1].amount     == 0 &&
            currentContract.accountDeposits[spDep1].timestamp  == 0 &&
            currentContract.depositSnapshots[spDep1].P         == 0 &&
            currentContract.depositSnapshots[spDep1].scale     == 0 &&
            currentContract.depositSnapshots[spDep1].epoch     == 0 &&
            currentContract.depositSums[spDep1]                == 0 &&
            currentContract.collateralGainsByDepositor[spDep1] == 0 &&
            currentContract.accountDeposits[spDep2].amount     == 0 &&
            currentContract.accountDeposits[spDep2].timestamp  == 0 &&
            currentContract.depositSnapshots[spDep2].P         == 0 &&
            currentContract.depositSnapshots[spDep2].scale     == 0 &&
            currentContract.depositSnapshots[spDep2].epoch     == 0 &&
            currentContract.depositSums[spDep2]                == 0 &&
            currentContract.collateralGainsByDepositor[spDep2] == 0;

    // enforce that both users have tokens to deposit into stability pool
    env e;
    uint256 user1DebtTokens = currentContract.debtToken.balanceOf(e, spDep1);
    uint256 user2DebtTokens = currentContract.debtToken.balanceOf(e, spDep2);
    require user1DebtTokens >= 1000000000000000000 && user2DebtTokens >= 1000000000000000000 &&
            user1DebtTokens == user2DebtTokens;
        
    // both users deposit their debt tokens into the stability pool
    env e1;
    require e1.msg.sender == spDep1;
    provideToSP(e1, user1DebtTokens);
    env e2;
    require e2.msg.sender == spDep2;
    provideToSP(e2, user2DebtTokens);

    // stability pool is used to offset debt from a liquidation
    uint256 debtTokensToOffset = require_uint256(user1DebtTokens + user2DebtTokens);
    uint256 seizedCollateral = debtTokensToOffset; // 1:1
    env e3;
    registerLiquidation(e3, debtTokensToOffset, seizedCollateral);

    require(currentContract.collateralToken.balanceOf(e, currentContract) == seizedCollateral);

    // enforce each user is owed same reward since they deposited the same
    uint256 rewardPerUser = getDepositorCollateralGain(spDep1);
    require rewardPerUser > 0;
    require rewardPerUser == getDepositorCollateralGain(spDep2);

    // enforce contract has enough reward tokens to pay both users
    require(currentContract.collateralToken.balanceOf(e, currentContract) >= require_uint256(rewardPerUser * 2));

    // first user withdraws their reward
    env e4;
    require e4.msg.sender == spDep1;
    claimCollateralGains(e4);

    // enforce contract has enough reward tokens to pay second user
    require(currentContract.collateralToken.balanceOf(e, currentContract) >= rewardPerUser);
    
    // first user perform any arbitrary successful transaction f()
    env e5;
    require e5.msg.sender == spDep1;
    method f;
    calldataarg args;
    f(e5, args);

    // second user withdraws their reward
    env e6;
    require e6.msg.sender == spDep2 &&
            e6.msg.value  == 0;
    claimCollateralGains@withrevert(e6);

    // verify first user was not able to do anything that would make
    // second user's withdrawal revert
    assert !lastReverted;
}