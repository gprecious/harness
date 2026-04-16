# fixture-react-solid

Contains 3 SOLID principle violations. Expected: auditor flags all 3 as Priority 3 suggestions. **Critical**: auditor must NOT auto-fix these even though the code could theoretically be refactored — `auto_fix_expected: false` is the contract.

## Convention

SOLID violations are always Priority 3+ (suggestion-only). The auditor's priority-matrix.md rule is the guard.
