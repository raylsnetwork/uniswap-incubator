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

import { Suitability } from "../contracts/Suitability.sol";
import { IERC20Minimal } from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import { console } from "forge-std/console.sol";
import "forge-std/StdJson.sol";

contract SuitabilityTest is Test, Deployers {
    using stdJson for string;
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    address proofSender = 0x1234567890AbcdEF1234567890aBcdef12345678;
    address invalidProofSender = 0x876543210FedCBa9876543210fedcBA987654321;

    Currency currency0;
    Currency currency1;

    PoolKey poolKey;

    Suitability hook;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    function loadProof()
        public
        returns (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals)
    {
        // read the proof.json file
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/solidityInputs.json");
        string memory json = vm.readFile(path);

        // parse pA
        pA = [json.readUint("[0][0]"), json.readUint("[0][1]")];

        // parse pB
        pB = [
            [json.readUint("[1][0][0]"), json.readUint("[1][0][1]")],
            [json.readUint("[1][1][0]"), json.readUint("[1][1][1]")]
        ];

        // parse pC
        pC = [json.readUint("[2][0]"), json.readUint("[2][1]")];

        // parse pubSignals
        pubSignals = [
            json.readUint("[3][0]"),
            json.readUint("[3][1]"),
            json.readUint("[3][2]"),
            json.readUint("[3][3]"),
            json.readUint("[3][4]")
        ];

        emit log_named_uint("pA[0]", pA[0]);
        emit log_named_uint("pA[1]", pA[1]);
        emit log_named_uint("pubSignals[2] (wallet)", pubSignals[2]);
    }

    function setUp() public {
        // Deploys all required artifacts.
        deployArtifacts();

        (currency0, currency1) = deployCurrencyPair();

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(poolManager); // Add all the necessary constructor arguments from the hook
        deployCodeTo("Suitability.sol:Suitability", constructorArgs, flags);
        hook = Suitability(flags);

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
            loadProof();

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

    function off_testDirectVerify() public view {
        // copy your pA, pB, pC and pubSignals exactly as used before
        uint256[2] memory pA = [
            0x2fd08ec3de4dcbf6d7134c1fb4d53677a4f15bef118000e4d090dcf0b5e91581,
            0x008925f3ec1a12a8109c85ab96d1aa8d91bf96fa0a52e1bfea4c9e337123c658
        ];

        uint256[2][2] memory pB = [
            [
                0x15255efb7cd651aed35427ea780cd178f34492b800a8dd9ddbad6cc3de6a64ac,
                0x10522c002623a0531b428825c3cb731f75b829b06b0fb037c96ce1cd0a6f16de
            ],
            [
                0x1f594f1ffe9fb3748e87d3f8ed6f1646054d75d8c1ffdf9d2634c06ac5611df8,
                0x174ba16487c4e4af5e3dbf31110df2f91398a2163152a51576d6cfa5e0581488
            ]
        ];

        uint256[2] memory pC = [
            0x2c7467b133a7379a65fa276b1ca8480688e17a648e19a02de8edb73432565699,
            0x274947e909acdb93270e058c57a73913f73ec259e77bec3951fec580cb1e3804
        ];

        uint256[5] memory pubSignals = [
            uint256(24),
            uint256(1),
            0x0000000000000000000000001234567890abcdef1234567890abcdef12345678,
            uint256(20),
            uint256(1)
        ];

        // If your verifier is public in the hook contract, call it directly:
        bool ok = hook.verifyProof(pA, pB, pC, pubSignals);
        assertTrue(ok); // this will fail if verifyProof==false
    }
}
