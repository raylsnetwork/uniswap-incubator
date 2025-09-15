#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────
# Args
# ─────────────────────────────
ONLYNEWPROOF=false
FORCE_SETUP=false
CIRCUIT_NAME="Suitability"
ENTROPY="$(openssl rand -hex 32 || echo 'deadbeef')"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --new-proof)   ONLYNEWPROOF=true; shift ;;
    --force-setup) FORCE_SETUP=true; shift ;;
    --circuit)     CIRCUIT_NAME="$2"; shift 2 ;;
    --help|-h)
      cat <<EOF
Usage: $0 [--new-proof] [--force-setup] [--circuit CIRCUIT_NAME]

--new-proof     Reutiliza PTAU/Phase2/ZKey e gera apenas nova prova
--force-setup   Refaz Phase2 + setup + zkey (troca o VK!)
--circuit       Nome do circuito (default: Suitability)
EOF
      exit 0
      ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

# ─────────────────────────────
# Paths
# ─────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CIRCUITS_DIR="$PKG_ROOT/circuits"
FOUNDRY_DIR="$PKG_ROOT/../foundry"
FOUNDRY_INPUTS_DIR="$PKG_ROOT/../foundry/inputs"
VERIFIER_NAME="${CIRCUIT_NAME}Verifier.sol"
CONTRACT_VERIFIER="$FOUNDRY_DIR/contracts/$VERIFIER_NAME"
OUT_DIR="$FOUNDRY_DIR" # onde salvamos os artefatos de chamada
ARTIFACTS_DIR="$PKG_ROOT/artifacts"
POT_DIR="$ARTIFACTS_DIR/pot"

INPUT_JSON="$SCRIPT_DIR/${CIRCUIT_NAME}_input.json"
R1CS_PATH="$ARTIFACTS_DIR/${CIRCUIT_NAME}.r1cs"
WASM_DIR="$ARTIFACTS_DIR/${CIRCUIT_NAME}_js"
WASM_PATH="$WASM_DIR/${CIRCUIT_NAME}.wasm"
GEN_WITNESS_JS="$WASM_DIR/generate_witness.js"

PTAU0="$POT_DIR/${CIRCUIT_NAME}_pot12_0000.ptau"
PTAU1="$POT_DIR/${CIRCUIT_NAME}_pot12_0001.ptau"
PTAU_FINAL="$POT_DIR/${CIRCUIT_NAME}_pot12_final.ptau"

ZKEY0="$POT_DIR/${CIRCUIT_NAME}_0000.zkey"
ZKEY1="$POT_DIR/${CIRCUIT_NAME}_0001.zkey"
VKEY_JSON="$POT_DIR/${CIRCUIT_NAME}_verification_key.json"

WITNESS="$ARTIFACTS_DIR/${CIRCUIT_NAME}_witness.wtns"
PROOF_JSON="$ARTIFACTS_DIR/${CIRCUIT_NAME}_proof.json"
PUBLIC_JSON="$ARTIFACTS_DIR/${CIRCUIT_NAME}_public.json"

CALLDATA_TXT="$OUT_DIR/solidityCalldata.txt"
INPUTS_HEX_JSON="$OUT_DIR/solidityInputs.json"
INPUTS_DEC_JSON="$OUT_DIR/solidityInputs.decimal.json"
INPUTS_UI_JSON="$OUT_DIR/solidityInputs.ui.json"
CAST_CALL_SH="$OUT_DIR/cast_call.sh"

