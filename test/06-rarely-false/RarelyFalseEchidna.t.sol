// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

// configure solc-select to use compiler version:
// solc-select use 0.8.23 
//
// run from base project directory with:
// echidna --test-mode assertion ./ --contract RarelyFalseEchidna
contract RarelyFalseEchidna {

    uint256 constant private OFFSET = 1234;
    uint256 constant private POW    = 80;
    uint256 constant private LIMIT  = type(uint256).max - OFFSET;

    // constructor has to be payable if balanceContract > 0 in yaml config
    constructor() payable {}

    // Echidna is unable to break this assertion
    function testFuzz(uint256 n) public {
        if(n > 0 && n <= LIMIT) {
           assert(rarelyFalse(n + OFFSET, POW));
        }
    }

    function rarelyFalse(uint256 n, uint256 e) private pure returns(bool) {
        if(n % 2**e == 0) return false;
        return true;
    }


}
