// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract OperatorRegistry {
    uint128 public numOperators;

    mapping(uint128 operatorId      => address operatorAddress) public operatorIdToAddress;
    mapping(address operatorAddress => uint128 operatorId) public operatorAddressToId;

    // anyone can register their address as an operator
    function register() external returns(uint128 newOperatorId) {
        require(operatorAddressToId[msg.sender] == 0, "Address already registered");

        newOperatorId = ++numOperators;

        operatorAddressToId[msg.sender] = newOperatorId;
        operatorIdToAddress[newOperatorId] = msg.sender;
    }

    // an operator can update their address
    function updateAddress(address newOperatorAddress) external {
        require(msg.sender != newOperatorAddress, "Updated address must be different");

        uint128 operatorId = _getOperatorIdSafe(msg.sender);

        operatorAddressToId[newOperatorAddress] = operatorId;
        operatorIdToAddress[operatorId] = newOperatorAddress;

        delete operatorAddressToId[msg.sender];
    }

    function _getOperatorIdSafe(address operatorAddress) internal view returns (uint128 operatorId) {
        operatorId = operatorAddressToId[operatorAddress];

        require(operatorId != 0, "Operator not registered");
    }
}
