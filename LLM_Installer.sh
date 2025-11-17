\
#!/usr/bin/env bash
set -euo pipefail

LOGFILE="/data/nano_llm/install.log"

echo "==============================================================="
echo " NanoLLM Installer Run: $(date)"
echo "==============================================================="

if [[ -z "${HUGGINGFACE_HUB_TOKEN:-}" && -z "${HUGGINGFACE_TOKEN:-}" ]]; then
  echo "WARNING: No Hugging Face token detected."
  echo "Some gated models (Gemma, Meditron, etc.) may fail to download."
else
  echo "HuggingFace token detected."
fi
echo

tiny_models=(
  "TinyLlama/TinyLlama-1.1B-Chat-v1.0"
  "meta-llama/Llama-3.2-1B-Instruct"
  "meta-llama/Llama-3.2-3B-Instruct"
  "microsoft/Phi-3-mini-4k-instruct"
)

gpt_oss_models=(
  "GPT-OSS/gpt-oss-3b"
  "GPT-OSS/gpt-oss-7b"
)

mid_models=(
  "meta-llama/Meta-Llama-3-8B-Instruct"
  "Qwen/Qwen2.5-7B-Instruct"
  "mistralai/Mistral-7B-Instruct-v0.2"
)

specialized_models=(
  "deepseek-ai/deepseek-coder-6.7b-instruct"
  "ProsusAI/finbert"
  "epfl-llm/meditron-7b"
)

gemma_models=(
  "google/gemma-2-2b-it"
  "google/gemma-2-9b-it"
)

install_group() {
  local group_name="$1"
  shift
  local -a models=("$@")

  {
    echo "-----------------------------------------------------------"
    echo " INSTALLING GROUP: ${group_name}"
    echo "-----------------------------------------------------------"
  } | tee -a "$LOGFILE"

  for model in "${models[@]}"; do
    {
      echo
      echo ">>> Installing: ${model}"
      echo "Started: $(date)"
    } | tee -a "$LOGFILE"

    if huggingface-cli download \
        "$model" \
        --local-dir "/data/models/huggingface/$model" \
        --local-dir-use-symlinks False; then
      {
        echo "/data/models/huggingface/$model"
        echo "SUCCESS: $model"
        echo "Finished: $(date)"
        echo "-----------------------------------------------------------"
      } | tee -a "$LOGFILE"
    else
      {
        echo "ERROR: Failed to download $model"
        echo "Finished: $(date)"
        echo "-----------------------------------------------------------"
      } | tee -a "$LOGFILE"
    fi
  done
}

echo "Select an install option:"
echo "  1) Install Tiny / Small models"
echo "  2) Install GPT-OSS models"
echo "  3) Install Mid-size models"
echo "  4) Install Specialized"
echo "  5) Install Gemma-2"
echo "  6) Install EVERYTHING"
echo "  7) Exit"
echo

read -rp "Choice [1-7]: " choice
echo

case "$choice" in
  1)
    install_group "TINY_MODELS" "${tiny_models[@]}"
    ;;
  2)
    install_group "GPT_OSS_MODELS" "${gpt_oss_models[@]}"
    ;;
  3)
    install_group "MID_MODELS" "${mid_models[@]}"
    ;;
  4)
    install_group "SPECIALIZED_MODELS" "${specialized_models[@]}"
    ;;
  5)
    install_group "GEMMA_MODELS" "${gemma_models[@]}"
    ;;
  6)
    install_group "TINY_MODELS" "${tiny_models[@]}"
    install_group "GPT_OSS_MODELS" "${gpt_oss_models[@]}"
    install_group "MID_MODELS" "${mid_models[@]}"
    install_group "SPECIALIZED_MODELS" "${specialized_models[@]}"
    install_group "GEMMA_MODELS" "${gemma_models[@]}"
    ;;
  7)
    echo "Exiting installer."
    exit 0
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

{
  echo
  echo "==============================================================="
  echo " Installer Complete at $(date)"
  echo " Log saved to: ${LOGFILE}"
  echo "==============================================================="
} | tee -a "$LOGFILE"
