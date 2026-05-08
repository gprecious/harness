#!/usr/bin/env bash
# scripts/stage-contract.sh — finalize Stage 3 (contract).
#
# Pre-condition: claude orch has dispatched the contract-negotiator agent
# (see references/stage-contract.md), which has written
# .pipeline/runs/<run-id>/contract.md.
#
# This script validates the file exists and updates manifest.json:
#   .stages.contract.status        = "completed"
#   .stages.contract.contract_path = "contract.md"
#
# Usage:
#   stage-contract.sh <run-id>
#
# Env overrides (mainly for tests):
#   PIPELINE_ROOT  Pipeline runs root (default: .pipeline/runs)

set -uo pipefail

RUN_ID="${1:-}"
if [ -z "$RUN_ID" ]; then
  echo "stage-contract: <run-id> required" >&2
  echo "Usage: stage-contract.sh <run-id>" >&2
  exit 1
fi

PIPELINE_ROOT="${PIPELINE_ROOT:-.pipeline/runs}"
RUN_DIR="$PIPELINE_ROOT/$RUN_ID"
CONTRACT="$RUN_DIR/contract.md"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MANIFEST="$SCRIPT_DIR/manifest.sh"

if [ ! -f "$CONTRACT" ]; then
  echo "stage-contract: contract.md not found at $CONTRACT" >&2
  exit 1
fi

if [ ! -s "$CONTRACT" ]; then
  echo "stage-contract: contract.md is empty at $CONTRACT" >&2
  exit 1
fi

"$MANIFEST" update "$RUN_ID" \
  '.stages.contract.status = "completed" | .stages.contract.contract_path = "contract.md"'

echo "stage-contract: marked completed for $RUN_ID"
