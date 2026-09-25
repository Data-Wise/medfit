# Changelog

## medfit 0.5.0

Two fixes change results (marked **Behavior change** below): serial
[`te()`](https://data-wise.github.io/medfit/reference/te.md) and
[`pm()`](https://data-wise.github.io/medfit/reference/pm.md) now sum
every path ([\#81](https://github.com/data-wise/medfit/issues/81)), and
`confint(parm = "paths")` finds path rows by name instead of by position
([\#82](https://github.com/data-wise/medfit/issues/82)). Both correct
wrong output, so they ship without a deprecation period. Ecosystem:
probmed and RMediation call neither function and their test suites pass
against this release. The same bugs are present in CRAN 0.3.2; see
[\#83](https://github.com/data-wise/medfit/issues/83) for workarounds.

### New features

- New `JointMediationData` class:
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  on lm/glm fits with two or more mediators (serial or parallel) now
  supports treatment-by-mediator product terms in the outcome model,
  written with `:` or `*` (e.g. `Y ~ X * M2 + M1 + C`). It returns the
  **joint** natural effects of the mediators as a block (VanderWeele and
  Vansteelandt 2014): for a 0/1 treatment, NIE = sum over mediators of
  (theta2 + theta3) times the total treatment effect on that mediator,
  NDE and CDE add the product terms at the covariate means and at
  `m_star`. There is no per-mediator split of the NIE. For a serial
  chain the joint NIE counts every path through the mediators, so it
  differs from the chain-only `a * d * b` that
  [`nie()`](https://data-wise.github.io/medfit/reference/nie.md) reports
  by default for `SerialMediationData` (it matches `nie(type = "total")`
  when there is no product term). Standard errors use analytic
  delta-method gradients and a stacked-OLS covariance that includes the
  correlation between parallel mediator equations; they are conditional
  on the observed covariates.
  [`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
  [`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
  [`te()`](https://data-wise.github.io/medfit/reference/te.md),
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md),
  [`decompose()`](https://data-wise.github.io/medfit/reference/decompose.md),
  [`paths()`](https://data-wise.github.io/medfit/reference/paths.md),
  [`print()`](https://rdrr.io/r/base/print.html),
  [`summary()`](https://rdrr.io/r/base/summary.html),
  [`coef()`](https://rdrr.io/r/stats/coef.html),
  [`vcov()`](https://rdrr.io/r/stats/vcov.html),
  [`nobs()`](https://rdrr.io/r/stats/nobs.html),
  `confint(parm = "paths" / "effects")`,
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) (types
  `"paths"` and `"effects"`, with delta-method SEs) and
  [`glance()`](https://generics.r-lib.org/reference/glance.html) (adding
  `structure`, `n_mediators`, `interactions` and `m_star`) support the
  class. The new
  [`joint_effects()`](https://data-wise.github.io/medfit/reference/joint_effects.md)
  recomputes the effects at any parameter vector, which makes it the
  statistic for a parametric
  [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md).
  The “Model Extraction” article has a worked example on
  `mediation_demo$outcome_int`. The fit must use Gaussian identity-link
  models without weights, an intercept in each, the same rows and the
  same covariates in every model, a numeric 0/1 treatment, and every
  mediator in the outcome model; each violation errors, naming the
  cause. `m_star` is a scalar or a vector named by the interacting
  mediators. Products elsewhere (in a mediator model,
  mediator-by-mediator, three-way, with a covariate, or
  function-wrapped) still error, as do lavaan multi-mediator fits with
  products.

- New bundled dataset `mediation_demo` (400 rows, 8 variables):
  simulated data that supports simple, serial, parallel, and
  treatment-by-mediator interaction examples from one running example.
  The covariates are mediator-outcome confounders, so examples adjust
  for them. See
  [`?mediation_demo`](https://data-wise.github.io/medfit/reference/mediation_demo.md)
  for the generating equations; the generating script is in `data-raw/`.
  The “Getting Started”, “Introduction”, and “Model Extraction” articles
  and the single-mediator examples for
  [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md),
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md),
  [`med()`](https://data-wise.github.io/medfit/reference/med.md),
  [`quick()`](https://data-wise.github.io/medfit/reference/quick.md),
  [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md),
  [`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
  [`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
  [`te()`](https://data-wise.github.io/medfit/reference/te.md),
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md), and
  [`paths()`](https://data-wise.github.io/medfit/reference/paths.md) now
  use it, adjusting for both covariates.

- `bootstrap_mediation(method = "parametric")` and `method = "plugin"`
  now accept `SerialMediationData`, `ParallelMediationData`, and
  `InteractionMediationData`, not only `MediationData`. Both methods
  read only `@estimates` and `@vcov`, which every class carries with
  matching names, so `statistic_fn` can use the path aliases directly
  (e.g. `a * d1 * b` for a serial chain, `a1 * b1 + a2 * b2` for
  parallel mediators). Previously these classes were rejected because
  they do not inherit from `MediationData`.

- `BootstrapResult` gains [`coef()`](https://rdrr.io/r/stats/coef.html)
  and [`confint()`](https://rdrr.io/r/stats/confint.html) methods.
  [`coef()`](https://rdrr.io/r/stats/coef.html) returns
  `c(estimate = ...)`;
  [`confint()`](https://rdrr.io/r/stats/confint.html) returns the stored
  percentile interval as a 1 x 2 matrix, recomputes it from the
  bootstrap distribution when a different `level` is given, and returns
  `NA` with a warning for plugin results. Previously both errored with
  “Can’t get S7 properties with `$`”.

- [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
  [`glance()`](https://generics.r-lib.org/reference/glance.html) now
  support `ParallelMediationData` and `InteractionMediationData`;
  previously both errored with “not implemented for this S7 object
  type”. [`tidy()`](https://generics.r-lib.org/reference/tidy.html)
  returns path rows (`a1, b1, ..., c_prime` or `a, b, c_prime, theta3`)
  with standard errors from
  [`vcov()`](https://rdrr.io/r/stats/vcov.html), then effect rows
  (`nie`, `nde`, `te`, plus the four-way `cde`, `int_ref`, `int_med`,
  `pie` for interaction models) with delta-method standard errors (see
  below). [`glance()`](https://generics.r-lib.org/reference/glance.html)
  adds `n_mediators` (parallel) or `interaction` and `m_star`
  (interaction).

- [`tidy()`](https://generics.r-lib.org/reference/tidy.html) now reports
  delta-method standard errors for effect rows (NIE, NDE, TE, and the
  four-way components) for all four mediation classes, from the same
  computation as `confint(parm = "effects")`, so `tidy(conf.int = TRUE)`
  reproduces [`confint()`](https://rdrr.io/r/stats/confint.html)
  exactly. Previously these rows had `NA` standard errors, and
  `SerialMediationData` returned `NA` intervals with a warning.
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) stays
  silent;
  [`?tidy.S7_object`](https://data-wise.github.io/medfit/reference/tidy.S7_object.md)
  documents that the intervals are normal approximations and that the
  proportion mediated should be bootstrapped.

- New [`confint()`](https://rdrr.io/r/stats/confint.html) method for
  `SerialMediationData`, with `parm = "paths"` or `"effects"`.

### Bug fixes

- **Behavior change:** `confint(parm = "paths")` now finds each path’s
  row of `@vcov` by name: the alias rows (`a`, `b`, `c_prime`; `d1`, …;
  `a1`, `b1`, …; `theta3`) first, then, for `MediationData`, the
  lm-style `m_<treatment>`, `y_<mediator>`, `y_<treatment>` rows. Names
  come from `rownames(`[`@vcov`](https://github.com/vcov)`)`, or from
  `names(`[`@estimates`](https://github.com/estimates)`)` when `@vcov`
  has none. Previously `MediationData` looked only for the lm-style
  names and otherwise warned and took the first three diagonal entries.
  That gave wrong SEs for every lavaan-extracted object, where rows 1-3
  are a, c’, b, so b and c’ swapped SEs. It was right for a hand-built
  object with alias names only when those came first. The serial,
  parallel, interaction and joint methods returned `NA` bounds for a
  missing row. All five now error, naming the missing rows, when neither
  set of names resolves.
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) still
  reports `NA` there, as it is descriptive;
  [`confint()`](https://rdrr.io/r/stats/confint.html) is strict.
  **Ecosystem note:** downstream code that builds these objects by hand
  with unnamed `@estimates`/`@vcov` gets an error from
  `confint(parm = "paths")` instead of a warning or `NA`.

- **Behavior change:**
  [`te()`](https://data-wise.github.io/medfit/reference/te.md) and
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) for
  `SerialMediationData` now use the full total effect, the sum over
  every X-to-Y path, instead of only the chain plus the direct effect
  (`a * d * b + c'`). For the usual specification (`M2 ~ X + M1`,
  `Y ~ X + M1 + M2`) the old value left out the paths that skip a
  mediator (X -\> M1 -\> Y, X -\> M2 -\> Y) and could be badly off. In
  one simulated example it gave 0.13 where the true total effect was
  0.54. With linear models and the same covariates in every equation,
  [`te()`](https://data-wise.github.io/medfit/reference/te.md) now
  equals the treatment coefficient of `lm(Y ~ X + covariates)`.
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) is the
  total indirect effect divided by that total.
  [`nie()`](https://data-wise.github.io/medfit/reference/nie.md) still
  returns the chain-specific indirect effect by default. The new
  `nie(x, type = "total")` returns the total indirect effect,
  `te(x) - nde(x)`. The serial lm/glm and lavaan extractors now record
  the skip-path coefficients as `a2..ak` (`X -> Mj`), `b1..b{k-1}`
  (`Mi -> Y`) and `d{i}_{j}` (`Mi -> Mj`, j \> i + 1) in `@estimates`
  and `@vcov`. The delta-method SE of `te` in
  [`confint()`](https://rdrr.io/r/stats/confint.html) and
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html)
  differentiates the full sum. It matches lavaan `:=` SEs. Serial
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) gains a
  `nie_total` row,
  [`glance()`](https://generics.r-lib.org/reference/glance.html) gains a
  `nie_total` column and `coef(type = "effects")` gains
  `indirect_total`, appended after `total` so existing positions are
  unchanged. A hand-built object whose predictor lists include a skip
  path without its coefficient gets `NA` and a warning from
  [`te()`](https://data-wise.github.io/medfit/reference/te.md) and
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md), because
  assuming zero would reproduce the bug. For glm fits with a
  non-identity link, the path sum is on the linear-predictor scale, as
  it already is for `MediationData`.
  [`quick()`](https://data-wise.github.io/medfit/reference/quick.md) now
  prints the chain and total NIE side by side. Downstream impact: none
  for probmed (imports only
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md))
  or RMediation (its serial `ci()` reads `@a_path`, `@d_path` and
  `@b_path`, which are unchanged); neither calls serial
  [`te()`](https://data-wise.github.io/medfit/reference/te.md) or
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md). Code
  that stored serial
  [`te()`](https://data-wise.github.io/medfit/reference/te.md) or
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) values
  from medfit 0.4.0 or earlier will see different numbers.

- `tidy(<SerialMediationData>, type = "effects")` no longer errors on
  mismatched row counts.

- The single-mediator four-way decomposition
  (`InteractionMediationData`, lm/glm engine) now includes factor
  covariates in E\[M \| X = 0\]. Covariate means were taken only for
  numeric data columns named after a coefficient, so a factor’s dummy
  coefficients (e.g. `Gb`, `Gc`) were skipped without a warning. NDE,
  INTref and the total effect were wrong, and so were their delta-method
  SEs. The means now come from the mediator model’s design matrix, as in
  `JointMediationData`, and both the point estimates and the gradients
  use them. Two other cases change for the same reason: transformed
  covariate terms (e.g. `log(C)`, `poly(C, 2)`) were also skipped and
  are now included, and when a caller-supplied `data` has rows the
  mediator model did not use, the means now cover only the estimation
  sample. With case weights (e.g. `fit_mediation(weights = )`), the
  means are now weighted by them; they were unweighted before. Results
  with plain numeric covariates and no weights are unchanged.
  [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  with an `X * M` outcome formula is fixed as well. The lavaan engine
  accepts only numeric observed variables, so it is unaffected.

- `JointMediationData` effect standard errors are no longer `NA` in
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
  [`summary()`](https://rdrr.io/r/base/summary.html) when
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  receives `data =` and a model has a factor or transformed covariate
  (e.g. `G` with levels `a`/`b`/`c`, or `poly(W, 2)`);
  `confint(parm = "effects")` no longer errors for the same fits. The
  gradients rebuilt the covariate means from `@data`, which only works
  for a model frame, so the SE computation failed and
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
  [`summary()`](https://rdrr.io/r/base/summary.html) caught the failure
  and reported `NA`. The extractor now stores the exact means the point
  estimate uses on `@data` (attribute `medfit_covariate_means`, the
  convention of the four-way extractor), so SEs with `data = d` equal
  those with `data = NULL`, including fits with `subset =`. Point
  estimates were already correct.

- `fit_mediation(se_type = "sandwich")` now applies the sandwich
  estimator to fits with a treatment-by-mediator interaction. The
  four-way worker ignored `vcov_fun` and always used the model-based
  [`stats::vcov()`](https://rdrr.io/r/stats/vcov.html), so the returned
  `@vcov` was identical to `se_type = "model"`, with no warning. A
  `vcov_fun` passed to
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  now also reaches serial and parallel fits, which ignored it the same
  way.

- The four-way decomposition now requires the identity link. A Gaussian
  [`glm()`](https://rdrr.io/r/stats/glm.html) with another link
  (e.g. `gaussian(link = "log")`) passed the family check, and the
  linear four-way formulas were applied to a model that is not linear in
  its coefficients. It now errors, naming the link.

- [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  now errors when `m_star` is supplied but no four-way decomposition or
  joint-effects fit uses it (no treatment-by-mediator term, or
  `decomposition = "two_way"`), on both the lm/glm and lavaan paths. The
  value was previously dropped silently. As in
  [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md),
  the check keys on whether `m_star` was given at the call site, not on
  its value.

- [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  on lm/glm fits now detects products written inside a function call,
  such as `I(X * M)`. R records such a term as an ordinary covariate, so
  it previously bypassed both the multi-mediator product guard and the
  single-mediator interaction check: the fit returned main-effect
  estimates that ignored the product, with no error. Multi-mediator
  extraction now errors on any wrapped term that combines the treatment
  or a mediator with another variable (e.g. `I(X * M2)` or
  `log(M1 + C)`). Single-mediator extraction errors on a wrapped
  treatment-by-mediator product and asks for `X * M` or `X:M`, which
  route to the four-way decomposition. Single-variable transforms such
  as `I(X^2)` are unaffected, and a product precomputed as a data column
  still cannot be detected from the formula.

- `confint(parm = "effects")` for `MediationData` gave a total-effect
  interval that was too wide: it treated the indirect effect and `c'` as
  independent, dropping their covariance. It now uses the full
  delta-method gradient (on the simple `mediation_demo` fit the TE
  standard error drops from 0.127 to 0.119, matching a parametric
  bootstrap). NIE and NDE are unchanged.

- `confint(parm = "effects")` and
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) now work
  for `MediationData` extracted from lavaan. Both located paths by
  lm-style names, so [`confint()`](https://rdrr.io/r/stats/confint.html)
  stopped with “Could not compute SEs for effects” and
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) omitted
  standard errors.

- [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  with two or more mediators (serial or parallel) now errors when a
  model carries a product term involving the treatment or a mediator,
  e.g. `X:M1` in the outcome model. Previously the multi-mediator branch
  returned before any interaction check, so the product term was ignored
  silently and main-effect paths were reported as if no interaction
  existed. Applies to both the lm/glm and lavaan methods; for lavaan, a
  product precomputed as a plain data column is recognized when named
  via `interaction =`. Products among covariates alone are still
  allowed. On lm/glm, a treatment-by-mediator product in the outcome
  model is now supported through `JointMediationData` (see New
  features); every other product still errors.

- [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  on a lavaan fit whose paths carry custom labels (e.g. `M ~ aa*X`) now
  fills the alias rows of `@vcov` (`a`, `b`, `c_prime`, and the serial,
  parallel, and interaction aliases) from the labeled parameters.
  Previously the label-based parameter names from lavaan did not match
  the names the extractors looked for, so those rows and columns were
  all zero, and `bootstrap_mediation(method = "parametric")` drew a
  degenerate distribution with a zero-width interval. The simple
  extractor only recognized labels equal to
  `a_label`/`b_label`/`cp_label`; the serial, parallel, and interaction
  extractors recognized no labels at all. All four now read each path’s
  parameter name from
  [`lavaan::parTable()`](https://rdrr.io/pkg/lavaan/man/parTable.html).

- [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  on a lavaan fit now stops with an error when a user label reuses one
  of medfit’s alias names for a different path, for example `a1`/`a2`
  written for `mediator = c("M1", "M2")` while the call lists
  `c("M2", "M1")`, or a covariate path labeled `a`. The alias estimate
  was taken from the right path, but its `@vcov` row stayed the labeled
  parameter’s, so standard errors and bootstrap draws used the wrong
  variance. A label on the alias’s own path (such as the default `a`,
  `b`) is still accepted. The simple extractor now takes each alias’s
  `@vcov` row from the same parameter-table row as its estimate, so the
  two agree when the paths were found through `a_label`, `b_label`, and
  `cp_label`.

### Documentation

- The articles now evaluate their code when the site is built, instead
  of showing output typed in by hand, so the shown output cannot drift
  from the code and a broken example fails the build. The pkgdown
  workflow also runs on pull requests to `dev`. Turning this on exposed
  three broken examples in the “Introduction” article (a missing
  [`library(medfit)`](https://data-wise.github.io/medfit/) and two
  hand-built objects missing required properties), now fixed; the
  error-handling example in “Model Extraction” shows the real messages.

- New “Methods and Formulas” article collecting the estimand, formula,
  covariance and standard-error computation for every class, the
  bootstrap methods, and the fitting engines, with the assumptions each
  estimand needs.

- Help pages now cover every class:
  [`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
  [`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
  [`te()`](https://data-wise.github.io/medfit/reference/te.md),
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) and
  [`paths()`](https://data-wise.github.io/medfit/reference/paths.md)
  give the formulas for parallel, interaction and joint objects;
  [`decompose()`](https://data-wise.github.io/medfit/reference/decompose.md)
  gains the four-way formulas, the joint method, references and an
  example; `InteractionMediationData` gains the INTref formula and
  `JointMediationData` the NDE formula;
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  documents the lm/glm arguments, the returned classes, and the
  covariance of the estimates;
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html)/[`glance()`](https://generics.r-lib.org/reference/glance.html)
  document
  [`glance()`](https://generics.r-lib.org/reference/glance.html) and the
  [`coef()`](https://rdrr.io/r/stats/coef.html),
  [`vcov()`](https://rdrr.io/r/stats/vcov.html),
  [`confint()`](https://rdrr.io/r/stats/confint.html) and
  [`nobs()`](https://rdrr.io/r/stats/nobs.html) methods; bootstrap
  intervals are stated to be percentile intervals.

- Corrected stale examples and statements in the articles and README:
  `confint(parm = "effects")` (not `type =`), tidy output with
  delta-method effect SEs, the list of classes, and the covariance
  between parallel mediator equations, which the lm/glm `@vcov` omits.

- [`?fit_mediation`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  and
  [`?bootstrap_mediation`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
  no longer merge in the placeholder stubs left over in
  `R/aab-generics.R` (removed). Each page had two usage blocks, two
  return values, duplicated details sections, and examples on
  nonexistent objects inside `\dontrun{}`. The regmedint-engine and
  reference-mediator-level notes from the
  [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  stub now live with the real function.

- Serial mediation docs now recommend including the treatment and every
  earlier mediator in the outcome model (`Y ~ X + M1 + M2`, not
  `Y ~ X + M2`). Only the last mediator’s coefficient becomes the `b`
  path, but when an earlier mediator also affects the outcome, leaving
  it out confounds `b`. The serial indirect effect `a * d * b` is the
  effect through the full chain only. Updated in the
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  lm/glm and lavaan documentation and the “Model Extraction” article; a
  new test checks the bias.

- Fixed the lavaan serial examples in the “Model Extraction” and
  “Bootstrap” articles, which passed `mediators =` to
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md);
  the argument is `mediator`.

- Repaired the “Bootstrap Inference” article so every code chunk runs
  against the current API. It now uses `mediation_demo`, adjusting for
  both covariates, and reads
  [`med()`](https://data-wise.github.io/medfit/reference/med.md)’s
  bootstrap via `attr(result, "bootstrap")`. The serial example refits
  the chain nonparametrically, because the parametric and plugin methods
  accept only `MediationData`. The article also reads `BootstrapResult`
  properties directly, since that class has no
  [`coef()`](https://rdrr.io/r/stats/coef.html)/[`confint()`](https://rdrr.io/r/stats/confint.html)
  methods, and its printed output has been regenerated.

## medfit 0.4.0

### New features

- [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  gains a second engine, `engine = "regmedint"`, which fits the mediator
  and outcome regressions through the suggested package and returns
  medfit’s own classes. On a formula without a treatment-by-mediator
  term it returns a `MediationData`; on one carrying an `X:M` term it
  returns an `InteractionMediationData` with the four-way (VanderWeele)
  decomposition filled in from regmedint’s closed-form
  `cde`/`pnde`/`tnie`/`pnie`/`te` output. Auto-detection mirrors
  `extract_mediation(decomposition = "auto")`.

- [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  gains an `engine_args` argument: a named list of engine-specific
  overrides, ignored by `engine = "glm"`. For the regmedint engine it
  accepts `interaction`, `cvar`, `mreg`, `yreg`, `a0`, `a1`, and
  `c_cond`, each replacing a value the adapter would otherwise derive
  from the formulas, families, and data.

- [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  gains an `m_star` argument: the reference mediator level (`m*`) at
  which the controlled direct effect is evaluated, when the fit returns
  an `InteractionMediationData`. It closes a gap that predates the
  engine work –
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  has always accepted `m_star`, but
  [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  routed unrecognized arguments to
  [`stats::glm()`](https://rdrr.io/r/stats/glm.html), so
  `fit_mediation(Y ~ X * M, ..., m_star = 1)` previously failed with
  `unused argument`. The default of `0` is unchanged behavior, and
  matches the lm/glm and lavaan extractors.

  Both engines honor it, by different routes: `engine = "glm"` applies
  it at extraction time, after the coefficients are fit, while
  `engine = "regmedint"` passes it to
  [`regmedint::regmedint()`](https://kaz-yos.github.io/regmedint/reference/regmedint.html)
  as `m_cde`, where that package’s closed-form estimator consumes it at
  fitting time. The two agree to delta-method tolerance on `@cde` and
  `@int_ref` at any shared `m_star`. Because `m_star` and `regmedint`’s
  `m_cde` name one quantity, `m_cde` is no longer accepted in
  `engine_args`; supplying it errors with a pointer to `m_star`. (Both
  surfaces are new in this release, so no deprecation cycle applies.)

  [`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
  [`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
  [`te()`](https://data-wise.github.io/medfit/reference/te.md), and
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) are
  invariant to `m_star` – only the CDE/INTref split moves. Supplying
  `m_star` for a fit with no treatment-by-mediator term is an error
  rather than a silent no-op.

- Standard errors for the regmedint engine are analytical, not
  bootstrapped. [`confint()`](https://rdrr.io/r/stats/confint.html) on
  an `InteractionMediationData` now prefers a stored component
  covariance block when the fitting engine supplied one; objects from
  the lm/glm and lavaan extractors carry none, so their existing
  delta-method gradient path is unchanged.

### Details and limitations

- The regmedint engine requires a numeric 0/1 treatment and a linear
  (Gaussian) mediator model. Outside those cases regmedint’s closed-form
  effects are no longer the products of regression coefficients that
  `MediationData`/`InteractionMediationData` are defined in terms of, so
  the adapter raises an explicit error with guidance rather than
  returning an object whose numbers disagree with
  [`nie()`](https://data-wise.github.io/medfit/reference/nie.md).
  Outcome models may be Gaussian or binomial.

- `engine = "regmedint"` does not support `weights` or
  `se_type = "sandwich"` (regmedint implements neither); supplying them
  is an error rather than a silent no-op.

- `m_cde` defaults to `0`, matching the `m_star = 0` default already
  used by the lm/glm and lavaan extractors, so all three report the
  CDE/INTref split at the same reference level.
  [`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
  [`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
  [`te()`](https://data-wise.github.io/medfit/reference/te.md), and
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) are
  invariant to this choice.

- is a `Suggests` dependency; medfit checks and tests cleanly with it
  absent.

### Bug fixes

- [`BootstrapResult()`](https://data-wise.github.io/medfit/reference/BootstrapResult.md)’s
  validator checked `method` for length *after* three
  `self@method != "plugin"` branches had already used it. A non-scalar
  `method` therefore raised R’s `the condition has length > 1` instead
  of the intended message, `method must be a single character string`.
  The `method` scalar and membership checks are now hoisted above every
  branch that reads it.

### Internal

- New internal helper
  [`.find_interaction_term_formula()`](https://data-wise.github.io/medfit/reference/dot-find_interaction_term_formula.md)
  (`R/utils.R`): the formula-level counterpart of
  [`.find_interaction_term()`](https://data-wise.github.io/medfit/reference/dot-find_interaction_term.md),
  used to choose the return class before any model is fitted.

## medfit 0.3.2 (2026-07-23)

CRAN release: 2026-07-23

CRAN patch release. No new features; CI/lint compatibility, CRAN
compliance, and Rd documentation fixes only (no change to exported
function behavior).

### CRAN pretest fix

- First submission attempt (2026-07-21) was archived by CRAN’s incoming
  pretest over a Debian-flavor NOTE: S7 class Rd files had `\arguments`
  without a `\usage` section (`BootstrapResult`,
  `InteractionMediationData`, `MediationData`, `ParallelMediationData`,
  `SerialMediationData`). Fixed by adding explicit constructor-call
  `@usage` signatures to all 5 S7 classes. Resubmitted 2026-07-23 and
  accepted.

### CI and lint

- Fixed `lint` job breakage from lintr 3.4.0’s tightened
  `indentation_linter` (reindented function signatures 4 -\> 2 spaces;
  whitespace only, `git diff -w` empty).
- Re-documented with roxygen2 8.0.0 (`RoxygenNote` -\>
  `Config/roxygen2/version`).

### CRAN compliance

- Fixed a stale `Date` field (CRAN incoming-feasibility check flags
  dates over a month old).
- `.Rbuildignore`d the `.remember` session-memory scratch directory,
  which was leaking into the built source tarball (`.Rbuildignore` is
  independent of `.gitignore`).
- Added `inst/WORDLIST` entries for domain vocabulary (VanderWeele
  decomposition acronyms, S7 class names, DOI journal-code fragments)
  that `spelling::spell_check_package()`/CRAN’s `aspell` pass would
  flag.
- Added `.aspell/defaults.R` to suppress a “possibly misspelled” NOTE on
  the cited author surname “VanderWeele” in the DESCRIPTION field (a
  separate aspell mechanism from `inst/WORDLIST`).

## medfit 0.3.1 (2026-06-11)

### New features

- [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  gains a `weights=` argument and a `se_type=` argument (`"model"`
  default, or `"sandwich"` for robust SEs), enabling IPW-weighted
  estimation. Unweighted calls are byte-identical to 0.3.0. Consumed by
  `missingmed`’s IPW estimator — downstream packages should require
  `medfit (>= 0.3.1)` when they pass `weights=`/`se_type=`.
  - `se_type = "sandwich"` uses the suggested package (`vcovHC`, HC3);
    it is required only on that opt-in path, so is a `Suggests`
    dependency, not `Imports`.
  - Supplying `weights=` with the default `se_type = "model"` emits a
    one-time advisory message, since model-based SEs are not valid under
    IPW.

## medfit 0.3.0 (2026-06-06)

### New features

- `MediationData` now carries the GLM `family`/link of the mediator and
  outcome models in new `family_m` and `family_y` properties (populated
  by the lm/glm and lavaan extractors; default `NULL` is treated as
  Gaussian). This lets scale-free estimands such as `probmed::pmed()`
  simulate non-Gaussian potential outcomes on the correct (e.g. logit)
  scale rather than discarding the link. Backward compatible: existing
  constructors that omit the families continue to work.

- New S7 class `InteractionMediationData` for simple mediation **with a
  treatment-by-mediator interaction** (`X:M` in the outcome model),
  carrying VanderWeele’s (2014) four-way decomposition of the total
  effect into controlled direct effect (CDE), reference interaction
  (INTref), mediated interaction (INTmed), and pure indirect effect
  (PIE), with `NDE = CDE + INTref` and `NIE = INTmed + PIE`. The class
  validator enforces both the aggregate identities and the path ties
  (`INTmed = theta3 * beta1`, `PIE = theta2 * beta1`,
  `CDE = theta1 + theta3 * m*`), so an inconsistent decomposition is
  rejected at construction. Effect extractors (`nie`, `nde`, `te`, `pm`)
  have methods for the new class, plus a new
  [`decompose()`](https://data-wise.github.io/medfit/reference/decompose.md)
  generic returning all four components and the derived effects.

- [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  now builds `InteractionMediationData` from **lm/glm** fits whose
  outcome model contains an `X:M` term. A new `decomposition` argument
  (`"auto"` default / `"four_way"` / `"two_way"`) controls detection,
  and `m_star` sets the reference mediator level. Continuous (Gaussian)
  mediator and outcome are supported (non-Gaussian models error with a
  clear message); the no-interaction path is unchanged. The companion
  [`confint()`](https://rdrr.io/r/stats/confint.html) method gives
  delta-method intervals for `parm = "paths"`, `"components"` (the
  four-way CDE/INTref/INTmed/PIE), and `"effects"` (NDE/NIE/TE).

- [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  also builds `InteractionMediationData` from a **lavaan** fit. The
  interaction enters as a product variable named via the `interaction`
  argument, and the model must be fit with `meanstructure = TRUE` (the
  mediator intercept is needed for INTref). Because the SEM is estimated
  jointly, the extracted `@vcov` carries the full joint covariance of
  the paths. A “treatment-mediator interaction” section was added to the
  extraction article.

- New S7 class `ParallelMediationData` for **parallel mediation**
  (`X -> M_j -> Y` for independent mediators `j = 1..k`). The total
  indirect effect is the sum of per-mediator products, `sum(a_j * b_j)`.
  Completes the structural trio alongside `MediationData` (simple) and
  `SerialMediationData` (serial). Effect extractors (`nie`, `nde`, `te`,
  `pm`, `paths`) have methods for the new class;
  [`paths()`](https://data-wise.github.io/medfit/reference/paths.md)
  returns interleaved `a1, b1, a2, b2, ..., c_prime`.

- [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  now builds `ParallelMediationData` from **lm/glm** fits: pass the
  per-mediator models via `mediator_models` and the new
  `structure = "parallel"` argument. `structure = "auto"` (default)
  infers serial vs parallel from the mediator models’ predictors,
  defaulting to serial unless there is positive evidence of a parallel
  structure. The returned `@vcov` is named `a1, b1, ..., c_prime`; the
  `b_j` (jointly fit in the outcome model) keep their mutual covariances
  and `cov(b_j, c')`, while the `a_j` (separate mediator regressions)
  are independent.

- [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  also builds `ParallelMediationData` from a single **lavaan**
  [`sem()`](https://rdrr.io/pkg/lavaan/man/sem.html) fit: pass a
  `mediator` vector and (optionally) `structure = "parallel"`.
  `structure = "auto"` infers parallel vs serial from the SEM’s
  regression rows. Because the system is estimated jointly, the
  extracted `@vcov` preserves **all** off-diagonals — including
  `cov(a_j, b_j)` and `cov(a_j, a_{j'})` — so SEs reflect the full joint
  covariance (and differ from the block-diagonal lm/glm engine for
  identical data).

- New [`confint()`](https://rdrr.io/r/stats/confint.html) method for
  `ParallelMediationData` (`parm = "paths"` or `"effects"`). The
  indirect-effect variance uses the delta method over the full
  `{a1, b1, ..., ak, bk}` covariance block, so correlated `b_j` are
  handled correctly; `method = "boot"` directs to
  [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md).

### Bug Fixes

- `print(summary(x))` now shows the formatted summary for
  `MediationData`, `BootstrapResult`, and `SerialMediationData` instead
  of dumping the raw list. The `print.summary.*` S3 methods exist and
  are correct, but their `S3method()` NAMESPACE directives are not
  activated once `print` participates in S7 dispatch, so
  [`print()`](https://rdrr.io/r/base/print.html) silently fell back to
  `print.default`. They are now registered explicitly in `.onLoad()`
  (the same fix already used for `print.mediation_effect`), so dispatch
  works whether the package is installed or loaded via `load_all()`.

### Internal

- `R CMD check` is clean again (0 errors / 0 warnings / 0 notes). Added
  `@usage NULL` to the `BootstrapResult`, `ParallelMediationData`, and
  `InteractionMediationData` class docs (matching `MediationData` /
  `SerialMediationData`), which removes spurious codoc mismatches from
  the S7 constructors’ complex property defaults. The `show` method
  bodies registered in `.onLoad()` now delegate to a top-level helper
  (`.show_via_print()`) so no literal
  [`print()`](https://rdrr.io/r/base/print.html) call sits in `.onLoad`,
  clearing the “startup functions should use packageStartupMessage”
  note.

### CRAN compliance and dependencies

- Moved **MASS** from `Suggests` to `Imports`: the default parametric
  bootstrap (`bootstrap_mediation(method = "parametric")`) calls
  [`MASS::mvrnorm()`](https://rdrr.io/pkg/MASS/man/mvrnorm.html)
  unconditionally, so MASS must always be available (it previously
  failed under CRAN’s “noSuggests” check flavor).
- Documentation/CRAN fixes (forward-ported from the 0.2.1 CRAN
  resubmission): added `\value` to the exported
  `print`/`print.summary.*` methods; converted `\dontrun{}` examples to
  self-contained `\donttest{}` (the lavaan example guarded with
  [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html)); spelled
  out the “GLM” acronym and added method references (`<doi:...>`) to the
  Description; enriched `inst/CITATION`.

## medfit 0.2.1 (2026-06-18)

CRAN release: 2026-06-18

CRAN patch release. No new features; documentation and compliance fixes
only (all changes forward-ported to 0.3.0).

### CRAN compliance and documentation

- Explained the “GLM” acronym in the package Description.
- Added method references (`<doi:...>`) to the Description field
  (MacKinnon, Lockwood & Williams 2004; Tofighi & MacKinnon 2011).
- Added `\value` sections to the four exported `print` /
  `print.summary.*` methods.
- Converted `\dontrun{}` examples to self-contained `\donttest{}`
  (lavaan example guarded with
  [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html)).
- Enriched `inst/CITATION` with method references and ORCID.
- Moved **MASS** from `Suggests` to `Imports`: the default parametric
  bootstrap calls
  [`MASS::mvrnorm()`](https://rdrr.io/pkg/MASS/man/mvrnorm.html)
  unconditionally, so MASS must always be available.

## medfit 0.2.0 (2026-05-31)

### New features

- [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  now supports **serial mediation** (`X -> M1 -> M2 -> ... -> Mk -> Y`),
  returning a `SerialMediationData` object. For **lavaan** fits, pass an
  ordered vector of mediator names (`mediator = c("M1", "M2")`); for
  **lm/glm** sequential regressions, pass the per-mediator models via
  the new `mediator_models` argument. The returned `@vcov` is named with
  the path aliases `a`, `d1`, …, `b`, `c_prime` and preserves the full
  covariance structure (single-equation lavaan SEM keeps the
  off-diagonals; the separately-fitted lm equations are block-diagonal
  among chain paths with `cov(b, c')` preserved), so downstream serial
  indirect-effect confidence intervals are correct.

### Bug Fixes

- [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  for lavaan models now preserves the **off-diagonal** covariances among
  the `a`, `b`, and `c_prime` path aliases in the returned `@vcov`.
  Previously only the diagonal variances were copied, so
  `vcov[c("a", "b"), c("a", "b")]` reported `cov(a, b) = 0` even when
  the underlying lavaan fit had a genuinely non-zero covariance
  (e.g. single-equation SEM with correlated residuals, or the
  within-equation `cov(b, c')`). This silently biased downstream
  indirect-effect confidence intervals; the alias block now reproduces
  the true `lavaan::vcov()` covariances exactly.

- [`print()`](https://rdrr.io/r/base/print.html) on the effect objects
  returned by
  [`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
  [`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
  [`te()`](https://data-wise.github.io/medfit/reference/te.md), and
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) (class
  `mediation_effect`) now reliably shows the formatted label
  (e.g. `Natural Indirect Effect (NIE): 0.1897`). Because
  `mediation_effect` is layered on the base `numeric` type, S3 dispatch
  could miss `print.mediation_effect` and fall back to the bare numeric
  value plus raw attributes. The method is now explicitly registered in
  `.onLoad()` so dispatch works whether the package is installed or
  loaded via `load_all()`.

- The **lm/glm** extractor now copies the full within-equation
  covariance onto the `a`/`b`/`c_prime` aliases, so `cov(b, c_prime)` is
  preserved (previously only the diagonal variance was copied). The
  indirect effect `a * b` is unchanged; `cov(a, b)` remains `0`
  (separate equations).

### Internal

- Overall test coverage raised to \>90% (enforced via `codecov`), and
  all repo-wide `lintr` warnings cleared. A shared alias-vcov helper
  ([`.expand_vcov_with_aliases()`](https://data-wise.github.io/medfit/reference/dot-expand_vcov_with_aliases.md))
  now backs both the lm/glm and lavaan extractors so the two engines
  cannot drift.

## medfit 0.1.0 (2025-12-20)

**Initial CRAN release**

### Overview

medfit provides S7-based infrastructure for fitting mediation models,
extracting path coefficients, and performing bootstrap inference. It
serves as the foundation package for the mediationverse ecosystem.

### Major Features

#### User-Friendly API

- **[`med()`](https://data-wise.github.io/medfit/reference/med.md)
  function** - Recommended entry point for most users
  - Fits mediator and outcome models automatically
  - Optional bootstrap inference with `boot = TRUE`
  - Supports covariates and different model families
  - Example: `med(data, treatment = "X", mediator = "M", outcome = "Y")`
- **[`quick()`](https://data-wise.github.io/medfit/reference/quick.md)
  function** - One-line summary of results
  - Compact display: `NIE = 0.19 [0.08, 0.32] | NDE = 0.16 | PM = 55%`
  - Works with all medfit objects

#### Effect Extractors

- **Dedicated functions for mediation effects**
  - [`nie()`](https://data-wise.github.io/medfit/reference/nie.md):
    Natural Indirect Effect (a × b)
  - [`nde()`](https://data-wise.github.io/medfit/reference/nde.md):
    Natural Direct Effect (c’)
  - [`te()`](https://data-wise.github.io/medfit/reference/te.md): Total
    Effect
  - [`pm()`](https://data-wise.github.io/medfit/reference/pm.md):
    Proportion Mediated
  - [`paths()`](https://data-wise.github.io/medfit/reference/paths.md):
    Path coefficients (a, b, c’)

#### Model Fitting and Extraction

- **[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  function** - Fit mediation models with formula interface
  - GLM engine for linear and generalized linear models
  - Support for continuous and binary outcomes
  - Covariates in both mediator and outcome models
  - Returns `MediationData` object
- **[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  generic** - Extract from fitted models
  - Methods for lm, glm objects
  - Optional lavaan support (when installed)
  - Extracts path coefficients and variance-covariance matrices

#### Bootstrap Inference

- **[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
  function** - Three bootstrap methods
  - **Parametric**: Fast, assumes multivariate normality
  - **Nonparametric**: Robust, resamples data and refits models
  - **Plugin**: Point estimate only
  - Parallel processing support
  - Returns `BootstrapResult` with confidence intervals

#### Tidyverse and Base R Integration

- **[`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
  [`glance()`](https://generics.r-lib.org/reference/glance.html)
  methods** for broom compatibility
  - [`tidy()`](https://generics.r-lib.org/reference/tidy.html): Convert
    to tibble (paths, effects, or both)
  - `tidy(conf.int = TRUE)`: Include confidence intervals
  - [`glance()`](https://generics.r-lib.org/reference/glance.html):
    One-row model summary
- **Base R generics**: [`coef()`](https://rdrr.io/r/stats/coef.html),
  [`vcov()`](https://rdrr.io/r/stats/vcov.html),
  [`confint()`](https://rdrr.io/r/stats/confint.html),
  [`nobs()`](https://rdrr.io/r/stats/nobs.html)

#### S7 Class Architecture

- **Modern S7 object system** for type safety and extensibility
  - `MediationData`: Simple mediation (X → M → Y)
  - `SerialMediationData`: Serial mediation (X → M1 → M2 → … → Y)
  - `BootstrapResult`: Bootstrap inference results
  - All classes include validators, print, summary, and show methods

#### Input Validation

- **Defensive programming** with `checkmate` package
  - Fast, informative error messages
  - All user-facing functions validate inputs
  - Complements S7 class validators

### Documentation

- **Four comprehensive articles** (on the package website)
  - Getting Started: Quick introduction with examples
  - Introduction: Detailed package overview
  - Model Extraction: Extract from lm, glm, lavaan objects
  - Bootstrap Inference: Parametric and nonparametric methods
- **pkgdown website**: <https://data-wise.github.io/medfit/>

### Testing and Quality

- **427 comprehensive tests** (0 errors, 0 warnings)
  - Full coverage of S7 classes and methods
  - Validation tests for data integrity
  - Edge case handling
- **CI/CD**: GitHub Actions workflows
  - R CMD check on Ubuntu, macOS, Windows
  - Test coverage tracking with Codecov
  - Automated pkgdown deployment

### Ecosystem

- Foundation package for the **mediationverse** ecosystem
- Supports future integration with probmed, RMediation, medrobust
- Tested with R \>= 4.1.0, S7 \>= 0.1.0
