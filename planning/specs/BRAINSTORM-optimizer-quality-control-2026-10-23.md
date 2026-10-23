# Brainstorm: optimizer quality control as models are added, and where it is recorded

**Date:** 2026-10-23. **Status:** brainstorm, not a plan of record. Companion to
`ADR-native-solver-and-engines-2026-10-23.md` (solver choices) and `PLAN-optimizer-robustness-2026-10-20.md`
(five test layers). **Request:** test the optimizer whenever a model class is added, and keep a section of the
documentation that records the tests and the technical decisions.

## What exists today (checked 2026-10-23)

- **22 gates** in `tests/sim/gates.csv` (parity, constrained, se, stationarity, reliability, nonlinear, fixed-x,
  mean-constrained, factor, oracle-sweep, compare-lr, restoration, ...), each with an expected row count, run by
  `tests/sim/run-gates.R`, which re-derives verdicts from the saved results, has `--fast` (ties constants to the
  package) and `--mutants` (planted defects must be rejected).
- **CI:** `gates.yaml` runs two shards on PRs to `main` (`gates (rest)`, `gates (reliability)`, required checks).
- **Criteria:** `planning/specs/CRITERIA-native-experimental-exit-2026-10-17.csv`; a test fails when a gate is added
  or removed without updating its gate set (C2).
- **Layers 1 and 2** of the robustness plan (metamorphic, fault injection) are implemented; **layers 3 to 5** (edge-case
  grid, randomized oracle sweep as a per-model rule, cross-platform and alternate BLAS) are not, except the
  `oracle-sweep` gate and the OpenBLAS runner.
- **Decisions** live in `planning/specs/` (GRILL, PLAN, ADR files), which the site does not publish.

## The gaps

