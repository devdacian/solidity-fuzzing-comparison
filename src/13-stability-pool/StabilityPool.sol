// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// A simplified version of Prisma Finance's StabilityPool where users
// can deposit `debtToken` to receive a share of `collateralToken`
// rewards from liquidations
//
// Challenge: write an invariant to test the solvency of the pool;
// can the pool reach a state where it owes more `collateralToken` to
// depositors than it has available?
contract StabilityPool {
    using SafeERC20 for IERC20;

    uint256 constant DECIMAL_PRECISION = 1e18;
    uint256 constant SCALE_FACTOR = 1e9;
    uint256 constant REWARD_DURATION = 1 weeks;
    uint8 constant COLLATERAL_DECIMALS = 18;

    IERC20 public immutable debtToken;
    IERC20 public immutable collateralToken;

    uint128 public currentScale;
    uint128 public currentEpoch;
    uint256 public lastBabelError;
    uint256 public lastCollateralError_Offset;
    uint256 public lastDebtLossError_Offset;
    uint256 public P = DECIMAL_PRECISION;
    uint256 public totalDebtTokenDeposits;

    // mappings
    mapping(address depositor => AccountDeposit) public accountDeposits;
    mapping(address depositor => Snapshots) public depositSnapshots;
    mapping(address depositor => uint256 deposits) public depositSums;
    mapping(address depositor => uint80 gains) public collateralGainsByDepositor;
    mapping(uint128 epoch => mapping(uint128 scale => uint256 sumS)) public epochToScaleToSums;

    // structs
    struct AccountDeposit {
        uint128 amount;
        uint128 timestamp; // timestamp of the last deposit
    }
    struct Snapshots {
        uint256 P;
        uint128 scale;
        uint128 epoch;
    }

    constructor(IERC20 _debtTokenAddress, IERC20 _collateralToken) {
        debtToken = _debtTokenAddress;
        collateralToken = _collateralToken;
    }

    // provides collateral tokens to the stability pool
    function provideToSP(uint256 _amount) external {
        require(_amount > 0, "StabilityPool: Amount must be non-zero");

        _accrueDepositorCollateralGain(msg.sender);

        uint256 compoundedDebtDeposit = getCompoundedDebtDeposit(msg.sender);

        debtToken.transferFrom(msg.sender, address(this), _amount);

        uint256 newTotalDebtTokenDeposits = totalDebtTokenDeposits + _amount;
        totalDebtTokenDeposits = newTotalDebtTokenDeposits;

        uint256 newTotalDeposited = compoundedDebtDeposit + _amount;

        accountDeposits[msg.sender] = AccountDeposit({
            amount: SafeCast.toUint128(newTotalDeposited),
            timestamp: uint128(block.timestamp)
        });

        _updateSnapshots(msg.sender, newTotalDeposited);
    }

    function registerLiquidation(uint256 _debtToOffset, uint256 _collToAdd) external {
        uint256 totalDebt = totalDebtTokenDeposits;
        if (totalDebt == 0 || _debtToOffset == 0) {
            return;
        }

        (uint256 collateralGainPerUnitStaked, uint256 debtLossPerUnitStaked) = _computeRewardsPerUnitStaked(
            _collToAdd,
            _debtToOffset,
            totalDebt
        );

        _updateRewardSumAndProduct(collateralGainPerUnitStaked, debtLossPerUnitStaked);

        _decreaseDebt(_debtToOffset);
    }

    function _computeRewardsPerUnitStaked(
        uint256 _collToAdd,
        uint256 _debtToOffset,
        uint256 _totalDebtTokenDeposits
    ) internal returns (uint256 collateralGainPerUnitStaked, uint256 debtLossPerUnitStaked) {
        /*
         * Compute the Debt and collateral rewards. Uses a "feedback" error correction, to keep
         * the cumulative error in the P and S state variables low:
         *
         * 1) Form numerators which compensate for the floor division errors that occurred the last time this
         * function was called.
         * 2) Calculate "per-unit-staked" ratios.
         * 3) Multiply each ratio back by its denominator, to reveal the current floor division error.
         * 4) Store these errors for use in the next correction when this function is called.
         * 5) Note: static analysis tools complain about this "division before multiplication", however, it is intended.
         */
        uint256 collateralNumerator = (_collToAdd * DECIMAL_PRECISION) + lastCollateralError_Offset;

        if (_debtToOffset == _totalDebtTokenDeposits) {
            debtLossPerUnitStaked = DECIMAL_PRECISION; // When the Pool depletes to 0, so does each deposit
            lastDebtLossError_Offset = 0;
        } else {
            uint256 debtLossNumerator = (_debtToOffset * DECIMAL_PRECISION) - lastDebtLossError_Offset;
            /*
             * Add 1 to make error in quotient positive. We want "slightly too much" Debt loss,
             * which ensures the error in any given compoundedDebtDeposit favors the Stability Pool.
             */
            debtLossPerUnitStaked = (debtLossNumerator / _totalDebtTokenDeposits) + 1;
            lastDebtLossError_Offset = (debtLossPerUnitStaked * _totalDebtTokenDeposits) - debtLossNumerator;
        }

        collateralGainPerUnitStaked = collateralNumerator / _totalDebtTokenDeposits;
       lastCollateralError_Offset = collateralNumerator - (collateralGainPerUnitStaked * _totalDebtTokenDeposits);
    }

    // Update the Stability Pool reward sum S and product P
    function _updateRewardSumAndProduct(
        uint256 _collateralGainPerUnitStaked,
        uint256 _debtLossPerUnitStaked
    ) internal {
        uint256 currentP = P;
        uint256 newP;

        /*
         * The newProductFactor is the factor by which to change all deposits, due to the depletion of Stability Pool Debt in the liquidation.
         * We make the product factor 0 if there was a pool-emptying. Otherwise, it is (1 - DebtLossPerUnitStaked)
         */
        uint256 newProductFactor = DECIMAL_PRECISION - _debtLossPerUnitStaked;

        uint128 currentScaleCached = currentScale;
        uint128 currentEpochCached = currentEpoch;
        uint256 currentS = epochToScaleToSums[currentEpochCached][currentScaleCached];

        /*
         * Calculate the new S first, before we update P.
         * The collateral gain for any given depositor from a liquidation depends on the value of their deposit
         * (and the value of totalDeposits) prior to the Stability being depleted by the debt in the liquidation.
         *
         * Since S corresponds to collateral gain, and P to deposit loss, we update S first.
         */
        uint256 marginalCollateralGain = _collateralGainPerUnitStaked * currentP;
        uint256 newS = currentS + marginalCollateralGain;
        epochToScaleToSums[currentEpochCached][currentScaleCached] = newS;

        // If the Stability Pool was emptied, increment the epoch, and reset the scale and product P
        if (newProductFactor == 0) {
            currentEpoch = currentEpochCached + 1;
            currentScale = 0;
            newP = DECIMAL_PRECISION;

            // If multiplying P by a non-zero product factor would reduce P below the scale boundary, increment the scale
        } else if ((currentP * newProductFactor) / DECIMAL_PRECISION < SCALE_FACTOR) {
            newP = (currentP * newProductFactor * SCALE_FACTOR) / DECIMAL_PRECISION;
            currentScale = currentScaleCached + 1;
        } else {
            newP = (currentP * newProductFactor) / DECIMAL_PRECISION;
        }

        require(newP > 0, "NewP");
        P = newP;
    }

    function _decreaseDebt(uint256 _amount) internal {
        uint256 newTotalDebtTokenDeposits = totalDebtTokenDeposits - _amount;
        totalDebtTokenDeposits = newTotalDebtTokenDeposits;
    }

    // --- Reward calculator functions for depositor and front end ---

    /* Calculates the collateral gain earned by the deposit since its last snapshots were taken.
     * Given by the formula:  E = d0 * (S - S(0))/P(0)
     * where S(0) and P(0) are the depositor's snapshots of the sum S and product P, respectively.
     * d0 is the last recorded deposit value.
     */
    function getDepositorCollateralGain(address _depositor) external view returns (uint256 collateralGains) {
        uint256 P_Snapshot = depositSnapshots[_depositor].P;
        if (P_Snapshot == 0) return collateralGains;
        collateralGains = collateralGainsByDepositor[_depositor];
        uint256 initialDeposit = accountDeposits[_depositor].amount;
        uint128 epochSnapshot = depositSnapshots[_depositor].epoch;
        uint128 scaleSnapshot = depositSnapshots[_depositor].scale;
        uint256 sums = epochToScaleToSums[epochSnapshot][scaleSnapshot];
        uint256 nextSums = epochToScaleToSums[epochSnapshot][scaleSnapshot + 1];
        uint256 depSums = depositSums[_depositor];

        if (sums != 0) {
            uint256 firstPortion = sums - depSums;
            uint256 secondPortion = nextSums / SCALE_FACTOR;
            collateralGains += (initialDeposit * (firstPortion + secondPortion)) / P_Snapshot / DECIMAL_PRECISION;
        }
    }

    function _accrueDepositorCollateralGain(address _depositor) private returns (bool hasGains) {
        // cache user's initial deposit amount
        uint256 initialDeposit = accountDeposits[_depositor].amount;

        if(initialDeposit != 0) {
            uint128 epochSnapshot = depositSnapshots[_depositor].epoch;
            uint128 scaleSnapshot = depositSnapshots[_depositor].scale;
            uint256 P_Snapshot = depositSnapshots[_depositor].P;

            uint256 sumS = epochToScaleToSums[epochSnapshot][scaleSnapshot];
            uint256 nextSumS = epochToScaleToSums[epochSnapshot][scaleSnapshot + 1];
            uint256 depSums = depositSums[_depositor];

            if (sumS != 0) {
                hasGains = true;

                uint256 firstPortion = sumS - depSums;
                uint256 secondPortion = nextSumS / SCALE_FACTOR;

                collateralGainsByDepositor[_depositor] += SafeCast.toUint80(
                    (initialDeposit * (firstPortion + secondPortion)) / P_Snapshot / DECIMAL_PRECISION
                );
            }
        }
    }

    function getCompoundedDebtDeposit(address _depositor) public view returns (uint256 compoundedDeposit) {
        compoundedDeposit = accountDeposits[_depositor].amount;

        if (compoundedDeposit != 0) {
            Snapshots memory snapshots = depositSnapshots[_depositor];

            compoundedDeposit = _getCompoundedStakeFromSnapshots(compoundedDeposit, snapshots);
        }
    }

    function _getCompoundedStakeFromSnapshots(
        uint256 initialStake,
        Snapshots memory snapshots
    ) internal view returns (uint256 compoundedStake) {
        if(snapshots.epoch >= currentEpoch) {
            uint128 scaleDiff = currentScale - snapshots.scale;

            if (scaleDiff == 0) {
                compoundedStake = (initialStake * P) / snapshots.P;
            } else if (scaleDiff == 1) {
                compoundedStake = (initialStake * P) / snapshots.P / SCALE_FACTOR;
            } 
        }
    }

    function claimCollateralGains() external {
        _accrueDepositorCollateralGain(msg.sender);

        uint80 depositorGains = collateralGainsByDepositor[msg.sender];

        if (depositorGains > 0) {
            collateralGainsByDepositor[msg.sender] = 0;

            collateralToken.safeTransfer(msg.sender, depositorGains);
        }
    }

    function _updateSnapshots(address _depositor, uint256 _newValue) internal {
        if (_newValue == 0) {
            delete depositSnapshots[_depositor];
            
            depositSums[_depositor] = 0;
        }
        else {
            uint128 currentScaleCached = currentScale;
            uint128 currentEpochCached = currentEpoch;
            uint256 currentP = P;

            // Get S and G for the current epoch and current scale
            uint256 currentS = epochToScaleToSums[currentEpochCached][currentScaleCached];

            // Record new snapshots of the latest running product P, sum S, and sum G, for the depositor
            depositSnapshots[_depositor].P = currentP;
            depositSnapshots[_depositor].scale = currentScaleCached;
            depositSnapshots[_depositor].epoch = currentEpochCached;
            depositSums[_depositor] = currentS;
        }
    }
}