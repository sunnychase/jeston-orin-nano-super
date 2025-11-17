\
#!/usr/bin/env bash
set -euo pipefail

LOGFILE="/data/nano_llm/install.log"
HF_DIR="${HF_HOME:-/data/models/huggingface}"
MLC_DIR="${MLC_HOME:-/data/models/mlc}"

echo "======================================================="
echo " NanoLLM Model Status Dashboard"
echo "======================================================="
echo "Date: $(date)"
echo "Log file: ${LOGFILE}"
echo

echo ">>> [1] Hugging Face models found on disk:"
if [[ -d "$HF_DIR" ]]; then
  HF_DIRS=$(find "$HF_DIR" -maxdepth 2 -mindepth 2 -type d 2>/dev/null | sort)
  echo "  Root: $HF_DIR"
  if [[ -z "$HF_DIRS" ]]; then
    echo "   (no model subdirectories found yet)"
  else
    while read -r d; do
      rel="${d#"$HF_DIR"/}"
      size=$(du -sh "$d" 2>/dev/null | awk '{print $1}')
      echo "   - ${rel}$(printf '%40s' '') (${size})"
    done <<< "$HF_DIRS"
  fi
else
  echo "  HF directory not found: $HF_DIR"
fi
echo

echo ">>> [2] MLC models (quantized builds):"
if [[ -d "$MLC_DIR/dist" ]]; then
  echo "  Root: $MLC_DIR/dist"
  MLC_DIRS=$(find "$MLC_DIR/dist" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
  if [[ -z "$MLC_DIRS" ]]; then
    echo "   (no MLC builds yet)"
  else
    while read -r d; do
      rel="${d#"$MLC_DIR/dist"/}"
      size=$(du -sh "$d" 2>/dev/null | awk '{print $1}')
      echo "   - ${rel}$(printf '%40s' '') (${size})"
    done <<< "$MLC_DIRS"
  fi
else
  echo "  MLC dist directory not found: $MLC_DIR/dist"
fi
echo

echo ">>> [3] NanoLLM runtime local models (if utils available):"
python3 - << 'PYCODE'
try:
    from nano_llm.utils import list_local_models
    models = list_local_models()
    if not models:
        print("  (no models registered with NanoLLM yet)")
    else:
        for m in models:
            print("  -", m)
except Exception as e:
    print("  Error calling list_local_models():", e)
PYCODE
echo

echo ">>> [4] Disk usage:"
echo "  df -h /data:"
df -h /data || true
echo
echo "  HF directory usage (depth 1):"
du -sh "$HF_DIR"/* 2>/dev/null || echo "  (no HF usage yet)"
echo
echo "  MLC directory usage (depth 2):"
du -sh "$MLC_DIR" "$MLC_DIR"/dist* 2>/dev/null || echo "  (no MLC usage yet)"
echo

echo ">>> [5] Recent installer log tail:"
if [[ -f "$LOGFILE" ]]; then
  tail -n 40 "$LOGFILE"
else
  echo "  (no install log found at $LOGFILE)"
fi

echo
echo "Done."
