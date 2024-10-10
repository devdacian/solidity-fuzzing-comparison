// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {VotingNftForFuzz} from "../../src/04-voting-nft/VotingNftForFuzz.sol";
import {BaseSetup} from "@chimera/BaseSetup.sol";

abstract contract Setup is BaseSetup {
    uint256 constant requiredCollateral       = 100000000000000000000;
    uint256 constant maxNftPower              = 1000000000000000000000000000;
    uint256 constant nftPowerReductionPercent = 100000000000000000000000000;
    uint256 constant nftsToMint               = 10;
    uint256 constant initMaxNftPower          = maxNftPower * nftsToMint;
    uint256 constant timeUntilPowerCalc       = 1000;

    uint256 powerCalcTimestamp;

    // contracts required for test
    VotingNftForFuzz votingNft;

    function setup() internal override {
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

        // advance time to power calculation start; we modify the
        // contract to use hard-coded constant instead of block.timestamp
        // such that the fuzzer can focus on probing the initial power
        // calculation state, without the fuzzer moving block.timestamp
        // passed the initial power calculation timestamp
        votingNft.setFuzzerConstantBlockTimestamp(powerCalcTimestamp);
    }
}