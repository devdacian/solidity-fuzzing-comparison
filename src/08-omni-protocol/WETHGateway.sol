// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

import "./interfaces/IOmniToken.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/IWithUnderlying.sol";
import "./SubAccount.sol";

/**
 * @title WETHGateway
 * @notice Handles native ETH deposits directly to contract through WETH, but does not handle native ETH withdrawals.
 * @dev This contract serves as a gateway for handling deposits of native ETH, which are then wrapped into WETH tokens.
 */
contract WETHGateway is Initializable {
    using SubAccount for address;

    address public oweth;
    address public weth;
    uint96 private constant SUBACCOUNT_ID = 0;

    event Deposit(bytes32 indexed account, uint8 indexed trancheId, uint256 amount, uint256 share);

    /**
     * @notice Initializes the contract with the OWETH contract address.
     * @param _oweth The address of the OWETH contract.
     */
    function initialize(address _oweth) external initializer {
        address _weth = IWithUnderlying(_oweth).underlying();
        IWETH9(_weth).approve(_oweth, type(uint256).max);
        oweth = _oweth;
        weth = _weth;
    }

    /**
     * @notice Deposits native ETH to the contract, wraps it into WETH tokens, and handles the deposit operation
     * through the Omni Token contract.
     * @dev The function is payable to accept ETH deposits.
     * @param _subId The subscription ID related to the depositor's account.
     * @param _trancheId The identifier of the tranche where the deposit is occurring.
     * @return share The number of shares received in exchange for the deposited ETH.
     */
    function deposit(uint96 _subId, uint8 _trancheId) external payable returns (uint256 share) {
        bytes32 to = msg.sender.toAccount(_subId);
        IWETH9(weth).deposit{value: msg.value}();
        share = IOmniToken(oweth).deposit(SUBACCOUNT_ID, _trancheId, msg.value);
        IOmniToken(oweth).transfer(SUBACCOUNT_ID, to, _trancheId, share);
        emit Deposit(to, _trancheId, msg.value, share);
    }

    /**
     * @notice Fallback function that reverts if ETH is sent directly to the contract.
     * @dev Any attempts to send ETH directly to the contract will cause a transaction revert.
     */
    receive() external payable {
        revert("This contract should not accept ETH directly.");
    }
}
