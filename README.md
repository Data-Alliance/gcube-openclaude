# openclaude-baseimage

OpenClaude를 gcube 워크로드 환경에서 실행하기 위한 컨테이너 이미지입니다.
GLM, Kimi, Anthropic, Ollama 등 다양한 LLM provider를 지원합니다.

## 구성

- **Base**: nvidia/cuda 12.8.1 (Ubuntu 22.04)
- **Runtime**: Node.js 22, Ollama
- **App**: @gitlawb/openclaude (npm)
- **Tools**: ripgrep, git, python3, jq

## 빌드 및 배포

```
git push origin main
```

GitHub Actions가 자동으로 이미지를 빌드해서 ghcr.io에 푸시합니다.

이미지 태그: `ghcr.io/<owner>/openclaude-baseimage:latest`

## gcube 워크로드 설정

### 이미지

```
ghcr.io/<owner>/openclaude-baseimage:latest
```

### 환경변수

#### LLM Provider (시나리오별)

기본은 OpenClaude README의 표준 환경변수를 그대로 사용합니다.

##### Z.ai GLM
```
CLAUDE_CODE_USE_OPENAI=1
OPENAI_API_KEY=<Z.ai API key>
OPENAI_BASE_URL=https://api.z.ai/api/paas/v4
OPENAI_MODEL=glm-5.1
```

##### Moonshot Kimi
```
CLAUDE_CODE_USE_OPENAI=1
OPENAI_API_KEY=<Moonshot API key>
OPENAI_BASE_URL=https://api.moonshot.ai/v1
OPENAI_MODEL=kimi-k2.6
```

##### Anthropic Sonnet (비교군)
```
ANTHROPIC_API_KEY=<Anthropic API key>
ANTHROPIC_MODEL=claude-sonnet-4-5
```

##### Ollama 로컬
```
CLAUDE_CODE_USE_OPENAI=1
OPENAI_API_KEY=ollama
OPENAI_BASE_URL=http://localhost:11434/v1
OPENAI_MODEL=qwen3:14b
```

#### Git 자동 설정 (선택)

세 변수 모두 제공되면 컨테이너 시작 시 자동으로 git 설정이 완료됩니다.
하나라도 비어있으면 git 설정 없이 컨테이너만 기동됩니다.

```
GIT_USER_NAME=<GitHub username>
GIT_USER_EMAIL=<email>
GIT_TOKEN=<GitHub Personal Access Token>
```

설정 후 컨테이너 안에서 바로 `git clone`·`git push` 가능합니다.

### 마운트

| 외부 저장소 | 컨테이너 경로 | 용도 |
|---|---|---|
| `dropbox-openclaude_data` | `/root/.claude` | OpenClaude 설정·세션·메모리 보존 |

작업물 보존이 필요하면 추가 마운트:

| 외부 저장소 | 컨테이너 경로 | 용도 |
|---|---|---|
| `dropbox-openclaude_workspace` | `/workspace` | 코드·결과 보존 |

## 사용법

1. gcube 워크로드 배포
2. 컨테이너 콘솔(SSH 또는 웹 콘솔) 진입
3. `openclaude` 입력
4. 자연어로 task 지시

```
$ openclaude
> 이 디렉토리 구조를 분석해줘
> hello.py 파일을 만들어서 Hello World 출력하게 해줘
```

### Git 워크플로우

Git 자동 설정이 활성화된 경우, 컨테이너 안에서 바로 작업 가능:

```
$ git clone https://github.com/<owner>/<repo>.git
$ cd <repo>
$ openclaude
> 이 프로젝트에 README 추가하고 commit·push까지 해줘
```

### 자동화 모드

자동화나 스크립트 검증에는 `--print` 모드 사용:

```
$ openclaude --print "이 프로젝트의 README 작성해줘"
```

### 슬래시 명령

세션 안에서 사용 가능한 주요 명령:

| 명령 | 용도 |
|---|---|
| `/help` | 모든 명령 목록 |
| `/provider` | provider 추가 또는 전환 (가이드 마법사) |
| `/model` | 현재 provider 내에서 모델 변경 |
| `/cost` | 토큰 사용량 및 비용 |
| `/doctor` | 환경 진단 |

## 로컬 모델 추가

컨테이너 안에서 Ollama로 로컬 모델 추가 가능:

```
$ ollama pull qwen3:14b
$ ollama list
```

## 참고

- OpenClaude: https://github.com/Gitlawb/openclaude
- Ollama: https://ollama.com