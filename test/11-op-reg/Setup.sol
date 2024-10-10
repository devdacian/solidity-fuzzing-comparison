// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { OperatorRegistry } from "../../src/11-op-reg/OperatorRegistry.sol";
import { BaseSetup } from "@chimera/BaseSetup.sol";

abstract contract Setup is BaseSetup {
    // contract being tested
    OperatorRegistry operatorRegistry;

    // ghost variables
    address[] addressPool;
    uint256 internal ADDRESS_POOL_LENGTH;

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
        ADDRESS_POOL_LENGTH = addressPool.length;

        operatorRegistry = new OperatorRegistry();
    }
}