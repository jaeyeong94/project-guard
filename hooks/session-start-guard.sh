#!/bin/bash
# SessionStart hook: 프로젝트 검증 설정 상태를 확인하고 Claude에게 알림
# CLAUDE.md에 검증 워크플로우가 없으면 project-guard 스킬 실행을 제안

CWD="${1:-$(pwd)}"
cd "$CWD" 2>/dev/null || exit 0

# git repo가 아니면 skip
git rev-parse --git-dir &>/dev/null || exit 0

# 프로젝트 루트에 코드 프로젝트 마커가 있는지 확인
HAS_PROJECT=false
for f in package.json Cargo.toml pyproject.toml go.mod build.gradle pom.xml Gemfile; do
  [ -f "$f" ] && HAS_PROJECT=true && break
done
$HAS_PROJECT || exit 0

# CLAUDE.md에 검증 워크플로우 섹션이 있는지 확인
HAS_GUARD=false
for f in CLAUDE.md .claude/CLAUDE.md; do
  if [ -f "$f" ] && grep -q '검증 워크플로우\|verification workflow\|Lint:\|Test:' "$f" 2>/dev/null; then
    HAS_GUARD=true
    break
  fi
done

if ! $HAS_GUARD; then
  # 감지된 스택 정보
  STACK=""
  [ -f "package.json" ] && STACK="JS/TS"
  [ -f "tsconfig.json" ] && STACK="TypeScript"
  [ -f "pyproject.toml" ] && STACK="Python"
  [ -f "Cargo.toml" ] && STACK="Rust"
  [ -f "go.mod" ] && STACK="Go"

  echo "[project-guard] 이 프로젝트($STACK)에 검증 워크플로우가 설정되지 않았습니다. /project-guard 스킬을 실행하여 lint, test, type-check 설정을 권장합니다."
  exit 0
fi

exit 0
