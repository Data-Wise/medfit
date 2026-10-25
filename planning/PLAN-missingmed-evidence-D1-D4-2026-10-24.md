# Plan: integrate missingmed's T5 evidence work (D1-D4) into medfit

Status: draft, 2026-10-24. Starts after 0.14.0 ships (release PR #333). Owner: the medfit session (the author's
decision, relayed by the missingmed session). Target release: 0.15.0 or a 0.14.x minor, decided at Checkpoint 1.

## Why

missingmed's D5 (adapter integration) and its PR #102 are blocked until a medfit release carries the D1-D4 evidence
contract: a ledger of native SEM branch and null outcomes that typed errors keep, literal zero/nonzero certificates,
branch maps with raw counts, and covariance-stage likelihood evidence. Contract source:
missingmed `docs/specs/PROPOSAL-T5-medfit-evidence-contract-2026-10-22.md`.

## Where the work is

Local, unpushed branches in this checkout (created by the missingmed session so the commits are kept):

- `keep/d4-3a98bf6`: the whole chain, 12 commits from 0.12.0 (`505e8ed`).
- `keep/d3-pin-cba4c1a`: the D3 pin missingmed's receipts name.

| Slice | Commits | R/ files | Tests | Receipt |
|---|---|---|---|---|
| D1 outcome ledger | 06b2ca9, 9abca87, 3435a39, c8194aa, 96cf7ff, 8d7d6c1 | new `sem-outcomes.R`; `classes.R`, `fit-sem.R`, `sem-fit.R`, `sem-mbco.R`, `sem-syntax-help.R` | `test-sem-outcomes.R` (new, about 390 lines) | NOTE-D1 |
| D2 literal certificates | d9ace70, a11c63b | `sem-outcomes.R`, `fit-sem.R`, `sem-fit.R`, `sem-mbco.R` | `test-sem-literal-certificates.R` (new) | NOTE-D2 |
| D3 branch map, raw cap | 08e2dc2, cba4c1a | `sem-outcomes.R`, `fit-sem.R`, `sem-fit.R` | `test-sem-branch-map.R` (new) | NOTE-D3 |
| D4 covariance-stage evidence | f31e12e, 3a98bf6 | `sem-outcomes.R`, `fit-sem.R`, `sem-fit.R`, `sem-mbco.R`, `sem-se.R` | `test-sem-post-fit.R` (new) | NOTE-D4 |

## What changed on dev since 0.12.0 in the same files

Six of the seven R/ files changed on `dev` (116 insertions, 28 deletions; `sem-outcomes.R` does not exist on
`dev`). The ones that matter are semantic, not textual:

- **#300** (0.13.0): status -4 restoration cap; a refit the optimizer cannot fit is an *unresolved* result in
  `mbco_sem()` and `compare_lr()`.
- **#303** (0.13.0, ADR D-11): a zero-product branch that cannot be fitted while another succeeds stops `fit_sem()`
  with `medfit_error_no_convergence`; no partial fit.
- **#321, #323, #325** (0.14.0): pinned-SE fix; internal refits pass `fixed_x` and `meanstructure`; the default
  resolver.

D1 was written against 0.12.0, before #300 and #303. Its "any unresolved required branch prevents ordinary
inference; typed errors keep the ledger" overlaps both. The rebase is a reconciliation of two designs for the same
failure, not a conflict-resolution exercise.

## Approach: one PR per D step, re-derived on current dev

Not one large rebase. Each slice is a feature worktree from `dev`, implemented test-first through the
medfit-orchestrator pipeline (implementer, oracle QA, gates, docs), and its own PR to `dev`. Every slice touches risk
files, so each PR carries the seven-item risk-tier checklist and a `gates.yaml` dispatch.

- [x] **P0. Reconcile D1 with #300/#303 (decision, no code).** Read NOTE-D1 and ADR D-11 together; write
  `planning/specs/ADR-...` decision: is the D1 ledger attached to the #303 error (the classed error keeps
  `$ledger`), or does D1 replace #303's message path? Acceptance: an ADR entry with a `decisions:` row; the author
  approves. Blocked by: nothing.
  - **Decided (author, 2026-10-24):** keep #303's classed error (`medfit_error_no_convergence`, no partial fit) and
    attach the D1 ledger to it as `$ledger`. D1 does not replace that path. P0's remaining work is the ADR entry
    recording this. Recorded 2026-10-25 as D-12 in
    `planning/specs/ADR-native-solver-and-engines-2026-10-23.md`. Next: P1.
- [x] **P1. D1 outcome ledger.** Port `sem-outcomes.R` and the ledger fields; adapt to the P0 decision; carry the D1
  controls (both partial-failure orderings, counterfactual LR 1 versus survivor 9, all-success minimum, all-failure,
  malformed-ledger refusal, the three mutants). Acceptance: `test-sem-outcomes.R` green on `dev`; stored known
  answers unchanged; #303's tests still pass. Blocked by: P0.
  - **Done on `feature/p1-d1-ledger` (2026-10-25); the PR is not merged yet.** Decisions kept: field `ledger`, new class
    `medfit_error_ledger` (ADR D-12). Not run yet: the `tests/sim` gates and the OpenBLAS runner.
- [ ] **P2. D2 literal certificates.** Acceptance: `test-sem-literal-certificates.R` green; no tolerance or solver
  status used as proof (planted mutant fails). Blocked by: P1.
- [ ] **P3. D3 branch map and raw cap.** Acceptance: `test-sem-branch-map.R` green including the forged-map refusals
  and the 2^53 / overflow message oracles. Blocked by: P1 (P2 and P3 can run in parallel; both touch
  `sem-outcomes.R`, so merge in order P2 then P3).
- [ ] **P4. D4 covariance-stage evidence.** NOTE-D4 records D4 as *not independently closed* (the review failed to
  produce a verdict). Acceptance: `test-sem-post-fit.R` green, the nonwinning-child mutants fail, and a fresh
  independent review closes it. Blocked by: P1; touches `sem-se.R`, so it reruns the SE oracles.

### Checkpoint 1 (after P0)
- [x] Author approves the reconciliation (D-12, 2026-10-24). Target release: open (0.15.0 or a 0.14.x minor).

### Checkpoint 2 (after P4)
- [ ] missingmed source-loads `dev` and reruns its consumer suite (816 assertions in its receipts); results
  attached to the last PR.
- [ ] Full medfit suite, lint and both gate shards green; NEWS entries per slice.

## Always / never

- Always: keep missingmed's receipt evidence (NOTE files) with each slice; one PR per slice; oracle evidence in each
  PR body.
- Never: push the `keep/*` branches or cherry-pick the chain wholesale; change stored known answers; weaken #303's
  "no partial fit" guarantee without an ADR decision.

## Open

- Whether D4 needs its contract narrowed before porting (its review never concluded).
- T5 in missingmed also waits on a stored improper-null input the author has not supplied; that is missingmed's
  blocker, not medfit's.
