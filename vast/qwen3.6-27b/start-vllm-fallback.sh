#!/usr/bin/env bash
set -euo pipefail

mkdir -p /workspace/qwen36-vllm /workspace/models
cd /workspace

export HF_HOME=/workspace/.hf_home
export FLASHINFER_DISABLE_VERSION_CHECK=1

exec /venv/main/bin/vllm serve Qwen/Qwen3.6-27B \
  --attention-backend flash_attn \
  --max-model-len 8192 \
  --max-num-batched-tokens 8192 \
  --gpu-memory-utilization 0.90 \
  --cpu-offload-gb 32 \
  --download-dir /workspace/models \
  --host 0.0.0.0 \
  --port 8000
