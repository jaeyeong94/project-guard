#!/bin/bash
# PreToolUse hook: git commit 전에 lint + test 실행
# Bash 도구의 command에 "git commit"이 포함된 경우에만 동작
set -uo pipefail

# stdin에서 JSON 파싱
INPUT=$(cat)
TOOL_INPUT_COMMAND=$(echo "$INPUT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('tool_input', {}).get('command', ''))
" 2>/dev/null)

# git commit 명령이 아니면 즉시 통과
echo "$TOOL_INPUT_COMMAND" | grep -qE '^\s*git\s+commit' || exit 0

CWD=$(echo "$INPUT" | python3 -c "
import json, sys, os
data = json.load(sys.stdin)
print(data.get('cwd', os.getcwd()))
" 2>/dev/null)
cd "$CWD" 2>/dev/null || exit 0

# 프로젝트 타입 감지 및 검증 실행
FAILED=0

detect_pm() {
  if [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then echo "bun"
  elif [ -f "pnpm-lock.yaml" ]; then echo "pnpm"
  elif [ -f "yarn.lock" ]; then echo "yarn"
  else echo "npm"
  fi
}

# exit code를 보존하며 실행
run_check() {
  local OUTPUT RC
  OUTPUT=$("$@" 2>&1)
  RC=$?
  [ -n "$OUTPUT" ] && echo "$OUTPUT" | tail -40
  return $RC
}

# ─── JavaScript/TypeScript ───
if [ -f "package.json" ]; then
  PM=$(detect_pm)

  # Lint (staged files)
  HAS_ESLINT=false
  for f in .eslintrc .eslintrc.js .eslintrc.json .eslintrc.cjs .eslintrc.yml \
           eslint.config.js eslint.config.mjs eslint.config.ts eslint.config.cjs; do
    [ -f "$f" ] && HAS_ESLINT=true && break
  done

  if $HAS_ESLINT; then
    STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$' || true)
    if [ -n "$STAGED_FILES" ]; then
      echo "[pre-commit] ESLint 검사 중..."
      if [ "$PM" = "bun" ]; then
        run_check bunx eslint --quiet $STAGED_FILES || FAILED=1
      else
        run_check npx eslint --quiet $STAGED_FILES || FAILED=1
      fi
    fi
  fi

  # TypeScript type-check
  if [ -f "tsconfig.json" ]; then
    echo "[pre-commit] TypeScript 타입 체크 중..."
    if [ "$PM" = "bun" ]; then
      run_check bunx tsc --noEmit || FAILED=1
    else
      run_check npx tsc --noEmit || FAILED=1
    fi
  fi

  # Test (package.json에 test 스크립트가 있을 때만)
  HAS_TEST=$(python3 -c "
import json
with open('package.json') as f:
    d = json.load(f)
s = d.get('scripts', {}).get('test', '')
print('yes' if s and 'no test' not in s.lower() else 'no')
" 2>/dev/null)

  if [ "$HAS_TEST" = "yes" ]; then
    echo "[pre-commit] 테스트 실행 중..."
    run_check $PM test || FAILED=1
  fi

# ─── Python ───
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
  # Lint
  if command -v ruff &>/dev/null; then
    STAGED_PY=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.py$' || true)
    if [ -n "$STAGED_PY" ]; then
      echo "[pre-commit] Ruff 검사 중..."
      run_check ruff check $STAGED_PY || FAILED=1
    fi
  fi

  # Type check
  if command -v mypy &>/dev/null; then
    echo "[pre-commit] mypy 타입 체크 중..."
    run_check mypy --ignore-missing-imports . || FAILED=1
  fi

  # Test
  if command -v pytest &>/dev/null; then
    echo "[pre-commit] pytest 실행 중..."
    run_check pytest --tb=short -q || FAILED=1
  fi

# ─── Rust ───
elif [ -f "Cargo.toml" ]; then
  echo "[pre-commit] cargo clippy 검사 중..."
  run_check cargo clippy --quiet -- -D warnings || FAILED=1

  echo "[pre-commit] cargo test 실행 중..."
  run_check cargo test --quiet || FAILED=1

# ─── Go ───
elif [ -f "go.mod" ]; then
  echo "[pre-commit] go vet 검사 중..."
  run_check go vet ./... || FAILED=1

  echo "[pre-commit] go test 실행 중..."
  run_check go test ./... || FAILED=1
fi

if [ $FAILED -ne 0 ]; then
  # PreToolUse에서 exit 2 + stderr = 도구 실행 차단 + stderr를 Claude에게 전달
  echo "❌ [pre-commit] 검증 실패. lint/type/test 에러를 수정한 후 다시 커밋하세요." >&2
  exit 2
fi

echo "✅ [pre-commit] 모든 검증 통과."
exit 0
