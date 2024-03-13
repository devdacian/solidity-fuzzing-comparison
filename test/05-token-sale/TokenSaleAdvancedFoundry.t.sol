// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./TokenSaleBasicFoundry.t.sol";

// run from base project directory with:
// forge test --match-contract TokenSaleAdvancedFoundry
//
// get coverage report (see https://medium.com/@rohanzarathustra/forge-coverage-overview-744d967e112f):
// 1) forge coverage --report lcov --report-file test/05-token-sale/coverage-foundry-advanced.lcov --match-contract TokenSaleAdvancedFoundry
// 2) genhtml test/05-token-sale/coverage-foundry-advanced.lcov -o test/05-token-sale/coverage-foundry-advanced
// 3) open test/05-token-sale/coverage-foundry-advanced/index.html in your browser and
//    navigate to the relevant source file to see line-by-line execution records
contract TokenSaleAdvancedFoundry is TokenSaleBasicFoundry {

    function setUp() public override {
        // call parent first to setup test environment
        super.setUp();

        // advanced test with guiding of the fuzzer
        //
        // guide Foundry to focus only on the `tokenSale` contract
        //
        // advanced foundry is able to break both invariants!
        targetContract(address(tokenSale));
    }

    // invariants inherited from base contract
}
