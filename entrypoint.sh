#!/bin/bash

echo "================================================"
echo "  OpenClaude Base Image Entrypoint"
echo "================================================"

# ============================================================
# Anthropic native 모드 분기 (USE_ANTHROPIC=1 시)
# - Dockerfile 기본값으로 CLAUDE_CODE_USE_OPENAI=1 적용되어 있음
# - Anthropic API 직접 호출이 필요하면 USE_ANTHROPIC=1 입력
# ============================================================
if [ "$USE_ANTHROPIC" = "1" ]; then
    unset CLAUDE_CODE_USE_OPENAI
    echo "[INFO] Anthropic native 모드 활성화 (CLAUDE_CODE_USE_OPENAI 비활성화)"
fi

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
# gcube CLI 자동 설정 (GCUBE_ACCESS_TOKEN 제공 시)
# - 환경변수 GCUBE_ACCESS_TOKEN가 있으면 gcube CLI 토큰 자동 등록
# - 미제공 시 사용자가 컨테이너 진입 후 직접 `gcube configure set --token <token>` 실행
# ============================================================
if [ -n "$GCUBE_ACCESS_TOKEN" ]; then
    echo ""
    echo "[INFO] gcube CLI 토큰 설정 중..."
    if gcube configure set --token "$GCUBE_ACCESS_TOKEN" > /dev/null 2>&1; then
        echo "✅ gcube configure 완료"
    else
        echo "[WARN] gcube configure 실패"
    fi
else
    echo "[INFO] GCUBE_ACCESS_TOKEN이 제공되지 않아 gcube CLI 자동 설정을 건너뜁니다."
fi

# ============================================================
# Hugging Face Hub 자동 인증 (HF_TOKEN 제공 시)
# - 환경변수 + 토큰 파일 둘 다 설정으로 견고성 확보
# - vllm 이미지에서만 동작 (huggingface_hub CLI 존재 시)
# - default 이미지에서는 huggingface_hub CLI 미설치로 건너뜀 (환경변수만 유지)
# ============================================================
if [ -n "$HF_TOKEN" ]; then
    echo ""
    echo "[INFO] Hugging Face Hub 토큰 설정 중..."
    if command -v hf > /dev/null 2>&1; then
        if hf auth login --token "$HF_TOKEN" --add-to-git-credential > /dev/null 2>&1; then
            echo "✅ Hugging Face 토큰 등록 완료"
        else
            echo "[WARN] Hugging Face 토큰 등록 실패"
        fi
    elif command -v huggingface-cli > /dev/null 2>&1; then
        if huggingface-cli login --token "$HF_TOKEN" --add-to-git-credential > /dev/null 2>&1; then
            echo "✅ Hugging Face 토큰 등록 완료"
        else
            echo "[WARN] Hugging Face 토큰 등록 실패"
        fi
    else
        echo "[INFO] Hugging Face CLI 미설치 — 환경변수 HF_TOKEN만 유지 (라이브러리 자동 인식)"
    fi
fi

# ============================================================
# Ollama 백그라운드 시작 (Ollama가 설치된 이미지에서만)
# - default 이미지: Ollama 설치되어 있음 → 시작
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

  Mode:      ${USE_ANTHROPIC:+Anthropic native}${USE_ANTHROPIC:-OpenAI compatible}
  Provider:  ${OPENAI_BASE_URL:-${ANTHROPIC_BASE_URL:-anthropic native}}
  Model:     ${OPENAI_MODEL:-${ANTHROPIC_MODEL:-default}}
  Git user:  ${GIT_USER_NAME:-not configured}
  gcube CLI: ${GCUBE_ACCESS_TOKEN:+configured}${GCUBE_ACCESS_TOKEN:-not configured}
  HF Token:  ${HF_TOKEN:+configured}${HF_TOKEN:-not configured}

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
    \$ gcube workload list                   # list gcube workloads (if configured)
    \$ ollama list                           # list pulled local models (default image only)
    \$ ollama pull <model>                   # pull a local model (default image only)

==================================================================

EOF

echo "================================================"
echo "  설정 완료! 컨테이너를 시작합니다."
echo "================================================"

# ============================================================
# gRPC 서버 모드 분기 (GRPC_MODE=1 시 자동 기동)
# - default 이미지에서만 동작 (vllm 이미지에는 bun + 소스 없음)
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
        echo "[WARN] gRPC 모드는 default 이미지(gcube-openclaude)를 사용해주세요."
    fi
fi

# ============================================================
# 추가 커맨드 처리 + 컨테이너 유지 (콘솔 모드)
# ============================================================
if [ $# -gt 0 ]; then
    "$@" &
fi

tail -f /dev/null