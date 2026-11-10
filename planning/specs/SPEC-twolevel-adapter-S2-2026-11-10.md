# Spec: slice S2, lavaan two-level adapter and `TwoLevelMediationData` (issue #394)

**Date:** 2026-11-10 · **Status:** DRAFT for the maintainer; nothing implemented, no PR, nothing posted ·
**Controls:** [PLAN-multilevel-mediation-2026-11-10.md](PLAN-multilevel-mediation-2026-11-10.md) section 0 (decisions Q1-Q11 and S1-Q1..Q4 are closed there) ·
**Evidence:** [RESEARCH-multilevel-mediation-2026-11-10.md](RESEARCH-multilevel-mediation-2026-11-10.md) ·
**Base:** `origin/dev` at `ca4b247f` (S0 guard merged, PR #395). File and line references below are to that tree.

Scope: one treatment X (level 1 with a between part), one mediator M, one outcome Y, observed variables, linear, a lavaan two-level
fit given by the user. No native fitter (S4), no latent mediators (S5), no product terms, no cluster-level treatment (that is
`ClusterMediationData`, 2-1-1).

## 1. Behavior in one page

```r
fit <- lavaan::sem(model, data = d, cluster = "id")           # level: 1 / level: 2 blocks
td  <- extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y")   # TwoLevelMediationData
nie(td)                      # within a_w*b_w (default)
nie(td, level = "between")   # a_b*b_b
nie(td, level = "contrast")  # a_w*b_w - a_b*b_b  (descriptive, not a test)
tidy(td); confint(td); summary(td)
bootstrap_mediation(twolevel_statistic(fit, "nie_between"), method = "nonparametric",
                    data = d, cluster = "id", n_boot = 500)
```

Estimand (Q3): fixed slopes (`sigma_ab = 0`), between effects through **latent cluster means** (lavaan's two-level parameterization), per level
`NIE_l = a_l b_l`, `NDE_l = c'_l`, `TE_l = NIE_l + c'_l`, `PM_l = NIE_l / TE_l`; contrast `NIE_w - NIE_b`. No cross-level total or proportion.

## 2. Class `TwoLevelMediationData` (new file `R/classes-twolevel.R`; collate after `classes.R`)

One class for the adapter and the later native fitter (Q2); `source` says which. Properties (snake_case, scalar unless noted):

| Group | Property | Type | Notes |
|---|---|---|---|
| Paths | `a_within`, `b_within`, `c_prime_within` | numeric | always finite |
| | `a_between`, `b_between`, `c_prime_between` | numeric | `NA_real_` when `between_identified` is FALSE |
| Parameters | `estimates` | named numeric | the **identified** path rows, in the order above |
| | `vcov` | matrix | same rows and columns, sub-block of the fit's **joint** vcov, extracted by free-parameter index (section 3) |
| | `parameter_table` | data.frame | one row per path row: `path`, `level`, `lhs`, `op`, `rhs`, `label`, `free` (index), `est`, `se`; provenance and audit |
| Variables | `treatment`, `mediator`, `outcome`, `cluster` | character | |
| Design | `n_obs`, `n_clusters` | integer | from the fitted object (FIML keeps all rows, listwise fewer) |
| | `cluster_sizes` | integer vector | length `n_clusters`, sums to `n_obs` for complete data; for FIML sums to the rows lavaan used |
| Diagnostics | `icc` | named numeric | `Sigma_B / (Sigma_B + Sigma_W)` per variable at both levels (section 5) |
| | `between_identified` | logical | S1-Q1 |
| | `admissible` | logical | `lavaan::lavInspect(fit, "post.check")` (Q8: flag, warn) |
| | `converged` | logical | |
| | `cross_level_equal` | character | names of paths equated across levels (empty if none), S1-Q3 |
| | `fixed_paths` | character | names of path rows with `free == 0` (variance 0 in `vcov`) |
| Provenance | `source` | character | `"lavaan"` here, `"native"` later |
| | `fixed_x`, `information`, `h1_information`, `se_type`, `estimator`, `missing` | logical / character | read from the fit, never refit (S1-Q2) |
| | `lavaan_version`, `call` | character | `as.character(utils::packageVersion("lavaan"))`; `call` is `paste(deparse(fit@call), collapse = " ")` |
| | `between_parameterization` | character | `"latent"` (Q3); `"manifest"` reserved |
| Data | `data` | data.frame or NULL | the data lavaan holds, only if cheap; else `NULL` |
| | `source_package` | character | `"lavaan"` |

Validator (mirrors `ClusterMediationData`, `R/classes.R:1937`): scalars non-missing; `n_clusters == length(cluster_sizes)`, at least 2
clusters; `nrow(vcov) == ncol(vcov) == length(estimates)`; unique names and `identical(dimnames(vcov), names(estimates))`; alias rows present: the
three within rows always, the three between rows **iff** `between_identified`; when FALSE the between properties are `NA_real_`, the between
rows are absent from `estimates` and `vcov`, and `cross_level_equal` is empty; alias rows equal the path properties to 1e-12; `vcov` finite;
`icc` values in [0, 1]; `source %in% c("lavaan", "native")`. `S4_register(TwoLevelMediationData)` in `R/zzz.R` before `methods_register()` (the
list at `R/zzz.R:59-69`); `print` through `.onLoad` like the other classes. Within-only objects keep `estimates`/`vcov` to three rows so
`MASS::mvrnorm` in the parametric bootstrap never sees `NA`.

## 3. Extraction

**Entry point.** The lavaan method of `extract_mediation()` (`R/extract-lavaan.R:131`): where it now calls
`.assert_lavaan_single_level(object)` and `.assert_lavaan_single_group(object)` (`:144-145`), branch on `lavInspect(object, "nlevels")`:
`== 1` unchanged; `== 2` to `.extract_lavaan_twolevel()`; `> 2` keeps `medfit_error_lavaan_multilevel` (three-level fits stay refused).
`ngroups > 1` keeps `medfit_error_lavaan_multigroup`. The S0 test that a *two-level* fit errors flips to "returns `TwoLevelMediationData`"; its
three-level and multigroup cases stay as errors.

**Arguments** (all `extract_mediation()` arguments already exist; the adapter honors a subset):

| Argument | Behavior for a two-level fit |
|---|---|
| `treatment`, `mediator`, `outcome` | required strings (`outcome = NULL` allowed only if exactly one endogenous non-mediator variable exists at level 1); one mediator only, else `medfit_error_twolevel_unsupported` |
| `a_label`, `b_label`, `cp_label` | **ignored** (keying is by parameter-table row, never by label); a non-default value warns once |
| `standardized` | `TRUE` errors, `medfit_error_twolevel_standardized` (S1-Q4) |
| `interaction`, `m_star`, `decomposition`, `structure` | `interaction` non-NULL or a `:` term in any `~` row: `medfit_error_twolevel_product` (Q5); the others do not apply and error if set |
| `...` | `rlang::check_dots_used()` as elsewhere |

**Parameter-table keying** (`.twolevel_key_rows()`, a named internal function so a test can replace it with a planted defect). From
`pt <- lavaan::parTable(object)` select, for `level in 1:2` (1 = within, 2 = between in lavaan) and `op == "~"`: `a` = `lhs == M, rhs == X`;
`b` = `lhs == Y, rhs == M`; `cp` = `lhs == Y, rhs == X`. Exactly one row per path and level, else `medfit_error_twolevel_path_missing` (a path
absent at one level is not assumed 0). Rows with `free == 0` are accepted (fixed value, variance 0, listed in `fixed_paths`). Each row's key is
its **free-parameter index** `pt$free`. The joint vcov is `V <- lavaan::vcov(object)`; the 6x6 (or 3x3) sub-block is
`V[idx, idx]` with `idx` the free indices **by position, not by name** (duplicate column names are possible when a label is shared across
levels). Names are assigned afterwards from the path names (`a_within`, ... ). When two paths share an index the sub-block simply
repeats that row and column (correlation 1), which is the correct covariance of an equated parameter. The implementer must pin the exact lavaan
representation of cross-level equality (shared index vs `==` rows) with the finding-3 fixture (`m ~ a*x` at both levels) in the first PR; both are handled
below. A fixed row (`free == 0`) contributes a zero row and column.

**Cross-level equality** (S1-Q3): a path pair is equated if (i) the within and between rows share a non-zero free index, or (ii) share a non-empty
label, or (iii) a `==` row of the table names both labels (or their `plabel`s). Record the equated names in `cross_level_equal`; effects at each
level keep their value and SE; `nie(level = "contrast")`, `tidy`, `confint` report the contrast **`NA`** and signal the classed warning
`medfit_warning_twolevel_constrained` (the contrast is identically zero by constraint when all of a, b are equated).

**Between identification** (S1-Q1; section 5 for the thresholds). The adapter sets `between_identified`; when FALSE the object is **within-only**:
between properties `NA_real_`, rows dropped, and one warning of class `medfit_between_unidentified` at extraction; the accessors for between
effects and the contrast return `NA_real_` with the same condition (never an error, never `0 +/- 0`).

**Small J** (Q7, PLAN 0.4): warn `medfit_warning_twolevel_few_clusters` below 50 clusters (cites the J = 20 evidence: 27% `post.check` failures,
`ab` coverage 0.908); the adapter never errors on J. Constants live in one place (`.twolevel_defaults`), editable by `options(medfit.twolevel_min_clusters = )`.

**Admissibility** (Q8): `post.check` FALSE gives `admissible = FALSE` and the warning `medfit_warning_twolevel_inadmissible`.

**Non-convergence** (S1-Q1 lists it as a trigger): see question 1 in section 14; proposed: `converged = FALSE` gives within-only **only if** the within
block of the vcov is finite and positive definite; otherwise `medfit_error_twolevel_unusable`.

**Missing data** (Q6): lavaan's `missing = "fiml"` passes through; `n_obs` and the cluster counts come from `lavInspect(fit, "nobs")` and `"nclusters"` /
`"cluster.size"` on the fitted object (to be verified against lavaan 0.7.3 and the supported floor).

**Detection regression tests** (PLAN 0.3): a `cluster = "id"` single-level fit (`nlevels == 1`, `nclusters == 1`) still extracts as a
single-level cluster-robust fit and returns `MediationData`; a two-level fit returns the new class. A treatment or mediator present at only one
level (cluster-level X: the 2-1-1 design) errors, `medfit_error_twolevel_unsupported`, with a message that names `engine = "lmer"`.

## 4. Effects, gradients and the joint covariance

Parameter vector `theta = (a_w, b_w, c_w, a_b, b_b, c_b)`; `V` its joint 6x6 sub-block (the off-diagonal `Cov(a_w, a_b)` etc. is carried, not
zeroed). Gradients (named over the alias rows) in `.effect_gradients_twolevel()` (new, in `R/effect-se.R`, wired into the dispatch at `:177`
before the `MediationData` branch, as the cluster class is):

| Term | Estimate | Gradient over theta |
|---|---|---|
| `nie_within` | `a_w b_w` | `(b_w, a_w, 0, 0, 0, 0)` |
| `nie_between` | `a_b b_b` | `(0, 0, 0, b_b, a_b, 0)` |
| `nie_contrast` | `a_w b_w - a_b b_b` | `(b_w, a_w, 0, -b_b, -a_b, 0)` |
| `nde_within`, `nde_between` | `c_w`, `c_b` | unit vectors |
| `te_within`, `te_between` | `a b + c` per level | `nie` gradient plus the unit vector |
| `pm_within`, `pm_between` | `nie / te` per level | `(te * g_nie - nie * g_te) / te^2` (quotient rule); `NA` when `|te|` < `.Machine$double.eps` (as `pm` for cluster, `R/generics-effects.R:705`) |

SE `= sqrt(g' V g)` through the existing `.gradient_var()` (`R/effect-se.R:108`); within-only objects have no between terms and
`.effect_se_or_na()` returns `NA` for them. For a path, `.path_se()` (`:135`) reads the alias rows. All intervals are Wald-normal (delta
method); there is no small-J t correction in S2 (documented).

**Generics** (the existing generics take `x, ...`; the new methods add `level`, which is allowed because the generics carry `...`):

| Call | Returns |
|---|---|
| `nie(x)` / `nie(x, level = "within")` | scalar `mediation_effect`, type `"nie"` (within is the default, Q4) |
| `nie(x, level = "between" | "contrast")` | scalar `mediation_effect` (`NA_real_` plus the classed condition when unidentified or constrained) |
| `nie(x, level = "both")` | length-2 named `mediation_effect` (`within`, `between`); the contrast is **not** included |
| `nde`, `te`, `pm` with `level = "within" | "between" | "both"` | as above; `level = "contrast"` is **not** accepted (classed error); only `nie` has a first-class contrast (question 9) |
| `paths(x)` | named numeric `c(a_within, b_within, c_prime_within, a_between, b_between, c_prime_between)`; between entries `NA` when within-only |
| `decompose(x)` | named numeric `c(within = , between = , contrast = )` of the NIE, **no SE**, `attr(, "label") = "descriptive; the contrast is not a test"` (the existing `decompose` contract, `R/generics-effects.R:737`) |

**Base methods** (`R/methods-base.R`, modeled on `:689-780`): `coef(x, type = c("paths", "effects", "all"))`; `vcov(x)` (the path block);
`nobs(x)` (`n_obs`); `confint(x, parm = "paths" | "effects" | <names>, level = 0.95)` Wald. `tidy(x, type = c("all", "paths", "effects"),
conf_int = FALSE, conf_level = 0.95)` through `.tidy_paths_effects()` with an effects vector from `.twolevel_effect_vec()` (the nine terms above plus
`nie_contrast`), and `glance(x)` one row: `nie_within`, `nie_between`, `nie_contrast`, `n_clusters`, `nobs`, `converged`, `between_identified`,
`admissible`. `print()` shows the design (`J` clusters, sizes, ICCs), the six paths, the within and between NIE and the contrast labeled
descriptive; `summary()` adds SEs, the stored provenance (`fixed_x`, `information`, `h1_information`, `estimator`, `missing`, lavaan version),
the assumptions block (fixed slopes, latent cluster means, no products, no between-level confounding beyond the model), and any flags
(`cross_level_equal`, `fixed_paths`, within-only). `summary()` states, for `fixed_x = TRUE`, that between-path SEs are conditional on the
sample between moments and 3-4% narrower than under `fixed.x = FALSE` (S1-Q2).

## 5. Between-identification diagnostics (S1-Q1)

`.twolevel_identification(fit, X, M)`:

1. ICC per variable from `lavInspect(fit, "implied")` (list with `within` and `between`): `icc_v = Sigma_B[v, v] / (Sigma_B[v, v] + Sigma_W[v, v])`;
   a variable absent at the within level gets ICC 1 and, for X or M, the error above. Reported for X, M and Y; **X and M drive the decision** (`a_b`
   needs between variance in X, `b_b` in M; a Y ICC near zero shows up as a Heywood case and `admissible`).
2. `between_identified` is FALSE if **any** holds: `icc_X < 0.01` or `icc_M < 0.01` (`options(medfit.between_icc_error)`); a between-path SE is
   `NA` or non-finite; the joint vcov is not positive definite (smallest eigenvalue of the path block <= 0, tolerance 1e-10 scaled by the largest);
   `converged` is FALSE (subject to question 1).
3. Warning band `0.01 <= icc < 0.05` (`options(medfit.between_icc_warn)`): `medfit_warning_between_weak`, between results kept. Evidence for
   why `post.check` alone is not used: a between SD of 0.05 gives `post.check` TRUE and a between SE of 0.731 (research 2.6).

Classed conditions (all subclass `rlang` condition via `rlang::abort` / `rlang::warn` as the package does for `medfit_error_lavaan_multilevel`):

| Class | Kind | When |
|---|---|---|
| `medfit_error_twolevel_unsupported` | error | more than one mediator, X or M absent at a level, a non-linear/latent/product shape outside S2 |
| `medfit_error_twolevel_product` | error | `:` term or `interaction =` (Q5) |
| `medfit_error_twolevel_standardized` | error | `standardized = TRUE` (S1-Q4) |
| `medfit_error_twolevel_path_missing` | error | a, b or cp row absent at a level |
| `medfit_error_twolevel_unusable` | error | not converged and the within block is unusable (question 1) |
| `medfit_between_unidentified` | warning | within-only result at extraction; also from between accessors (S1-Q1) |
| `medfit_warning_between_weak` | warning | ICC in [0.01, 0.05) |
| `medfit_warning_twolevel_constrained` | warning | contrast `NA` because of cross-level equality |
| `medfit_warning_twolevel_inadmissible` | warning | `post.check` FALSE |
| `medfit_warning_twolevel_few_clusters` | warning | J < 50 |

## 6. Bootstrap (Q11 (a); S2c object-based dispatch stays deferred)

`bootstrap_mediation(statistic_fn, method, mediation_data, data, ..., cluster)` (`R/bootstrap.R:251`) needs scalar callbacks. New export
`twolevel_statistic(x, effect = c("nie_within", "nie_between", "nie_contrast", "nde_within", ...))` returns a callback whose form depends on the first
argument:

- `x` a `TwoLevelMediationData`: the **parametric** callback, `function(p)` taking the named alias vector `mvrnorm` draws (`R/bootstrap.R:361-374`:
  `statistic_fn(boot_params[i, ])`, names are `names(x@estimates)`), computing the term. `.assert_param_mediation_data()` (`R/bootstrap.R:680`) gains
  `TwoLevelMediationData` in its `supported` list and its message. A between effect from a within-only object errors, `medfit_between_unidentified`.
- `x` a `lavaan` two-level fit (plus `treatment`, `mediator`, `outcome`): the **nonparametric refit** callback, `function(d)` that re-fits with
  `lavaan::update(x, data = d)` (the cluster ids in `d` are already relabeled per draw by `.relabel_clusters()`, `R/bootstrap.R:535`, so a cluster drawn twice is two
  clusters), extracts, and returns the term; a non-converged or within-only refit returns `NA_real_` for between terms (the loop's existing failure
  handling at `R/bootstrap.R:581` is verified in PR3, and if it errors on `NA` the helper counts and drops them with a message).

The exact public calls are tested end to end (no hand-built callback): `bootstrap_mediation(twolevel_statistic(td, "nie_between"), method = "parametric",
mediation_data = td)` and `bootstrap_mediation(twolevel_statistic(fit, "nie_within", ...), method = "nonparametric", data = d, cluster = "id")`, each
checked for a finite estimate and CI, the `n_boot` count, and, for the cluster route, a planted resample with a duplicated cluster whose refit has
`n_clusters` equal J (not J minus duplicates). `method = "plugin"` returns the point estimate.

## 7. Oracle plan (independent of the thing under test; tolerances scale by SE, PLAN 0.5)

| # | Oracle | What it checks | Tolerance |
|---|---|---|---|
| O1 | **Balanced saturated closed form** (`Sigma_W = S_PW`, `Sigma_B = (S_B - S_PW) / n`; hand code in `helper-twolevel.R`, no lavaan) | the lavaan numbers the adapter reads, on a balanced, saturated, observed fixture (estimates only) | `max(0.01 * SE, 1e-4)` (lavaan optimizer is ~1e-5 off the closed form, research 2.6) |
| O2 | **`lm` on cluster-centered data** for `a_w, b_w, c_w`; `lm` on cluster means for the manifest between paths | within paths (exact up to the ML/LS gap), between paths approximately | within: `max(0.01 * SE, 1e-4)`; between: labeled approximate, `0.1 * SE` |
| O3 | lavaan `:=` and a **hand delta** `sqrt(g' V g)` with `V` re-read by free index in the test (not by the adapter's helper) | adapter arithmetic: effects, SEs, contrast, `Cov(a_w, a_b)` carried | `1e-8` relative (same numbers, algebra only) |
| O4 | **Nonparametric cluster bootstrap** of the lavaan fit (`bootstrap_mediation`, B = 300, J = 60) | SE plausibility of `nie_within`, `nie_between`, `nie_contrast` | `0.20` relative; a sanity oracle, MC error at B = 300 is ~4%; `skip_on_cran()` |
| O5 | lavaan with `fixed.x = FALSE` at the same information | the documented SE gap: `fixed.x = TRUE` between SEs 3-4% narrower; estimates within 5e-5 | SEs `1e-3` relative **only** against `fixed.x = FALSE` at the same information; against the default fit the gap is asserted to be in 1-6% (not a tolerance) |
| O6 | lavaan `se = "robust.huber.white"`, `missing = "fiml"` and lavaan's cluster bootstrap passed as options | the adapter reads whatever fit it is given: stored provenance correct, no refit, vcov rows keyed correctly, `n_obs` FIML = 500 | exact on provenance; estimates `max(0.01 * SE, 1e-4)` |
| O7 | lme4 (`lmer` with within and between terms) | point estimates, **manifest-mean parameterization only** (no cross-level covariance from lme4) | labeled approximate, `0.1 * SE` |
| O8 | (S3, not S2) hand-built two-level likelihood | validates lavaan's two-level likelihood itself, so the adapter is not validated only against the software it wraps | scheduled **before S2 merges**, outside this PR set |

Mplus and brms are not planned (PLAN 0.5). The cross-level covariance is asserted **directly**: `Cov(a_w, a_b)` from `td@vcov` equals the fit's entry (-0.00195
in the research fixture) and is non-zero; the functional `a_w - a_b` (SE 0.1898 joint vs 0.1792 with the block zeroed, 5.6%) is the delta-method check where the block matters; the
contrast `a_w b_w - a_b b_b` (0.48%) is **not** used to detect a dropped block.

## 8. Planted defects (positive controls; each is a test that must fail under the defect)

Mechanism: the keying, sub-vcov, gradient and ICC steps are named internal functions (`.twolevel_key_rows`, `.twolevel_subvcov`,
`.twolevel_gradients`, `.twolevel_identification`); a test replaces one with `testthat::local_mocked_bindings()` and expects the oracle assertion to fail.

| Defect | Detected by |
|---|---|
| levels swapped (`a_within` read from level 2) | O1/O3: `nie(level = "within")` differs from the closed form; `a_within` vs `lm` on centered data |
| group-1/level-1 mis-keying on an unlabeled model (first block taken for both levels) | O3 and the between value differing from O1 on a fixture whose levels differ |
| `.l2` suffix mismatch (between rows matched by name with the wrong suffix) | the keyed rows' `free` indices differ from `parTable`; a test on the exact index set |
| cross-level block dropped from `V` | direct `Cov(a_w, a_b)` assertion; `a_w - a_b` SE (5.6% gap) |
| shared label read as a free contrast | the `cross_level_equal` fixture: contrast must be `NA` with the classed warning, not `0 +/- 0` |
| `post.check`-only admissibility | the between-SD 0.05 fixture must be flagged weak/unidentified |
| ICC threshold swapped (X vs M) | degenerate fixtures with only M or only X degenerate |

## 9. Test files (all under `tests/testthat/`; all need lavaan, skip with `skip_if_not_installed("lavaan")`)

| File | Content |
|---|---|
| `helper-twolevel.R` | the DGP (J = 100, n = 5, true paths known), fixtures cached per file (`withr`/`local` cache), the closed-form oracle, a fit builder for each degenerate case |
| `test-twolevel-class.R` | constructor, validator (every branch), within-only object, alias rows, `S4_register` smoke, `print` |
| `test-twolevel-extract.R` | keying, `nlevels`/`ngroups` guard and the flipped S0 test, single-level `cluster=` fit unaffected, `standardized` refusal, product refusal, path-missing, one mediator only, `cross_level_equal` fixture, provenance (`fixed_x`, `information`, `missing`, version), O1, O2, O5, O6 |
| `test-twolevel-degenerate.R` | the three degenerate-X fixtures (cluster-mean centered X, between SD 0.05, within-randomized X) return within-only results with the classed condition; M degenerate; the ICC band warning; non-convergence (question 1); small-J warning |
| `test-twolevel-effects.R` | generics with `level =`, defaults, `"both"`, constrained and unidentified `NA`, `paths`, `decompose`, `pm` zero-total path, O3 |
| `test-twolevel-se.R` | gradients, `tidy`, `confint`, `glance`, `summary` provenance text, the cross-level covariance assertions, the planted defects of section 8 |
| `test-twolevel-bootstrap.R` | the two public calls, duplicate-cluster resample, `NA` handling, within-only error, O4 (`skip_on_cran()`) |
| `test-dependents-contract.R` (edit) | see section 11 |
| `test-refcard-coverage.R`, `test-model-pages*.R`, `test-guide-*.R`, `test-cookbook-consistency.R` (edit/keep green) | see section 10 |

Test cost: the fixtures are lavaan two-level ML fits (~1-3 s each); one cached fixture per file, B = 300 only in the slow bootstrap oracle.

## 10. Documentation

The repo's docs tests fail the PR when a new export, class, page or quoted message is not wired in, so these are part of the slices, not a follow-up.

| File | Change | Guard |
|---|---|---|
| `vignettes/articles/model-twolevel.qmd` (new) | the model page: design, estimand, what `lavaan` fit to give, example, within/between/contrast, diagnostics, flags, limits, `fixed.x` note | `test-model-pages.R` |
| `vignettes/articles/models.qmd` | row on the landing page | `test-model-pages.R` |
| `_pkgdown.yml` | articles index entry, navbar item under "Clusters and latent variables" (next to `articles/model-cluster.html`, `:84-86`), reference section for the class and `twolevel_statistic()` | `test-model-pages.R`, pkgdown check |
| `vignettes/articles/cookbook.qmd` | one recipe (next number) with a two-level example; heading id and any `cookbook.html#...` link must agree | `test-cookbook-consistency.R`, `test-model-pages.R` |
| `vignettes/articles/refcard.qmd` | name the class, `twolevel_statistic(`, and any new export | `test-refcard-coverage.R` (every export and class) |
| `vignettes/articles/guide-troubleshooting.qmd` | one entry per quoted classed message (unidentified between, constrained contrast, few clusters, standardized refusal, product refusal); each quoted message must be triggered by a test | `test-guide-troubleshooting.R`, `test-model-pages-messages.R` |
| `vignettes/articles/guide-glossary.qmd` | within effect, between effect, ICC, latent cluster mean, contrast | `test-guide-pages.R` |
| `vignettes/articles/methods.qmd` | the formulas: nine terms, gradients, quotient rule; all math lives here (CLAUDE.md) | docs consistency |
| `vignettes/articles/model-lavaan.qmd`, `extraction.qmd` | replace the "multilevel is refused" limit with the two-level route; keep three-level and multigroup refusals | `test-model-pages.R` |
| `vignettes/articles/lavaan-comparison.qmd` | feature-table row (two-level mediation extraction) | `test-lavaan-comparison.R` (probed live) |
| `R/extract-lavaan.R` roxygen `@section Limits` (`:114-121`) | rewrite; `man/` regenerated | `devtools::document()` |
| `NEWS.md`, `DESCRIPTION` | minor bump (new exported class and a behavior change for two-level fits: refused in S0, extracted in S2); behavior-change note | CLAUDE.md breaking-changes exemption |
| `CLAUDE.md` and `.STATUS` | add the class, files and test files; remove nothing else | doc-currency |

## 11. Ecosystem and `test-dependents-contract.R`

No dependent reads the new class: probmed (`MediationData`, `ParallelMediationData`), RMediation (`MediationData`, `SerialMediationData`, `SEMFit`) and missingmed
(`MediationData`, `InteractionMediationData`) are listed in `.dependent_classes`. Before S2, a two-level lavaan fit passed to `extract_mediation()` returned the within
level silently (pre-S0) or an error (S0); after S2 it returns a class the dependents do not know. Planned edits: (a) add `TwoLevelMediationData` to a new
`.dependent_new_classes` list with the property names this spec fixes (so a rename is caught), (b) a test that `nie()`, `confint()` and `bootstrap_mediation()` accept it
and that probmed-style `.assert_*` guards reject it with a clear message instead of a slot error (read the siblings' guards read-only; **no sibling edits**), (c) a NEWS ecosystem
note. No coordination issue is needed (no previously working call changes); flagged anyway as question 7.

## 12. Risk tier: **normal**

`tests/sim/risk-files.txt` (on `origin/dev`) lists the native engine files (`R/sem-ml.R`, `sem-model.R`, `sem-constraints.R`, `sem-optim.R`, `sem-parse.R`, `sem-fit.R`, `fit-sem.R`,
`sem-fiml.R`, `sem-fiml-interface.R`) and `tests/sim/gates.csv`. S2 touches none: new `R/classes-twolevel.R`, `R/extract-lavaan-twolevel.R`, `R/twolevel-helpers.R`, edits to
`R/extract-lavaan.R`, `R/effect-se.R`, `R/generics-effects.R`, `R/methods-base.R`, `R/methods-tidy.R`, `R/bootstrap.R`, `R/zzz.R`. No objective, parameter vector, constraint set, bound or solver
path changes, so the seven-item admission checklist does not apply, and no `gates.csv` row is needed. The `risk-tier` workflow check should pass as normal. (S4 is high-risk; the planned
`parser` change at `R/sem-parse.R:323` is S4's, not S2's.)

## 13. PR slicing (all against `dev`; no PR is opened by this spec)

| PR | Content | Files (indicative) | Effort |
|---|---|---|---|
| **PR1 class + extraction** | class and validator, `S4_register`, `.extract_lavaan_twolevel()` with keying, equality detection, identification diagnostics, classed conditions, provenance, flipped S0 test; `print`; `test-twolevel-class.R`, `-extract.R`, `-degenerate.R`, `helper-twolevel.R`; O1, O2, O5, O6 | `R/classes-twolevel.R`, `R/extract-lavaan-twolevel.R`, `R/extract-lavaan.R`, `R/zzz.R`, `tests/testthat/*twolevel*`, `test-dependents-contract.R` | 3-4 days |
| **PR2 effects + inference** | the generics with `level =`, gradients, `coef`/`vcov`/`nobs`/`confint`, `tidy`/`glance`, `summary`, planted defects, O3 | `R/generics-effects.R`, `R/effect-se.R`, `R/methods-base.R`, `R/methods-tidy.R`, `test-twolevel-effects.R`, `-se.R` | 2-3 days |
| **PR3 bootstrap helper** | `twolevel_statistic()`, `.assert_param_mediation_data()`, NA handling, duplicate-cluster test, the exact public calls, O4 | `R/bootstrap.R`, `R/twolevel-helpers.R`, `test-twolevel-bootstrap.R` | 1.5-2 days |
| **PR4 docs** | model page, cookbook, refcard, troubleshooting, glossary, methods, pkgdown wiring, lavaan article, roxygen, NEWS, version bump, `CLAUDE.md`/`.STATUS` | `vignettes/articles/*`, `_pkgdown.yml`, `NEWS.md`, `DESCRIPTION` | 2 days |
| **Total** | | | **8.5-11 days** (inside the 8-12 day budget of PLAN 0.7) |

Order: PR1 to PR2 to PR3 are sequential (each uses the previous class); PR4 can start after PR2 and merge last. O8 (the S3 hand-built likelihood) is a separate branch
that runs in parallel and merges before PR2. Each PR runs the full suite in its own tree, reports counts, and quotes a live end-to-end transcript in its body (the
`e2e-before-pr` rule): PR1 an extraction of the review fixture, PR2 the `tidy()` table against `:=`, PR3 both bootstrap calls.

## 14. Questions for the maintainer (still undecided)

1. **Non-convergence.** S1-Q1 lists non-convergence as a within-only trigger. A non-converged fit's *within* estimates may also be unreliable. Proposed: within-only only if the
   within block of the vcov is finite and positive definite, else error `medfit_error_twolevel_unusable`. Confirm, or make non-convergence always an error.
2. **Accessor behavior when between is unidentified or the contrast is constrained.** Proposed: return `NA_real_` and signal the classed *warning* (suppressible per class). Alternative: classed
   *message*, or error. Confirm.
3. **Fixed or constrained paths.** Proposed: a path row with `free == 0` is accepted (variance 0, listed in `fixed_paths`) and an absent row errors. Alternative: refuse fixed rows too.
4. **Names.** `TwoLevelMediationData`, `twolevel_statistic()` (export), `level = "within" | "between" | "contrast" | "both"`; alias row names `a_within`, ... `c_prime_between`. Confirm or rename
   (the existing 2-1-1 class uses `b_within`, `b_between`, `c_prime`).
5. **Version.** A new exported class plus a behavior change (two-level fits go from refused to extracted): proposed minor bump (0.17.0) with a NEWS behavior-change note.
6. **lavaan floor.** The adapter reads `nlevels`, `cluster.size`, `implied`, `post.check`, `parTable()`'s `block`/`level` and `vcov()`; the supported floor is set after running PR1 on the oldest lavaan CI
   runs and lavaan 0.7.3. Does the maintainer want a floor stated now?
7. **Dependents.** No previously working call changes, so no `[BREAKING]` issue is planned. Confirm that a NEWS ecosystem note and the contract-test edit are enough.
8. **Where the S3 hand-built likelihood lives.** Proposed: `tests/testthat/helper-twolevel-likelihood.R` (cheap, runs everywhere) rather than `tests/sim/`; confirm before S3.
9. **Contrast for `nde`/`te`/`pm`.** Proposed: only `nie` has a first-class contrast (`level = "contrast"`); `nde`, `te`, `pm` contrasts appear only in `tidy()`. Confirm.
