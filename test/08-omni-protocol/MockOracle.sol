// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../../src/08-omni-protocol/interfaces/IOmniOracle.sol";

contract MockOracle is AccessControl, IOmniOracle {
    event SetPrice(address underlying, uint256 price);

    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    mapping(address => uint256) public prices;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(UPDATER_ROLE, msg.sender);
    }

    function setPrices(address[] calldata _underlyings, uint256[] calldata _prices) external onlyRole(UPDATER_ROLE) {
        require(_underlyings.length == _prices.length, "MockOracle::setPrices: bad data length");
        for (uint256 index = 0; index < _underlyings.length; ++index) {
            prices[_underlyings[index]] = _prices[index];
            emit SetPrice(_underlyings[index], _prices[index]);
        }
    }

    function getPrice(address _underlying) external view returns (uint256) {
        uint256 price = prices[_underlying];
        require(price != 0, "MockOracle::getPrice: no price available");
        return price;
    }
}
