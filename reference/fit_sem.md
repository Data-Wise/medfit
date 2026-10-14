# Fit a Structural Equation Model by Maximum Likelihood

**\[experimental\]**

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
  `y ~ 1 + x`) and turns on the mean structure.

- data:

  A data frame with the model's observed variables as numeric columns.
  Rows with missing values in those columns are dropped once (listwise
  deletion) and counted in `n_dropped`.

- information:

  Character: `"observed"` (default) or `"expected"` information for the
  standard errors.

- n_starts:

  Positive integer or `NULL`: number of optimizer starts tried before
  the fit is declared failed (`NULL` uses 5). Retries use perturbed
  starts drawn under a fixed seed and never change the caller's random
  number stream. With a nonlinear constraint, which can leave several
  local optima, every start is tried and the best accepted one is kept
  (a warning says when the accepted starts disagree); otherwise the
  first accepted start is used.

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
  covariance-only fit. A latent variable's mean is fixed at 0.

- fixed_x:

  `FALSE` (default), `TRUE`, or a character vector of exogenous observed
  variable names. The selected variables (`TRUE`: every exogenous
  observed variable, product columns included) have their mean (with a
  mean structure), variance and every covariance with another exogenous
  variable fixed at the sample moments of the estimation sample
  (weighted when `weights` are given) and removed from estimation, as
  lavaan does with `fixed.x = TRUE`. The structural estimates, their
  standard errors, the degrees of freedom and the chi-square do not
  change; the parameter count and the log likelihood do: the log
  likelihood (and so AIC and BIC) is conditional on the fixed variables,
  and `glance()$fixed_x` lists them. Models whose `fixed_x` sets or data
  differ cannot be compared with
  [`anova()`](https://rdrr.io/r/stats/anova.html),
  [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md),
  [`AIC()`](https://rdrr.io/r/stats/AIC.html) or
  [`BIC()`](https://rdrr.io/r/stats/AIC.html). A (co)variance or
  intercept statement on a selected variable is an error (lavaan would
  silently keep it free). The fixed rows stay in the parameter table
  (`fixed_x` column, no standard error) but not in
  [`coef()`](https://rdrr.io/r/stats/coef.html) or
  [`vcov()`](https://rdrr.io/r/stats/vcov.html).

- sampling_weights:

  **\[deprecated\]** Renamed `weights`, the name
  [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  uses; the old name still works with a warning.

## Value

A [SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)
object.

## See also

[SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md),
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)

## Examples

``` r
# \donttest{
fit <- fit_sem(
  "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment\nab := a*b",
  data = mediation_demo
)
fit@defined
#>   name expr       est         se
#> 1   ab  a*b 0.3253207 0.08016376
# }
```
