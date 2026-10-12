# Joint Effects at a Given Parameter Vector

Recomputes the joint CDE, NDE, NIE and total effect of a
[JointMediationData](https://data-wise.github.io/medfit/reference/JointMediationData.md)
object from a named parameter vector, holding the object's structure,
reference levels (`m_star`) and sample covariate means fixed. With the
default `estimates = object@estimates` it returns the stored effects.
Its main use is as the statistic of a parametric bootstrap: the draws
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
passes to `statistic_fn` are named like `@estimates`, and the NDE needs
the prefixed intercept and covariate rows (`m1_`, ..., `y_`) and the
covariate means, not only the path aliases.

## Usage

``` r
joint_effects(object, estimates = object@estimates)
```

## Arguments

- object:

  A
  [JointMediationData](https://data-wise.github.io/medfit/reference/JointMediationData.md)
  object.

- estimates:

  Named numeric vector containing every prefixed source row of
  `object@estimates` (`m1_...`, `y_...`); alias rows are ignored. A
  missing source row is an error, not a zero.

## Value

Named numeric vector: `cde`, `nde`, `nie`, `te`.

## Examples

``` r
d <- mediation_demo
fit <- extract_mediation(
  lm(mediator1 ~ treatment + covariate1 + covariate2, d),
  model_y = lm(outcome_int ~ treatment * mediator1 + mediator2 +
                 covariate1 + covariate2, d),
  treatment = "treatment", mediator = c("mediator1", "mediator2"),
  mediator_models = list(lm(mediator2 ~ treatment + mediator1 +
                              covariate1 + covariate2, d))
)
joint_effects(fit)
#>       cde       nde       nie        te 
#> 0.1747908 0.2197091 0.6560315 0.8757405 

# Parametric bootstrap of the joint NIE
boot <- bootstrap_mediation(
  function(theta) joint_effects(fit, theta)[["nie"]],
  method = "parametric", mediation_data = fit, n_boot = 500, seed = 1
)
boot@ci_lower
#> [1] 0.435042
boot@ci_upper
#> [1] 0.9073042
```
