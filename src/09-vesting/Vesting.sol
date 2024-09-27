// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract Vesting {
    uint24 public constant TOTAL_POINTS = 100_000;

    struct AllocationInput {
        address recipient;
        uint24 points;
        uint8  vestingWeeks;
    }

    struct AllocationData {
        uint24 points;
        uint8  vestingWeeks;
        bool   claimed;
    }

    mapping(address recipient => AllocationData data) public allocations;

    constructor(AllocationInput[] memory allocInput) {
        uint256 inputLength = allocInput.length;
        require(inputLength > 0, "No allocations");

        uint24 totalPoints;
        for(uint256 i; i<inputLength; i++) {
            require(allocInput[i].points != 0, "Zero points invalid");
            require(allocations[allocInput[i].recipient].points == 0, "Already set");

            totalPoints += allocInput[i].points;
            require(totalPoints <= TOTAL_POINTS, "Too many points");

            allocations[allocInput[i].recipient].points = allocInput[i].points;
            allocations[allocInput[i].recipient].vestingWeeks = allocInput[i].vestingWeeks;
        }
        
        require(totalPoints == TOTAL_POINTS, "Not enough points");
    }

    // users entitled to an allocation can transfer their points to
    // another address if they haven't claimed
    function transferPoints(address to, uint24 points) external {
        require(points != 0, "Zero points invalid");

        AllocationData memory fromAllocation = allocations[msg.sender];
        require(fromAllocation.points >= points, "Insufficient points");
        require(!fromAllocation.claimed, "Already claimed");

        AllocationData memory toAllocation = allocations[to];

        // enforce identical vesting periods if `to` has an active vesting period
        if(toAllocation.vestingWeeks != 0) {
            require(fromAllocation.vestingWeeks == toAllocation.vestingWeeks, "Vesting mismatch");
        }

        allocations[msg.sender].points = fromAllocation.points - points;
        allocations[to].points = toAllocation.points + points;

        // if `to` had no active vesting period, copy from `from`
        if (toAllocation.vestingWeeks == 0) {
            allocations[to].vestingWeeks = fromAllocation.vestingWeeks;
        }
    }
}