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
  sampling_weights = lifecycle::deprecated()
)
```

## Arguments

- model:

  Character: model syntax. Lines may use `~` (regression), `=~` (latent
  variable), `~~` (variance or covariance), `label*variable` modifiers,
  [`start()`](https://rdrr.io/r/stats/start.html), `lower()` and
  `upper()`, and the constraint operators `==`, `<`, `>` and `:=`. Mean
  structures are not supported.

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
