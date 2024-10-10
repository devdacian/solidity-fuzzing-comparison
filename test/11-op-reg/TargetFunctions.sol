// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Properties } from "./Properties.sol";
import { BaseTargetFunctions } from "@chimera/BaseTargetFunctions.sol";
import { IHevm, vm } from "@chimera/Hevm.sol";

abstract contract TargetFunctions is BaseTargetFunctions, Properties {

    // gets a random non-zero address from `Setup::addressPool`
    function _getRandomAddress(uint256 index) internal returns(address addr) {
        index = between(index, 0, ADDRESS_POOL_LENGTH - 1);
        addr = addressPool[index];
    }

    function handler_register(uint256 callerIndex) external {
        address caller = _getRandomAddress(callerIndex);

        vm.prank(caller);
        operatorRegistry.register();
    }

    function handler_updateAddress(uint256 callerIndex, uint256 updateIndex) external {
        address caller = _getRandomAddress(callerIndex);
        address update = _getRandomAddress(updateIndex);

        vm.prank(caller);
        operatorRegistry.updateAddress(update);
    }
}