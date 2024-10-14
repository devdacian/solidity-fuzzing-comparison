// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface ILiquidateDos {
    error InvalidMarketId();
    error UserAlreadyInMarket();
    error LiquidationsDisabled();
    error LiquidateUserNotInAnyMarkets();
}

contract LiquidateDos is ILiquidateDos {
    using EnumerableSet for EnumerableSet.UintSet;

    // 10 possible markets for users to trade in
    uint8 public constant MIN_MARKET_ID = 1;
    uint8 public constant MAX_MARKET_ID = 10;

    bool liquidationsEnabled;

    // tracks open markets for each user
    mapping(address user => EnumerableSet.UintSet activeMarkets) userActiveMarkets;

    // users can only have 1 open position in each market
    function openPosition(uint8 marketId) external {
        if(marketId < MIN_MARKET_ID || marketId > MAX_MARKET_ID) revert InvalidMarketId();

        if(!userActiveMarkets[msg.sender].add(marketId)) revert UserAlreadyInMarket();
    }

    function toggleLiquidations(bool toggle) external {
        liquidationsEnabled = toggle;
    }

    function liquidate(address user) external {
        if(!liquidationsEnabled) revert LiquidationsDisabled();

        uint8 userActiveMarketsNum = uint8(userActiveMarkets[user].length());
        if(userActiveMarketsNum == 0) revert LiquidateUserNotInAnyMarkets();

        // in our simple implementation users are always liquidated
        for(uint8 i; i<userActiveMarketsNum; i++) {
            uint8 marketId = uint8(userActiveMarkets[user].at(i));
            userActiveMarkets[user].remove(marketId);
        }
    }

    function userActiveInMarket(address user, uint8 marketId) external view returns(bool isActive) {
        isActive = userActiveMarkets[user].contains(marketId);
    }
}
