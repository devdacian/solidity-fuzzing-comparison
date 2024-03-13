// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Asserts} from "@chimera/Asserts.sol";

// target functions to test
abstract contract RarelyFalseTargetFunctions is Asserts {

    uint256 constant private OFFSET = 1234;
    uint256 constant private POW    = 80;
    uint256 constant private LIMIT  = type(uint256).max - OFFSET;

    // fuzzers call this function
    function test_RarelyFalse(uint256 n) external {
        // input preconditions
        n = between(n, 1, LIMIT);

        // assertion to break
        t(_rarelyFalse(n + OFFSET, POW), "Should not be false");
    }

     // actual implementation to test
    function _rarelyFalse(uint256 n, uint256 e) private pure returns(bool) {
        if(n % 2**e == 0) return false;
        return true;
    }

}
