# PLAN: close the sem engine's gaps with lavaan, refreshed for 0.21.0 (2026-11-24)

Status: **planned, nothing implemented.** Supersedes the release grouping of
`planning/PLAN-lavaan-parity-2026-11-17.md`: its T0 to T6 were meant for 0.20.0, but 0.20.0 shipped without them and none
was started. Their content (oracles, planted defects, probes) stays valid and is cited, not repeated.
Maintainer priority (2026-11-24): the four **Partial** rows of the lavaan comparison table come first.
Decisions below were taken in an adversarial review and grill on 2026-11-24 (section 7).

## 1. What changed since 2026-11-17

- 0.20.0 released (2026-11-24): S4a native two-level fit (experimental), IG2 cluster-robust SEs, IG3 equal-indirect LR, T8.
- The 2026-11-17 triage put three of the four Partial rows out of scope (missing data deferred to the FIML admission
  plan; product terms won't-do; two-level not a row of that plan). The 2026-11-24 priority reverses that for all four.

## 2. The four Partial rows

| Row | What exists | Gap to close | Task | Release |
|---|---|---|---|---|
| Estimators | ML plus the HC0 sandwich | MLR: Yuan-Bentler scaled chi-square (scaled fit indices are postponed, section 3) | P1a | 0.21.0 |
| Product terms (`x:m`, four-way) | coefficients and SEs equal lavaan's | chi-square `NA`; `anova()` and `mbco_sem()` refuse when a product factor is a regression target; supported class only | P2(c), P2(b) | 0.21.0 / 0.22.0 |
| Two-level models | observed 1-1-1 and parallel, experimental | the route refuses latent variables, product terms, `weights`, `missing = "fiml"`, nonlinear constraints, `fixed_x = TRUE`, `meanstructure = FALSE`, `information = "expected"` | P3 | 0.22.0 and later |
| Missing data | listwise default; separate bounded random-X FIML opt-in | broader FIML models | P4 | placeholder, 0.22.0 |

### P1a. MLR point estimates and scaled chi-square (0.21.0)
- Trailing `estimator = c("ML", "MLR")` after `sampling_weights` (appended to the `test-api-freeze.R` pin). MLR = ML
  estimates, the existing sandwich SEs, and the Yuan-Bentler scaled chi-square with `chisq_scaled` and `scaling_factor`
  in `glance()`, matching lavaan `estimator = "MLR"`.
- **Precondition (checked first, recorded in the task report):** the scaling factor needs the same scores and
  second-order machinery as the sandwich. If it cannot be built in a new file without editing a risk file other than
  `R/fit-sem.R`, stop and record the finding (section 5); do not widen the task.
- Oracle: lavaan `estimator = "MLR"`, complete data, 1e-5. Planted defect: the Satorra-Bentler (MLM) factor must fail.
- Acceptance: `estimator = "ML"` bit-identical to `origin/dev`. Risk: high (`R/fit-sem.R`), seven-item checklist.
- The "Estimators other than ML" probe is rewritten to compare behavior with lavaan (numbers, not `formals()`), with a
  planted defect, before the argument lands (rule 1 of the 2026-11-17 plan). Row stays **Partial** (ML and MLR).

### P2(c). Product refusals become classed errors (0.21.0)
- No number changes. Every refusal in the supported-class check (`.sem_check_product_parsed()`,
  `.sem_check_product_completed()`) and every `NA`/refusal path (`.sem_product_modeltest()`, `anova()`, `mbco_sem()`)
  carries a `medfit_*` class, its reason in the message, and a row in the article and `?"medfit-syntax"`.
- Oracle: the existing four-way and colon-path gates must stay bit-identical; planted defect: an unclassed refusal fails
  a test that lists every refusal.

### P2(b). A valid scaled test for product models (0.22.0, after P1a)
- The plain chi-square is not valid when a product factor is a regression target (the saturated Gaussian model does not
  cover the product). An MLR scaled statistic is robust to non-normality, so it may give a valid test where today there
  is `NA`. This is an **open question, not a promise:** the task starts with a simulation that checks the scaled
  statistic's size against the lavaan MLR oracle on `x:m` models; if it is not valid, keep `NA` and record the result.
- Decision needed at the start of the task: none beyond the stop rule below.

### P3. Two-level refusal lifts (0.22.0 and later, after P2(b))
- Corrects the earlier draft: **linear constraints already work** on the two-level route (a path equated across levels,
  with the sandwich projected onto the constraint). The refused constraint class is **nonlinear** constraints.
- Order, cheapest first: `weights`, nonlinear constraints, products, latent variables, FIML. Each lift is its own task
  with a lavaan two-level oracle (`fixed.x = FALSE`, `information = "observed"`, `h1.information = "structured"`), a
  planted defect, and the refusal pinned by its own test until it flips.
- Still out: serial two-level mediators (IG5s, decision only), two-level `compare_lr()` (IG3 D6), IG4 and IG6 NO-GO.
  The relation to the roadmap's S4b (out of 0.20.0, next cycle) is **not established here**; the first P3 task reads the
  roadmap and records which refusals S4b already owns before starting.
- The route stays labeled experimental until the maintainer changes it.

### P4. Missing data (placeholder, 0.22.0, not authorized)
- Owned by `PLAN-FIML-statistical-admission-2026-11-01.md`. This plan **schedules a placeholder** that depends on that
  plan; it does **not** authorize FIML admission, which stays unauthorized (CLAUDE.md). 0.21.0 ships no FIML code.
- The comparison test treats a broadened FIML scope as a defect (`test-lavaan-comparison.R`, missing-data tests); if the
  placeholder is ever started, its first commit edits those tests with their planted defects.

## 3. Postponed (maintainer, 2026-11-24)

Fit indices (T2 and the scaled CFI/TLI/RMSEA of the old P1b), modification indices (T5) and the non-mediation SEM tasks
T1 (several modifiers on one term), T3 (fitted values, residuals) and T4 (standardized solution) are postponed, with
T0 (probes, row split), which only matters once one of them lands. They keep their content, oracles and planted defects
from `PLAN-lavaan-parity-2026-11-17.md` and are not scheduled in any release here. P1b is removed from the active plan
because it needs T2; MLR ships without scaled fit indices. A later plan picks them up and re-triages.

## 4. Release grouping

- **0.21.0:** P1a, P2(c). Flips: none to Supported; "Estimators other than ML" stays Partial (ML, MLR); the product row
  stays Partial with every refusal classed.
- **0.22.0:** P2(b), then the P3 lifts in the order above; the P4 placeholder is scheduled alongside, not authorized.
- **Later (postponed, section 3):** T0 to T5 and scaled fit indices, the remaining P3 lifts.
- **Not planned here:** multiple groups, categorical outcomes (backlog B3), latent means (1.0).
- Each release follows `ADR-docs-release-pipeline` and the release-ordering policy (GitHub-only; CRAN hold #83).

## 5. Rules and stop rules

Rules from the 2026-11-17 plan stand: probe changes first; one commit edits the article row, its probe and the
exact-rows test; the seven-item admission checklist for any file in `tests/sim/risk-files.txt`; `test-api-freeze.R` and the
dependents contract; default rule (match lavaan, else classed refusal, keep results bit-identical).
Added stop rules for the priority group:
- P1a: the scaling factor needs an unplanned risk-file edit (see its precondition).
- P1a, P2(b): the lavaan MLR oracle disagrees beyond 1e-5 after two implementer-QA loops.
- P2(b): the scaled statistic's size is off in the check simulation: keep `NA`, record, stop.
- Any task: the full suite differs from `origin/dev` for a reason outside the task.

## 6. Order

0.21.0: P1a, then P2(c) (independent; either may go first). 0.22.0: P2(b), P3, P4 placeholder.

## 7. Decisions (grill 2026-11-24)

| # | Decision | Alternatives rejected |
|---|---|---|
| 1 | 0.21.0 is P1a plus P2(c) only | adding fit indices; two P3 lifts (each is another high-risk OpenBLAS-gated task) |
| 2 | P4 is a scheduled placeholder for 0.22.0, not authorized | keep Partial with no placeholder; start admission now |
| 3 | Fit indices, modification indices, T1, T3, T4 (and T0) postponed to a later plan; 0.22.0 is P2(b), then P3 | fit indices first (the earlier recommendation, overridden by the maintainer); P3 first |

Open, with defaults: P3 keeps the experimental label (default: keep); whether P3's first task is `weights` or nonlinear
constraints (default: `weights`, the smaller change).

## 8. Ledger

| Date | Event |
|---|---|
| 2026-11-24 | refreshed for 0.21.0 after an adversarial review; four Partial rows prioritized; corrected a wrong claim that two-level constraints were refused (only nonlinear ones are) |
