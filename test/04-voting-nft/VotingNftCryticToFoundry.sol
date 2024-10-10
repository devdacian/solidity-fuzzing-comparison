// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Properties} from "./Properties.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";
import {Test} from "forge-std/Test.sol";

// run from base project directory with:
// forge test --match-contract VotingNftCryticToFoundry
//
// get coverage report (see https://medium.com/@rohanzarathustra/forge-coverage-overview-744d967e112f):
// 1) forge coverage --report lcov --report-file test/04-voting-nft/coverage-foundry-basic.lcov --match-contract VotingNftCryticToFoundry
// 2) genhtml test/04-voting-nft/coverage-foundry-basic.lcov -o test/04-voting-nft/coverage-foundry-basic
// 3) open test/04-voting-nft/coverage-foundry-basic/index.html in your browser and
//    navigate to the relevant source file to see line-by-line execution records
contract VotingNftCryticToFoundry is Test, Properties, FoundryAsserts {
    function setUp() public virtual {
        setup();

        // use specific attacker address; attacker has no assets or
        // any special permissions for the contract being attacked
        targetSender(address(0x1337));
    }

    // wrap common invariants for foundry
    function invariant_total_power_gt_zero_power_calc_start() external {
        t(property_total_power_gt_zero_power_calc_start(), "Total voting power not zero when power calculation starts");
    }

    function invariant_total_power_eq_init_max_power_calc_start() external {
        t(property_total_power_eq_init_max_power_calc_start(), "Total voting power correct when power calculation starts");
    }
}
