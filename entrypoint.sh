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
# Ollama 백그라운드 시작
# ============================================================
echo ""
echo "[INFO] Starting Ollama..."
ollama serve > /var/log/ollama.log 2>&1 &

echo "[INFO] Waiting for Ollama to be ready..."
until curl -s http://localhost:11434 > /dev/null 2>&1; do
    sleep 1
done
echo "[INFO] Ollama ready."

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
    \$ ollama list                           # list pulled local models
    \$ ollama pull <model>                   # pull a local model

==================================================================

EOF

echo "================================================"
echo "  설정 완료! 컨테이너를 시작합니다."
echo "================================================"

# ============================================================
# 추가 커맨드 처리 + 컨테이너 유지
# ============================================================
if [ $# -gt 0 ]; then
    "$@" &
fi

tail -f /dev/null