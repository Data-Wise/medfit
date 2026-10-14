# Implementation Plan: medfit 0.9.0 (native observed mean structure)

**Date:** 2026-10-13 | **Branch of record:** `dev`; work on `feature/native-mean-structure` (not created; branching waits for the author's request) | **Release channel:** GitHub only
**Source of truth:** [PLAN-native-mean-structure-2026-10-12.md](../planning/specs/PLAN-native-mean-structure-2026-10-12.md) (task numbers T1-T9, review findings, semantics 1-7), [GRILL](../planning/specs/GRILL-native-mean-structure-2026-10-12.md) G1-G13, [grammar amendment](../planning/specs/SPEC-sem-grammar-amendment-intercept-term-2026-10-13.md) (APPROVED). **This file restates the spec plan as vertical slices; it adds no new scope.** Where the two differ, the spec plan wins. The closed 0.8.0 plan is `planning/archive/PLAN-0.8.0-closed-2026-10-12.md`.
**Task list:** `tasks/todo.md` (checklist; slice numbers match this file).

## Goal

The native SEM engine fits observed intercepts and exogenous means (`y ~ 1`, `meanstructure =`), with covariance-only fits unchanged to 1e-12. Out of scope: latent means (0.11.0), the `:` operator and four-way (0.10.0), `fixed_x` (0.9.1, its own plan).

## Already done

- **T1** (merged, #170): `has_mean` flag and frozen v0.8.0 values. Two follow-ups stay open (tolerance/platform, seed).
- The `anova()` nesting fixes (#171, #173) and the `y ~ 1 + x` amendment approval.

## Dependency graph

```
S1 observed intercepts, end to end (parse -> likelihood -> counts -> SEs)
   -> S2 scale robustness (centered gate)                      == Checkpoint A
        -> S3 restrictions and anova across status
        -> S4 weights and sandwich
              -> S5 constraints, MBCO, re-fit plumbing, lavaan parity   == Checkpoint B
                    -> S6 methods and extraction
                          -> S7 docs and close-out                      == Checkpoint C
```

S3 and S4 are independent of each other once S2 passes. Spec-plan mapping: S1 = T2 (parser/flag/messages) + T3 (core likelihood, counts); S2 = T3 (scale, sweep); S3 = T2 (`~0*1` meaning) + T5; S4 = T4; S5 = T6 + T8a + T2 plumbing; S6 = T7 + T8b; S7 = T9.

## Slices

### S1: One observed-intercept model works end to end (M)
Vertical path: `fit_sem("m ~ a*x\ny ~ b*m + cp*x\nm ~ 1 + x" ...)` style input, through parser, RAM, ML, counts and SEs, to a printed fit.
- Parse `y ~ 1 + x` in either order (D1: a repeated `1` errors; D2: either position); `meanstructure` tri-state (`NULL`/`TRUE`/`FALSE`) on `fit_sem()`; any `~1` row turns mean structure on and frees every unwritten observed intercept.
- `m` vector in the RAM, `mu = F (I - A)^-1 m`; F adds the mean term; gradient, expected and observed information gain the additive mean term (G1); `.sem_sample()` keeps `xbar`; `.sem_df()` counts `p(p+1)/2 + p` moments; the df-error text and the "mean structure is not supported" messages and their tests change in this slice.
- **Acceptance:** a saturated-mean fit reproduces the covariance-only estimates, SEs, df and chi-square to 1e-6; its AIC equals the covariance-only AIC; `y ~ 1` alone frees the other observed intercepts (npar and logLik equal lavaan's); no-`~1` fits still match every frozen value (T1 gate) to the stated tolerance.
- **Verify:** `devtools::test(".", filter = "sem")` plus the T1 frozen test; intercept SEs against the always-on OLS oracle (SE = OLS SE x sqrt((n-k)/n)); planted defects, each named and failing the right test: gradient without `dmu`, information without the mean term, information with `dmu/dA` dropped.
- Files: `R/sem-parse.R` (the 176 error), `R/sem-model.R` (`.sem_complete`, `.sem_to_ram`, `.sem_df`), `R/sem-ml.R`, `R/sem-fit.R`, `R/fit-sem.R`, tests.

### S2: Scale robustness (S) — Checkpoint A
- Centered gate: run the information, its inversion (`.sem_invert_info`) and the identification check in implied-mean coordinates; map back with `V = J V_phi J'`; same centering in `.sem_gate_projected` and `.sem_active_set`; define the map for fixed or constrained intercepts; sd floor and sample-mean starts for scale (G9).
- **Acceptance:** a mean/sd sweep to 1e5 gives accepted fits with non-NA vcov equal to the OLS values; every non-mean case is unchanged.
- **Verify:** the sweep test; the gradient finite-difference test at `d = xbar - mu != 0`; the T1 frozen gate rerun.
- **Checkpoint A (go/no-go on S3-S7):** frozen-value gate, saturated-regression gate, intercept-SE oracle, sweep all pass; full `devtools::test()` with counts.

### S3: Restrictions and comparison across mean-structure status (M)
- A fixed `y ~ 0*1` is a restriction (df 1, chi-square and logLik equal lavaan's on the review's model; `meanstructure = TRUE` plus a user-fixed `0*` keeps it); `meanstructure = FALSE` with any `~1` errors naming the term; the old behavior's tests and help text updated (`test-sem-fit.R:108-111`, `test-sem-model.R:234-235`, `test-sem-parse.R:58`, `R/sem-syntax-help.R:35`); NEWS behavior-change entry; a frozen intended-change fixture.
- logLik no longer double counts the means (`R/methods-sem.R:116`); `anova()` across status: a covariance-only fit gets implicit free `v ~1` keys before the nesting check; shared labels between an intercept and a path allowed (G12).
- **Acceptance:** `anova(cov_only, fit_y0)` gives df 1 and the lavaan chi-square difference, both argument orders; equal-df comparisons still error; AIC/BIC cases (saturated, one fixed, one equality) correct.
- **Verify:** tests named above plus the planted defect "fixed intercept dropped".

### S4: Weights and the sandwich (M)
- `.sem_scores()` adds the mean score with uncentered data; the sandwich header comment updated.
- **Acceptance:** saturated weighted sandwich equals the covariance-only sandwich; sandwich SEs match lavaan `sampling.weights` with `meanstructure = TRUE, fixed.x = FALSE`.
- **Verify:** restricted-intercept model at an off-optimum theta (the case where a scores defect shows); planted defect: centered scores.

### S5: Constraints, MBCO and re-fits (M) — Checkpoint B
- Intercept rows in linear and nonlinear `==`, `<`, `>`, `:=` and the redundancy rule; `mbco_sem()` refits, `.sem_fit_branches` and `fit_mediation(engine = "native", meanstructure = )` carry the flag (pass by name); `SEMFit@internals` stores it, read with `isTRUE()` so old objects load.
- T8a lavaan parity (simple, serial, parallel, latent mediator in the G7 case-A form).
- **Acceptance:** intercept variants of `tests/sim/sem-nonlinear-gate.R` pass, including one that drops the flag on refit and must fail; parity to 1e-4 on all four forms.
- **Checkpoint B (go/no-go on S6-S7):** nonlinear gate, parity and the intercept-SE oracle pass; full suite.

### S6: Methods, extraction and the worked example (S)
- `coef`, `vcov`, `tidy`, `glance`, `confint`, `summary` include intercept rows (summary row name `y~1` without the trailing space); `extract_mediation(<SEMFit>)` equals the covariance-only effects; `b0` and its covariances stay in `vcov`; four-way on a SEMFit refused by name for `"auto"` and for an explicit `"four_way"`.
- OpenMx independent optimum on a constrained-intercept model (`skip_if_not_installed`); one worked example where an intercept constraint changes a result.
- **Acceptance:** extraction equality with and without a saturated mean structure; the refusal tests.

### S7: Docs and close-out (S) — Checkpoint C
- NEWS (honest benefit statement; the lavaan-route four-way corrections first), the vignette and help text that say native cannot estimate intercepts, `?"medfit-syntax"`, `man/fit_sem.Rd`, the lavaan-comparison row (the `y ~ 1 + x` probe flips to Supported), `methods.qmd`, CLAUDE.md Engines row and file/testing sections, `.STATUS`.
- **Acceptance:** doc currency check; `test-refcard-coverage.R`, cookbook and link tests green; full suite with counts; `R CMD check --as-cran` and the strict-flavor check; `urlchecker`, `spelling`; US English.
- **Checkpoint C:** release decision (the version bump is release engineering's).

## Risks

| Risk | Caught in |
|---|---|
| Silent change to existing fits | T1 frozen gate, rerun after every edit to `.sem_eval`/`.sem_scores`/`.sem_sample` (every slice) |
| Information or scores missing the mean term | S1 intercept-SE oracle and planted defects; S4 off-optimum scores test |
| Acceptance gate rejects realistic data (distant means) | S2 sweep |
| `meanstructure` lost on a re-fit | S5 tests |
| A fixed `~0*1` changes meaning versus 0.8.0 | S3 NEWS and intended-change fixture |
| Four-way reached through a buggy worker | S6 refusal |

## Verification baseline

Before S1: `devtools::test()` on `dev` gives FAIL 0, WARN 1 (the existing `test-sem-optim` and Heywood warnings), SKIP 3, about 4316 passes. Each slice states its own pass count against that baseline.

## Open items for the author

- Create `feature/native-mean-structure` (or a worktree) to start S1.
- Release channel stays GitHub-only; the 0.11.0 "experimental" target and `fixed_x` (0.9.1) are tracked in GRILL G13.
