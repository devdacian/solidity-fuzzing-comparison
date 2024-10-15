// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { MockERC20 } from "../../src/MockERC20.sol";
import { StabilityPool } from "../../src/13-stability-pool/StabilityPool.sol";
import { BaseSetup } from "@chimera/BaseSetup.sol";

abstract contract Setup is BaseSetup {
    // contract being tested
    StabilityPool stabilityPool;

    // support contracts
    MockERC20 collateralToken;
    MockERC20 debtToken;

    // ghost variables
    address[] addressPool;
    uint8 internal ADDRESS_POOL_LENGTH;

    function setup() internal virtual override {
        addressPool.push(address(0x1111));
        addressPool.push(address(0x2222));
        ADDRESS_POOL_LENGTH = uint8(addressPool.length);

        collateralToken = new MockERC20("CT","CT");
        debtToken = new MockERC20("DT","DT");

        stabilityPool = new StabilityPool(debtToken, collateralToken);
    }
}