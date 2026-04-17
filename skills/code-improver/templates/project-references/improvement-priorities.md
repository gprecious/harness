---
type: project-reference
category: improvement-priorities
generated_at: {{ISO_8601_TIMESTAMP}}
derived_from: [language-guide.md, framework-guide.md, codebase analysis]
---

# Improvement Priorities for This Project

Based on project type, the auditor should weight these categories more heavily:

## High-Impact Categories for This Project

{{ordered list of 3-5 categories from the 9-catalog, with rationale}}

Example for a React/TypeScript project:
1. Performance — missing memoization, unnecessary re-renders, prop drilling
2. Structural Health — component composition, hook extraction
3. Clarity — cognitive complexity in event handlers and reducers

Example for a Python/FastAPI project:
1. Error Handling — unvalidated request input, exposed stacktraces
2. Testing — endpoint contract coverage
3. Performance — N+1 ORM queries

## Category-Specific Weight Multipliers

Multipliers adjust how issue counts contribute to the project-health score:

| Category | Multiplier | Rationale |
|---|---|---|
| {{category}} | {{1.0 / 1.5 / 2.0}} | {{e.g. React project: performance issues directly impact UX}} |

## Deprioritized Categories

Categories that the auditor should still report but not treat as urgent for this project type:

{{1-3 categories with rationale}}
