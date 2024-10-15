// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Setup } from "./Setup.sol";
import { Asserts } from "@chimera/Asserts.sol";

abstract contract Properties is Setup, Asserts {

    function property_priority_order_correct() public view returns(bool result) {
        // TODO: implement this invariant. If you need to track additional
        // ghost variables, add them to `Setup` storage and update them in
        // `TargetFunctions` handlers
        result = true;
    }
}