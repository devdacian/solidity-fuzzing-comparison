// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Setup } from "./Setup.sol";
import { Asserts } from "@chimera/Asserts.sol";

abstract contract Properties is Setup, Asserts {

    function property_stability_pool_solvent() public view returns(bool result) {
        uint256 totalClaimableRewards;

        // sum total claimable rewards for each possible user
        for(uint8 i; i<ADDRESS_POOL_LENGTH; i++) {
            address user = addressPool[i];

            totalClaimableRewards += stabilityPool.getDepositorCollateralGain(user);
        }

        // pool is solvent if the total claimable rewards are
        // lte its collateral token balance
        if(totalClaimableRewards <= collateralToken.balanceOf(address(stabilityPool)))
            result = true;
    }
}