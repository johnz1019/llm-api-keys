# Qwen3.6-27B vLLM + DFlash on Vast001

This runbook captures the final working setup from Vast001 so the server can be rebuilt after reset.

## One-Click Setup

Run from this repository on your local machine:

```bash
HF_TOKEN=<huggingface-token> ./vast/qwen3.6-27b/setup-vllm-dflash.sh Vast001
```

The script installs the vLLM DFlash PR build on the remote Vast host, writes a restartable supervisor entry, and starts the OpenAI-compatible API on port `18000`.

## Final Working Configuration

- Host: `Vast001`
- GPU tested: RTX 5090 32GB
- API backend port: `18000`
- Vast/Caddy public port `8000` proxies to `localhost:18000` on this machine.
- Served model name: `Qwen/Qwen3.6-27B`
- Target model weights: `cyankiwi/Qwen3.6-27B-AWQ-INT4`
- DFlash drafter: `z-lab/Qwen3.6-27B-DFlash`
- vLLM install: PR `refs/pull/40898/head`
- Context length: `16384`
- CPU offload: `4GB`
- Thinking disabled for both `/v1/chat/completions` and `/v1/responses`

The original BF16 `Qwen/Qwen3.6-27B` plus `z-lab/Qwen3.6-27B-DFlash` does not fit on a 32GB 5090. It OOMs during model init. The AWQ INT4 target model is required for this single-GPU setup.

## Prerequisites

SSH into Vast001:

```bash
ssh Vast001
```

Confirm HF auth. The DFlash repo is gated/auto-gated and must be accessible:

```bash
huggingface-cli whoami
python3 - <<'PY'
from huggingface_hub import model_info
for repo in ["cyankiwi/Qwen3.6-27B-AWQ-INT4", "z-lab/Qwen3.6-27B-DFlash"]:
    info = model_info(repo)
    print(repo, "gated=", info.gated, "files=", len(info.siblings))
PY
```

If not logged in:

```bash
huggingface-cli login
```

## Install vLLM PR Build

```bash
mkdir -p /root/vllm-dflash
cd /root/vllm-dflash

uv venv .venv --python 3.12
. .venv/bin/activate

uv pip install vllm
VLLM_USE_PRECOMPILED=1 uv pip install -U --torch-backend=auto \
  "vllm @ git+https://github.com/vllm-project/vllm.git@refs/pull/40898/head"
```

Verify DFlash modules exist:

```bash
python - <<'PY'
import importlib.util, vllm, torch
print("vllm", getattr(vllm, "__version__", "unknown"))
print("torch", torch.__version__, "cuda", torch.version.cuda)
for mod in [
    "vllm.model_executor.models.qwen3_dflash",
    "vllm.v1.spec_decode.dflash",
]:
    print(mod, importlib.util.find_spec(mod) is not None)
PY
```

Expected:

```text
vllm.model_executor.models.qwen3_dflash True
vllm.v1.spec_decode.dflash True
```

## Patch vLLM Responses API Thinking Flag

In this PR build, `--default-chat-template-kwargs '{"enable_thinking": false}'` is honored by `/v1/chat/completions`, but `/v1/responses` drops it in the Responses routing path. Apply this patch so Responses also passes the default chat template kwargs into rendering.

Back up files:

```bash
cp /root/vllm-dflash/.venv/lib/python3.12/site-packages/vllm/entrypoints/openai/responses/serving.py \
  /root/vllm-dflash/.venv/lib/python3.12/site-packages/vllm/entrypoints/openai/responses/serving.py.bak-enable-thinking-fix

cp /root/vllm-dflash/.venv/lib/python3.12/site-packages/vllm/entrypoints/openai/generate/api_router.py \
  /root/vllm-dflash/.venv/lib/python3.12/site-packages/vllm/entrypoints/openai/generate/api_router.py.bak-enable-thinking-fix
```

Patch with Python:

```bash
python - <<'PY'
from pathlib import Path

serving = Path("/root/vllm-dflash/.venv/lib/python3.12/site-packages/vllm/entrypoints/openai/responses/serving.py")
text = serving.read_text()

text = text.replace(
    '        tool_server: ToolServer | None = None,\n'
    '        enable_prompt_tokens_details: bool = False,\n',
    '        tool_server: ToolServer | None = None,\n'
    '        default_chat_template_kwargs: dict[str, Any] | None = None,\n'
    '        enable_prompt_tokens_details: bool = False,\n',
)

text = text.replace(
    '        self.chat_template = chat_template\n'
    '        self.chat_template_content_format: Final = chat_template_content_format\n'
    '        self.enable_log_outputs = enable_log_outputs\n',
    '        self.chat_template = chat_template\n'
    '        self.chat_template_content_format: Final = chat_template_content_format\n'
    '        self.default_chat_template_kwargs = default_chat_template_kwargs or {}\n'
    '        self.enable_log_outputs = enable_log_outputs\n',
)

text = text.replace(
    '        return request.build_chat_params(\n'
    '            self.chat_template,\n'
    '            self.chat_template_content_format,\n'
    '        ).chat_template_kwargs\n',
    '        return self.default_chat_template_kwargs | request.build_chat_params(\n'
    '            self.chat_template,\n'
    '            self.chat_template_content_format,\n'
    '        ).chat_template_kwargs\n',
)

text = text.replace(
    '            default_template_kwargs=None,\n'
    '            tool_dicts=tool_dicts,\n',
    '            default_template_kwargs=self.default_chat_template_kwargs,\n'
    '            tool_dicts=tool_dicts,\n',
    1,
)

text = text.replace(
    '            default_template_kwargs=None,\n'
    '            tool_dicts=tool_dicts,\n',
    '            default_template_kwargs=self.default_chat_template_kwargs,\n'
    '            tool_dicts=tool_dicts,\n',
    1,
)

serving.write_text(text)

router = Path("/root/vllm-dflash/.venv/lib/python3.12/site-packages/vllm/entrypoints/openai/generate/api_router.py")
text = router.read_text()
text = text.replace(
    '            reasoning_parser=args.structured_outputs_config.reasoning_parser,\n'
    '            enable_prompt_tokens_details=args.enable_prompt_tokens_details,\n',
    '            reasoning_parser=args.structured_outputs_config.reasoning_parser,\n'
    '            default_chat_template_kwargs=args.default_chat_template_kwargs,\n'
    '            enable_prompt_tokens_details=args.enable_prompt_tokens_details,\n',
)
router.write_text(text)
PY

python -m py_compile \
  /root/vllm-dflash/.venv/lib/python3.12/site-packages/vllm/entrypoints/openai/responses/serving.py \
  /root/vllm-dflash/.venv/lib/python3.12/site-packages/vllm/entrypoints/openai/generate/api_router.py
```

