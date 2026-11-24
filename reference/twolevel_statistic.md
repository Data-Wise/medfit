# Bootstrap Callback for Two-Level Mediation

**Experimental.** The interface may change without the usual deprecation
period.

## Usage

``` r
twolevel_statistic(
  x,
  effect = c("nie_within", "nie_between", "nie_contrast", "nde_within", "nde_between",
    "te_within", "te_between", "pm_within", "pm_between", "a_within", "b_within",
    "c_prime_within", "a_between", "b_between", "c_prime_between"),
  treatment = NULL,
  mediator = NULL,
  outcome = NULL,
  level = NULL,
  specific = NULL
)
```

## Arguments

- x:

  A
  [TwoLevelMediationData](https://data-wise.github.io/medfit/reference/TwoLevelMediationData.md)
  or
  [TwoLevelParallelMediationData](https://data-wise.github.io/medfit/reference/TwoLevelParallelMediationData.md)
  object, or a two-level `lavaan` fit.

- effect:

  One of `"nie_within"` (default), `"nie_between"`, `"nie_contrast"`
  (within minus between, descriptive), `"nde_within"`, `"nde_between"`,
  `"te_within"`, `"te_between"`, `"pm_within"`, `"pm_between"`, or a
  path row: `"a_within"`, `"b_within"`, `"c_prime_within"`,
  `"a_between"`, `"b_between"`, `"c_prime_between"`. The proportion
  mediated is `NA` where the total effect is zero. For several
  mediators: `"nie"` (default), `"nie_j"`, `"nde"` or `"te"`.

- treatment, mediator, outcome:

  Variable names. Required for a `lavaan` fit; taken from the object for
  a
  [TwoLevelMediationData](https://data-wise.github.io/medfit/reference/TwoLevelMediationData.md)
  or
  [TwoLevelParallelMediationData](https://data-wise.github.io/medfit/reference/TwoLevelParallelMediationData.md).
  `mediator` is a character vector of length two or more for a fit with
  several mediators, a character scalar otherwise.

- level:

  For several mediators only: `"within"` (default), `"between"` or
  `"contrast"`. For one mediator the level is part of `effect`, and
  `level` must be left unset.

- specific:

  For `effect = "nie_j"` only: the name of the mediator whose specific
  indirect effect is returned.

## Value

A function of one argument returning a number: a named parameter vector
for a
[TwoLevelMediationData](https://data-wise.github.io/medfit/reference/TwoLevelMediationData.md)
or
[TwoLevelParallelMediationData](https://data-wise.github.io/medfit/reference/TwoLevelParallelMediationData.md),
a data frame for a `lavaan` fit.

## Details

Builds the scalar `statistic_fn` that
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
needs for one effect of a two-level (1-1-1) mediation model, so the
within and the between indirect effect and their contrast can be
bootstrapped without writing the callback by hand. The form of the
callback depends on the first argument:

- `x` a
  [TwoLevelMediationData](https://data-wise.github.io/medfit/reference/TwoLevelMediationData.md):
  the callback for `method = "parametric"` (and `"plugin"`). It takes
  the named parameter vector drawn from \\N(\hat\theta, \hat\Sigma)\\,
  so the cross-level covariance is part of every draw.

- `x` a two-level `lavaan` fit (with `treatment`, `mediator` and
  `outcome`): the callback for `method = "nonparametric"` with
  `cluster =`. It refits the fit's own model on each resampled data set
  (the call stored in the fit, with `data` replaced) and returns the
  effect. The cluster bootstrap gives every drawn cluster a fresh id, so
  a cluster drawn twice is refitted as two clusters.

- `x` a
  [TwoLevelParallelMediationData](https://data-wise.github.io/medfit/reference/TwoLevelParallelMediationData.md)
  (several mediators), or a two-level `lavaan` fit with a `mediator`
  vector of length two or more: the same two callbacks for the effects
  that [`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
  [`nde()`](https://data-wise.github.io/medfit/reference/nde.md) and
  [`te()`](https://data-wise.github.io/medfit/reference/te.md) define
  for that class. `effect` is then one of `"nie"` (the total indirect
  effect, the default), `"nie_j"` (the specific indirect effect of the
  mediator named in `specific`), `"nde"` or `"te"`, and `level` is
  `"within"` (default), `"between"` or `"contrast"` (within minus
  between, `"nie"` and `"nie_j"` only). The callback evaluates the same
  effect code as those generics, so at the estimate it returns their
  value.

A refit that errors, does not converge, warns, or leaves the between
level unidentified (a treatment or any mediator ICC below
`getOption("medfit.between_icc_error", 0.01)`, for a between effect or
the contrast; the ICC is the unrestricted (h1) one that
`lavaan::lavInspect(refit, "icc")` reports) is a failed replicate:
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
excludes it and reports the count in a warning. An inadmissible refit (a
negative variance) is kept, as the point estimate keeps it. The
covariance checks of the point-estimate extraction are not repeated per
refit (no standard errors are computed). Refits skip standard errors,
the model test and lavaan's post-check (`se = "none"`, `test = "none"`,
`check.post = FALSE`), which do not change the maximum likelihood
estimates; everything else comes from the fit's own call.

**Refit environment.** The refit re-evaluates the call stored in the fit
with `data` replaced by the resampled data (and, for a `model` that is
not a literal string, with the fit's parameter table). Names that lavaan
leaves unevaluated in that call (for example `control = ctl` or
`estimator = est`) are resolved in the environment that called
`twolevel_statistic()`, captured at that call, not where the fit was
made and not where the callback later runs. Create the callback in the
scope that holds those objects. Calls written with a namespace, such as
[`lavaan::lavaan()`](https://rdrr.io/pkg/lavaan/man/lavaan.html) resolve
regardless.

The contrast is `NA` by constraint when both `a` and `b` are equated
across levels and a between effect is `NA` when the between level is not
identified, so asking for either raises a classed error here instead of
returning a distribution of `NA`.

**Several mediators.** An invalid `level`, or `level = "contrast"` with
`effect = "nde"` or `"te"`, stops with class
`medfit_error_twolevel_level`. An effect not defined for several
mediators, `effect = "nie_j"` without `specific` or with a name that is
not one of the mediators, and `specific` with another effect stop with
class `medfit_error_twolevel_unsupported`, as do `level` and `specific`
given for one mediator. A between effect or the contrast of a
within-only fit stops with class `medfit_between_unidentified`, and the
contrast of a mediator (for `"nie_j"`) or of every mediator (for
`"nie"`) whose `a` and `b` are both equated across levels stops with
class `medfit_error_twolevel_constrained`.

## See also

[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md),
[TwoLevelMediationData](https://data-wise.github.io/medfit/reference/TwoLevelMediationData.md),
[TwoLevelParallelMediationData](https://data-wise.github.io/medfit/reference/TwoLevelParallelMediationData.md)

## Examples

``` r
# \donttest{
if (requireNamespace("lavaan", quietly = TRUE) && requireNamespace("MASS", quietly = TRUE)) {
  set.seed(1)
  id <- rep(1:60, each = 5)
  x <- stats::rnorm(60)[id] + stats::rnorm(300)
  m <- 0.5 * x + stats::rnorm(60)[id] + stats::rnorm(300)
  y <- 0.4 * m + 0.2 * x + stats::rnorm(60)[id] + stats::rnorm(300)
  d <- data.frame(id = id, X = x, M = m, Y = y)
  model <- "
    level: 1
      M ~ X
      Y ~ M + X
    level: 2
      M ~ X
      Y ~ M + X
  "
  fit <- lavaan::sem(model, data = d, cluster = "id")
  td <- extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y")
  bootstrap_mediation(twolevel_statistic(td, "nie_between"), method = "parametric",
                      mediation_data = td, n_boot = 200, seed = 1)
  bootstrap_mediation(
    twolevel_statistic(fit, "nie_between", treatment = "X", mediator = "M", outcome = "Y"),
    method = "nonparametric", data = d, cluster = "id", n_boot = 20, seed = 1
  )
}
#> BootstrapResult object
#> ======================
#> 
#> Method:   nonparametric
#> Estimate:   0.0994
#> N bootstrap samples: 20
#> 
#> 95% Confidence Interval:
#>   Lower:  -0.0833
#>   Upper:   0.3506
# }
```
