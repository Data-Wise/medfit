# Spec: delta-method effect standard errors in `tidy()` and `confint()`

**Date:** 2026-09-23 · **Status:** approved 2026-09-23 · **Branch for implementation:**
`feature/tidy-effect-se` (worktree `~/.git-worktrees/medfit/feature-tidy-effect-se`, from `dev`)
**Decisions:** [GRILL-tidy-effect-se-2026-09-23.md](GRILL-tidy-effect-se-2026-09-23.md) D1–D7.
This spec turns those decisions into a buildable contract; where they conflict, the ledger wins
and this spec is corrected.

---

## Objective

**What:** one internal delta-method helper computes standard errors for mediation effects from an
object's `@vcov`. `tidy()` and `confint(parm = "effects")` both call it, for all four mediation
data classes (`MediationData`, `SerialMediationData`, `ParallelMediationData`,
`InteractionMediationData`).

**Why:** today `confint()` has effect SEs for three classes while `tidy()` shows `NA` for the same
rows, so `tidy(conf.int = TRUE)` and `confint()` disagree; Serial has neither; and the Simple
`confint()` TE SE is wrong (it drops Cov(ab, c'), giving 0.1273 instead of 0.1194 on the
`mediation_demo` simple fit, confirmed by a 20,000-draw parametric bootstrap SD of 0.1193).

**Users:** medfit users calling `tidy()`/`confint()` on fitted mediation objects; broom-style
pipelines (`purrr::map(fits, tidy)`). No mediationverse package consumes this output (read-only
scan, GRILL D7).

**User stories**

- As an analyst, `tidy(fit, conf.int = TRUE)` gives me a normal-approximation interval for NIE,
  NDE and TE that matches `confint(fit, parm = "effects")` exactly.
- As an analyst with a serial chain, I get path and effect SEs from `tidy()` and a working
  `confint()`, instead of `NA` plus a warning.
- As an analyst running `tidy()` over many fits, I get no warnings; the approximation is
  documented in `?tidy`.

## Assumptions (approved)

1. **Output names do not change.** `tidy()` keeps its term names (`nie`, `nde`, `te`; Serial keeps
   `d`); each existing `confint()` keeps its row names (Parallel `indirect`/`direct`/`total`,
   Interaction `nde`/`nie`/`total` and the four components). The helper works on canonical keys
   and each caller maps them. Renaming rows would be a breaking change outside D1–D7.
2. **Serial `confint()` row names** follow the Simple method: `parm = "paths"` → the names
   `paths()` and `tidy()` use (`a`, `d`, `b`, `c_prime`; for 3+ mediators the d paths are named
   by mediator pair, `d21`, `d32`, ...), while their SEs come from the `@vcov` aliases `d1..dk`
   by position; `parm = "effects"` → `nie`, `nde`, `te`. (Corrected during T5: the approved
   text said `d1..dk` for the row names.)
3. **Interaction reuses its existing gradients.** `confint(<InteractionMediationData>)` already
   builds component gradients (and uses the regmedint engine's stored `vcov` for components). The
   refactor moves that gradient construction behind the helper without changing its numbers; a
   regression test pins the current Interaction output.
4. **Parallel effect numbers are unchanged** (its `confint()` already uses a full gradient); only
   `tidy()` gains the SEs. A regression test pins current Parallel `confint()` output.
5. **Simple `confint(parm = "effects")` keeps its warning** text and its NIE/NDE values; only TE
   changes (D2).
6. `tidy()`'s `std.error` for effect rows is the helper SE; `conf.low`/`conf.high` stay
   `estimate ± z * std.error` as today.

## Tech Stack

R ≥ 4.1.0, S7 classes, `checkmate` for validation, `testthat` (3e). `lavaan` (Suggests) only in
tests, guarded by `skip_if_not_installed()`. No new dependencies.

## Commands

```r
devtools::load_all()
devtools::document()   # then revert the roxygen 8.1.0 churn: DESCRIPTION Config/roxygen2/version + NAMESPACE
devtools::test()       # sum both `failed` and `error` columns when tallying
testthat::test_file("tests/testthat/test-effect-se.R")
lintr::lint_package()  # baseline: 4 existing object_usage_linter hits in untouched files
spelling::spell_check_package()
devtools::check(cran = TRUE, args = c("--run-donttest", "--no-manual"), document = FALSE,
                env_vars = c("_R_CHECK_DEPENDS_ONLY_" = "true",
                             "_R_CHECK_SUGGESTS_ONLY_" = "true",
                             "_R_CHECK_CRAN_INCOMING_" = "true",
                             "_R_CHECK_CRAN_INCOMING_REMOTE_" = "true"))
# Expected: 0 errors / 0 warnings / 1 NOTE (Date field over a month old; same on dev)
```

## Project Structure

```
R/effect-se.R                       NEW  .effect_se() helper + per-class gradient builders
R/methods-base.R                    EDIT confint() effects branches call the helper;
                                         NEW confint(<SerialMediationData>)
R/methods-tidy.R                    EDIT tidy() effect rows (and Serial path rows) get std.error;
                                         @details documents the approximation (D3, D4)
tests/testthat/test-effect-se.R     NEW  oracles (D6), consistency, regression pins
tests/testthat/test-methods-base.R  EDIT only if an existing expectation encodes the old TE SE
NEWS.md                             EDIT New features + Bug fixes entries (D7)
man/                                     regenerated by devtools::document()
```

`R/effect-se.R` sorts after `aab-generics.R` and needs no generics, so no collation change.

## Code Style

Match `R/methods-base.R`: dot-prefixed internals, `@noRd`, explicit `stats::` namespacing,
`checkmate` at entry, snake_case. Gradients are named vectors aligned on `colnames(@vcov)`,
using the alias rows the extractors already add.

```r
#' Delta-method standard errors for mediation effects
#'
#' @param x A mediation data object.
#' @param terms Character: canonical effect keys to return (e.g. "nie", "nde", "te").
#' @return Named numeric vector of SEs, one per `terms`.
#' @keywords internal
#' @noRd
.effect_se <- function(x, terms) {
  grads <- .effect_gradients(x)            # named list: key -> gradient over colnames(x@vcov)
  checkmate::assert_subset(terms, names(grads), .var.name = "terms")
  vc <- x@vcov
  vapply(terms, function(k) {
    g <- grads[[k]][colnames(vc)]
    sqrt(drop(crossprod(g, vc %*% g)))
  }, numeric(1))
}
```

Gradients per class (parameters are `@vcov` alias names):

| Class | NIE | NDE | TE |
|---|---|---|---|
| Simple | ∂(a·b): a ↦ b, b ↦ a | c_prime ↦ 1 | NIE gradient + c_prime ↦ 1 |
| Serial | ∂(a·∏d_i·b): each factor ↦ product of the others | c_prime ↦ 1 | NIE + c_prime |
| Parallel | Σ_j ∂(a_j·b_j) | c_prime ↦ 1 | NIE + c_prime |
| Interaction | existing component/aggregate gradients from `confint(<InteractionMediationData>)` | same | same |

## Testing Strategy

All in `tests/testthat/test-effect-se.R`, on `mediation_demo` (deterministic data, no simulation
noise in the oracle comparisons except the bootstrap one).

1. **Oracle A — lavaan `:=` (exact).** For Simple, Serial and Parallel, fit the same model jointly
   in lavaan with labeled paths and `:=` definitions for the indirect/total effects; extract with
   `extract_mediation()`; the helper's SE must equal lavaan's defined-parameter SE within
   `1e-6`. `skip_if_not_installed("lavaan")`.
2. **Oracle B — parametric bootstrap (model-free).** For all four classes, the helper SE must be
   within 3% of `sd()` of `bootstrap_mediation(method = "parametric", n_boot = 20000, seed = 1)`
   for the same statistic.
3. **Consistency.** `tidy(x, conf.int = TRUE)` effect `conf.low`/`conf.high` equal
   `confint(x, parm = "effects")` (after name mapping) to `1e-12`, all four classes.
4. **Regression pins.** Simple TE SE = 0.1194 (±5e-4) on the `mediation_demo` simple fit, not
   0.1273 (D2). Parallel and Interaction `confint(parm = "effects")` match their pre-change output
   (captured before the refactor) to `1e-10`.
5. **Silence.** `expect_silent(tidy(x))` and `expect_silent(tidy(x, conf.int = TRUE))` for all
   four classes (D3); `confint()` still warns/messages as before.
6. **No PM SE (D4).** `glance()` output unchanged; `tidy()` has no `pm` row.
7. **Positive control (D6).** Temporarily flip the sign of one gradient term per class and confirm
   Oracles A and B both fail; record the transcript in the PR body, then revert.

Coverage: every new branch in `R/effect-se.R` and the new Serial `confint()` hit by tests.

## Boundaries

- **Always:** work in the feature worktree, never on `dev`; run the full test suite and the strict
  check in the worktree before the PR; report pass/fail/skip counts; revert roxygen version churn;
  US spelling; run every changed example.
- **Ask first:** renaming any existing `tidy()` term or `confint()` row; changing Interaction or
  Parallel numbers; adding a dependency; adding a `conf.method` argument to `tidy()`; touching the
  regmedint engine's stored `vcov`.
- **Never:** emit a warning or message from `tidy()` for effect SEs; add a PM SE; change
  `bootstrap_mediation()`; open an ecosystem `[BREAKING]` issue for this change; merge without an
  explicit request.

## Success Criteria

- [ ] `tidy()` returns a numeric `std.error` for every NIE/NDE/TE (and Interaction component) row
      for all four classes; Serial `tidy()` also has path SEs.
- [ ] `confint(<SerialMediationData>, parm = "paths" | "effects")` exists and matches `tidy()`.
- [ ] Simple `confint(parm = "effects")` TE SE equals the full-gradient value (0.1194 on the demo
      fit); NIE and NDE unchanged.
- [ ] Parallel and Interaction `confint()` numbers unchanged.
- [ ] Tests 1–7 pass; full suite 0 failed / 0 errors; strict check 0/0 with only the Date NOTE;
      lint adds no new hits.
- [ ] `?tidy` documents the delta-method approximation, the lm-chain block-diagonal caveat
      (one sentence), and that PM should be bootstrapped.
- [ ] NEWS: "New features" (effect SEs in `tidy()`, new Serial `confint()`) and "Bug fixes"
      (Simple TE SE) entries.

## Resolved Questions (approval, 2026-09-23)

1. `?tidy` gets one sentence on the lm serial chain's block-diagonal `vcov` across equations,
   next to the D3 approximation note.
2. `confint()` row names stay as they are (Assumption 1). Harmonizing them with `tidy()` is a
   separate, breaking decision, not part of this change.
