# gcube-openclaude

OpenClaude 실행용 컨테이너 이미지. 사용 목적에 따라 두 가지 이미지 제공.

## 이미지 종류

| 이미지 | 베이스 | 용도 |
|--------|--------|------|
| `ghcr.io/data-alliance/gcube-openclaude:latest` | `nvidia/cuda:12.8.1-runtime-ubuntu22.04` | 클라우드 모델 + Ollama 로컬 모델 + gRPC |
| `ghcr.io/data-alliance/gcube-openclaude-vllm:latest` | `vllm/vllm-openai:v0.20.2-cu129` | Hugging Face 모델 (vLLM) 전용 |

- vllm 이미지는 베이스 이미지(vLLM + CUDA + PyTorch) 크기로 인해 빌드·배포에 시간이 오래 소요됨
- 첫 빌드 또는 첫 배포 시 충분한 대기 시간 확보 권장

## 포함 패키지

| 패키지 | 기본 이미지 | vllm 이미지 |
|--------|:----------:|:-----------:|
| Node.js 22.x | ✓ | ✓ |
| OpenClaude (`@gitlawb/openclaude`) | ✓ | ✓ |
| gcube CLI (`gcube-cli`) | ✓ | ✓ |
| Ollama | ✓ | — |
| vLLM | — | ✓ (베이스 포함) |

## 프로젝트 구조

```
.
├── .github/
│   └── workflows/
│       └── build.yml         # 두 이미지 ghcr.io 자동 빌드·push
├── Dockerfile                # 기본 이미지
├── Dockerfile.vllm           # vllm 이미지
├── entrypoint.sh             # 두 이미지 공용 entrypoint
└── README.md
```

## 환경변수

### 고정값 (이미지 내부 `ENV`)

| 변수 | 기본 이미지 | vllm 이미지 |
|------|------------|-------------|
| `CLAUDE_CODE_USE_OPENAI` | `1` | `1` |
| `TZ` | `Asia/Seoul` | `Asia/Seoul` |
| `OLLAMA_HOST` | `127.0.0.1:11434` | — |
| `OLLAMA_MAX_LOADED_MODELS` | `2` | — |
| `HF_HOME` | — | `/workspace/huggingface_cache` |

- 기본 모드: OpenAI 호환 (`CLAUDE_CODE_USE_OPENAI=1`)
- Anthropic native 모드 사용 시 사용자가 `USE_ANTHROPIC=1` 입력 → entrypoint가 `CLAUDE_CODE_USE_OPENAI` 자동 비활성화

### 사용자 입력 (워크로드 배포 시 지정)

**LLM Provider**

| 변수 | 설명 |
|------|------|
| `OPENAI_API_KEY` / `OPENAI_BASE_URL` / `OPENAI_MODEL` | OpenAI 호환 API (Z.ai, Moonshot, Ollama, vLLM 등) |
| `USE_ANTHROPIC` / `ANTHROPIC_API_KEY` / `ANTHROPIC_MODEL` | Anthropic 자체 API |
| `OLLAMA_MODELS` | Ollama 자동 pull 모델 (공백 구분, 기본 이미지만) |

**Git 자동 설정**

| 변수 | 설명 |
|------|------|
| `GIT_USER_NAME` / `GIT_USER_EMAIL` / `GIT_TOKEN` | Git 사용자 정보 + GitHub Personal Access Token (세 변수 모두 필요) |

**gcube CLI 자동 설정**

| 변수 | 설명 |
|------|------|
| `GCUBE_ACCESS_TOKEN` | gcube CLI 인증 토큰 |
| `GCUBE_OUTPUT` | (선택) 출력 형식 (`table` / `json` / `yaml`) |

**Hugging Face (vllm 이미지)**

| 변수 | 설명 |
|------|------|
| `HF_TOKEN` | Hugging Face Hub 인증 토큰 |

**gRPC 모드 (기본 이미지만)**

| 변수 | 설명 |
|------|------|
| `GRPC_MODE=1` | gRPC 서버 모드 활성화 (검증 미진행) |
| `GRPC_PORT` / `GRPC_HOST` | (선택) |

## 노출 포트

| 이미지 | 포트 | 용도 |
|--------|------|------|
| 기본 이미지 | `50051` | gRPC 서버 (`GRPC_MODE=1` 시) |
| vllm 이미지 | `8000` | vLLM OpenAI-compatible API |

## entrypoint 동작 순서

1. `USE_ANTHROPIC=1` 분기 → `CLAUDE_CODE_USE_OPENAI` 비활성화
2. Git 자동 설정 (선택)
3. gcube CLI 토큰 자동 등록 (선택)
4. Hugging Face Hub 토큰 자동 등록 (선택, vllm 이미지)
5. Ollama 백그라운드 시작 + `OLLAMA_MODELS` 자동 pull (기본 이미지만)
6. 안내 메시지 출력 → 컨테이너 유지 (사용자가 콘솔에서 `openclaude` 실행)

## 빌드 & 배포

`.github/workflows/build.yml`이 `main` 브랜치 push 시 두 이미지를 ghcr.io에 자동 빌드·push.

```
main → ghcr.io/data-alliance/gcube-openclaude:latest
     → ghcr.io/data-alliance/gcube-openclaude-vllm:latest
```

## 참고

- OpenClaude 공식: https://github.com/Gitlawb/openclaude
- OpenClaude 문서: https://github.com/Gitlawb/openclaude/blob/main/docs/advanced-setup.md
- gcube CLI: https://pypi.org/project/gcube-cli/
- vLLM Recipes: https://docs.vllm.ai/projects/recipes/en/latest/