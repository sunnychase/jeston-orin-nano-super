# 🧠 Jetson Orin Nano Super 8GB – NanoLLM Playground

Local LLM lab on a **Jetson Orin Nano Super 8GB (67 TOPS)** with:

- 🐋 `jetson-containers` + `dustynv/nano_llm` container  
- 📁 All models & caches on NVMe under `/data`  
- 📥 Bulk installer for multiple HF models (Gemma, Llama, Mistral, Qwen, DeepSeek-Coder, FinBERT, Meditron, TinyLlama, Phi-3)  
- 🔁 MLC builds for fast, low-overhead inference  
- 📊 Simple GPU benchmark script  
- 🎒 “Model loadout” catalog (which model to use when)  
- 🧩 Future-proof layout so adding new models later is trivial  

---

## ⚡ Suggested Defaults (Quick Reference)

| Role / Task                      | Recommended Model                          | Notes                                      |
|----------------------------------|-------------------------------------------|--------------------------------------------|
| **Default chat / reasoning**     | `google/gemma-2-9b-it` or `Meta-Llama-3-8B-Instruct` | Use Gemma-2 9B if VRAM/RAM allow           |
| **Lightweight assistant**       | `microsoft/Phi-3-mini-4k-instruct`        | Great balance of size vs. brains           |
| **Ultra-fast tiny helper**      | `TinyLlama/TinyLlama-1.1B-Chat-v1.0`      | For quick glue tasks / background jobs     |
| **Coding / scripts**            | `deepseek-ai/deepseek-coder-6.7b-instruct`| Python/Bash/code tasks                     |
| **Finance sentiment (SPY/QQQ)** | `ProsusAI/finbert`                        | Bullish / Bearish / Neutral labeling       |
| **Medical / vet research**      | `epfl-llm/meditron-7b`                    | For summarizing medical/vet PDFs           |
| **Multilingual assistant**      | `Qwen/Qwen2.5-7B-Instruct`                | Strong non-English performance             |

---

## 1️⃣ High-Level Overview

You are running:

- **Host OS:** Ubuntu on x86_64 (desktop/laptop)  
- **Target:** Jetson Orin Nano Super 8GB (JetPack 6 / L4T R36)  
- **Container stack:** [`jetson-containers`](https://github.com/dusty-nv/jetson-containers)  
- **LLM container:** `dustynv/nano_llm:r36.4.0` via `jetson-containers run $(autotag nano_llm)`  
- **NVMe mount (inside container):** `/data` (bind-mounted from `~/jetson-containers/data` on the host)

We keep all **models & caches** in `/data` so:

- You can blow away containers without touching the model cache  
- You can re-run installers or upgrade containers without redownloading everything  

---

## 2️⃣ Host-Side Setup (One-Time)

On your **host Ubuntu** machine (not inside Docker):

```bash
# Install git and basics (if needed)
sudo apt update
sudo apt install -y git curl python3 python3-pip

# Clone jetson-containers
cd ~
git clone https://github.com/dusty-nv/jetson-containers.git
cd jetson-containers
````

Make sure Docker + NVIDIA container runtime are set up (you already did this, but for completeness):

```bash
# Docker installed via NVIDIA / Jetson docs or:
curl https://get.docker.com | sh

# Enable and start Docker
sudo systemctl enable --now docker

# Add your user to docker group
sudo usermod -aG docker $USER
# then log out / log in or run:
newgrp docker

# (Jetson-specific runtime configuration is already handled by jetson-containers scripts)
```

---

## 3️⃣ Data Layout on NVMe (`/data`)

We bind `~/jetson-containers/data` on the host to `/data` in the container:

* Host path: `~/jetson-containers/data`
* Container path: `/data`

Inside the container we use:

* `HF_HOME=/data/models/huggingface`
* `MLC_HOME=/data/models/mlc`
* `XDG_CACHE_HOME=/data/cache`
* `NANO_LLM_HOME=/data/nano_llm`

### 3.1 Create data folders (inside container)

You already have these, but the canonical steps are:

```bash
cd ~/jetson-containers
jetson-containers run $(autotag nano_llm)

# now you're inside the nano_llm container as root@ubuntu
mkdir -p /data/nano_llm /data/models/huggingface /data/models/mlc /data/cache
```

Then define the environment file:

```bash
cat > /data/nano_llm/nano_env.sh << 'EOF'
# === NanoLLM / Caches on NVMe ===

# Hugging Face (models, snapshots, etc.)
export HF_HOME=/data/models/huggingface
export TRANSFORMERS_CACHE=/data/models/huggingface
export HUGGINGFACE_HUB_CACHE=/data/models/huggingface

# Generic cache
export XDG_CACHE_HOME=/data/cache

# MLC artifacts
export MLC_HOME=/data/models/mlc

# NanoLLM home
export NANO_LLM_HOME=/data/nano_llm
EOF

# Auto-source this for every shell in the container:
echo '[[ -f /data/nano_llm/nano_env.sh ]] && source /data/nano_llm/nano_env.sh' >> ~/.bashrc
source /data/nano_llm/nano_env.sh
```

Now `echo $HF_HOME` should print:

```bash
/data/models/huggingface
```

---

## 4️⃣ Hugging Face Token Setup (Gated Models)

You’re using a **fine-grained HF token** (example):

```bash
export HUGGINGFACE_HUB_TOKEN="hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export HUGGINGFACE_TOKEN="$HUGGINGFACE_HUB_TOKEN"
```

> ⚠ Important for Gemma & Meditron:
> In your Hugging Face token settings, make sure:
>
> * The token is **fine-grained**
> * Has **“Access public gated repos”** permission enabled

This lets the installer access:

* `google/gemma-2-2b-it`
* `google/gemma-2-9b-it`
* `epfl-llm/meditron-7b`

---

## 5️⃣ One-Command Bootstrap Script (Host)

You can keep a **host-side** helper script like `bootstrap_nano_llm.sh`:

```bash
cat > ~/bootstrap_nano_llm.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo ">>> Bootstrap NanoLLM on Jetson Orin Nano Super"

cd ~/jetson-containers

# Launch nano_llm container with /data mount
jetson-containers run $(autotag nano_llm) << 'INNER_CMDS'
set -euo pipefail

# Inside container
mkdir -p /data/nano_llm /data/models/huggingface /data/models/mlc /data/cache

cat > /data/nano_llm/nano_env.sh << 'ENVEOF'
export HF_HOME=/data/models/huggingface
export TRANSFORMERS_CACHE=/data/models/huggingface
export HUGGINGFACE_HUB_CACHE=/data/models/huggingface
export XDG_CACHE_HOME=/data/cache
export MLC_HOME=/data/models/mlc
export NANO_LLM_HOME=/data/nano_llm
ENVEOF

if ! grep -q 'nano_env.sh' ~/.bashrc; then
  echo '[[ -f /data/nano_llm/nano_env.sh ]] && source /data/nano_llm/nano_env.sh' >> ~/.bashrc
fi

source /data/nano_llm/nano_env.sh

echo ">>> NanoLLM base env ready under /data/nano_llm"
INNER_CMDS
EOF

chmod +x ~/bootstrap_nano_llm.sh
```

Then whenever you need to re-establish the environment:

```bash
bash ~/bootstrap_nano_llm.sh
```

---

## 6️⃣ Bulk Model Installer (`LLM_Installer.sh`)

You already have `LLM_Installer.sh` under `/data/nano_llm`. It:

* Groups models into sets:

  * Tiny / Small (1–4B)
  * GPT-OSS (3B / 7B) – if you enabled them
  * Mid-size (Llama-3 8B, Qwen2.5 7B, Mistral-7B)
  * Specialized (DeepSeek-Coder, FinBERT, Meditron)
  * Gemma-2 (2B & 9B)
* Uses `huggingface-cli download` / `snapshot_download` under the hood
* Writes a log to `/data/nano_llm/install.log`

### 6.1 Running the installer

Inside the container:

```bash
cd ~/jetson-containers
jetson-containers run $(autotag nano_llm)

# Inside container:
source /data/nano_llm/nano_env.sh

# Set your token
export HUGGINGFACE_HUB_TOKEN="hf_xxxxxxxxxxxxxxxxxxxxxxxxxxx"
export HUGGINGFACE_TOKEN="$HUGGINGFACE_HUB_TOKEN"

# Run the interactive installer
bash /data/nano_llm/LLM_Installer.sh
```

You’ll see:

```text
Select an install option:
  1) Install Tiny / Small models
  2) Install GPT-OSS models
  3) Install Mid-size models
  4) Install Specialized
  5) Install Gemma-2
  6) Install EVERYTHING
  7) Exit
