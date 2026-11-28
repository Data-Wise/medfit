# TwoLevelParallelMediationData Class

**Experimental.** Like
[TwoLevelMediationData](https://data-wise.github.io/medfit/dev/reference/TwoLevelMediationData.md),
this class may change without the usual deprecation period.

## Usage

``` r
TwoLevelParallelMediationData(
  a_within, b_within, c_prime_within, a_between, b_between, c_prime_between,
  estimates, vcov, parameter_table, treatment, mediators, outcome, cluster, n_obs,
  n_clusters, cluster_sizes, icc, between_identified, admissible, converged,
  cross_level_equal, fixed_paths, source, fixed_x, information, h1_information,
  se_type, estimator, missing, lavaan_version, call, between_parameterization,
  data, source_package, source_version
)
```

## Arguments

- a_within, b_within:

  Named numeric vectors of length k (names `mediators`): within-level
  paths \\X \to M_j\\ and \\M_j \to Y\\ (always finite).

- c_prime_within:

  Numeric scalar: within-level direct path (always finite).

- a_between, b_between:

  Named numeric vectors of length k: between-level paths; all `NA_real_`
  when `between_identified` is `FALSE`.

- c_prime_between:

  Numeric scalar: between-level direct path; `NA_real_` when
  `between_identified` is `FALSE`.

- estimates:

  Named numeric vector of the identified path rows (the alias rows
  above).

- vcov:

  Covariance matrix of `estimates`: the sub-block of the fit's joint
  covariance, so the cross-level and cross-mediator covariances are
  carried.

- parameter_table:

  Data frame, one row per path row (`path`, `level`, `lhs`, `op`, `rhs`,
  `label`, `free`, `est`, `se`), kept for audit.

- treatment, outcome, cluster:

  Character scalars: variable names.

- mediators:

  Character vector of length \\k \ge 2\\: unique mediator names, in the
  order of the path vectors.

- n_obs, n_clusters:

  Integer scalars: rows used and number of clusters.

- cluster_sizes:

  Integer vector of cluster sizes (length `n_clusters`).

- icc:

  Named numeric vector: intraclass correlation of the treatment, each
  mediator and the outcome. It is the unrestricted (h1) estimate, as for
  [TwoLevelMediationData](https://data-wise.github.io/medfit/dev/reference/TwoLevelMediationData.md);
  the within-only rule reads it.

- between_identified:

  Logical scalar: whether the between level is identified.

- admissible:

  Logical scalar: `lavaan::lavInspect(fit, "post.check")`.

- converged:

  Logical scalar: whether the fit converged.

- cross_level_equal:

  Character vector: paths equated across levels.

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

  Data frame or `NULL`: always `NULL` for the lavaan adapter.

- source_package:

  Character scalar: `"lavaan"`, or `"medfit"` for a native two-level
  fit.

- source_version:

  Character: `character(0)` (the default) or one non-empty string, the
  version of the package that made the fit.

## Value

A `TwoLevelParallelMediationData` S7 object.

## Details

S7 class for two-level mediation with \\k \ge 2\\ parallel mediators,
all measured on level-1 units nested in clusters (1-1-1), with the paths
estimated separately at the within and the between level (latent cluster
means, fixed slopes). It is the parallel counterpart of
[TwoLevelMediationData](https://data-wise.github.io/medfit/dev/reference/TwoLevelMediationData.md):
a separate class, so the one-mediator object keeps its scalar paths.
Every property other than the paths and `mediators` has the meaning it
has there.

Per level \\l\\ the specific indirect effect through \\M_j\\ is
\\a\_{jl} b\_{jl}\\, the total indirect effect is \\\sum_j a\_{jl}
b\_{jl}\\ and the direct effect is \\c'\_l\\. When the between level
cannot be identified the object is **within-only**: the between path
vectors hold `NA_real_` (still named by `mediators`), `c_prime_between`
is `NA_real_`, and the between rows are absent from `estimates` and
`vcov`.

The alias rows of `estimates` and `vcov` are, per level, `a_<M>_within`
for each mediator, then `b_<M>_within`, then `c_prime_within`, and the
same set with `_between`.
