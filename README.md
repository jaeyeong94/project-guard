# project-guard

Claude Code 플러그인 — 코드 작성 시 lint, type-check, test를 자동 강제합니다.

## 설치

```bash
# 1. 마켓플레이스 등록
claude plugin marketplace add jaeyeong94/project-guard

# 2. 플러그인 설치
claude plugin install project-guard@project-guard-marketplace
```

## 무엇을 하는가

### 파일 수정 시 — 자동 lint

Edit/Write로 파일을 수정하면 해당 파일에 lint가 자동 실행됩니다. 에러가 있으면 Claude에게 전달되어 즉시 수정합니다.

### git commit 시 — lint + type-check + test 강제

`git commit`을 시도하면 staged 파일에 대해 lint, type-check, test를 실행합니다. 하나라도 실패하면 커밋이 차단됩니다.

### 세션 시작 시 — 프로젝트 컨텍스트 제공

```
[project-guard] 프로젝트 컨텍스트
├─ 스택: TypeScript (Next.js) + bun
├─ Scripts: dev: next dev, build: next build, test: vitest, lint: eslint .
├─ 미커밋 변경: 5개 파일
├─ TODO: 12개, FIXME/HACK: 3개
└─ 검증 워크플로우: 설정됨 ✅
```

스택, 패키지 매니저, 프레임워크, 주요 scripts, 미커밋 변경, TODO/FIXME 카운트를 감지하여 Claude에게 프로젝트 상태를 전달합니다.

### `/project-guard` 스킬 — 프로젝트별 설정

프로젝트의 tech stack을 감지하고 `CLAUDE.md`에 lint, test, type-check 명령을 설정합니다.

## 지원 스택

| 스택 | Lint | Type-check | Test |
|------|------|-----------|------|
| JavaScript/TypeScript | ESLint | tsc --noEmit | package.json scripts.test |
| Python | ruff / flake8 | mypy | pytest |
| Go | golangci-lint / go vet | — | go test |
| Rust | cargo clippy | — | cargo test |

패키지 매니저는 bun > pnpm > yarn > npm 순서로 자동 감지합니다.

## 업데이트

```bash
claude plugin marketplace update project-guard-marketplace
claude plugin update project-guard@project-guard-marketplace
```

## 라이선스

MIT
