# Extract Proportion Mediated (PM)

Extract the proportion of the total effect that is mediated (operates
through the mediator(s)).

## Usage

``` r
pm(x, ...)
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

A numeric scalar of class `mediation_effect`, usually between 0 and 1
(negative or greater than 1 in cases of suppression effects), or `NA`
with a warning when the total effect is numerically zero.

## Details

\$\$PM = \frac{NIE}{TE} = \frac{NIE}{NIE + NDE}\$\$

For serial mediation (SerialMediationData) the numerator is the total
indirect effect, `nie(x, type = "total")`, and the denominator the full
total effect from
[`te()`](https://data-wise.github.io/medfit/reference/te.md).

The proportion mediated can be:

- Between 0 and 1: Normal mediation

- Greater than 1: Suppression (direct and indirect effects have opposite
  signs)

- Negative: Inconsistent mediation

The ratio has no delta-method standard error in medfit; bootstrap it
with
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md).

## See also

[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
[`te()`](https://data-wise.github.io/medfit/reference/te.md),
[`paths()`](https://data-wise.github.io/medfit/reference/paths.md)

## Examples

``` r
med_data <- fit_mediation(
  formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
  formula_m = mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1"
)

pm(med_data)
#> Proportion Mediated (PM): 0.6179
```
