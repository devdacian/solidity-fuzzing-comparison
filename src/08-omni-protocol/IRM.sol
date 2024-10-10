// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

import "./interfaces/IIRM.sol";

/**
 * @title Interest Rate Model (IRM) Contract
 * @notice This contract defines the interest rate model for different markets and tranches.
 * @dev It inherits from the IIRM interface and the AccessControl contract from the OpenZeppelin library.
 * @dev It is important that contracts that integrate this IRM appropriately scale interest rate values.
 */
contract IRM is IIRM, AccessControl, Initializable {
    uint256 public constant UTILIZATION_SCALE = 1e9;
    uint256 public constant MAX_INTEREST_RATE = 10e9; // Scale must match OmniToken.sol, 1e9
    mapping(address => mapping(uint8 => IRMConfig)) public marketIRMConfigs;

    /**
     * @notice Initializes the admin role with the contract deployer/upgrader.
     * @param _admin The address of the multisig admin.
     */
    function initialize(address _admin) external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /**
     * @notice Calculates the interest rate for a specific OmniToken market, tranche, total deposit and total borrow.
     * @param _market The address of the market
     * @param _tranche The tranche number
     * @param _totalDeposit The total amount deposited in the market
     * @param _totalBorrow The total amount borrowed from the market
     * @return The calculated interest rate
     */
    function getInterestRate(address _market, uint8 _tranche, uint256 _totalDeposit, uint256 _totalBorrow)
        external
        view
        returns (uint256)
    {
        uint256 utilization;
        if (_totalBorrow <= _totalDeposit) {
            utilization = _totalDeposit == 0 ? 0 : (_totalBorrow * UTILIZATION_SCALE) / _totalDeposit;
        } else {
            utilization = UTILIZATION_SCALE;
        }
        return _getInterestRateLinear(marketIRMConfigs[_market][_tranche], utilization);
    }

    /**
     * @notice Internal function to calculate the interest rate linearly based on utilization and IRMConfig.
     * @param _config The IRM configuration structure
     * @param _utilization The current utilization rate
     * @return interestRate The calculated interest rate
     */
    function _getInterestRateLinear(IRMConfig memory _config, uint256 _utilization)
        internal
        pure
        returns (uint256 interestRate)
    {
        if (_config.kink == 0) {
            revert("IRM::_getInterestRateLinear: Interest config not set.");
        }
        if (_utilization <= _config.kink) {
            interestRate = _config.start;
            interestRate += (_utilization * (_config.mid - _config.start)) / _config.kink;
        } else {
            interestRate = _config.mid;
            interestRate +=
                ((_utilization - _config.kink) * (_config.end - _config.mid)) / (UTILIZATION_SCALE - _config.kink);
        }
    }

    /**
     * @notice Sets the IRM configuration for a specific OmniToken market and tranches.
     * @param _market The address of the market
     * @param _tranches An array of tranche numbers
     * @param _configs An array of IRMConfig configurations
     */
    function setIRMForMarket(address _market, uint8[] calldata _tranches, IRMConfig[] calldata _configs)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_tranches.length != _configs.length) {
            revert("IRM::setIRMForMarket: Tranches and configs length mismatch.");
        }
        for (uint256 i = 0; i < _tranches.length; ++i) {
            if (_configs[i].kink == 0 || _configs[i].kink >= UTILIZATION_SCALE) {
                revert("IRM::setIRMForMarket: Bad kink value.");
            }
            if (
                _configs[i].start > _configs[i].mid || _configs[i].mid > _configs[i].end
                    || _configs[i].end > MAX_INTEREST_RATE
            ) {
                revert("IRM::setIRMForMarket: Bad interest value.");
            }
            marketIRMConfigs[_market][_tranches[i]] = _configs[i];
        }
        emit SetIRMForMarket(_market, _tranches, _configs);
    }
}