```

You can:

* Start with `1` for small models
* Use `3` for mid-size general models
* Use `4` for DeepSeek-Coder / FinBERT / Meditron
* Use `5` for Gemma-2 (with token permissions enabled)
* Use `6` to go all-in

All runs append to `/data/nano_llm/install.log`.

---

## 7️⃣ Model Status Dashboard (`check_models.sh`)

You have a status script at `/data/nano_llm/check_models.sh` that summarizes:

* HF models under `/data/models/huggingface`
* MLC artifacts under `/data/models/mlc`
* Disk usage
* Tail of `/data/nano_llm/install.log`

### 7.1 Running it inside the container

```bash
cd ~/jetson-containers
jetson-containers run $(autotag nano_llm)

# Inside container:
source /data/nano_llm/nano_env.sh
bash /data/nano_llm/check_models.sh
```

Example output (similar to what you saw):

```text
>>> [1] Hugging Face models found on disk:
  Root: /data/models/huggingface
   - deepseek-ai/deepseek-coder-6.7b-instruct       (13G)
   - epfl-llm/meditron-7b                           (XXG)
   - google/gemma-2-2b-it                           (XXG)
   - google/gemma-2-9b-it                           (XXG)
   - meta-llama/Llama-3.2-1B-Instruct               (…)
   - meta-llama/Llama-3.2-3B-Instruct               (…)
   - meta-llama/Meta-Llama-3-8B-Instruct            (…)
   - microsoft/Phi-3-mini-4k-instruct               (…)
   - mistralai/Mistral-7B-Instruct-v0.2             (…)
   - ProsusAI/finbert                               (1.3G)
   - Qwen/Qwen2.5-7B-Instruct                       (15G)
   - TinyLlama/TinyLlama-1.1B-Chat-v1.0             (2.1G)

>>> [2] MLC models (quantized builds):
  Root: /data/models/mlc/dist
   - deepseek-coder-6.7b-instruct
   - Mistral-7B-Instruct-v0.2
   - TinyLlama-1.1B-Chat-v1.0
