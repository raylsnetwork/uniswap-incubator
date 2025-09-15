pragma circom 2.0.0;

include "node_modules/circomlib/circuits/bitify.circom";
include "node_modules/circomlib/circuits/comparators.circom";

/**
 * answers[i] ∈ {0,1,2,3}
 * weights = [3,3,2,2,1]
 * weightedScore = Σ (answers[i] * weights[i]) ∈ [0..33]
 * isSuitable = (weightedScore >= thresholdScaled)
 *
 * Públicos: thresholdScaled, isSuitablePub
 */
template SuitabilityWeighted() {
    // ---- Entradas privadas ----
    signal input answer1;
    signal input answer2;
    signal input answer3;
    signal input answer4;
    signal input answer5;

    // ---- Entrada pública para a wallet ----
    signal input wallet; // a 160-bit Ethereum address

    // ---- Entradas públicas ----
    signal input thresholdScaled;   // 0..33 (frente converte 0..15 → 0..33)
    signal input isSuitablePub;

    // ---- Saídas ----
    signal output weightedScore;    // Σ (ai * wi)
    signal output isSuitable;

    // Range-check: cada answer em 2 bits (0..3)
    component a1b = Num2Bits(2); a1b.in <== answer1;
    component a2b = Num2Bits(2); a2b.in <== answer2;
    component a3b = Num2Bits(2); a3b.in <== answer3;
    component a4b = Num2Bits(2); a4b.in <== answer4;
    component a5b = Num2Bits(2); a5b.in <== answer5;

    // Ponderação
    signal w1; w1 <== answer1 * 3;
    signal w2; w2 <== answer2 * 3;
    signal w3; w3 <== answer3 * 2;
    signal w4; w4 <== answer4 * 2;
    signal w5; w5 <== answer5 * 1;

    weightedScore <== w1 + w2 + w3 + w4 + w5;  // ∈ [0..33] (cabe em 6 bits)

    // Comparação: weightedScore >= thresholdScaled
    // Usamos LessThan(6) porque 2^6 = 64 > 33
    component lt = LessThan(6);
    lt.in[0] <== weightedScore;
    lt.in[1] <== thresholdScaled;

    isSuitable <== 1 - lt.out;

    // Amarra a saída pública
    isSuitable === isSuitablePub;

    // Booleanidade
    isSuitable * (1 - isSuitable) === 0;
}

// Tornar públicos: thresholdScaled e isSuitablePub
component main { public [thresholdScaled, isSuitablePub, wallet] } = SuitabilityWeighted();