# Compare medfit's Product-Null LR with OpenMx or lavaan

Bounded FIML fits are refused before an external-engine comparison or
refit; this function does not extend their supported inference. See
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md).

Runs the likelihood-ratio test of a product null (\\a b = 0\\) in an
external SEM engine and compares it with medfit's own
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
statistic. A general-purpose optimizer handed the nonlinear constraint
\\a b = 0\\ can drop it (OpenMx at a zero start) or stop at the wrong
branch (lavaan from either start, OpenMx from its default start), which
reports a statistic above the true minimum. `compare_lr()` flags exactly
those cases and nothing else.

A warning is raised only on observed evidence, never because an LR is
zero: `medfit_warning_engine_constraint_dropped` when the engine's
returned fit violates the product constraint, and
`medfit_warning_engine_statistic_above_max` when the engine's statistic
exceeds medfit's. Both inherit from `medfit_warning_engine_comparison`.
If medfit has no accepted reference, the engines' unrestricted fits
differ from medfit's, or a run fails or cannot be checked, the verdict
is `"unresolved"` and neither side is blamed. medfit has no accepted
reference when one of its own refits cannot be fitted (see
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)):
the reference LR is then `NA` and the result is a comparison with that
verdict, not an error.

Only observed-variable models are compared. With either engine, a
saturated mean structure (every intercept free) and `fixed_x` (all, a
named subset or a lenient subset) are supported: the fixed exogenous
moments are written to the engine as fixed parameters at their sample
values (in OpenMx, a fit with a mean structure is run on the raw data
the fit used). Latent variables, product terms, fixed or constrained
intercepts, weights, factors, other fixed or shared parameters,
start/bound modifiers and constraints in the model are refused by name.

Known limit (#320): an engine's statistic can land above medfit's
reference because the null \\a b = 0\\ is two lines, \\a = 0\\ and \\b =
0\\, each with its own minimum. A general-purpose optimizer settles on
one line; when it settles on the line with the larger minimum, the
engine's statistic is that line's LR, not the product-null LR. medfit
fits each line as a linear model and keeps the smaller (see
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)).
`medfit_warning_engine_statistic_above_max` says only that a feasible,
converged engine statistic exceeds the reference; it does not say which
line the engine reached or whether it reached that line's minimum. A run
that stopped short of the minimum on either line raises the same
warning. Treat the warning as undiagnosed until both line minima are
computed: if the engine's statistic equals the other line's minimum, the
engine chose the wrong line and medfit's reference stands; otherwise it
may be an optimizer failure in the engine. On the pinned design (15
seeds by 4 cells, 60 runs per engine) the warning fires in 18 of 60
lavaan runs (either start) and 13 of 60 OpenMx default-start runs; in
that design each of those runs was checked and equals the other line's
minimum, and the smaller of lavaan's two runs equals medfit's reference
in all 60. The counts are unchanged by the 0.15.0 flip of the
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
defaults, and no run is mislabeled.

## Usage

``` r
compare_lr(object, paths, engine = c("lavaan", "openmx"), tolerance = 1e-04)
```

## Arguments

- object:

  A [SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)
  from
  [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md).

- paths:

  Character vector: the labels of the regression paths whose product is
  the indirect effect, as in
  [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md).

- engine:

  `"lavaan"` or `"openmx"`: the external comparison program that runs
  the product-null LR for comparison, not a fitter of the mediation
  model. The mediation model is always medfit's native fit `object`, and
  the result's `reference` is medfit's LR. The package must be
  installed.

- tolerance:

  Relative tolerance on the LR difference, scaled by `max(1, LR)`.
  Default `1e-4`; values above `1e-2` are refused, because a loose
  tolerance would call different statistics equal.

## Value

An object of class `medfit_lr_comparison`: a list with `verdict`
(`"agree"`, `"disagree"` or `"unresolved"`), `reason`, `reference`
(medfit's LR, `NA` when it has none, and whether it was accepted),
`runs` (one row per engine start with the LR, convergence, constraint
residual and status) and `engine`.

## See also

[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md),
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)

## Examples

``` r
# \donttest{
if (requireNamespace("lavaan", quietly = TRUE)) {
  fit <- fit_sem(
    "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment",
    data = mediation_demo, fixed_x = FALSE, meanstructure = NULL
  )
  compare_lr(fit, paths = c("a", "b"), engine = "lavaan")
}
#> medfit LR comparison (lavaan, a*b = 0): agree
#>   medfit reference LR 17.5574 (accepted)
#>  engine version   start      lr converged     residual status
#>  lavaan   0.7.3 default 17.5574      TRUE 2.428822e-09  agree
#>  lavaan   0.7.3    zero 17.5574      TRUE 3.773291e-09  agree
# }
```
