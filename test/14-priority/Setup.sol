// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Priority } from "../../src/14-priority/Priority.sol";
import { BaseSetup } from "@chimera/BaseSetup.sol";

abstract contract Setup is BaseSetup {
    // contract being tested
    Priority priority;

    // ghost variables
    uint8 priority0;
    uint8 priority1;
    uint8 priority2;
    uint8 priority3;

    function setup() internal virtual override {
        priority = new Priority();
    }
}