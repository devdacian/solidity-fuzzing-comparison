// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Priority } from "../../src/14-priority/Priority.sol";
import { BaseSetup } from "@chimera/BaseSetup.sol";

abstract contract Setup is BaseSetup {
    // contract being tested
    Priority priority;

    function setup() internal virtual override {
        priority = new Priority();
    }
}