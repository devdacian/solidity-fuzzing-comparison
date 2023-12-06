// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../TestUtils.sol";

// configure solc-select to use compiler version:
// solc-select use 0.8.23 
//
// run from base project directory with:
// echidna --config test/06-rarely-false/RarelyFalseBasicEchidna.yaml ./ --contract RarelyFalseBasicEchidna
// medusa --config test/06-rarely-false/RarelyFalseBasicMedusa.json fuzz
contract RarelyFalseBasicEchidna {

    uint256 constant private OFFSET = 1234;
    uint256 constant private POW    = 80;
    uint256 constant private LIMIT  = type(uint256).max - OFFSET;

    // Echidna is unable to break this assertion
    // Medusa can break it almost instantly
    // intentionally not view/pure for Medusa
    function testFuzz(uint256 n) public {
        n = TestUtils.clampBetween(n, 1, LIMIT);

        assert(rarelyFalse(n + OFFSET, POW));
    }

    function rarelyFalse(uint256 n, uint256 e) private pure returns(bool) {
        if(n % 2**e == 0) return false;
        return true;
    }


}
