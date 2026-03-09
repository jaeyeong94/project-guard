# project-guard

A Claude Code plugin that automatically enforces lint, type-check, and test on every code change.

## Install

```bash
# 1. Register the marketplace
claude plugin marketplace add jaeyeong94/project-guard

# 2. Install the plugin
claude plugin install project-guard@project-guard-marketplace
```

## What It Does

### Auto-lint on file changes

When Claude edits or writes a file, the plugin automatically runs lint on that file. If there are errors, they are fed back to Claude for immediate fixing.

### Block commits on failure

When Claude attempts `git commit`, the plugin runs lint, type-check, and test against staged files. If any check fails, the commit is blocked.

### Project context on session start

```
[project-guard] Project Context
├─ Stack: TypeScript (Next.js) + bun
├─ Scripts: dev: next dev, build: next build, test: vitest, lint: eslint .
├─ Uncommitted changes: 5 files
├─ TODO: 12, FIXME/HACK: 3
└─ Verification workflow: configured ✅
```

On session start, the plugin detects the project's stack, package manager, framework, available scripts, uncommitted changes, and TODO/FIXME counts — then passes this context to Claude.

### `/project-guard` skill — per-project setup

Detects the project's tech stack and writes lint, test, and type-check commands into the project's `CLAUDE.md`.

## Supported Stacks

| Stack | Lint | Type-check | Test |
|-------|------|-----------|------|
| JavaScript / TypeScript | ESLint | tsc --noEmit | package.json scripts.test |
| Python | ruff / flake8 | mypy | pytest |
| Go | golangci-lint / go vet | — | go test |
| Rust | cargo clippy | — | cargo test |

Package manager auto-detection order: bun > pnpm > yarn > npm.

## Update

```bash
claude plugin marketplace update project-guard-marketplace
claude plugin update project-guard@project-guard-marketplace
```

## How It Works

The plugin uses Claude Code's hook system with `exit 2 + stderr` to communicate with Claude:

| Hook | Trigger | Action |
|------|---------|--------|
| **PostToolUse** | After Edit/Write | Lint the changed file |
| **PreToolUse** | Before git commit | Run lint + type-check + test on staged files |
| **SessionStart** | Session start | Detect project context and verification status |

## License

MIT
