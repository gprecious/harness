# fixture-python-complexity

Contains 3 Python functions with deliberately high cognitive complexity (> 15 per SonarQube model). Expected: auditor flags all 3 as Priority 2 clarity issues.

## Convention

The `cognitive_complexity_min` field in `expected-issues.json` is a lower bound — the auditor may compute a higher number. A match within 20% above the minimum is acceptable.
