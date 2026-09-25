# Extract Natural Direct Effect (NDE)

Extract the natural direct effect from a mediation analysis result. The
NDE represents the effect of treatment on outcome that does NOT operate
through the mediator(s).

## Usage

``` r
nde(x, ...)
```

## Arguments

- x:

  A
  [MediationData](https://data-wise.github.io/medfit/reference/MediationData.md),
  [SerialMediationData](https://data-wise.github.io/medfit/reference/SerialMediationData.md),
  [ParallelMediationData](https://data-wise.github.io/medfit/reference/ParallelMediationData.md),
  [InteractionMediationData](https://data-wise.github.io/medfit/reference/InteractionMediationData.md),
  or
  [JointMediationData](https://data-wise.github.io/medfit/reference/JointMediationData.md)
  object.

- ...:

  Additional arguments passed to methods

## Value

A numeric scalar of class `mediation_effect` carrying a `type`
attribute.

## Details

Without a treatment-by-mediator product (`MediationData`,
`SerialMediationData`, `ParallelMediationData`) the NDE is the
direct-path coefficient, \\NDE = c'\\. With a product it also depends on
the mediator's mean under no treatment:

- `InteractionMediationData`: \\NDE = CDE + INTref = \theta_1 + \theta_3
  E\[M \mid X = 0, \bar c\]\\.

- `JointMediationData`: \\NDE = \theta_1 + \sum_i \theta\_{3i}
  \mu^\*\_{0i}\\, with \\\mu^\*\_{0i}\\ the mean of mediator \\i\\ under
  no treatment at the covariate means.

## See also

[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`te()`](https://data-wise.github.io/medfit/reference/te.md),
[`pm()`](https://data-wise.github.io/medfit/reference/pm.md),
[`paths()`](https://data-wise.github.io/medfit/reference/paths.md),
[`decompose()`](https://data-wise.github.io/medfit/reference/decompose.md)

## Examples

``` r
med_data <- fit_mediation(
  formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
  formula_m = mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1"
)

nde(med_data)
#> Natural Direct Effect (NDE): 0.2058
```
