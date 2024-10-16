// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Setup } from "./Setup.sol";
import { Asserts } from "@chimera/Asserts.sol";

abstract contract Properties is Setup, Asserts {

    function property_stability_pool_solvent() public view returns(bool result) {
        // TODO: implement this invariant. If you need to track additional
        // ghost variables, add them to `Setup` storage. The challenge
        // can be solved without any additional ghost variables
        result = true;
    }
}