\
#!/usr/bin/env bash
set -euo pipefail

MLC_DIR="${MLC_HOME:-/data/models/mlc}"
DIST_DIR="$MLC_DIR/dist"
HF_DIR="${HF_HOME:-/data/models/huggingface}"

mkdir -p "$DIST_DIR"

models_to_build=(
  "TinyLlama/TinyLlama-1.1B-Chat-v1.0"
  "mistralai/Mistral-7B-Instruct-v0.2"
  "deepseek-ai/deepseek-coder-6.7b-instruct"
)

echo "======================================================="
echo " Rebuilding MLC Context (quantized) Models"
echo "======================================================="
echo "MLC_HOME: $MLC_DIR"
echo "HF_HOME:  $HF_DIR"
echo

for model in "${models_to_build[@]}"; do
  name="$(basename "$model")"
  outdir="$DIST_DIR/$name"
  echo ">>> Building MLC artifact for: $model"
  echo "    Output dir: $outdir"
  echo

  /opt/conda/bin/mlc_llm convert \
      --model "$model" \
      --hf-path "$HF_DIR/$model" \
      --artifact-path "$outdir" \
      --quantization q4f16_ft || {
        echo "!!! Failed to build MLC artifact for $model"
        continue
      }

  echo "    Done: $model"
  echo
done

echo "All requested MLC builds attempted."
