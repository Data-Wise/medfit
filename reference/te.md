# Extract Total Effect (TE)

Extract the total effect from a mediation analysis result: the sum of
the indirect and direct effects.

## Usage

``` r
te(x, ...)
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

\$\$TE = NIE + NDE\$\$

For a
[SerialMediationData](https://data-wise.github.io/medfit/reference/SerialMediationData.md)
object the total effect is the sum over every directed X-to-Y path in
the fitted models: the direct path, the full chain, and every path that
skips a mediator (for two mediators, \\c' + a_1 b_1 + a_2 b_2 + a_1
d\_{21} b_2\\). With the same covariates in every equation and linear
models this equals the treatment coefficient of the outcome regressed on
the treatment and covariates alone. A path missing from its model counts
as zero; when a path is in a model but its coefficient was not recorded
(a hand-built object), `te()` returns `NA` with a warning. For glm fits
with a non-identity link the sum of path products is on the
linear-predictor scale, as for
[MediationData](https://data-wise.github.io/medfit/reference/MediationData.md).

## See also

[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
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

te(med_data)
#> Total Effect (TE): 0.5386

# Verify: TE = NIE + NDE
nie(med_data) + nde(med_data)
#> Natural Indirect Effect (NIE): 0.5386
```
