// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { BaseHook } from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";

import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { IPoolManager, SwapParams, ModifyLiquidityParams } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { BalanceDelta } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { BeforeSwapDelta, BeforeSwapDeltaLibrary } from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import { SuitabilityAssessmentVerifier } from "./SuitabilityAssessmentVerifier.sol";
import { console } from "forge-std/console.sol";

import { PrivateSwapIntentVerifier } from "./PrivateSwapIntentVerifier.sol";
import { BalanceDelta } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { IUnlockCallback } from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { console } from "forge-std/console.sol";

contract RaylsHook is BaseHook, IUnlockCallback, ReentrancyGuard {
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for IERC20;

    // NOTE: ---------------------------------------------------------
    // state variables should typically be unique to a pool
    // a single hook contract should be able to service multiple pools
    // ---------------------------------------------------------------

    mapping(PoolId => uint256 count) public beforeSwapCount;
    mapping(PoolId => uint256 count) public afterSwapCount;

    mapping(PoolId => uint256 count) public beforeAddLiquidityCount;
    mapping(PoolId => uint256 count) public beforeRemoveLiquidityCount;
    SuitabilityAssessmentVerifier public suitabilityVerifier;
    PrivateSwapIntentVerifier public privateSwapIntentVerifier;

    mapping(PoolId poolId => mapping(uint256 => Commitment)) public commitments;

    event CommitmentStored(uint256 indexed id, address indexed sender, bytes, bytes);
    event CommitmentExecuted(uint256 indexed id, address indexed sender);
    event CommitmentCanceled(uint256 indexed id, address indexed canceller);

    // Errors
    error CommitmentMismatch(bytes pubId, uint256 expectedId);
    error CommitmentNotReady(uint256 notBefore, uint256 currentTime);
    error InvalidWallet(address provided, address expected);
    error InvalidSuitabilityProof();
    error AlreadyExecuted(uint256 id);
    error InvalidPrivateSwapIntentProof();
    error AlreadyExists(uint256 id);
    error CommitmentNotActive(uint256 id);
    error CommitmentNotFound(uint256 id);

    enum CommitmentStatus {
        None, // default, not stored
        Active, // stored but not yet executed
        Executed, // executed successfully
        Canceled // canceled by creator

    }

    struct Commitment {
        bytes ciphertextForAuditor; //ECIES-encrypted swap details for auditor
        bytes permit;
        CommitmentStatus status;
    }

    constructor(IPoolManager _poolManager, address _suitabilityVerifier, address _privateSwapIntentVerifier)
        BaseHook(_poolManager)
    {
        suitabilityVerifier = SuitabilityAssessmentVerifier(_suitabilityVerifier);
        privateSwapIntentVerifier = PrivateSwapIntentVerifier(_privateSwapIntentVerifier);
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /**
     * Here we verify the suitability proof and that the wallet in the proof matches the transaction origin
     *
     */
    function _beforeSwap(address, PoolKey calldata key, SwapParams calldata, bytes calldata data)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals) =
            abi.decode(data, (uint256[2], uint256[2][2], uint256[2], uint256[5]));

        uint256 walletInProof = pubSignals[2]; // index 2 because it's the 3rd public signal

        // We want to identify the originator of the transaction
        address origin = _determineOrigin(msg.sender);

        // Verify the wallet address in the proof matches the transaction origin
        if (walletInProof != uint256(uint160(origin))) {
            revert InvalidWallet(address(uint160(walletInProof)), origin);
        }

        // Verify the Suitability proof
        bool suitabilityOk = suitabilityVerifier.verifyProof(pA, pB, pC, pubSignals);
        if (!suitabilityOk) {
            revert InvalidSuitabilityProof();
        }

        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /**
     * @notice Stores a new encrypted swap commitment onchain.
     * @dev Each commitment is uniquely identified by `id` under a specific pool key.
     *      Reverts if a commitment with the same `id` already exists.
     *      The ciphertextForAuditor allows a designated auditor to decrypt the swap parameters offchain.
     * @param key Pool key identifying the Uniswap v4 pool this commitment belongs to.
     * @param id Unique identifier for the commitment (Poseidon/keccak hash).
     * @param ciphertextForAuditor Encrypted swap data for the auditor
     * @param permit ERC20 permit signature data, allowing token transfers at execution.
     * Emits a {CommitmentStored} event.
     */
    function storeCommitment(
        PoolKey calldata key,
        uint256 id,
        bytes calldata ciphertextForAuditor,
        bytes calldata permit
    ) external {
        if (commitments[key.toId()][id].status != CommitmentStatus.None) {
            revert AlreadyExists(id);
        }

        commitments[key.toId()][id] =
            Commitment({ ciphertextForAuditor: ciphertextForAuditor, permit: permit, status: CommitmentStatus.Active });
        emit CommitmentStored(id, msg.sender, ciphertextForAuditor, permit);
    }

    /**
     * @notice Cancels a previously stored commitment before execution.
     * @dev Marks the commitment as canceled so it cannot be executed.
     *      Reverts if the commitment does not exist, was already executed, or already canceled.
     *      Large storage fields may be cleared to save gas, but the status is retained for auditability.
     * @param key Pool key identifying the Uniswap v4 pool this commitment belongs to.
     * @param id Unique identifier of the commitment to cancel.
     * @param zkProof ABI-encoded zkSNARK proof data (pA, pB, pC, pubSignals) to authorize the cancellation.
     * Emits a {CommitmentCanceled} event.
     */
    function cancelCommitment(PoolKey calldata key, uint256 id, bytes calldata zkProof) external {
        Commitment storage c = commitments[key.toId()][id];
        if (c.status != CommitmentStatus.Active) {
            revert CommitmentNotActive(id);
        }

        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals) =
            abi.decode(zkProof, (uint256[2], uint256[2][2], uint256[2], uint256[5]));

        // Making sure we are executing the right commitment
        bytes memory pubId = abi.encode(pubSignals[0], c.ciphertextForAuditor);

        if (keccak256(pubId) != bytes32(id)) {
            revert CommitmentMismatch(pubId, id);
        }

        bool privateVerifierOk = privateSwapIntentVerifier.verifyProof(pA, pB, pC, pubSignals);
        if (!privateVerifierOk) {
            revert InvalidPrivateSwapIntentProof();
        }

        // We can cancel now
        c.status = CommitmentStatus.Canceled;
        delete c.ciphertextForAuditor;
        delete c.permit;
        emit CommitmentCanceled(id, msg.sender);
    }

    /**
     * @notice Executes a previously stored encrypted swap commitment once its conditions are met.
     * @dev Verifies a zkSNARK proof to ensure the executor knows the commitment’s plaintext
     *      and that the onchain commitment matches the provided proof. Uses ERC20 permit to
     *      pull tokens from the original sender, then executes a Uniswap v4 swap through
     *      the PoolManager. Marks the commitment as executed to prevent replay.
     * @param key Pool key identifying the Uniswap v4 pool this commitment belongs to.
     * @param id Unique identifier of the commitment to execute.
     * @param zkProof ABI-encoded zkSNARK proof data (pA, pB, pC, pubSignals) to authorize the execution.
     * @return delta Net balance delta returned from the swap execution.
     * Emits a {CommitmentExecuted} event (if you add one).
     */
    function executeCommitment(PoolKey calldata key, uint256 id, bytes calldata zkProof)
        external
        nonReentrant
        returns (BalanceDelta)
    {
        Commitment storage commitment = commitments[key.toId()][id];
        if (commitment.status == CommitmentStatus.None) {
            revert CommitmentNotFound(id);
        }
        if (commitment.status != CommitmentStatus.Active) {
            revert CommitmentNotActive(id);
        }

        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals) =
            abi.decode(zkProof, (uint256[2], uint256[2][2], uint256[2], uint256[5]));

        if (pubSignals[4] > block.timestamp) {
            revert CommitmentNotReady(pubSignals[4], block.timestamp);
        }

        // Making sure we are executing the right commitment
        bytes memory pubId = abi.encode(
            pubSignals[0], // Poseidon hash of (amount, recipient, nonce)
            commitment.ciphertextForAuditor
        );

        if (keccak256(pubId) != bytes32(id)) {
            revert CommitmentMismatch(pubId, id);
        }

        bool privateVerifierOk = privateSwapIntentVerifier.verifyProof(pA, pB, pC, pubSignals);
        if (!privateVerifierOk) {
            revert InvalidPrivateSwapIntentProof();
        }

        // We can swap now
        // Mark as executed before any external transfer/call
        commitment.status = CommitmentStatus.Executed;

        // Run the permit if needed
        if (commitment.permit.length > 0) {
            (uint8 v, bytes32 r, bytes32 s) = splitSig(commitment.permit);
            IERC20Permit(Currency.unwrap(key.currency0)).permit(
                address(uint160(pubSignals[3])), address(this), pubSignals[1], pubSignals[4] + 1 days, v, r, s
            );
        }

        // First transfer the tokens to the hook contract
        IERC20(Currency.unwrap(key.currency0)).safeTransferFrom(
            address(uint160(pubSignals[3])), address(this), pubSignals[1]
        );

        // Then unlock the PoolManager to execute the swap
        bool zeroForOne = pubSignals[2] == 1 ? true : false;
        bytes memory callbackReturn = poolManager.unlock(
            abi.encode(
                key,
                SwapParams({
                    zeroForOne: zeroForOne,
                    amountSpecified: -int256(pubSignals[1]),
                    // No slippage limits (maximum slippage possible)
                    sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
                })
            )
        );

        (BalanceDelta delta) = abi.decode(callbackReturn, (BalanceDelta));
        emit CommitmentExecuted(id, msg.sender);
        return delta;
    }

    function swapAndSettleBalances(PoolKey memory key, SwapParams memory params) internal returns (BalanceDelta) {
        // Conduct the swap inside the Pool Manager
        BalanceDelta delta = poolManager.swap(key, params, "");

        // If we just did a zeroForOne swap
        // We need to send Token 0 to PM, and receive Token 1 from PM
        if (params.zeroForOne) {
            // Negative Value => Money leaving user's wallet
            // Settle with PoolManager
            if (delta.amount0() < 0) {
                _settle(key.currency0, uint128(-delta.amount0()));
            }

            // Positive Value => Money coming into user's wallet
            // Take from PM
            if (delta.amount1() > 0) {
                _take(key.currency1, uint128(delta.amount1()));
            }
        } else {
            if (delta.amount1() < 0) {
                _settle(key.currency1, uint128(-delta.amount1()));
            }

            if (delta.amount0() > 0) {
                _take(key.currency0, uint128(delta.amount0()));
            }
        }

        return delta;
    }

    function _settle(Currency currency, uint128 amount) internal {
        // Transfer tokens to PM and let it know
        poolManager.sync(currency);
        currency.transfer(address(poolManager), amount);
        poolManager.settle();
    }

    function _take(Currency currency, uint128 amount) internal {
        // Take tokens out of PM to our hook contract
        poolManager.take(currency, address(this), amount);
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        (PoolKey memory key, SwapParams memory params) = abi.decode(data, (PoolKey, SwapParams));
        BalanceDelta delta = swapAndSettleBalances(key, params);
        return abi.encode(delta);
    }

    function splitSig(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(sig.length == 65, "bad sig length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    /**
     * Determines the origin of the transaction.
     *
     * @param _sender The sender of the transaction
     *
     * @return origin_ The origin of the transaction
     */
    function _determineOrigin(address _sender) internal returns (address origin_) {
        // Set our default origin to the `tx.origin`
        origin_ = tx.origin;

        // If the sender has a `msgSender` function, then we use that to determine the origin
        (bool success, bytes memory data) = _sender.call(abi.encodeWithSignature("msgSender()"));
        if (success && data.length >= 32) {
            origin_ = abi.decode(data, (address));
        }
    }
}
