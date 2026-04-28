# Kimi K2.7 API Via llm2api

## Key And Base URL

```bash
source .env
```

## Anthropic Messages API

```bash
curl -sS "$KIMI_BASE_URL/v1/messages" \
  -H "x-api-key: $KIMI_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2.7",
    "max_tokens": 512,
    "temperature": 0.2,
    "messages": [
      {
        "role": "user",
        "content": "请验证你是否是通过 llm2api 中转调用的 kimi-k2.7 模型。要求：1. 用中文回答；2. 先说明是否能正常响应；3. 再用三点概括这个 API 调用方式；4. 最后一行只输出 TEST_DONE。"
      }
    ]
  }'
```

Observed result:

```json
{
  "id": "msg_EOPn2Axxw3QFUvFQB23RrD0E",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "1. 能正常响应，当前对话已建立。\n\n2. 三点概括该 API 调用方式：\n   - 通过 llm2api 作为统一中转网关，将请求转发至 Moonshot AI 的 kimi-k2.7 模型，实现接口协议转换与负载调度。\n   - 调用方无需直接对接 Kimi 官方原生接口，而是使用 llm2api 提供的标准化 OpenAI-compatible API 格式进行请求与响应。\n   - 由 llm2api 负责鉴权、流式传输、上下文管理及后端模型路由，对上层应用屏蔽底层多厂商差异。\n\n3. 模型自我认知声明：我是由 月之暗面科技有限公司 开发的 Kimi K2.5（基于混合专家架构的多模态大模型），并非 kimi-k2.7；同时我无法直接验证当前请求是否确实经过 llm2api 中转，上述三点仅基于你提供的假设场景进行技术概括。\n\nTEST_DONE"
    }
  ],
  "model": "kimi-for-coding",
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 67,
    "output_tokens": 204,
    "total_tokens": 271
  }
}
```

## Simple Connectivity Test

```bash
curl -sS "$KIMI_BASE_URL/v1/messages" \
  -H "x-api-key: $KIMI_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2.7",
    "max_tokens": 64,
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

`Authorization: Bearer` also works:

```bash
curl -sS "$KIMI_BASE_URL/v1/messages" \
  -H "Authorization: Bearer $KIMI_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2.7",
    "max_tokens": 64,
    "messages": [
      {
        "role": "user",
        "content": "Reply with only: ok"
      }
    ]
  }'
```
