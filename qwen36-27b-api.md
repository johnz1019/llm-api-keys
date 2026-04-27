# Qwen3.6-27B API

## Key And Base URL

```bash
source .env
```

## List Models

```bash
curl -sS "$QWEN_BASE_URL/models" \
  -H "Authorization: Bearer $QWEN_API_KEY"
```

Successful model ID:

```text
Qwen/Qwen3.6-27B
```

## Chat Completions

```bash
curl -sS "$QWEN_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $QWEN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3.6-27B",
    "messages": [
      {
        "role": "user",
        "content": "Reply with only: ok"
      }
    ],
    "temperature": 0,
    "max_tokens": 16
  }'
```

Observed result:

```text
HTTP 200
content: ok
model: Qwen/Qwen3.6-27B
```

## Chat Completions With Larger max_tokens

```bash
curl -sS "$QWEN_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $QWEN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3.6-27B",
    "messages": [
      {
        "role": "user",
        "content": "请用中文写一段约80字的自我介绍，最后一行只写 DONE"
      }
    ],
    "temperature": 0.2,
    "max_tokens": 512
  }'
```

Observed result:

```text
HTTP 200
finish_reason: stop
```

## Streaming Chat Completions

```bash
curl -N -sS "$QWEN_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $QWEN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3.6-27B",
    "messages": [
      {
        "role": "user",
        "content": "请用中文写三句话介绍你自己。"
      }
    ],
    "temperature": 0.2,
    "max_tokens": 512,
    "stream": true
  }'
```

Observed result:

```text
data: {"object":"chat.completion.chunk", ...}
data: [DONE]
```
