// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

/**
 * @title Interest Rate Model (IRM) Interface
 * @notice This interface describes the publicly accessible functions implemented by the IRM contract.
 */
interface IIRM {
    /// Events
    event SetIRMForMarket(address indexed market, uint8[] tranches, IRMConfig[] configs);

    /**
     * @notice This structure defines the configuration for the interest rate model.
     * @dev It contains the kink utilization point, and the interest rates at 0%, kink, and 100% utilization.
     */
    struct IRMConfig {
        uint64 kink; // utilization at mid point (1e9 is 100%)
        uint64 start; // interest rate at 0% utlization
        uint64 mid; // interest rate at kink utlization
        uint64 end; // interest rate at 100% utlization
    }

    /**
     * @notice Calculates the interest rate for a specific market, tranche, total deposit, and total borrow.
     * @param _market The address of the market
     * @param _tranche The tranche number
     * @param _totalDeposit The total amount deposited in the market
     * @param _totalBorrow The total amount borrowed from the market
     * @return The calculated interest rate
     */

    function getInterestRate(address _market, uint8 _tranche, uint256 _totalDeposit, uint256 _totalBorrow)
        external
        view
        returns (uint256);

    /**
     * @notice Sets the IRM configuration for a specific market and tranches.
     * @param _market The address of the market
     * @param _tranches An array of tranche numbers
     * @param _configs An array of IRMConfig structures
     */
    function setIRMForMarket(address _market, uint8[] calldata _tranches, IRMConfig[] calldata _configs) external;
}
