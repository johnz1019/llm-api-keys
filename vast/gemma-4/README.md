# Gemma 4 vLLM on Vast.ai

One-click setup for a Gemma 4 OpenAI-compatible API on Vast.ai.

## Default Configuration

- Host: `Vast002`
- GPU target: single RTX 5090 32GB
- Default model: `ebircak/gemma-4-31B-it-4bit-W4A16-AWQ`
- Served model name: `gemma-4-31b`
- Backend port: `18000`
- Vast/Caddy public port: `8000`
- Context length: `32768`
- Max batched tokens: `8192`
- Quantization: `compressed-tensors`
- KV cache dtype: `fp8_e4m3`

The official BF16 `google/gemma-4-31B-it` should be deployed on 80GB-class GPUs. This setup uses a vLLM-compatible 4-bit AWQ checkpoint so the 31B instruction model can run on a single 32GB RTX 5090.

## Deploy

```bash
./vast/gemma-4/setup-vllm.sh Vast002
```

Optional overrides:

```bash
GEMMA_MODEL=google/gemma-4-E2B-it \
SERVED_MODEL_NAME=gemma-4-e2b \
QUANTIZATION=none \
KV_CACHE_DTYPE=auto \
MAX_MODEL_LEN=32768 \
./vast/gemma-4/setup-vllm.sh Vast002
```

If the selected model requires Hugging Face authentication, pass a token:

```bash
HF_TOKEN=<huggingface-token> ./vast/gemma-4/setup-vllm.sh Vast002
```

## Verify

```bash
ssh Vast002 'curl -fsS http://127.0.0.1:18000/v1/models'
```

Useful operations:

```bash
ssh Vast002 'supervisorctl status vllm'
ssh Vast002 'tail -f /workspace/gemma-4-vllm/vllm.log'
ssh Vast002 'nvidia-smi'
```

From your local machine, use the Vast/Caddy public port or an SSH tunnel:

```bash
ssh -L 8000:127.0.0.1:18000 Vast002
```

Then:

```bash
curl -fsS http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gemma-4-31b",
    "messages": [{"role": "user", "content": "Reply with OK only."}],
    "max_tokens": 16,
    "temperature": 0
  }'
```
