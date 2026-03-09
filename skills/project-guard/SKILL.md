---
name: project-guard
description: "프로젝트 진입 시 tech stack을 감지하고 검증 워크플로우(lint, test, type-check)를 설정합니다. 새 프로젝트 시작 시 또는 CLAUDE.md에 검증 설정이 없는 프로젝트에서 자동 제안합니다."
---

# Project Guard — 프로젝트별 검증 워크플로우 설정

프로젝트의 기술 스택을 감지하여 적절한 lint, test, type-check 명령을 CLAUDE.md에 설정합니다.

## 실행 조건

- 사용자가 `/project-guard`를 실행했을 때
- SessionStart hook이 "검증 워크플로우 미설정" 알림을 출력했을 때
- 사용자가 "검증 설정", "lint 설정", "테스트 설정" 등을 요청했을 때

## 절차

### Step 1: Tech Stack 감지

프로젝트 루트에서 다음 파일들을 확인:

| 파일 | 스택 |
|---|---|
| `package.json` | JavaScript/TypeScript (Node.js) |
| `tsconfig.json` | TypeScript |
| `pyproject.toml`, `setup.py`, `requirements.txt` | Python |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `build.gradle`, `pom.xml` | Java/Kotlin |
| `Gemfile` | Ruby |

### Step 2: 도구 감지

감지된 스택에 따라 설치된 도구 확인:

**JavaScript/TypeScript:**
- 패키지 매니저: `bun.lockb` → bun, `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, 기본 npm
- Lint: eslint 설정 파일 존재 여부
- Formatter: prettier 설정 여부
- Type-check: `tsconfig.json` 존재 → `tsc --noEmit`
- Test: `package.json`의 `scripts.test` 확인 (vitest, jest, mocha 등)

**Python:**
- Lint: ruff, flake8, pylint 중 설치된 것
- Type-check: mypy, pyright 중 설치된 것
- Test: pytest, unittest
- Formatter: black, ruff format

**Rust:**
- Lint: `cargo clippy`
- Test: `cargo test`
- Format: `cargo fmt`

**Go:**
- Lint: golangci-lint 또는 `go vet`
- Test: `go test ./...`
- Format: `gofmt`

### Step 3: 프로젝트 CLAUDE.md 생성/업데이트

감지 결과를 바탕으로 프로젝트의 `CLAUDE.md` (루트) 또는 `.claude/CLAUDE.md`에 다음 섹션을 추가:

```markdown
# 검증 워크플로우

## 명령어
- Lint: {감지된 lint 명령}
- Type-check: {감지된 type-check 명령}
- Test: {감지된 test 명령}
- Format: {감지된 format 명령}

## 규칙
- 코드 수정 후 lint 에러가 없는지 확인할 것
- 새 함수/모듈 작성 시 테스트도 함께 작성할 것
- 커밋 전에 type-check와 테스트를 통과시킬 것
- 테스트 없이 구현 완료를 주장하지 말 것
```

### Step 4: 사용자에게 보고

감지된 스택과 설정된 명령을 요약하여 보고합니다.
설치되지 않은 권장 도구가 있으면 설치를 제안합니다.

## 출력 예시

```
Project Guard 설정 완료

스택: TypeScript (Next.js) + bun
├─ Lint:       bunx eslint .
├─ Type-check: bunx tsc --noEmit
├─ Test:       bun test
├─ Format:     bunx prettier --write .
└─ CLAUDE.md:  검증 규칙 추가됨

권장: lint-staged + husky가 없습니다. 설치할까요?
```
