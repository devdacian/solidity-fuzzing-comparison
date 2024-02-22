// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./NaiveReceiverBasicEchidna.t.sol";

// configure solc-select to use compiler version:
// solc-select use 0.8.23 
//
// run from base project directory with:
// echidna --config test/01-naive-receiver/NaiveReceiverAdvancedEchidna.yaml ./ --contract NaiveReceiverAdvancedEchidna
// medusa --config test/01-naive-receiver/NaiveReceiverAdvancedMedusa.json fuzz
contract NaiveReceiverAdvancedEchidna is NaiveReceiverBasicEchidna {

    // constructor has to be payable if balanceContract > 0 in yaml config
    constructor() payable NaiveReceiverBasicEchidna() {
        // advanced test with guiding of the fuzzer
        //
        // make this contract into a handler to wrap the pool's flashLoan()
        // function and instruct echidna to call it passing receiver's
        // address as the parameter.
        // 
        // This is done in the yaml configuration file by setting 
        // `allContracts: false` then creating a wrapper function in this 
        // contract. With `allContracts: false` fuzzing will only call 
        // functions in this or parent contracts.
        //
        // advanced echidna is able to break both invariants and find
        // much more simplified exploit chains than advanced foundry!
    }

    // wrapper around pool.flashLoan() to "guide" the fuzz test
    function flashLoanWrapper(uint256 borrowAmount) public {
        // instruct fuzzer to cap borrowAmount under pool's
        // available amount to prevent wasted runs
        //
        // commented out as echidna is faster at breaking the invariant
        // without this
        //borrowAmount = borrowAmount % INIT_ETH_POOL;

        // call underlying function being tested with the receiver address
        // to prevent wasted runs. Initially tried it with address as fuzz
        // input parameter but this was unable to break the harder invariant
        pool.flashLoan(address(receiver), borrowAmount);
    }

    // invariants inherited from base contract
}
