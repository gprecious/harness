# Harness State: {feature-slug}

## Meta
- feature: {feature_description}
- type: {project_type}
- started: {started_at}
- current_phase: {current_phase}
- iteration: {iteration}/{max_iterations}
- run_dir: {run_dir}

## Phase Status
| Phase | Status | Artifact |
|-------|--------|----------|
| PLAN | {plan_status} | {plan_artifacts} |
| CONTRACT | {contract_status} | {contract_artifacts} |
| TEST | {test_status} | {test_artifacts} |
| BUILD_EVALUATE | {build_status} | {build_artifacts} |
| INTEGRATE | {integrate_status} | {integrate_artifacts} |
| LEARN | {learn_status} | {learn_artifacts} |

## Current Sprint State
- completed_tasks: [{completed_tasks}]
- current_task: {current_task_number} ({current_task_description})
- remaining_tasks: [{remaining_tasks}]

## Last Evaluation
| Criterion | Score | Threshold | Status |
|-----------|-------|-----------|--------|

- score_trend: []
- generator_strategy: refine
- plateau_detected: false
- iteration_type: full
- delta_targets: []

## Key Decisions

## Pending Feedback

## Resume Instructions
1. Read this file + contract.md + evaluations/iteration-{last}.md
2. Continue Phase {current_phase} from task {current_task_number}
3. Address pending feedback items before new work
