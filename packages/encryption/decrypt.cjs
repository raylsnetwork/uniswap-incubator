// We will use the oputput of this script (commitment ID) in the Foundry tests
// So Im removing all logs
console.info = () => {};
console.log = () => {};
console.err = () => {};
const eccrypto = require("eccrypto");
const crypto = require("crypto");
const { buildPoseidon } = require("circomlibjs");



// ECIES encrypted symmetric key (from encrypt.js)
if (process.argv.length !== 5) {
  console.error("Usage: node decrypt.cjs <auditorPrivateKey> <ciphertextHex> <encKeyForAuditor>");
  process.exit(1);
}

const auditorPrivKey = process.argv[2];
const ciphertextHex = process.argv[3];
const encKeyForAuditor = process.argv[4];

// Auditor private key (Buffer)
const auditorPriv = Buffer.from(
  auditorPrivKey.replace(/^0x/, ""),
  "hex"
);

const ciphertextBuffer = Buffer.from(ciphertextHex.replace(/^0x/, ""), "hex");
const encKeyForAuditorBuffer = Buffer.from(encKeyForAuditor.replace(/^0x/, ""), "hex");

// ----------------------
// Helper functions
// ----------------------

// 1️⃣ Decrypt symmetric key K using ECIES
async function decryptSymmetricKey(encKeyForAuditorBuffer, auditorPriv) {
  const iv = encKeyForAuditorBuffer.subarray(0, 16);
  const ephemPub = encKeyForAuditorBuffer.subarray(16, 16+65);
  const ciphertext = encKeyForAuditorBuffer.subarray(16+65, encKeyForAuditorBuffer.length - 32);
  const mac = encKeyForAuditorBuffer.subarray(encKeyForAuditorBuffer.length - 32);

  const encrypted = { iv, ephemPublicKey: ephemPub, ciphertext, mac };
  const K = await eccrypto.decrypt(auditorPriv, encrypted);
  return K;
}

// 2️⃣ Decrypt AES-GCM ciphertext
function decryptMessage(K, ciphertextBuffer) {
  const iv = ciphertextBuffer.slice(0, 12);
  const tag = ciphertextBuffer.slice(12, 28); // 16 bytes tag
  const enc = ciphertextBuffer.slice(28);

  const decipher = crypto.createDecipheriv("aes-256-gcm", K, iv);
  decipher.setAuthTag(tag);
  const plaintext = Buffer.concat([decipher.update(enc), decipher.final()]);
  return plaintext;
}

// 3️⃣ Parse plaintext buffer into circuit inputs
function parseMessage(plaintext) {
  let offset = 0;

  // Each numeric field was serialized into 32 bytes with last 8 bytes containing the number
  const amountIn = Number(plaintext.readBigUInt64BE(offset + 24));
  offset += 32;

  const zeroForOne = Number(plaintext.readBigUInt64BE(offset + 24));
  offset += 32;

  const sender = "0x" + plaintext.slice(offset, offset + 20).toString("hex");
  offset += 20;

  const timestamp = Number(plaintext.readBigUInt64BE(offset + 24));
  offset += 32;

  return { amountIn, zeroForOne, sender, timestamp };
}

async function computeCommitmentId(amountIn, zeroForOne, sender, timestamp) {
  const poseidon = await buildPoseidon();
  const F = poseidon.F;

  // Poseidon inputs must be BigInts
  const inputs = [
    BigInt(amountIn),
    BigInt(zeroForOne),
    BigInt(sender),
    BigInt(timestamp)
  ];

  const hash = poseidon(inputs);
  return "0x" + F.toString(hash, 16).padStart(64, "0");
}

// ----------------------
// Main
// ----------------------
(async () => {
  // Recover symmetric key
  const K = await decryptSymmetricKey(encKeyForAuditorBuffer, auditorPriv);

  // Decrypt message
  const plaintext = decryptMessage(K, ciphertextBuffer);

  // Parse back to circuit inputs
  const parsed = parseMessage(plaintext);

  // Compute commitment ID
  const commitmentId = await computeCommitmentId(
    parsed.amountIn,
    parsed.zeroForOne,
    parsed.sender,
    parsed.timestamp
  );

  // Output commitment ID for use in Foundry tests
  process.stdout.write("0x" + Buffer.from(commitmentId).toString("hex"));
})();
