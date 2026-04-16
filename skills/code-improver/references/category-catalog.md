---
name: category-catalog
description: The 9 categories of code improvement issues. Auditor agents use this catalog to classify every detected issue.
---

# Category Catalog

This document defines the 9 categories the codebase-auditor uses to classify every detected issue. Each category lists its definition, detection heuristics, concrete patterns (with Priority annotations), and representative examples. Priority levels referenced here (P1-P5) are defined in `priority-matrix.md`.

## 1. Structural Health

**Definition:** Macro-level code organization — module boundaries, dependency direction, file sizes, and layering. Failures here make every downstream category harder to fix.

**Detection Heuristics:**
- Import graph analysis (look for cycles across modules)
- File length in lines-of-code (LOC) combined with cohesion signals (e.g., many unrelated exports in one file)
- Count of distinct imports in a single source file
- Cross-layer imports that violate intended direction (e.g., `domain/` importing from `infrastructure/`)

**Concrete Patterns:**
- Circular module dependencies (P4)
- File > 500 LOC with low cohesion — multiple unrelated responsibilities in one file (P3-4)
- A file importing from 15+ distinct modules — likely a god module or misplaced orchestrator (P3)
- Layering violations — inner layer depends on outer layer (P4)

**Example:**
```ts
// src/domain/user.ts (bad: domain imports infrastructure)
import { db } from "../infrastructure/postgres";
export const loadUser = (id: string) => db.query("...", [id]);
```

## 2. Clarity

**Definition:** Local readability — cognitive complexity, naming, and the use of unexplained literals. Clarity issues slow every reader and amplify defect rates.

**Detection Heuristics:**
- Cognitive-complexity metric per function (cyclomatic + nesting weighting)
- Nesting depth (if/for/try blocks)
- Regex scan for unexplained numeric/string literals in conditionals or arithmetic
- Identifier-length/abbreviation detection

**Concrete Patterns:**
- Cognitive complexity > 15 per function (P2)
- Nesting depth > 3 levels (P2)
- Magic numbers / magic strings embedded in logic (P1)
- Abbreviated or single-letter names outside tight scopes (e.g., `usrMgr`, `x` at module scope) (P1)

**Example:**
```ts
// bad
if (user.age > 17 && user.role === "adm") { grant(); }

// better
const ADULT_AGE = 18;
const ROLE_ADMIN = "adm";
if (user.age >= ADULT_AGE && user.role === ROLE_ADMIN) { grant(); }
```

## 3. SOLID

**Definition:** Object-oriented / module-design principles — Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion. Violations here produce rigidity and fragility that ripple out over time.

**Detection Heuristics:**
- SRP: count distinct reasons-to-change per class/module (e.g., class both parses and persists)
- OCP: new requirement forces editing existing conditional chains instead of adding extensions
- LSP: subclass overrides that throw `NotImplementedError` or weaken postconditions
- ISP: interfaces with many optional/unused methods per client
- DIP: high-level modules directly importing concrete low-level modules

**Concrete Patterns:**
- SRP violation — class mixing persistence + business logic (P3)
- OCP violation — switch statements that grow with every new type (P3)
- LSP violation — subclass that rejects inputs parent accepts (P3)
- ISP violation — fat interface forcing clients to depend on unused methods (P3)
- DIP violation — high-level policy depending on low-level detail (P4)

**Example:**
```ts
// SRP violation
class Invoice {
  calculateTotal() { /* business */ }
  saveToDatabase() { /* persistence */ }
  renderEmailHtml() { /* presentation */ }
}
```

## 4. Code Smells

**Definition:** Fowler-style smells grouped into Bloaters, Couplers, Dispensables, Change Preventers, and OO Abusers. These are surface-level indicators of deeper design debt.

**Detection Heuristics:**
- Method length, parameter count, class size (Bloaters)
- Call-chain depth and cross-class coupling (Couplers)
- Duplicate-block AST hashing, reachability analysis (Dispensables)
- File-commit correlation over history (Change Preventers)
- Type-discriminant `switch`/`if` chains on classes (OO Abusers)

**Concrete Patterns:**

Bloaters:
- Long method (> 50 LOC) (P2)
- Large class (> 300 LOC, many fields) (P3)
- Long parameter list (> 4 params) (P2)
- Primitive obsession — strings/ints carrying domain meaning (P2)
- Data clumps — the same 3+ params appearing together repeatedly (P2)

Couplers:
- Feature envy — method uses another object's data more than its own (P3)
- Inappropriate intimacy — two classes accessing each other's internals (P3)
- Message chains — `a.b().c().d().e()` (P2)
- Middle man — class that only delegates (P2)

Dispensables:
- Duplicate code (P2-3 depending on volume)
- Dead code (P1, see category 5)
- Lazy class — class doing too little to justify itself (P3)
- Speculative generality — abstractions without current callers (P3)
- Data class — class with only getters/setters and no behavior where behavior belongs (P3)

Change Preventers:
- Divergent change — one class changes for many reasons (P4)
- Shotgun surgery — one change touches many classes (P4)
- Parallel inheritance — adding a subclass in one tree forces a matching subclass elsewhere (P4)

OO Abusers:
- Switch on type — `if (x instanceof ...)` chains instead of polymorphism (P3)
- Refused bequest — subclass ignoring most of its parent (P3)
- Temporary field — field only used under some conditions (P2)

**Example:**
```ts
// feature envy
class Order {
  formatAddress(customer: Customer) {
    return `${customer.street}, ${customer.city}, ${customer.zip}`;
  }
}
// better: move formatAddress onto Customer
```

