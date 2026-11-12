# Joint mediation with products

Several mediators when the outcome model has treatment-by-mediator
products. The result is the joint effect through the whole mediator
block. Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection.

|  |  |
|----|----|
| **Structure** | X to (M1, M2, …) to Y, with X by M terms |
| **Class returned** | `JointMediationData` |
| **Effects** | joint natural direct and indirect effects (VanderWeele and Vansteelandt, 2014) |
| **Routes** | [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) on `lm` fits; [`joint_effects()`](https://data-wise.github.io/medfit/reference/joint_effects.md) for bootstrapping |

``` r
library(medfit)
```


    Attaching package: 'medfit'

    The following object is masked from 'package:stats':

        decompose

``` r
library(generics)
```


    Attaching package: 'generics'

    The following objects are masked from 'package:base':

        as.difftime, as.factor, as.ordered, intersect, is.element, setdiff,
        setequal, union

## Fit it

``` r
fit_m1 <- lm(mediator1 ~ treatment + covariate1 + covariate2, mediation_demo)
fit_m2 <- lm(mediator2 ~ treatment + mediator1 + covariate1 + covariate2,
             mediation_demo)
fit_y <- lm(outcome_int ~ treatment * mediator1 + mediator2 + covariate1 +
              covariate2, mediation_demo)
x <- extract_mediation(fit_m1, model_y = fit_y, treatment = "treatment",
                       mediator = c("mediator1", "mediator2"),
                       mediator_models = list(fit_m2))
class(x)[1]
```

    [1] "medfit::JointMediationData"

``` r
tidy(x, type = "effects", conf_int = TRUE)
```

    # A tibble: 4 × 5
      term  estimate std_error conf_low conf_high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 cde      0.175     0.113 -0.0468      0.396
    2 nde      0.220     0.116 -0.00710     0.447
    3 nie      0.656     0.116  0.428       0.884
    4 te       0.876     0.135  0.611       1.14 

## Bootstrap the joint effect

[`joint_effects()`](https://data-wise.github.io/medfit/reference/joint_effects.md)
returns the effects at any parameter vector, so it plugs into
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md).

``` r
boot <- bootstrap_mediation(
  function(theta) joint_effects(x, theta)[["nie"]],
  method = "parametric", mediation_data = x, n_boot = 500, seed = 1
)
c(estimate = unname(nie(x)), lower = boot@ci_lower, upper = boot@ci_upper)
```

     estimate     lower     upper
    0.6560315 0.4210529 0.8812853 

## Requirements

The fit must meet these; each violation errors with its cause.

- Every model carries the same covariates.
- All models are Gaussian identity-link, unweighted, with an intercept,
  and fit to the same rows (medfit compares the values of the shared
  variables).
- Every mediator appears in the outcome model, and the treatment is
  coded 0/1.
- Only outcome-model products written with `:` or `*` are supported.

## Related

[Serial
mediation](https://data-wise.github.io/medfit/articles/model-serial.md)
\| [Parallel
mediation](https://data-wise.github.io/medfit/articles/model-parallel.md)
\| [Cookbook recipe
8](https://data-wise.github.io/medfit/articles/cookbook.html#many-mediators-with-products)
\| [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md)
