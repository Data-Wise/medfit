# Fit a Structural Equation Model by Maximum Likelihood

Fits a model written in lavaan-style syntax to raw data with medfit's
native maximum-likelihood engine, and returns a
[SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md) object.
The engine handles observed and latent variables, user labels, fixed
values, starts and bounds, equality and inequality constraints (`==`,
`<`, `>`, linear or nonlinear), and defined parameters (`:=`) with
delta-method standard errors.

## Usage

``` r
fit_sem(
  model,
  data,
  information = c("observed", "expected"),
  n_starts = NULL,
  control = list(),
  weights = NULL,
  se_type = c("model", "sandwich"),
  meanstructure = NULL,
  fixed_x = FALSE,
  sampling_weights = lifecycle::deprecated()
)
```

## Arguments

- model:

  Character: model syntax. Lines may use `~` (regression), `=~` (latent
  variable), `~~` (variance or covariance), `label*variable` modifiers,
  [`start()`](https://rdrr.io/r/stats/start.html), `lower()` and
  `upper()`, and the constraint operators `==`, `<`, `>` and `:=`. An
  intercept is written `y ~ 1` (alone or with other terms, as in
  `y ~ 1 + x`) and turns on the mean structure. A product of two
  observed variables is written `x:m` on the right side of a regression
  (canonical name `m:x`);
  [`?"medfit-syntax"`](https://data-wise.github.io/medfit/reference/medfit-syntax.md)
  lists the supported class and each limit.

- data:

  A data frame with the model's observed variables. Numeric columns are
  used as is; a factor, character or logical column named on a
  regression's right side is expanded to 0/1 dummies
  ([`?"medfit-syntax"`](https://data-wise.github.io/medfit/reference/medfit-syntax.md)
  lists the rules and limits). Rows with missing values in those columns
  are dropped once (listwise deletion) and counted in `n_dropped`.

- information:

  Character: `"observed"` (default) or `"expected"` information for the
  standard errors. `"expected"` is an error for a model with a product
  term that has an endogenous factor (the product is a function of
  another variable, so the expected information gives wrong standard
  errors); use the default with `se_type = "sandwich"`.

- n_starts:

  Positive integer or `NULL`: number of optimizer starts tried before
  the fit is declared failed (`NULL` uses 5). Retries use perturbed
  starts drawn under a fixed seed and never change the caller's random
  number stream; with 3 or more starts the last attempt is the model's
  own moment-based start, so a start in a bad basin does not end the
  fit. With a nonlinear constraint, which can leave several local
  optima, every start is tried and the best accepted one is kept (a
  warning says when the accepted starts disagree); otherwise the first
  accepted start is used.

- control:

  List: options passed to the optimizer (`nloptr`).

- weights:

  Optional numeric vector of non-negative case weights, one per row of
  `data` (`NULL`, the default, fits unweighted). The fit is weighted
  maximum likelihood on the weighted mean and covariance; the scale of
  the weights does not matter. Rows dropped for missing values drop
  their weights with them. Use with `se_type = "sandwich"`.

- se_type:

  Character: `"model"` (default) takes the covariance of the estimates
  from the inverse information; `"sandwich"` uses the robust sandwich
  covariance \\A^{-1} B A^{-1}\\ with casewise scores (HC0-type: it
  equals `sandwich::vcovHC(type = "HC0")` per equation and lavaan's
  robust standard errors with `sampling.weights`, and is smaller than
  the HC3 default of the glm route by a factor that shrinks like
  \\1/n\\). Model-based standard errors are not valid under weights.

- meanstructure:

  Logical or `NULL`. `NULL` (default) fits a mean structure when the
  model writes an intercept (`y ~ 1`, free or fixed); `TRUE` fits one
  regardless; `FALSE` fits covariances only and errors if an intercept
  is written. With a mean structure every observed variable whose
  intercept is not written has a free one, so a model with only free
  intercepts has the same estimates and standard errors as the
  covariance-only fit. A latent variable's mean is fixed at 0. A model
  with a product term (`y ~ x + m + x:m`) always fits the mean structure
  (it needs the mediator intercept for the four-way decomposition), so
  with a product `meanstructure = FALSE` is an error. Left unset, with
  no `~1` and no product in the model, it warns once per session that
  the default becomes `TRUE` in medfit 0.15.0;
  `options(medfit.native_defaults = "0.15")` uses `TRUE` now.

- fixed_x:

  `FALSE` (default), `TRUE`, or a character vector of exogenous observed
  variable names. The selected variables (`TRUE`: every exogenous
  observed variable, product columns included) have their mean (with a
  mean structure), variance and the exogenous covariances the model
  contains fixed at the sample moments of the estimation sample
  (weighted when `weights` are given) and removed from estimation, as
  lavaan does with `fixed.x = TRUE`. The structural estimates, their
  standard errors, the degrees of freedom and the chi-square do not
  change; the parameter count and the log likelihood do: the log
  likelihood (and so AIC and BIC) is conditional on the fixed variables,
  and `glance()$fixed_x` lists them. Models whose `fixed_x` sets or data
  differ cannot be compared with
  [`stats::anova()`](https://rdrr.io/r/stats/anova.html),
  [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md),
  [`AIC()`](https://rdrr.io/r/stats/AIC.html) or
  [`BIC()`](https://rdrr.io/r/stats/AIC.html). A (co)variance or
  intercept statement on a selected variable is an error (lavaan would
  silently keep it free). The fixed rows stay in the parameter table
  (`fixed_x` column, no standard error) but not in
  [`coef()`](https://rdrr.io/r/stats/coef.html) or
  [`vcov()`](https://rdrr.io/r/stats/vcov.html). Left unset, in a model
  with an exogenous observed variable, it warns once per session that
  the default becomes the exogenous observed variables in medfit 0.15.0;
  `options(medfit.native_defaults = "0.15")` uses that now: every
  exogenous observed variable (product and factor-dummy columns
  included) except those a `~~` or `~1` statement names, which are left
  free with a message of class `medfit_message_fixed_x_lenient` (an
  explicit `TRUE` errors there instead). `glance()$fixed_x` names the
  set the fit used.

- sampling_weights:

  **\[deprecated\]** Renamed `weights`, the name
  [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  uses; the old name still works with a warning.

## Value

A [SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)
object. With a product term whose factor is a regression target (`x:m`
with `m` regressed on `x`),
[`glance()`](https://generics.r-lib.org/reference/glance.html) reports
the chi-square, df and p-value as `NA` with a note, and
[`anova()`](https://rdrr.io/r/stats/anova.html) and
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
refuse; see
[SEMFit-methods](https://data-wise.github.io/medfit/reference/SEMFit-methods.md).

## Defaults are changing

In medfit 0.15.0 the defaults become `fixed_x` = the exogenous observed
variables (lavaan's `fixed.x = TRUE`) and `meanstructure = TRUE`, so a
default fit matches a default
[`lavaan::sem()`](https://rdrr.io/pkg/lavaan/man/sem.html) fit. 0.14.0
changes no result: it warns once per session per argument (class
`medfit_warning_default_change`) when an argument is left unset in a
model where its default will matter. Under the new defaults the
parameter count, [`logLik()`](https://rdrr.io/r/stats/logLik.html),
[`AIC()`](https://rdrr.io/r/stats/AIC.html),
[`BIC()`](https://rdrr.io/r/stats/AIC.html) and the names in
[`coef()`](https://rdrr.io/r/stats/coef.html),
[`vcov()`](https://rdrr.io/r/stats/vcov.html) and
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) change; the
structural estimates and their standard errors did not change on the
cases measured. Which random start a multi-start fit tries can change
too (the retry seed follows the parameter names). To keep today's
results and silence the warning, pass both arguments, for example
`fixed_x = FALSE, meanstructure = NULL`. To fit with the 0.15.0 defaults
now, set `options(medfit.native_defaults = "0.15")`; variables a `~~` or
`~1` statement names are then left free and named in a message of class
`medfit_message_fixed_x_lenient`.

## See also

[SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md),
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)

## Examples

``` r
# \donttest{
fit <- fit_sem(
  "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment\nab := a*b",
  data = mediation_demo, fixed_x = FALSE, meanstructure = NULL
)
fit@defined
#>   name expr       est         se
#> 1   ab  a*b 0.3253207 0.08016376

# A treatment-by-mediator product: the four-way decomposition
fit4 <- fit_sem(
  "mediator1 ~ treatment\noutcome_int ~ treatment + mediator1 + treatment:mediator1",
  data = mediation_demo, se_type = "sandwich"
)
#> Warning: the model test is not valid for this model: the product 'mediator1:treatment' has an endogenous factor ('mediator1'). `glance()` and `summary()` report the chi-square, df and p-value as NA, and `anova()` and `mbco_sem()` refuse. The coefficients equal equation-wise OLS, and the sandwich standard errors (observed information) are unaffected.
decompose(extract_mediation(fit4, treatment = "treatment", mediator = "mediator1",
                            outcome = "outcome_int"))
#>        cde    int_ref    int_med        pie        nde        nie      total 
#> 0.04048833 0.07763088 0.22810575 0.32526471 0.11811921 0.55337046 0.67148967 
# }
```
