#!/bin/bash
# SessionStart hook: 프로젝트 컨텍스트를 감지하여 Claude에게 전달
# exit 0 + stdout → SessionStart에서는 Claude에게 전달됨

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

OUTPUT=""

# ── 1. 스택 감지 ──
STACK=""
PM=""
if [ -f "package.json" ]; then
  STACK="JS/TS"
  [ -f "tsconfig.json" ] && STACK="TypeScript"
  if [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then PM="bun"
  elif [ -f "pnpm-lock.yaml" ]; then PM="pnpm"
  elif [ -f "yarn.lock" ]; then PM="yarn"
  else PM="npm"
  fi
  # 프레임워크 감지
  if [ -f "next.config.js" ] || [ -f "next.config.mjs" ] || [ -f "next.config.ts" ]; then
    STACK="$STACK (Next.js)"
  elif [ -f "nuxt.config.ts" ] || [ -f "nuxt.config.js" ]; then
    STACK="$STACK (Nuxt)"
  elif [ -f "vite.config.ts" ] || [ -f "vite.config.js" ]; then
    STACK="$STACK (Vite)"
  fi
elif [ -f "pyproject.toml" ]; then STACK="Python"
elif [ -f "Cargo.toml" ]; then STACK="Rust"
elif [ -f "go.mod" ]; then STACK="Go"
elif [ -f "build.gradle" ] || [ -f "pom.xml" ]; then STACK="Java/Kotlin"
fi

# ── 2. package.json scripts 감지 (JS/TS) ──
SCRIPTS=""
if [ -f "package.json" ]; then
  SCRIPTS=$(python3 -c "
import json
with open('package.json') as f:
    d = json.load(f)
scripts = d.get('scripts', {})
keys = ['dev', 'build', 'start', 'test', 'lint', 'typecheck', 'type-check', 'check', 'format', 'e2e']
found = {k: v for k, v in scripts.items() if k in keys}
if found:
    print(', '.join(f'{k}: {v}' for k, v in found.items()))
" 2>/dev/null)
fi

# ── 3. 마지막 실패 테스트 감지 ──
FAILED_TEST=""
# 최근 git log에서 test 실패 관련 커밋 확인
LAST_COMMITS=$(git log --oneline -5 2>/dev/null)
if echo "$LAST_COMMITS" | grep -qi 'fix.*test\|test.*fail\|broken.*test'; then
  FAILED_TEST="최근 커밋에 테스트 수정 이력 있음"
fi
# unstaged 변경사항 확인
DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

# ── 4. TODO/FIXME 카운트 ──
TODO_COUNT=0
FIXME_COUNT=0
if command -v rg &>/dev/null; then
  TODO_COUNT=$(rg --no-messages -c "TODO" --glob '!node_modules' --glob '!.git' --glob '!dist' --glob '!build' --glob '!.next' --glob '!target' --glob '!vendor' --glob '!__pycache__' --glob '!*.lock' --glob '!*.min.*' . 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
  FIXME_COUNT=$(rg --no-messages -c "FIXME|HACK|XXX" --glob '!node_modules' --glob '!.git' --glob '!dist' --glob '!build' --glob '!.next' --glob '!target' --glob '!vendor' --glob '!__pycache__' --glob '!*.lock' --glob '!*.min.*' . 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
else
  TODO_COUNT=$(grep -r --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" --include="*.go" --include="*.rs" --include="*.java" -c "TODO" . 2>/dev/null | grep -v node_modules | grep -v '.git' | awk -F: '{s+=$2} END {print s+0}')
  FIXME_COUNT=$(grep -r --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" --include="*.go" --include="*.rs" --include="*.java" -c "FIXME\|HACK\|XXX" . 2>/dev/null | grep -v node_modules | grep -v '.git' | awk -F: '{s+=$2} END {print s+0}')
fi

# ── 5. 검증 워크플로우 설정 확인 ──
HAS_GUARD=false
for f in CLAUDE.md .claude/CLAUDE.md; do
  if [ -f "$f" ] && grep -q '검증 워크플로우\|verification workflow\|Lint:\|Test:' "$f" 2>/dev/null; then
    HAS_GUARD=true
    break
  fi
done

# ── 출력 조합 ──
OUTPUT="[project-guard] 프로젝트 컨텍스트"
OUTPUT="$OUTPUT\n├─ 스택: $STACK"
[ -n "$PM" ] && OUTPUT="$OUTPUT + $PM"
[ -n "$SCRIPTS" ] && OUTPUT="$OUTPUT\n├─ Scripts: $SCRIPTS"
[ "$DIRTY" -gt 0 ] && OUTPUT="$OUTPUT\n├─ 미커밋 변경: ${DIRTY}개 파일"
[ -n "$FAILED_TEST" ] && OUTPUT="$OUTPUT\n├─ ⚠ $FAILED_TEST"
if [ "$TODO_COUNT" -gt 0 ] || [ "$FIXME_COUNT" -gt 0 ]; then
  OUTPUT="$OUTPUT\n├─ TODO: ${TODO_COUNT}개, FIXME/HACK: ${FIXME_COUNT}개"
fi
if $HAS_GUARD; then
  OUTPUT="$OUTPUT\n└─ 검증 워크플로우: 설정됨 ✅"
else
  OUTPUT="$OUTPUT\n└─ 검증 워크플로우: 미설정 ⚠ → /project-guard 실행 권장"
fi

echo -e "$OUTPUT"
exit 0
