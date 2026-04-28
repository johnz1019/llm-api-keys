#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-Vast002}"
GEMMA_MODEL="${GEMMA_MODEL:-ebircak/gemma-4-31B-it-4bit-W4A16-AWQ}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-gemma-4-31b}"
REMOTE_PORT="${REMOTE_PORT:-18000}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-32768}"
MAX_NUM_BATCHED_TOKENS="${MAX_NUM_BATCHED_TOKENS:-8192}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"
QUANTIZATION="${QUANTIZATION:-compressed-tensors}"
KV_CACHE_DTYPE="${KV_CACHE_DTYPE:-fp8_e4m3}"

REMOTE_ENV=(
  "GEMMA_MODEL=$(printf '%q' "${GEMMA_MODEL}")"
  "SERVED_MODEL_NAME=$(printf '%q' "${SERVED_MODEL_NAME}")"
  "REMOTE_PORT=$(printf '%q' "${REMOTE_PORT}")"
  "MAX_MODEL_LEN=$(printf '%q' "${MAX_MODEL_LEN}")"
  "MAX_NUM_BATCHED_TOKENS=$(printf '%q' "${MAX_NUM_BATCHED_TOKENS}")"
  "GPU_MEMORY_UTILIZATION=$(printf '%q' "${GPU_MEMORY_UTILIZATION}")"
  "QUANTIZATION=$(printf '%q' "${QUANTIZATION}")"
  "KV_CACHE_DTYPE=$(printf '%q' "${KV_CACHE_DTYPE}")"
)

if [ -n "${HF_TOKEN:-}" ]; then
  REMOTE_ENV+=("HF_TOKEN_VALUE=$(printf '%q' "${HF_TOKEN}")")
fi

ssh "${HOST}" "env ${REMOTE_ENV[*]} bash -s" <<'REMOTE'
set -euo pipefail

REMOTE_ROOT="/workspace/gemma-4-vllm"
REMOTE_VENV="${REMOTE_ROOT}/.venv"
REMOTE_START="/workspace/start_gemma4_vllm.sh"
REMOTE_MODELS="/workspace/models"
REMOTE_HF_HOME="/workspace/.hf_home"
REMOTE_HF_TOKEN_FILE="/workspace/.hf_token"

mkdir -p "${REMOTE_ROOT}" "${REMOTE_MODELS}" "${REMOTE_HF_HOME}"

if [ -n "${HF_TOKEN_VALUE:-}" ]; then
  umask 077
  printf '%s' "${HF_TOKEN_VALUE}" > "${REMOTE_HF_TOKEN_FILE}"
  umask 022
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required on remote host" >&2
  exit 1
fi

if [ ! -x "${REMOTE_VENV}/bin/python" ]; then
  uv venv "${REMOTE_VENV}" --python 3.12
fi

. "${REMOTE_VENV}/bin/activate"

uv pip install --upgrade pip
uv pip install -U vllm --pre \
  --extra-index-url https://wheels.vllm.ai/nightly \
  --extra-index-url https://download.pytorch.org/whl/cu129
uv pip install nvidia-cuda-runtime

cat > "${REMOTE_START}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

export HF_HOME="/workspace/.hf_home"
export FLASHINFER_DISABLE_VERSION_CHECK=1
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"
export LD_LIBRARY_PATH="/workspace/gemma-4-vllm/.venv/lib/python3.12/site-packages/nvidia/cu13/lib:${LD_LIBRARY_PATH:-}"

HF_TOKEN_FILE="/workspace/.hf_token"
if [ -s "${HF_TOKEN_FILE}" ]; then
  export HF_TOKEN="$(cat "${HF_TOKEN_FILE}")"
  export HUGGING_FACE_HUB_TOKEN="${HF_TOKEN}"
fi

cd /workspace/gemma-4-vllm
. /workspace/gemma-4-vllm/.venv/bin/activate

