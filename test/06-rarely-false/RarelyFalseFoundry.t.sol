// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract RarelyFalseFoundry
//
// get coverage report ( can be imported into https://lcov-viewer.netlify.app/ )
// forge coverage --report lcov --report-file test/06-rarely-false/coverage-foundry-basic.lcov --match-contract RarelyFalseFoundry

contract RarelyFalseFoundry is Test {

    uint256 constant private OFFSET = 1234;
    uint256 constant private POW    = 80;
    uint256 constant private LIMIT  = type(uint256).max - OFFSET;

    function setUp() public virtual {}

    // Foundry is unable to break this assertion
    function testFuzz(uint256 n) public {
        n = bound(n, 1, LIMIT);

        assert(rarelyFalse(n + OFFSET, POW));
        
    }

    function rarelyFalse(uint256 n, uint256 e) private pure returns(bool) {
        if(n % 2**e == 0) return false;
        return true;
    }
}
