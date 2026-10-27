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
  meanstructure = TRUE,
  fixed_x = TRUE,
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

  Logical or `NULL`. `TRUE` (default) fits a mean structure; `NULL` fits
  one only when the model writes an intercept (`y ~ 1`, free or fixed);
  `FALSE` fits covariances only and errors if an intercept is written.
  With a mean structure every observed variable whose intercept is not
  written has a free one, so a model with only free intercepts has the
  same estimates and standard errors as the covariance-only fit. A
  latent variable's mean is fixed at 0. A model with a product term
  (`y ~ x + m + x:m`) always fits the mean structure (it needs the
  mediator intercept for the four-way decomposition), so with a product
  `meanstructure = FALSE` is an error. An explicit `NULL` or `FALSE` is
  kept as given.

- fixed_x:

  `TRUE` (default), `FALSE`, or a character vector of exogenous observed
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
  [`vcov()`](https://rdrr.io/r/stats/vcov.html). Left unset it resolves
  to an explicit subset: every exogenous observed variable (product and
  factor-dummy columns included) except those a `~~` or `~1` statement
  names, which are left free with a message of class
  `medfit_message_fixed_x_lenient` (an explicit `TRUE` errors there
  instead; an explicit `FALSE` is kept). `glance()$fixed_x` names the
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
`diagnostics$ledger` holds the versioned outcome ledger described below.

## Defaults changed in 0.15.0

`fixed_x` is the exogenous observed variables (lavaan's
`fixed.x = TRUE`) and `meanstructure = TRUE`, so a default fit matches a
default [`lavaan::sem()`](https://rdrr.io/pkg/lavaan/man/sem.html) fit.
Against 0.14.x the parameter count,
[`logLik()`](https://rdrr.io/r/stats/logLik.html),
[`AIC()`](https://rdrr.io/r/stats/AIC.html),
[`BIC()`](https://rdrr.io/r/stats/AIC.html) and the names in
[`coef()`](https://rdrr.io/r/stats/coef.html),
[`vcov()`](https://rdrr.io/r/stats/vcov.html) and
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) change; the
structural estimates and their standard errors did not change on the
cases measured. Which random start a multi-start fit tries can change
too (the retry seed follows the parameter names). To keep the 0.14.x
results, pass `fixed_x = FALSE, meanstructure = NULL`.
`options(medfit.native_defaults)` is obsolete and ignored, with one
message per session; it is removed in 0.16.0.

## Outcome ledger

`diagnostics$ledger` is a list with `schema_version = 1L`. Each node has
`id`, `parent_id`, the exact parsed `constraints`, and `context` (the
estimation `sample`, the model syntax and parameters, the likelihood
`domain`, the settings and `n_obs`). `enumeration` records `state` and
the number of required children; `complete` means every required
restriction was attempted, not that any was globally optimized.
`outcome` is `resolved` or `unresolved`. Separate fields record
`optimizer` (acceptance state, original status, decrement, retries and
optimum diagnostics), `likelihood` (availability and `f`), `feasibility`
(`witness` or `unknown`), `covariance` (`available`, `unavailable`,
`not_retained` or `failed`), `improper`, the retained `notices`
(warnings and messages), the original `condition` (class, message, call)
and the recursive `children`. IDs are deterministic positions within the
call, not certificates of equivalent parameter spaces. No global optimum
is asserted, and a failed branch is unknown, never certified infeasible.

A node whose constraints hold zero-product rows also has `branch_map`:
`state`, `raw_count`, the parser `factor_counts`, `unique_count` and
`raw_to_canonical`, a structural restriction-set ID for each raw row.
The IDs collapse duplicate or permuted constraint rows, not arbitrary
affine equivalence, and every raw row is still fitted in its original
order (ties go to the first). More than 64 raw combinations, duplicates
included, is refused before the grid is allocated, even when the unique
count would be smaller; that node is `not_enumerated`, with an unknown
unique count and no raw mapping, and nothing is fitted or certified. Its
message prints the count without scientific notation, labels a count
above \\2^{53}\\ as approximate (a double need not be an exact
cardinality there) and names an overflow; `raw_count` is `Inf` on
overflow. If the map cannot be built while an error is recorded, its
`state` is `unavailable` with that condition, and the original error is
not replaced. The map is rebuilt from the node's constraints during
validation, so a forged map is refused.

The one proof of emptiness is the literal certificate
`literal_zero_nonzero`: an explicit `label == 0` equality and an
explicit finite nonzero literal equality on the same parsed label
(`a == 0` with `a == 1`). Its label, source rows and values are kept in
`certificate` and rebuilt from the node's own parsed parameters and
constraints before any inference uses it. A certified-empty branch is
retained with `outcome = "excluded"`, `feasibility = "certified_empty"`
and an unavailable likelihood: it is not fitted and is not a successful
fit. No tolerance, solver status, numerical rank, bound, general affine
contradiction or fixed value in the parameter table is a proof, and a
literal too small to represent (`1e-999`) is unknown.

A zero-product fit returns only if at least one required branch resolves
and every other branch resolves or is certified empty. A direct fit
whose own equalities contradict literally stops with
`medfit_sem_infeasible`, and a union whose every branch is certified
empty with `medfit_sem_empty_union`; both are refinements of
`medfit_error_no_convergence` and carry the ledger. Otherwise it stops
with a `medfit_error_no_convergence` error, never a fit; the error
carries the ledger of every required branch as `$ledger` and, when a
branch survived, `$best_survivor` (its `id` and discrepancy `f`,
diagnostic only, never a p-value). The union's own node does not
aggregate its children's notices; inspect each child. The notices of a
failed call are in the ledger only; the error message keeps its text. A
data or model error keeps its own class and also carries `$ledger`. The
estimation sample is stored once, on the root node; a descendant fitted
on the same rows carries only `context$sample_hash`. A fit made before
the ledger existed must be refitted before
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
can use it, which refuses it with a `medfit_error_ledger` error.

When the optimizer accepts a fit and only the covariance stage fails (an
error from the covariance, not the singular-information NA return, which
stays `unavailable` with its warning), the call stops with
`medfit_sem_covariance_error`, never a fit. The class is a sibling of
`medfit_error_no_convergence`: no optimizer failed, so the handlers that
report an unresolved result for an optimizer failure do not take it. Its
fields are `schema_version = 1L`, `stage = "covariance"`, `partial` (the
accepted optimizer result: `f`, `theta`, sample, domain, dimensions and
settings; no `vcov` or `defined`) and `ledger` (the same node as
`partial$ledger`, with `covariance = "failed"` and `post_fit`: versioned
evidence with the original condition's class, message and call). The
message is the original one. Resolved here means an accounted-for
accepted likelihood, not a successful covariance. A union root reports
the first failing branch's `post_fit`, in branch order, even when
another branch supplies its minimum likelihood, and does not claim the
winning branch failed: inspect the branch IDs. A branch that did not
converge still stops the call with `medfit_error_no_convergence` first.
Definition values and gradients are checked before the covariance, and
model, data, optimizer, objective and other errors get no covariance
certificate. The condition is not accepted as an input to
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md),
and a fit that carries `post_fit` is refused with `medfit_error_ledger`.

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
