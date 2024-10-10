// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Setup } from "./Setup.sol";
import { Asserts } from "@chimera/Asserts.sol";

abstract contract Properties is Setup, Asserts {

    // TODO: write an additional invariant. If you need to track additional
    // ghost variables, add them to `Setup` storage. The challenge
    // can be solved without any additional ghost variables
}