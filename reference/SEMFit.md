# SEMFit S7 Class

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

  Numeric scalar: minimized maximum-likelihood discrepancy; `NA` for
  bounded FIML

- n_obs, n_dropped:

  Integer scalars: rows used and rows dropped for missing values
  (listwise deletion by default; only all-empty model rows for FIML)

- df:

  Numeric scalar: model-test degrees of freedom; `NA` for bounded FIML,
  which stores the free-parameter count separately in
  `internals$likelihood$k`

- information:

  Character scalar: `"observed"` or `"expected"`

- converged:

  Logical scalar: the acceptance gate passed.
  [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
  returns a fit only for an accepted solution (otherwise it errors), so
  this is `TRUE` for every fit it returns and
  [`glance()`](https://generics.r-lib.org/reference/glance.html) does
  not report it

- data:

  Data frame: the rows used, on the model's observed variables

- model:

  Character scalar: the model syntax

- diagnostics:

  List: the versioned outcome `ledger` (see
  [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md))
  and optimizer diagnostics (`status`, `decrement`, `retries`,
  `active_bounds`, `active_constraints`, `improper`, `sign_check`, and
  `optimum`: a list with `n_starts`, `n_accepted`, `best_of`,
  `certified`, `spread` (discrepancy range among accepted starts, `NA`
  when fewer than two or not best-of), and `status` (`unique`,
  `certified`, `agreed`, `disagreed`, or `single`))

- internals:

  List: the internal index objects the engine needs (`ram`, `par_map`,
  `constraints`); not part of the interface

- call:

  Call object or NULL: the call that produced the fit

## Value

A SEMFit S7 object

## See also

[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)

## Examples

``` r
# \donttest{
fit <- fit_sem(
  "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment\nab := a*b",
  data = mediation_demo, fixed_x = FALSE, meanstructure = NULL
)
fit@table[fit@table$op == "~", c("lhs", "rhs", "est", "se")]
#>         lhs       rhs        est         se
#> 1 mediator1 treatment 0.45599612 0.10763360
#> 2   outcome mediator1 0.71342873 0.05047202
#> 3   outcome treatment 0.04057666 0.11106057
fit@defined
#>   name expr       est         se
#> 1   ab  a*b 0.3253207 0.08016376
fit@converged
#> [1] TRUE
# }
```
