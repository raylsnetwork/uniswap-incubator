#!/usr/bin/env bash
set -euo pipefail

ADDR="${ADDR:-}"
if [ -z "$ADDR" ]; then
  echo "Usage: ADDR=<verifier_address> $0"
  exit 1
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
INPUTS="$HERE/solidityInputs.json"

# monta parâmetros no formato que o cast espera (sem aspas)
A=$(node -e "const p=require(process.argv[1]);console.log('['+p[0].join(',')+']');" "$INPUTS")
B=$(node -e "const p=require(process.argv[1]);console.log('[['+p[1][0].join(',')+'],['+p[1][1].join(',')+']]');" "$INPUTS")
C=$(node -e "const p=require(process.argv[1]);console.log('['+p[2].join(',')+']');" "$INPUTS")
INP=$(node -e "const p=require(process.argv[1]);console.log('['+p[3].join(',')+']');" "$INPUTS")
N=$(node -e "const p=require(process.argv[1]);console.log(p[3].length);" "$INPUTS")

SIG="verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[$N])"

cast call "$ADDR" "$SIG" "$A" "$B" "$C" "$INP"