```

---

## 8️⃣ Rebuilding MLC Context (`rebuild_mlc_ctx.sh`)

`rebuild_mlc_ctx.sh` converts selected HF models into **MLC artifacts** under `$MLC_HOME`.

Typical usage inside container:

```bash
source /data/nano_llm/nano_env.sh

bash /data/nano_llm/rebuild_mlc_ctx.sh
```

This script:

* Takes a model list (for example: TinyLlama, Mistral-7B, DeepSeek-Coder)
* Runs the MLC tooling to create quantized runtime artifacts in `/data/models/mlc/dist/<model-name>`
* Lets you use them with very lightweight inference frontends (e.g., `mlc_chat_cli`)

If you later add new HF models and want MLC builds:

1. Add them to the model list inside `rebuild_mlc_ctx.sh`
2. Re-run the script

---

## 9️⃣ Running Models (CLI Examples)

Most workflows follow this pattern inside the container:

```bash
cd ~/jetson-containers
jetson-containers run $(autotag nano_llm)

source /data/nano_llm/nano_env.sh
export HUGGINGFACE_HUB_TOKEN="hf_xxxxx"
export HUGGINGFACE_TOKEN="$HUGGINGFACE_HUB_TOKEN"
```

### 9.1 Example: run Mistral-7B via HF backend

If NanoLLM exposes a Python CLI (example):

```bash
python3 -m nano_llm.chat \
  --model "mistralai/Mistral-7B-Instruct-v0.2" \
  --max-new-tokens 128 \
  --prompt "Explain how to optimize matrix multiplications on GPUs for finance models."
```

### 9.2 Example: run DeepSeek-Coder for code tasks

```bash
python3 -m nano_llm.chat \
  --model "deepseek-ai/deepseek-coder-6.7b-instruct" \
  --max-new-tokens 256 \
  --prompt "Write a Python script that loads SPY data from yfinance and computes a 21-day rolling Sharpe ratio."
```

### 9.3 Example: use FinBERT as a classifier

FinBERT is best used programmatically:

```python
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import torch

model_id = "ProsusAI/finbert"
tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForSequenceClassification.from_pretrained(model_id)

text = "SPY is surging on strong earnings and declining inflation."
inputs = tokenizer(text, return_tensors="pt")
with torch.no_grad():
    logits = model(**inputs).logits
pred = torch.softmax(logits, dim=-1).argmax(dim=-1).item()
labels = ["negative", "neutral", "positive"]
print("Sentiment:", labels[pred])
```

Run that inside the container (with PyTorch already available).

---

## 🔟 GPU Benchmark Script (`benchmark_llm.sh`)

A simple benchmark script can:

* Load a model
* Generate a short response
* Approximate tokens/sec and SM/utilization via `tegrastats`

Example script under `/data/nano_llm/benchmark_llm.sh`:

```bash
cat > /data/nano_llm/benchmark_llm.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

source /data/nano_llm/nano_env.sh

MODEL_ID="${1:-mistralai/Mistral-7B-Instruct-v0.2}"
MAX_NEW_TOKENS="${2:-128}"

echo "==============================================="
echo " Benchmarking model: $MODEL_ID"
echo " Max new tokens:     $MAX_NEW_TOKENS"
echo " Started:            $(date)"
echo "==============================================="

python3 - << PYCODE
import time
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch, os

model_id = os.environ.get("BENCH_MODEL_ID", "${MODEL_ID}")
max_new_tokens = int(os.environ.get("BENCH_MAX_NEW_TOKENS", "${MAX_NEW_TOKENS}"))

print(f"Loading model: {model_id}")
t0 = time.time()
tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(model_id, device_map="auto", torch_dtype=torch.float16)
t1 = time.time()
print(f"Load time: {t1 - t0:.2f} sec")

prompt = "Explain what Gamma Exposure (GEX) means for SPX options and how it affects intraday volatility."
inputs = tokenizer(prompt, return_tensors="pt").to(model.device)

gen_t0 = time.time()
with torch.no_grad():
    output = model.generate(
        **inputs,
        max_new_tokens=max_new_tokens,
        do_sample=False
    )
gen_t1 = time.time()

gen_tokens = output.shape[-1] - inputs["input_ids"].shape[-1]
secs = gen_t1 - gen_t0
tps = gen_tokens / secs if secs > 0 else 0

print(f"Generated tokens: {gen_tokens}")
print(f"Generation time: {secs:.2f} sec")
print(f"Approx tokens/sec: {tps:.2f}")
print("\\n--- Sample output ---\\n")
print(tokenizer.decode(output[0], skip_special_tokens=True))
PYCODE
EOF

