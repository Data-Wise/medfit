# Spec: `fit_mediation()` must apply row-level arguments to the original rows (plan T5b; Codex review finding 2)

**Date:** 2026-10-11 | **Status:** specified, not implemented | **Files:** `R/fit-glm.R`, `tests/testthat/test-missing-data.R`,
`NEWS.md`, `man/fit_mediation.Rd` | **Origin:** adversarial review of the research note; introduced by #138 (`1186698`, merged to `dev`
after the 0.7.0 release, so the regression is unreleased)

## Problem

#138 makes `fit_mediation()` drop rows that are incomplete on any variable of either formula before fitting, so both models share one
sample. It then forwards `...` to `glm()` unchanged. Arguments in `...` that describe observations were written against the *original* rows,
and glm resolves them before it drops incomplete rows (R's `?model.frame`: `subset` indexes the rows of `data`, and `na.action` is applied to
what remains). Filtering first reverses that order.

### Measured (three-variable data, n = 200, `X[1]` set to NA; same script on the commit before #138, on `dev`, and a direct `glm()`)

| Call | Before #138 | `dev` (#138) | Direct `glm()` (intended sample) |
|---|---|---|---|
| `subset = 1:50` | a = 0.4281 (rows 2:50), `n_obs` 200 | a = **0.4295** (rows 2:51), `n_obs` 199 | a = 0.4281, n = 49 |
| `subset = X > 0` (a variable also present in the caller) | a = 0.7066 | a = **0.1794** | a = 0.7066, n = 94 |
| `offset = z` (a vector of length n) | works, a = 0.3703 | **error**: `variable lengths differ (found for '(offset)')` | works |
| `offset(z)` inside the formulas | works | works (a = 0.3703, n 199) | works |
| `weights = w` with `subset = 1:50` | not measured | a = 0.5619 (rows 2:51) | a = 0.5608 |
| `subset = X > 0` with no `X` in the caller | error, `object 'X' not found` | same | works (evaluated in `data`) |

Three consequences: a `subset` that includes an incomplete row silently adds the next row (wrong estimate, wrong sample size); an expression
subset changes meaning because the caller's variable is evaluated against the filtered data; vector arguments misalign and error. The first two
are silent. `n_obs` was already `nrow(data)` for any call that used `subset` (the `.used_rows()` fallback for non-aligned models), so it also
mis-reports the sample; fixing the row mask fixes it.

## Design

Resolve every row-level argument against the **original** data, build one row mask, and apply it to all of them:

1. `keep_complete <- complete.cases(data[, vars])`, as today.
2. `subset` (if supplied): evaluated as today (eagerly, a logical or integer vector on the original rows) and converted to a logical mask of
   the original rows; `NA` entries mean not selected, as in `model.frame()`.
3. `rows <- keep_complete & subset_mask`; error with the existing message if no row remains.
4. `data <- data[rows, ]`; `weights`, `offset`, `etastart` and `mustart` are indexed by `rows` when supplied (length checked against the original
   `nrow(data)` first, with a named error on mismatch: `'offset' has length 150 but data has 200 rows`).
5. `subset` is **not** forwarded to `glm()` (it has been applied), so glm sees the final data and the aligned vectors.
6. `@data` and `@n_obs` then describe exactly the rows the models used, including under `subset`.

### Decisions and the alternatives rejected

| Decision | Alternative | Why |
|---|---|---|
| Keep accepting `subset`, `offset`, `etastart`, `mustart` | Reject them with a named error and advise `data[rows, ]` and `offset()` in the formula | Rejecting would turn arguments that worked before #138 into errors for a fix to unreleased code; the resolve-then-mask design restores every case that worked and costs a few lines. Rejection is the fallback if a future glm argument cannot be masked safely |
| Evaluate expressions eagerly, as before | Capture the unevaluated `subset` and evaluate it inside `data` (what `glm()` does) | Out of scope: before #138 `subset = X > 0` only worked by accident when the caller had an `X`; evaluating in `data` is an enhancement that changes error behavior. Record as a possible follow-up |
| One mask for `weights`, `subset`, `offset`, `etastart`, `mustart` | Special-case `subset` only | Finding 2 names `subset`, but the same reversal breaks `offset` today; one mask removes the class of bug |

## Acceptance tests (in `test-missing-data.R`, each fails on `dev` before the change)

- `subset = 1:50` with row 1 incomplete: both models equal a direct `glm(subset = 1:50)` fit (coefficients to 1e-10), `n_obs` 49.
- A logical subset, and a subset that contains only complete rows (control: unchanged result).
- `subset` evaluated against a decoy: a caller variable with the same name as a data column but different values; the test pins today's
  eager behavior so a later NSE change is visible.
- `offset = z` and `etastart` as length-n vectors with an incomplete row: equal to the direct `glm()` fit; a wrong-length vector errors by name.
- `weights` with `subset` and an incomplete row: equal to the direct weighted `glm()` fit.
- Planted defect: applying the complete-case filter before the subset (today's order) must turn the first test red.

## NEWS

Bug fix under the development version: `fit_mediation()` applies `subset`, `weights`, `offset`, `etastart` and `mustart` to the rows you passed,
then drops incomplete rows. After #138 a `subset` containing an incomplete row selected the next row instead, and a vector `offset` stopped the
fit with a length error. `n_obs` now counts the rows the models used when `subset` is given.

## Branch and release

An unreleased regression on `dev`, in the glm engine, unrelated to the SEM work: fix it on its own branch (`fix/glm-observation-level-args`) from
`dev` and merge it before the 0.8.0 release PR. It is not part of Checkpoint A.
