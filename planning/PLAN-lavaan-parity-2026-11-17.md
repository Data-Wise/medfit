# PLAN: close the gaps between the sem engine and lavaan (2026-11-17)

Status: **planned, nothing implemented.** Written on `feature/lavaan-parity-plan` off `origin/dev` (`4f8eac80` era).
Source of the gaps: the feature table in `vignettes/articles/lavaan-comparison.qmd` and its live probes in
`tests/testthat/test-lavaan-comparison.R`. Runner: the `medfit-orchestrator` skill, one task per run, in task order.

## 0. How to run this plan without questions

- **Start:** "Start T0 from planning/PLAN-lavaan-parity-2026-11-17.md", then "next task" until the 0.20.0 group is done.
- **The only sanctioned interrupts** are the orchestrator's Phase 5 asks (push, open the PR) and the merge. Every
  other choice is decided below. When something unexpected comes up, apply the **default rule** (section 4) and the
  **stop rules** (section 5); do not ask.
- **Pre-decided choices live in this file**, not in a new ADR. A task that wants a durable record adds rows to the
  `decisions:` front matter of an existing ADR only if `test-adr-front-matter.R` still passes; otherwise it records the
  choice in its PR body and in this file's ledger (section 8).
- **Contracts every task respects:** `test-api-freeze.R` (new `fit_sem()` arguments go after `sampling_weights`; no
  pinned name moves), the risk-tier admission checklist for any file in `tests/sim/risk-files.txt`, the ADR front
  matter, `test-dependents-contract.R`, `test-refcard-coverage.R` (every new export on the Reference Card and in
  `_pkgdown.yml`), US English, CRAN on hold (#83).

## 1. Triage of the gap rows

The table has 8 gap rows (5 Unsupported, 3 Partial). "Means and intercepts" is already **Supported** (observed means);
latent means are noted under Deferred and do not flip a row.

| Row (exact table text) | Today | Verdict | Task / reason |
|---|---|---|---|
| Several modifiers on one term | Unsupported | **In scope, 0.20.0** | T1 |
| CFI, RMSEA, SRMR | Unsupported | **In scope, 0.20.0** | T2 |
| Standardized estimates, modification indices, fitted values, residuals | Unsupported | **Split (T0), then in scope** | T0 splits into four rows; T3 fitted + residuals, T4 standardized (0.20.0); T5 modification indices (0.21.0) |
| Estimators other than ML | Partial | **In scope, 0.21.0 (MLR only)** | T6. WLS/ULS/DWLS are won't-do here: they serve categorical data (below) |
| Multiple groups | Unsupported | **Deferred** | Changes the objective, parameter vector and constraint set across groups; needs its own high-risk plan with OpenBLAS runs (section 7) |
| Categorical outcomes | Unsupported | **Deferred** | Roadmap backlog B3 (L, weeks): a new likelihood, information and gate layer; requires a named consumer and an oracle first. Binary outcomes stay on `engine = "glm"` |
| Missing data | Partial | **Deferred** | Owned by `PLAN-FIML-statistical-admission-2026-11-01.md`; the comparison test treats a broadened FIML scope as a defect (test lines 265-285). No change here |
| Product terms (`x:m`) and four-way effects | Partial | **Won't-do** | The `NA` chi-square for a product factor that is a regression target is a correctness decision (`.sem_product_modeltest()`), not a gap |
| (note) latent means | n/a | **Deferred to 1.0** | Roadmap; not a table row |

## 2. Probe changes come first in every task

Each status is computed by a live probe, so a row flips only when its probe says so. Rules:

1. **Name-only probes are replaced before the feature lands.** "Multiple groups" and "Estimators other than ML" read
   `formals(fit_sem)`; a task that adds such an argument first rewrites the probe to compare behavior with lavaan
   (numbers, not names) and adds a planted defect (argument present, behavior wrong ⇒ not Supported).
2. **Bundled rows are split before any part lands** (T0).
3. A task edits the article row, the probe and, if the row set changes, the "rows are exactly the probed features"
   test in one commit. The planted-defect test (lines 239-246) must still fail on an edited status.
4. Hard pins stay: the categorical row's `expect_identical(row$status, "Unsupported")` and the missing-data evidence
   tests are not touched by this plan.

## 3. Tasks

Risk tier is read from `tests/sim/risk-files.txt` (today: `R/sem-ml.R`, `R/sem-model.R`, `R/sem-constraints.R`,
`R/sem-optim.R`, `R/sem-parse.R`, `R/sem-fit.R`, `R/fit-sem.R`, `R/sem-fiml.R`, `R/sem-fiml-interface.R`,
`tests/sim/gates.csv`). A task that touches any of them is **high** and its PR body carries the seven-item checklist
(each item ticked or `n/a: <reason>`). New computation goes in new files to keep tasks off the list where possible.

### T0. Plan pointer and the row split (docs + tests, low)

- **Files:** `CLAUDE.md` (add an `**Active plan:**` line naming this file under "Planning Documents"; the orchestrator's
  Phase 0 stops without it), `vignettes/articles/lavaan-comparison.qmd`, `tests/testthat/test-lavaan-comparison.R`.
- **Change:** replace the bundled row by four rows, each Unsupported, with its own probe:
  `Fitted values (model-implied moments)`, `Residuals`, `Standardized estimates`, `Modification indices`.
  Probes: fitted ⇒ `fitted(f)` equals `lavaan::fitted(l)` (cov and mean, 1e-6); residuals ⇒ `residuals(f, "raw")` and
  `residuals(f, "cor")` equal lavaan's `"raw"` and `"cor.bollen"`; standardized ⇒ `standardized_solution(f)` exists
  and `est_std` and `se` equal `lavaan::standardizedSolution()` (1e-5); MI ⇒ `modification_indices(f)` exists and `mi`
  equals `lavaan::modindices()` (1e-4). Rewrite the "Estimators other than ML" and "Multiple groups" probes per
  section 2 rule 1 (estimator: `fit_sem(..., estimator = "MLR")` scaled chi-square equals lavaan's `chisq.scaled`;
  groups: a two-group fit's coefficients equal lavaan's `group =` fit). Statuses do not change in T0.
- **Acceptance:** suite green; every new probe returns the current status; a planted defect (a stub `fitted()` returning
  the sample moments) makes the fitted probe say Unsupported.
- **Docs:** the article's table and its paragraph listing what to use lavaan for (line 25).

### T1. Several modifiers on one term (high: `R/sem-parse.R`)

- **Decision:** a term may carry a chain `m1 * m2 * ... * operand` with **at most one modifier of each kind**: label,
  fixed value (number or `NA`), `start()`, `lower()`, `upper()`. Allowed combinations are exactly those lavaan's
  `lavaanify()` accepts; the chain is order-free. Conflicts error: two labels, two fixed values, a fixed value with
  `start()`, `lower()` or `upper()` (lavaan ignores bounds on a fixed parameter; medfit refuses, as it does today).
  A repeated term (`y ~ a*x + start(0.1)*x`) keeps today's behavior.
- **Error class:** `.sem_syntax_error()` gains class `c("medfit_syntax_error", "error", "condition")` (additive).
  The message "more than one modifier on a term; use one modifier per term" is replaced by
  "two <kind> modifiers on one term" for same-kind conflicts.
- **Files:** `R/sem-parse.R`, `R/sem-syntax-help.R` (`?"medfit-syntax"`), `tests/testthat/test-sem-parse.R`, every
  test or page that quotes the old message (`git grep "more than one modifier"`; today only the two files above), the
  native model pages' error tables if they list it.
- **Oracle:** for each allowed pair and triple, the parsed table's free/fixed/start/bound/label fields equal
  `lavaan::lavaanify()`'s `free`, `ustart`, `start`, `lower`, `upper`, `label`; fitted coefficients equal
  `lavaan::sem()` (1e-5) on `mediation_demo`.
- **Planted defect:** a parser that keeps only the first modifier must fail the table oracle.
- **Checklist notes:** reliability cell and metamorphic invariance = modifier order permutation gives the identical
  fit; fault injection = conflicting chains error; registration = a `gates.csv` row and a `structures.csv` row
  `modifier-chain`; platform run on the OpenBLAS runner.
- **Flips:** "Several modifiers on one term" → Supported.

### T2. Fit indices in `glance()` (standard: new file `R/sem-fitmeasures.R`, `R/methods-sem.R`)

- **Decision:** `glance(<SEMFit>)` gains `cfi`, `tli`, `rmsea`, `rmsea_ci_lower`, `rmsea_ci_upper`, `rmsea_p_close`,
  `srmr` (additive columns after `p_value`; check `test-dependents-contract.R`). Matching targets:
  `lavaan::fitMeasures(l, c("cfi", "tli", "rmsea", "rmsea.ci.lower", "rmsea.ci.upper", "rmsea.pvalue", "srmr"))` on
  the same settings (`meanstructure`, `fixed.x`, `likelihood = "normal"`, i.e. N not N - 1). The baseline model is
  lavaan's independence model in **closed form** (diagonal covariance at the sample variances; means at sample means;
  with `fixed_x` the exogenous block stays at its sample values), so no optimizer call and no risk file.
