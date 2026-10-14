# SPEC: `fixed_x` for the native SEM engine

| | |
|---|---|
| **Date** | 2026-10-13 |
| **Status** | APPROVED by the author 2026-10-13 (implemented on `feature/native-fixed-x`, PR #175) |
| **Inputs** | [PLAN-native-fixed-x-2026-10-13.md](PLAN-native-fixed-x-2026-10-13.md), [GRILL-native-fixed-x-2026-10-13.md](GRILL-native-fixed-x-2026-10-13.md) (F-G1 to F-G7), RMediation's proposal (read-only) |
| **Release** | bundled into 0.9.0 (F-G1); the 0.9.0 tag waits for checkpoints F-A and F-B |
| **Evidence labels** | **[V]** verified by a command in this repo; **[A]** assumption, correct me |

## Assumptions

1. **[V]** 0.9.0 mean structure is merged to `dev` (#174 `8681083`); `DESCRIPTION` is 0.8.0; no 0.9.0 tag.
2. **[A]** "Exogenous observed variable" means `ram$ov_x` as `R/sem-model.R` computes it: an observed variable that appears as a predictor and is never an outcome or an indicator. Product columns are ordinary data columns, so they qualify.
3. **[A]** The fixed values come from the estimation sample after listwise deletion, ML denominator `n`, case-weighted when `weights` are used.
4. **[A]** Latent exogenous variables, non-Gaussian likelihoods and a default of `TRUE` are out of scope (revisit at 1.0).
5. **[V]** Native `standardized = TRUE` is unsupported, so the standardized-SE effect of `fixed.x` reaches no medfit output.
6. **[A]** `AIC()`/`BIC()` for `SEMFit` currently reach `logLik()` through base R's default methods; the guard needs S3 methods registered for `medfit::SEMFit`.

## 1. Objective

Add `fixed_x = FALSE | TRUE | <character vector>` to `fit_sem()` and, through `engine_args`, to `fit_mediation(engine = "native")`. Selected exogenous observed variables have their mean (when a mean structure is on), variance and every covariance touching them fixed at the sample moments and removed from estimation. Why: lavaan parity (`fixed.x = TRUE` table, npar, conditional logLik), speed with many covariates, and RMediation's CRAN-hold prerequisite.

**Users:** applied researchers fitting mediation models with many covariates; the RMediation, probmed and medrobust maintainers who compare against lavaan.

**What does not change:** structural estimates and their model-based and sandwich SEs, df, chi-square, `anova()` results for same-set fits, and every `fixed_x = FALSE` value (the T1 frozen gate).

### Semantics (locked)

| Rule | Statement |
|---|---|
| S1 selection | `TRUE` selects every exogenous observed variable, product columns included; names select any subset, a product column too. The set is computed from the completed model, not the raw syntax. Names that are not exogenous observed variables error, naming them. |
| S2 what is fixed | Per selected variable: its mean, its variance, and every covariance touching it (also with unselected exogenous variables). |
| S3 not restrictions | Fixed-x rows leave both the moment count and the parameter count; df, `anova()` and `mbco_sem()` are unchanged. A user `0*` stays a restriction (separate flag). |
| S4 pairing | Completion adds the free covariances among the unselected exogenous variables itself, even for variables with explicit `~~` rows. |
| S5 explicit statements | A user statement that touches a selected variable's moments (`x ~~ v*x`, `x ~ 1`, a shared label, a constraint or `:=` on them) errors naming the term. |
| S6 visibility | Fixed rows stay in `@table`, `tidy()` and `summary()` (flag column `fixed_x`, `est` = the sample moment, `se` NA); absent from `theta`, `vcov`, `coef()`, npar and df. |
| S7 likelihood | logLik, AIC and BIC are conditional on the fixed block (as lavaan). `glance()$fixed_x` lists the fixed names (empty when none); `print()` and `summary()` print "logLik is conditional on: ...". |
| S8 comparisons | `anova()`, `mbco_sem()` and multi-fit `AIC()`/`BIC()` error when the fixed sets or the estimation data differ, naming the difference; same-set fits compare. |
| S9 default | `FALSE` at both entry points. |
| S10 scale | The shifted route (`.sem_shift_ok()`) stays allowed for fixed-x intercept rows; `fixed_x = TRUE` keeps the 0.9.0 scale protection. |

## 2. Commands

```bash
Rscript -e 'devtools::load_all(); devtools::test(filter = "sem-fixed-x")'      # the new tests
Rscript -e 'devtools::test(reporter = "summary")'                               # full suite
Rscript tests/sim/sem-fixed-x-gate.R                                            # new gate (SEEDS=5 default)
MUTANT=countrestrict Rscript tests/sim/sem-fixed-x-gate.R                       # each planted defect must exit 1
Rscript -e 'devtools::document()'                                               # after roxygen edits
Rscript -e 'devtools::check(cran = TRUE, args = "--run-donttest", env_vars = c("_R_CHECK_DEPENDS_ONLY_" = "true", "_R_CHECK_SUGGESTS_ONLY_" = "true"))'
```

## 3. Project structure

```
R/sem-model.R        .sem_complete(): resolve the fixed set, add fixed-x rows (flag), pair free unselected covariances
R/sem-fit.R          .sem_fit_syntax(), .sem_fit_branches(): pass fixed_x by name; assign fixed values after .sem_sample()
R/sem-ml.R           RAM: fixed-x entries are fixed values, not parameters; .sem_df()/.sem_moments() exclusion
R/methods-sem.R      logLik (conditional), glance(), print/summary note, .sem_n_free()
R/sem-anova.R        same-fixed-set and same-data refusal
R/sem-mbco.R         refit carries fixed_x
R/fit-sem.R          fit_sem(fixed_x =) and roxygen; R/fit-glm.R engine_args text for fit_mediation
R/sem-syntax-help.R  ?"medfit-syntax": the fixed_x paragraph and the lavaan-difference text
R/methods-aic.R      (new) AIC()/BIC() S3 methods for medfit::SEMFit, registered in zzz.R / NAMESPACE
tests/testthat/test-sem-fixed-x-*.R   unit tests (args, completion, counts, logLik, comparisons, plumbing, parity)
tests/sim/sem-fixed-x-gate.R          subset-invariance, lavaan parity, scale sweep, timing table, mutants
vignettes/articles/  model-native.qmd, lavaan-comparison.qmd, native-guide.qmd (text); NEWS.md; CLAUDE.md Engines row
```

## 4. Code style

Match the surrounding R: tidyverse style, `snake_case`, native pipe, 120-column lines (lintr, CI-enforced), `checkmate` validation at function entry, `stop(..., call. = FALSE)` with messages naming the offending term, US English. Internal helpers start with `.sem_`. Example, the validation shape to copy:

```r
.sem_resolve_fixed_x <- function(fixed_x, ram) {
  checkmate::assert(
    checkmate::check_flag(fixed_x),
    checkmate::check_character(fixed_x, any.missing = FALSE, min.len = 1L, unique = TRUE),
    .var.name = "fixed_x"
  )
  if (isTRUE(fixed_x)) return(ram$ov_x)
  if (isFALSE(fixed_x)) return(character())
  bad <- setdiff(fixed_x, ram$ov_x)
  if (length(bad)) {
    stop("`fixed_x` names variables that are not exogenous observed variables of the model: ",
         paste(bad, collapse = ", "), call. = FALSE)
  }
  fixed_x
}
```

## 5. Testing strategy

Framework: testthat 3e, `devtools::test()`; every numeric claim against an independent oracle, every guard with a planted defect (`sem_mutate()` in `tests/testthat/helper-sem.R`).

| Level | What | Oracle |
|---|---|---|
| Unit | argument forms, error messages (S1, S5), flag vs user `0*`, pairing (S4), df/npar/logLik counts, S6 visibility, S8 refusals, plumbing (`.sem_fit_branches`, MBCO refit, `fit_mediation`) | exact values, message regexes |
| Parity | `fixed_x = TRUE` vs lavaan `fixed.x = TRUE`: table rows, npar, df 1, chi-square 9.188694 on the reference model, conditional logLik | lavaan 0.7.2 (skip if absent) |
| Subset invariance | every subset of {x, c1, c2}: estimates and SEs equal the free fit, model-based and sandwich, weighted, one dataset with missing rows | the free `fit_sem()` fit; lavaan with explicit numeric values plus the df/logLik correction; OpenMx |
| Scale | location sweep (mean/sd 0 to 1e5) with `fixed_x = TRUE` and with a subset | the same fit at location 0 |
| Frozen | `fixed_x = FALSE` bit-identical to 0.9.0 values | the T1 fixture |
| Timing | 30-covariate table on the real build (n, hardware, free parameters before and after); reported, not gated | wall clock |

**Planted defects, each named and each caught:** `countrestrict` (fixed moments counted as restrictions: df moves), `droppair` (free covariance among unselected variables dropped), `jointlik` (joint instead of conditional logLik), `acceptbad` (a non-exogenous or tied variable accepted), `aicwarnonly` (AIC across fixed sets returns a number), `noshift` (the scale route lost under `fixed_x`).

## 6. Boundaries

- **Always:** run the full suite and the frozen gate after any edit to `.sem_eval`, `.sem_df`, `logLik` or `.sem_complete`; write the failing test first; verify against lavaan or OpenMx, not against medfit's own output; keep US English; lint at 120 columns.
- **Ask first:** adding a dependency; changing the default of `fixed_x`; changing any `fixed_x = FALSE` value; a new exported function; touching `DESCRIPTION` Version (release engineering's).
- **Never:** count a fixed exogenous moment as a restriction; fix moments tied to a structural parameter (error instead); silently drop an explicit user statement; merge or push to `main`; remove a failing test without approval; edit another repository (RMediation's files are read-only inputs).

## 7. Success criteria

1. `fit_sem(..., fixed_x = TRUE)` matches lavaan `fixed.x = TRUE` on the reference model: same rows, npar, df, chi-square 9.188694, conditional logLik (tolerance 1e-6).
2. For every subset of the three exogenous variables, structural estimates equal the free fit to 1e-8 and model-based and sandwich SEs to 1e-6, with and without weights and missing rows.
3. All five planted defects fail the right test; the gate exits 1 under each `MUTANT`.
4. `fixed_x = FALSE` results are bit-identical to the 0.9.0 frozen fixture.
5. S5 and S8 errors fire with the stated wording for each cause (selected-variable statement; different fixed set; different data) and do not fire for same-set fits.
6. The location sweep to mean/sd 1e5 accepts every fit with `fixed_x = TRUE` and with a subset.
7. A timing table for 30 covariates is recorded; NEWS quotes only the measured ratio.
8. `devtools::test()` has 0 failures; the strict `R CMD check` is 0 errors, 0 warnings, 0 notes; lint is clean; spelling and URL checks are clean.
9. Docs updated: NEWS, `?fit_sem`, `?"medfit-syntax"`, the native vignettes, the lavaan-comparison row, the CLAUDE.md Engines row; doc-currency check run.

## 8. Open questions

1. **lavaan's behavior for an explicit `x ~~ x` under `fixed.x = TRUE`** was not verified; check once with lavaan 0.7.2 before F1 and record any difference in `?"medfit-syntax"` (S5 errors regardless).
2. **Ordering inside the fit:** fixed values need the listwise-complete rows' moments, which need the observed set from the completed table. Choose between assigning the values after `.sem_sample()` or computing the observed set first, whichever keeps the frozen gate bit-identical.
3. **Message wording** for S8 (the exact text naming the difference) is set at F5.
