---
description: Iterative codebase improvement. Use `/improve --init` first.
argument-hint: "[--init [--refresh] | --audit | --apply | --verify | --resume | --category <name> | nothing for full flow]"
---

Invoke the `code-improver` skill with the arguments: $ARGUMENTS.

The skill will:
1. Check state (and gate on `--init` if not yet initialized)
2. Route to the appropriate mode based on the parsed arguments
3. Orchestrate the 4-phase workflow (or init/audit/verify-only as requested)

If no arguments provided, run the full workflow (audit → prioritize → apply → verify).