- **NA rules:** every index is `NA` when `chisq` is `NA` (weights, product-invalid test); `rmsea` CI and p-close are
  `NA` when `df == 0`; CFI/TLI are `NA` when the baseline df is 0. Weighted or sandwich fits report nothing extra
  (scaled indices are T6).
- **Oracle:** lavaan on a grid: `fixed_x` TRUE/FALSE × `meanstructure` TRUE/FALSE × {simple, serial, parallel, latent
  mediator, constrained} on `mediation_demo` and one simulated misfitting model; tolerance 1e-6.
- **Planted defect:** a baseline that frees the exogenous covariances under `fixed_x = TRUE` must fail CFI.
- **Docs:** `?glance` SEMFit section, the lavaan-comparison article, the sem engine guide's fit section, NEWS.
- **Flips:** "CFI, RMSEA, SRMR" → Supported.

### T3. Fitted values and residuals (standard: new methods in `R/methods-sem.R`)

- **Decision:** `fitted(<SEMFit>)` returns lavaan's meaning, the model-implied moments `list(cov = , mean = )`
  (`mean` absent without a mean structure), observed variables only, in data column order. Case-level predictions are
  out of scope. `residuals(<SEMFit>, type = c("raw", "cor"))`: sample minus implied moments; `"cor"` = lavaan's
  `cor.bollen`. Sample moments use N (ML). `type = "standardized"` errors with class `medfit_unsupported` and points to
  T5 (it needs the residuals' standard errors).
- **Oracle:** `lavaan::fitted()` and `lavaan::residuals(type = "raw" | "cor.bollen")` on the T2 grid; 1e-6.
- **Planted defect:** N - 1 sample moments must fail the raw-residual oracle.
- **Flips:** "Fitted values (model-implied moments)" → Supported, "Residuals" → Supported once `"raw"` and `"cor"` pass
  (the row text says "raw and correlation residuals").

### T4. Standardized solution (standard: new export, new file `R/sem-standardized.R`)

- **Decision:** export `standardized_solution(object, type = c("std.all", "std.lv", "std.nox"), level = 0.95)`;
  returns a tibble with lavaan's rows (`lhs`, `op`, `rhs`, `label`) plus `est_std`, `se`, `statistic`, `p_value`,
  `conf_low`, `conf_high`; `:=` rows are standardized by re-evaluating the definition on standardized values, as lavaan
  does. SEs by the delta method: numerical Jacobian of the standardization map (central differences) times the fit's
  `vcov` (already projected for constraints). `fixed_x` variances come from the sample, as in lavaan.
- **Oracle:** `lavaan::standardizedSolution(type = )` est and se on the T2 grid; 1e-5 est, 1e-4 se.
- **Planted defect:** standardizing with implied instead of sample exogenous variances under `fixed_x` must fail.
- **Docs:** Reference Card, `_pkgdown.yml`, cookbook recipe, lavaan-comparison article, NEWS.
- **Flips:** "Standardized estimates" → Supported.

### T5. Modification indices (0.21.0; standard unless the information code in a risk file must change)

- **Decision:** export `modification_indices(object, sort = TRUE, minimum = 0)`: score tests for every fixed-at-zero
  regression, loading and residual covariance lavaan would list, with `mi`, `epc`, `sepc_all`, from the expected
  information of the extended parameter vector at the restricted estimate (lavaan's default). Refused (class
  `medfit_unsupported`) for weighted fits, nonlinear constraints and product-invalid tests. Adds
  `residuals(type = "standardized")` from the same machinery.
- **Oracle:** `lavaan::modindices()` and `lavaan::residuals(type = "standardized")`; 1e-4.
- **Planted defect:** observed instead of expected information must fail.
- **Flips:** "Modification indices" → Supported.

### T6. MLR (0.21.0; high: `R/fit-sem.R`)

- **Decision:** trailing argument `estimator = c("ML", "MLR")` after `sampling_weights`. `"MLR"` = ML estimates, the
  existing sandwich SEs, and the Yuan-Bentler scaled chi-square with `chisq_scaled`, `scaling_factor`, and scaled
  `cfi`/`tli`/`rmsea` in `glance()`, matching lavaan `estimator = "MLR"`'s `.scaled` and `.robust` fields. `"ML"` keeps
  every current result. Only MLR is added; WLS-family estimators stay with the categorical deferral.
- **Oracle:** lavaan `estimator = "MLR"` on the T2 grid (complete data); 1e-5.
- **Planted defect:** the Satorra-Bentler (MLM) factor in place of Yuan-Bentler must fail.
- **Flips:** "Estimators other than ML" stays **Partial** (ML and MLR) with the probe from T0; the row text is updated.

## 4. Default rule for the unexpected

In order: (1) match lavaan's documented default for the same option; (2) if lavaan has no counterpart, refuse with a
classed error (`medfit_unsupported`) rather than guess; (3) keep every existing result bit-identical (`origin/dev`
numeric neutrality is part of QA); (4) prefer an additive change (new column, new trailing argument, new class on an
existing condition) over a changed one; (5) record the choice in the PR body and section 8.

## 5. Stop rules (halt the task, record, move on)

Stop the task, leave it unticked, and write the finding to `_agents_workspace/<task>/` and section 8 when:
- the lavaan oracle disagrees beyond tolerance after two implementer-QA loops and the cause is not found;
- the work needs a change to a file in `tests/sim/risk-files.txt` that the task did not plan for (T2-T5 must not);
- a pinned API name would move (`test-api-freeze.R`) or `test-dependents-contract.R` breaks;
- lavaan itself errors or warns on the oracle model (choose another oracle model once; then stop);
- the full suite fails on the branch but passes on `origin/dev` for a reason outside the task.
A stopped task does not block the next one unless it is listed as its dependency (section 6).

## 6. Order and dependencies

T0 → T1 (independent of T2-T4) → T2 → T3 (reuses T2's sample moments) → T4 → T5 (needs T3) → T6 (needs T2).

## 7. Release grouping

- **0.20.0:** T0-T4. Flips: several modifiers, CFI/RMSEA/SRMR, fitted values, residuals, standardized estimates.
  Release follows `ADR-docs-release-pipeline` (GitHub-only; CRAN hold).
- **0.21.0:** T5, T6.
- **Later, own plans (not authorized here):** multiple groups (high-risk plan: per-group moments, cross-group equality
  constraints, `group =` and `group.equal =` semantics, OpenMx and lavaan oracles); categorical outcomes (backlog B3);
  FIML scope (its admission plan); latent means (1.0).

## 8. Ledger

| Date | Task | Event |
|---|---|---|
| 2026-11-17 | plan | written; nothing implemented |