chmod +x /data/nano_llm/benchmark_llm.sh
```

Usage inside container:

```bash
bash /data/nano_llm/benchmark_llm.sh mistralai/Mistral-7B-Instruct-v0.2 128
bash /data/nano_llm/benchmark_llm.sh google/gemma-2-9b-it 128
bash /data/nano_llm/benchmark_llm.sh microsoft/Phi-3-mini-4k-instruct 128
```

You can watch `tegrastats` in another terminal to see GPU use.

---

## 1️⃣1️⃣ Flowchart – End-to-End Pipeline

```text
   ┌──────────────────────────────────────────────────────┐
   │       Host (x86_64 Ubuntu Desktop / Laptop)         │
   │  - git clone jetson-containers                      │
   │  - docker + nvidia-container-runtime               │
   └───────────────┬────────────────────────────────────┘
                   │
                   │ jetson-containers run $(autotag nano_llm)
                   ▼
   ┌──────────────────────────────────────────────────────┐
   │      nano_llm Container on Jetson Orin Nano        │
   │  - dustynv/nano_llm:r36.4.0                        │
   │  - CUDA, Torch, Transformers, MLC                  │
   └───────────────┬────────────────────────────────────┘
                   │  /home/…/jetson-containers/data → /data
                   ▼
   ┌──────────────────────────────────────────────────────┐
   │                  /data (NVMe)                       │
   │  /data/nano_llm/nano_env.sh                         │
   │    → sets HF_HOME, MLC_HOME, XDG_CACHE_HOME         │
   │                                                     │
   │  /data/models/huggingface                           │
   │    → HF models (Gemma, Llama, Qwen, Mistral…)       │
   │                                                     │
   │  /data/models/mlc                                   │
   │    → MLC artifacts (TinyLlama, DeepSeek, Mistral…)  │
   │                                                     │
   │  /data/cache                                        │
   │    → generic caches                                 │
   └───────────────┬────────────────────────────────────┘
                   │
                   │ LLM_Installer.sh / rebuild_mlc_ctx.sh
                   ▼
   ┌──────────────────────────────────────────────────────┐
   │             Inference / Benchmarks                  │
   │  - nano_llm.chat (HF backend)                       │
   │  - mlc runtimes (MLC backend)                       │
   │  - benchmark_llm.sh                                 │
   └─────────────────────────────────────────────────────┘
