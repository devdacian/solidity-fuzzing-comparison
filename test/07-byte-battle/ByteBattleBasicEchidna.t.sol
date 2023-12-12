// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// configure solc-select to use compiler version:
// solc-select use 0.8.23 
//
// run from base project directory with:
// echidna --config test/07-byte-battle/ByteBattleBasicEchidna.yaml ./ --contract ByteBattleBasicEchidna
// medusa --config test/07-byte-battle/ByteBattleBasicMedusa.json fuzz
contract ByteBattleBasicEchidna {

    // Echidna can break it but Medusa can't
    // intentionally not pure/view for Medusa
    function testFuzz(bytes32 a, bytes32 b) public {
        require(a != b);
        assert(_convertIt(a) != _convertIt(b));
    }

    function _convertIt(bytes32 b) private pure returns (uint96) {
        return uint96(uint256(b) >> 160);
    }
}
