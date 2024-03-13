// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../src/04-voting-nft/VotingNftForFuzz.sol";

// configure solc-select to use compiler version:
// solc-select use 0.8.23 
//
// run from base project directory with:
// echidna --config test/04-voting-nft/VotingNftBasicEchidna.yaml ./ --contract VotingNftBasicEchidna
// medusa --config test/04-voting-nft/VotingNftBasicMedusa.json fuzz
contract VotingNftBasicEchidna {
    uint256 constant requiredCollateral       = 100000000000000000000;
    uint256 constant maxNftPower              = 1000000000000000000000000000;
    uint256 constant nftPowerReductionPercent = 100000000000000000000000000;
    uint256 constant nftsToMint               = 10;
    uint256 constant initMaxNftPower          = maxNftPower * nftsToMint;
    uint256 constant timeUntilPowerCalc       = 1000;

    uint256 powerCalcTimestamp;

    // contracts required for test
    VotingNftForFuzz votingNft;

    // constructor has to be payable if balanceContract > 0 in yaml config
    constructor() payable {
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
        // set in yaml config

        // advance time to power calculation start; we modify the
        // contract to use hard-coded constant instead of block.timestamp
        // such that the fuzzer can focus on probing the initial power
        // calculation state, without the fuzzer moving block.timestamp
        // passed the initial power calculation timestamp
        votingNft.setFuzzerConstantBlockTimestamp(powerCalcTimestamp);

        // basic test with no advanced guiding of the fuzzer
        // Echidna & Medusa are easily able to break the second easier
        // invariant but not the harder first invariant
    }

    // two possible invariants in order of importance:
    //
    // 1) at power calculation timestamp, total voting power is not 0
    // breaking this invariant is very valuable but much harder
    // if it can break this invariant, it has pulled off the epic hack
    function invariant_total_power_gt_zero_power_calc_start() public view returns(bool) {
        return(votingNft.getTotalPower() != 0);
    }

    // 2)  at power calculation timestamp, total voting power is equal
    //     to the initial max nft power
    // breaking this invariant is less valuable but much easier
    // if it can break this invariant, it has found the problem that would
    // then lead a human auditor to the big hack
    function invariant_total_power_eq_init_max_power_calc_start() public view returns(bool) {
        return(votingNft.getTotalPower() == initMaxNftPower);
    }
}