```

---

## 1️⃣2️⃣ Model Catalog – Loadout Guide

You now have a curated set of models installed. Here’s how to think about them.

### 💻 Coding & Automation

**DeepSeek-Coder 6.7B Instruct**

* **HF ID:** `deepseek-ai/deepseek-coder-6.7b-instruct`
* **Best for:** code-heavy tasks:

  * Python / Bash scripting
  * Refactoring
  * Jetson / Orange Pi tooling, trading scripts
* **Why:** specialized for code; excellent for “write me a script to…” prompts.

---

### 📈 Markets, SPY/QQQ/VIX Sentiment

**FinBERT**

* **HF ID:** `ProsusAI/finbert`
* **Best for:**

  * Tagging text as **positive / neutral / negative**
  * Headlines, tweets, transcripts related to SPY/QQQ/VIX
* **Why:** designed for finance; better signal than generic sentiment models.

---

### 🩺 Medical & Vet Research

**Meditron-7B**

* **HF ID:** `epfl-llm/meditron-7b`
* **Best for:**

  * Summarizing medical/vet PDFs
  * Jargon-heavy medical notes, structured lab summaries
* **Why:** tuned on medical content; more precise for that domain.

> 🧷 Always treat output as **informational**, not a substitute for a clinician.

---

### 🧠 General Reasoning & Chat

**Gemma-2 9B IT**

* **HF ID:** `google/gemma-2-9b-it` (gated)
* **Best for:**

  * Deep reasoning and longer answers
  * Mixed tasks: explanations, planning, math, basic code
* **Why:** strong all-rounder; good candidate for default assistant on this Jetson.

**Gemma-2 2B IT**

* **HF ID:** `google/gemma-2-2b-it` (gated)
* **Best for:**

  * Lightweight assistant tasks
  * When you need Gemma style but less resource use.

---

### 🔍 Small / Efficient Assistants

**TinyLlama-1.1B Chat**

* **HF ID:** `TinyLlama/TinyLlama-1.1B-Chat-v1.0`
* **Best for:**

  * Very fast responses
  * Glue logic, short prompts, background helpers
* **Why:** minimal VRAM/RAM footprint.

**Phi-3 Mini 4k Instruct**

* **HF ID:** `microsoft/Phi-3-mini-4k-instruct`
* **Best for:**

  * General assistant tasks where you need better reasoning than a 1B model
* **Why:** punches above its weight in quality.

---

### 🌍 Generalists & Multilingual

**Mistral-7B Instruct v0.2**

* **HF ID:** `mistralai/Mistral-7B-Instruct-v0.2`
* **Best for:**

  * Everyday assistant use, explanations, mixed domains
* **Why:** mature baseline; easy to compare performance.

**Qwen2.5-7B Instruct**

* **HF ID:** `Qwen/Qwen2.5-7B-Instruct`
* **Best for:**

  * Multilingual tasks
  * Alternative style to Mistral/Gemma/Llama.

---

### 🦙 Llama Family (Meta)

**Llama-3.2 1B / 3B Instruct**

* **HF IDs:**

  * `meta-llama/Llama-3.2-1B-Instruct`
  * `meta-llama/Llama-3.2-3B-Instruct`
* **Best for:**

  * Very small yet modern instruction-tuned assistants.

**Meta-Llama-3 8B Instruct**

* **HF ID:** `meta-llama/Meta-Llama-3-8B-Instruct`
* **Best for:**

  * Strong alternative large assistant, good for reasoning and general chat.

---

### 🧾 Loadout Cheat Sheet

* **Coding / automation:** `deepseek-ai/deepseek-coder-6.7b-instruct`
* **Finance sentiment:** `ProsusAI/finbert`
* **Medical/vet context:** `epfl-llm/meditron-7b`
* **Flagship assistant:** `google/gemma-2-9b-it` or `Meta-Llama-3-8B-Instruct`
* **Fast “daily driver” assistant:** `microsoft/Phi-3-mini-4k-instruct`
* **Tiny helper:** `TinyLlama/TinyLlama-1.1B-Chat-v1.0`
* **Multilingual / different flavor:** `Qwen/Qwen2.5-7B-Instruct`

---

## 1️⃣3️⃣ Future-Proofing – Adding New Models Later

This layout is designed so that **adding models later is easy**:

1. **Hugging Face**

   * Models always live under: `/data/models/huggingface/<author>/<model-id>`
   * The installer uses HF IDs, so you just extend the arrays inside `LLM_Installer.sh`.

2. **Update `LLM_Installer.sh`**

   * Inside `/data/nano_llm/LLM_Installer.sh`, you have groups like:

     ```bash
     TINY_MODELS=(
       "TinyLlama/TinyLlama-1.1B-Chat-v1.0"
       "meta-llama/Llama-3.2-1B-Instruct"
       "meta-llama/Llama-3.2-3B-Instruct"
       "microsoft/Phi-3-mini-4k-instruct"
       # add new small models here
     )
     ```

   * Add new HF IDs to the appropriate group (or create a new group).

3. **Update MLC Rebuild Script**

   * If you want MLC builds for a new model, add it to `/data/nano_llm/rebuild_mlc_ctx.sh`.

4. **(Optional) Cassette / Launcher Menu**

   * If you use a menu-driven “cassette” launcher (desktop app or TUI), keep a **small JSON or shell list** of model options to update:

     * “HF backend models”
     * “MLC backend models”
     * “GGUF models (when you add them)”

5. **Version Upgrades**

   * New “industry standard” models (e.g., Mistral-8x, Qwen-3, Llama-4) will generally fit into the same pattern:

     * HF download → `/data/models/huggingface/...`
     * Optional AWQ or GGUF conversion for speed
     * Optional MLC build for low-overhead runtime

You can periodically sweep through:

* **Mature HF models**: new stable releases from Mistral, Meta, Qwen, Gemma lines
* **Domain models**: updated FinBERT variants, new med/vet models, new coding LLMs

Just extend the script arrays; everything else (paths, caches, logs) remains unchanged.

---

## 1️⃣4️⃣ Terminology Cheat Sheet (Plain English)

### 🧩 HF Directory

* **HF directory**: `/data/models/huggingface`
* Hugging Face uses this path to store:

  * Model weights (e.g., `pytorch_model-00001-of-00003.bin` or `.safetensors`)
  * Config files (`config.json`, `generation_config.json`)
  * Tokenizers

Environment vars:

```bash
HF_HOME=/data/models/huggingface
TRANSFORMERS_CACHE=/data/models/huggingface
HUGGINGFACE_HUB_CACHE=/data/models/huggingface
```

### 🧩 MLC Directory

* **MLC directory**: `/data/models/mlc`
* Stores compiled / quantized model artifacts for the **MLC runtime**.
* After `rebuild_mlc_ctx.sh`, you get something like:

  ```text
  /data/models/mlc/dist/TinyLlama-1.1B-Chat-v1.0
  /data/models/mlc/dist/Mistral-7B-Instruct-v0.2
  /data/models/mlc/dist/deepseek-coder-6.7b-instruct
  ```

These are used by lightweight runtimes (C++/CUDA/TVM style).

### 🧩 AWQ

* **AWQ (Activation-aware Weight Quantization)**:

  * A method that shrinks models using **int4 / int8** weights while looking at how activations behave.
  * The point is to keep quality high while cutting memory & compute.
* In practice:

  * You can convert a full-precision model to an **AWQ variant** (like `model.awq.safetensors`) and load it with AWQ-compatible runtimes.

You saw a runtime message:

```text
AWQ not installed (requires JetPack 6 / L4T R36) - AWQ models will fail to initialize
```

That just means AWQ support is optional and can be added later via pip + compiled kernels when you start using AWQ models.

### 🧩 GGUF

* **GGUF**: A modern model format used by llama.cpp-style engines and many desktop tools.
* Features:

  * Pure binary file, easy to deploy
  * Typically stores quantized weights (Q2, Q3, Q4, Q5, Q8, etc.)
* Use cases:

  * CPU + GPU hybrid inference
  * Tools like `llama.cpp`, `text-generation-webui` in GGUF mode, etc.

You can later:

* Convert HF models to GGUF (using tools like `llama.cpp` converters)
* Store them alongside HF/MLC, e.g. `/data/models/gguf/<model-name>`.

### 🧩 Quantization Levels (q2, q3, q4, q5, etc.)

These are shortcuts for **how much you compress the model**:

* **Q2 / Q3**:

  * Very small; lowest memory usage
  * More compression, more quality loss
* **Q4** (e.g., Q4_K_M):

  * Common sweet spot
  * Big memory savings with still good quality
* **Q5 / Q6**:

  * Higher quality, more memory usage
* **Q8 / fp16**:

  * Closer to original; best quality, most memory use

On an **8GB Orin**, Q4-style quantization for 7–9B models is usually where it starts to feel practical.

---

## 1️⃣5️⃣ Common Gotchas & Fixes

* **Gated models (403 errors)**

  * Make sure:

    * You accepted the model license on the HF model page
    * Your token settings allow **“Access public gated repos”**
  * Re-run the installer for that group (Gemma or Meditron).

* **“Permission denied” on `/data` from host**

  * Work with `/data` **inside** the container; on the host, the path is `~/jetson-containers/data`.

* **Installer interrupted (Ctrl+C)**

  * HF caching is incremental:

    * Partially downloaded binaries can usually resume correctly.
  * Just rerun `LLM_Installer.sh` for the same group; it will skip what’s already complete or reuse partial caches.

Nice, let’s lock this in.
Here are **ready-to-paste** versions of the four scripts.

> 📍 Use these **inside the nano_llm container** and save them under `/data/nano_llm/`, then:
>
> ```bash
> chmod +x /data/nano_llm/LLM_Installer.sh \
>          /data/nano_llm/check_models.sh \
>          /data/nano_llm/rebuild_mlc_ctx.sh \
>          /data/nano_llm/benchmark_llm.sh
> ```

---

## 1️⃣ `LLM_Installer.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# NanoLLM Bulk Model Installer
# - Installs Hugging Face models into $HF_HOME (on /data)
# - Logs to /data/nano_llm/install.log
# ============================================================

