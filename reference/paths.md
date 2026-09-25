# Extract All Path Coefficients

Extract all path coefficients from a mediation analysis result.

## Usage

``` r
paths(x, ...)
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

A named numeric vector of path coefficients

## Details

For simple mediation (MediationData):

- `a`: Treatment -\> Mediator (X -\> M)

- `b`: Mediator -\> Outcome (M -\> Y \| X)

- `c_prime`: Direct effect (X -\> Y \| M)

For serial mediation (SerialMediationData):

- `a`: Treatment -\> First mediator

- `d` (two mediators) or `d21`, `d32`, ...: Mediator-to-mediator paths

- `b`: Last mediator -\> Outcome

- `c_prime`: Direct effect

For parallel mediation (ParallelMediationData): `a1`, `b1`, `a2`, `b2`,
..., `c_prime`.

For InteractionMediationData: `a`, `b`, `c_prime`, and `theta3` (the
treatment-by-mediator coefficient).

For JointMediationData: the raw coefficients `a1..aK`, `dij`, `b1..bK`,
`theta3_<mediator>`, and `c_prime`. The `a` paths here are the raw
coefficients, not the propagated `a*` values used by the effects.

## See also

[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
[`te()`](https://data-wise.github.io/medfit/reference/te.md),
[`pm()`](https://data-wise.github.io/medfit/reference/pm.md)

## Examples

``` r
med_data <- fit_mediation(
  formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
  formula_m = mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1"
)

paths(med_data)
#>         a         b   c_prime 
#> 0.5826425 0.5711384 0.2057983 
```
