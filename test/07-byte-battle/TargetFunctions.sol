// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Asserts} from "@chimera/Asserts.sol";

// target functions to test
abstract contract TargetFunctions is Asserts {

    // fuzzers call this function
    function test_ByteBattle(bytes32 a, bytes32 b) external {
        // input precondition
        precondition(a != b);

        // assertion to break
        t(_convertIt(a) != _convertIt(b), "Different inputs should not convert to the same value");
    }

    // actual implementation to test
    function _convertIt(bytes32 b) private pure returns (uint96) {
        return uint96(uint256(b) >> 160);
    }
}
