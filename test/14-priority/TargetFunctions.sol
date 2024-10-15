// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Properties } from "./Properties.sol";
import { BaseTargetFunctions } from "@chimera/BaseTargetFunctions.sol";
import { IHevm, vm } from "@chimera/Hevm.sol";

abstract contract TargetFunctions is BaseTargetFunctions, Properties {

    function handler_addCollateral(uint8 collateralId) external {
        collateralId = uint8(between(collateralId,
                                       priority.MIN_COLLATERAL_ID(),
                                       priority.MAX_COLLATERAL_ID()));

        priority.addCollateral(collateralId);
    }

    function handler_removeCollateral(uint8 collateralId) external {
        collateralId = uint8(between(collateralId,
                                       priority.MIN_COLLATERAL_ID(),
                                       priority.MAX_COLLATERAL_ID()));

        priority.removeCollateral(collateralId);
    }
}