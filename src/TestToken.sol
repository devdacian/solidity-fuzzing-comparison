// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {

    // mint initial supply to msg.sender. Used in test
    // setups so test setup can then distribute initial
    // tokens to different participants
    constructor(uint256 initialMint) ERC20("TTKN", "TTKN") {
        _mint(msg.sender, initialMint);
    }
}