1. Gates were added after bugs (#213, #238, #276), not when a model class arrived. Nothing makes a new structure
   (a new syntax feature, constraint type or engine option) bring optimizer coverage with it.
2. The reliability harness compares only SLSQP and L-BFGS; the ADR needs it solver-agnostic (SLSQP, `nlminb`, AUGLAG).
3. Layers 3 to 5 are open.
4. No section of the site records what is tested, by which oracle, or why a solver was chosen.
5. Evidence provenance: designs committed before runs is now a rule for the D-4 gate (ADR D-9) but not for gates in
   general.

## Quick wins (under 30 minutes each)

1. **Admission checklist** (one table in the docs and in `CLAUDE.md`): what a new model class must have before it
   merges (see "Admission" below).
2. **`test-gate-coverage.R`:** every structure in `sem_models()` and every `model-native-*.qmd` page must name a gate
   in `gates.csv`; the test fails when a structure is added without one. Same pattern as the C2 gate-set test.
3. **Metadata columns in `gates.csv`** (`oracle`, `mutants`, `since`, `doc`) so the site table is generated, not
   hand-written, and cannot drift.

## Medium effort (1 to 2 hours each)

1. **Generate the "Quality control and technical decisions" article** from `gates.csv`, the criteria file and an ADR
   index (see "Documentation section").
2. **Solver-agnostic reliability harness:** parametrize `sem-reliability.R` by backend through the `.sem_nlopt` /
   `.sem_solve_one` seam; implement the D-8 paired score interval and the commit-first design file (D-9) in
   `run-gates.R`.
3. **Layer 3, the edge-case grid:** near-singular covariance, tight bounds, constraint rank, scale extremes, per
   `PLAN-optimizer-robustness`.
4. **A "model onboarding" template:** one script that, given a model structure, instantiates the standard checks
   (oracle parity, reliability cell, metamorphic, fault injection) so adding a model is filling in a fixture.

## Long term

1. **Structure registry drives every layer:** `sem_models()` becomes the single registry; parity, reliability,
   metamorphic, fault-injection and sweep gates iterate over it, so adding a model runs all layers automatically.
2. **Layer 5, the platform matrix:** Linux, macOS, Windows and an alternate BLAS (the #274 container).
3. **Scheduled gates with a trend:** nightly or weekly runs that record the unresolved rate, the largest restoration
   ratio (rho) and the reliability per cell, so drift is seen before a release; results archived with provenance.
4. **Solver-change protocol:** any solver change (ADR D-4, D-6) runs the full suite on both solvers and records the
   paired comparison in the decision log.

## Admission: what a new model class must bring (proposal)

| # | Check | Evidence |
|---|---|---|
| 1 | **Independent oracle** | lavaan, OpenMx, OLS or a hand calculation agrees within a stated tolerance |
| 2 | **Reliability cell** | the structure is in the reliability grid (default and random starts, the four data scales) |
| 3 | **Planted defect** | a mutant the gate must reject (the harness already has `MUTANT=` and `--mutants`) |
| 4 | **Metamorphic invariance** | rescaling a variable, reordering syntax, and a redundant constraint leave the answer unchanged |
| 5 | **Fault injection** | bad solver statuses and non-finite values are refused or retried, never accepted |
| 6 | **Registration** | a `gates.csv` row, a criteria entry and a documentation entry (enforced by `test-gate-coverage.R`) |
| 7 | **Platform run** | the gate passes on the OpenBLAS runner, not only locally |

Risk tiers could scale this: a model with constraints, latent variables or products needs all seven; a model that only
adds an output method needs 1, 3 and 6.

## Documentation section: "Quality control and technical decisions"

A site article, generated where possible, with:

1. **Principles:** every number has an independent oracle; every gate has a planted defect it must catch; an
   unresolved result beats a wrong one; evidence is designed before it is run.
2. **Gate catalog** (generated from `gates.csv`): gate, what it checks, oracle, mutants, platforms, last result.
3. **Decision log** (ADR index): one row per decision with status (accepted, proposed, superseded), date, evidence
   link and what would change it. Starts with the solver ADR.
4. **How to add a model:** the admission table above, with a worked example.
5. **Evidence archive:** where result files live, naming, provenance rule (design committed before the run),
   and how `run-gates.R` re-derives verdicts.
6. **Known limits:** what is not tested (latent-model solver benchmark, reference BLAS, other seeds of the floor
   fixture), copied from the PR bodies and ADRs so they are not lost.

A test keeps it honest: the article's gate table must equal `gates.csv`, and every ADR in `planning/specs/ADR-*.md`
must appear in the decision log.

## Recommended next step

Start with quick wins 2 and 3 (`test-gate-coverage.R` and the metadata columns): they make "add a model, get
coverage" enforced and they feed the article. Then generate the article (medium 1). Reason: enforcement before
documentation, so the documented rule is already true when it is published.

## Open questions

See the grill that produced this file; decisions are recorded below as they are made.

### Grill ledger

| # | Question | Decision (author, 2026-10-23) |
|---|---|---|
| Q-1 | How strict is the admission rule? | **Three checks for every new model class** (independent oracle, a reliability cell, a planted defect) and **all seven for high-risk classes** (metamorphic, fault injection, registration, platform run on top), **enforced by a test** (`test-gate-coverage.R`) that fails the build when a structure has no gate row. |
| Q-2 | How is a change classified as high-risk? | **By what the optimizer sees:** high-risk if the change alters the objective, the parameter vector, the constraint set, the bounds or the solver path; low-risk if it only touches post-fit output (a new `tidy()` column, a printout). Checkable from the files touched (`R/sem-ml.R`, `sem-model.R`, `sem-constraints.R`, `sem-optim.R`, `sem-parse.R`); not a feature list and not an author's declaration. |
| Q-3 | How does the QC article stay in sync with `gates.csv` and the decision log? | **Generate at site build and test the sources.** The gate catalog and the decision log are rendered by R chunks from `gates.csv` (with new `oracle`, `mutants`, `doc` columns) and from ADR front matter; tests fail when a `gates.csv` row lacks its metadata or an ADR lacks the front-matter fields. The pkgdown workflow, which already runs on PRs to `dev`, catches a broken generation before merge. Not a committed copy, not hand-written. |
| Q-4 | What is the unit of the decision log? | **One row per decision**, read from a YAML list in each ADR's front matter (`id`, `title`, `status`, `date`, `supersedes`). The ADR stays the single source; mixed statuses show correctly (the solver ADR has parts A to D and ten sub-decisions); the sync test requires the list in every ADR and unique ids across ADRs. Not one row per file, not a separate `decisions.csv`, and the solver ADR is not split into ten files. |
| Q-5 | How and when do the scheduled QC gates run, and what drift raises an alert? | **Weekly on `dev` on the OpenBLAS runner** (the `s7-watch.yaml` pattern: cron plus `workflow_dispatch`, results archived with provenance). **Alert now on two things only:** a gate failure, or a changed environment fingerprint (R, BLAS, nloptr version); each opens **one GitHub issue, deduplicated while one is open**. **Metrics are recorded every week** (unresolved rate, largest restoration ratio rho against its cap k = 4, reliability per cell); **drift bands are set after about 8 weeks** from the recorded spread. Not a fraction-of-limit rule from day one (it would fire permanently: the restoration row already sits near 75% of its limit), not failures only (slow drift would be invisible), not record-only. |
| Q-6 | Where does the weekly gate run publish its results? | **A summary CSV committed by the scheduled job to a dedicated `qc-results` branch**, with the full artifacts attached to the workflow run. The article's gate table reads the latest row at site build (the "last result" column); `dev` history carries no weekly commits; the record outlives the 90-day artifact retention. Not workflow artifacts only (no last-result column, record expires), not commits to `dev` (weekly noise, bot write access to a guarded branch). Open detail: the site build must tolerate a missing or stale `qc-results` branch (show "no recent run", never fail the build). |

### Design review (engineering code-review, 2026-10-23)

Verdict: needs discussion, approve once the two High findings are resolved. Resolutions (decided with the author's instruction "address all the critical issues"):

| # | Finding | Resolution |
|---|---|---|
| R-1 | Q-2's risk tier cannot be tested inside testthat: a test sees no diff, so the tier would be advisory. | **A CI step, not a test, owns the tier.** A `classify-risk` job on PRs to `dev` and `main` lists changed files with `git diff --name-only origin/<base>...HEAD`. If any of `R/sem-ml.R`, `sem-model.R`, `sem-constraints.R`, `sem-optim.R`, `sem-parse.R`, `sem-fit.R`, `tests/sim/gates.csv` changed, the job requires the PR body to contain the seven-check admission checklist with each box ticked or marked "n/a" with a reason, and fails otherwise. The file list lives in one place (`tests/sim/risk-files.txt`), read by the job and by `test-gate-coverage.R`, which fails if a listed file no longer exists (so a rename cannot silently disable the tier). Low-risk PRs pass without the checklist. The job is a required check once it has run clean on three PRs. |
| R-2 | `test-gate-coverage.R` only proves a row exists; a row with an empty oracle or a mutant that never runs passes. | **The test checks that each row is real, in three parts.** (a) `oracle` and `mutants` are non-empty for every gate (`mutants` may be the literal `none` only with a `none_reason` column filled, and the test lists those so they stay visible). (b) Every mutant named in `gates.csv` is a `MUTANT=` value that the gate's script actually reads (the test greps the script, as the existing `--fast` check ties constants to the package). (c) `run-gates.R --mutants` runs in the nightly and PR gate jobs, not only on request, and a mutant that is accepted fails the gate. A row whose mutant list is stale therefore fails in the cheap test (a, b) before it can reach the expensive run (c). |

Still open from the review (Medium and Low, settle during implementation): R-3 the `qc-results` branch needs a write-permission rule and a push step that cannot turn a green run red; R-4 the site build must read a committed snapshot when `tests/sim/` and `planning/` are absent (both Rbuildignored); R-5 the solver ADR needs its YAML front matter before the sync test lands; R-6 a `run-qc` label for pulling a gate run forward between weekly runs.