## 5. Dead Code

**Definition:** Code that is never executed, imported, or referenced in a way that contributes to runtime behavior or tests.

**Detection Heuristics:**
- Static import/usage graph (unused imports, unused variables)
- Exported symbols with no in-project consumers (see fixture heuristic note in `priority-matrix.md`)
- Unreachable code after `return`/`throw`
- Long-commented blocks (multi-line comments containing code-like tokens)
- Feature flags referenced but always evaluating to the same constant

**Concrete Patterns:**
- Unused imports (P1)
- Unused local variables / parameters (P1)
- Unused private functions / methods (P1)
- Exports with no in-project consumers and no public-API marker (P1-2)
- Unreachable statements (P1)
- Commented-out code blocks > 5 lines (P1)
- Stale feature flags — always-true or always-false in config (P2)

**Example:**
```ts
// bad
import { legacyHelper } from "./legacy"; // never called
function compute(x: number) {
  return x * 2;
  console.log("unreachable");
}
```

## 6. Error Handling

**Definition:** Correctness of failure modes — how the code handles exceptions, I/O errors, untrusted input, type coercion, and secrets exposure.

**Detection Heuristics:**
- AST scan for `catch` blocks with empty bodies or re-throws that discard context
- I/O calls (file, network, DB) missing error paths
- Unchecked type coercions (`as any`, `@ts-ignore`, `# type: ignore`)
- External-input entry points (HTTP handlers, CLI args, env vars) without validation
- Regex scan for committed secrets (AWS keys, GitHub tokens, `.env*` leakage)

**Concrete Patterns:**
- Empty catch block (P3)
- Swallowed exception — `catch` that logs and continues without recovery (P2-3)
- Missing I/O error path — `fs.readFile` without error handling (P2)
- Unsafe type coercion — `as any`, unchecked `JSON.parse` (P2)
- Unvalidated external input reaching business logic (P3)
- Hardcoded secrets or tokens in source (P2 — flag, never auto-fix)

**Example:**
```ts
// bad
try { await writeFile(path, data); } catch (e) {}

// better
try { await writeFile(path, data); }
catch (e) { logger.error({ path, err: e }, "write failed"); throw e; }
```

## 7. Testing

**Definition:** Test health — coverage of important behavior, stability under reruns, and whether tests assert on behavior vs. implementation detail.

**Detection Heuristics:**
- Per-file or per-module coverage reports
- Regex for `sleep`, `setTimeout`, `Thread.sleep`, unordered assertions
- Tests asserting on private fields, internal call counts, or snapshot of implementation details
- Missing edge-case branches vs. observed happy-path-only asserts

**Concrete Patterns:**
- Coverage gap — critical module < 60% line coverage (P3)
- Flaky pattern — reliance on `sleep`/real time/external ordering (P3)
- Implementation-testing — mocking internal methods of the unit under test (P3)
- Missing edge cases — no tests for null, empty, boundary, or error inputs (P3)

**Example:**
```ts
// flaky
await new Promise(r => setTimeout(r, 500));
expect(queue.length).toBe(0);

// better: await the promise returned by the operation, assert directly
await worker.drain();
expect(queue.length).toBe(0);
```

## 8. Performance

**Definition:** Runtime efficiency — avoiding unnecessary work, redundant rendering, unbounded growth, and leaked resources.

**Detection Heuristics:**
- Query patterns inside loops (N+1)
- React component re-render analysis (missing `memo`/`useMemo`/`useCallback`)
- Sync I/O inside async code paths
- Unbounded collection growth (caches without eviction, arrays pushed to without cleanup)
- Open handles (files, sockets, timers) without matching close/clear

**Concrete Patterns:**
- N+1 query pattern (P3-4)
- Unnecessary re-renders — expensive component re-renders on unrelated state change (P3)
- Missing memoization on hot path (P3)
- Blocking call inside async function — e.g., `fs.readFileSync` inside async handler (P3)
- Unbounded data structure — cache/map/array without size limit or TTL (P3-4)
- Missing resource cleanup — `setInterval` without `clearInterval`, open streams without close (P3)

**Example:**
```ts
// N+1
for (const id of userIds) {
  const u = await db.query("SELECT * FROM users WHERE id = $1", [id]);
}

// better
const users = await db.query("SELECT * FROM users WHERE id = ANY($1)", [userIds]);
```

## 9. Documentation

**Definition:** External-facing documentation — public-API docs, top-level README, type annotations, and Architecture Decision Records.

**Detection Heuristics:**
- Public exports missing JSDoc/docstring/type annotations
- README last-modified date vs. recent major refactors
- Missing ADR for decisions that appear contentious in git history (many reverts, many discussions)
- Public types using `any` / untyped parameters

**Concrete Patterns:**
- Missing public-API docs — exported function without docstring (P3-4)
- Stale README — instructions that no longer match the code (P4)
- Missing type annotations on public function signatures (P3)
- Missing ADR for significant architectural decisions (P5)

**Example:**
```ts
// bad: exported without docs or precise types
export function parseConfig(input: any): any { /* ... */ }

// better
/**
 * Parse a raw config blob into a validated Config object.
 * Throws ConfigValidationError on invalid input.
 */
export function parseConfig(input: unknown): Config { /* ... */ }
```

## Auditor Instructions

When auditing, scan each category independently. For each detected issue, record: file path, line range, category, Priority level (use priority-matrix.md), and a one-line description. Emit output matching the audit-report template.
