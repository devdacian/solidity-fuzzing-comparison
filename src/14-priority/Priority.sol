// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// A simplified collateral priority queue used in multi-collateral
// borrowing protocols. The queue ensures that the riskiest collateral
// at the start of the queue is liquidated first such that the
// borrower's remaining collateral basket is more stable post-liquidation
//
// Challenge: write an invariant to test whether the collateral priority
// order is always maintained
contract Priority {
    using EnumerableSet for EnumerableSet.UintSet;

    error InvalidCollateralId();
    error CollateralAlreadyAdded();
    error CollateralNotAdded();
    error InvalidIndex();

    uint8 public constant MIN_COLLATERAL_ID = 1;
    uint8 public constant MAX_COLLATERAL_ID = 4;

    EnumerableSet.UintSet collateralPriority;

    function addCollateral(uint8 collateralId) external {
        if(collateralId < MIN_COLLATERAL_ID || collateralId > MAX_COLLATERAL_ID) revert InvalidCollateralId();

        if(!collateralPriority.add(collateralId)) revert CollateralAlreadyAdded();
    }

    function removeCollateral(uint8 collateralId) external {
        if(collateralId < MIN_COLLATERAL_ID || collateralId > MAX_COLLATERAL_ID) revert InvalidCollateralId();

        if(!collateralPriority.remove(collateralId)) revert CollateralNotAdded();
    }

    function getCollateralAtPriority(uint8 index) external view returns(uint8 val) {
        if(index >= MAX_COLLATERAL_ID) revert InvalidIndex();

        val = uint8(collateralPriority.at(index));
    }

}