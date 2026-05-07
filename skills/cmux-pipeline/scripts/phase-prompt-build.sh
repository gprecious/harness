#!/usr/bin/env bash
# scripts/phase-prompt-build.sh — synthesize a codex worker prompt for a phase
# by combining the phase's PLAN file(s) with templates/codex-prompt.md.tmpl.
#
# Usage:
#   phase-prompt-build.sh <run-id> <phase-id>
#
# Reads:
#   .pipeline/runs/<run-id>/manifest.json (topic, git.feature_branch)
#   .pipeline/runs/<run-id>/decompose/phases/<phase-id>/*-PLAN.md (1+ files)
#   .pipeline/runs/<run-id>/decompose/phases/<phase-id>/*-CONTEXT.md (optional)
#   .pipeline/runs/<run-id>/decompose/phases/<phase-id>/*-RESEARCH.md (optional)
#   templates/codex-prompt.md.tmpl
# Writes:
#   .pipeline/runs/<run-id>/phases/<phase-id>/prompt.md
# Prints output path on stdout.
#
# Env overrides:
#   PIPELINE_ROOT  Pipeline runs root (default: .pipeline/runs)

set -uo pipefail

RUN_ID="${1:-}"
PHASE_ID="${2:-}"

if [ -z "$RUN_ID" ]; then
  echo "phase-prompt-build: <run-id> required" >&2
  echo "Usage: phase-prompt-build.sh <run-id> <phase-id>" >&2
  exit 1
fi
if [ -z "$PHASE_ID" ]; then
  echo "phase-prompt-build: <phase-id> required" >&2
  echo "Usage: phase-prompt-build.sh <run-id> <phase-id>" >&2
  exit 1
fi

PIPELINE_ROOT="${PIPELINE_ROOT:-.pipeline/runs}"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TMPL="$SCRIPT_DIR/../templates/codex-prompt.md.tmpl"
PHASE_SRC="$PIPELINE_ROOT/$RUN_ID/decompose/phases/$PHASE_ID"
OUT_DIR="$PIPELINE_ROOT/$RUN_ID/phases/$PHASE_ID"
OUT="$OUT_DIR/prompt.md"
MANIFEST="$SCRIPT_DIR/manifest.sh"

if [ ! -d "$PHASE_SRC" ]; then
  echo "phase-prompt-build: phase dir not found: $PHASE_SRC" >&2
  exit 1
fi
if [ ! -f "$TMPL" ]; then
  echo "phase-prompt-build: template not found: $TMPL" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

# --- Manifest fields ---------------------------------------------------------
TOPIC=$("$MANIFEST" read "$RUN_ID" .topic)
FEATURE_BRANCH=$("$MANIFEST" read "$RUN_ID" '.git.feature_branch // empty')
[ -z "$FEATURE_BRANCH" ] || [ "$FEATURE_BRANCH" = "null" ] && FEATURE_BRANCH="feat/${TOPIC}"

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# --- Locate PLAN files (sorted) ---------------------------------------------
PLAN_FILES=()
while IFS= read -r f; do
  PLAN_FILES+=("$f")
done < <(find "$PHASE_SRC" -maxdepth 1 -type f -name "*-PLAN.md" 2>/dev/null | sort)

if [ "${#PLAN_FILES[@]}" -eq 0 ]; then
  echo "phase-prompt-build: no *-PLAN.md files in $PHASE_SRC" >&2
  exit 1
fi

FIRST_PLAN="${PLAN_FILES[0]}"

# --- Phase title (first heading of first PLAN, stripped) --------------------
PHASE_TITLE=$(head -1 "$FIRST_PLAN" | sed -E 's/^#+ *//; s/^[0-9]+ *//; s/ *PLAN *$//')
[ -z "$PHASE_TITLE" ] && PHASE_TITLE="$PHASE_ID"

