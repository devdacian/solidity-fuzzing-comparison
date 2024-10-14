// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ILiquidateDos } from "../../src/12-liquidate-dos/LiquidateDos.sol";
import { Properties } from "./Properties.sol";
import { BaseTargetFunctions } from "@chimera/BaseTargetFunctions.sol";
import { IHevm, vm } from "@chimera/Hevm.sol";

abstract contract TargetFunctions is BaseTargetFunctions, Properties {

    // gets a random non-zero address from `Setup::addressPool`
    function _getRandomAddress(uint8 index) internal returns(address addr) {
        index = uint8(between(index, 0, ADDRESS_POOL_LENGTH - 1));
        addr = addressPool[index];
    }

    function handler_openPosition(uint8 callerIndex, uint8 marketId) external {
        address caller = _getRandomAddress(callerIndex);

        vm.prank(caller);
        liquidateDos.openPosition(marketId);

        // update ghost variables
        ++userActiveMarketsCount[caller];
        userActiveMarkets[caller][marketId] = true;
    }

    function handler_toggleLiquidations(bool toggle) external {
        liquidateDos.toggleLiquidations(toggle);
    }

    // TODO: re-write this handler to detect unexpected errors
    // and fail in that case. The most cross-fuzzer compatible way
    // appears to be:
    // 1) add a bool ghost variable to `Setup`
    // 2) add an invariant to `Properties` which fails if the bool is `true`
    // 3) set the bool in this handler if an unexpected error has occured
    //
    // Echidna, Medusa & Foundry will all fail with an invariant failure if
    // `liquidate` failed with an unexpected error
    function handler_liquidate(uint8 victimIndex) external {
        address victim = _getRandomAddress(victimIndex);

        liquidateDos.liquidate(victim);

        // update ghost variables
        delete userActiveMarketsCount[victim];

        for(uint8 marketId = liquidateDos.MIN_MARKET_ID();
            marketId <= liquidateDos.MAX_MARKET_ID();
            marketId++) {
            delete userActiveMarkets[victim][marketId];
        }
    }
}