// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./TokenSaleBasicEchidna.t.sol";

// configure solc-select to use compiler version:
// solc-select use 0.8.23 
//
// run from base project directory with:
// echidna --config test/05-token-sale/TokenSaleAdvancedEchidna.yaml ./ --contract TokenSaleAdvancedEchidna
contract TokenSaleAdvancedEchidna is TokenSaleBasicEchidna {

    // constructor has to be payable if balanceContract > 0 in yaml config
    constructor() payable TokenSaleBasicEchidna() {
        // advanced test with guiding of the fuzzer
        //
        // ideally we would like a quick way to just point Echidna
        // at only the `tokenSale` contract, but since I'm not aware
        // of one we just wrap every function from that contract
        // into this one.
        // 
        // Also in the yaml config set `allContracts: false`
        //
        // advanced echidna is able to break both invariants and find
        // much more simplified exploit chains than advanced foundry!
    }

    // dumb wrappers around the non-view `tokenSale` contract functions
    // would be nice if there was a simple way to just point Echidna
    // at the contract
    function buy(uint256 amountToBuy) public {
        hevm.prank(msg.sender);
        tokenSale.buy(amountToBuy);
    }

    function endSale() public {
        hevm.prank(msg.sender);
        tokenSale.endSale();
    }

    // invariants inherited from base contract
}
