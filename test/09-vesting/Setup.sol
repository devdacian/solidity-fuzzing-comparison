// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Vesting } from "../../src/09-vesting/Vesting.sol";
import { BaseSetup } from "@chimera/BaseSetup.sol";

abstract contract Setup is BaseSetup {
    // contract being tested
    uint24 constant TOTAL_POINTS = 100_000;
    Vesting vesting;

    // ghost variables
    address[] recipients;

    function setup() internal virtual override {
        // use two recipients with equal allocation
        recipients.push(address(0x1111));
        recipients.push(address(0x2222));

        // prepare allocation array
        Vesting.AllocationInput[] memory inputs
            = new Vesting.AllocationInput[](2);
        inputs[0].recipient = recipients[0];
        inputs[0].points = TOTAL_POINTS / 2;
        inputs[0].vestingWeeks = 10;
        inputs[1].recipient = recipients[1];
        inputs[1].points = TOTAL_POINTS / 2;
        inputs[1].vestingWeeks = 10;

        vesting = new Vesting(inputs);
    }
}