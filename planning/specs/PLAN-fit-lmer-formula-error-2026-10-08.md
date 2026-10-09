# PLAN: clear error for random-effect terms in `fit_mediation(engine = "lmer")` formulas

**Date:** 2026-10-08 · **Status:** APPROVED 2026-10-08 (author) · **Branch:** `feature/lmer-formula-error` off `dev` (R code, so not on `dev`)
**Origin:** the refcard's fresh-context trial (PR #94): an agent wrote `Y ~ X + M + (1 | school)` and got `Invalid grouping factor specification, 1 | school` plus a stray `'|' not meaningful for factors` warning.
**Size:** one small PR, about 30 minutes.

## 1. Problem (reproduced 2026-10-08)

`fit_mediation(engine = "lmer", cluster = "school")` builds both models itself and adds the random cluster intercept (`R/fit-lmer.R`, `.lmer_outcome_formula`, `.lmer_mediator_formula`). A formula that already contains `(1 | school)` is not rejected: `terms()` returns `1 | school` as an ordinary term label, the outcome rewrite passes it through as a fixed term, and `lmer()` fails on it with an lme4 message that names neither the cause nor the remedy.

## 2. Decisions

| # | Decision | Recommendation and reason |
|---|---|---|
| F1 | Reject, do not strip | **Error.** Silently dropping the user's random terms would hide that their model differs from the one fitted (for example `(M | school)` is a random slope, which has its own route). The error says where to put each thing. |
| F2 | Detector | A small base-R walk over the formula that finds `(` calls wrapping a `|` or `||` call, plus a top-level `|` on the right-hand side. **Not** `lme4::findbars()`: it is deprecated in lme4 (moved to `reformulas`) and flags `I(a | b)`, a legitimate logical-OR covariate (probed 2026-10-08). |
| F3 | Where | Top of `.fit_mediation_lmer()`, before the data checks, on `formula_y` and `formula_m` separately, so the message names which formula. |
| F4 | Message | `` `formula_y` contains the random-effect term `(1 | school)`. engine = "lmer" adds the random cluster intercept itself; write fixed effects only (`Y ~ X + M`). For a random slope use `engine_args = list(random_y = ~ M)`. `` (same shape for `formula_m` and `random_m`). |
| F5 | Scope | `fit_mediation()` only. `extract_mediation()` takes the user's own `lmer` fits, so random terms there are expected. No change to behavior for valid input. |

## 3. Tasks

- [ ] **T1: Detector and check** in `R/fit-lmer.R` (`.formula_random_terms()` plus the call in `.fit_mediation_lmer()`).
- [ ] **T2: Tests** in `tests/testthat/test-cluster-211.R`: error for `(1 | school)` in `formula_y`, in `formula_m`, for `(M | school)`, and for `(1 + M || school)`; message names the formula and the offending term and points at `engine_args`; **no false positive** for `I(a | b)` as a covariate; plain formulas unchanged (the existing route-identity tests). **Mutation:** with the check disabled, the new tests fail.
- [ ] **T3: Docs.** One sentence in the `engine = "lmer"` item of `?fit_mediation` ("formulas hold fixed effects only; the random cluster intercept is added for you; random slopes via `engine_args`"); regenerate Rd; NEWS bullet under the development version.
- [ ] **T4: Gates and PR.** Full suite in the worktree, `lint_package()`, strict CRAN check, spelling. E2E transcript: the failing call before (error text above) and after (new message), and a valid call still returning the same NIE.

## 4. Acceptance criteria

1. The reproduced call errors with the F4 message, once, with no stray `|` warning (the check runs before any model code).
2. `I(a | b)` in a formula is not rejected by this check.
3. Valid calls give identical objects to `dev` (route-identity tests unchanged).
4. Full suite 0 failures, lint 0, strict check 0/0/0, CI green.

## 5. Out of scope

A list of other lme4 error messages to translate; random terms in `extract_mediation()`; the refcard row (already says "plain formulas, no `(1 \| id)`").
