# Optimizer settings for the sem engine

Builds the `control` argument of
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
and
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
(and of
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
with `engine = "sem"`, through `engine_args = list(control = )`). A
plain list is still accepted there and keeps its earlier meaning: every
entry is an `nloptr` option, exactly as `sem_control(nloptr = <list>)`.

## Usage

``` r
sem_control(optimizer = "auto", n_starts = NULL, nloptr = list())
```

## Arguments

- optimizer:

  Character: `"auto"` (default) leaves the algorithm to the engine
  (SLSQP for a listwise fit, unless `nloptr` names another `algorithm`;
  the fixed SLSQP-plus-`nlminb` protocol for FIML). `"slsqp"` requests
  SLSQP explicitly; it gives the same fit as `"auto"`, and naming a
  different `nloptr` `algorithm` with it is an error. FIML accepts only
  `"auto"`.

- n_starts:

  Positive integer or `NULL` (default): the number of starts, as the
  `n_starts` argument of
  [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md).
  Giving it both here and at the top level is an error unless the two
  agree. `NULL` uses the top-level value, or the default of the
  estimator (5 listwise, 3 for FIML).

- nloptr:

  Named list of options passed to `nloptr` for a listwise fit (for
  example `list(maxeval = 20000L)`). The empty list (default) keeps the
  engine's options. FIML requires the empty list.

## Value

An object of class `medfit_sem_control`: a list with elements
`optimizer`, `n_starts` and `nloptr`.

## Details

The resolved search protocol of a fit (estimator, the algorithm that
ran, the number of starts and the start rule) is recorded in
`fit@diagnostics$protocol`.

A top-level `n_starts` that differs in value from
`sem_control(n_starts = )`, or `optimizer = "slsqp"` with a different
`nloptr` `algorithm`, stops with an error of class
`medfit_error_sem_control_conflict`.

## See also

[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md),
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)

## Examples

``` r
ctl <- sem_control(nloptr = list(maxeval = 20000L))
ctl
#> <sem_control>
#>   optimizer: auto 
#>   n_starts:  default 
#>   nloptr:    maxeval = 20000 
fit <- fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment",
               mediation_demo, control = ctl)
fit@diagnostics$protocol
#> $version
#> [1] 1
#> 
#> $estimator
#> [1] "listwise"
#> 
#> $optimizer
#> [1] "NLOPT_LD_SLSQP"
#> 
#> $n_starts
#> [1] 5
#> 
#> $start_rule
#> [1] "model_start_then_perturbed"
#> 
```
