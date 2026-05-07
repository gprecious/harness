#!/usr/bin/env bash
# preflight.sh — verify cmux-pipeline external dependencies before /build
#
# Usage:
#   preflight.sh                  # full check (binaries + git repo + plugins)
#   preflight.sh --dry-run        # full check, prints "OK (dry-run)" instead of "OK"
#   preflight.sh --no-plugin-check  # skip plugin half (CI / testing)
#   preflight.sh --help           # print usage and exit 0
#
# Exits 0 if all required dependencies are present, 1 otherwise.
# Missing-dep details + install hints are written to stderr.
#
# Plugin paths follow the corrected install layout (Phase 0 Task 3):
#   - gstack:       ~/.claude/skills/office-hours/SKILL.md (flatten symlink)
#                   AND ~/.claude/skills/gstack/bin/gstack-slug (slug helper)
#   - gsd:          ~/.claude/skills/gsd-plan-phase/SKILL.md
#                   AND ~/.claude/agents/gsd-planner.md (sibling agents/ tree)
#                   AND ~/.claude/get-shit-done/workflows/plan-phase.md
#   - build-loop:   ~/.claude plugin list grep build-loop
#   - superpowers:  ~/.claude plugin list grep superpowers
#   - ralph-loop:   ~/.claude plugin list grep ralph-loop
#
# We collect ALL missing deps before exiting (no `set -e`), so the user gets
# a complete checklist on first run instead of fix-one-rerun whack-a-mole.

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: preflight.sh [--dry-run] [--no-plugin-check] [--help]

Verifies cmux-pipeline external dependencies are installed.

Options:
  --dry-run            Run all checks but print "OK (dry-run)" on success.
  --no-plugin-check    Skip the claude plugin / install-path half.
                       Useful in CI where plugins aren't installed but you
                       still want to verify binaries.
  --help               Show this help and exit 0.

Exit codes:
  0  All required dependencies present.
  1  One or more dependencies missing (details on stderr).
USAGE
}

DRY_RUN=0
NO_PLUGIN_CHECK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)         DRY_RUN=1 ;;
    --no-plugin-check) NO_PLUGIN_CHECK=1 ;;
    --help|-h)         usage; exit 0 ;;
    *)
      echo "preflight: unknown flag: $1" >&2
      echo "" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

missing=()

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    missing+=("$1")
  fi
}

require_bin cmux
require_bin codex
require_bin jq
require_bin git
require_bin gh

# Git repo check — only meaningful if `git` itself is on PATH; otherwise the
# binary-missing report above already covers it.
if command -v git >/dev/null 2>&1; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    missing+=("(not a git repo)")
  fi
fi

if [ "$NO_PLUGIN_CHECK" -eq 0 ]; then
  # gstack: flatten symlink + slug helper binary
  if [ ! -f "$HOME/.claude/skills/office-hours/SKILL.md" ] \
      || [ ! -x "$HOME/.claude/skills/gstack/bin/gstack-slug" ]; then
    missing+=("plugin:gstack")
  fi

  # gsd: skill entry + sibling agents/ tree + workflow
  if [ ! -f "$HOME/.claude/skills/gsd-plan-phase/SKILL.md" ] \
      || [ ! -f "$HOME/.claude/agents/gsd-planner.md" ] \
      || [ ! -f "$HOME/.claude/get-shit-done/workflows/plan-phase.md" ]; then
    missing+=("plugin:gsd")
  fi

  # claude-managed plugins: build-loop / superpowers / ralph-loop.
  # Prefer `claude plugin list`; fall back to "skip" if claude CLI absent
  # (treat as missing so user gets actionable install hint).
  if command -v claude >/dev/null 2>&1; then
    plugin_list=$(claude plugin list 2>/dev/null || true)
    for p in build-loop superpowers ralph-loop; do
      # `claude plugin list` formats lines as "  ❯ <name>@<source>"
      # We match the plugin name following the chevron+space.
      if ! printf '%s\n' "$plugin_list" | grep -qE "❯[[:space:]]+${p}[@[:space:]]"; then
        missing+=("plugin:${p}")
      fi
    done
  else
    # No claude CLI → can't verify managed plugins
    missing+=("plugin:build-loop" "plugin:superpowers" "plugin:ralph-loop")
  fi
fi

if [ ${#missing[@]} -gt 0 ]; then
  echo "preflight: missing dependencies:" >&2
  printf "  - %s\n" "${missing[@]}" >&2
  echo "" >&2
  echo "Install instructions:" >&2
  for m in "${missing[@]}"; do
    case "$m" in
      cmux)               echo "  cmux:        download from https://cmux.app" >&2 ;;
      codex)              echo "  codex:       npm install -g @openai/codex-cli" >&2 ;;
      jq)                 echo "  jq:          brew install jq" >&2 ;;
      git)                echo "  git:         brew install git  (or use system git)" >&2 ;;
      gh)                 echo "  gh:          brew install gh" >&2 ;;
      "(not a git repo)") echo "  git repo:    cd into a git working tree (or run 'git init')" >&2 ;;
      "plugin:gstack")
        echo "  gstack:      git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack \\" >&2
        echo "               && (cd ~/.claude/skills/gstack && ./setup --no-prefix)" >&2
        ;;
      "plugin:gsd")
        echo "  gsd:         npx -y get-shit-done-cc@latest --global --claude" >&2
        ;;
      "plugin:build-loop")
        echo "  build-loop:  claude plugin marketplace add tyroneross/build-loop \\" >&2
        echo "               && claude plugin install build-loop@build-loop" >&2
        ;;
      "plugin:superpowers")
        echo "  superpowers: claude plugin install superpowers@claude-plugins-official" >&2
        ;;
      "plugin:ralph-loop")
        echo "  ralph-loop:  claude plugin install ralph-loop@claude-plugins-official" >&2
        ;;
    esac
  done
  echo "" >&2
  echo "preflight: FAILED" >&2
  exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "preflight: OK (dry-run)"
else
  echo "preflight: OK"
fi
exit 0
