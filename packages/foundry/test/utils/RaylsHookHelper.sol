// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.21;

import { console } from "forge-std/console.sol";
import "forge-std/StdJson.sol";
import { Vm } from "forge-std/Test.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

library RaylsHookHelper {
    using stdJson for string;

    struct PrivateSwapPublic {
        uint256 amountIn;
        uint256 timestamp;
        uint256 poseidonHash;
        bytes proofData;
    }

    function decryptCiphertext(Vm vm, string memory _auditorPk, string memory ciphertext)
        public
        returns (uint256 output)
    {
        // You can implement this function to validate the encryption on-chain if needed.
        // For example, you might want to check the length of the ciphertext or other properties.
        // Enable FFI
        string[] memory cmds = new string[](4);
        cmds[0] = "node";
        cmds[1] = "../encryption/decrypt.cjs";
        cmds[2] = _auditorPk;
        cmds[3] = cmds[3] = ciphertext;

        bytes memory result = vm.ffi(cmds);

        output = parseHexStringToUint(string(result));
    }

    function encryptValuesForAuditor(Vm vm) public {
        string[] memory cmds = new string[](2);
        cmds[0] = "node";
        cmds[1] = "../encryption/encrypt.js";

        vm.ffi(cmds);
    }

    function loadSuitabilityProof(string memory json)
        public
        pure
        returns (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals)
    {
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
    }

    function loadPrivateSwapIntentProof(string memory json)
        public
        pure
        returns (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals)
    {
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
    }

    function parseHexStringToUint(string memory s) internal pure returns (uint256) {
        bytes memory b = bytes(s);
        require(b.length >= 2 && b[0] == "0" && (b[1] == "x" || b[1] == "X"), "invalid hex string");

        uint256 result = 0;
        for (uint256 i = 2; i < b.length; i++) {
            uint8 c = uint8(b[i]);
            uint8 value;
            if (c >= 48 && c <= 57) {
                // 0-9
                value = c - 48;
            } else if (c >= 97 && c <= 102) {
                // a-f
                value = c - 87;
            } else if (c >= 65 && c <= 70) {
                // A-F
                value = c - 55;
            } else {
                revert("invalid hex char");
            }
            result = result * 16 + value;
        }
        return result;
    }

    function hexStringToBytes(string memory s) internal pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        uint256 offset = 0;

        // Skip optional "0x"
        if (ss.length >= 2 && ss[0] == "0" && (ss[1] == "x" || ss[1] == "X")) {
            offset = 2;
        }

        require((ss.length - offset) % 2 == 0, "hex string length must be even");

        bytes memory r = new bytes((ss.length - offset) / 2);
        for (uint256 i = 0; i < r.length; i++) {
            r[i] = bytes1(_fromHexChar(uint8(ss[offset + 2 * i])) * 16 + _fromHexChar(uint8(ss[offset + 2 * i + 1])));
        }
        return r;
    }

    function _fromHexChar(uint8 c) private pure returns (uint8) {
        if (c >= 48 && c <= 57) return c - 48; // '0'-'9'
        if (c >= 65 && c <= 70) return c - 55; // 'A'-'F'
        if (c >= 97 && c <= 102) return c - 87; // 'a'-'f'
        revert("invalid hex char");
    }

    function splitSig(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(sig.length == 65, "bad sig length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function buildPermitSignature(
        Vm vm,
        uint256 privateKey,
        address token,
        uint256 timestamp,
        address sender,
        address receiver,
        uint256 amount
    ) public view returns (bytes memory) {
        uint256 nonce = IERC20Permit(token).nonces(sender);
        uint256 deadline = timestamp + 1 days;

        // EIP-712 domain separator
        bytes32 DOMAIN_SEPARATOR = IERC20Permit(token).DOMAIN_SEPARATOR();

        // Permit typehash (same as OZ ERC20Permit)
        bytes32 PERMIT_TYPEHASH =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        // Build struct hash
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, sender, address(receiver), amount, nonce, deadline));

        // Final digest (EIP-712)
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        // Sign with Foundry’s vm.sign
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function getPublicSignalsFromPrivateSwapIntentProof(string memory json, bool fakePa, bool fakeHash)
        public
        pure
        returns (PrivateSwapPublic memory out)
    {
        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, uint256[5] memory pubSignals) =
            loadPrivateSwapIntentProof(json);

        if (fakePa) {
            // Change the poseidon hash to an incorrect one
            pA = [uint256(1), pA[1]];
        }

        if (fakeHash) {
            // Change the poseidon hash to an incorrect one
            pubSignals[0] = 1;
        }

        out.proofData = abi.encode(pA, pB, pC, pubSignals);
        out.poseidonHash = pubSignals[0];
        out.amountIn = pubSignals[1];
        out.timestamp = pubSignals[4];
    }

    function getJsonCiphertext(string memory _jsonEncryptedPayload)
        public
        pure
        returns (bytes memory ciphertextForAuditor)
    {
        string memory ciphertextForAuditorStr = _jsonEncryptedPayload.readString(".ciphertextForAuditor");
        ciphertextForAuditor = RaylsHookHelper.hexStringToBytes(ciphertextForAuditorStr);
    }
}
