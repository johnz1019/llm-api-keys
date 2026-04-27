# DeepSeek V4 API

## Key And Base URL

```bash
source .env
```

## List Models

```bash
curl -sS "$DEEPSEEK_BASE_URL/models" \
  -H "Authorization: Bearer $DEEPSEEK_API_KEY"
```

Observed models:

```text
deepseek-v4-flash
deepseek-v4-pro
```

## Chat Completions: deepseek-v4-flash

```bash
curl -sS "$DEEPSEEK_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-v4-flash",
    "messages": [
      {
        "role": "user",
        "content": "Reply with only: ok"
      }
    ],
    "temperature": 0,
    "max_tokens": 128
  }'
```

Observed result:

```text
HTTP 200
content: ok
model: deepseek-v4-flash
```

## Chat Completions: deepseek-v4-pro

```bash
curl -sS "$DEEPSEEK_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-v4-pro",
    "messages": [
      {
        "role": "user",
        "content": "Reply with only: ok"
      }
    ],
    "temperature": 0,
    "max_tokens": 128
  }'
```

Observed result:

```text
HTTP 200
content: ok
model: deepseek-v4-pro
```
