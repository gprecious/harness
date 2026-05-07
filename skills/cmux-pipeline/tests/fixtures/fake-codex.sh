#!/usr/bin/env bash
# tests/fixtures/fake-codex.sh — test stub for codex CLI
#
# Usage:
#   SCENARIO=<success|fail|needs_help|timeout|interactive> \
#   RUN_ID=<id> PHASE_ID=<id> bash fake-codex.sh
#
# Used by integration / e2e tests to simulate codex worker behavior
# without requiring an actual codex installation or interactive TTY.

set -uo pipefail

SCENARIO="${SCENARIO:-success}"
RUN_ID="${RUN_ID:-test}"
PHASE_ID="${PHASE_ID:-0001}"

case "$SCENARIO" in
  success)
    echo "fake-codex: doing work…"
    sleep 1
    echo "==DONE==${RUN_ID}==phase-${PHASE_ID}==SUCCESS=="
    ;;
  fail)
    echo "fake-codex: encountered error"
    sleep 1
    echo "==DONE==${RUN_ID}==phase-${PHASE_ID}==FAILED=="
    ;;
  needs_help)
    echo "fake-codex: ambiguous spec"
    sleep 1
    echo "==DONE==${RUN_ID}==phase-${PHASE_ID}==NEEDS_HELP=="
    ;;
  timeout)
    echo "fake-codex: hanging…"
    sleep 3600
    ;;
  interactive)
    # Mimic interactive codex — read stdin and respond
    while IFS= read -r line; do
      case "$line" in
        /compact)
          echo "fake-codex: context compacted"
          ;;
        /quit|/exit)
          exit 0
          ;;
        *)
          echo "fake-codex echo: $line"
          echo "==DONE==${RUN_ID}==phase-${PHASE_ID}==SUCCESS=="
          ;;
      esac
    done
    ;;
  *)
    echo "fake-codex: unknown SCENARIO: $SCENARIO" >&2
    exit 1
    ;;
esac
