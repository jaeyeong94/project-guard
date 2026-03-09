# project-guard

Claude Code 플러그인 — 프로젝트 검증 워크플로우 자동화

## 기능

### 하드 강제 (Hooks — 자동 실행)

| Hook | 트리거 | 동작 |
|------|--------|------|
| **PostToolUse** | Edit/Write 후 | 변경 파일 lint 실행, 에러 시 Claude에게 전달 |
| **PreToolUse** | git commit 전 | staged 파일 lint + type-check + test, 실패 시 커밋 차단 |
| **SessionStart** | 세션 시작 | 검증 워크플로우 미설정 프로젝트 감지 → `/project-guard` 제안 |

### 소프트 강제 (CLAUDE.md + Skill)

- **CLAUDE.md**: 검증 원칙 항상 로드
- **`/project-guard`**: 프로젝트 tech stack 감지 → CLAUDE.md에 검증 명령 설정

### 지원 스택

| 스택 | Lint | Type-check | Test |
|------|------|-----------|------|
| JS/TS | ESLint | tsc --noEmit | package.json scripts.test |
| Python | ruff / flake8 | mypy | pytest |
| Go | golangci-lint / go vet | - | go test |
| Rust | cargo clippy | - | cargo test |

## 설치

```bash
claude plugin add jaeyeong94/project-guard
```

## 패키지 매니저 자동 감지

bun > pnpm > yarn > npm 순서로 자동 감지합니다.

## Hook exit code 규칙

| exit code | PreToolUse | PostToolUse |
|-----------|-----------|-------------|
| 0 | 통과 | 통과 |
| 1 | 비차단 | 비차단 |
| **2** | **차단 + stderr → Claude** | **stderr → Claude** |

## 라이선스

MIT
