#!/bin/bash

echo "================================================"
echo "  OpenClaude Base Image Entrypoint"
echo "================================================"

# ============================================================
# Git 자동 설정 (환경변수 기반)
# ============================================================
MISSING_VARS=0
for VAR in GIT_USER_NAME GIT_USER_EMAIL GIT_TOKEN; do
    if [ -z "${!VAR}" ]; then
        echo "[INFO] '$VAR' 환경변수가 제공되지 않았습니다."
        MISSING_VARS=1
    fi
done

if [ $MISSING_VARS -eq 1 ]; then
    echo "[INFO] Git 구성 없이 컨테이너를 시작합니다."
else
    echo "[1/3] Git 초기화 중..."
    git init /workspace 2>/dev/null || true
    echo "✅ git init 완료"

    echo "[2/3] Git 사용자 설정 중..."
    git config --global user.name "$GIT_USER_NAME"
    echo "✅ user.name: $GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    echo "✅ user.email: $GIT_USER_EMAIL"

    echo "[3/3] Git 인증 설정 중..."
    git config --global credential.helper store
    echo "https://$GIT_USER_NAME:$GIT_TOKEN@github.com" > ~/.git-credentials
    chmod 600 ~/.git-credentials
    echo "[INFO] Git 구성이 완료되었습니다."
fi

# ============================================================
# Ollama 백그라운드 시작 (Ollama가 설치된 이미지에서만)
# - basic 이미지: Ollama 설치되어 있음 → 시작
# - vllm 이미지: Ollama 없음 → 건너뜀
# ============================================================
if command -v ollama > /dev/null 2>&1; then
    echo ""
    echo "[INFO] Starting Ollama..."
    ollama serve > /var/log/ollama.log 2>&1 &

    echo "[INFO] Waiting for Ollama to be ready..."
    until curl -s http://localhost:11434 > /dev/null 2>&1; do
        sleep 1
    done
    echo "[INFO] Ollama ready."

    # OLLAMA_MODELS 환경변수가 있으면 자동 pull (공백 구분, 다수 모델 가능)
    # 예: OLLAMA_MODELS="glm-4.7-flash:q4_K_M qwen3:14b"
    if [ -n "$OLLAMA_MODELS" ]; then
        echo ""
        echo "================================================"
        echo "  Ollama Auto Pull"
        echo "================================================"
        echo "  Models: $OLLAMA_MODELS"
        echo "================================================"
        
        for MODEL in $OLLAMA_MODELS; do
            echo "[INFO] Pulling: $MODEL"
            ollama pull "$MODEL" || echo "[WARN] Failed to pull: $MODEL"
        done
        echo "[INFO] Ollama models ready."
    fi
else
    echo ""
    echo "[INFO] Ollama not installed (vllm image), skipping Ollama startup."
fi

# ============================================================
# OpenClaude 안내 메시지
# ============================================================
cat << EOF

==================================================================
  OpenClaude container is ready
==================================================================

  Provider:  ${OPENAI_BASE_URL:-${ANTHROPIC_BASE_URL:-anthropic native}}
  Model:     ${OPENAI_MODEL:-${ANTHROPIC_MODEL:-default}}
  Git user:  ${GIT_USER_NAME:-not configured}

  To start, run:
    \$ openclaude

  Useful slash commands inside openclaude:
    /help      - List all available commands
    /provider  - Add or switch provider (guided wizard)
    /model     - Change current model
    /cost      - Show token usage and cost
    /doctor    - Diagnose configuration

  Useful CLI commands:
    \$ openclaude --print "your task here"   # one-shot mode
    \$ openclaude --version                  # check version
    \$ ollama list                           # list pulled local models (basic image only)
    \$ ollama pull <model>                   # pull a local model (basic image only)

==================================================================

EOF

echo "================================================"
echo "  설정 완료! 컨테이너를 시작합니다."
echo "================================================"

# ============================================================
# gRPC 서버 모드 분기 (GRPC_MODE=1 시 자동 기동)
# - basic 이미지에서만 동작 (vllm 이미지에는 bun + 소스 없음)
# ============================================================
if [ "$GRPC_MODE" = "1" ]; then
    if [ -d "/opt/openclaude" ] && command -v bun > /dev/null 2>&1; then
        echo ""
        echo "================================================"
        echo "  OpenClaude gRPC Server Mode"
        echo "================================================"
        echo "  Port:  ${GRPC_PORT:-50051}"
        echo "  Host:  ${GRPC_HOST:-0.0.0.0}"
        echo "  Model: ${OPENAI_MODEL:-${ANTHROPIC_MODEL:-default}}"
        echo "================================================"

        cd /opt/openclaude
        exec bun run dev:grpc
    else
        echo ""
        echo "[WARN] GRPC_MODE=1 이지만 gRPC 실행 환경이 없습니다 (vllm 이미지)."
        echo "[WARN] gRPC 모드는 basic 이미지(gcube-openclaude)를 사용해주세요."
    fi
fi

# ============================================================
# 추가 커맨드 처리 + 컨테이너 유지 (콘솔 모드)
# ============================================================
if [ $# -gt 0 ]; then
    "$@" &
fi

tail -f /dev/null