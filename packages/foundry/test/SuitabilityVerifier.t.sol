// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";

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

    /// @dev Converte uma célula JSON (que pode ser número, ou string "0x.."/"123..") para uint.
    function _readUintFlexible(string memory json, string memory pointer) internal returns (uint256 out) {
        // Tenta ler como número direto (caso você mude para um JSON com números mesmo)
        try this._readUint(json, pointer) returns (uint256 v) {
            return v;
        } catch {
            // Se não for número, lê como string e usa vm.parseUint (aceita "0x..." ou decimal)
            string memory s = json.readString(pointer);
            return vm.parseUint(s);
        }
    }

    // Wrapper separado porque stdJson.readUint é uma função "internal" via using-for e
    // o try/catch acima precisa de algo externo para diferenciar fallback.
    function _readUint(string memory json, string memory pointer) external view returns (uint256) {
        return json.readUint(pointer);
    }

    function loadProof()
        public
        returns (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals)
    {
        string memory root = vm.projectRoot();

        // 👉 use o arquivo que preferir; todos funcionam:
        // string memory path = string.concat(root, "/packages/foundry/solidityInputs.json");        // hex em string
        // string memory path = string.concat(root, "/packages/foundry/solidityInputs.ui.json");     // hex em string (UI)
        // string memory path = string.concat(root, "/packages/foundry/solidityInputs.decimal.json"); // decimal em string
        // Se os testes rodam dentro de packages/foundry, você pode apontar relativo:
        string memory path = string.concat(root, "/solidityInputs.json");

        string memory json = vm.readFile(path);

        // pA
        pA[0] = _readUintFlexible(json, "[0][0]");
        pA[1] = _readUintFlexible(json, "[0][1]");

        // pB (já no layout Solidity [[bx1,bx0],[by1,by0]] gerado pelo pipeline)
        pB[0][0] = _readUintFlexible(json, "[1][0][0]");
        pB[0][1] = _readUintFlexible(json, "[1][0][1]");
        pB[1][0] = _readUintFlexible(json, "[1][1][0]");
        pB[1][1] = _readUintFlexible(json, "[1][1][1]");

        // pC
        pC[0] = _readUintFlexible(json, "[2][0]");
        pC[1] = _readUintFlexible(json, "[2][1]");

        // pubSignals (fixo 5)
        for (uint256 i = 0; i < 5; i++) {
            pubSignals[i] = _readUintFlexible(json, string.concat("[3][", vm.toString(i), "]"));
        }

        emit log_named_uint("pA[0]", pA[0]);
        emit log_named_uint("pA[1]", pA[1]);
        emit log_named_uint("pubSignals[2] (wallet)", pubSignals[2]);
    }

    function setUp() public {
        deployArtifacts();
        (currency0, currency1) = deployCurrencyPair();

        // Deploy o hook com as flags corretas
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            ) ^ (0x4444 << 144)
        );
        bytes memory constructorArgs = abi.encode(poolManager);
        deployCodeTo("Suitability.sol:Suitability", constructorArgs, flags);
        hook = Suitability(flags);

        // Pool
        poolKey = PoolKey(currency0, currency1, 3000, 60, IHooks(address(hook)));
        poolId = poolKey.toId();
        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        // Liquidez full-range
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

        // Fund senders
        currency0.transfer(proofSender, 1e18);
        currency0.transfer(invalidProofSender, 1e18);
    }

    function testVerifyProofInBeforeSwap() public {
        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals) =
            loadProof();

        // 👉 Deriva o wallet da prova
        address proofWallet = address(uint160(pubSignals[2]));
        // Garante que é diferente do inválido
        assert(proofWallet != invalidProofSender);

        // Garante saldo pro wallet correto (além do que foi enviado no setUp para proofSender)
        uint256 amountIn = 1e16;
        currency0.transfer(proofWallet, 1e18);

        bytes memory proofData = abi.encode(pA, pB, pC, pubSignals);

        // Caminho inválido: deve reverter
        vm.startPrank(invalidProofSender, invalidProofSender);
        IERC20Minimal(Currency.unwrap(currency0)).approve(address(swapRouter), amountIn);
        vm.expectRevert(); // revert lógico do hook
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

        // Caminho válido: usa o sender da prova
        vm.startPrank(proofWallet, proofWallet);
        IERC20Minimal(Currency.unwrap(currency0)).approve(address(swapRouter), amountIn);

        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: proofData, // passa a prova gerada
            receiver: proofWallet,
            deadline: block.timestamp + 1
        });
        vm.stopPrank();

        assertEq(int256(swapDelta.amount0()), -int256(amountIn));
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
