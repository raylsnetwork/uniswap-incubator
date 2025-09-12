import * as ethers from "ethers";
import eccrypto from "eccrypto";
import crypto from "crypto";
import fs from 'fs/promises';
import path from 'path';

// Generate random AES key and encrypt message
function aesGcmEncrypt(K, plaintext) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", K, iv);
  const enc = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, enc]);
}

function numberToBuffer(n, bytes = 32) {
    const buf = Buffer.alloc(bytes);
    buf.writeBigUInt64BE(BigInt(n), bytes - 8); // last 8 bytes
    return buf;
  }

async function main() {
    // Public key for 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
  const pubKeyUncompressed = "0x048318535b54105d4a7aae60c08fc45f9687181b4fdfc625bd1a753fa7397fed753547f11ca8696646f2f3acb08e31016afac23e630c5d11f59f61fef57b0d2aa5"; 

  const jsonPath = path.resolve('../circom/scripts/PrivateSwapIntent_input.json');
  const raw = await fs.readFile(jsonPath, 'utf-8');
  const privateSwapInputs = JSON.parse(raw);

  const senderBuf = ethers.getBytes(privateSwapInputs.sender); // Uint8Array
  const amountBuf = numberToBuffer(privateSwapInputs.amountIn);
  const zeroForOneBuf = numberToBuffer(privateSwapInputs.zeroForOne);
  const timestampBuf = numberToBuffer(privateSwapInputs.timestamp);

  const message = Buffer.concat([amountBuf, zeroForOneBuf, senderBuf, timestampBuf]);

  // Encrypt K with auditor’s public key (ECIES)
  const encForAuditor = await eccrypto.encrypt(
    Buffer.from(pubKeyUncompressed.slice(2), "hex"), // drop 0x
    message
  );

  const encryptedBuffer = Buffer.concat([
    encForAuditor.iv,             // 16 bytes
    encForAuditor.ephemPublicKey, // 65 bytes
    encForAuditor.ciphertext,     // variable
    encForAuditor.mac              // 32 bytes
  ]);

 const jsonData = {
    ciphertextForAuditor: ethers.hexlify(encryptedBuffer)
  };
  
  await fs.writeFile("../foundry/inputs/encryptedPayload.json", JSON.stringify(jsonData, null, 2));
}

main().catch(console.error);
