# Methods for SEMFit objects

**\[experimental\]**

Accessors and display for a
[SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)
returned by
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md).

## Arguments

- object, x:

  A [SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)
  object

- ...:

  Additional arguments (ignored)

## Value

[`coef()`](https://rdrr.io/r/stats/coef.html) a named numeric vector;
[`vcov()`](https://rdrr.io/r/stats/vcov.html) a matrix;
[`nobs()`](https://rdrr.io/r/stats/nobs.html) an integer;
[`logLik()`](https://rdrr.io/r/stats/logLik.html) an object of class
`"logLik"`; [`summary()`](https://rdrr.io/r/base/summary.html) an object
of class `"summary.SEMFit"`;
[`print()`](https://rdrr.io/r/base/print.html) invisibly returns its
argument.

## Details

- [`coef()`](https://rdrr.io/r/stats/coef.html) returns the
  free-parameter estimates, named as in the parameter table (the label
  when the row has one).

- [`vcov()`](https://rdrr.io/r/stats/vcov.html) returns their
  covariance, projected onto the active constraints and bounds; rows for
  a pinned parameter are zero.

- [`nobs()`](https://rdrr.io/r/stats/nobs.html) returns the number of
  rows used after listwise deletion.

- [`logLik()`](https://rdrr.io/r/stats/logLik.html) returns the log
  likelihood with the means free; its `df` attribute counts the free
  parameters plus one mean per observed variable.

- [`summary()`](https://rdrr.io/r/base/summary.html) collects the
  estimates, standard errors and z statistics, the defined parameters,
  and the diagnostics: rows dropped, information type, degrees of
  freedom, retries, stationarity, active bounds and constraints,
  improper-solution flags and the multiplier sign check.

## See also

[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md),
[SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)

## Examples

``` r
# \donttest{
fit <- fit_sem(
  "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment\nab := a*b",
  data = mediation_demo
)
coef(fit)
#>                      a                      b    outcome ~ treatment 
#>             0.45599612             0.71342873             0.04057666 
#> mediator1 ~~ mediator1     outcome ~~ outcome treatment ~~ treatment 
#>             1.15847022             1.18044624             0.24999375 
vcov(fit)[c("a", "b"), c("a", "b")]
#>               a             b
#> a  1.158499e-02 -3.349652e-14
#> b -3.349652e-14  2.547425e-03
nobs(fit)
#> [1] 400
summary(fit)
#> Summary of SEMFit
#> =================
#> 
#> Observations: 400
#> Degrees of freedom: 0
#> Information: observed
#> Standard errors: model-based
#> Converged: Yes
#> 
#> Parameters:
#>                    name    est     se       z      p
#>                       a 0.4560 0.1076  4.2366 <1e-04
#>                       b 0.7134 0.0505 14.1351 <1e-04
#>     outcome ~ treatment 0.0406 0.1111  0.3654  0.715
#>  mediator1 ~~ mediator1 1.1585 0.0819 14.1421 <1e-04
#>      outcome ~~ outcome 1.1804 0.0835 14.1421 <1e-04
#>  treatment ~~ treatment 0.2500 0.0177 14.1421 <1e-04
#> 
#> Defined parameters:
#>  name expr    est     se
#>    ab  a*b 0.3253 0.0802
#> 
#> Diagnostics:
#>   Optimizer status: 4; stationarity 1.22e-08; retries 0
#>   Active bounds: none
#>   Active constraints: none
#>   Improper solution: no
#>   Multiplier sign check: ok
# }
```
