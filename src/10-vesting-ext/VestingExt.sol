// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract VestingExt {
    uint24  public  constant TOTAL_POINTS_PCT   = 100_000;
    uint256 public  constant TOTAL_PRECLAIM_PCT = 100;
    uint256 public  constant MAX_PRECLAIM_PCT   =  10;
    uint96  public  constant TOTAL_TOKEN_ALLOCATION = 1_000_000e18;

    struct AllocationInput {
        address recipient;
        uint24  points;
        uint8   vestingWeeks;
    }

    struct AllocationData {
        uint24  points;
        uint8   vestingWeeks;
        bool    claimed;
        uint96  preclaimed;
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
            require(totalPoints <= TOTAL_POINTS_PCT, "Too many points");

            allocations[allocInput[i].recipient].points = allocInput[i].points;
            allocations[allocInput[i].recipient].vestingWeeks = allocInput[i].vestingWeeks;
        }
        
        require(totalPoints == TOTAL_POINTS_PCT, "Not enough points");
    }

    // users entitled to an allocation can transfer their points to
    // another address if they haven't claimed
    function transferPoints(address to, uint24 points) external {
        require(msg.sender != to, "Self transfer invalid");
        require(points != 0, "Zero points invalid");

        AllocationData memory fromAllocation = allocations[msg.sender];
        require(fromAllocation.points >= points, "Insufficient points");
        require(!fromAllocation.claimed, "Already claimed");

        AllocationData memory toAllocation = allocations[to];
        require(!toAllocation.claimed, "Already claimed");

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

    // calculates how many tokens user is entitled to based on their points
    function getUserTokenAllocation(uint24 points) public pure returns(uint96 allocatedTokens) {
        allocatedTokens = (points * TOTAL_TOKEN_ALLOCATION) / TOTAL_POINTS_PCT;
    }

    // calculates max preclaimable token amount given a user's total allocated tokens
    function getUserMaxPreclaimable(uint96 allocatedTokens) public pure returns(uint96 maxPreclaimable) {
        // unsafe cast OK here
        maxPreclaimable
            = uint96(MAX_PRECLAIM_PCT * allocatedTokens/ TOTAL_PRECLAIM_PCT);
    }

    // allows users to preclaim part of their token allocation
    function preclaim() external returns(uint96 userPreclaimAmount) {
        AllocationData memory userAllocation = allocations[msg.sender];

        require(userAllocation.preclaimed == 0, "Already preclaimed");

        userPreclaimAmount = getUserMaxPreclaimable(getUserTokenAllocation(userAllocation.points));
        require(userPreclaimAmount > 0, "Zero preclaim amount");

        allocations[msg.sender].preclaimed = userPreclaimAmount;
    }
}