// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Setup } from "./Setup.sol";
import { Asserts } from "@chimera/Asserts.sol";

abstract contract Properties is Setup, Asserts {

    function property_user_active_markets_correct() public view returns(bool result) {
        // for each possible user
        for(uint8 i; i<ADDRESS_POOL_LENGTH; i++) {
            address user = addressPool[i];

            // if they are active in at least 1 market
            if(userActiveMarketsCount[user] != 0) {
                // then iterate over all possible markets for that user
                // verifying their active markets in ghost variables
                // match what is stored in the underlying contract
                for(uint8 marketId = liquidateDos.MIN_MARKET_ID();
                    marketId <= liquidateDos.MAX_MARKET_ID();
                    marketId++) {
                    // if any irregularity occurs, immediately fail invariant
                    bool activeInGhost = userActiveMarkets[user][marketId];
                    bool activeInContract = liquidateDos.userActiveInMarket(user, marketId);

                    if(activeInGhost != activeInContract) return false;
                }
            }
        }

        result = true;
    }

    // TODO: write an additional invariant. If you need to track additional
    // ghost variables, add them to `Setup` storage
}