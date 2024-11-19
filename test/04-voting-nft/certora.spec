// run from base folder:
// certoraRun test/04-voting-nft/certora.conf
methods {
    // `envfree` definitions to call functions without explicit `env`
    function getTotalPower()    external returns (uint256) envfree;
    function totalSupply()      external returns (uint256) envfree;
    function owner()            external returns (address) envfree;
    function ownerOf(uint256)   external returns (address) envfree;
    function balanceOf(address) external returns (uint256) envfree;
}

// define constants and require them later to prevent HAVOC into invalid state
definition PERCENTAGE_100() returns uint256 = 1000000000000000000000000000;

// given: safeMint() -> power calculation start time -> f()
// there should exist no f() where a permissionless attacker
// could nuke total power to 0 when power calculation starts
rule total_power_gt_zero_power_calc_start(address to, uint256 tokenId) {
    // enforce basic sanity checks on variables set during constructor
    require currentContract.s_requiredCollateral > 0 &&
            currentContract.s_powerCalcTimestamp > 0 &&
            currentContract.s_maxNftPower > 0 &&
            currentContract.s_nftPowerReductionPercent > 0 &&
            currentContract.s_nftPowerReductionPercent < PERCENTAGE_100();

    // enforce no nfts have yet been created; in practice some may
    // exist in storage though due to certora havoc
    require totalSupply() == 0 && getTotalPower() == 0;

    // enforce msg.sender as owner required to mint nfts
    env e1;
    require e1.msg.sender == currentContract.owner();

    // enforce block.timestamp < power calculation start time
    // so new nfts can still be minted
    require e1.block.timestamp < currentContract.s_powerCalcTimestamp;

    // first safeMint() succeeds
    safeMint(e1, to, tokenId);

    // sanity check results of first mint
    require totalSupply() == 1 && balanceOf(to) == 1 && ownerOf(tokenId) == to &&
            getTotalPower() == currentContract.s_maxNftPower;

    // perform any arbitrary successful transaction at power calculation
    // start time, where msg.sender is not an nft owner or an admin
    env e2;
    require e2.msg.sender != currentContract &&
            e2.msg.sender != to &&
            e2.msg.sender != currentContract.owner() &&
            balanceOf(e2.msg.sender) == 0 &&
            e2.block.timestamp == currentContract.s_powerCalcTimestamp;
    method f;
    calldataarg args;
    f(e2, args);

    // total power should not equal to 0
    assert getTotalPower() != 0;
}