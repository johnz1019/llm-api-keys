#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-Vast001}"

if [ -z "${HF_TOKEN:-}" ]; then
  echo "HF_TOKEN is required. Example: HF_TOKEN=<huggingface-token> $0 ${HOST}" >&2
  exit 1
fi

HF_TOKEN_VALUE="${HF_TOKEN}"
REMOTE_ENV="HF_TOKEN_VALUE=$(printf '%q' "${HF_TOKEN_VALUE}")"

ssh "${HOST}" "${REMOTE_ENV} bash -s" <<'REMOTE'
set -euo pipefail

REMOTE_ROOT="/workspace/qwen36-vllm"
REMOTE_VENV="${REMOTE_ROOT}/.venv"
REMOTE_START="/workspace/start_qwen36_vllm_dflash.sh"
REMOTE_LOG="${REMOTE_ROOT}/vllm-awq-notthinking.log"
REMOTE_PID="${REMOTE_ROOT}/vllm.pid"
REMOTE_MODELS="/workspace/models"
REMOTE_HF_HOME="/workspace/.hf_home"
REMOTE_HF_TOKEN_FILE="/workspace/.hf_token"

export HF_TOKEN="${HF_TOKEN_VALUE}"
export HUGGING_FACE_HUB_TOKEN="${HF_TOKEN_VALUE}"
export HF_HOME="${REMOTE_HF_HOME}"

mkdir -p "${REMOTE_ROOT}" "${REMOTE_MODELS}" "${REMOTE_HF_HOME}"
umask 077
printf '%s' "${HF_TOKEN_VALUE}" > "${REMOTE_HF_TOKEN_FILE}"
umask 022

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required on remote host" >&2
  exit 1
fi

if [ ! -x "${REMOTE_VENV}/bin/python" ]; then
  uv venv "${REMOTE_VENV}" --python 3.12
fi

. "${REMOTE_VENV}/bin/activate"

python - <<'PY' >/dev/null 2>&1 || uv pip install huggingface_hub
import huggingface_hub
PY

python - <<'PY'
from huggingface_hub import hf_hub_download

for repo, filename in [
    ("cyankiwi/Qwen3.6-27B-AWQ-INT4", "config.json"),
    ("z-lab/Qwen3.6-27B-DFlash", "config.json"),
]:
    path = hf_hub_download(repo_id=repo, filename=filename, local_files_only=False)
    print(repo, path)
PY

if ! python - <<'PY'
import importlib.util
mods = [
    "vllm.model_executor.models.qwen3_dflash",
    "vllm.v1.spec_decode.dflash",
]
raise SystemExit(0 if all(importlib.util.find_spec(m) is not None for m in mods) else 1)
PY
then
  uv pip install vllm
  VLLM_USE_PRECOMPILED=1 uv pip install -U --torch-backend=auto \
    "vllm @ git+https://github.com/vllm-project/vllm.git@refs/pull/40898/head"
fi

python - <<'PY'
from pathlib import Path

root = Path("/workspace/qwen36-vllm/.venv/lib/python3.12/site-packages/vllm/entrypoints/openai")
serving = root / "responses" / "serving.py"
router = root / "generate" / "api_router.py"
parser = root / "parser" / "responses_parser.py"

text = serving.read_text()

if 'default_chat_template_kwargs: dict[str, Any] | None = None,' not in text:
    text = text.replace(
        '        tool_server: ToolServer | None = None,\n'
        '        enable_prompt_tokens_details: bool = False,\n',
        '        tool_server: ToolServer | None = None,\n'
        '        default_chat_template_kwargs: dict[str, Any] | None = None,\n'
        '        enable_prompt_tokens_details: bool = False,\n',
    )

if 'self.default_chat_template_kwargs = default_chat_template_kwargs or {}' not in text:
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

router_text = router.read_text()
if 'default_chat_template_kwargs=args.default_chat_template_kwargs,' not in router_text:
    router_text = router_text.replace(
        '            reasoning_parser=args.structured_outputs_config.reasoning_parser,\n'
        '            enable_prompt_tokens_details=args.enable_prompt_tokens_details,\n',
        '            reasoning_parser=args.structured_outputs_config.reasoning_parser,\n'
        '            default_chat_template_kwargs=args.default_chat_template_kwargs,\n'
        '            enable_prompt_tokens_details=args.enable_prompt_tokens_details,\n',
    )
    router.write_text(router_text)

parser_text = parser.read_text()
parser_text = parser_text.replace(
    '    return request.build_chat_params(\n'
    '        default_template=chat_template,\n'
    '        default_template_content_format=chat_template_content_format,\n'
    '    ).chat_template_kwargs\n',
    '    default_kwargs = getattr(request, "_vllm_default_chat_template_kwargs", None) or {}\n'
    '    return default_kwargs | request.build_chat_params(\n'
    '        default_template=chat_template,\n'
    '        default_template_content_format=chat_template_content_format,\n'
    '    ).chat_template_kwargs\n',
)
parser.write_text(parser_text)

