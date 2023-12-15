// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

/**
 * @title SubAccount
 * @notice This library provides utility functions to handle sub-accounts using bytes32 types, where id is most significant bytes.
 */
library SubAccount {
    /**
     * @notice Combines an address and a sub-account identifier into a bytes32 account representation.
     * @param _sender The address component.
     * @param _subId The sub-account identifier component.
     * @return A bytes32 representation of the account.
     */
    function toAccount(address _sender, uint96 _subId) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_sender)) | (uint256(_subId) << 160));
    }

    /**
     * @notice Extracts the address component from a bytes32 account representation.
     * @param _account The bytes32 representation of the account.
     * @return The address component.
     */
    function toAddress(bytes32 _account) internal pure returns (address) {
        return address(uint160(uint256(_account)));
    }

    /**
     * @notice Extracts the sub-account identifier component from a bytes32 account representation.
     * @param _account The bytes32 representation of the account.
     * @return The sub-account identifier component.
     */
    function toSubId(bytes32 _account) internal pure returns (uint96) {
        return uint96(uint256(_account) >> 160);
    }
}
