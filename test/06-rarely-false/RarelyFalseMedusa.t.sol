// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// run from base project directory with:
// medusa fuzz --assertion-mode --deployment-order "RarelyFalseMedusa"
contract RarelyFalseMedusa {
    
    uint256 constant private OFFSET = 1234;
    uint256 constant private POW    = 80;
    uint256 constant private LIMIT  = type(uint256).max - OFFSET;

    // Medusa:function being tested should not be declared view/pure
    //
    // Medusa is easily able to break this straight away
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