if "request._vllm_default_chat_template_kwargs = self.default_chat_template_kwargs" not in text:
    text = text.replace(
        "        if maybe_validation_error is not None:\n"
        "            return maybe_validation_error\n\n"
        "        # If the engine is dead, raise the engine's DEAD_ERROR.\n",
        "        if maybe_validation_error is not None:\n"
        "            return maybe_validation_error\n\n"
        "        # ResponsesParser reconstructs parser kwargs from the request object.\n"
        "        request._vllm_default_chat_template_kwargs = self.default_chat_template_kwargs\n\n"
        "        # If the engine is dead, raise the engine's DEAD_ERROR.\n",
    )

if "def _should_use_chat_completion_shim" not in text:
    marker = "    async def _make_request(\n"
    shim = '''
    def _should_use_chat_completion_shim(self, request: ResponsesRequest) -> bool:
        return (
            not request.stream
            and not request.tools
            and request.previous_response_id is None
            and request.previous_input_messages is None
            and request.prompt is None
            and not self.use_harmony
        )

    async def _create_simple_response_via_chat_completion(
        self,
        request: ResponsesRequest,
        raw_request: Request | None,
    ) -> ResponsesResponse | ErrorResponse | None:
        if raw_request is None:
            return None

        import httpx

        messages = construct_input_messages(
            request_instructions=request.instructions,
            request_input=request.input,
        )
        payload = {
            "model": request.model,
            "messages": messages,
            "max_tokens": request.max_output_tokens,
            "temperature": request.temperature,
            "top_p": request.top_p,
            "top_k": request.top_k,
            "presence_penalty": request.presence_penalty,
            "frequency_penalty": request.frequency_penalty,
            "repetition_penalty": request.repetition_penalty,
            "stop": request.stop,
            "seed": request.seed,
            "logit_bias": request.logit_bias,
            "skip_special_tokens": request.skip_special_tokens,
            "include_stop_str_in_output": request.include_stop_str_in_output,
            "chat_template_kwargs": {"enable_thinking": False},
        }
        payload = {k: v for k, v in payload.items() if v is not None}

        chat_url = str(raw_request.base_url).rstrip("/") + "/v1/chat/completions"
        async with httpx.AsyncClient(timeout=300.0) as client:
            result = await client.post(chat_url, json=payload)

        if result.status_code != 200:
            return self.create_error_response(
                message=f"Responses shim upstream chat call failed: {result.text}",
                err_type="internal_server_error",
                status_code=result.status_code,
            )

        data = result.json()
        content = (
            data.get("choices", [{}])[0]
            .get("message", {})
            .get("content", "")
        )
        usage_json = data.get("usage", {}) or {}
        prompt_tokens = usage_json.get("prompt_tokens", 0)
        completion_tokens = usage_json.get("completion_tokens", 0)
        total_tokens = usage_json.get("total_tokens", prompt_tokens + completion_tokens)

        sampling_params = request.to_sampling_params(
            request.max_output_tokens or self.model_config.max_model_len,
            self.default_sampling_params,
        )
        usage = ResponseUsage(
            input_tokens=prompt_tokens,
            output_tokens=completion_tokens,
            total_tokens=total_tokens,
            input_tokens_details=InputTokensDetails(
                cached_tokens=0,
                input_tokens_per_turn=[],
                cached_tokens_per_turn=[],
            ),
            output_tokens_details=OutputTokensDetails(
                reasoning_tokens=0,
                tool_output_tokens=0,
                output_tokens_per_turn=[],
                tool_output_tokens_per_turn=[],
            ),
        )
        output = [
            ResponseOutputMessage(
                type="message",
                id=f"msg_{random_uuid()}",
                status="completed",
                role="assistant",
                content=[
                    ResponseOutputText(
                        annotations=[],
                        type="output_text",
                        text=content,
                        logprobs=None,
                    )
                ],
            )
        ]
        response = ResponsesResponse.from_request(
            request,
            sampling_params,
            model_name=data.get("model", request.model or self.models.base_model_paths[0].name),
            created_time=int(data.get("created", time.time())),
            output=output,
            status="completed",
            usage=usage,
        )
        if request.store and self.enable_store:
            async with self.response_store_lock:
                self.response_store[response.id] = response
        return response

'''
    text = text.replace(marker, shim + marker)