## Start Service

```bash
cd /root/vllm-dflash
. .venv/bin/activate

if [ -f /root/vllm-dflash/vllm.pid ]; then
  pid=$(cat /root/vllm-dflash/vllm.pid)
  kill "$pid" 2>/dev/null || true
  sleep 5
  kill -9 "$pid" 2>/dev/null || true
fi

ps -eo pid=,comm= | awk '$2 == "VLLM::EngineCore" {print $1}' | xargs -r kill 2>/dev/null || true
sleep 2
ps -eo pid=,comm= | awk '$2 == "VLLM::EngineCore" {print $1}' | xargs -r kill -9 2>/dev/null || true

rm -f /root/vllm-dflash/vllm-awq-notthinking.log /root/vllm-dflash/vllm.pid

PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True nohup vllm serve cyankiwi/Qwen3.6-27B-AWQ-INT4 \
  --served-model-name Qwen/Qwen3.6-27B \
  --host 0.0.0.0 \
  --port 18000 \
  --speculative-config '{"method": "dflash", "model": "z-lab/Qwen3.6-27B-DFlash", "num_speculative_tokens": 15}' \
  --attention-backend flash_attn \
  --max-num-batched-tokens 16384 \
  --max-model-len 16384 \
  --max-num-seqs 8 \
  --cpu-offload-gb 4 \
  --enforce-eager \
  --default-chat-template-kwargs '{"enable_thinking": false}' \
  > /root/vllm-dflash/vllm-awq-notthinking.log 2>&1 &

echo $! > /root/vllm-dflash/vllm.pid
```

Startup takes a few minutes. Watch logs:

```bash
tail -f /root/vllm-dflash/vllm-awq-notthinking.log
```

Ready indicators:

```text
Starting vLLM server on http://0.0.0.0:18000
Route: /v1/chat/completions, Methods: POST
Route: /v1/responses, Methods: POST
Application startup complete.
```

## Verify

```bash
curl -fsS http://127.0.0.1:18000/v1/models
curl -fsS http://127.0.0.1:18000/health
```

Verify both Chat Completions and Responses do not emit thinking:

```bash
cd /root/vllm-dflash
. .venv/bin/activate

python - <<'PY'
from openai import OpenAI

client = OpenAI(base_url="http://127.0.0.1:18000/v1", api_key="EMPTY", timeout=180)
prompt = "Answer only with: OK."

chat = client.chat.completions.create(
    model="Qwen/Qwen3.6-27B",
    messages=[{"role": "user", "content": prompt}],
    max_tokens=32,
    temperature=0,
)
print("CHAT", repr(chat.choices[0].message.content))

resp = client.responses.create(
    model="Qwen/Qwen3.6-27B",
    input=prompt,
    max_output_tokens=32,
    temperature=0,
)
print("RESP", repr(resp.output_text))
PY
```

Expected:

```text
CHAT 'OK.'
RESP 'OK.'
```

## Access From Local Machine

Option 1: SSH tunnel:

```bash
ssh -L 8000:127.0.0.1:18000 Vast001
```

Then use:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="EMPTY",
)
```

Option 2: Vast/Caddy public `8000` usually proxies to `localhost:18000`. If using the Vast exposed URL/port, keep any required Vast auth/token behavior in mind.

## Useful Operations

Check status:

```bash
ps -eo pid,ppid,stat,pcpu,pmem,etime,cmd | grep -E "[v]llm serve|[V]LLM::EngineCore" || true
nvidia-smi --query-gpu=memory.used,memory.free,utilization.gpu --format=csv,noheader
ss -ltnp | grep ':18000'
curl -fsS http://127.0.0.1:18000/v1/models
```

Stop service:

```bash
if [ -f /root/vllm-dflash/vllm.pid ]; then
  kill "$(cat /root/vllm-dflash/vllm.pid)" 2>/dev/null || true
fi
ps -eo pid=,comm= | awk '$2 == "VLLM::EngineCore" {print $1}' | xargs -r kill 2>/dev/null || true
```

## Notes From Debugging

- BF16 `Qwen/Qwen3.6-27B` + BF16 DFlash OOMed on 32GB.
- AWQ INT4 target model plus DFlash loads with about 30.5GB used after initialization.
- `--enforce-eager` avoids torch.compile/cudagraph extra allocations that previously caused OOM.
- `--cpu-offload-gb 4` is required to keep enough GPU headroom.
- `--max-model-len 16384` and `--max-num-batched-tokens 16384` are the stable values used here.
- vLLM PR `40898` exposes `/v1/responses`, but this build dropped `default_chat_template_kwargs` in the Responses path. The patch above fixes thinking suppression for `/v1/responses`.
