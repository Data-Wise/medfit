# ClusterMediationData: Cluster-Level Treatment Mediation (2-1-1)

S7 class for mediation with a treatment assigned to whole clusters (such
as schools) and a mediator and outcome measured on the individuals in
them. It holds the paths of a two-level linear mixed model pair: the
mediator model `M ~ X + ... + (1 | cluster)` and the outcome model with
the mediator split into its within-cluster deviation and the observed
cluster mean. medfit computes the effects; causal interpretation is the
user's responsibility.

## Usage

``` r
ClusterMediationData(a_path, b_within, b_between, c_prime, estimates, vcov,
  kr_df, treatment, mediator, outcome, cluster, n_obs, n_clusters,
  cluster_sizes, parameterization, covariates_centered, se_type, reml,
  converged, sigma_m, sigma_y, tau_m, tau_y, data, source_package)
```

## Arguments

- a_path:

  Numeric scalar: effect of the treatment on the mediator.

- b_within:

  Numeric scalar: within-cluster mediator effect on the outcome.

- b_between:

  Numeric scalar: between-cluster (cluster-mean) mediator effect on the
  outcome.

- c_prime:

  Numeric scalar: direct effect of the treatment.

- estimates:

  Named numeric vector of parameter estimates: the four alias rows plus
  each model's fixed effects.

- vcov:

  Square variance-covariance matrix of `estimates`, with matching
  dimnames.

- kr_df:

  Named numeric vector of Kenward-Roger degrees of freedom, one per
  path, when `se_type = "kr"`; `NULL` otherwise.

- treatment, mediator, outcome:

  Character names of the variables.

- cluster:

  Character name of the cluster variable.

- n_obs:

  Integer number of observations.

- n_clusters:

  Integer number of clusters.

- cluster_sizes:

  Integer vector with one size per cluster.

- parameterization:

  `"within"` or `"raw"`: how the outcome model was fitted.

- covariates_centered:

  Logical: whether every level-1 covariate in the outcome model has a
  cluster-mean companion.

- se_type:

  `"model"` or `"kr"`.

- reml:

  Logical: whether the models were fitted by REML.

- converged:

  Logical convergence flag.

- sigma_m, sigma_y:

  Numeric scalars: residual standard deviations of the mediator and
  outcome models.

- tau_m, tau_y:

  Numeric scalars: random-intercept standard deviations of the mediator
  and outcome models.

- data:

  Optional data frame, or NULL.

- source_package:

  Character name of the originating package.

## Value

A `ClusterMediationData` S7 object.

## Details

With the within parameterization \\Y\_{ij} = \theta_0 + c' X_j + b_W
(M\_{ij} - \bar M_j) + b_B \bar M_j + \dots\\ and \\a\\ the effect of
the treatment on the mediator, the natural indirect effect is \\a b_B\\.
It splits into an own-mediator part \\a b_W\\ and a spillover part \\a
(b_B - b_W)\\.

The split is the large-cluster, cluster-average approximation. With the
observed cluster mean, moving only member \\i\\'s mediator by \\a\\ also
moves the mean by \\a / n_j\\, so the exact own-mediator effect is \\a
\[b_W + (b_B - b_W) / n_j\]\\ and the exact spillover is \\a (b_B -
b_W)(n_j - 1) / n_j\\; they still sum to \\a b_B\\.
[`decompose()`](https://data-wise.github.io/medfit/reference/decompose.md)
warns when the approximation error exceeds half the own effect's
standard error.

The estimand assumes randomized treatment, intact clusters, no
interference between clusters, linear models without
mediator-by-treatment or mediator-by-covariate products, and
interference through the observed cluster mean only; all members of a
cluster must be in the analysis rows. The own effect also needs no
unmeasured lower-level mediator-outcome confounding. The spillover, NIE
and NDE need no unmeasured upper-level mediator-outcome confounding
either; under it only the sum of the direct effect and \\a (b_B - b_W)\\
is identified. [`print()`](https://rdrr.io/r/base/print.html) and
[`summary()`](https://rdrr.io/r/base/summary.html) print this block. The
validator ties the alias rows `a`, `c_prime`, `b_within` and `b_between`
of `estimates` and `vcov` to the path properties, so an object with
inconsistent numbers cannot be built.

`kr_df` holds the Kenward-Roger degrees of freedom of each path when
`se_type = "kr"`, and is empty otherwise.

## References

Talloen, W., Moerkerke, B., Loeys, T., De Naeghel, J., Van Keer, H., &
Vansteelandt, S. (2016). Estimation of indirect effects in the presence
of unmeasured confounding for the mediator-outcome relationship in a
multilevel 2-1-1 mediation model. *Journal of Educational and Behavioral
Statistics*, 41(4), 359-391.
[doi:10.3102/1076998616636855](https://doi.org/10.3102/1076998616636855)

VanderWeele, T. J. (2010). Direct and indirect effects for
neighborhood-based clustered and longitudinal data. *Sociological
Methods & Research*, 38(4), 515-544.
[doi:10.1177/0049124110366236](https://doi.org/10.1177/0049124110366236)

## Examples

``` r
# Hand-built object (the paths and their alias rows must agree)
est <- c(a = 0.5, c_prime = 0.2, b_within = 0.3, b_between = 0.6)
vc <- diag(0.01, 4)
dimnames(vc) <- list(names(est), names(est))
cmd <- ClusterMediationData(
  a_path = 0.5, b_within = 0.3, b_between = 0.6, c_prime = 0.2,
  estimates = est, vcov = vc,
  treatment = "X", mediator = "M", outcome = "Y", cluster = "school",
  n_obs = 400L, n_clusters = 40L, cluster_sizes = rep(10L, 40),
  parameterization = "within", covariates_centered = TRUE, se_type = "model",
  reml = TRUE, converged = TRUE, sigma_m = 1, sigma_y = 1, tau_m = 0.5,
  tau_y = 0.5, source_package = "medfit"
)
cmd@a_path * cmd@b_between  # the NIE, 0.5 * 0.6
#> [1] 0.3
```
