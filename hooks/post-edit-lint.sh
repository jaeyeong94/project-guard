#!/bin/bash
# PostToolUse hook: Edit/Write 후 변경된 파일에 lint 실행
# exit 2 + stderr로 lint 에러를 Claude에게 전달
set -uo pipefail

# stdin에서 JSON 파싱
STDIN_DATA=$(cat)
FILE_PATH=$(echo "$STDIN_DATA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('tool_input', {}).get('file_path', ''))
" 2>/dev/null)

[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

EXT="${FILE_PATH##*.}"

find_root() {
  local dir
  dir=$(dirname "$FILE_PATH")
  while [ "$dir" != "/" ] && [ "$dir" != "." ]; do
    [ -f "$dir/$1" ] && echo "$dir" && return 0
    dir=$(dirname "$dir")
  done
  return 1
}

detect_pm() {
  if [ -f "$1/bun.lockb" ] || [ -f "$1/bun.lock" ]; then echo "bunx"
  elif [ -f "$1/pnpm-lock.yaml" ]; then echo "pnpm exec"
  elif [ -f "$1/yarn.lock" ]; then echo "yarn"
  else echo "npx"
  fi
}

has_eslint() {
  local root="$1"
  for f in .eslintrc .eslintrc.js .eslintrc.json .eslintrc.cjs .eslintrc.yml \
           eslint.config.js eslint.config.mjs eslint.config.ts eslint.config.cjs; do
    [ -f "$root/$f" ] && return 0
  done
  python3 -c "
import json
with open('$root/package.json') as f:
    d = json.load(f)
exit(0 if 'eslintConfig' in d else 1)
" 2>/dev/null && return 0
  return 1
}

# lint 실행 후 에러가 있으면 exit 2 + stderr로 Claude에게 전달
run_and_report() {
  local OUTPUT RC
  OUTPUT=$("$@" 2>&1)
  RC=$?
  if [ $RC -ne 0 ] && [ -n "$OUTPUT" ]; then
    # PostToolUse exit 2 → stderr를 Claude에게 표시
    echo "[post-edit-lint] $OUTPUT" >&2
    exit 2
  fi
  exit 0
}

case "$EXT" in
  ts|tsx|js|jsx|mjs|cjs)
    ROOT=$(find_root "package.json") || exit 0
    cd "$ROOT"
    if has_eslint "$ROOT"; then
      PM=$(detect_pm "$ROOT")
      run_and_report $PM eslint --quiet "$FILE_PATH"
    fi
    ;;
  py)
    if command -v ruff &>/dev/null; then
      run_and_report ruff check --no-fix "$FILE_PATH"
    elif command -v flake8 &>/dev/null; then
      run_and_report flake8 --max-line-length=120 "$FILE_PATH"
    fi
    ;;
  go)
    ROOT=$(find_root "go.mod") || exit 0
    cd "$ROOT"
    if command -v golangci-lint &>/dev/null; then
      run_and_report golangci-lint run --fast "$FILE_PATH"
    else
      run_and_report go vet "$FILE_PATH"
    fi
    ;;
  rs)
    exit 0
    ;;
esac

exit 0
