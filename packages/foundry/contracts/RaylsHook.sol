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

contract RaylsHook is BaseHook {
    using PoolIdLibrary for PoolKey;

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

    mapping(uint256 => Commitment) public commitments;

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

    function executeCommitment(uint256 id, bytes calldata data) external {
        if (commitments[id].executed) {
            revert AlreadyExecuted(id);
        }

        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals) =
            abi.decode(data, (uint256[2], uint256[2][2], uint256[2], uint256[5]));

        // Making sure we are executing the right commitment
        bytes memory pubId = abi.encodePacked(
            pubSignals[0], // Poseidon hash of (amount, recipient, nonce)
            commitments[id].ciphertext,
            commitments[id].encKeyForAuditor
        );

        if (uint256(keccak256(pubId)) != id) {
            revert CommitmentMismatch(pubId, id);
        }

        if (pubSignals[2] != 1) {
            revert NotMarkedAsExecuted(pubSignals[2]);
        }

        if (pubSignals[4] > block.timestamp) {
            revert CommitmentNotReady(pubSignals[4], block.timestamp);
        }

        bool privateVerifierOk = privateSwapIntentVerifier.verifyProof(pA, pB, pC, pubSignals);
        if (!privateVerifierOk) {
            revert InvalidPrivateSwapIntentProof();
        }
        commitments[id].executed = true;
    }

    function storeCommitment(uint256 id, bytes calldata ciphertext, bytes calldata encKeyForAuditor) external {
        if (commitments[id].exists) {
            revert AlreadyExists(id);
        }
        commitments[id] =
            Commitment({ ciphertext: ciphertext, encKeyForAuditor: encKeyForAuditor, exists: true, executed: false });
        emit CommitmentStored(id, msg.sender);
    }
}
