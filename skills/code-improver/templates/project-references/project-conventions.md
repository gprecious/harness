---
type: project-reference
category: project-conventions
generated_at: {{ISO_8601_TIMESTAMP}}
extraction_source: "codebase analysis + git history"
---

# Project Conventions

Extracted from the existing codebase by `/improve --init` analysis. The auditor respects these conventions when classifying issues — violations of existing conventions are higher priority than violations of generic best practices.

## Naming

- Files: {{e.g. kebab-case.ts | PascalCase.tsx | snake_case.py}}
- Functions: {{e.g. camelCase | snake_case}}
- Classes / Types: {{e.g. PascalCase}}
- Constants: {{e.g. SCREAMING_SNAKE_CASE | camelCase}}
- Variables: {{e.g. camelCase}}

## Folder Structure

{{observed top-level folders and their purpose}}

## Import Order Convention

{{e.g. external → internal → relative; or alphabetical; or enforced by eslint-plugin-import}}

## Commit Message Convention

Detected: `{{e.g. type(scope): subject}}` from {{sample size}} recent commits.

Examples:
- `{{example 1}}`
- `{{example 2}}`

## Test Organization

- Location: {{e.g. co-located *.test.ts | separate tests/ directory}}
- Naming: {{e.g. *.test.ts | *.spec.ts | test_*.py}}
- Framework: {{e.g. vitest | jest | pytest}}

## Existing Code Style Rules (from config)

{{parsed from .eslintrc, pyproject.toml [tool.*], .prettierrc, etc.}}
