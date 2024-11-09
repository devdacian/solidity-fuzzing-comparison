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

    function handler_liquidate(uint8 victimIndex) external {
        address victim = _getRandomAddress(victimIndex);

        try liquidateDos.liquidate(victim) {
            // update ghost variables
            delete userActiveMarketsCount[victim];

            for(uint8 marketId = liquidateDos.MIN_MARKET_ID();
                marketId <= liquidateDos.MAX_MARKET_ID();
                marketId++) {
                delete userActiveMarkets[victim][marketId];
            }
        }
        catch(bytes memory err) {
            bytes4[] memory allowedErrors = new bytes4[](2);
            allowedErrors[0] = ILiquidateDos.LiquidationsDisabled.selector;
            allowedErrors[1] = ILiquidateDos.LiquidateUserNotInAnyMarkets.selector;

            if(_isUnexpectedError(bytes4(err), allowedErrors)) {
                liquidateUnexpectedError = true;
            }
        }
    }

    // returns whether error was unexpected
    function _isUnexpectedError(
        bytes4 errorSelector,
        bytes4[] memory allowedErrors
    ) internal pure returns(bool isUnexpectedError) {
        for (uint256 i; i < allowedErrors.length; i++) {
            if (errorSelector == allowedErrors[i]) {
                return false;
            }
        }

        isUnexpectedError = true;
    }
}