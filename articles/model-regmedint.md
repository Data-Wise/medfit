# The regmedint engine

`engine = "regmedint"` computes the effects from the closed-form
regression formulas of VanderWeele, with analytical standard errors. It
needs the suggested `regmedint` package. Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection.

|  |  |
|----|----|
| **Structure** | one mediator, with or without an X by M term |
| **Class returned** | `MediationData`, or `InteractionMediationData` with a product |
| **Set with** | `engine = "regmedint"` in [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md) |
| **Needs** | a numeric 0/1 treatment and the same covariates in both formulas |

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
fit_rm <- fit_mediation(
  outcome ~ treatment + mediator1 + covariate1 + covariate2,
  mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo, treatment = "treatment", mediator = "mediator1",
  engine = "regmedint"
)
nie(fit_rm)
```

    Natural Indirect Effect (NIE): 0.3328

## Compare with the default engine

``` r
fit_glm <- fit_mediation(
  outcome ~ treatment + mediator1 + covariate1 + covariate2,
  mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo, treatment = "treatment", mediator = "mediator1"
)
c(regmedint = unname(nie(fit_rm)), glm = unname(nie(fit_glm)))
```

    regmedint       glm
    0.3327695 0.3327695 

## When to choose it

| Choose `regmedint` when | Choose the default `glm` engine when |
|----|----|
| you want the closed-form standard errors for the four-way decomposition | you need weights or the sandwich covariance |
| you already use `regmedint` and want the same numbers | you want the engine with the widest options |

## Limits

- No `weights` and no `se_type = "sandwich"`.
- The treatment must be numeric 0/1 and both formulas must carry the
  same covariates.
- Engine-specific settings go through `engine_args`; the reference level
  of the mediator for the controlled direct effect is `m_star`.

## Related

[Treatment-by-mediator
interaction](https://data-wise.github.io/medfit/articles/model-interaction.md)
\| [Simple
mediation](https://data-wise.github.io/medfit/articles/model-simple.md)
\| [Getting
Started](https://data-wise.github.io/medfit/articles/getting-started.md)
