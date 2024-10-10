// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Proposal} from "../../src/03-proposal/Proposal.sol";
import {BaseSetup} from "@chimera/BaseSetup.sol";

abstract contract Setup is BaseSetup {

    // eth reward
    uint256 constant ETH_REWARD = 10e18;

    // allowed voters
    address[] voters;

    // contracts required for test
    Proposal prop;

    function setup() internal override {
        // this contract given ETH_REWARD in yaml config

        // setup the allowed list of voters
        // make sure to use full address not just shorthand as Echidna
        // expands the address differently to Foundry & make sure to
        // use full addresses in yaml config `sender` list
        voters.push(address(0x1000000000000000000000000000000000000000));
        voters.push(address(0x2000000000000000000000000000000000000000));
        voters.push(address(0x3000000000000000000000000000000000000000));
        voters.push(address(0x4000000000000000000000000000000000000000));
        voters.push(address(0x5000000000000000000000000000000000000000));
        
        // setup contract to be tested
        prop = new Proposal{value:ETH_REWARD}(voters);

        // verify setup
        //
        // proposal has rewards
        assert(address(prop).balance == ETH_REWARD);
        // proposal is active
        assert(prop.isActive());
        // proposal has correct number of allowed voters
        assert(prop.getTotalAllowedVoters() == voters.length);
        // this contract is the creator
        assert(prop.getCreator() == address(this));

        // constrain fuzz test senders to the set of allowed voting addresses
        // done in yaml config
    }

    // required to receive refund if proposal fails
    receive() external payable {}
}