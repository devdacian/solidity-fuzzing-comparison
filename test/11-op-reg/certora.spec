// run from base folder:
// certoraRun test/11-op-reg/certora.conf

// given two registered operators, there should be no f() that could
// corrupt the unique relationship between operator_id : operator_address
rule operator_addresses_have_unique_ids(address opAddr1, address opAddr2) {
    // enforce unique addresses in `operatorAddressToId` mapping
    require opAddr1 != opAddr2;

    uint128 op1AddrToId = currentContract.operatorAddressToId[opAddr1];
    uint128 op2AddrToId = currentContract.operatorAddressToId[opAddr2];

    // enforce valid and unique operator_ids in `operatorAddressToId` mapping
    require op1AddrToId != op2AddrToId && op1AddrToId > 0 && op2AddrToId > 0;

    // enforce matching addresses in `operatorIdToAddress` mapping
    require currentContract.operatorIdToAddress[op1AddrToId] == opAddr1 &&
            currentContract.operatorIdToAddress[op2AddrToId] == opAddr2;

    // perform any arbitrary successful transaction f()
    env e;
    method f;
    calldataarg args;
    f(e, args);

    // verify that no transaction exists which corrupts the uniqueness
    // property between operator_id : operator_address
    assert currentContract.operatorIdToAddress[op1AddrToId] !=
           currentContract.operatorIdToAddress[op2AddrToId];
}