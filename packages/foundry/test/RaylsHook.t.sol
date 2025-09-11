// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { IPoolManager, SwapParams } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { BalanceDelta } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { CurrencyLibrary, Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { StateLibrary } from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import { LiquidityAmounts } from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import { IPositionManager } from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import { Constants } from "@uniswap/v4-core/test/utils/Constants.sol";
import { BeforeSwapDelta, BeforeSwapDeltaLibrary } from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";

import { EasyPosm } from "./utils/libraries/EasyPosm.sol";
import { Deployers } from "./utils/Deployers.sol";

import { RaylsHook } from "../contracts/RaylsHook.sol";
import { IERC20Minimal } from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import { console } from "forge-std/console.sol";
import "forge-std/StdJson.sol";

import { SuitabilityAssessmentVerifier } from "../contracts/SuitabilityAssessmentVerifier.sol";
import { PrivateSwapIntentVerifier } from "../contracts/PrivateSwapIntentVerifier.sol";
import { RaylsHookHelper } from "./utils/RaylsHookHelper.sol";

contract RaylsHookTest is Test, Deployers {
    using stdJson for string;
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    address proofSender = 0x1234567890AbcdEF1234567890aBcdef12345678;
    address invalidProofSender = 0x876543210FedCBa9876543210fedcBA987654321;
    // Private key for Auditor for wallet 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
    string auditorPk = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

    Currency currency0;
    Currency currency1;

    PoolKey poolKey;

    RaylsHook hook;
    SuitabilityAssessmentVerifier suitabilityVerifier;
    PrivateSwapIntentVerifier privateSwapIntentVerifier;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    string jsonSuitability;
    string jsonPrivateSwap;
    string jsonEncryptedPayload;

    function setUp() public {
        // Get all necessary json files
        string memory root = vm.projectRoot();
        // Get the proof for SuitabilityAssessment
        string memory pathSuitability = string.concat(root, "/inputs/SuitabilityAssessmentInputs.json");
        jsonSuitability = vm.readFile(pathSuitability);

        // Get the proof for PrivateSwapIntent
        string memory pathPrivateSwap = string.concat(root, "/inputs/PrivateSwapIntentInputs.json");
        jsonPrivateSwap = vm.readFile(pathPrivateSwap);

        //  Encrypt and get the encrypted payload for the auditor
        RaylsHookHelper.encryptValuesForAuditor(vm);
        jsonEncryptedPayload = vm.readFile("inputs/encryptedPayload.json");

        // Deploys all required artifacts.
        deployArtifacts();

        suitabilityVerifier = new SuitabilityAssessmentVerifier();
        privateSwapIntentVerifier = new PrivateSwapIntentVerifier();

        (currency0, currency1) = deployCurrencyPair();

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(poolManager, suitabilityVerifier, privateSwapIntentVerifier); // Add all the necessary constructor arguments from the hook
        deployCodeTo("RaylsHook.sol:RaylsHook", constructorArgs, flags);
        hook = RaylsHook(flags);

        // Create the pool
        poolKey = PoolKey(currency0, currency1, 3000, 60, IHooks(address(hook)));
        poolId = poolKey.toId();
        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        // Provide full-range liquidity to the pool
        tickLower = TickMath.minUsableTick(poolKey.tickSpacing);
        tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing);

        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        (tokenId,) = positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            Constants.ZERO_BYTES
        );

        // Fund proofSender with tokens
        currency0.transfer(proofSender, 1e18);
        currency0.transfer(invalidProofSender, 1e18);
    }

    function testVerifyProofInBeforeSwap() public {
        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals) =
            RaylsHookHelper.loadSuitabilityProof(jsonSuitability);

        bytes memory proofData = abi.encode(pA, pB, pC, pubSignals);
        uint256 amountIn = 1e16;

        vm.startPrank(invalidProofSender, invalidProofSender);
        IERC20Minimal(Currency.unwrap(currency0)).approve(address(swapRouter), amountIn);
        vm.expectRevert();
        swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: proofData,
            receiver: address(this),
            deadline: block.timestamp + 1
        });
        vm.stopPrank();

        vm.startPrank(proofSender, proofSender);
        IERC20Minimal(Currency.unwrap(currency0)).approve(address(swapRouter), amountIn);

        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: proofData, // pass proof here
            receiver: address(proofSender),
            deadline: block.timestamp + 1
        });
        vm.stopPrank();

        assertEq(int256(swapDelta.amount0()), -int256(amountIn));

        // assertEq(selector, IHooks.beforeSwap.selector, "selector mismatch");
        // delta and fee are placeholder, assert if needed
    }

    function testSuitabilityAssessmentVerifier() public view {
        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals) =
            RaylsHookHelper.loadSuitabilityProof(jsonSuitability);

        // If your verifier is public in the hook contract, call it directly:
        bool ok = suitabilityVerifier.verifyProof(pA, pB, pC, pubSignals);
        assertTrue(ok); // this will fail if verifyProof==false
    }

    function testPrivateSwapIntentVerifier() public view {
        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals) =
            RaylsHookHelper.loadPrivateSwapIntentProof(jsonPrivateSwap);

        // If your verifier is public in the hook contract, call it directly:
        bool ok = privateSwapIntentVerifier.verifyProof(pA, pB, pC, pubSignals);
        assertTrue(ok); // this will fail if verifyProof==false
    }

    function testPrivateSwap() public {
        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals) =
            RaylsHookHelper.loadPrivateSwapIntentProof(jsonPrivateSwap);

        bytes memory proofData = abi.encode(pA, pB, pC, pubSignals);
        uint256 amountIn = 1e16;
        IERC20Minimal(Currency.unwrap(currency0)).approve(address(swapRouter), amountIn);

        string memory encKeyForAuditorStr = jsonEncryptedPayload.readString(".encKeyForAuditor");
        string memory ciphertextStr = jsonEncryptedPayload.readString(".ciphertext");

        bytes memory encKeyForAuditor = RaylsHookHelper.hexStringToBytes(encKeyForAuditorStr);
        bytes memory ciphertext = RaylsHookHelper.hexStringToBytes(ciphertextStr);

        uint256 id = uint256(
            keccak256(
                abi.encodePacked(
                    pubSignals[0], // Poseidon hash of (amountIn, zeroForOne, sender, timestamp)
                    ciphertext, // AES-encrypted message optional
                    encKeyForAuditor // optional: can be empty bytes
                )
            )
        );

        vm.startPrank(proofSender, proofSender);
        hook.storeCommitment(id, ciphertext, encKeyForAuditor);

        // Move time forward but not enough to be able to execute the commitment
        vm.warp(pubSignals[4] - 1);
        bytes memory expectedRevert =
            abi.encodeWithSelector(RaylsHook.CommitmentNotReady.selector, pubSignals[4], block.timestamp);
        vm.expectRevert(expectedRevert);
        hook.executeCommitment(id, proofData);

        // Move time forward to be able to execute the commitment
        vm.warp(pubSignals[4]);
        hook.executeCommitment(id, proofData);

        vm.stopPrank();

        (bytes memory onChainCiphertext, bytes memory onChainEncKeyForAuditor,, bool executed) = hook.commitments(id);

        assertEq(executed, true);
        assertEq(onChainCiphertext, ciphertext);
        assertEq(onChainEncKeyForAuditor, encKeyForAuditor);
        string memory hexOnChainCiphertext = vm.toString(onChainCiphertext);
        string memory hexOnChainEncKeyForAuditor = vm.toString(onChainEncKeyForAuditor);

        // Decrypt off-chain and use the private values to calculate the commitment ID
        // It must match to the one stored on-chain created by the circuit.
        uint256 decryptedCommitmentId =
            RaylsHookHelper.decryptCiphertext(vm, auditorPk, hexOnChainCiphertext, hexOnChainEncKeyForAuditor);

        // Check that commitmentId is correct
        assertEq(pubSignals[0], decryptedCommitmentId);

        // assertEq(selector, IHooks.beforeSwap.selector, "selector mismatch");
        // delta and fee are placeholder, assert if needed
    }
}