NANO_LLM_HOME="${NANO_LLM_HOME:-/data/nano_llm}"
LOGFILE="${NANO_LLM_HOME}/install.log"

# Default HF paths if not already set
export HF_HOME="${HF_HOME:-/data/models/huggingface}"
export TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE:-$HF_HOME}"
export HUGGINGFACE_HUB_CACHE="${HUGGINGFACE_HUB_CACHE:-$HF_HOME}"

mkdir -p "$NANO_LLM_HOME" "$HF_HOME"
touch "$LOGFILE"

log() {
  echo "$@" | tee -a "$LOGFILE"
}

download_model() {
  local MODEL_ID="$1"

  log ">>> Installing: ${MODEL_ID}"
  log "Started: $(date)"

  # Using huggingface-cli; it should already be in the container
  if ! command -v huggingface-cli >/dev/null 2>&1; then
    log "ERROR: huggingface-cli not found (pip install huggingface_hub)"
    log "-----------------------------------------------------------"
    return 1
  fi

  # Local dir under HF_HOME, neat layout: HF_HOME/author/model
  local LOCAL_DIR="${HF_HOME}/${MODEL_ID}"

  huggingface-cli download \
    "${MODEL_ID}" \
    --local-dir "${LOCAL_DIR}" \
    --local-dir-use-symlinks False \
    2>&1 | tee -a "$LOGFILE" || {
      log "ERROR: Failed to download ${MODEL_ID}"
      log "-----------------------------------------------------------"
      return 1
    }

  log "${LOCAL_DIR}"
  log "SUCCESS: ${MODEL_ID}"
  log "Finished: $(date)"
  log "-----------------------------------------------------------"
}

# ----------------- Model Groups ---------------------------------

TINY_MODELS=(
  "TinyLlama/TinyLlama-1.1B-Chat-v1.0"
  "meta-llama/Llama-3.2-1B-Instruct"
  "meta-llama/Llama-3.2-3B-Instruct"
  "microsoft/Phi-3-mini-4k-instruct"
)

GPT_OSS_MODELS=(
  # Add GPT-OSS style models here if/when you want them
  # Example:
  # "siro-kr/gpt-oss-9.0b-specialized-all-pruned-moe-only-12-experts-Q4_K_M-GGUF"
)

MID_MODELS=(
  "meta-llama/Meta-Llama-3-8B-Instruct"
  "Qwen/Qwen2.5-7B-Instruct"
  "mistralai/Mistral-7B-Instruct-v0.2"
)

SPECIALIZED_MODELS=(
  "deepseek-ai/deepseek-coder-6.7b-instruct"
  "ProsusAI/finbert"
  "epfl-llm/meditron-7b"
)

GEMMA_MODELS=(
  "google/gemma-2-2b-it"
  "google/gemma-2-9b-it"
)

# ----------------- Main Menu ------------------------------------

log "==============================================================="
log " NanoLLM Installer Run: $(date)"
log "==============================================================="

if [[ -z "${HUGGINGFACE_HUB_TOKEN:-}" && -z "${HUGGINGFACE_TOKEN:-}" ]]; then
  log "WARNING: No Hugging Face token set (export HUGGINGFACE_HUB_TOKEN)"
fi

echo
echo "HuggingFace token $( [[ -n ${HUGGINGFACE_HUB_TOKEN:-} ]] && echo 'detected.' || echo 'not detected.' )"
echo
echo "Select an install option:"
echo "  1) Install Tiny / Small models"
echo "  2) Install GPT-OSS models"
echo "  3) Install Mid-size models"
echo "  4) Install Specialized"
echo "  5) Install Gemma-2"
echo "  6) Install EVERYTHING"
echo "  7) Exit"
echo

read -rp "Choice [1-7]: " CHOICE
echo

