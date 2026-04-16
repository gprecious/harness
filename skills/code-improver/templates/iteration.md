---
iteration: {{N}}
started_at: {{ISO_8601_TIMESTAMP}}
completed_at: {{ISO_8601_TIMESTAMP | in_progress}}
status: {{completed | in_progress | plateau}}
harness_version: {{semver}}
---

# Iteration {{N}} — Code Improvement Report

## Summary

- Total issues found: {{X}} (Priority 1-2: {{Y}}, Priority 3-5: {{Z}})
- Auto-fixed: {{Y_fixed}} issues across {{P}} PRs
- Remaining suggestions: {{Z_remaining}} issues

## Metrics (Before / After)

| Metric | Before | After | Δ |
|---|---|---|---|
| Avg cognitive complexity | {{before}} | {{after}} | {{delta}} |
| Dead code lines | {{before}} | {{after}} | {{delta}} |
| Unused imports | {{before}} | {{after}} | {{delta}} |
| Test coverage | {{before}} | {{after}} | {{delta}} |
| Files > 300 lines | {{before}} | {{after}} | {{delta}} |
| SOLID violations | {{before}} | {{after}} | {{delta}} |

## Auto-Fixes Applied (by category → PR)

### Category: {{category-name}} → PR {{#N}}

- Files changed: {{n}} / Lines: +{{added}} / -{{removed}}
- Verification: tests {{✅/❌}} / lint {{✅/❌}} / typecheck {{✅/❌}}
- Specific fixes:
  - {{e.g. Removed 89 unused imports across 34 files}}
  - {{e.g. Removed 12 unused private functions}}
- PR: {{URL | "local-only — gh CLI unavailable"}}

<!-- Repeat per category. If no auto-fixes: replace this section with "No auto-fixes applied this iteration." -->

## Suggestions (Priority 3-5) — Manual Review Required

### {{Category}} (Priority {{3 | 4 | 5}})

1. **{{Principle / smell type}}**: `{{file path}}` {{brief description}}
   - Suggested: {{refactoring action}}
   - Risk: {{low | medium | high}} ({{rationale, e.g. 20+ call sites}})

<!-- Repeat per suggestion -->

## Failure Log

Issues that the applier attempted to auto-fix but had to demote (tests/lint/typecheck failed even after binary-search rollback):

- {{file path}} — demoted to Priority 3 (attempted: {{fix-type}}; reason: {{test failure | lint error | etc.}})

<!-- Empty if no failures -->

## Issues Carried Over from Iteration {{N-1}}

- [RESOLVED] {{issue description}} (fixed in PR {{#N}})
- [STILL PRESENT] {{issue description}}
- [DEFERRED] {{issue description}} (user requested skip)

<!-- Empty for iteration 1 -->

## Plateau Check

- resolved: {{X}}, new: {{Y}}, ratio: {{Y/max(X,1)}}
- Consecutive plateau iterations: {{count}}
- Plateau confirmed: {{yes | no}}

## Next Recommended Action

{{e.g. Run `/improve --verify` after PRs #142-145 merge to measure actual impact.}}
