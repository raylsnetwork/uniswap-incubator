#!/usr/bin/env bash
set -euo pipefail

# ───────────────────────────── 
# Arguments
# ─────────────────────────────


ONLYNEWPROOF=false
CIRCUIT_NAME="SuitabilityAssessment"   # default

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --new-proof)
      ONLYNEWPROOF=true
      shift
      ;;
    --circuit)
      CIRCUIT_NAME="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [--new-proof] [--circuit CIRCUIT_NAME]"
      exit 0
      ;;
    *)
      echo "Unknown flag: $1"
      exit 1
      ;;
  esac
done

# ─────────────────────────────
# Configuração básica
# ─────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CIRCUITS_DIR="$PKG_ROOT/circuits"
POT_DIR="$PKG_ROOT/pot"
CONTRACTS_DIR="$PKG_ROOT/contracts"
FOUNDRY_DIR="$PKG_ROOT/../foundry"
VERIFIER_NAME="${CIRCUIT_NAME}Verifier.sol"
CONTRACT_VERIFIER="$FOUNDRY_DIR/contracts/$VERIFIER_NAME"

INPUT_JSON="$SCRIPT_DIR/${CIRCUIT_NAME}_input.json"
R1CS_PATH="$CIRCUITS_DIR/${CIRCUIT_NAME}.r1cs"
WASM_DIR="$CIRCUITS_DIR/${CIRCUIT_NAME}_js"
WASM_PATH="$WASM_DIR/${CIRCUIT_NAME}.wasm"
GEN_WITNESS_JS="$WASM_DIR/generate_witness.js"

PTAU0="$POT_DIR/${CIRCUIT_NAME}_pot12_0000.ptau"
PTAU1="$POT_DIR/${CIRCUIT_NAME}_pot12_0001.ptau"
PTAU_FINAL="$POT_DIR/${CIRCUIT_NAME}_pot12_final.ptau"

ZKEY0="$POT_DIR/${CIRCUIT_NAME}_0000.zkey"
ZKEY1="$POT_DIR/${CIRCUIT_NAME}_0001.zkey"
VKEY_JSON="$POT_DIR/${CIRCUIT_NAME}_verification_key.json"

WITNESS="$PKG_ROOT/${CIRCUIT_NAME}_witness.wtns"
PROOF_JSON="$PKG_ROOT/${CIRCUIT_NAME}_proof.json"
PUBLIC_JSON="$PKG_ROOT/${CIRCUIT_NAME}_public.json"

# ─────────────────────────────
# Helpers
# ─────────────────────────────
bin() {
  # prioriza CLI local do pacote
  if [ -x "$PKG_ROOT/node_modules/.bin/$1" ]; then
    echo "$PKG_ROOT/node_modules/.bin/$1"
  else
    echo "$1"
  fi
}
CIRCOM_BIN="$(bin circom)"
SNARKJS_BIN="$(bin snarkjs)"

log() { printf "\033[1;36m[zk]\033[0m %s\n" "$*"; }

# ─────────────────────────────
# Pré-checks
# ─────────────────────────────
mkdir -p "$POT_DIR"

if [ ! -f "$INPUT_JSON" ]; then
  echo "❌ input.json não encontrado em $INPUT_JSON"
  exit 1
fi

# ─────────────────────────────
# 1) Compilar circuito
# ─────────────────────────────
if [ "$ONLYNEWPROOF" = false ]; then
  log "Compilando circuito: $CIRCUITS_DIR/${CIRCUIT_NAME}.circom"
  "$CIRCOM_BIN" "$CIRCUITS_DIR/${CIRCUIT_NAME}.circom" \
    --r1cs --wasm --sym --c \
    -l "$PKG_ROOT" \
    -l "$PKG_ROOT/node_modules/circomlib/circuits" \
    -o "$CIRCUITS_DIR"
fi
# ─────────────────────────────
# 2) Gerar witness
# (usa generate_witness.js gerado pelo circom em <circuit>_js/)
# ─────────────────────────────
if [ ! -f "$GEN_WITNESS_JS" ]; then
  echo "❌ generate_witness.js não encontrado em $GEN_WITNESS_JS"
  exit 1
fi
log "Gerando witness em: $WITNESS"
node "$GEN_WITNESS_JS" "$WASM_PATH" "$INPUT_JSON" "$WITNESS"

if [ "$ONLYNEWPROOF" = false ]; then
  # ─────────────────────────────
  # 3) Powers of Tau (bn128, 12)
  # ─────────────────────────────
  if [ ! -f "$PTAU0" ]; then
    log "Iniciando Powers of Tau → $PTAU0"
    "$SNARKJS_BIN" powersoftau new bn128 12 "$PTAU0" -v
  else
    log "PTAU inicial já existe: $PTAU0"
  fi

  log "Contribuindo para PTAU → $PTAU1"
  "$SNARKJS_BIN" powersoftau contribute "$PTAU0" "$PTAU1" --name="First contribution" -v

  # ─────────────────────────────
  # 4) Phase 2 + setup groth16 + contribuição + export vkey
  # ─────────────────────────────
  log "Preparando Phase 2 → $PTAU_FINAL"
  "$SNARKJS_BIN" powersoftau prepare phase2 "$PTAU1" "$PTAU_FINAL" -v

  log "groth16 setup → $ZKEY0"
  "$SNARKJS_BIN" groth16 setup "$R1CS_PATH" "$PTAU_FINAL" "$ZKEY0"

  log "zkey contribute → $ZKEY1"
  "$SNARKJS_BIN" zkey contribute "$ZKEY0" "$ZKEY1" --name="1st Contributor Name" -v

  log "Exportando verification key → $VKEY_JSON"
  "$SNARKJS_BIN" zkey export verificationkey "$ZKEY1" "$VKEY_JSON"
fi
# ─────────────────────────────
# 5) Gerar prova
# ─────────────────────────────
log "Gerando prova → $PROOF_JSON | público → $PUBLIC_JSON"
"$SNARKJS_BIN" groth16 prove "$ZKEY1" "$WITNESS" "$PROOF_JSON" "$PUBLIC_JSON"

# ─────────────────────────────
# 6) Verificar prova
# ─────────────────────────────
log "Verificando prova…"
"$SNARKJS_BIN" groth16 verify "$VKEY_JSON" "$PUBLIC_JSON" "$PROOF_JSON"
log "✅ Prova verificada com sucesso!"

# ─────────────────────────────
# 7) Gerar solidity
# ─────────────────────────────
if [ "$ONLYNEWPROOF" = false ]; then
  log "Exportando Solidity verifier → $CONTRACT_VERIFIER"
  "$SNARKJS_BIN" zkey export solidityverifier "$ZKEY1" "$CONTRACT_VERIFIER"

  log Renaming verifier contract to ${CIRCUIT_NAME}Verifier…
  sed -i "s/contract Groth16Verifier/contract ${CIRCUIT_NAME}Verifier/" "$CONTRACT_VERIFIER"
fi

log criando inputs Solidity…
"$SNARKJS_BIN" zkey export soliditycalldata "$PUBLIC_JSON" "$PROOF_JSON" | sed '1s/^/[/; $s/$/]/' > "$FOUNDRY_DIR/${CIRCUIT_NAME}Inputs.json" 