exec vllm serve "${GEMMA_MODEL}" \
  --served-model-name "${SERVED_MODEL_NAME}" \
  --host 127.0.0.1 \
  --port "${REMOTE_PORT}" \
  --download-dir /workspace/models \
  --max-model-len "${MAX_MODEL_LEN}" \
  --max-num-batched-tokens "${MAX_NUM_BATCHED_TOKENS}" \
  --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION}" \
  --quantization "${QUANTIZATION}" \
  --kv-cache-dtype "${KV_CACHE_DTYPE}" \
  --limit-mm-per-prompt '{"image": 0, "audio": 0}' \
  --default-chat-template-kwargs '{"enable_thinking": false}' \
  --enforce-eager \
  --trust-remote-code
EOF

sed -i \
  -e "s|\${GEMMA_MODEL}|${GEMMA_MODEL}|g" \
  -e "s|\${SERVED_MODEL_NAME}|${SERVED_MODEL_NAME}|g" \
  -e "s|\${REMOTE_PORT}|${REMOTE_PORT}|g" \
  -e "s|\${MAX_MODEL_LEN}|${MAX_MODEL_LEN}|g" \
  -e "s|\${MAX_NUM_BATCHED_TOKENS}|${MAX_NUM_BATCHED_TOKENS}|g" \
  -e "s|\${GPU_MEMORY_UTILIZATION}|${GPU_MEMORY_UTILIZATION}|g" \
  -e "s|\${QUANTIZATION}|${QUANTIZATION}|g" \
  -e "s|\${KV_CACHE_DTYPE}|${KV_CACHE_DTYPE}|g" \
  "${REMOTE_START}"

chmod +x "${REMOTE_START}"

cat > /root/onstart.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec /workspace/start_gemma4_vllm.sh
EOF
chmod +x /root/onstart.sh

if [ -f /etc/supervisor/conf.d/vllm.conf ]; then
  cp /etc/supervisor/conf.d/vllm.conf \
    "/etc/supervisor/conf.d/vllm.conf.bak-gemma4-$(date +%Y%m%d%H%M%S)"
fi

cat > /etc/supervisor/conf.d/vllm.conf <<'EOF'
[program:vllm]
command=/workspace/start_gemma4_vllm.sh
autostart=true
autorestart=unexpected
exitcodes=0
startsecs=10
stopasgroup=true
killasgroup=true
stopsignal=TERM
stopwaitsecs=20
stdout_logfile=/workspace/gemma-4-vllm/vllm.log
redirect_stderr=true
stdout_events_enabled=true
stdout_logfile_maxbytes=104857600
stdout_logfile_backups=3
EOF

supervisorctl stop vllm 2>/dev/null || true
ps -eo pid=,args= | awk '/vllm serve/ && $0 !~ /awk/ {print $1}' | xargs -r kill 2>/dev/null || true
sleep 3
ps -eo pid=,comm= | awk '$2 == "VLLM::EngineCore" {print $1}' | xargs -r kill 2>/dev/null || true
sleep 2
ps -eo pid=,args= | awk '/vllm serve/ && $0 !~ /awk/ {print $1}' | xargs -r kill -9 2>/dev/null || true
ps -eo pid=,comm= | awk '$2 == "VLLM::EngineCore" {print $1}' | xargs -r kill -9 2>/dev/null || true

supervisorctl reread
supervisorctl update
if ! supervisorctl status vllm | grep -Eq 'RUNNING|STARTING'; then
  supervisorctl start vllm
fi

for _ in $(seq 1 90); do
  if curl -fsS --max-time 5 "http://127.0.0.1:${REMOTE_PORT}/v1/models" >/dev/null 2>&1; then
    curl -fsS "http://127.0.0.1:${REMOTE_PORT}/v1/models"
    exit 0
  fi
  sleep 10
done

echo "Gemma 4 vLLM did not become ready within timeout. Recent supervisor status:" >&2
supervisorctl status vllm >&2 || true
exit 1
REMOTE