# ─────────────────────────────
# Binaries
# ─────────────────────────────
bin() {
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
# Pre-checks
# ─────────────────────────────
mkdir -p "$POT_DIR" "$OUT_DIR" "$ARTIFACTS_DIR" "$FOUNDRY_INPUTS_DIR"
if [ ! -f "$INPUT_JSON" ]; then
  echo "❌ input.json não encontrado em $INPUT_JSON"; exit 1
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
    -o "$ARTIFACTS_DIR"
fi

# ─────────────────────────────
# 2) Witness
# ─────────────────────────────
if [ ! -f "$GEN_WITNESS_JS" ]; then
  echo "❌ generate_witness.js não encontrado em $GEN_WITNESS_JS"; exit 1
fi
log "Gerando witness → $WITNESS"
node "$GEN_WITNESS_JS" "$WASM_PATH" "$INPUT_JSON" "$WITNESS"

# ─────────────────────────────
# 3) PTAU/Phase2/Setup/ZKey (reuso por default)
# ─────────────────────────────
if [ "$ONLYNEWPROOF" = true ]; then
  [ -f "$ZKEY1" ] || { echo "❌ $ZKEY1 não encontrado. Rode sem --new-proof (ou --force-setup) ao menos uma vez."; exit 1; }
  [ -f "$VKEY_JSON" ] || { echo "❌ $VKEY_JSON não encontrado. Rode sem --new-proof (ou --force-setup)."; exit 1; }
else
  if [ "$FORCE_SETUP" = true ] || [ ! -f "$PTAU_FINAL" ]; then
    log "PTAU inicial $( [ -f "$PTAU0" ] && echo 'já existe' || echo 'novo' ) → $PTAU0"
    [ -f "$PTAU0" ] || "$SNARKJS_BIN" powersoftau new bn128 12 "$PTAU0" -v

    log "Contribuindo PTAU → $PTAU1"
    "$SNARKJS_BIN" powersoftau contribute "$PTAU0" "$PTAU1" --name="First contribution" --entropy="$ENTROPY" -v

    log "Phase 2 → $PTAU_FINAL"
    "$SNARKJS_BIN" powersoftau prepare phase2 "$PTAU1" "$PTAU_FINAL" -v
  else
    log "Reutilizando Phase 2 existente → $PTAU_FINAL"
  fi

  if [ "$FORCE_SETUP" = true ] || [ ! -f "$ZKEY1" ]; then
    log "groth16 setup → $ZKEY0"
    "$SNARKJS_BIN" groth16 setup "$R1CS_PATH" "$PTAU_FINAL" "$ZKEY0"

    log "zkey contribute → $ZKEY1"
    "$SNARKJS_BIN" zkey contribute "$ZKEY0" "$ZKEY1" --name="1st Contributor" --entropy="$ENTROPY" -v

    log "Exportando verification key → $VKEY_JSON"
    "$SNARKJS_BIN" zkey export verificationkey "$ZKEY1" "$VKEY_JSON"

    log "Exportando Solidity verifier → $CONTRACT_VERIFIER"
    "$SNARKJS_BIN" zkey export solidityverifier "$ZKEY1" "$CONTRACT_VERIFIER"

    # Renomeio compatível com macOS/BSD
    if grep -q 'contract Groth16Verifier' "$CONTRACT_VERIFIER"; then
      perl -0777 -pe "s/contract Groth16Verifier/contract ${CIRCUIT_NAME}Verifier/g" -i "$CONTRACT_VERIFIER"
    fi
  else
    log "Reutilizando ZKey existente → $ZKEY1"
    [ -f "$VKEY_JSON" ] || "$SNARKJS_BIN" zkey export verificationkey "$ZKEY1" "$VKEY_JSON"

    # Reexporta sempre o verifier para não ficar desatualizado
    log "Reexportando Solidity verifier do ZKEY atual → $CONTRACT_VERIFIER"
    "$SNARKJS_BIN" zkey export solidityverifier "$ZKEY1" "$CONTRACT_VERIFIER"
    if grep -q 'contract Groth16Verifier' "$CONTRACT_VERIFIER"; then
      perl -0777 -pe "s/contract Groth16Verifier/contract ${CIRCUIT_NAME}Verifier/g" -i "$CONTRACT_VERIFIER"
    fi
  fi
fi

# ─────────────────────────────
# 4) Prova + Verificação off-chain
# ─────────────────────────────
log "Prove → $PROOF_JSON | Public → $PUBLIC_JSON"
"$SNARKJS_BIN" groth16 prove "$ZKEY1" "$WITNESS" "$PROOF_JSON" "$PUBLIC_JSON"

log "Verify off-chain…"
"$SNARKJS_BIN" groth16 verify "$VKEY_JSON" "$PUBLIC_JSON" "$PROOF_JSON"
log "✅ Prova verificada com sucesso!"

# ─────────────────────────────
# 5) Artefatos p/ UI & cast
# ─────────────────────────────
# 5.1 Calldata (hex em 1 linha)
log "Exportando solidityCalldata (hex) → $CALLDATA_TXT"
"$SNARKJS_BIN" zkey export soliditycalldata "$PUBLIC_JSON" "$PROOF_JSON" > "$CALLDATA_TXT"

#log Renaming verifier contract to ${CIRCUIT_NAME}Verifier…
#sed -i "s/contract Groth16Verifier/contract ${CIRCUIT_NAME}Verifier/" "$CONTRACT_VERIFIER"

log criando inputs Solidity…
"$SNARKJS_BIN" zkey export soliditycalldata "$PUBLIC_JSON" "$PROOF_JSON" | sed '1s/^/[/; $s/$/]/' > "$FOUNDRY_INPUTS_DIR/${CIRCUIT_NAME}Inputs.json" 

# Lucas part:
# 5.2 solidityInputs.json (HEX) a partir do calldata
log "Gerando $INPUTS_HEX_JSON a partir do calldata…"
{
  printf '['
  cat "$CALLDATA_TXT"
  printf ']\n'
} > "$INPUTS_HEX_JSON"

# 5.3 Versão decimal (strings) – para UIs/libs que não aceitam hex
log "Gerando $INPUTS_DEC_JSON (decimal)…"
node - <<'NODE'
const fs = require('fs');
const path = require('path');

const here = path.resolve(__dirname, '..');          // packages/circom/scripts
const foundry = path.resolve(here, '../foundry');    // packages/foundry

const hexPath = path.join(foundry, 'solidityInputs.json');
const decPath = path.join(foundry, 'solidityInputs.decimal.json');

const data = JSON.parse(fs.readFileSync(hexPath, 'utf8'));

function toDec(x){
  if (Array.isArray(x)) return x.map(toDec);
  if (typeof x === 'string' && x.startsWith('0x')) return BigInt(x).toString(10);
  return String(x);
}

const dec = [ toDec(data[0]), toDec(data[1]), toDec(data[2]), toDec(data[3]) ];
fs.writeFileSync(decPath, JSON.stringify(dec));
console.log('ok');
NODE

# 5.4 Versão para UI (strings; hex preservado)
log "Gerando $INPUTS_UI_JSON (UI – strings em hex)…"
node - <<'NODE'
const fs = require('fs');
const path = require('path');

const here = path.resolve(__dirname, '..');          // packages/circom/scripts
const foundry = path.resolve(here, '../foundry');    // packages/foundry

const hexPath = path.join(foundry, 'solidityInputs.json');
const uiPath  = path.join(foundry, 'solidityInputs.ui.json');

const data = JSON.parse(fs.readFileSync(hexPath, 'utf8'));
const toUI = (x) => Array.isArray(x) ? x.map(toUI) : String(x);
const ui = [ toUI(data[0]), toUI(data[1]), toUI(data[2]), toUI(data[3]) ];
fs.writeFileSync(uiPath, JSON.stringify(ui));
console.log('ok');
NODE

# 5.5 Script de cast call (auto-detecta N dos públicos)
cat > "$CAST_CALL_SH" <<'EOSH'
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
EOSH
chmod +x "$CAST_CALL_SH"

# ─────────────────────────────
# 6) Sanidade dos arquivos
# ─────────────────────────────
log "Sanidade dos artefatos:"
for f in "$CALLDATA_TXT" "$INPUTS_HEX_JSON" "$INPUTS_DEC_JSON" "$INPUTS_UI_JSON" "$CAST_CALL_SH"; do
  if [ -s "$f" ]; then
    echo "  ✔ $(basename "$f") ($(wc -c <"$f") bytes)"
  else
    echo "  ❌ $(basename "$f") está vazio!"
    exit 1
  fi
done

log "✅ Pipeline concluído"
