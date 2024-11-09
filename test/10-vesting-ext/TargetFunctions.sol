// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Properties } from "./Properties.sol";
import { BaseTargetFunctions } from "@chimera/BaseTargetFunctions.sol";
import { IHevm, vm } from "@chimera/Hevm.sol";

abstract contract TargetFunctions is BaseTargetFunctions, Properties {

    function handler_transferPoints(uint256 recipientIndex,
                                    uint256 senderIndex,
                                    uint24 pointsToTransfer) external {
        // get an index into the recipients array to randomly
        // select a valid recipient
        //
        // note: using `between` provided by Chimera instead of
        // Foundry's `bound` for cross-fuzzer compatibility
        recipientIndex = between(recipientIndex, 0, recipients.length-1);
        senderIndex    = between(senderIndex, 0, recipients.length-1);

        address sender = recipients[senderIndex];
        address recipient = recipients[recipientIndex];

        (uint24 senderMaxPoints, , , ) = vesting.allocations(sender);

        pointsToTransfer = uint24(between(pointsToTransfer, 1, senderMaxPoints));

        // note: using `vm` from Chimera's IHevm
        // for cross-fuzzer cheatcode compatibility
        vm.prank(sender);
        vesting.transferPoints(recipient, pointsToTransfer);
    }

    function handler_preclaim(uint256 userIndex) external {
        userIndex = between(userIndex, 0, recipients.length-1);

        address user = recipients[userIndex];

        vm.prank(user);
        uint96 userPreclaimed = vesting.preclaim();

        totalPreclaimed += userPreclaimed;
    }
}