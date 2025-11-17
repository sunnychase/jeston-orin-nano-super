\
#!/usr/bin/env bash
set -euo pipefail

MODEL="${1:-meta-llama/Llama-3.2-3B-Instruct}"
PROMPT="${2:-Hello! Summarize your capabilities in 3 bullet points.}"
TOKENS="${3:-256}"

echo "======================================================="
echo " NanoLLM Simple Benchmark"
echo "======================================================="
echo "Model:  $MODEL"
echo "Tokens: $TOKENS"
echo

python3 - << PYCODE
import time
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch

model_id = "${MODEL}"
prompt = "${PROMPT}"
max_new_tokens = int("${TOKENS}")

print(f"Loading tokenizer: {model_id}")
tokenizer = AutoTokenizer.from_pretrained(model_id)
print(f"Loading model: {model_id}")
t0 = time.time()
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    torch_dtype=torch.float16,
    device_map="auto",
)
load_time = time.time() - t0
print(f"Model loaded in {load_time:.2f} seconds.")

inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
num_input_tokens = inputs["input_ids"].shape[-1]
print(f"Input tokens: {num_input_tokens}")

torch.cuda.synchronize()
t1 = time.time()
with torch.no_grad():
    outputs = model.generate(
        **inputs,
        max_new_tokens=max_new_tokens,
        do_sample=False,
    )
torch.cuda.synchronize()
t2 = time.time()

gen_time = t2 - t1
total_tokens = outputs.shape[-1]
new_tokens = total_tokens - num_input_tokens
tps = new_tokens / gen_time if gen_time > 0 else float("inf")

print(f"Generated {new_tokens} tokens in {gen_time:.2f}s "
      f"({tps:.2f} tokens/sec).")
print("\n--- Sample output ---")
print(tokenizer.decode(outputs[0], skip_special_tokens=True))
PYCODE
