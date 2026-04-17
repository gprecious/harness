---
type: project-reference
category: anti-patterns
generated_at: {{ISO_8601_TIMESTAMP}}
research_cutoff: {{YYYY-MM-DD}}
---

# Anti-Patterns for This Project

Things that should NEVER appear in this project. If the auditor finds any, they are automatically escalated (at minimum Priority 2; some are Priority 1 for immediate auto-fix where safe).

## Language-Specific Anti-Patterns

{{items with severity annotation}}

## Framework-Specific Anti-Patterns

{{items}}

## Project-Specific Anti-Patterns

Extracted from CLAUDE.md, ADRs, or code review history:

{{items}}

## Security-Critical Anti-Patterns

- Hardcoded secrets, API keys, tokens → Priority 1 (but NEVER auto-remove; flag only — user must rotate)
- Unvalidated user input flowing to SQL/shell/eval → Priority 2 (suggest parametrization)
- Disabled CSRF / auth middleware in production paths → Priority 2

## Dependency Anti-Patterns

- {{deprecated package name}} → replace with {{modern alternative}}
- {{vulnerable version range}} → upgrade to {{safe version}}

## Detection Hints

For each anti-pattern, the auditor should:
1. Document the detection regex / AST query (where possible)
2. Link to the research source for ongoing verification
