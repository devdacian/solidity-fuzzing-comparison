// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Properties } from "./Properties.sol";
import { BaseTargetFunctions } from "@chimera/BaseTargetFunctions.sol";
import { IHevm, vm } from "@chimera/Hevm.sol";

abstract contract TargetFunctions is BaseTargetFunctions, Properties {

    uint80 internal constant MIN_DEBT = 1000e18;
    uint80 internal constant MIN_COLL = 10e18;

    // gets a random non-zero address from `Setup::addressPool`
    function _getRandomAddress(uint8 index) internal returns(address addr) {
        index = uint8(between(index, 0, ADDRESS_POOL_LENGTH - 1));
        addr = addressPool[index];
    }

    function handler_provideToSP(uint8 callerIndex, uint80 amount) external {
        address caller = _getRandomAddress(callerIndex);
        amount = uint80(between(amount, MIN_DEBT, type(uint80).max));

        vm.prank(address(this));
        debtToken.mint(caller, amount);

        vm.prank(caller);
        debtToken.approve(address(stabilityPool), amount);
        vm.prank(caller);
        stabilityPool.provideToSP(amount);
    }

    function handler_registerLiquidation(uint80 debtToOffset, uint80 seizedCollateral) external {
        debtToOffset = uint80(between(debtToOffset, MIN_DEBT, type(uint80).max));
        seizedCollateral = uint80(between(seizedCollateral, MIN_COLL, type(uint80).max));

        stabilityPool.registerLiquidation(debtToOffset, seizedCollateral);

        vm.prank(address(this));
        collateralToken.mint(address(stabilityPool), seizedCollateral);
    }

    function handler_claimCollateralGains(uint8 callerIndex) external {
        address caller = _getRandomAddress(callerIndex);

        vm.prank(caller);
        stabilityPool.claimCollateralGains();
    }
}