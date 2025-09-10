#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./organize_artifacts.sh SuitabilityAssessment v1
#   ./organize_artifacts.sh SuitabilityAssessment v2

CIRCUIT_NAME="${1:-SuitabilityAssessment}"
VERSION="${2:-v1}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ARTIFACTS_DIR="$PKG_ROOT/artifacts/$CIRCUIT_NAME/$VERSION"
mkdir -p "$ARTIFACTS_DIR"

# Arquivos de origem padrão (ajuste caminhos se necessário)
WASM_SRC="$PKG_ROOT/circuits/${CIRCUIT_NAME}_js/${CIRCUIT_NAME}.wasm"
ZKEY_SRC="$PKG_ROOT/pot/${CIRCUIT_NAME}_0001.zkey"
VKEY_SRC="$PKG_ROOT/pot/verification_key.json"

echo "[INFO] Organizando artefatos para $CIRCUIT_NAME@$VERSION"

# Valida se arquivos existem
[ -f "$WASM_SRC" ] || { echo "❌ Arquivo WASM não encontrado em $WASM_SRC"; exit 1; }
[ -f "$ZKEY_SRC" ] || { echo "❌ Arquivo ZKey não encontrado em $ZKEY_SRC"; exit 1; }
[ -f "$VKEY_SRC" ] || { echo "❌ Arquivo VKey não encontrado em $VKEY_SRC"; exit 1; }

# Copia arquivos para estrutura padronizada
cp "$WASM_SRC" "$ARTIFACTS_DIR/circuit.wasm"
cp "$ZKEY_SRC" "$ARTIFACTS_DIR/circuit.zkey"
cp "$VKEY_SRC" "$ARTIFACTS_DIR/verification_key.json"

echo "[OK] Artefatos organizados em: $ARTIFACTS_DIR"