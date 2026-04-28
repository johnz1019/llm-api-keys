# LLM API Curl Examples

Verified curl examples for several LLM provider APIs.

## Files

- `kimi-coding-api.md`: Kimi Coding Anthropic Messages API examples.
- `qwen36-27b-api.md`: Qwen3.6-27B OpenAI-compatible API examples.
- `gemini-25-flash-api.md`: Gemini 2.5 Flash Generate Content example.
- `deepseek-v4-api.md`: DeepSeek V4 OpenAI-compatible API examples.
- `glm-51-api.md`: GLM-5.1 OpenAI-compatible API example.
- `.env.example`: Environment variable template.
- `scripts/test_llm_endpoints.py`: Smoke test for the self-hosted llm2api relay targets: Kimi K2.7, Qwen3.6-27B, Gemma 4, Llama 3.1, and GPT-OSS.

## Test API Endpoints

```bash
cp .env.example .env
# Fill in LLM2API_API_KEY or the model-specific API key variables.
python3 scripts/test_llm_endpoints.py
```

Run one target only:

```bash
python3 scripts/test_llm_endpoints.py --target qwen3.6-27b
```

The script prints a compact pass/fail table and never prints API key values.

## Vast.ai Deployment Scripts

- `vast/qwen3.6-27b/`: Qwen3.6-27B vLLM + DFlash setup scripts and runbook.
- `vast/gemma-4/`: Gemma 4 vLLM setup script and runbook.
- `vast/llama-3.1/`: Llama 3.1 vLLM setup script and runbook.
- `vast/gpt-oss/`: GPT-OSS vLLM setup script and runbook.

Run model setup scripts with a Hugging Face token in the environment:

```bash
HF_TOKEN=<huggingface-token> ./vast/qwen3.6-27b/setup-vllm-dflash.sh Vast001
```

## Setup

```bash
cp .env.example .env
```

Then fill in real API keys in `.env`.

## Safety

`.env` is ignored by git and should not be committed. The Markdown docs use environment variables instead of hard-coded secrets.
