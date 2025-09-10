#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./zk_prove_verify.sh                      # usa circuito SuitabilityAssessment e scripts/input.json
#   ./zk_prove_verify.sh --circuit Multiplier2 --input ./inputs/m2.json
#   ./zk_prove_verify.sh -c SuitabilityAssessment -i ./scripts/input.json -o ./artifacts/custom

# ─────────────────────────────
# Defaults
# ─────────────────────────────
CIRCUIT_NAME="SuitabilityAssessment"
INPUT_JSON=""
OUT_DIR=""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CIRCUITS_DIR="$PKG_ROOT/circuits"
POT_DIR="$PKG_ROOT/pot"
ART_ROOT="$PKG_ROOT/artifacts"

# ─────────────────────────────
# Parse flags
# ─────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--circuit) CIRCUIT_NAME="$2"; shift 2;;
    -i|--input)   INPUT_JSON="$2";  shift 2;;
    -o|--outdir)  OUT_DIR="$2";     shift 2;;
    -h|--help)
      echo "Usage: $0 [-c|--circuit NAME] [-i|--input FILE] [-o|--outdir DIR]"
      exit 0
      ;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

# Defaults if not provided
INPUT_JSON="${INPUT_JSON:-"$SCRIPT_DIR/input.json"}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="${OUT_DIR:-"$ART_ROOT/$CIRCUIT_NAME/$STAMP"}"

# ─────────────────────────────
# Paths/CLI
# ─────────────────────────────
WASM_DIR="$CIRCUITS_DIR/${CIRCUIT_NAME}_js"
WASM_PATH="$WASM_DIR/${CIRCUIT_NAME}.wasm"
GEN_WITNESS_JS="$WASM_DIR/generate_witness.js"

# zkey/vkey vindos do setup anterior (mantive seus nomes)
ZKEY_CANDIDATES=(
  "$POT_DIR/${CIRCUIT_NAME}_final.zkey"
  "$POT_DIR/${CIRCUIT_NAME}_0001.zkey"
  "$POT_DIR/${CIRCUIT_NAME}.zkey"
)
VKEY_CANDIDATES=(
  "$POT_DIR/verification_key.json"
  "$POT_DIR/${CIRCUIT_NAME}_verification_key.json"
)

bin() {
  if [ -x "$PKG_ROOT/node_modules/.bin/$1" ]; then
    echo "$PKG_ROOT/node_modules/.bin/$1"
  else
    echo "$1"
  fi
}
SNARKJS_BIN="$(bin snarkjs)"

log() { printf "\033[1;36m[zk]\033[0m %s\n" "$*"; }

# ─────────────────────────────
# Checks
# ─────────────────────────────
mkdir -p "$OUT_DIR"

[ -f "$INPUT_JSON" ]      || { echo "❌ input.json não encontrado: $INPUT_JSON"; exit 1; }
[ -f "$WASM_PATH" ]       || { echo "❌ WASM não encontrado: $WASM_PATH (compile o circuito antes)"; exit 1; }
[ -f "$GEN_WITNESS_JS" ]  || { echo "❌ generate_witness.js não encontrado: $GEN_WITNESS_JS"; exit 1; }

ZKEY=""
for z in "${ZKEY_CANDIDATES[@]}"; do
  if [ -f "$z" ]; then ZKEY="$z"; break; fi
done
[ -n "$ZKEY" ] || { echo "❌ ZKey não encontrado em: ${ZKEY_CANDIDATES[*]} (rode o setup)"; exit 1; }

VKEY=""
for v in "${VKEY_CANDIDATES[@]}"; do
  if [ -f "$v" ]; then VKEY="$v"; break; fi
done
[ -n "$VKEY" ] || { echo "❌ Verification key não encontrada em: ${VKEY_CANDIDATES[*]} (rode o setup)"; exit 1; }

WITNESS="$OUT_DIR/witness.wtns"
PROOF_JSON="$OUT_DIR/proof.json"
PUBLIC_JSON="$OUT_DIR/public.json"

# ─────────────────────────────
# 1) Gerar witness (apenas muda o input)
# ─────────────────────────────
log "Gerando witness → $WITNESS"
node "$GEN_WITNESS_JS" "$WASM_PATH" "$INPUT_JSON" "$WITNESS"

# ─────────────────────────────
# 2) Provar
# ─────────────────────────────
log "Gerando prova → $PROOF_JSON / público → $PUBLIC_JSON"
"$SNARKJS_BIN" groth16 prove "$ZKEY" "$WITNESS" "$PROOF_JSON" "$PUBLIC_JSON"

# ─────────────────────────────
# 3) Verificar
# ─────────────────────────────
log "Verificando prova…"
"$SNARKJS_BIN" groth16 verify "$VKEY" "$PUBLIC_JSON" "$PROOF_JSON"

log "✅ Prova verificada! Artefatos em: $OUT_DIR"