# --- Phase goal (## Goal section of first PLAN) -----------------------------
# Extract lines after "## Goal" up to (but not including) the next "## " heading.
PHASE_GOAL=$(awk '
  /^## *Goal/ { in_goal=1; next }
  in_goal && /^## / { in_goal=0 }
  in_goal { print }
' "$FIRST_PLAN" | sed -E '/^[[:space:]]*$/d' | head -20)
[ -z "$PHASE_GOAL" ] && PHASE_GOAL="See PLAN body below"

# --- Substitute placeholders (multi-line safe) ------------------------------
# Strategy: feed all values to awk via env vars; awk does literal gsub per line.
# This avoids sed pain with newlines in PHASE_GOAL.
export PHASE_ID PHASE_TITLE PHASE_GOAL RUN_ID REPO_ROOT FEATURE_BRANCH TOPIC
export ALLOW_FILES="<see PLAN body>"
export DENY_FILES="<phases already completed>"
export PRIOR_OUTPUTS="<git log --oneline ${FEATURE_BRANCH}>"
export TEST_COMMAND="<repo test cmd>"
export TYPECHECK_COMMAND="<repo typecheck cmd>"
export LINT_COMMAND="<repo lint cmd>"
export INTERFACE_CONTRACT="<see PLAN body>"
export TEST_PATHS="<see PLAN body>"

awk '
  function repl(s, key, val,    out, i, n) {
    out=""
    while ((i = index(s, key)) > 0) {
      out = out substr(s, 1, i-1) val
      s = substr(s, i + length(key))
    }
    return out s
  }
  {
    line = $0
    line = repl(line, "{{PHASE_ID}}",          ENVIRON["PHASE_ID"])
    line = repl(line, "{{PHASE_TITLE}}",       ENVIRON["PHASE_TITLE"])
    line = repl(line, "{{PHASE_GOAL}}",        ENVIRON["PHASE_GOAL"])
    line = repl(line, "{{ALLOW_FILES}}",       ENVIRON["ALLOW_FILES"])
    line = repl(line, "{{DENY_FILES}}",        ENVIRON["DENY_FILES"])
    line = repl(line, "{{RUN_ID}}",            ENVIRON["RUN_ID"])
    line = repl(line, "{{REPO_ROOT}}",         ENVIRON["REPO_ROOT"])
    line = repl(line, "{{FEATURE_BRANCH}}",    ENVIRON["FEATURE_BRANCH"])
    line = repl(line, "{{PRIOR_OUTPUTS}}",     ENVIRON["PRIOR_OUTPUTS"])
    line = repl(line, "{{TEST_COMMAND}}",      ENVIRON["TEST_COMMAND"])
    line = repl(line, "{{TYPECHECK_COMMAND}}", ENVIRON["TYPECHECK_COMMAND"])
    line = repl(line, "{{LINT_COMMAND}}",      ENVIRON["LINT_COMMAND"])
    line = repl(line, "{{INTERFACE_CONTRACT}}",ENVIRON["INTERFACE_CONTRACT"])
    line = repl(line, "{{TEST_PATHS}}",        ENVIRON["TEST_PATHS"])
    line = repl(line, "{{TOPIC}}",             ENVIRON["TOPIC"])
    print line
  }
' "$TMPL" > "$OUT.tmp"

# --- Append PLAN(s) + CONTEXT/RESEARCH as appendix --------------------------
{
  cat "$OUT.tmp"
  echo ""
  echo "---"
  echo ""
  echo "## Original GSD Plan"
  echo ""
  for f in "${PLAN_FILES[@]}"; do
    echo "### $(basename "$f")"
    echo ""
    cat "$f"
    echo ""
  done
  for c in "$PHASE_SRC"/*-CONTEXT.md; do
    [ -f "$c" ] || continue
    echo "## Context — $(basename "$c")"
    echo ""
    cat "$c"
    echo ""
  done
  for r in "$PHASE_SRC"/*-RESEARCH.md; do
    [ -f "$r" ] || continue
    echo "## Research — $(basename "$r")"
    echo ""
    cat "$r"
    echo ""
  done
} > "$OUT"

rm -f "$OUT.tmp"

echo "$OUT"
