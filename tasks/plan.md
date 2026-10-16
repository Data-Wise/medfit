# Implementation Plan: `fixed_x` for the native SEM engine (bundled into 0.9.0)

**Status:** spec and plan approved by the author 2026-10-13; merged to `dev` as #175 (`1023520`), V1-V10 done; unreleased, DESCRIPTION still 0.8.0 (the 0.9.0 mean structure is #174, `8681083`). Open: R1 and the 0.9.0 release decision.

**Spec:** [planning/specs/SPEC-native-fixed-x-2026-10-13.md](../planning/specs/SPEC-native-fixed-x-2026-10-13.md) (draft; rules S1-S10) | **Decisions:** [GRILL-native-fixed-x](../planning/specs/GRILL-native-fixed-x-2026-10-13.md) F-G1 to F-G7 | **Older plan:** [PLAN-native-fixed-x](../planning/specs/PLAN-native-fixed-x-2026-10-13.md)
**Archived:** the finished S1-S7 plan, `planning/archive/PLAN-0.9.0-mean-structure-closed-2026-10-13.md` (+ its todo). Its two unchecked T1 follow-ups are carried below as release gates R1 and R2.
**Branch:** `feature/native-fixed-x` from `dev` (`f36658b`), created only when you ask. Squash-merge to `dev`, then the 0.9.0 release decision (release engineering bumps the version).

## Overview

Add `fixed_x = FALSE | TRUE | <names>` to `fit_sem()` and, through `engine_args`, `fit_mediation(engine = "native")`. Selected exogenous observed variables have mean, variance and covariances fixed at the sample moments and leave estimation; structural estimates, SEs, df, chi-square stay the same; logLik/AIC/BIC become conditional; comparisons across fixed sets or data are refused. Ships inside 0.9.0, so the 0.9.0 tag waits for this plan's checkpoints and R1-R2.

## Architecture decisions

- **One RAM, fixed entries.** A fixed-x row becomes a *fixed value* in the RAM (`s0`, `m0`), not a free parameter, flagged `fixed_x` in the parameter table (separate from a user `0*`, which stays a restriction). `ram$q` shrinks, so the optimizer, information and gates see fewer parameters; that is where the speed comes from.
- **Moments leave with the parameters (T-1).** `.sem_moments(ram)` subtracts the number of exogenous moment parameters that became fixed (`ram$n_fixed_x`), so `.sem_df()` is unchanged. Cross-covariances between an exogenous and an endogenous variable are not parameters and are not touched.
- **Values come late.** The exogenous set is known from the completed table; the values need the listwise-complete sample. Flag the rows in `.sem_complete()` (no data needed), assign the values after `.sem_sample()` in `.sem_fit_syntax()`. This keeps `.sem_complete()` data-free, and `fixed_x = FALSE` takes the old path untouched (frozen gate).
- **Exogenous set from the completed model** (`ram$ov_x`), so product columns qualify and 0.10.0's `:` term inherits the rule.
- **Visibility:** table/tidy/summary show fixed rows (est = sample moment, se NA); `theta`, `vcov`, `coef()`, npar, df exclude them.
- **Comparisons:** one helper, `.sem_fixed_signature(fit)` (sorted fixed names + a data fingerprint), used by `anova()`, `mbco_sem()` and new `AIC()`/`BIC()` S3 methods for `medfit::SEMFit`.
- **Scale:** the shifted route (`.sem_shift_ok()`) keeps allowing fixed-x intercept rows (value maps to 0 on centered data).

## Dependency graph

```
R0 lavaan probe ──────────────┐
V1 argument + errors (S1,S5) ─┼─> V2 TRUE, covariance-only, end to end (S2-S4,S6 partial) ──> CHECKPOINT F-A
                              │        │
                              │        ├─> V3 subsets + pairing (S1,S4)
                              │        ├─> V4 mean structure + conditional logLik (S7)
                              │        └─> V5 scale sweep (S10)         [V3-V5 independent of each other]
                              │                 │
                              └─────────────────┴─> V6 weights, sandwich, missing rows
                                                    V7 comparisons refused (S8)
                                                    V8 plumbing + visibility (fit_mediation, branches, MBCO refit, S6)
                                                    ──> CHECKPOINT F-B
                                                    V9 evidence gate, timing table, OpenMx, mutants
                                                    V10 docs + NEWS + strict check ──> CHECKPOINT F-C ──> R1, R2 ──> 0.9.0 release decision
```

## Task list

### Phase 0: groundwork
- **R0 (XS)** Probe lavaan 0.7.2 for `y ~ x + ... ; x ~~ x` with `fixed.x = TRUE` (error, override or keep free); record the answer in the GRILL open questions. Resolves spec open question 1.
- **V1 (S)** `fixed_x` argument: `fit_sem()` signature + roxygen, `.sem_resolve_fixed_x()` (logical or names; non-exogenous names error naming them), explicit-statement error (S5), tie-to-structural error; the resolved set stored in `SEMFit@internals`; `fixed_x = FALSE` changes nothing.

