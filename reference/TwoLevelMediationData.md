# TwoLevelMediationData Class

**Experimental.** This class,
[`twolevel_statistic()`](https://data-wise.github.io/medfit/reference/twolevel_statistic.md)
and the `level` argument of the effect generics may change without the
usual deprecation period (a native two-level fitter, a later milestone,
could change the object).

## Usage

``` r
TwoLevelMediationData(
  a_within, b_within, c_prime_within, a_between, b_between, c_prime_between,
  estimates, vcov, parameter_table, treatment, mediator, outcome, cluster, n_obs,
  n_clusters, cluster_sizes, icc, between_identified, admissible, converged,
  cross_level_equal, fixed_paths, source, fixed_x, information, h1_information,
  se_type, estimator, missing, lavaan_version, call, between_parameterization,
  data, source_package
)
```

## Arguments

- a_within, b_within, c_prime_within:

  Numeric scalars: within-level paths (always finite).

- a_between, b_between, c_prime_between:

  Numeric scalars: between-level paths; `NA_real_` when
  `between_identified` is `FALSE`.

- estimates:

  Named numeric vector of the identified path rows, in the order above.

- vcov:

  Covariance matrix of `estimates`: the sub-block of the fit's joint
  covariance, so the cross-level covariances are carried.

- parameter_table:

  Data frame, one row per path row (`path`, `level`, `lhs`, `op`, `rhs`,
  `label`, `free`, `est`, `se`), kept for audit.

- treatment, mediator, outcome, cluster:

  Character scalars: variable names.

- n_obs, n_clusters:

  Integer scalars: rows used and number of clusters.

- cluster_sizes:

  Integer vector of cluster sizes (length `n_clusters`).

- icc:

  Named numeric vector: intraclass correlation of treatment, mediator
  and outcome.

- between_identified:

  Logical scalar: whether the between level is identified.

- admissible:

  Logical scalar: `lavaan::lavInspect(fit, "post.check")`.

- converged:

  Logical scalar: whether the fit converged.

- cross_level_equal:

  Character vector: paths (`"a"`, `"b"`, `"c_prime"`) equated across
  levels.

- fixed_paths:

  Character vector: path rows with `free == 0` (variance 0 in `vcov`).

- source:

  Character scalar: `"lavaan"` or `"native"`.

- fixed_x, information, h1_information, se_type, estimator, missing:

  How the fit was made, read from it.

- lavaan_version, call:

  Character scalars: provenance of the fit.

- between_parameterization:

  Character scalar: `"latent"` (cluster means are latent).

- data:

  Data frame or `NULL`: always `NULL` for the lavaan adapter (the fit is
  never refit and the data are not copied); kept for the contract shared
  with the other mediation classes, which read `@data`.

- source_package:

  Character scalar: `"lavaan"`; kept for the dependents contract shared
  with the other mediation classes
  (`tests/testthat/test-dependents-contract.R` pins it across classes).

## Value

A `TwoLevelMediationData` S7 object.

## Details

S7 class for two-level mediation in which treatment, mediator and
outcome are all measured on level-1 units nested in clusters (1-1-1),
with the paths estimated separately at the within and the between level
(latent cluster means, fixed slopes). Built by
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
from a `lavaan` two-level fit; the same class is the target of a native
fitter later (`source` says which).

Per level the indirect effect is \\NIE_l = a_l b_l\\, the direct effect
is \\c'\_l\\, and the contrast \\NIE_w - NIE_b\\ is descriptive, not a
test. When the between level cannot be identified (for example a
treatment with no between-cluster variance) the object is
**within-only**: the between properties are `NA_real_` and the between
rows are absent from `estimates` and `vcov`.

## Examples

``` r
# \donttest{
if (requireNamespace("lavaan", quietly = TRUE)) {
  set.seed(1)
  id <- rep(1:60, each = 5)
  xb <- stats::rnorm(60)[id]
  x <- xb + stats::rnorm(300)
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
  td@a_within * td@b_within
}
#> [1] 0.2498413
# }
```
