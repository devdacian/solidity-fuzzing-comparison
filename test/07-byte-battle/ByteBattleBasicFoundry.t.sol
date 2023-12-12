// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract ByteBattleBasicFoundry
//
// get coverage report ( can be imported into https://lcov-viewer.netlify.app/ )
// forge coverage --report lcov --report-file test/07-byte-battle/coverage-foundry-basic.lcov --match-contract ByteBattleBasicFoundry

contract ByteBattleBasicFoundry is Test {

    // Foundry can break it
    function testFuzz(bytes32 a, bytes32 b) public pure {
        vm.assume(a != b);
        assert(_convertIt(a) != _convertIt(b));
    }

    function _convertIt(bytes32 b) private pure returns (uint96) {
        return uint96(uint256(b) >> 160);
    }
}
