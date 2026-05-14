FROM nvidia/cuda:12.8.1-runtime-ubuntu22.04

# ============================================================
# Environment
# ============================================================
ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV TZ=Asia/Seoul
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Ollama defaults (overridable via gcube workload env)
ENV OLLAMA_HOST=127.0.0.1:11434
ENV OLLAMA_MAX_LOADED_MODELS=2

# OpenClaude default mode (OpenAI 호환 모드)
# Anthropic native 호출 시에만 사용자가 USE_ANTHROPIC=1 입력
ENV CLAUDE_CODE_USE_OPENAI=1

# ============================================================
# Base packages
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl wget git nano vim ca-certificates build-essential \
        python3 python3-pip jq zstd ripgrep locales \
    && locale-gen ko_KR.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Node.js 22 (OpenClaude requires >= 22)
# ============================================================
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Ollama (for local model scenarios)
# ============================================================
RUN curl -fsSL https://ollama.com/download/ollama-linux-amd64.tar.zst \
        -o /tmp/ollama.tar.zst \
    && zstd -d /tmp/ollama.tar.zst --stdout | tar x -C /usr \
    && rm /tmp/ollama.tar.zst

# ============================================================
# OpenClaude
# ============================================================
RUN npm install -g @gitlawb/openclaude

# ============================================================
# gcube CLI (워크로드 관리·모니터링)
# ============================================================
RUN pip3 install gcube-cli

# ============================================================
# Workspace
# ============================================================
RUN mkdir -p /root/.claude /workspace
WORKDIR /workspace

# ============================================================
# Exposed ports
# - 50051: gRPC server (GRPC_MODE=1 시 사용, 기능 검증 미진행)
# ============================================================
EXPOSE 50051

# ============================================================
# Entrypoint
# ============================================================
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]