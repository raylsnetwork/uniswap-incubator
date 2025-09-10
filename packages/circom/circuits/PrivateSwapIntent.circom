pragma circom 2.0.0;

include "poseidon.circom";

template CommitmentCheck() {
    // Private inputs
    signal input amountIn;
    signal input zeroForOne;
    signal input sender;
    signal input timestamp;

    // Public output
    signal output commitment;
    signal output pubAmount;
    signal output pubZeroForOne;
    signal output pubSender;
    signal output pubTimestamp;

    component poseidon = Poseidon(4);

    poseidon.inputs[0] <== amountIn;
    poseidon.inputs[1] <== zeroForOne;
    poseidon.inputs[2] <== sender;
    poseidon.inputs[3] <== timestamp;

    poseidon.out ==> commitment;
    pubAmount <== amountIn;
    pubZeroForOne <== zeroForOne;
    pubSender <== sender;
    pubTimestamp <== timestamp;
}

component main = CommitmentCheck();