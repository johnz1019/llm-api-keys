# GLM-5.1 API

## Key And Base URL

```bash
source .env
```

## List Models

```bash
curl -sS "$GLM_BASE_URL/models" \
  -H "Authorization: Bearer $GLM_API_KEY"
```

Observed model:

```text
glm-5.1
```

## Chat Completions: Reasoning Disabled

```bash
curl -sS "$GLM_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $GLM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-5.1",
    "messages": [
      {
        "role": "user",
        "content": "Reply with only: ok"
      }
    ],
    "temperature": 0,
    "max_tokens": 64,
    "thinking": {
      "type": "disabled"
    }
  }'
```

Observed result:

```json
{
  "choices": [
    {
      "finish_reason": "stop",
      "index": 0,
      "message": {
        "content": "ok",
        "role": "assistant"
      }
    }
  ],
  "model": "glm-5.1",
  "object": "chat.completion",
  "usage": {
    "completion_tokens": 2,
    "completion_tokens_details": {
      "reasoning_tokens": 0
    },
    "prompt_tokens": 10,
    "total_tokens": 12
  }
}
```

