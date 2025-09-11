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

    event CommitmentStored(uint256 id, address indexed sender);
    event Revealed(uint256 id, address indexed revealer);

    // Errors
    error CommitmentMismatch(bytes pubId, uint256 expectedId);
    error NotMarkedAsExecuted(uint256 signal);
    error CommitmentNotReady(uint256 notBefore, uint256 currentTime);
    error InvalidWallet(address provided, address expected);
    error InvalidSuitabilityProof();
    error AlreadyExecuted(uint256 id);
    error InvalidPrivateSwapIntentProof();
    error AlreadyExists(uint256 id);

    struct Commitment {
        bytes ciphertext; // AES/GCM ciphertext (includes tag)
        bytes encKeyForAuditor; // encrypted symmetric key for auditor
        bytes permit;
        bool exists;
        bool executed;
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
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    function _beforeSwap(address, PoolKey calldata key, SwapParams calldata, bytes calldata data)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals) =
            abi.decode(data, (uint256[2], uint256[2][2], uint256[2], uint256[5]));

        uint256 walletInProof = pubSignals[2]; // index 2 because it's the 3rd public signal
        address origin = _determineOrigin(msg.sender);

        if (walletInProof != uint256(uint160(origin))) {
            revert InvalidWallet(address(uint160(walletInProof)), origin);
        }

        bool suitabilityOk = suitabilityVerifier.verifyProof(pA, pB, pC, pubSignals);
        if (!suitabilityOk) {
            revert InvalidSuitabilityProof();
        }

        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function _afterSwap(address, PoolKey calldata key, SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        return (BaseHook.afterSwap.selector, 0);
    }

    function _beforeAddLiquidity(address, PoolKey calldata key, ModifyLiquidityParams calldata, bytes calldata)
        internal
        override
        returns (bytes4)
    {
        beforeAddLiquidityCount[key.toId()]++;
        return BaseHook.beforeAddLiquidity.selector;
    }

    function _beforeRemoveLiquidity(address, PoolKey calldata key, ModifyLiquidityParams calldata, bytes calldata)
        internal
        override
        returns (bytes4)
    {
        beforeRemoveLiquidityCount[key.toId()]++;
        return BaseHook.beforeRemoveLiquidity.selector;
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

    function executeCommitment(PoolKey calldata key, uint256 id, bytes calldata data)
        external
        nonReentrant
        returns (BalanceDelta)
    {
        if (commitments[key.toId()][id].executed) {
            revert AlreadyExecuted(id);
        }

        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals) =
            abi.decode(data, (uint256[2], uint256[2][2], uint256[2], uint256[5]));

        if (pubSignals[4] > block.timestamp) {
            revert CommitmentNotReady(pubSignals[4], block.timestamp);
        }

        if (pubSignals[2] != 1) {
            revert NotMarkedAsExecuted(pubSignals[2]);
        }

        // Making sure we are executing the right commitment
        bytes memory pubId = abi.encode(
            pubSignals[0], // Poseidon hash of (amount, recipient, nonce)
            commitments[key.toId()][id].ciphertext,
            commitments[key.toId()][id].encKeyForAuditor
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
        commitments[key.toId()][id].executed = true;

        // Run the permit if needed
        if (commitments[key.toId()][id].permit.length > 0) {
            (uint8 v, bytes32 r, bytes32 s) = splitSig(commitments[key.toId()][id].permit);
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
                    // We provide a negative value here to signify an "exact input for output" swap
                    amountSpecified: -int256(pubSignals[1]),
                    // No slippage limits (maximum slippage possible)
                    sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
                })
            )
        );

        (BalanceDelta delta) = abi.decode(callbackReturn, (BalanceDelta));
        // emit Executed(keyId, id, owner, /*...*/);
        return delta;
    }

    function storeCommitment(
        PoolKey calldata key,
        uint256 id,
        bytes calldata ciphertext,
        bytes calldata encKeyForAuditor,
        bytes calldata permit
    ) external {
        if (commitments[key.toId()][id].exists) {
            revert AlreadyExists(id);
        }
        commitments[key.toId()][id] = Commitment({
            ciphertext: ciphertext,
            encKeyForAuditor: encKeyForAuditor,
            permit: permit,
            exists: true,
            executed: false
        });
        emit CommitmentStored(id, msg.sender);
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
}
