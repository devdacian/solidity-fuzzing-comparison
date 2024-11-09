// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Setup } from "./Setup.sol";
import { Asserts } from "@chimera/Asserts.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract Properties is Setup, Asserts {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet foundAddresses;

    function property_operator_ids_have_unique_addresses() public returns(bool result) {
        // first remove old found
        uint256 oldFoundLength = foundAddresses.length();
        if(oldFoundLength > 0) {
            address[] memory values = foundAddresses.values();

            for(uint256 i; i<oldFoundLength; i++) {
                foundAddresses.remove(values[i]);
            }
        }

        // then iterate over every current operator, fetch its address
        // and attempt to add it to the found set. If the add fails it is
        // a duplicate breaking the invariant
        uint128 numOperators = operatorRegistry.numOperators();
        if(numOperators > 0) {
            // operator ids start at 1
            for(uint128 operatorId = 1; operatorId <= numOperators; operatorId++) {
                if(!foundAddresses.add(operatorRegistry.operatorIdToAddress(operatorId))) {
                    return false;
                }
            }
        }

        result = true;
    }
}