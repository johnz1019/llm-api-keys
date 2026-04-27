# Kimi Coding API

## Key And Base URL

```bash
source .env
```

## Anthropic Messages API: kimi-k2.7

```bash
curl -sS "$KIMI_BASE_URL/v1/messages" \
  -H "x-api-key: $KIMI_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2.7",
    "max_tokens": 16,
    "messages": [
      {
        "role": "user",
        "content": "Reply with only: ok"
      }
    ]
  }'
```

Observed result:

```text
HTTP 200
content: ok
model: kimi-for-coding
```

## Anthropic Messages API: kimi-k2.6

```bash
curl -sS "$KIMI_BASE_URL/v1/messages" \
  -H "x-api-key: $KIMI_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2.6",
    "max_tokens": 16,
    "messages": [
      {
        "role": "user",
        "content": "Reply with only: ok"
      }
    ]
  }'
```

Observed result:

```text
HTTP 200
content: ok
model: kimi-for-coding
```

## Anthropic Messages API With Authorization Bearer

```bash
curl -sS "$KIMI_BASE_URL/v1/messages" \
  -H "Authorization: Bearer $KIMI_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2.7",
    "max_tokens": 16,
    "messages": [
      {
        "role": "user",
        "content": "Reply with only: ok"
      }
    ]
  }'
```
