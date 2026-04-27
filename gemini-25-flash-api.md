# Gemini 2.5 Flash API

## Key And Endpoint

```bash
source .env
```

## Generate Content

```bash
curl -sS "$GEMINI_MODEL_URL" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [
      {
        "parts": [
          {
            "text": "Reply with only: ok"
          }
        ]
      }
    ],
    "generationConfig": {
      "temperature": 0,
      "maxOutputTokens": 32
    }
  }'
```

Observed result:

```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "ok"
          }
        ],
        "role": "model"
      },
      "finishReason": "STOP",
      "index": 0
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 5,
    "candidatesTokenCount": 1,
    "totalTokenCount": 29,
    "promptTokensDetails": [
      {
        "modality": "TEXT",
        "tokenCount": 5
      }
    ],
    "thoughtsTokenCount": 23
  },
  "modelVersion": "gemini-2.5-flash",
  "responseId": "s1fvad6sI7y0juMPn-vj6Q0"
}
```