### Phase 1: the core path
- **V2 (M)** `fixed_x = TRUE`, covariance-only, simple model, end to end: completion adds flagged fixed rows, values assigned after `.sem_sample()`, `.sem_to_ram()` fixes them, `.sem_moments()` subtracts `n_fixed_x`, table/theta/vcov/npar per S6. Estimates and SEs equal the free fit; df equals the free fit's.
- **Checkpoint F-A:** lavaan `fixed.x = TRUE` parity (table rows, npar, df 1, chi-square 9.188694, reference model); frozen gate bit-identical with `fixed_x = FALSE`; planted defect `countrestrict` fails; full suite green.

### Phase 2: breadth (V3, V4, V5 independent; any order)
- **V3 (S)** Subsets and pairing: names select any subset (incl. a product column); free pairs among unselected variables added even with explicit `~~` rows (T-2); every subset of {x, c1, c2} equals the free fit. Planted defect `droppair`.
- **V4 (M)** Mean structure: fixed means; logLik conditional on the fixed block; `glance()$fixed_x`; print/summary note "logLik is conditional on: ...". Planted defect `jointlik`; lavaan conditional logLik parity.
- **V5 (S)** Scale: `.sem_shift_ok()` allows fixed-x intercept rows; location sweep (mean/sd 0 to 1e5) with `TRUE` and with a subset. Planted defect `noshift`.

### Phase 3: robustness and guards
- **V6 (M)** Weights (weighted moments), sandwich SEs, missing rows (listwise): subset invariance holds for model-based and sandwich SEs, weighted and unweighted.
- **V7 (M)** Comparisons refused (S8): `.sem_fixed_signature()`; `anova()` and `mbco_sem()` error across different fixed sets or data; new `R/methods-aic.R` with `AIC()`/`BIC()` S3 methods registered for `medfit::SEMFit` (multi-fit calls error naming the difference; single fit unchanged); documented dispatch limit. Negative tests for both causes, positive for the same set; planted defect `aicwarnonly`.
- **V8 (S)** Plumbing and visibility: `fit_mediation(engine_args = list(fixed_x = ))`, `.sem_fit_branches()` (pass by name), `mbco_sem()` refit, `extract_mediation()` unchanged; `tidy()`/`summary()` fixed-row display (S6).
- **Checkpoint F-B:** all of S1-S10 covered by a passing test; the five planted defects each fail the right test; full suite and lint green; strict check clean.

### Phase 4: evidence and docs
- **V9 (M)** `tests/sim/sem-fixed-x-gate.R` (subset invariance, lavaan parity, scale, OpenMx) with `MUTANT` switches; the 30-covariate timing table on the real build (reported, not gated); `acceptbad` defect.
- **V10 (S)** Docs: NEWS (behavior note + measured ratio only), `?fit_sem`, `?"medfit-syntax"` (incl. R0's lavaan difference), `model-native.qmd`, `native-guide.qmd`, `lavaan-comparison.qmd` row, CLAUDE.md Engines row, `.STATUS`; doc-currency check; spelling, urlchecker, strict `R CMD check`.
- **Checkpoint F-C:** doc-currency report; strict check 0/0/0; CI green; merge decision with you.

### 0.9.0 release gates (carried from the archived plan)
- **R1 (S)** Say whether the 1e-12 frozen tolerance is relative; confirm the fixture on the ubuntu CI BLAS.
- **R2 (S)** `.sem_seed()` must not hash the `m` vector when the mean flag is off; add a frozen retry case.

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Fixed moments counted as restrictions (df moves) | High | `n_fixed_x` in `.sem_moments()`; df equality test on every V; planted defect `countrestrict` |
| Pairing rule silently drops `c1 ~~ c2` | High | V3 test with explicit `~~` rows; `droppair` defect |
| Frozen values change for `fixed_x = FALSE` | High | T1 gate rerun after every edit to `.sem_eval`, `.sem_df`, `logLik`, `.sem_complete` |
| Scale protection lost under `fixed_x = TRUE` | Med | V5 sweep, `noshift` defect |
| AIC across fixed sets returns a number | Med | V7 S3 methods + negative tests; dispatch limit documented |
| Values depend on data, completion is data-free | Med | flag early, assign after `.sem_sample()`; decided in V2 against the frozen gate |
| Speed claim does not reproduce | Low | measured table only; no promise in NEWS until measured |
| Explicit-statement behavior differs from lavaan | Low | R0 probe; error regardless (S5) |

## Open questions

- R0's answer (lavaan with an explicit `x ~~ x` under `fixed.x = TRUE`).
- Exact wording of the S8 refusal message (set in V7).
- Whether V3-V5 run as one session or three (they are independent; the harness comes first, see the spec's testing table).
