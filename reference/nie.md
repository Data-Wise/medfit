# Extract Natural Indirect Effect (NIE)

Extract the natural indirect effect from a mediation analysis result.
The NIE represents the effect of treatment on outcome that operates
through the mediator(s).

## Usage

``` r
nie(x, ...)
```

## Arguments

- x:

  A
  [MediationData](https://data-wise.github.io/medfit/reference/MediationData.md),
  [SerialMediationData](https://data-wise.github.io/medfit/reference/SerialMediationData.md),
  [ParallelMediationData](https://data-wise.github.io/medfit/reference/ParallelMediationData.md),
  [InteractionMediationData](https://data-wise.github.io/medfit/reference/InteractionMediationData.md),
  [JointMediationData](https://data-wise.github.io/medfit/reference/JointMediationData.md),
  or
  [BootstrapResult](https://data-wise.github.io/medfit/reference/BootstrapResult.md)
  object. For a `BootstrapResult`, `nie()` returns the bootstrapped
  point estimate (with a warning if the statistic was not an NIE).

- ...:

  Additional arguments passed to methods. For a `SerialMediationData`,
  `type = c("chain", "total")` selects the chain-specific (default) or
  the total indirect effect (see Details).

## Value

A numeric scalar of class `mediation_effect` carrying a `type`
attribute. For intervals use
[`confint()`](https://rdrr.io/r/stats/confint.html) or
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md).

## Details

The effects are for a unit contrast of the treatment. By class:

- `MediationData`: \\NIE = a b\\.

- `SerialMediationData`: with `type = "chain"` (the default), the effect
  through the full chain only, \\NIE = a \\ d_1 \cdots d\_{k-1} \\ b\\;
  with `type = "total"`, the total indirect effect, the sum over every
  treatment-to-outcome path through at least one mediator (including
  paths that skip a mediator, such as X -\> M2 -\> Y), which equals
  `te(x) - nde(x)`.

- `ParallelMediationData`: \\NIE = \sum_j a_j b_j\\.

- `InteractionMediationData`: \\NIE = INTmed + PIE = (\theta_2 +
  \theta_3) \beta_1\\.

- `JointMediationData`: the joint NIE through all the mediators,
  \\\sum_i (\theta\_{2i} + \theta\_{3i}) \beta^\*\_{1i}\\.

The "Methods and Formulas" article on the package website gives the full
formulas.

## See also

[`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
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

nie(med_data)
#> Natural Indirect Effect (NIE): 0.3328
```
