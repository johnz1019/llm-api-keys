# LLM API Curl Examples

Verified curl examples for several LLM provider APIs.

## Files

- `kimi-coding-api.md`: Kimi Coding Anthropic Messages API examples.
- `qwen36-27b-api.md`: Qwen3.6-27B OpenAI-compatible API examples.
- `gemini-25-flash-api.md`: Gemini 2.5 Flash Generate Content example.
- `deepseek-v4-api.md`: DeepSeek V4 OpenAI-compatible API examples.
- `.env.example`: Environment variable template.

## Setup

```bash
cp .env.example .env
```

Then fill in real API keys in `.env`.

## Safety

`.env` is ignored by git and should not be committed. The Markdown docs use environment variables instead of hard-coded secrets.

