# Llama 3.1 vLLM on Vast.ai

One-click setup for a Llama 3.1 OpenAI-compatible API on Vast.ai.

## Default Configuration

- Host: `Vast002`
- GPU target: single RTX 5090 32GB
- Default model: `NousResearch/Meta-Llama-3.1-8B-Instruct`
- Served model name: `llama-3.1`
- Backend port: `18000`
- Vast/Caddy public port: `8000`
- Context length: `32768`
- GPU memory utilization: `0.90`

The default uses a public NousResearch mirror so the script works without Meta gating. To use the official Meta repository, pass `LLAMA_MODEL=meta-llama/Llama-3.1-8B-Instruct` and an `HF_TOKEN` that has been approved for Llama 3.1 access.

## Deploy

```bash
./vast/llama-3.1/setup-vllm.sh Vast002
```

Optional overrides:

```bash
LLAMA_MODEL=meta-llama/Llama-3.1-70B-Instruct \
SERVED_MODEL_NAME=llama-3.1-70b \
MAX_MODEL_LEN=8192 \
CPU_OFFLOAD_GB=24 \
HF_TOKEN=<huggingface-token> ./vast/llama-3.1/setup-vllm.sh Vast002
```

For a single 32GB GPU, the default 8B model is the stable baseline. Larger 70B variants require quantization and/or CPU offload and will be much slower.

## Verify

```bash
ssh Vast002 'curl -fsS http://127.0.0.1:18000/v1/models'
```

Useful operations:

```bash
ssh Vast002 'supervisorctl status vllm'
ssh Vast002 'tail -f /workspace/llama-3.1-vllm/vllm.log'
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
    "model": "llama-3.1",
    "messages": [{"role": "user", "content": "Reply with OK only."}],
    "max_tokens": 16,
    "temperature": 0
  }'
```
