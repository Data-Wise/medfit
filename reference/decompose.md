# Decomposition of a Mediation Effect

Return the components of the total effect for an object whose outcome
model has treatment-by-mediator products.

For an
[InteractionMediationData](https://data-wise.github.io/medfit/reference/InteractionMediationData.md)
object this is VanderWeele's (2014) four-way decomposition: controlled
direct effect (CDE), reference interaction (INTref), mediated
interaction (INTmed), and pure indirect effect (PIE), together with the
derived natural direct and indirect effects and the total effect. For a
[JointMediationData](https://data-wise.github.io/medfit/reference/JointMediationData.md)
object it is the CDE and the joint natural direct and indirect effects
(VanderWeele and Vansteelandt 2014).

## Usage

``` r
decompose(x, ...)
```

## Arguments

- x:

  An
  [InteractionMediationData](https://data-wise.github.io/medfit/reference/InteractionMediationData.md)
  or
  [JointMediationData](https://data-wise.github.io/medfit/reference/JointMediationData.md)
  object.

- ...:

  Additional arguments (ignored).

## Value

A named numeric vector: `c(cde, int_ref, int_med, pie, nde, nie, total)`
for `InteractionMediationData`, `c(cde, nde, nie, total)` for
`JointMediationData`.

## Details

For a 0/1 treatment, outcome model \\Y = \theta_0 + \theta_1 X +
\theta_2 M + \theta_3 X M + \dots\\, mediator model \\M = \beta_0 +
\beta_1 X + \dots\\, and reference mediator level \\m^\*\\: \$\$CDE =
\theta_1 + \theta_3 m^\*\$\$ \$\$INTref = \theta_3 (E\[M \mid X = 0,
\bar c\] - m^\*)\$\$ \$\$INTmed = \theta_3 \beta_1\$\$ \$\$PIE =
\theta_2 \beta_1\$\$ with \\NDE = CDE + INTref\\, \\NIE = INTmed +
PIE\\, and \\TE = NDE + NIE\\. \\E\[M \mid X = 0, \bar c\]\\ is the
mediator model's prediction at no treatment and the covariate means.

## References

VanderWeele, T. J. (2014). A unification of mediation and interaction: A
4-way decomposition. *Epidemiology*, 25(5), 749–761.

VanderWeele, T. J., & Vansteelandt, S. (2014). Mediation analysis with
multiple mediators. *Epidemiologic Methods*, 2(1), 95–115.
[doi:10.1515/em-2012-0010](https://doi.org/10.1515/em-2012-0010)

## See also

[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
[`te()`](https://data-wise.github.io/medfit/reference/te.md)

## Examples

``` r
# \donttest{
fit_m <- lm(mediator1 ~ treatment + covariate1 + covariate2,
            data = mediation_demo)
fit_y <- lm(outcome ~ treatment * mediator1 + covariate1 + covariate2,
            data = mediation_demo)
med_int <- extract_mediation(fit_m, model_y = fit_y,
                             treatment = "treatment", mediator = "mediator1")
decompose(med_int)
#>          cde      int_ref      int_med          pie          nde          nie 
#>  0.215212780 -0.002235243 -0.014225737  0.340017581  0.212977537  0.325791844 
#>        total 
#>  0.538769381 
# }
```
