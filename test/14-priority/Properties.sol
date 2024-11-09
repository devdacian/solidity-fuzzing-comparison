// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Setup } from "./Setup.sol";
import { Asserts } from "@chimera/Asserts.sol";

abstract contract Properties is Setup, Asserts {

    function property_priority_order_correct() public view returns(bool result) {
        if(priority0 != 0) {
            if(priority.getCollateralAtPriority(0) != priority0) return false;
        }
        if(priority1 != 0) {
            if(priority.getCollateralAtPriority(1) != priority1) return false;
        }
        if(priority2 != 0) {
            if(priority.getCollateralAtPriority(2) != priority2) return false;
        }
        if(priority3 != 0) {
            if(priority.getCollateralAtPriority(3) != priority3) return false;
        }

        result = true;
    }
}