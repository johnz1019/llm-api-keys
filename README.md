# LLM API Curl Examples

Verified curl examples for several LLM provider APIs.

## Files

- `kimi-coding-api.md`: Kimi Coding Anthropic Messages API examples.
- `qwen36-27b-api.md`: Qwen3.6-27B OpenAI-compatible API examples.
- `gemini-25-flash-api.md`: Gemini 2.5 Flash Generate Content example.
- `deepseek-v4-api.md`: DeepSeek V4 OpenAI-compatible API examples.
- `glm-51-api.md`: GLM-5.1 OpenAI-compatible API example.
- `bitdeer-api.md`: Bitdeer OpenAI-compatible API example and rate-limit headers.
- `.env.example`: Environment variable template.

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