case "$CHOICE" in
  1)
    log "-----------------------------------------------------------"
    log " INSTALLING GROUP: TINY_MODELS"
    log "-----------------------------------------------------------"
    for m in "${TINY_MODELS[@]}"; do
      download_model "$m" || true
    done
    ;;
  2)
    log "-----------------------------------------------------------"
    log " INSTALLING GROUP: GPT_OSS_MODELS"
    log "-----------------------------------------------------------"
    for m in "${GPT_OSS_MODELS[@]}"; do
      download_model "$m" || true
    done
    ;;
  3)
    log "-----------------------------------------------------------"
    log " INSTALLING GROUP: MID_MODELS"
    log "-----------------------------------------------------------"
    for m in "${MID_MODELS[@]}"; do
      download_model "$m" || true
    done
    ;;
  4)
    log "-----------------------------------------------------------"
    log " INSTALLING GROUP: SPECIALIZED_MODELS"
    log "-----------------------------------------------------------"
    for m in "${SPECIALIZED_MODELS[@]}"; do
      download_model "$m" || true
    done
    ;;
  5)
    log "-----------------------------------------------------------"
    log " INSTALLING GROUP: GEMMA_MODELS"
    log "-----------------------------------------------------------"
    for m in "${GEMMA_MODELS[@]}"; do
      download_model "$m" || true
    done
    ;;
  6)
    log "-----------------------------------------------------------"
    log " INSTALLING GROUP: ALL"
    log "-----------------------------------------------------------"
    for m in "${TINY_MODELS[@]}" "${GPT_OSS_MODELS[@]}" "${MID_MODELS[@]}" "${SPECIALIZED_MODELS[@]}" "${GEMMA_MODELS[@]}"; do
      download_model "$m" || true
    done
    ;;
  7)
    log "User chose Exit."
    ;;
  *)
    log "Invalid choice: $CHOICE"
    ;;
esac

log "==============================================================="
log " Installer Complete at $(date)"
log " Log saved to: ${LOGFILE}"
log "==============================================================="
```

---

## 2️⃣ `check_models.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# NanoLLM Model Status Dashboard
# - Lists HF models, MLC models, disk usage, and log tail
# ============================================================

NANO_LLM_HOME="${NANO_LLM_HOME:-/data/nano_llm}"
LOGFILE="${NANO_LLM_HOME}/install.log"

HF_DIR="${HF_HOME:-/data/models/huggingface}"
MLC_DIR="${MLC_HOME:-/data/models/mlc}"

echo "======================================================="
echo " NanoLLM Model Status Dashboard"
echo "======================================================="
echo "Date: $(date)"
echo "Log file: ${LOGFILE}"
echo

# ---------------------------------------------------------
# 1) Hugging Face models on disk
# ---------------------------------------------------------
echo ">>> [1] Hugging Face models found on disk:"
echo "  Root: ${HF_DIR}"

