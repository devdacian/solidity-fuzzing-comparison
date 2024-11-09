// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { LiquidateDos } from "../../src/12-liquidate-dos/LiquidateDos.sol";
import { BaseSetup } from "@chimera/BaseSetup.sol";

abstract contract Setup is BaseSetup {
    // contract being tested
    LiquidateDos liquidateDos;

    // ghost variables
    address[] addressPool;
    uint8 internal ADDRESS_POOL_LENGTH;

    // tracks open markets for each user, using different
    // method than the underlying implementation
    mapping(address user => uint8 activeMarketCount) userActiveMarketsCount;
    mapping(address user => mapping(uint8 marketId => bool userInMarket)) userActiveMarkets;

    // track unexpected errors
    bool liquidateUnexpectedError;

    function setup() internal virtual override {
        addressPool.push(address(0x1111));
        addressPool.push(address(0x2222));
        addressPool.push(address(0x3333));
        addressPool.push(address(0x4444));
        addressPool.push(address(0x5555));
        addressPool.push(address(0x6666));
        addressPool.push(address(0x7777));
        addressPool.push(address(0x8888));
        addressPool.push(address(0x9999));
        ADDRESS_POOL_LENGTH = uint8(addressPool.length);

        liquidateDos = new LiquidateDos();
    }
}