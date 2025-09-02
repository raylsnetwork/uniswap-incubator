pragma circom 2.0.0;

include "node_modules/circomlib/circuits/bitify.circom";
include "node_modules/circomlib/circuits/comparators.circom";

/**
 * Respostas: 0..3 (4 opções) -> use 2 bits p/ range-check.
 * riskScore = answer1 + answer2 + answer3 + answer4 + answer5 ∈ [0..15]
 * Adequação: isSuitable = (riskScore >= thresholdPts)
 */
template SuitabilityAssessment() {
    // ---- Entradas privadas (respostas) ----
    signal input answer1;
    signal input answer2;
    signal input answer3;
    signal input answer4;
    signal input answer5;

    // ---- Entradas públicas ----
    signal input thresholdPts;     // público real (o protocolo define)
    signal input isSuitablePub;    // espelho público da saída

    // ---- Saídas ----
    signal output riskScore;       // privado por padrão
    signal output isSuitable;      // saída “real” (privada a priori)

    // (range-checks opcionais; removi para focar no erro)
    riskScore <== answer1 + answer2 + answer3 + answer4 + answer5;

    // Comparação simples: isSuitable = (riskScore >= thresholdPts)
    component lt = LessThan(4);
    lt.in[0] <== riskScore;
    lt.in[1] <== thresholdPts;

    isSuitable <== 1 - lt.out;

    // Force o espelho público a ser igual à saída calculada
    isSuitable === isSuitablePub;

    // Booleanidade (boa prática)
    isSuitable * (1 - isSuitable) === 0;
}

// Somente *inputs* podem ser públicos.
// Aqui tornamos públicos: thresholdPts e isSuitablePub (o espelho).
component main { public [thresholdPts, isSuitablePub] } = SuitabilityAssessment();