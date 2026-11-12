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
  outcome = NULL
)
```

## Arguments

- x:

  A
  [TwoLevelMediationData](https://data-wise.github.io/medfit/reference/TwoLevelMediationData.md)
  object, or a two-level `lavaan` fit.

- effect:

  One of `"nie_within"` (default), `"nie_between"`, `"nie_contrast"`
  (within minus between, descriptive), `"nde_within"`, `"nde_between"`,
  `"te_within"`, `"te_between"`, `"pm_within"`, `"pm_between"`, or a
  path row: `"a_within"`, `"b_within"`, `"c_prime_within"`,
  `"a_between"`, `"b_between"`, `"c_prime_between"`. The proportion
  mediated is `NA` where the total effect is zero.

- treatment, mediator, outcome:

  Character scalars: variable names. Required for a `lavaan` fit; taken
  from the object for a
  [TwoLevelMediationData](https://data-wise.github.io/medfit/reference/TwoLevelMediationData.md).

## Value

A function of one argument returning a number: a named parameter vector
for a
[TwoLevelMediationData](https://data-wise.github.io/medfit/reference/TwoLevelMediationData.md),
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

A refit that errors, does not converge, warns, or leaves the between
level unidentified (a treatment or mediator ICC below
`getOption("medfit.between_icc_error", 0.01)`, for a between effect or
the contrast) is a failed replicate:
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

## See also

[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md),
[TwoLevelMediationData](https://data-wise.github.io/medfit/reference/TwoLevelMediationData.md)

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
