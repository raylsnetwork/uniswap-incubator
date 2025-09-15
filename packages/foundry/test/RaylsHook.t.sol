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

import { SuitabilityVerifier } from "../contracts/SuitabilityVerifier.sol";
import { PrivateSwapIntentVerifier } from "../contracts/PrivateSwapIntentVerifier.sol";
import { RaylsHookHelper } from "./utils/RaylsHookHelper.sol";

contract RaylsHookTest is Test, Deployers {
    using stdJson for string;
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    address invalidProofSender = 0x876543210FedCBa9876543210fedcBA987654321;

    // Private key for proofSender for wallet 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
    uint256 proofSenderPk = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    address proofSender = vm.addr(proofSenderPk);

    // Private key for Auditor for wallet 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
    string auditorPk = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

    Currency currency0;
    Currency currency1;

    PoolKey poolKey;

    RaylsHook hook;
    SuitabilityVerifier suitabilityVerifier;
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
        // Get the proof for Suitability
        string memory pathSuitability = string.concat(root, "/inputs/SuitabilityInputs.json");
        jsonSuitability = vm.readFile(pathSuitability);

        // Get the proof for PrivateSwapIntent
        string memory pathPrivateSwap = string.concat(root, "/inputs/PrivateSwapIntentInputs.json");
        jsonPrivateSwap = vm.readFile(pathPrivateSwap);

        //  Encrypt and get the encrypted payload for the auditor
        RaylsHookHelper.encryptValuesForAuditor(vm);
        jsonEncryptedPayload = vm.readFile("inputs/encryptedPayload.json");

        // Deploys all required artifacts.
        deployArtifacts();

        suitabilityVerifier = new SuitabilityVerifier();
        privateSwapIntentVerifier = new PrivateSwapIntentVerifier();

        (currency0, currency1) = deployCurrencyPair();

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(Hooks.BEFORE_SWAP_FLAG) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
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

    function testSwapRevertsWithInvalidProof() public {
        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals) =
            RaylsHookHelper.loadSuitabilityProof(jsonSuitability);

        uint256[2] memory fakePA = [uint256(1), pA[1]];
        bytes memory fakeProofData = abi.encode(fakePA, pB, pC, pubSignals);

        uint256 amountIn = 1e16;
        vm.startPrank(proofSender, proofSender);
        IERC20Minimal(Currency.unwrap(currency0)).approve(address(swapRouter), amountIn);

        vm.expectRevert();
        swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: fakeProofData,
            receiver: address(proofSender),
            deadline: block.timestamp + 1
        });

        vm.stopPrank();
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

        // Sucessful swap
        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: proofData,
            receiver: address(proofSender),
            deadline: block.timestamp + 1
        });
        vm.stopPrank();

        assertEq(int256(swapDelta.amount0()), -int256(amountIn));

        // assertEq(selector, IHooks.beforeSwap.selector, "selector mismatch");
        // delta and fee are placeholder, assert if needed
    }

    function testSuitabilityVerifier() public view {
        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals) =
            RaylsHookHelper.loadSuitabilityProof(jsonSuitability);

        // If your verifier is public in the hook contract, call it directly:
        bool ok = suitabilityVerifier.verifyProof(pA, pB, pC, pubSignals);
        assertTrue(ok);
    }

    function testPrivateSwapIntentVerifier() public view {
        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals) =
            RaylsHookHelper.loadPrivateSwapIntentProof(jsonPrivateSwap);

        // If your verifier is public in the hook contract, call it directly:
        bool ok = privateSwapIntentVerifier.verifyProof(pA, pB, pC, pubSignals);
        assertTrue(ok);
    }

    function testAPrivateSwap() public {
        // Get the proof and public signals from the json file
        RaylsHookHelper.PrivateSwapPublic memory proofCorrect =
            RaylsHookHelper.getPublicSignalsFromPrivateSwapIntentProof(jsonPrivateSwap, false, false);

        // Get the ciphertext for the auditor from the json file
        bytes memory ciphertextForAuditor = RaylsHookHelper.getJsonCiphertext(jsonEncryptedPayload);

        // Calculate the commitment ID off-chain using both the ZK Snark Poseidon Hash and the ciphertext
        uint256 id = uint256(keccak256(abi.encode(proofCorrect.poseidonHash, ciphertextForAuditor)));

        // Store the commitment on-chain
        vm.startPrank(proofSender, proofSender);
        // Build the permit signature to approve the hook to spend the tokens
        bytes memory permitSignature = RaylsHookHelper.buildPermitSignature(
            vm,
            proofSenderPk,
            Currency.unwrap(currency0),
            proofCorrect.timestamp,
            proofSender,
            address(hook),
            proofCorrect.amountIn
        );

        // Call the hook to store the commitment
        hook.storeCommitment(poolKey, id, ciphertextForAuditor, permitSignature);

        // Revert if already exsits
        bytes memory expectedRevert = abi.encodeWithSelector(RaylsHook.AlreadyExists.selector, id);
        vm.expectRevert(expectedRevert);
        hook.storeCommitment(poolKey, id, ciphertextForAuditor, permitSignature);

        // For now we just approve the swapRouter to spend the tokens
        // IERC20Minimal(Currency.unwrap(currency0)).approve(address(hook), amountIn);

        // Move time forward but not enough to be able to execute the commitment
        vm.warp(proofCorrect.timestamp - 1);
        expectedRevert =
            abi.encodeWithSelector(RaylsHook.CommitmentNotReady.selector, proofCorrect.timestamp, block.timestamp);
        vm.expectRevert(expectedRevert);
        hook.executeCommitment(poolKey, id, proofCorrect.proofData);

        // Move time forward to be able to execute the commitment
        vm.warp(proofCorrect.timestamp);

        // Revert if commitementId is incorrect and doesnt match the proof
        uint256 fakeId = 123456;
        expectedRevert = abi.encodeWithSelector(RaylsHook.CommitmentNotFound.selector, fakeId);
        vm.expectRevert(expectedRevert);
        hook.executeCommitment(poolKey, fakeId, proofCorrect.proofData);

        // Revert if the public signal poseidon hash is invalid
        RaylsHookHelper.PrivateSwapPublic memory proofWithWrongHash =
            RaylsHookHelper.getPublicSignalsFromPrivateSwapIntentProof(jsonPrivateSwap, false, true);
        bytes memory fakeCommitmentId = abi.encode(proofWithWrongHash.poseidonHash, ciphertextForAuditor);
        expectedRevert = abi.encodeWithSelector(RaylsHook.CommitmentMismatch.selector, fakeCommitmentId, id);
        vm.expectRevert(expectedRevert);
        hook.executeCommitment(poolKey, id, proofWithWrongHash.proofData);

        // Revert if the proof is invalid
        RaylsHookHelper.PrivateSwapPublic memory proofWithWrongPA =
            RaylsHookHelper.getPublicSignalsFromPrivateSwapIntentProof(jsonPrivateSwap, true, false);
        expectedRevert = abi.encodeWithSelector(RaylsHook.InvalidPrivateSwapIntentProof.selector);
        vm.expectRevert(expectedRevert);
        hook.executeCommitment(poolKey, id, proofWithWrongPA.proofData);

        // Execute the commitment successfully
        BalanceDelta delta = hook.executeCommitment(poolKey, id, proofCorrect.proofData);
        assertEq(int256(delta.amount0()), -int256(proofCorrect.amountIn));

        // Revert if we want to execute it again
        expectedRevert = abi.encodeWithSelector(RaylsHook.CommitmentNotActive.selector, id);
        vm.expectRevert(expectedRevert);
        hook.executeCommitment(poolKey, id, proofCorrect.proofData);
        vm.stopPrank();

        (bytes memory onChainCiphertext,, RaylsHook.CommitmentStatus status) = hook.commitments(poolKey.toId(), id);

        assertEq(uint8(status), uint8(RaylsHook.CommitmentStatus.Executed));
        assertEq(onChainCiphertext, ciphertextForAuditor);

        string memory hexOnChainCiphertext = vm.toString(onChainCiphertext);

        // Decrypt off-chain and use the private values to calculate the commitment ID
        // It must match to the one stored on-chain created by the circuit.
        uint256 decryptedPoseidonHash = RaylsHookHelper.decryptCiphertext(vm, auditorPk, hexOnChainCiphertext);

        // Check that commitmentId is correct
        assertEq(proofCorrect.poseidonHash, decryptedPoseidonHash);
    }

    /**
     * Loads the poseidon hash from the ZK Snark proof, decrypts the ciphertext from the encrypted payload and checks that they are equal.
     * This simulates the auditor decrypting the ciphertext and checking that the commitment ID is correct.
     * Which proves that the values in the encrypted payload: amountIn, zeroForOne, sender, timestamp are correct.
     */
    function test_EncryptedCommitmentForAuditor() public {
        // Get the proof and public signals from the json file
        RaylsHookHelper.PrivateSwapPublic memory proofCorrect =
            RaylsHookHelper.getPublicSignalsFromPrivateSwapIntentProof(jsonPrivateSwap, false, false);

        // Get the ciphertext for the auditor from the json file
        bytes memory ciphertextForAuditor = RaylsHookHelper.getJsonCiphertext(jsonEncryptedPayload);
        string memory hexOnChainCiphertext = vm.toString(ciphertextForAuditor);

        // Decrypt off-chain and use the poseidonHash for comparison
        // It must match to the one stored on-chain created by the circuit.
        uint256 decryptedPoseidonHash = RaylsHookHelper.decryptCiphertext(vm, auditorPk, hexOnChainCiphertext);

        // Check that hashes are equal
        assertEq(proofCorrect.poseidonHash, decryptedPoseidonHash);
    }

    function test_cancelCommitment() public {
        // Get the proof and public signals from the json file
        RaylsHookHelper.PrivateSwapPublic memory proofCorrect =
            RaylsHookHelper.getPublicSignalsFromPrivateSwapIntentProof(jsonPrivateSwap, false, false);

        // Get the ciphertext for the auditor from the json file
        bytes memory ciphertextForAuditor = RaylsHookHelper.getJsonCiphertext(jsonEncryptedPayload);

        // Calculate the commitment ID off-chain using both the ZK Snark Poseidon Hash and the ciphertext
        uint256 id = uint256(keccak256(abi.encode(proofCorrect.poseidonHash, ciphertextForAuditor)));

        // Store the commitment on-chain
        vm.startPrank(proofSender, proofSender);
        // Build the permit signature to approve the hook to spend the tokens
        bytes memory permitSignature = RaylsHookHelper.buildPermitSignature(
            vm,
            proofSenderPk,
            Currency.unwrap(currency0),
            proofCorrect.timestamp,
            proofSender,
            address(hook),
            proofCorrect.amountIn
        );

        // Call the hook to store the commitment
        hook.storeCommitment(poolKey, id, ciphertextForAuditor, permitSignature);

        // Revert if the public signal poseidon hash is invalid
        RaylsHookHelper.PrivateSwapPublic memory proofWithWrongHash =
            RaylsHookHelper.getPublicSignalsFromPrivateSwapIntentProof(jsonPrivateSwap, false, true);
        bytes memory fakeCommitmentId = abi.encode(proofWithWrongHash.poseidonHash, ciphertextForAuditor);
        bytes memory expectedRevert =
            abi.encodeWithSelector(RaylsHook.CommitmentMismatch.selector, fakeCommitmentId, id);
        vm.expectRevert(expectedRevert);
        hook.cancelCommitment(poolKey, id, proofWithWrongHash.proofData);

        // Revert if the proof is invalid
        RaylsHookHelper.PrivateSwapPublic memory proofWithWrongPA =
            RaylsHookHelper.getPublicSignalsFromPrivateSwapIntentProof(jsonPrivateSwap, true, false);
        expectedRevert = abi.encodeWithSelector(RaylsHook.InvalidPrivateSwapIntentProof.selector);
        vm.expectRevert(expectedRevert);
        hook.cancelCommitment(poolKey, id, proofWithWrongPA.proofData);

        // Cancel it before it can be executed
        hook.cancelCommitment(poolKey, id, proofCorrect.proofData);

        // Cancel it again shoule revvert
        expectedRevert = abi.encodeWithSelector(RaylsHook.CommitmentNotActive.selector, id);
        vm.expectRevert(expectedRevert);
        hook.cancelCommitment(poolKey, id, proofCorrect.proofData);

        // Move time forward to be able to execute the commitment
        vm.warp(proofCorrect.timestamp + 1);

        // Revert if we try to execute a cancelled commitment
        expectedRevert = abi.encodeWithSelector(RaylsHook.CommitmentNotActive.selector, id);
        vm.expectRevert(expectedRevert);
        hook.executeCommitment(poolKey, id, proofCorrect.proofData);
        vm.stopPrank();

        (,, RaylsHook.CommitmentStatus status) = hook.commitments(poolKey.toId(), id);

        assertEq(uint8(status), uint8(RaylsHook.CommitmentStatus.Cancelled));
    }
}