if [[ -d "$HF_DIR" ]]; then
  # Look for HF-style layout: HF_HOME/author/model
  mapfile -t HF_MODELS < <(find "$HF_DIR" -mindepth 2 -maxdepth 2 -type d | sort || true)
  if [[ ${#HF_MODELS[@]} -eq 0 ]]; then
    echo "   (no HF models found)"
  else
    for d in "${HF_MODELS[@]}"; do
      # compute size
      SIZE=$(du -sh "$d" 2>/dev/null | awk '{print $1}')
      # convert path to author/model form
      REL="${d#${HF_DIR}/}"
      echo "   - ${REL}$(printf '%*s' $((40 - ${#REL})) ' ')(${SIZE})"
    done
  fi
else
  echo "   (directory not found)"
fi

echo

# ---------------------------------------------------------
# 2) MLC models on disk
# ---------------------------------------------------------
echo ">>> [2] MLC models (quantized builds):"
echo "  Root: ${MLC_DIR}/dist"

if [[ -d "${MLC_DIR}/dist" ]]; then
  mapfile -t MLC_MODELS < <(find "${MLC_DIR}/dist" -mindepth 1 -maxdepth 1 -type d | sort || true)
  if [[ ${#MLC_MODELS[@]} -eq 0 ]]; then
    echo "   (no MLC models found yet)"
  else
    for d in "${MLC_MODELS[@]}"; do
      SIZE=$(du -sh "$d" 2>/dev/null | awk '{print $1}')
      NAME="${d##*/}"
      echo "   - ${NAME}$(printf '%*s' $((35 - ${#NAME})) ' ')(${SIZE})"
    done
  fi
else
  echo "   (no MLC dist directory yet)"
fi

echo

# ---------------------------------------------------------
# 3) NanoLLM runtime local models (if utils available)
# ---------------------------------------------------------
echo ">>> [3] NanoLLM runtime local models (if utils available):"
python3 - << 'PYCODE' 2>/dev/null || echo "  (nano_llm.utils.list_local_models not available)"
try:
    import nano_llm.utils as u
    if hasattr(u, "list_local_models"):
        models = u.list_local_models()
        if not models:
            print("  (no runtime-local models reported)")
        else:
            for m in models:
                print("  -", m)
    else:
        print("  (nano_llm.utils.list_local_models not found)")
except Exception as e:
    print("  Error calling list_local_models():", e)
PYCODE

echo

# ---------------------------------------------------------
# 4) Disk usage
# ---------------------------------------------------------
echo ">>> [4] Disk usage:"
if command -v df >/dev/null 2>&1; then
  echo "  df -h /data:"
  df -h /data || true
  echo
fi

if [[ -d "$HF_DIR" ]]; then
  echo "  HF directory usage (depth 1):"
  du -sh "${HF_DIR}"/* 2>/dev/null || echo "   (no subdirectories)"
  echo
fi

if [[ -d "$MLC_DIR" ]]; then
  echo "  MLC directory usage (depth 2):"
  du -sh "${MLC_DIR}"/* "${MLC_DIR}/dist"/* 2>/dev/null || echo "   (no subdirectories)"
  echo
fi

# ---------------------------------------------------------
# 5) Log tail
# ---------------------------------------------------------
echo ">>> [5] Recent installer log tail:"
if [[ -f "$LOGFILE" ]]; then
  tail -n 40 "$LOGFILE" || true
else
  echo "  (no install log found at ${LOGFILE})"
fi

echo
echo "Done."
```

---

## 3️⃣ `rebuild_mlc_ctx.sh` (template)

> ⚠ This assumes NanoLLM/MLC exposes a builder CLI or Python entry.
> Adjust the `MLC_BUILD_CMD` line to match your actual build call (you already have something here; this script gives you structure + logging).

```bash
#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Rebuild MLC Contexts for Selected Models
# - Converts HF models under $HF_HOME into MLC artifacts
#   under $MLC_HOME/dist/<model-name>
# ============================================================

NANO_LLM_HOME="${NANO_LLM_HOME:-/data/nano_llm}"
LOGFILE="${NANO_LLM_HOME}/mlc_rebuild.log"

export HF_HOME="${HF_HOME:-/data/models/huggingface}"
export MLC_HOME="${MLC_HOME:-/data/models/mlc}"

mkdir -p "$NANO_LLM_HOME" "$MLC_HOME/dist"
touch "$LOGFILE"

log() {
  echo "$@" | tee -a "$LOGFILE"
}

# List of HF models you want MLC builds for
MLC_MODELS=(
  "TinyLlama/TinyLlama-1.1B-Chat-v1.0"
  "mistralai/Mistral-7B-Instruct-v0.2"
  "deepseek-ai/deepseek-coder-6.7b-instruct"
  # Add more here as needed
)

echo "=======================================================" | tee -a "$LOGFILE"
echo " Rebuild MLC Contexts: $(date)" | tee -a "$LOGFILE"
echo " HF_HOME: $HF_HOME" | tee -a "$LOGFILE"
echo " MLC_HOME: $MLC_HOME" | tee -a "$LOGFILE"
echo "=======================================================" | tee -a "$LOGFILE"

# Simple check that MLC is installed
python3 - << 'PYCODE' 2>/dev/null || {
  echo "ERROR: MLC Python package not found. Install / enable it before running this." | tee -a "$LOGFILE"
  exit 1
}
try:
    import mlc_llm  # or whatever your package name is
    print("MLC package detected.")
except Exception as e:
    print("MLC import failed:", e)
    raise
PYCODE

for MODEL_ID in "${MLC_MODELS[@]}"; do
  log "-------------------------------------------------------"
  log "Building MLC artifacts for: ${MODEL_ID}"
  log "Started: $(date)"

  # Suggested normalized name for dist dir
  NAME_SAFE=$(echo "$MODEL_ID" | tr '/' '-' )
  OUT_DIR="${MLC_HOME}/dist/${NAME_SAFE}"
  mkdir -p "$OUT_DIR"

  # TODO: adjust this to your actual MLC build command.
  # Example stub (replace with real command):
  python3 - << PYCODE 2>&1 | tee -a "$LOGFILE"
import os, sys, time

model_id = "${MODEL_ID}"
out_dir = "${OUT_DIR}"

print(f"[MLC] (stub) Build requested for {model_id}")
print(f"[MLC] Output directory: {out_dir}")
# Replace this with the real mlc_llm build call for your environment
# e.g.:
# from mlc_llm import build_model
# build_model(model_id, out_dir=out_dir, quantization="q4f16_1")

time.sleep(1)
print(f"[MLC] (stub) Done for {model_id}")
PYCODE

  log "Finished: $(date)"
done

log "======================================================="
log " MLC rebuild complete at $(date)"
log " Log saved to: ${LOGFILE}"
log "======================================================="
```

> Once you know the exact MLC call (your previous script already worked), just swap the stub with your real builder.

---

## 4️⃣ `benchmark_llm.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Simple GPU Benchmark for HF Models
# - Loads a model from HF_HOME
# - Generates text and prints tokens/sec
# ============================================================

source /data/nano_llm/nano_env.sh 2>/dev/null || true

MODEL_ID="${1:-mistralai/Mistral-7B-Instruct-v0.2}"
MAX_NEW_TOKENS="${2:-128}"

echo "==============================================="
echo " Benchmarking model: $MODEL_ID"
echo " Max new tokens:     $MAX_NEW_TOKENS"
echo " Started:            $(date)"
echo "==============================================="

python3 - << PYCODE
import time
import os

from transformers import AutoTokenizer, AutoModelForCausalLM
import torch

model_id = os.environ.get("BENCH_MODEL_ID", "${MODEL_ID}")
max_new_tokens = int(os.environ.get("BENCH_MAX_NEW_TOKENS", "${MAX_NEW_TOKENS}"))

print(f"Loading model: {model_id}")
t0 = time.time()
tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    device_map="auto",
    torch_dtype=torch.float16
)
t1 = time.time()
print(f"Load time: {t1 - t0:.2f} sec")

prompt = "Explain what Gamma Exposure (GEX) is and how it affects SPX intraday volatility."
inputs = tokenizer(prompt, return_tensors="pt").to(model.device)

gen_t0 = time.time()
with torch.no_grad():
    output = model.generate(
        **inputs,
        max_new_tokens=max_new_tokens,
        do_sample=False
    )
gen_t1 = time.time()

gen_tokens = output.shape[-1] - inputs["input_ids"].shape[-1]
secs = gen_t1 - gen_t0
tps = gen_tokens / secs if secs > 0 else 0

print(f"Generated tokens: {gen_tokens}")
print(f"Generation time: {secs:.2f} sec")
print(f"Approx tokens/sec: {tps:.2f}")

print("\\n--- Sample output ---\\n")
print(tokenizer.decode(output[0], skip_special_tokens=True))
PYCODE
```


