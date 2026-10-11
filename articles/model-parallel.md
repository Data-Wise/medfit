# Parallel mediation

Two or more mediators that the treatment drives independently, with no
path between them. Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection.

|  |  |
|----|----|
| **Structure** | X to M_j to Y, one path per mediator |
| **Class returned** | `ParallelMediationData` |
| **Indirect effect** | the sum \\\sum_j a_j b_j\\ |
| **Routes** | `extract_mediation(..., structure = "parallel")` on `lm`/`glm`, or a lavaan fit |

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
fit_m3 <- lm(mediator3 ~ treatment + covariate1 + covariate2, mediation_demo)
fit_y <- lm(outcome ~ treatment + mediator1 + mediator3 + covariate1 +
              covariate2, mediation_demo)
x <- extract_mediation(fit_m1, model_y = fit_y, treatment = "treatment",
                       mediator = c("mediator1", "mediator3"),
                       mediator_models = list(fit_m3), structure = "parallel")
paths(x)
```

           a1        b1        a2        b2   c_prime
    0.5826425 0.5685676 0.4760604 0.2124038 0.1061791 

``` r
nie(x)
```

    Natural Indirect Effect (NIE): 0.4324

## Read it

| Quantity   | Meaning                                                        |
|------------|----------------------------------------------------------------|
| `a1`, `a2` | effect of the treatment on each mediator                       |
| `b1`, `b2` | effect of each mediator on the outcome, both in the same model |
| `nie(x)`   | \\a_1 b_1 + a_2 b_2\\, the total through both mediators        |

## Limits

- The mediator equations are fitted separately, so the stored covariance
  omits Cov(\\a_j\\, \\a\_{j'}\\). When the mediators’ errors are
  correlated, the indirect-effect standard error can be off; a lavaan
  fit or a nonparametric bootstrap captures it.
- Each mediator must be driven by the treatment (and covariates) only.
  If one mediator affects another, use [serial
  mediation](https://data-wise.github.io/medfit/articles/model-serial.md).

## Related

[Serial
mediation](https://data-wise.github.io/medfit/articles/model-serial.md)
\| [Joint
mediation](https://data-wise.github.io/medfit/articles/model-joint.md)
\| [Cookbook recipe
6](https://data-wise.github.io/medfit/articles/cookbook.html#two-mediators-side-by-side)
\| [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md)
