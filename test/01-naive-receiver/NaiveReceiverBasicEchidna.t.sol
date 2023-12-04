// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../src/01-naive-receiver/NaiveReceiverLenderPool.sol";
import "../../src/01-naive-receiver/FlashLoanReceiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// configure solc-select to use compiler version:
// solc-select use 0.8.23 
//
// run from base project directory with:
// echidna --config test/01-naive-receiver/NaiveReceiverBasicEchidna.yaml ./ --contract NaiveReceiverBasicEchidna
// medusa --config test/01-naive-receiver/NaiveReceiverMedusa.json fuzz
// note: medusa not working yet as it doesn't support configuring initial eth balance
contract NaiveReceiverBasicEchidna {
    using Address for address payable;

    // initial eth flash loan pool
    uint256 constant INIT_ETH_POOL     = 1000e18;
    // initial eth flash loan receiver
    uint256 constant INIT_ETH_RECEIVER = 10e18;

    // contracts required for test
    NaiveReceiverLenderPool pool;
    FlashLoanReceiver receiver;

    // constructor has to be payable if balanceContract > 0 in yaml config
    constructor() payable {
        // create contracts to be tested
        pool     = new NaiveReceiverLenderPool();
        receiver = new FlashLoanReceiver(payable(address(pool)));

        // set their initial eth balances by sending them ether. This contract
        // starts with `balanceContract` defined in yaml config
        payable(address(pool)).sendValue(INIT_ETH_POOL);
        payable(address(receiver)).sendValue(INIT_ETH_RECEIVER);

        // basic test with no advanced guiding of the fuzzer
        // echidna doesn't tell us how many fuzz runs reverted
        //
        // echidna is able to break invariant 2) but not 1)
    }

    // two possible invariants in order of importance:
    //
    // 1) receiver's balance is not 0
    // breaking this invariant is very valuable but much harder
    function echidna_receiver_balance_not_zero() public view returns (bool) {
        return(address(receiver).balance != 0);
    }

    // 2) receiver's balance is not less than starting balance
    // breaking this invariant is less valuable but much easier
    function echidna_receiver_balance_not_less_initial() public view returns (bool) {
       return(address(receiver).balance >= INIT_ETH_RECEIVER);
    }

}
