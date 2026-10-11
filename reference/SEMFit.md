# SEMFit S7 Class

**\[experimental\]**

S7 class holding a structural equation model fitted by the native
maximum-likelihood engine (see
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)):
estimates, their covariance, the parameter table, defined parameters
(`:=`) with delta-method standard errors, and the diagnostics of the
optimizer.

## Usage

``` r
SEMFit(theta, vcov, table, defined, f, n_obs, n_dropped, df, information,
  converged, data, model, diagnostics, internals, call)
```

## Arguments

- theta:

  Named numeric vector: free-parameter estimates

- vcov:

  Numeric matrix: covariance of `theta` (projected onto the active
  constraints and bounds; `NA` when the model is not identified)

- table:

  Data frame: one row per parameter-table row with `lhs`, `op`, `rhs`,
  `label`, `free`, `est` and `se`

- defined:

  Data frame of `:=` parameters: `name`, `expr`, `est`, `se`

- f:

  Numeric scalar: minimized maximum-likelihood discrepancy

- n_obs, n_dropped:

  Integer scalars: rows used and rows dropped for missing values
  (listwise deletion)

- df:

  Numeric scalar: degrees of freedom

- information:

  Character scalar: `"observed"` or `"expected"`

- converged:

  Logical scalar: the acceptance gate passed

- data:

  Data frame: the rows used, on the model's observed variables

- model:

  Character scalar: the model syntax

- diagnostics:

  List: optimizer diagnostics (`status`, `decrement`, `retries`,
  `active_bounds`, `active_constraints`, `improper`, `sign_check`)

- internals:

  List: the internal index objects the engine needs (`ram`, `par_map`,
  `constraints`); not part of the interface

- call:

  Call object or NULL: the call that produced the fit

## Value

A SEMFit S7 object

## See also

[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
