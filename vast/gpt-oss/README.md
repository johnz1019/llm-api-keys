# GPT-OSS vLLM on Vast.ai

One-click setup for an OpenAI GPT-OSS OpenAI-compatible API on Vast.ai.

## Default Configuration

- Host: `Vast002`
- GPU target: single RTX 5090 32GB
- Default model: `openai/gpt-oss-20b`
- Served model name: `gpt-oss`
- Backend port: `18000`
- Vast/Caddy public port: `8000`
- Context length: `32768`
- GPU memory utilization: `0.90`

The default uses `openai/gpt-oss-20b` because it is the GPT-OSS model suited for a single consumer GPU. `openai/gpt-oss-120b` needs substantially larger GPU memory or a multi-GPU/tensor-parallel setup.

## Deploy

```bash
./vast/gpt-oss/setup-vllm.sh Vast002
```

Optional overrides:

```bash
GPT_OSS_MODEL=openai/gpt-oss-120b \
SERVED_MODEL_NAME=gpt-oss-120b \
MAX_MODEL_LEN=8192 \
TENSOR_PARALLEL_SIZE=2 \
./vast/gpt-oss/setup-vllm.sh Vast002
```

## Verify

```bash
ssh Vast002 'curl -fsS http://127.0.0.1:18000/v1/models'
```

Useful operations:

```bash
ssh Vast002 'supervisorctl status vllm'
ssh Vast002 'tail -f /workspace/gpt-oss-vllm/vllm.log'
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
    "model": "gpt-oss",
    "messages": [{"role": "user", "content": "Reply with OK only."}],
    "max_tokens": 128,
    "temperature": 0
  }'
```

GPT-OSS may emit reasoning tokens before final content, so very small `max_tokens` values can stop before the final answer.
