// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Asserts} from "@chimera/Asserts.sol";
import {VotingNftSetup} from "./VotingNftSetup.sol";

abstract contract VotingNftProperties is VotingNftSetup, Asserts {
    // two possible invariants in order of importance:
    //
    // 1) at power calculation timestamp, total voting power is not 0
    // breaking this invariant is very valuable but much harder
    // if it can break this invariant, it has pulled off the epic hack
    function property_total_power_gt_zero_power_calc_start() public view returns(bool) {
        return votingNft.getTotalPower() != 0;
    }


    // 2)  at power calculation timestamp, total voting power is equal
    //     to the initial max nft power
    // breaking this invariant is less valuable but much easier
    // if it can break this invariant, it has found the problem that would
    // then lead a human auditor to the big hack
    function property_total_power_eq_init_max_power_calc_start() public view returns(bool) {
        return votingNft.getTotalPower() == initMaxNftPower;
    }
}