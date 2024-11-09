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

        // update ghost variables with expected order
        if(priority0 == 0) priority0 = collateralId;
        else if(priority1 == 0) priority1 = collateralId;
        else if(priority2 == 0) priority2 = collateralId;
        else priority3 = collateralId;
    }

    function handler_removeCollateral(uint8 collateralId) external {
        collateralId = uint8(between(collateralId,
                                       priority.MIN_COLLATERAL_ID(),
                                       priority.MAX_COLLATERAL_ID()));

        priority.removeCollateral(collateralId);

        // update ghost variables with expected order
        if(priority0 == collateralId) {
            priority0 = priority1;
            priority1 = priority2;
            priority2 = priority3;
        }
        else if(priority1 == collateralId) {
            priority1 = priority2;
            priority2 = priority3;
        }
        else if(priority2 == collateralId) {
            priority2 = priority3;
        }
        
        delete priority3;
    }
}