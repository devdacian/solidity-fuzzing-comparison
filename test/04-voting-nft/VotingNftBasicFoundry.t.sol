// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../src/04-voting-nft/VotingNftForFuzz.sol";

import "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract VotingNftBasicFoundry
//
// get coverage report (see https://medium.com/@rohanzarathustra/forge-coverage-overview-744d967e112f):
// 1) forge coverage --report lcov --report-file test/04-voting-nft/coverage-foundry-basic.lcov --match-contract VotingNftBasicFoundry
// 2) genhtml test/04-voting-nft/coverage-foundry-basic.lcov -o test/04-voting-nft/coverage-foundry-basic
// 3) open test/04-voting-nft/coverage-foundry-basic/index.html in your browser and
//    navigate to the relevant source file to see line-by-line execution records
contract VotingNftBasicFoundry is Test {

    uint256 constant requiredCollateral       = 100000000000000000000;
    uint256 constant maxNftPower              = 1000000000000000000000000000;
    uint256 constant nftPowerReductionPercent = 100000000000000000000000000;
    uint256 constant nftsToMint               = 10;
    uint256 constant initMaxNftPower          = maxNftPower * nftsToMint;
    uint256 constant timeUntilPowerCalc       = 1000;

    uint256 powerCalcTimestamp;

    // contracts required for test
    VotingNftForFuzz votingNft;

    function setUp() public virtual {
        powerCalcTimestamp = block.timestamp + timeUntilPowerCalc;

        // setup contract to be tested
        votingNft = new VotingNftForFuzz(requiredCollateral,
                                         powerCalcTimestamp,
                                         maxNftPower,
                                         nftPowerReductionPercent);

        // no nfts deployed yet so total power should be 0
        assert(votingNft.getTotalPower() == 0);

        // create 10 power nfts
        for(uint i=1; i<11; ++i) {
            votingNft.safeMint(address(0x1234), i);
        }

        // verify max power has been correctly increased
        assert(votingNft.getTotalPower() == initMaxNftPower);

        // this contract is the owner
        assert(votingNft.owner() == address(this));

        // use specific attacker address; attacker has no assets or
        // any special permissions for the contract being attacked
        targetSender(address(0x1337));

        // advance time to power calculation start; we modify the
        // contract to use hard-coded constant instead of block.timestamp
        // such that the fuzzer can focus on probing the initial power
        // calculation state, without the fuzzer moving block.timestamp
        // passed the initial power calculation timestamp
        votingNft.setFuzzerConstantBlockTimestamp(powerCalcTimestamp);

        // basic test with no advanced guiding of the fuzzer
        // Foundry is easily able to break the second easier
        // invariant but not the harder first invariant
    }

    // two possible invariants in order of importance:
    //
    // 1) at power calculation timestamp, total voting power is not 0
    // breaking this invariant is very valuable but much harder
    // if it can break this invariant, it has pulled off the epic hack
    function invariant_total_power_gt_zero_power_calc_start() public view {
        assert(votingNft.getTotalPower() != 0);
    }

    // 2)  at power calculation timestamp, total voting power is equal
    //     to the initial max nft power
    // breaking this invariant is less valuable but much easier
    // if it can break this invariant, it has found the problem that would
    // then lead a human auditor to the big hack
    function invariant_total_power_eq_init_max_power_calc_start() public view {
        assert(votingNft.getTotalPower() == initMaxNftPower);
    }
}
