# medfit (development version)

## Bug fixes

* The native acceptance gate no longer rejects a correct fit at an active bound because of roundoff (#238). The
  multiplier slope of a bound is now compared with a floor that scales with the natural-unit gradient norm
  (`1e-10` of it, never below `1e-12`), not with the fixed `1e-12`. On the reference BLAS (the GitHub Linux runner)
  the extreme-scale floor fixture of the #213 gate (variances from 1e-3 to 1e3) returned a slope of 2e-12 against a
  gradient of norm 1e4, was rejected, and left a wrong-branch optimum as the only accepted start; the gate now passes
  144 of 144 runs on that BLAS, and the CI `gates` workflow runs it strict.

# medfit 0.11.1

## New features

* Native `SEMFit` diagnostics now record the best-of-starts verdict in
  `@diagnostics$optimum`; `summary()` prints a concise note when starts disagree
  or only one start is accepted. Existing optimization warnings are unchanged.

* `anova()` on `SEMFit` records whether each chi-square p-value is valid in the logical attribute `p_valid`
  (named by row, `NA` for the first row). It is `FALSE` where the null sits on the boundary of the parameter space,
  the case that already warned. The p-value and the warning are unchanged; code that had to read the warning text
  can now test `attr(x, "p_valid")`.

## Bug fixes

* `anova()` on `SEMFit` refuses a pair where a nonzero fixed parameter (for example `M1 ~~ 0.5*M2`) is in one fit and
  absent from the other. Parameter-table inclusion alone let such a pair through, with a chi-square p-value for two
  models that are not nested. A parameter fixed at a value in one fit and free in the other is still a valid
  restriction.

* `bootstrap_mediation(method = "nonparametric")`, with or without `cluster =`, now draws every resample in the
  calling process before the refits are spread over cores. A fixed `seed` gives the same resamples and
  `boot_estimates` for any `ncores` and for sequential runs; before, each worker drew from its own random-number
  stream, so `ncores` changed the result (#247). For a `statistic_fn` that uses no random numbers, sequential runs keep the stream of 0.11.0, so their results do not
  change; one that does use them sees a different stream, because its draws no longer interleave with the
  resampling. `?bootstrap_mediation` states what the seed does and does not cover (a `statistic_fn` that draws random
  numbers itself, and BLAS thread effects in the last digits).

# medfit 0.11.0

## New features

* Factor, character and logical covariates in the native engine. A column of that kind named on a regression's
  right side of `fit_sem()` or `fit_mediation(engine = "native")` is expanded to 0/1 dummies named `<column>_<level>`
  (reference: the first level; character columns sort in the C locale), built before rows with missing values are
  dropped. `g:m` expands to one product per dummy, `fixed_x = "g"` fixes every dummy, `mbco_sem()` refits through a
  stored factor map, and four-way extraction accepts a factor covariate in the mediator equation. A label or fixed
  value on the factor (`b*g`) stops, as do ordered factors, a product of two factors, and a factor treatment or
  mediator; the numeric-only error now says where factors are accepted. Numeric-only models are unchanged.
* A worked example article, "Worked example: study hours, engagement and GPA" (`vignettes/articles/example-gpa.qmd`): a simulated
  mediation analysis with known truth, with the delta-method and Sobel formulas written out and a table of 26 pass/fail
  checks (against the truth, `lm`, lavaan, the native engine, a bootstrap and a Monte Carlo coverage study). The page
  stops its own build if a check fails, and `tests/testthat/test-example-gpa.R` runs the same code.
* Four-way standard errors can be population-average: `options(medfit.covariate_mean_variance = TRUE)` adds the
  sampling variance of the estimated covariate mean, `(theta3 * gamma)^2 * Var(c) / n` (case-weighted when the
  fit has weights), to INTref, the NDE and the TE in `tidy()` and `confint()`. The default is
  unchanged (conditional on the observed covariates, as lavaan's `:=` and the glm route). On simulated data with
  a strong covariate effect on the mediator, the conditional SE of INTref, 0.0995, becomes 0.1516 against a bootstrap
  SD of 0.1568; on `mediation_demo` the term is about 0.08% of the SE.

## Bug fixes

* `fit_sem()` no longer fails when a supplied start sits in a bad basin. The retries are perturbations of that start, so
  every attempt could stall; with `n_starts >= 3` the last attempt is now the model's own moment-based start. Found by
  the reliability gate (latent structure, n = 50, one replicate: 4 of 9600 shipped-configuration fits ended with `no start
  converged`; now 0). A start that was accepted before is unchanged, and models with nonlinear constraints keep their
  starts.
* medfit installs and loads with development S7 (versions after 0.2.2). The nullable property types
  (`S7::class_numeric | NULL` and the list, data frame and call equivalents) and plain `S7::class_numeric` are
  registered as S4 unions before the classes use them, in `.onLoad()` as well as at build time, and the package calls
  S7's `S7_on_load()`, `S7_on_unload()` and `S7_on_build()` hooks when the installed S7 has them (S7 0.2.2 and
  earlier still use `methods_register()`). Reported and first fixed by t-kalinowski (PR #214); the plain-numeric
  union was added because the installed package failed to load under development S7 although `load_all()` worked.
  No change for users of S7 0.2.2.
* Nonlinear equality and inequality constraints in the native engine no longer land on a wrong point (#213).
  A fit such as `a*b/sqrt(2*(b^2*Vm+Vy)) == q` used to step to a negative variance (no start converged), or stop
  on the wrong sign branch of the constraint and report `converged` with a likelihood-ratio statistic of 1459
  where 0 is right. Behavior change, for fits with a nonlinear row only (every other fit is bit-identical):
  the variances that appear in a nonlinear row get a lower bound of `1e-4` times their natural unit (the variable's
  variance, so it does not depend on the data scale), and the fit warns when a bound is active; the model without
  the nonlinear rows is fitted first, and its estimate and sign-flipped copies of it are extra starts; a feasible
  reference estimate is never replaced by a worse accepted fit, and a fit that reaches it no longer warns that the
  starts disagree. Checked against an independent profile-likelihood oracle on 24 fixtures at 6 constraint values
  (`tests/sim/sem-nonlinear-profile-gate.R`). A residual variance below `1e-4` of the variable's variance (an
  R-squared above 0.9999) is outside what a nonlinear row can fit and is reported by the floor warning.
* `AIC()` and `BIC()` with several `SEMFit` fits now stop when the fits do not share their observed variables, and
  name the variables that differ. A product term (`x:m`) adds a column to the joint likelihood, so a fit with a
  product and the same model without it describe different data; before, the two were ranked anyway (on
  `mediation_demo`, the same outcome gave AIC 3934.7 with the product and 2994.1 without). `anova()` and
  `mbco_sem()` already refused such a pair (#206).

* A fit with nonlinear constraints that found exactly one optimum among its starts (every other start failed or was
  rejected) was returned without a note, although the failed starts are often the sign-flipped ones that would have
  found another branch. It now warns "only 1 of N starts reached an accepted solution". Found by running the
  simulation gates on a Linux runner with the reference BLAS, where the `#213` floor fixture at an extreme data scale
  (R-squared of 1 - 1e-6) kept a wrong-branch optimum silently; that fixture's underlying instability at the floor
  is tracked separately.

## Lifecycle

* The native maximum-likelihood engine (`fit_sem()`, `mbco_sem()`, `SEMFit`, `fit_mediation(engine = "native")`) is no
  longer marked experimental. It met the written exit criteria in
  `planning/specs/CRITERIA-native-experimental-exit-2026-10-17.csv`: all 17 native simulation gates re-run green on
  this code (`tests/sim/run-gates.R`), lavaan and OpenMx parity hold, and no correctness issue is open. From now on
  the exported signatures, the `SEMFit` properties and the model-syntax grammar in `?medfit-syntax` change only through
  a deprecation; numerical fixes are not breaking changes.
  New syntax and new properties are added without changing what an existing name means: the planned categorical
  mediators, outcomes and treatments will arrive as additions (the dummy names such as `g_b` and the product name
  `m:x` stay), and `tests/testthat/test-api-freeze.R` pins the current names, argument order and grammar so a rename
  fails the suite.

## Documentation

* Removed a literal header file path and a literal `Version {version}` footer placeholder that the website printed;
  mathematics uses the built-in MathJax support in pkgdown. README installation guidance now distinguishes available
  binaries from source installation.

# medfit 0.10.0

## New features

* The native engine reads a product term, `:`, in a regression: `y ~ x + m + x:m` (`fit_sem()` and
  `fit_mediation(engine = "native", model = )`). The product is an observed exogenous variable whose column
  `x * m` the engine builds from `data` after listwise deletion, as lavaan does, so the likelihood, the constraints and the
  mean structure are unchanged. `x:m` and `m:x` are one term; the table, `tidy()` and the extraction use the
  canonical name, the two factor names sorted in the C locale (`m:x` for `x` and `m`), and a label
  (`b*x:m`) names the coefficient. Writing both spellings in one equation is an error that names both. A product
  term always turns the mean structure on (`meanstructure = FALSE` with a product is an error), because the
  four-way decomposition needs the mediator intercept. A column already in `data` under either spelling is used
  only if it equals `x * m` on the rows kept, and otherwise stops with a message that names the column; with
  `fixed_x = TRUE` the product column is fixed at its sample moments with the other exogenous variables.

* `extract_mediation()` on a `SEMFit` now returns the four-way decomposition (`InteractionMediationData`) when
  the outcome equation carries the treatment-by-mediator product; `decomposition = "four_way"` and `interaction =`
  (the product written with `:`) work, and without the product `decomposition = "four_way"` is refused with a
  message that says to add `x:m`. This replaces the 0.9.0 refusal. On a simple model the four-way parts equal the `glm`
  route to the printed digits, and on `mediation_demo` the native and lavaan coefficients and sandwich standard
  errors agree to the printed digits. The estimate names and `outcome_predictors` carry the canonical `m:x`; the
  lavaan route keeps the spelling you wrote. Any other product involving the treatment or the mediator is
  refused on this route. Centering matters: the reference level `m_star = 0` and `E[M | X = 0]` depend on where the
  mediator is centered, so CDE and INTref move with centering while NDE, NIE and the total do not (the native
  four-way article shows this).

## Supported class for a product (limits)

A model with a product is fitted only inside the class below; anything else is an error that names the
feature and says it is not yet supported with products. A model without a product keeps every 0.9.0 capability.

* Recursive models; no residual covariance between observed outcomes (a `~~` between outcomes, or a free one;
  the covariance that completion would add between pure outcomes is fixed at 0 with one note, and the same model
  without the product estimates it); no shared label, fixed coefficient, bound, or `==`, `<`, `>` constraint on a
  coefficient; intercepts free, not shared and unconstrained; no outcome-derived regressor (a product factor that is the
  target or one of its descendants). `:=` parameters are allowed. Exogenous products and products of two
  exogenous variables (`x:w`) are inside the class; latent products, `x:x` and three-way products are not supported.

* Model tests. When a product factor is itself a regression target, or the exogenous (co)variance block is
  restricted, the global chi-square is not valid, so `glance()` reports chi-square, df and p-value as `NA` with a
  note, `summary()` and `print()` show the note, `anova()` and `mbco_sem()` refuse naming the product, and
  `information = "expected"` is refused for a product with an endogenous factor (use the default observed
  information with `se_type = "sandwich"`). `logLik()`, AIC and BIC stay defined. `fit_sem()` warns once when the
  model test is unavailable and once when a product is fitted without `se_type = "sandwich"`. A product of
  exogenous variables with a free exogenous block keeps the ordinary test (null simulation, 1000 replications,
  n = 500: rejection 0.055 and 0.056 at nominal 0.05 for normal and centered-exponential factors).

* The product depends on the 0.9.0 mean structure (a product turns it on) and on `fixed_x` (a fixed set
  includes the product columns). The native four-way read uses the shared worker, so it carries the corrections
  shipped in 0.9.0 (standard errors that include the mediator-covariate term, an error for a treatment product
  in the mediator equation, weighted covariate means in INTref; see "Behavior changes" under 0.9.0 below).

# medfit 0.9.0

## New features

* The native engine fits observed intercepts and means. Any `y ~ 1` row (or `meanstructure = TRUE` in `fit_sem()`
  and `engine_args = list(meanstructure = TRUE)` in `fit_mediation()`) turns the mean structure on and frees every
  observed intercept the model does not write, as lavaan does. The fit works in mean-centered coordinates, so data
  far from zero (checked to a mean of 1e5 standard deviations) no longer ruins the information matrix; intercepts
  can be constrained or bounded (checked to a mean of 1e3 standard deviations). Weights, the sandwich covariance,
  linear and nonlinear constraints, `anova()` (a covariance-only fit counts as having free intercepts), `mbco_sem()`
  and `fit_mediation(engine = "native")` all work with it. The four-way decomposition on a native fit is refused by
  name until the `:` operator arrives (planned for 0.10.0).

* `fit_sem(fixed_x = )` (and `fit_mediation(engine = "native", engine_args = list(fixed_x = ))`) fixes the mean,
  variance and covariances of exogenous observed variables at their sample values, as lavaan's `fixed.x = TRUE`
  does. `TRUE` selects every exogenous observed variable (product columns included) and a character vector selects
  any subset; the default stays `FALSE`. The structural estimates, their standard errors (model-based and
  sandwich), the degrees of freedom and the chi-square do not change; the parameter count falls, and the
  fixed rows stay in `@table`, `tidy()` and `summary()` with a `fixed_x` flag and no standard error. On one
  simulated model with 30 covariates (n = 400, Apple M5 Pro) the fit went from 561 to 65 parameters and from
  about 5 seconds to about 0.2 seconds; your timing will differ.

## Behavior changes

* With `fixed_x`, `logLik()`, `AIC()` and `BIC()` are conditional on the fixed variables (lavaan's value), so
  `anova()`, `mbco_sem()` and multi-fit `AIC()`/`BIC()` now stop when the fits' fixed sets or data differ. A
  `(co)variance` or intercept statement on a selected variable is an error; lavaan keeps such a statement free and
  lets the degrees of freedom move. `glance()` for a `SEMFit` gains a `fixed_x` column (`""` when nothing is
  fixed), and `print()` and `summary()` say what the log likelihood is conditional on. `fixed_x = FALSE` results
  are unchanged.

* A fixed intercept, `y ~ 0*1`, is now a restriction in the native engine. 0.8.0 dropped the row and
  returned the covariance-only fit; 0.9.0 reads it as "the mean of `y` is 0", which costs one degree of freedom,
  changes the discrepancy, and can be compared with `anova()` against the fit that frees it. Any `y ~ 1` row
  (free, fixed or labeled) now turns the mean structure on and frees every unwritten observed intercept, as lavaan
  does; `meanstructure = FALSE` with an intercept is an error. A model without `~1` rows is unchanged.

* Names without dots. Everything medfit names now uses snake_case: `tidy()` and
  `glance()` columns `std.error`, `p.value`, `conf.low` and `conf.high` became
  `std_error`, `p_value`, `conf_low` and `conf_high`, and the `tidy()` arguments
  `conf.int` and `conf.level` became `conf_int` and `conf_level`; the old
  argument names still work and warn. The S3 classes of `summary()` results are
  now `summary_MediationData`, `summary_SEMFit` and so on. `mbco_sem()` keeps
  `p.value`, because it returns a base-R `htest`. Update code that reads the
  old column names.

* `anova()` and `mbco_sem()` for `SEMFit` close two more gaps in their guards. The nesting check now also keeps the
  equalities that repeated labels impose in the larger model (`M ~ a*X`, `Y ~ a*M`): releasing the shared label no
  longer returns a chi-square p-value. The boundary warning now covers an active nonlinear inequality (`a*b > 0`
  at the restricted fit), which it missed before.

* `anova()` for `SEMFit` no longer reports a p-value for a restricted model that is not nested in the larger one
  through constraints. The nesting check compared only the free parameters, so `a == b` against
  `a == 0` and `b == 0.5` (the second breaks the first) returned a chi-square p-value. The restricted model must now keep every
  fixed value, bound and constraint of the larger one (a bound includes a single-label inequality such as `a > 0.1`): a linear equality must follow from the restricted model's
  equalities and fixed values, and a nonlinear equality or an inequality must appear verbatim. Comparisons that
  are not nested now stop with "not nested".

* Four-way decomposition from a lavaan fit (`extract_mediation()` with an
  `x:m` or `interaction =` product) gave wrong results in three cases, now fixed:
  - The standard errors of INTref, NDE and TE left out the mediator-covariate
    term (`g * cbar` and its covariance with the mediator intercept), so they
    were too small when the mediator equation has a covariate (INTref SE 0.037
    against lavaan's `:=` 0.095 in one check). They now match lavaan's `:=`.
  - A treatment product in the mediator equation (`m ~ x + w + x:w`), or a
    treatment-by-covariate product in the outcome equation, returned a wrong
    decomposition without a message. Both are now errors that name the
    equation.
  - With sampling weights, INTref used unweighted covariate means, so it
    differed from the lm/glm route (1.16 against 1.46 on one data set). It now
    uses the weighted means.
  - Related: a mediator predictor that is not a numeric column of the model data (for
    example a latent variable) is now an error ("Cannot compute the covariate
    means for E[M | X = 0]"); it used to be skipped, which dropped its
    contribution from INTref without a message. A weighted multi-group fit is
    an error as well.
  Point estimates change only for the weighted case and for covariates that
  used to be skipped. The effects are the treatment contrast 0 to 1, as on the
  lm/glm route.

## Documentation

* Two new pages for the native engine, in the Guides menu: "Native engine in five
  minutes" (write, fit, read, test, constrain, extract) and "The native engine
  guide" (syntax, fitting and reading, standard errors and weights, constraints and
  how each kind is solved, model comparison and the MBCO test, diagnostics, the route
  to the mediation objects, limits). A third page, "Native engine, step by step",
  walks the same path in nine checked steps, including a chain of three paths and, in the last step, `fixed_x`.

* The constraints page and the introduction no longer say native constraints must
  be linear: nonlinear constraints, `anova()` for nested fits and
  `mbco_sem(paths = )` are described there.
* Cookbook recipes 14 to 17: compare two native models with `anova()`, a defined
  parameter with its interval, a bound or a fixed path with the diagnostics, and
  checking a native fit before trusting it. Recipe 18 fixes the exogenous covariates with `fixed_x`. The cookbook now
  has eighteen recipes.

# medfit 0.8.0

## New features

* `anova()` for `SEMFit`: the likelihood-ratio test for nested fits,
  `anova(fit_full, fit_restricted)` or several fits in a chain. It reports each
  fit's chi-square (n times the discrepancy), the difference, its degrees of
  freedom and the p-value, and reproduces the per-refit statistics of
  `mbco_sem()` (221.05 and 0.083 on RMediation's `memory_exp`). It compares fits
  that were already made and never refits. Fits on different data or variables,
  with sampling weights, that did not converge, with equal degrees of freedom, or
  where the restricted fit frees a parameter the other leaves out are refused,
  and a null on the boundary of the parameter space (an active bound or
  inequality on a tested parameter) warns that the p-value is not valid, as
  `mbco_sem()` does. Nesting is checked by parameter-table inclusion, which is
  necessary and not sufficient.

* `tidy()`, `glance()` and `confint()` for `SEMFit`. `tidy()` returns one row per
  free and defined parameter (`term`, `op`, `estimate`, `std.error`, `statistic`,
  `p.value`, and the interval with `conf.int = TRUE`); `glance()` returns one
  row with `nobs`, `npar`, `df`, the chi-square test against the saturated model,
  `logLik`, `AIC` and `BIC`; `confint()` covers the defined parameters too. All
  agree with lavaan on a shared model to about 1e-9. `glance()` has no
  `converged` column: `fit_sem()` returns a fit only for an accepted solution, so
  `@converged` is `TRUE` for every `SEMFit` and carries no information (now
  documented). A fit with sampling weights has no likelihood, so its chi-square,
  `logLik`, `AIC` and `BIC` are `NA`.

* Nonlinear equality constraints in `fit_sem()` and `fit_mediation(engine =
  "native")`: `cp == a*b`, `a*b == 0.1`, `exp(a) == 1` and any equality built from
  the allowed functions are solved by SLSQP with the constraint's value and
  Jacobian recomputed at every point (the Jacobian by central differences). The
  covariance is projected onto the null space of the Jacobian **at the
  solution**, and the degrees of freedom count the equalities' rank there. The
  fit matches OpenMx's constrained optimum to 1e-5 and the standard errors agree
  with a reparameterized fit and a bootstrap. Nonlinear inequalities are covered
  in the next entry. A product of labels set to zero (`a*b == 0`,
  `b1*b2*b3 == 0`, also through a `:=` name) is not solved by the nonlinear route,
  whose Jacobian vanishes at the solution: it is `a == 0` or `b == 0`, so the model
  is refitted once per factor from the default start and the smallest discrepancy
  wins (`fit@internals$branch` names the winning line). On RMediation's
  `memory_exp` the `a1*b1 == 0` statistic is the exact 0.083100, where a nonlinear
  solve lands on 221.05. Several zero-product lines give the cartesian product of
  branches (at most 64).

* `mbco_sem()` tests a product of k labeled paths: `mbco_sem(fit, paths = c("a",
  "d", "b"))` (or a vector in `a` with `b` missing) refits once per path, keeps the
  smallest diffLL and refers it to chi-square(1). With two paths it gives exactly
  the old result (`mbco_sem(fit, "a", "b")` still works). The null is a union of
  k hypotheses, so the test is conservative. A simulation gate
  (`tests/sim/sem-mbco-k-size.R`, 2000 replications per cell) found the size at
  most 0.055 at alpha = 0.05 with one zero path and under 0.005 with two or three.

* Nonlinear inequality constraints in `fit_sem()`: `a*b > 0.1`, `a*b < 0.5`, and a
  defined name inside a constraint (`ab := a*b` then `ab > 0`) are solved like the
  nonlinear equalities, as rows `c(theta) <= 0` with a recomputed Jacobian. The
  acceptance test for a curved constraint now uses the reduced Hessian of the
  Lagrangian, the objective's Hessian plus each active nonlinear row's curvature
  times its multiplier; the objective's Hessian alone can call a saddle of the
  restricted problem a minimum (or the reverse). **`n_starts` changes meaning for a
  model with a nonlinear constraint:** every start is tried and the best accepted
  one is kept (before, the first accepted start was used), and a warning says when
  the accepted starts reached different optima, because a nonlinear constraint can
  leave several (`a*b > 0.1` is feasible for two positive or two negative paths).
  Models without a nonlinear constraint behave as before.

* A sum of products set to zero (`a1*b1 + a2*b2 == 0`) fits through the same
  nonlinear route and is documented as best-effort: unlike a single product it has
  no exact reduction, so the result is the best of the starts tried, and the
  starts-disagree warning means a better optimum may exist (raise `n_starts`).

## Behavior changes

* A `SEMFit` has one spelling for a parameter: its label, else `lhs op rhs`
  without spaces, as lavaan names coefficients. `coef()`, `vcov()`, `tidy()`
  and the accessors `extract_mediation()` reads now agree. Before, `coef()` of an
  unlabeled parameter read `"M ~ X"` and `"X ~~ X"` (with spaces) while the
  accessors read `"M~X"`, and a latent loading was named like a regression into
  its indicator (`"m2 ~ eta"`, with `tidy()` reporting `op` as `=~`). Now the
  names are `"M~X"`, `"X~~X"` and `"eta=~m2"`, and they equal
  `names(lavaan::coef())` on a shared model. Code that indexed `coef(fit)` by an
  unlabeled spaced name must drop the spaces; labeled parameters are unchanged.
  The wrong names were never part of a release's documented interface
  (`SEMFit` is experimental).

* `fit_sem(weights = )` replaces `fit_sem(sampling_weights = )`, the name
  `fit_mediation()` already uses, and `mbco_sem(object, a, b)` replaces
  `mbco_sem(fit, a, b)`, the name the other `SEMFit` methods use. The old names
  still work and warn once per session with `lifecycle`; positional calls are
  unaffected.

## Bug fixes

* Native SEM fits with an active nonlinear constraint (`cp == a*b`, `a*b > k`,
  `a*b + cp == 0`) are polished after the solver is accepted. SLSQP stops along a
  flat constraint tangent, so estimates could sit up to 4e-5 from the exact
  optimum; a few Newton steps on the KKT system (using the Lagrangian Hessian)
  now bring them within 1e-10 of a fit with the constraint solved out. The
  acceptance gate is unchanged and is re-run on the polished point, which
  replaces the accepted one only if it is accepted again.

* `fit_sem()` now gives the same verdict on a wrong-side active bound whether or
  not the model has constraint lines. A solution sitting at a bound with the
  gradient pointing into the interior (a point that is not a local minimum) was
  rejected for a model without constraints but accepted with a warning once any
  `==`, `<` or `>` line was added, even one that never binds. It is now rejected
  in both cases, and the next start is tried; each bound is judged by the same
  statistic, the gradient over the root of the Hessian diagonal, so an indefinite
  Hessian cannot hide it. A wrong-signed active inequality
  constraint still warns and does not reject. Behavior change: a fit that
  returned with the warning "lower bound of ... is active, but moving into the
  feasible region would lower the objective" now errors or uses another start.
  `fit_sem()` is experimental and no dependent package uses it, so there is no
  deprecation period.
* `nobs()`, `@n_obs` and `med()` no longer overstate the sample size when the
  data have missing values on the model variables. The lm/glm extractors counted
  `nrow(data)` although `glm()` had dropped the incomplete rows, so a fit with 5
  missing treatment values reported 400 observations on 395 rows. `n_obs` now
  counts the rows the models used, and the stored `@data` drops the same rows, so
  the four-way covariate means use them too. `fit_mediation()` drops rows that
  are incomplete on any variable in either formula before fitting, so the
  mediator and outcome models share one sample; `extract_mediation()` warns when
  models you fitted yourself used different rows. The estimates are unchanged
  when the models already used the same rows; the native and lmer engines
  already counted correctly.
* `fit_mediation()` applies `subset`, `weights`, `offset`, `etastart` and
  `mustart` to the rows you passed, then drops incomplete rows. After #138 a
  `subset` containing an incomplete row selected the next row instead, and a
  vector `offset` stopped the fit with a length error. `n_obs` now counts the
  rows the models used when `subset` is given.
* `fit_mediation(engine = "lmer")` now stops with an error when either formula
  contains an `offset()`. The engine rebuilds both formulas from their terms,
  which exclude offsets, so the offset was dropped without a word and the fit
  was the same as without it.
* Joint mediation effects (several mediators with treatment-by-mediator
  products) now check that every variable two models share holds the same
  values in the same order, not only that the row names agree. A mediator model
  fitted to a reordered copy of the data with its row names reset used to pass,
  and the cross-equation covariance, and with it the joint effect intervals,
  was silently wrong.
* Fits made with `na.action = na.exclude` no longer break the extraction. The
  joint covariance came back with `NA` blocks and `NA` effect intervals and no
  error, and the residual standard deviation of a Gaussian `glm()` stopped
  `extract_mediation()` with a missing-value error.
* `fit_sem()` now rejects a self-regression (`Y ~ Y`) and a repeated row
  (`Y ~ X` twice, or `X ~~ Y` and `Y ~~ X`) at parse time, naming the row. Before,
  `Y ~ Y` failed late with "no start converged" and a repeated row with "a path
  appears twice in the RAM specification". Infeasible bounds (`a > 1` with
  `a < 0.5`) now stop with a message naming the parameter and both bounds instead
  of an internal assertion.
* `fit_sem()` now accepts a consistent set whose inequality repeats an equality:
  `a == b` with `a - b < 0`, or `a + b == 0.8` with `a + b > 0.8`. These sets
  stopped with "no start converged" on 5 to 7 of 12 simulated datasets, because
  the inequality is active at every feasible point and gave the optimizer a
  rank-deficient active Jacobian. The optimizer now gets the rows without an
  inequality that the equality rows imply and satisfy; the acceptance gate still
  checks every row, so an implied inequality the equalities violate
  (`a + b == 0.8` with `a + b < 0.5`) is still reported as violated. Behavior
  change: sets that errored now fit, and the estimates equal those of the model
  with the redundant inequality deleted.

## Documentation

* Cookbook recipe 12 shows a nonlinear constraint (`cp == a*b`) and the indirect
  effect of a three-path chain with `mbco_sem(paths = )`. The 0.7.0 entry for
  `fit_mediation(engine = "native")` no longer says it handles serial and parallel
  mediators; it takes one mediator, and `model-native-multi` already said so.

* New article "lavaan and the native engine" (Guides menu): both engines run on
  `mediation_demo` at site build, then a feature table lists what each does with a
  status for every row. `test-lavaan-comparison.R` computes each status from a live
  probe against lavaan, so a row cannot change without the behavior changing.

* Every cookbook recipe from 1 to 8 now runs after the setup chunk alone. Recipes
  3, 6, 7 and 8 used fitted models that only an earlier recipe created, which
  running the page top to bottom hid; a test now runs each recipe in a fresh
  environment.
* The cookbook and Getting Started no longer present survey weights as covered
  by `se_type = "sandwich"`: HC3 standard errors treat the observations as
  independent, so they do not handle survey clusters, strata or replicate
  weights.
* The home page now leads with the r-universe and GitHub installs of 0.7.0 and
  says that CRAN 0.3.2 does not run the examples (it lacks `mediation_demo`,
  `fit_sem()`, `mbco_sem()` and the joint and cluster classes). Getting Started,
  the cookbook and the Reference Card state the version they need.
* Getting Started and the Introduction now cover the cluster and native engines
  (an engine table, the two classes, and a `fit_sem()` example), and the Model
  Extraction article has a section on extracting from a `SEMFit`. `?extract_mediation`
  lists the `SEMFit` method and the `ClusterMediationData` return, and no longer
  names `brms` as a supported model type; it is still future work.
* `?SEMFit`, `?SEMFit-methods` and `?"medfit-syntax"` now have examples that run.
* The Model Extraction article has a "Which section do I need?" table at the top, ends
  on Next Steps, and sets three dense paragraphs as bullets. The Methods article's
  cluster and native engine sections now have subheadings.
* The Introduction counted `SEMFit` as the seventh class; it is the eighth. Its
  Package Ecosystem list now names probmed and medrobust, and the Reference Card
  gives `joint_effects()` its real argument names (`object`, `estimates`).
* New **Models** menu and landing page, and a **Cookbook** menu in the top menu bar. The Models
  page has a capability matrix and a "find your model" table; eight model pages cover
  simple mediation, binary and non-normal variables, treatment-by-mediator interaction,
  weights and robust standard errors, the `regmedint` engine, serial, parallel and joint
  mediation. Articles are now grouped in an index. A test keeps every model page on the
  landing page, in the index and in the menu, and every cookbook anchor real.
* Six more model pages: cluster-randomized trials (2-1-1), lavaan fits, and four on
  the native engine (paths and defined parameters, a latent mediator, constraints and
  the MBCO test, several mediators and weights). They join the Models menu, the
  landing page and the articles index. A test triggers each error message the pages
  quote, so a reworded message fails the tests before a page goes stale.
* A new "Guides" menu and group with four pages: What changed since CRAN 0.3.2 (the
  results that changed and the calls that now stop with an error), Troubleshooting (the
  errors and warnings a user is most likely to hit, each with its cause and fix), Which
  interval should I use?, and a Glossary of terms and symbols. Tests trigger every
  message the guides quote and check the known answers behind their claims.
* The home page and Getting Started are rewritten so they are quick to skim: a "What's new"
  table, a 60-second start, a "pick your model" table, long examples folded away, and
  Getting Started cut to four steps that link to the model pages. A test checks that
  their article links and cookbook anchors are real.
* The Models page states that `fit_mediation(engine = "native")` takes one mediator;
  for several, fit with `fit_sem()` and call `extract_mediation()`.
* The bootstrap example in the README printed `NIE = 0.19 [0.08, 0.32] | NDE = 0.16 |
  PM = 55%`, which no longer matched the code or its own non-bootstrap fit on the
  same data; it now shows `NIE = 0.164  [0.0867, 0.256] | NDE = 0.293 | PM = 36 %`.
  Its feature list, function list and test count now include the `lmer` engine,
  cluster decomposition and native fits.

# medfit 0.7.0

medfit 0.7.0 adds an experimental native maximum-likelihood structural
equation engine. It is released on GitHub and r-universe only and is not
submitted to CRAN.

## New features

* New native maximum-likelihood structural equation engine (experimental).
  `fit_sem(model, data)` fits lavaan-style model syntax to raw data and
  returns a `SEMFit` with `print()`, `summary()`, `coef()`, `vcov()`,
  `nobs()` and `logLik()`. It handles observed and latent variables, labels,
  fixed values, starts and bounds, linear equality and inequality constraints
  (`==`, `<`, `>`), and defined parameters (`:=`) with delta-method standard
  errors. The syntax is documented in `?"medfit-syntax"`, including the two
  medfit extensions (comma shorthand and `CONSTRAINT(...)`).
* `fit_mediation(engine = "native", model = , treatment = , mediator = )`
  fits the syntax and returns the usual mediation objects, for an observed or a
  latent single mediator (which need not be a column of `data`); serial and
  parallel mediators go through `fit_sem()` and then `extract_mediation(fit,
  mediator = c(...), outcome = )`, because `fit_mediation()` takes one mediator. `extract_mediation()` has a method for `SEMFit`
  that shares its workers with the lavaan route, so the aliases and covariance
  rows are the same; its `source_package` is `"medfit"`. For an observed
  single mediator, `probmed::pmed()` runs on the native route with the plugin
  estimator and the parametric bootstrap, which agrees with the glm route
  within Monte Carlo error; a latent mediator supports the plugin estimator
  only (#105).
* Standard errors use observed information by default (`information =
  "expected"` is available). Against OpenMx they agree to 1.6e-4 in the worst
  of 240 simulated datasets; expected information for latent-variable models
  differs from that reference by up to 11% at n = 50, which is why observed is
  the default. Under equality constraints and at active bounds the covariance
  is projected onto the feasible directions, so a constrained parameter has
  zero variance and `a == b` gives the standard error of the collapsed model.
* Sampling weights and robust standard errors: `fit_sem(sampling_weights = ,
  se_type = "sandwich")` fits weighted maximum likelihood on the weighted mean
  and covariance with the sandwich covariance from casewise scores, and
  `fit_mediation(engine = "native", weights = , se_type = "sandwich")` takes
  the same two arguments the glm engine does. The native sandwich is HC0-type:
  it equals `sandwich::vcovHC(type = "HC0")` per equation and lavaan's robust
  standard errors with `sampling.weights` (to 1e-6 and 1e-5), so it is a few
  percent narrower than the glm engine's HC3 default at moderate n, a gap that
  shrinks like 1/n. `logLik()` is not defined for a weighted fit.
* `mbco_sem(fit, a, b)` tests the indirect effect in a `fit_sem()` fit as the
  minimum of two likelihood-ratio tests: it refits with `a == 0` and with
  `b == 0` (two linear solves), takes the smaller diffLL as the statistic, and
  refers it to chi-square with one degree of freedom. The result is an `htest`
  that also carries both diffLL values. It reproduces OpenMx's diffLL on
  RMediation's `memory_exp` to 1e-6 (221.045546 and 0.083100) and lavaan's
  constrained fits on a latent-mediator model. It tests a product of two
  labeled regression paths, refuses a fit with sampling weights or one that did
  not converge, has its refits inherit the fit's `n_starts` and `control`, and
  warns when a bound or an inequality on the tested path puts the null on the
  boundary of the parameter space. The nonlinear `a*b == 0` is deliberately
  not solved: a nonlinear solver can stop at the branch with the larger
  statistic.
* Not yet supported by the native engine: mean structures (free intercepts),
  the four-way decomposition (it needs the mediator intercept; use
  `decomposition = "two_way"`), standardized estimates, and multilevel models.
  Nonlinear constraints are planned for a later release; until then a
  nonlinear constraint is an error that names the constraint.

## Bug fixes

* `bootstrap_mediation(cluster = )` no longer discards every replicate when the
  statistic refits through `fit_mediation(engine = "lmer")` with fewer than 25
  clusters. The few-cluster warning (fewer than 25 clusters with model-based
  standard errors, or fewer than 10 with any standard error) was counted as a
  failed refit, so the bootstrap that the warning recommends stopped with "Too
  many bootstrap samples failed". The warning now has the condition class
  `medfit_few_clusters` and is not counted; the point estimate on the original
  data still shows it once. In 0.6.0, `se_type = "kr"` with 10 or more clusters
  avoids the warning and so avoids the failure.

## Behavior change

* `fit_mediation()` has a new named argument `model`. An argument passed to
  `stats::glm()` through `...` that partially matches it, such as
  `mod = FALSE`, now binds to `model` instead, and `model` is an error with
  the glm engine. Spelling out `model = FALSE` does not help: drop the
  argument. `glm()`'s own `model` argument cannot be passed through
  `fit_mediation()`.

* `extract_mediation()` on a lavaan fit of a simple single-mediator model now
  appends the rows `m_<treatment>`, `y_<mediator>` and `y_<treatment>` to
  `@estimates` and `@vcov` of the returned `MediationData`. These are the
  names the lm/glm route already used, so code that resolves coefficients by
  name, such as `probmed::pmed(method = "parametric_bootstrap")`, now works on
  lavaan-derived objects instead of failing with a subscript-out-of-bounds
  error. Each new row repeats the `a`, `b` or `c_prime` path with the same
  estimate and covariances; every existing row keeps its name, value and
  position. Code that indexes `@estimates` or `@vcov` by position past the
  `a`, `b`, `c_prime` rows, or that counts their rows, sees three more. A
  lavaan fit with a latent or ordered treatment, mediator or outcome, and
  any `standardized = TRUE` extraction, gets none of the three rows and
  supports the plugin estimators only. Serial, parallel and four-way objects
  are unchanged (#106).

## Documentation

* The cookbook has an eleventh recipe, a latent mediator fitted with the
  native engine and tested with `mbco_sem()`. The model syntax is documented in
  `?"medfit-syntax"`, the Methods and Formulas article has a section on the
  native engine with a subsection on MBCO, and the Reference Card lists
  `fit_sem()`, `mbco_sem()` and the `SEMFit` class.

## Dependencies

* `lifecycle` is now in `Imports`, and the lifecycle badge figures ship in
  `man/figures/`. Deprecations and experimental features are marked with it.
* `nloptr (>= 1.0.4)` is now in `Imports`: the native engine uses its SLSQP
  solver. It contains compiled code, so a source install from GitHub (for
  example `pak::pak("data-wise/medfit")`) builds it unless `lme4` already
  brought it in; the r-universe binaries need no compiler.
* `OpenMx` is now in `Suggests`. Only the tests use it, as the independent
  reference for standard errors and for `mbco_sem()`.

# medfit 0.6.0

## New features

* New `ClusterMediationData` class and an `lmer` method for
  `extract_mediation()`: mediation for a treatment assigned to whole clusters
  (such as schools), with the mediator and outcome measured on individuals (the
  2-1-1 design). Pass the mediator model `M ~ X + ... + (1 | cluster)` as
  `object` and the outcome model as `model_y`, both fitted with
  `lme4::lmer()` on the same rows. The outcome model must carry the mediator
  as its within-cluster deviation plus the **observed cluster mean**, or the
  raw mediator plus the cluster mean (the within parameterization is
  recovered from it); medfit finds these terms by value, so grand-mean
  centering and `scale()` work. The natural indirect effect is
  `a * b_between`; `decompose()` splits it into an own-mediator part
  `a * b_within` and a spillover part `a * (b_between - b_within)`, labeled
  as the cluster-average, large-cluster approximation, with a warning when the
  approximation error exceeds half the own effect's standard error.
  `print()` and `summary()` end with an "Estimand and assumptions" block.
  `nie()`, `nde()`, `te()`, `pm()`, `paths()`, `decompose()`, `coef()`,
  `vcov()`, `nobs()`, `confint()`, `tidy()`, `glance()` and `quick()` support
  the class, and the parametric bootstrap accepts it. Standard errors are
  delta-method SEs from lme4's model-based covariance. Treatment-by-mediator
  and covariate-by-mediator products, non-Gaussian (`glmer`) fits and random
  slopes on anything but the within term are errors. `lme4` is in
  `Suggests`.

* `fit_mediation(engine = "lmer", cluster = )` fits the two linear mixed models
  of the cluster design (REML, random cluster intercepts, the mediator and any
  level-1 covariates split into a within-cluster deviation and a cluster mean)
  and returns a `ClusterMediationData`. `se_type = "kr"` applies the
  Kenward-Roger adjustment (`pbkrtest`, in `Suggests`; REML fits only): each
  path gets a Kenward-Roger denominator degrees of freedom in `@kr_df`, and
  `confint()` and `tidy(conf.int = TRUE)` give t intervals for the paths
  while the product effects keep normal intervals. `extract_mediation()` warns
  per call when there are fewer than 25 clusters with model-based standard
  errors, and when there are fewer than 10 clusters with any standard error
  type. The methods article has a new 2-1-1 section: models, effects, the
  own/spillover approximation and its exact form, the covariance argument and
  the assumptions table.

* Fix: the `?ClusterMediationData` reference now cites Talloen et al. (2016,
  *Journal of Educational and Behavioral Statistics*) correctly; the entry in
  the development version cited a different title and journal.

* `bootstrap_mediation()` gains `cluster =` for `method = "nonparametric"`: it
  resamples whole clusters with replacement and gives each draw a fresh
  cluster id before `statistic_fn` sees the data, so a cluster drawn twice is
  refit as two clusters rather than one larger one. Singular fits and
  convergence warnings from a refit count as failures: they are excluded, their
  messages are suppressed, and their number is added to the existing warning.
  `cluster = NULL` (the default) resamples rows as before; `cluster` with the
  parametric or plugin methods is an error.

* `extract_mediation()` on two `lmer` fits now stops when the fits kept different
  individuals within the same clusters (the same number of rows, the same
  cluster vector and the same treatment values, but different rows). It used to
  fall through to a misleading "no cluster-mean term" error, and could pair rows
  incorrectly if values coincided. The check compares the data row names the fits
  kept, so it cannot see a mismatch between frames whose row names were both
  reset (a tibble, for example). `?extract_mediation` no longer lists `lmerMod` as
  future.

* The 30 internal helper functions (names starting with a dot) no longer have Rd
  pages, so the package site stops publishing 30 unlisted `dot-*` reference pages.
  No user-facing function changes.

* `fit_mediation(engine = "lmer")` now stops with a clear error when a formula
  contains a random-effect term such as `(1 | id)`: the engine adds the random
  cluster intercept itself, and the term used to reach `lmer()` as a fixed term
  and fail with `Invalid grouping factor specification`. The message names the
  formula and points to `engine_args` for random slopes. `I(a | b)` as a
  covariate is not affected.

## Documentation

* New "Reference Card" article listing every export and class on one page, and a
  "Cookbook" article with ten task recipes (a first fit through cluster designs).
  Both are linked from the site menu and README; tests check that the card names
  every export and that each recipe's code and links resolve. The cluster
  examples on `?fit_mediation`, `?bootstrap_mediation` and `?extract_mediation`
  now run, and Getting Started and Introduction point to the new pages.

# medfit 0.5.0

Two fixes change results (marked **Behavior change** below): serial `te()`
and `pm()` now sum every path (#81), and `confint(parm = "paths")` finds path
rows by name instead of by position (#82). Both correct wrong output, so they
ship without a deprecation period. Ecosystem: probmed and RMediation call
neither function and their test suites pass against this release. The same
bugs are present in CRAN 0.3.2; see #83 for workarounds.

## New features

* New `JointMediationData` class: `extract_mediation()` on lm/glm fits with
  two or more mediators (serial or parallel) now supports treatment-by-mediator
  product terms in the outcome model, written with `:` or `*` (e.g.
  `Y ~ X * M2 + M1 + C`). It returns the **joint** natural effects of the
  mediators as a block (VanderWeele and Vansteelandt 2014): for a 0/1
  treatment, NIE = sum over mediators of (theta2 + theta3) times the total
  treatment effect on that mediator, NDE and CDE add the product terms at the
  covariate means and at `m_star`. There is no per-mediator split of the NIE.
  For a serial chain the joint NIE counts every path through the mediators,
  so it differs from the chain-only `a * d * b` that `nie()` reports by
  default for `SerialMediationData` (it matches `nie(type = "total")` when
  there is no product term). Standard errors use analytic delta-method
  gradients and a stacked-OLS covariance that includes the correlation between parallel
  mediator equations; they are conditional on the observed covariates.
  `nie()`, `nde()`, `te()`, `pm()`, `decompose()`, `paths()`, `print()`,
  `summary()`, `coef()`, `vcov()`, `nobs()`, `confint(parm = "paths" /
  "effects")`, `tidy()` (types `"paths"` and `"effects"`, with delta-method
  SEs) and `glance()` (adding `structure`, `n_mediators`, `interactions` and
  `m_star`) support the class. The new `joint_effects()` recomputes the
  effects at any parameter vector, which makes it the statistic for a
  parametric `bootstrap_mediation()`. The "Model Extraction" article has a
  worked example on `mediation_demo$outcome_int`.
  The fit must use Gaussian identity-link models without weights, an
  intercept in each, the same rows and the same covariates in every model, a
  numeric 0/1 treatment, and every mediator in the outcome model; each
  violation errors, naming the cause. `m_star` is a scalar or a vector named
  by the interacting mediators. Products elsewhere (in a mediator model,
  mediator-by-mediator, three-way, with a covariate, or function-wrapped)
  still error, as do lavaan multi-mediator fits with products.

* New bundled dataset `mediation_demo` (400 rows, 8 variables): simulated data
  that supports simple, serial, parallel, and treatment-by-mediator interaction
  examples from one running example. The covariates are mediator-outcome
  confounders, so examples adjust for them. See `?mediation_demo` for the
  generating equations; the generating script is in `data-raw/`. The
  "Getting Started", "Introduction", and "Model Extraction" articles and the
  single-mediator examples for `fit_mediation()`, `extract_mediation()`,
  `med()`, `quick()`, `bootstrap_mediation()`, `nie()`, `nde()`, `te()`,
  `pm()`, and `paths()` now use it, adjusting for both covariates.

* `bootstrap_mediation(method = "parametric")` and `method = "plugin"` now
  accept `SerialMediationData`, `ParallelMediationData`, and
  `InteractionMediationData`, not only `MediationData`. Both methods read only
  `@estimates` and `@vcov`, which every class carries with matching names, so
  `statistic_fn` can use the path aliases directly (e.g. `a * d1 * b` for a
  serial chain, `a1 * b1 + a2 * b2` for parallel mediators). Previously these
  classes were rejected because they do not inherit from `MediationData`.

* `BootstrapResult` gains `coef()` and `confint()` methods. `coef()` returns
  `c(estimate = ...)`; `confint()` returns the stored percentile interval as a
  1 x 2 matrix, recomputes it from the bootstrap distribution when a different
  `level` is given, and returns `NA` with a warning for plugin results.
  Previously both errored with "Can't get S7 properties with `$`".

* `tidy()` and `glance()` now support `ParallelMediationData` and
  `InteractionMediationData`; previously both errored with "not implemented
  for this S7 object type". `tidy()` returns path rows (`a1, b1, ..., c_prime`
  or `a, b, c_prime, theta3`) with standard errors from `vcov()`, then effect
  rows (`nie`, `nde`, `te`, plus the four-way `cde`, `int_ref`, `int_med`,
  `pie` for interaction models) with delta-method standard errors (see
  below). `glance()` adds `n_mediators` (parallel) or `interaction` and `m_star`
  (interaction).

* `tidy()` now reports delta-method standard errors for effect rows (NIE,
  NDE, TE, and the four-way components) for all four mediation classes, from
  the same computation as `confint(parm = "effects")`, so
  `tidy(conf.int = TRUE)` reproduces `confint()` exactly. Previously these rows
  had `NA` standard errors, and `SerialMediationData` returned `NA` intervals
  with a warning. `tidy()` stays silent; `?tidy.S7_object` documents that the
  intervals are normal approximations and that the proportion mediated should
  be bootstrapped.

* New `confint()` method for `SerialMediationData`, with `parm = "paths"` or
  `"effects"`.

## Bug fixes

* `extract_mediation()` on a lavaan fit with sampling weights no longer fails
  with "Number of rows in data must match n_obs". lavaan normalizes the weights
  to sum to N, so its `nobs` can read N - 1e-13 (355.99999999999994 for
  N = 356), and `n_obs` was truncated to N - 1. It is now rounded. This affects
  the mediation, parallel, serial and interaction extractors.

* **Behavior change:** `confint(parm = "paths")` now finds each path's row of
  `@vcov` by name: the alias rows (`a`, `b`, `c_prime`; `d1`, ...; `a1`,
  `b1`, ...; `theta3`) first, then, for `MediationData`, the lm-style
  `m_<treatment>`, `y_<mediator>`, `y_<treatment>` rows. Names come from
  `rownames(x@vcov)`, or from `names(x@estimates)` when `x@vcov` has none.
  Previously `MediationData` looked only for the lm-style names and otherwise
  warned and took the first three diagonal entries. That gave wrong SEs for
  every lavaan-extracted object, where rows 1-3 are a, c', b, so b and c'
  swapped SEs. It was right for a hand-built object with alias names only
  when those came first. The serial, parallel, interaction and joint methods
  returned `NA` bounds for a missing row. All five now error, naming the
  missing rows, when neither set of names resolves. `tidy()` still reports
  `NA` there, as it is descriptive; `confint()` is strict.
  **Ecosystem note:** downstream code that builds these objects by hand with
  unnamed `@estimates`/`@vcov` gets an error from `confint(parm = "paths")`
  instead of a warning or `NA`.

* **Behavior change:** `te()` and `pm()` for `SerialMediationData` now use the
  full total effect, the sum over every X-to-Y path, instead of only the chain
  plus the direct effect (`a * d * b + c'`). For the usual specification
  (`M2 ~ X + M1`, `Y ~ X + M1 + M2`) the old value left out the paths that
  skip a mediator (X -> M1 -> Y, X -> M2 -> Y) and could be badly off. In one
  simulated example it gave 0.13 where the true total effect was 0.54. With
  linear models and the same covariates in every equation, `te()` now equals
  the treatment coefficient of `lm(Y ~ X + covariates)`. `pm()` is the total
  indirect effect divided by that total. `nie()` still returns the
  chain-specific indirect effect by default. The new `nie(x, type = "total")`
  returns the total indirect effect, `te(x) - nde(x)`. The serial lm/glm and
  lavaan extractors now record the skip-path coefficients as `a2..ak`
  (`X -> Mj`), `b1..b{k-1}` (`Mi -> Y`) and `d{i}_{j}` (`Mi -> Mj`, j > i + 1)
  in `@estimates` and `@vcov`. The delta-method SE of `te` in `confint()` and
  `tidy()` differentiates the full sum. It matches lavaan `:=` SEs. Serial
  `tidy()` gains a `nie_total` row, `glance()` gains a `nie_total` column and
  `coef(type = "effects")` gains `indirect_total`, appended after `total`
  so existing positions are unchanged. A hand-built object whose
  predictor lists include a skip path without its coefficient gets `NA` and a
  warning from `te()` and `pm()`, because assuming zero would reproduce the
  bug. For glm fits with a non-identity link, the path sum is on the
  linear-predictor scale, as it already is for `MediationData`. `quick()` now
  prints the chain and total NIE side by side. Downstream impact: none for
  probmed (imports only `extract_mediation()`) or RMediation (its serial
  `ci()` reads `@a_path`, `@d_path` and `@b_path`, which are unchanged);
  neither calls serial `te()` or `pm()`. Code that stored serial `te()` or
  `pm()` values from medfit 0.4.0 or earlier will see different numbers.
* `tidy(<SerialMediationData>, type = "effects")` no longer errors on
  mismatched row counts.
* The single-mediator four-way decomposition (`InteractionMediationData`,
  lm/glm engine) now includes factor covariates in E[M | X = 0]. Covariate
  means were taken only for numeric data columns named after a coefficient,
  so a factor's dummy coefficients (e.g. `Gb`, `Gc`) were skipped without
  a warning. NDE, INTref and the total effect were wrong, and so were their
  delta-method SEs. The means now come from the mediator model's design
  matrix, as in `JointMediationData`, and both the point estimates and the
  gradients use them. Two other cases change for the same reason:
  transformed covariate terms (e.g. `log(C)`, `poly(C, 2)`) were also
  skipped and are now included, and when a caller-supplied `data` has rows
  the mediator model did not use, the means now cover only the estimation
  sample. With case weights (e.g. `fit_mediation(weights = )`), the means
  are now weighted by them; they were unweighted before. Results with plain
  numeric covariates and no weights are unchanged.
  `fit_mediation()` with an `X * M` outcome formula is fixed as well. The
  lavaan engine accepts only numeric observed variables, so it is
  unaffected.
* `JointMediationData` effect standard errors are no longer `NA` in
  `tidy()` and `summary()` when `extract_mediation()` receives `data =` and
  a model has a factor or transformed covariate (e.g. `G` with levels
  `a`/`b`/`c`, or `poly(W, 2)`); `confint(parm = "effects")` no longer
  errors for the same fits. The gradients rebuilt the covariate means from
  `@data`, which only works for a model frame, so the SE computation failed
  and `tidy()` and `summary()` caught the failure and reported `NA`. The
  extractor now stores the exact means the point estimate uses on `@data`
  (attribute `medfit_covariate_means`, the convention of the four-way
  extractor), so SEs with `data = d` equal those with `data = NULL`,
  including fits with `subset =`. Point estimates were already correct.

* `fit_mediation(se_type = "sandwich")` now applies the sandwich estimator
  to fits with a treatment-by-mediator interaction. The four-way worker
  ignored `vcov_fun` and always used the model-based `stats::vcov()`, so the
  returned `@vcov` was identical to `se_type = "model"`, with no warning. A
  `vcov_fun` passed to `extract_mediation()` now also reaches serial and
  parallel fits, which ignored it the same way.

* The four-way decomposition now requires the identity link. A Gaussian
  `glm()` with another link (e.g. `gaussian(link = "log")`) passed the
  family check, and the linear four-way formulas were applied to a model that
  is not linear in its coefficients. It now errors, naming the link.

* `extract_mediation()` now errors when `m_star` is supplied but no four-way
  decomposition or joint-effects fit uses it (no treatment-by-mediator term,
  or `decomposition = "two_way"`), on both the lm/glm and lavaan paths.
  The value was previously dropped silently. As in `fit_mediation()`, the
  check keys on whether `m_star` was given at the call site, not on its value.

* `extract_mediation()` on lm/glm fits now detects products written inside a
  function call, such as `I(X * M)`. R records such a term as an ordinary
  covariate, so it previously bypassed both the multi-mediator product guard
  and the single-mediator interaction check: the fit returned main-effect
  estimates that ignored the product, with no error. Multi-mediator
  extraction now errors on any wrapped term that combines the treatment or a
  mediator with another variable (e.g. `I(X * M2)` or `log(M1 + C)`). Single-mediator extraction errors on a wrapped
  treatment-by-mediator product and asks for `X * M` or `X:M`, which route
  to the four-way decomposition. Single-variable transforms such as
  `I(X^2)` are unaffected, and a product precomputed as a data column still
  cannot be detected from the formula.

* `confint(parm = "effects")` for `MediationData` gave a total-effect interval
  that was too wide: it treated the indirect effect and `c'` as independent,
  dropping their covariance. It now uses the full delta-method gradient (on the
  simple `mediation_demo` fit the TE standard error drops from 0.127 to
  0.119, matching a parametric bootstrap). NIE and NDE are unchanged.

* `confint(parm = "effects")` and `tidy()` now work for `MediationData`
  extracted from lavaan. Both located paths by lm-style names, so
  `confint()` stopped with "Could not compute SEs for effects" and `tidy()`
  omitted standard errors.

* `extract_mediation()` with two or more mediators (serial or parallel) now
  errors when a model carries a product term involving the treatment or a
  mediator, e.g. `X:M1` in the outcome model. Previously the multi-mediator
  branch returned before any interaction check, so the product term was
  ignored silently and main-effect paths were reported as if no interaction
  existed. Applies to both the lm/glm and lavaan methods; for lavaan, a
  product precomputed as a plain data column is recognized when named via
  `interaction =`. Products among covariates alone are still allowed. On
  lm/glm, a treatment-by-mediator product in the outcome model is now
  supported through `JointMediationData` (see New features); every other
  product still errors.

* `extract_mediation()` on a lavaan fit whose paths carry custom labels
  (e.g. `M ~ aa*X`) now fills the alias rows of `@vcov` (`a`, `b`, `c_prime`,
  and the serial, parallel, and interaction aliases) from the labeled
  parameters. Previously the label-based parameter names from lavaan did not
  match the names the extractors looked for, so those rows and columns were
  all zero, and `bootstrap_mediation(method = "parametric")` drew a degenerate
  distribution with a zero-width interval. The simple extractor only
  recognized labels equal to `a_label`/`b_label`/`cp_label`; the serial,
  parallel, and interaction extractors recognized no labels at all. All four
  now read each path's parameter name from `lavaan::parTable()`.

* `extract_mediation()` on a lavaan fit now stops with an error when a user
  label reuses one of medfit's alias names for a different path, for example
  `a1`/`a2` written for `mediator = c("M1", "M2")` while the call lists
  `c("M2", "M1")`, or a covariate path labeled `a`. The alias estimate was
  taken from the right path, but its `@vcov` row stayed the labeled
  parameter's, so standard errors and bootstrap draws used the wrong
  variance. A label on the alias's own path (such as the default `a`, `b`)
  is still accepted. The simple extractor now takes each alias's `@vcov` row
  from the same parameter-table row as its estimate, so the two agree when
  the paths were found through `a_label`, `b_label`, and `cp_label`.

## Documentation

* The articles now evaluate their code when the site is built, instead of
  showing output typed in by hand, so the shown output cannot drift from the
  code and a broken example fails the build. The pkgdown workflow also runs
  on pull requests to `dev`. Turning this on exposed three broken examples in
  the "Introduction" article (a missing `library(medfit)` and two
  hand-built objects missing required properties), now fixed; the
  error-handling example in "Model Extraction" shows the real messages.

* New "Methods and Formulas" article collecting the estimand, formula,
  covariance and standard-error computation for every class, the bootstrap
  methods, and the fitting engines, with the assumptions each estimand needs.

* Help pages now cover every class: `nie()`, `nde()`, `te()`, `pm()` and
  `paths()` give the formulas for parallel, interaction and joint objects;
  `decompose()` gains the four-way formulas, the joint method, references and
  an example; `InteractionMediationData` gains the INTref formula and
  `JointMediationData` the NDE formula; `extract_mediation()` documents the
  lm/glm arguments, the returned classes, and the covariance of the
  estimates; `tidy()`/`glance()` document `glance()` and the `coef()`,
  `vcov()`, `confint()` and `nobs()` methods; bootstrap intervals are stated
  to be percentile intervals.

* Corrected stale examples and statements in the articles and README:
  `confint(parm = "effects")` (not `type =`), tidy output with delta-method
  effect SEs, the list of classes, and the covariance between parallel
  mediator equations, which the lm/glm `@vcov` omits.

* `?fit_mediation` and `?bootstrap_mediation` no longer merge in the
  placeholder stubs left over in `R/aab-generics.R` (removed). Each page had
  two usage blocks, two return values, duplicated details sections, and
  examples on nonexistent objects inside `\dontrun{}`. The regmedint-engine
  and reference-mediator-level notes from the `fit_mediation()` stub now live
  with the real function.

* Serial mediation docs now recommend including the treatment and every
  earlier mediator in the outcome model (`Y ~ X + M1 + M2`, not `Y ~ X + M2`).
  Only the last mediator's coefficient becomes the `b` path, but when an
  earlier mediator also affects the outcome, leaving it out confounds `b`.
  The serial indirect effect `a * d * b` is the effect through the full chain
  only. Updated in the `extract_mediation()` lm/glm and lavaan documentation
  and the "Model Extraction" article; a new test checks the bias.

* Fixed the lavaan serial examples in the "Model Extraction" and "Bootstrap"
  articles, which passed `mediators =` to `extract_mediation()`; the argument
  is `mediator`.

* Repaired the "Bootstrap Inference" article so every code chunk runs against
  the current API. It now uses `mediation_demo`, adjusting for both covariates,
  and reads `med()`'s bootstrap via `attr(result, "bootstrap")`. The serial
  example refits the chain nonparametrically, because the parametric and plugin
  methods accept only `MediationData`. The article also reads `BootstrapResult`
  properties directly, since that class has no `coef()`/`confint()` methods,
  and its printed output has been regenerated.

# medfit 0.4.0

## New features

* `fit_mediation()` gains a second engine, `engine = "regmedint"`, which fits
  the mediator and outcome regressions through the suggested \pkg{regmedint}
  package and returns medfit's own classes. On a formula without a
  treatment-by-mediator term it returns a `MediationData`; on one carrying an
  `X:M` term it returns an `InteractionMediationData` with the four-way
  (VanderWeele) decomposition filled in from regmedint's closed-form
  `cde`/`pnde`/`tnie`/`pnie`/`te` output. Auto-detection mirrors
  `extract_mediation(decomposition = "auto")`.

* `fit_mediation()` gains an `engine_args` argument: a named list of
  engine-specific overrides, ignored by `engine = "glm"`. For the regmedint
  engine it accepts `interaction`, `cvar`, `mreg`, `yreg`, `a0`, `a1`, and
  `c_cond`, each replacing a value the adapter would otherwise derive from the
  formulas, families, and data.

* `fit_mediation()` gains an `m_star` argument: the reference mediator level
  (`m*`) at which the controlled direct effect is evaluated, when the
  fit returns an `InteractionMediationData`. It closes a gap that predates the
  engine work -- `extract_mediation()` has always accepted `m_star`, but
  `fit_mediation()` routed unrecognized arguments to `stats::glm()`, so
  `fit_mediation(Y ~ X * M, ..., m_star = 1)` previously failed with
  `unused argument`. The default of `0` is unchanged behavior, and matches the
  lm/glm and lavaan extractors.

  Both engines honor it, by different routes: `engine = "glm"` applies it at
  extraction time, after the coefficients are fit, while `engine = "regmedint"`
  passes it to `regmedint::regmedint()` as `m_cde`, where that package's
  closed-form estimator consumes it at fitting time. The two agree to
  delta-method tolerance on `@cde` and `@int_ref` at any shared `m_star`.
  Because `m_star` and `regmedint`'s `m_cde` name one quantity, `m_cde` is no
  longer accepted in `engine_args`; supplying it errors with a pointer to
  `m_star`. (Both surfaces are new in this release, so no deprecation cycle
  applies.)

  `nde()`, `nie()`, `te()`, and `pm()` are invariant to `m_star` -- only the
  CDE/INTref split moves. Supplying `m_star` for a fit with no
  treatment-by-mediator term is an error rather than a silent no-op.

* Standard errors for the regmedint engine are analytical, not bootstrapped.
  `confint()` on an `InteractionMediationData` now prefers a stored component
  covariance block when the fitting engine supplied one; objects from the
  lm/glm and lavaan extractors carry none, so their existing delta-method
  gradient path is unchanged.

## Details and limitations

* The regmedint engine requires a numeric 0/1 treatment and a linear (Gaussian)
  mediator model. Outside those cases regmedint's closed-form effects are no
  longer the products of regression coefficients that
  `MediationData`/`InteractionMediationData` are defined in terms of, so the
  adapter raises an explicit error with guidance rather than returning an
  object whose numbers disagree with `nie()`. Outcome models may be Gaussian or
  binomial.

* `engine = "regmedint"` does not support `weights` or `se_type = "sandwich"`
  (regmedint implements neither); supplying them is an error rather than a
  silent no-op.

* `m_cde` defaults to `0`, matching the `m_star = 0` default already used by
  the lm/glm and lavaan extractors, so all three report the CDE/INTref split at
  the same reference level. `nde()`, `nie()`, `te()`, and `pm()` are invariant
  to this choice.

* \pkg{regmedint} is a `Suggests` dependency; medfit checks and tests cleanly
  with it absent.

## Bug fixes

* `BootstrapResult()`'s validator checked `method` for length *after* three
  `self@method != "plugin"` branches had already used it. A non-scalar `method`
  therefore raised R's `the condition has length > 1` instead of the intended
  message, `method must be a single character string`. The `method` scalar and
  membership checks are now hoisted above every branch that reads it.

## Internal

* New internal helper `.find_interaction_term_formula()` (`R/utils.R`): the
  formula-level counterpart of `.find_interaction_term()`, used to choose the
  return class before any model is fitted.

# medfit 0.3.2 (2026-07-23)

CRAN patch release. No new features; CI/lint compatibility, CRAN
compliance, and Rd documentation fixes only (no change to exported
function behavior).

## CRAN pretest fix

* First submission attempt (2026-07-21) was archived by CRAN's incoming
  pretest over a Debian-flavor NOTE: S7 class Rd files had `\arguments`
  without a `\usage` section (`BootstrapResult`, `InteractionMediationData`,
  `MediationData`, `ParallelMediationData`, `SerialMediationData`). Fixed by
  adding explicit constructor-call `@usage` signatures to all 5 S7 classes.
  Resubmitted 2026-07-23 and accepted.

## CI and lint

* Fixed `lint` job breakage from lintr 3.4.0's tightened `indentation_linter`
  (reindented function signatures 4 -> 2 spaces; whitespace only,
  `git diff -w` empty).
* Re-documented with roxygen2 8.0.0 (`RoxygenNote` -> `Config/roxygen2/version`).

## CRAN compliance

* Fixed a stale `Date` field (CRAN incoming-feasibility check flags dates
  over a month old).
* `.Rbuildignore`d the `.remember` session-memory scratch directory, which
  was leaking into the built source tarball (`.Rbuildignore` is independent
  of `.gitignore`).
* Added `inst/WORDLIST` entries for domain vocabulary (VanderWeele
  decomposition acronyms, S7 class names, DOI journal-code fragments) that
  `spelling::spell_check_package()`/CRAN's `aspell` pass would flag.
* Added `.aspell/defaults.R` to suppress a "possibly misspelled" NOTE on the
  cited author surname "VanderWeele" in the DESCRIPTION field (a separate
  aspell mechanism from `inst/WORDLIST`).

# medfit 0.3.1 (2026-06-11)

## New features

* `fit_mediation()` gains a `weights=` argument and a `se_type=` argument
  (`"model"` default, or `"sandwich"` for robust SEs), enabling IPW-weighted
  estimation. Unweighted calls are byte-identical to 0.3.0. Consumed by
  `missingmed`'s IPW estimator — downstream packages should require
  `medfit (>= 0.3.1)` when they pass `weights=`/`se_type=`.
  * `se_type = "sandwich"` uses the suggested \pkg{sandwich} package
    (`vcovHC`, HC3); it is required only on that opt-in path, so \pkg{sandwich}
    is a `Suggests` dependency, not `Imports`.
  * Supplying `weights=` with the default `se_type = "model"` emits a one-time
    advisory message, since model-based SEs are not valid under IPW.

# medfit 0.3.0 (2026-06-06)

## New features

* `MediationData` now carries the GLM `family`/link of the mediator and outcome
  models in new `family_m` and `family_y` properties (populated by the lm/glm
  and lavaan extractors; default `NULL` is treated as Gaussian). This lets
  scale-free estimands such as `probmed::pmed()` simulate non-Gaussian
  potential outcomes on the correct (e.g. logit) scale rather than discarding
  the link. Backward compatible: existing constructors that omit the families
  continue to work.

* New S7 class `InteractionMediationData` for simple mediation **with a
  treatment-by-mediator interaction** (`X:M` in the outcome model), carrying
  VanderWeele's (2014) four-way decomposition of the total effect into
  controlled direct effect (CDE), reference interaction (INTref), mediated
  interaction (INTmed), and pure indirect effect (PIE), with
  `NDE = CDE + INTref` and `NIE = INTmed + PIE`. The class validator enforces
  both the aggregate identities and the path ties (`INTmed = theta3 * beta1`,
  `PIE = theta2 * beta1`, `CDE = theta1 + theta3 * m*`), so an inconsistent
  decomposition is rejected at construction. Effect extractors (`nie`, `nde`,
  `te`, `pm`) have methods for the new class, plus a new `decompose()` generic
  returning all four components and the derived effects.

* `extract_mediation()` now builds `InteractionMediationData` from **lm/glm**
  fits whose outcome model contains an `X:M` term. A new `decomposition`
  argument (`"auto"` default / `"four_way"` / `"two_way"`) controls detection,
  and `m_star` sets the reference mediator level. Continuous (Gaussian) mediator
  and outcome are supported (non-Gaussian models error with a clear message);
  the no-interaction path is unchanged. The companion `confint()` method gives
  delta-method intervals for `parm = "paths"`, `"components"` (the four-way
  CDE/INTref/INTmed/PIE), and `"effects"` (NDE/NIE/TE).

* `extract_mediation()` also builds `InteractionMediationData` from a **lavaan**
  fit. The interaction enters as a product variable named via the `interaction`
  argument, and the model must be fit with `meanstructure = TRUE` (the mediator
  intercept is needed for INTref). Because the SEM is estimated jointly, the
  extracted `@vcov` carries the full joint covariance of the paths. A
  "treatment-mediator interaction" section was added to the extraction article.

* New S7 class `ParallelMediationData` for **parallel mediation**
  (`X -> M_j -> Y` for independent mediators `j = 1..k`). The total indirect
  effect is the sum of per-mediator products, `sum(a_j * b_j)`. Completes the
  structural trio alongside `MediationData` (simple) and `SerialMediationData`
  (serial). Effect extractors (`nie`, `nde`, `te`, `pm`, `paths`) have methods
  for the new class; `paths()` returns interleaved `a1, b1, a2, b2, ..., c_prime`.

* `extract_mediation()` now builds `ParallelMediationData` from **lm/glm** fits:
  pass the per-mediator models via `mediator_models` and the new
  `structure = "parallel"` argument. `structure = "auto"` (default) infers serial
  vs parallel from the mediator models' predictors, defaulting to serial unless
  there is positive evidence of a parallel structure.
  The returned `@vcov` is named `a1, b1, ..., c_prime`; the `b_j` (jointly fit in
  the outcome model) keep their mutual covariances and `cov(b_j, c')`, while the
  `a_j` (separate mediator regressions) are independent.

* `extract_mediation()` also builds `ParallelMediationData` from a single
  **lavaan** `sem()` fit: pass a `mediator` vector and (optionally)
  `structure = "parallel"`. `structure = "auto"` infers parallel vs serial from
  the SEM's regression rows. Because the system is estimated jointly, the
  extracted `@vcov` preserves **all** off-diagonals — including `cov(a_j, b_j)`
  and `cov(a_j, a_{j'})` — so SEs reflect the full joint covariance (and differ
  from the block-diagonal lm/glm engine for identical data).

* New `confint()` method for `ParallelMediationData` (`parm = "paths"` or
  `"effects"`). The indirect-effect variance uses the delta method over the full
  `{a1, b1, ..., ak, bk}` covariance block, so correlated `b_j` are handled
  correctly; `method = "boot"` directs to `bootstrap_mediation()`.

## Bug Fixes

* `print(summary(x))` now shows the formatted summary for `MediationData`,
  `BootstrapResult`, and `SerialMediationData` instead of dumping the raw list.
  The `print.summary.*` S3 methods exist and are correct, but their
  `S3method()` NAMESPACE directives are not activated once `print` participates
  in S7 dispatch, so `print()` silently fell back to `print.default`. They are
  now registered explicitly in `.onLoad()` (the same fix already used for
  `print.mediation_effect`), so dispatch works whether the package is installed
  or loaded via `load_all()`.

## Internal

* `R CMD check` is clean again (0 errors / 0 warnings / 0 notes). Added
  `@usage NULL` to the `BootstrapResult`, `ParallelMediationData`, and
  `InteractionMediationData` class docs (matching `MediationData` /
  `SerialMediationData`), which removes spurious codoc mismatches from the S7
  constructors' complex property defaults. The `show` method bodies registered
  in `.onLoad()` now delegate to a top-level helper (`.show_via_print()`) so no
  literal `print()` call sits in `.onLoad`, clearing the "startup functions
  should use packageStartupMessage" note.

## CRAN compliance and dependencies

* Moved **MASS** from `Suggests` to `Imports`: the default parametric bootstrap
  (`bootstrap_mediation(method = "parametric")`) calls `MASS::mvrnorm()`
  unconditionally, so MASS must always be available (it previously failed under
  CRAN's "noSuggests" check flavor).
* Documentation/CRAN fixes (forward-ported from the 0.2.1 CRAN resubmission):
  added `\value` to the exported `print`/`print.summary.*` methods; converted
  `\dontrun{}` examples to self-contained `\donttest{}` (the lavaan example
  guarded with `requireNamespace()`); spelled out the "GLM" acronym and added
  method references (`<doi:...>`) to the Description; enriched `inst/CITATION`.

# medfit 0.2.1 (2026-06-18)

CRAN patch release. No new features; documentation and compliance fixes only
(all changes forward-ported to 0.3.0).

## CRAN compliance and documentation

* Explained the "GLM" acronym in the package Description.
* Added method references (`<doi:...>`) to the Description field
  (MacKinnon, Lockwood & Williams 2004; Tofighi & MacKinnon 2011).
* Added `\value` sections to the four exported `print` / `print.summary.*`
  methods.
* Converted `\dontrun{}` examples to self-contained `\donttest{}` (lavaan
  example guarded with `requireNamespace()`).
* Enriched `inst/CITATION` with method references and ORCID.
* Moved **MASS** from `Suggests` to `Imports`: the default parametric bootstrap
  calls `MASS::mvrnorm()` unconditionally, so MASS must always be available.

# medfit 0.2.0 (2026-05-31)

## New features

* `extract_mediation()` now supports **serial mediation**
  (`X -> M1 -> M2 -> ... -> Mk -> Y`), returning a `SerialMediationData` object.
  For **lavaan** fits, pass an ordered vector of mediator names
  (`mediator = c("M1", "M2")`); for **lm/glm** sequential regressions, pass the
  per-mediator models via the new `mediator_models` argument. The returned
  `@vcov` is named with the path aliases `a`, `d1`, ..., `b`, `c_prime` and
  preserves the full covariance structure (single-equation lavaan SEM keeps the
  off-diagonals; the separately-fitted lm equations are block-diagonal among
  chain paths with `cov(b, c')` preserved), so downstream serial
  indirect-effect confidence intervals are correct.

## Bug Fixes

* `extract_mediation()` for lavaan models now preserves the **off-diagonal**
  covariances among the `a`, `b`, and `c_prime` path aliases in the returned
  `@vcov`. Previously only the diagonal variances were copied, so
  `vcov[c("a", "b"), c("a", "b")]` reported `cov(a, b) = 0` even when the
  underlying lavaan fit had a genuinely non-zero covariance (e.g. single-equation
  SEM with correlated residuals, or the within-equation `cov(b, c')`). This
  silently biased downstream indirect-effect confidence intervals; the alias
  block now reproduces the true `lavaan::vcov()` covariances exactly.

* `print()` on the effect objects returned by `nie()`, `nde()`, `te()`, and
  `pm()` (class `mediation_effect`) now reliably shows the formatted label
  (e.g. `Natural Indirect Effect (NIE): 0.1897`). Because `mediation_effect`
  is layered on the base `numeric` type, S3 dispatch could miss
  `print.mediation_effect` and fall back to the bare numeric value plus raw
  attributes. The method is now explicitly registered in `.onLoad()` so
  dispatch works whether the package is installed or loaded via `load_all()`.

* The **lm/glm** extractor now copies the full within-equation covariance onto
  the `a`/`b`/`c_prime` aliases, so `cov(b, c_prime)` is preserved (previously
  only the diagonal variance was copied). The indirect effect `a * b` is
  unchanged; `cov(a, b)` remains `0` (separate equations).

## Internal

* Overall test coverage raised to >90% (enforced via `codecov`), and all
  repo-wide `lintr` warnings cleared. A shared alias-vcov helper
  (`.expand_vcov_with_aliases()`) now backs both the lm/glm and lavaan
  extractors so the two engines cannot drift.


# medfit 0.1.0 (2025-12-20)

**Initial CRAN release**

## Overview

medfit provides S7-based infrastructure for fitting mediation models, extracting path coefficients, and performing bootstrap inference. It serves as the foundation package for the mediationverse ecosystem.

## Major Features

### User-Friendly API

* **`med()` function** - Recommended entry point for most users
  - Fits mediator and outcome models automatically
  - Optional bootstrap inference with `boot = TRUE`
  - Supports covariates and different model families
  - Example: `med(data, treatment = "X", mediator = "M", outcome = "Y")`

* **`quick()` function** - One-line summary of results
  - Compact display: `NIE = 0.19 [0.08, 0.32] | NDE = 0.16 | PM = 55%`
  - Works with all medfit objects

### Effect Extractors

* **Dedicated functions for mediation effects**
  - `nie()`: Natural Indirect Effect (a × b)
  - `nde()`: Natural Direct Effect (c')
  - `te()`: Total Effect
  - `pm()`: Proportion Mediated
  - `paths()`: Path coefficients (a, b, c')

### Model Fitting and Extraction

* **`fit_mediation()` function** - Fit mediation models with formula interface
  - GLM engine for linear and generalized linear models
  - Support for continuous and binary outcomes
  - Covariates in both mediator and outcome models
  - Returns `MediationData` object

* **`extract_mediation()` generic** - Extract from fitted models
  - Methods for lm, glm objects
  - Optional lavaan support (when installed)
  - Extracts path coefficients and variance-covariance matrices

### Bootstrap Inference

* **`bootstrap_mediation()` function** - Three bootstrap methods
  - **Parametric**: Fast, assumes multivariate normality
  - **Nonparametric**: Robust, resamples data and refits models
  - **Plugin**: Point estimate only
  - Parallel processing support
  - Returns `BootstrapResult` with confidence intervals

### Tidyverse and Base R Integration

* **`tidy()` and `glance()` methods** for broom compatibility
  - `tidy()`: Convert to tibble (paths, effects, or both)
  - `tidy(conf.int = TRUE)`: Include confidence intervals
  - `glance()`: One-row model summary

* **Base R generics**: `coef()`, `vcov()`, `confint()`, `nobs()`

### S7 Class Architecture

* **Modern S7 object system** for type safety and extensibility
  - `MediationData`: Simple mediation (X → M → Y)
  - `SerialMediationData`: Serial mediation (X → M1 → M2 → ... → Y)
  - `BootstrapResult`: Bootstrap inference results
  - All classes include validators, print, summary, and show methods

### Input Validation

* **Defensive programming** with `checkmate` package
  - Fast, informative error messages
  - All user-facing functions validate inputs
  - Complements S7 class validators

## Documentation

* **Four comprehensive articles** (on the package website)
  - Getting Started: Quick introduction with examples
  - Introduction: Detailed package overview
  - Model Extraction: Extract from lm, glm, lavaan objects
  - Bootstrap Inference: Parametric and nonparametric methods

* **pkgdown website**: https://data-wise.github.io/medfit/

## Testing and Quality

* **427 comprehensive tests** (0 errors, 0 warnings)
  - Full coverage of S7 classes and methods
  - Validation tests for data integrity
  - Edge case handling

* **CI/CD**: GitHub Actions workflows
  - R CMD check on Ubuntu, macOS, Windows
  - Test coverage tracking with Codecov
  - Automated pkgdown deployment

## Ecosystem

* Foundation package for the **mediationverse** ecosystem
* Supports future integration with probmed, RMediation, medrobust
* Tested with R >= 4.1.0, S7 >= 0.1.0
