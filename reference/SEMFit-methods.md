# Methods for SEMFit objects

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
of class `"summary_SEMFit"`;
[`print()`](https://rdrr.io/r/base/print.html) invisibly returns its
argument.

## Details

- [`coef()`](https://rdrr.io/r/stats/coef.html) returns the
  free-parameter estimates, named as lavaan names its coefficients: the
  label when the row has one, else `lhs op rhs` without spaces (`"M~X"`,
  `"X~~X"`, `"eta=~m2"`). [`vcov()`](https://rdrr.io/r/stats/vcov.html),
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and the
  accessors
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  reads use the same names.

- [`vcov()`](https://rdrr.io/r/stats/vcov.html) returns their
  covariance, projected onto the active constraints and bounds; rows for
  a pinned parameter are zero.

- [`nobs()`](https://rdrr.io/r/stats/nobs.html) returns the number of
  rows used after listwise deletion.

- [`logLik()`](https://rdrr.io/r/stats/logLik.html) returns the log
  likelihood with the means free; its `df` attribute counts the free
  parameters plus one mean per observed variable that is not fixed. With
  `fixed_x` it is conditional on the fixed variables (lavaan's value),
  so [`AIC()`](https://rdrr.io/r/stats/AIC.html) and
  [`BIC()`](https://rdrr.io/r/stats/AIC.html) of fits with different
  fixed sets or data stop instead of ranking them; the same holds for
  [`anova()`](https://rdrr.io/r/stats/anova.html) and
  [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md).
  A `fixed_x` fit also lists its fixed moments after the free parameters
  in [`tidy()`](https://generics.r-lib.org/reference/tidy.html)
  (`fixed_x` column `TRUE`, no standard error) and in
  [`summary()`](https://rdrr.io/r/base/summary.html);
  [`coef()`](https://rdrr.io/r/stats/coef.html) and
  [`vcov()`](https://rdrr.io/r/stats/vcov.html) leave them out.
  [`print()`](https://rdrr.io/r/base/print.html) and
  [`summary()`](https://rdrr.io/r/base/summary.html) say what the log
  likelihood is conditional on.

- **Model test with a product term.** The global chi-square is not valid
  when a factor of a product term (`x:m`) is itself a regression target,
  because the model then treats the product as exogenous although it is
  a function of `m`; nor when the variances and covariances of the
  exogenous variables (every product included) are restricted (fixed,
  labeled, bounded, or left out because a `~~` statement names one of
  them; a `fixed_x` moment is not a restriction).
  [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
  then warns once,
  [`glance()`](https://generics.r-lib.org/reference/glance.html) reports
  `chisq`, `df` and `p_value` as `NA` (with the reason in
  `attr(, "note")`), [`summary()`](https://rdrr.io/r/base/summary.html)
  prints the reason, and [`anova()`](https://rdrr.io/r/stats/anova.html)
  and
  [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
  stop naming the product. The coefficients equal equation-wise least
  squares and the sandwich standard errors are unaffected, but only with
  observed information: `fit_sem(information = "expected")` stops for a
  product with an endogenous factor, because its standard errors (the
  sandwich built on them included) are wrong there.
  [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
  also warns once for any product term fitted without
  `se_type = "sandwich"`.
  [`logLik()`](https://rdrr.io/r/stats/logLik.html),
  [`AIC()`](https://rdrr.io/r/stats/AIC.html) and
  [`BIC()`](https://rdrr.io/r/stats/AIC.html) stay defined, but the
  values of a fit with a product are not comparable with those of a fit
  without one (the product column enters the likelihood), so
  `AIC(fit_a, fit_b)`, [`BIC()`](https://rdrr.io/r/stats/AIC.html),
  [`anova()`](https://rdrr.io/r/stats/anova.html) and
  [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
  refuse such a pair.

- [`anova()`](https://rdrr.io/r/stats/anova.html) tests nested fits by
  the likelihood-ratio statistic \\n (F_r - F_f)\\ on the difference in
  model degrees of freedom: `anova(fit_full, fit_restricted)`, or
  several fits, each tested against the one with fewer degrees of
  freedom. It compares fits that were already made and never refits. The
  fits must use the same observed variables and rows, and neither may
  have sampling weights or have failed to converge. Nesting is checked
  by parameter-table inclusion: the restricted fit may free no parameter
  the other leaves out and must have more degrees of freedom. That is
  necessary for nesting, not sufficient; whether two models are nested
  in substance is the analyst's responsibility. A restricted fit with a
  smaller discrepancy than the model it restricts is an error (one fit
  is not at its global optimum). When a bound or an inequality on a
  tested parameter is active at the restricted fit, the null lies on the
  boundary of the parameter space, the statistic is a mixture of
  chi-squares, and the function warns that the p-value is not valid, as
  [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
  does. The p-value is still returned; the logical attribute
  `attr(x, "p_valid")` (named by row, `NA` for the first) is `FALSE` for
  each such row, so code can read the verdict without parsing the
  warning. It belongs to the object
  [`anova()`](https://rdrr.io/r/stats/anova.html) returns: subsetting it
  with `[` or binding rows drops the attribute. Returns an object of
  class `"anova"` with columns `Df`, `Chisq` (n times the discrepancy),
  `Chisq diff`, `Df diff` and `Pr(>Chisq)`. Name rows by naming the
  arguments after the first.

- [`confint()`](https://rdrr.io/r/stats/confint.html) returns Wald
  (normal) intervals for the free parameters and the defined parameters,
  `confint(fit, parm, level = 0.95)`; `parm` takes names or positions. A
  parameter pinned by a constraint or sitting on a bound has a zero
  standard error and a point interval.

- [`tidy()`](https://generics.r-lib.org/reference/tidy.html) returns one
  row per free parameter, then the moments `fixed_x` fixed (a `fixed_x`
  column, only when something is fixed), then per defined parameter:
  `term` (the name [`coef()`](https://rdrr.io/r/stats/coef.html) uses),
  `op` (the operator of its row in the parameter table, `:=` for a
  defined parameter), `estimate`, `std_error`, `statistic` (the z value,
  `NA` when the standard error is zero), `p_value` (two-sided), and with
  `conf_int = TRUE` the interval
  [`confint()`](https://rdrr.io/r/stats/confint.html) returns
  (`conf_low`, `conf_high`, at `conf_level`). `type` is `"all"`
  (default), `"parameters"` or `"defined"`.

- [`glance()`](https://generics.r-lib.org/reference/glance.html) returns
  one row: `nobs`, `npar` (free parameters after the equality
  constraints), `df`, `chisq` (n times the minimized discrepancy, the
  test of the model against the saturated one), `p_value` (`NA` when
  `df` is 0), `logLik`, `AIC` and `BIC` (with the means free, as
  [`logLik()`](https://rdrr.io/r/stats/logLik.html) defines them) and
  `fixed_x`, the names the fit holds at their sample moments,
  comma-joined (`""` when none). A fit with sampling weights has no
  likelihood, so its `chisq`, `p_value`, `logLik`, `AIC` and `BIC` are
  `NA`. There is no `converged` column:
  [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
  returns a fit only for a solution that passed the acceptance gate and
  errors otherwise, so `@converged` is `TRUE` for every `SEMFit` and
  would carry no information.

- [`summary()`](https://rdrr.io/r/base/summary.html) collects the
  estimates, standard errors and z statistics, the defined parameters,
  and the diagnostics: rows dropped, information type, degrees of
  freedom, retries, stationarity, optimum status, active bounds and
  constraints, improper-solution flags and the multiplier sign check.

## See also

[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md),
[SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)

## Examples

``` r
# \donttest{
fit <- fit_sem(
  "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment\nab := a*b",
  data = mediation_demo, fixed_x = FALSE, meanstructure = NULL
)
coef(fit)
#>                    a                    b    outcome~treatment 
#>           0.45599612           0.71342873           0.04057666 
#> mediator1~~mediator1     outcome~~outcome treatment~~treatment 
#>           1.15847022           1.18044624           0.24999375 
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
generics::tidy(fit, conf_int = TRUE)
#> # A tibble: 7 × 8
#>   term            op    estimate std_error statistic  p_value conf_low conf_high
#>   <chr>           <chr>    <dbl>     <dbl>     <dbl>    <dbl>    <dbl>     <dbl>
#> 1 a               ~       0.456     0.108      4.24  2.27e- 5    0.245     0.667
#> 2 b               ~       0.713     0.0505    14.1   2.31e-45    0.615     0.812
#> 3 outcome~treatm… ~       0.0406    0.111      0.365 7.15e- 1   -0.177     0.258
#> 4 mediator1~~med… ~~      1.16      0.0819    14.1   2.09e-45    0.998     1.32 
#> 5 outcome~~outco… ~~      1.18      0.0835    14.1   2.09e-45    1.02      1.34 
#> 6 treatment~~tre… ~~      0.250     0.0177    14.1   2.09e-45    0.215     0.285
#> 7 ab              :=      0.325     0.0802     4.06  4.95e- 5    0.168     0.482
generics::glance(fit)
#> # A tibble: 1 × 9
#>    nobs  npar    df chisq p_value logLik   AIC   BIC fixed_x
#>   <int> <int> <dbl> <dbl>   <dbl>  <dbl> <dbl> <dbl> <chr>  
#> 1   400     6     0     0      NA -1488. 2994. 3030. ""     

# a likelihood-ratio test of b = 0 against the fitted model
fit0 <- fit_sem(paste0(fit@model, "\nb == 0"), data = mediation_demo)
#> Warning: fit_sem(): `fixed_x` is unset. Its default changes from FALSE to the model's exogenous observed variables in medfit 0.15.0 (lavaan's fixed.x = TRUE): their variances, covariances and means are fixed at the sample values, which changes logLik, npar, AIC and BIC; structural estimates and SEs are unchanged on the measured cases. To silence this, pass the argument explicitly (the old default keeps today's results), or opt in to the 0.15.0 defaults with options(medfit.native_defaults = "0.15"). Shown once per session.
#> Warning: fit_sem(): `meanstructure` is unset. Its default changes from NULL (a mean structure only when the model writes `~1`) to TRUE in medfit 0.15.0: intercepts and means become free parameters, which changes logLik, npar, AIC and BIC; structural estimates and SEs are unchanged on the measured cases. To silence this, pass the argument explicitly (the old default keeps today's results), or opt in to the 0.15.0 defaults with options(medfit.native_defaults = "0.15"). Shown once per session.
anova(fit, fit0)
#> Likelihood-ratio (chi-square difference) test for SEMFit models
#> 
#> n = 400; Chisq is n times the minimized discrepancy
#> 
#>      Df  Chisq Chisq diff Df diff Pr(>Chisq)    
#> fit   0   0.00                                  
#> fit0  1 162.05     162.05       1  < 2.2e-16 ***
#> ---
#> Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1
# }
```
