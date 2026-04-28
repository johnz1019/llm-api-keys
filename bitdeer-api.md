# Bitdeer API

## Key And Base URL

```bash
source .env
```

## Chat Completions

```bash
curl -sS -D - --location "$BITDEER_BASE_URL/chat/completions" \
  --header "Authorization: Bearer $BITDEER_API_KEY" \
  --header "Content-Type: application/json" \
  --data '{
    "model": "google/gemma-4-31B-it",
    "messages": [
      {
        "role": "system",
        "content": "You are a knowledgeable assistant. Provide concise and clear explanations to scientific questions."
      },
      {
        "role": "user",
        "content": "Can you explain the theory of evolution in simple terms?"
      }
    ],
    "max_tokens": 200,
    "top_p": 1.0,
    "temperature": 1.0,
    "frequency_penalty": 0.0,
    "presence_penalty": 0.0,
    "seed": 0,
    "stream": false
  }'
```

Observed result:

```text
HTTP 200
model: google/gemma-4-31B-it
finish_reason: length
prompt_tokens: 44
completion_tokens: 200
total_tokens: 244
```

Observed rate-limit headers:

```text
x-ratelimit-limit: 100
x-ratelimit-remaining: 99
x-ratelimit-reset: 1777369440
```

`finish_reason: length` means `max_tokens: 200` truncated the response. Increase `max_tokens` for complete answers.

## Backup Models

Use the same request body and replace the `model` field with one of these model IDs:

```text
MiniMaxAI/MiniMax-M2.5
google/gemma-4-31B-it
openai/gpt-oss-20b
meta-llama/Llama-3.2-11B-Vision-Instruct
moonshotai/Kimi-K2.6
```

Example:

```bash
curl -sS -D - --location "$BITDEER_BASE_URL/chat/completions" \
  --header "Authorization: Bearer $BITDEER_API_KEY" \
  --header "Content-Type: application/json" \
  --data '{
    "model": "MiniMaxAI/MiniMax-M2.5",
    "messages": [
      {
        "role": "user",
        "content": "Reply with only: ok"
      }
    ],
    "max_tokens": 128,
    "top_p": 1.0,
    "temperature": 0.0,
    "frequency_penalty": 0.0,
    "presence_penalty": 0.0,
    "seed": 0,
    "stream": false
  }'
```

## Response Example

```json
{
  "id": "de2ed772ccc749e08f857fc5e18ce770",
  "object": "chat.completion",
  "created": 1777369385,
  "model": "google/gemma-4-31B-it",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "The theory of evolution is the scientific explanation for how living things change over very long periods of time to better survive in their environments."
      },
      "finish_reason": "length",
      "logprobs": null
    }
  ],
  "usage": {
    "prompt_tokens": 44,
    "completion_tokens": 200,
    "total_tokens": 244,
    "prompt_tokens_details": {
      "cached_tokens": 24
    }
  }
}
```
