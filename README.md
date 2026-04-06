# Universal Feature Harness

A TDD Generator-Evaluator harness plugin for Claude Code that automates the full feature development lifecycle. It drives a structured pipeline from planning through integration, using contracts and tests as the source of truth to ensure every feature is built correctly, reviewed thoroughly, and integrated safely.

## Installation

```bash
claude plugin install harness
```

## Usage

```bash
# Initialize harness for a project (profiles tech stack, design system, conventions)
/feature --init

# Run feature development pipeline
/feature "description"

# Resume interrupted feature run
/feature --resume
```

## Pipeline Overview

- **Phase 0** — Plan
- **Phase 1** — Contract
- **Phase 2** — Test
- **Phase 3** — Build
- **Phase 4** — Evaluate
- **Phase 5** — Integrate
- **Phase 6** — Learn

## Required Plugins

- feature-dev
- code-review
- pr-review-toolkit
- security-guidance
- superpowers
