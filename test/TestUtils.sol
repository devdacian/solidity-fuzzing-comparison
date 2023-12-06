// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// adapted from https://github.com/crytic/properties/blob/main/contracts/util/PropertiesHelper.sol#L240-L259
library TestUtils {

    // platform-agnostic input restriction to easily
    // port fuzz tests between different fuzzers
    function clampBetween(uint256 value, 
                          uint256 low, 
                          uint256 high
    ) internal pure returns (uint256) {
        if (value < low || value > high) {
            return (low + (value % (high - low + 1)));
        }
        return value;
    }
}