if "request._vllm_default_chat_template_kwargs = self.default_chat_template_kwargs" in text and "self._should_use_chat_completion_shim(request)" not in text:
    text = text.replace(
        "        if request.store and not self.enable_store:\n"
        "            # Disable the store option.\n",
        "        if request.store and not self.enable_store:\n"
        "            # Disable the store option.\n",
    )
    text = text.replace(
        "            request.store = False\n\n"
        "        # ResponsesParser reconstructs parser kwargs from the request object.\n"
        "        request._vllm_default_chat_template_kwargs = self.default_chat_template_kwargs\n\n"
        "        # If the engine is dead, raise the engine's DEAD_ERROR.\n",
        "            request.store = False\n\n"
        "        # ResponsesParser reconstructs parser kwargs from the request object.\n"
        "        request._vllm_default_chat_template_kwargs = self.default_chat_template_kwargs\n\n"
        "        if self._should_use_chat_completion_shim(request):\n"
        "            shimmed = await self._create_simple_response_via_chat_completion(\n"
        "                request, raw_request\n"
        "            )\n"
        "            if shimmed is not None:\n"
        "                return shimmed\n\n"
        "        # If the engine is dead, raise the engine's DEAD_ERROR.\n",
    )

serving.write_text(text)
PY

python -m py_compile \
  "${REMOTE_VENV}/lib/python3.12/site-packages/vllm/entrypoints/openai/parser/responses_parser.py" \
  "${REMOTE_VENV}/lib/python3.12/site-packages/vllm/entrypoints/openai/responses/serving.py" \
  "${REMOTE_VENV}/lib/python3.12/site-packages/vllm/entrypoints/openai/generate/api_router.py"

cat > "${REMOTE_START}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

HF_TOKEN_FILE="/workspace/.hf_token"
if [ ! -s "${HF_TOKEN_FILE}" ]; then
  echo "Missing ${HF_TOKEN_FILE}. Re-run setup with HF_TOKEN set." >&2
  exit 1
fi

export HF_TOKEN="$(cat "${HF_TOKEN_FILE}")"
export HUGGING_FACE_HUB_TOKEN="${HF_TOKEN}"
export HF_HOME='/workspace/.hf_home'
export PYTORCH_CUDA_ALLOC_CONF='expandable_segments:True'

cd /workspace/qwen36-vllm
. /workspace/qwen36-vllm/.venv/bin/activate

exec vllm serve cyankiwi/Qwen3.6-27B-AWQ-INT4 \
  --served-model-name Qwen/Qwen3.6-27B \
  --host 0.0.0.0 \
  --port 18000 \
  --download-dir /workspace/models \
  --speculative-config '{"method": "dflash", "model": "z-lab/Qwen3.6-27B-DFlash", "num_speculative_tokens": 15}' \
  --attention-backend flash_attn \
  --max-num-batched-tokens 16384 \
  --max-model-len 16384 \
  --max-num-seqs 8 \
  --cpu-offload-gb 4 \
  --enforce-eager \
  --default-chat-template-kwargs '{"enable_thinking": false}'
EOF

chmod +x "${REMOTE_START}"

cat > /root/onstart.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec /workspace/start_qwen36_vllm_dflash.sh
EOF

chmod +x /root/onstart.sh

cp /etc/supervisor/conf.d/vllm.conf /etc/supervisor/conf.d/vllm.conf.bak-qwen36
cat > /etc/supervisor/conf.d/vllm.conf <<'EOF'
[program:vllm]
command=/workspace/start_qwen36_vllm_dflash.sh
autostart=true
autorestart=unexpected
exitcodes=0
startsecs=0
stopasgroup=true
killasgroup=true
stopsignal=TERM
stopwaitsecs=10
stdout_logfile=/dev/stdout
redirect_stderr=true
stdout_events_enabled=true
stdout_logfile_maxbytes=0
stdout_logfile_backups=0
EOF

supervisorctl stop vllm 2>/dev/null || true
ps -eo pid=,args= | awk '/vllm serve/ && $0 !~ /awk/ {print $1}' | xargs -r kill 2>/dev/null || true
sleep 3
ps -eo pid=,comm= | awk '$2 == "VLLM::EngineCore" {print $1}' | xargs -r kill 2>/dev/null || true
sleep 2
ps -eo pid=,args= | awk '/vllm serve/ && $0 !~ /awk/ {print $1}' | xargs -r kill -9 2>/dev/null || true
ps -eo pid=,comm= | awk '$2 == "VLLM::EngineCore" {print $1}' | xargs -r kill -9 2>/dev/null || true

rm -f "${REMOTE_LOG}" "${REMOTE_PID}"
supervisorctl reread
supervisorctl update
supervisorctl start vllm

for _ in $(seq 1 60); do
  if curl -fsS --max-time 5 http://127.0.0.1:18000/v1/models >/dev/null 2>&1; then
    break
  fi
  sleep 10
done

curl -fsS http://127.0.0.1:18000/v1/models
REMOTE
