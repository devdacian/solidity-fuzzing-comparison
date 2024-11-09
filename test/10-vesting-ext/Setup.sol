// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { VestingExt } from "../../src/10-vesting-ext/VestingExt.sol";
import { BaseSetup } from "@chimera/BaseSetup.sol";

abstract contract Setup is BaseSetup {
    // contract being tested
    uint24 constant TOTAL_POINTS = 100_000;
    VestingExt vesting;

    // ghost variables
    address[] recipients;
    uint96 totalPreclaimed;
    uint96 MAX_PRECLAIMABLE;

    function setup() internal virtual override {
        // use two recipients with equal allocation
        recipients.push(address(0x1111));
        recipients.push(address(0x2222));

        // prepare allocation array
        VestingExt.AllocationInput[] memory inputs
            = new VestingExt.AllocationInput[](2);
        inputs[0].recipient = recipients[0];
        inputs[0].points = TOTAL_POINTS / 2;
        inputs[0].vestingWeeks = 10;
        inputs[1].recipient = recipients[1];
        inputs[1].points = TOTAL_POINTS / 2;
        inputs[1].vestingWeeks = 10;

        vesting = new VestingExt(inputs);

        // calculate and save total max preclaimable token amount
        for(uint256 i; i<inputs.length; i++) {
            MAX_PRECLAIMABLE
                += vesting.getUserMaxPreclaimable(
                       vesting.getUserTokenAllocation(inputs[0].points));
        }
    }
}