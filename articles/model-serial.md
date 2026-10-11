# Serial mediation (a chain)

Treatment, then mediator 1, then mediator 2, then the outcome. Part of
the [Models](https://data-wise.github.io/medfit/articles/models.md)
collection.

|  |  |
|----|----|
| **Structure** | X to M1 to M2 to Y (a chain), plus every skip path |
| **Class returned** | `SerialMediationData` |
| **Indirect effect** | the chain \\a \\ d_1 \\ b\\; `nie(type = "total")` adds the paths that skip a mediator |
| **Routes** | `extract_mediation(..., mediator = c(...), mediator_models = list(...))` on `lm`/`glm`, or a lavaan fit |

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

One model per mediator plus the outcome model. Put every earlier
mediator in each later model, and every mediator in the outcome model.

``` r
fit_m1 <- lm(mediator1 ~ treatment + covariate1 + covariate2, mediation_demo)
fit_m2 <- lm(mediator2 ~ treatment + mediator1 + covariate1 + covariate2,
             mediation_demo)
fit_y <- lm(outcome ~ treatment + mediator1 + mediator2 + covariate1 +
              covariate2, mediation_demo)
x <- extract_mediation(fit_m1, model_y = fit_y, treatment = "treatment",
                       mediator = c("mediator1", "mediator2"),
                       mediator_models = list(fit_m2))
class(x)[1]
```

    [1] "medfit::SerialMediationData"

## Three effects, three meanings

``` r
c(chain = unname(nie(x)), every_path = unname(nie(x, type = "total")),
  total = unname(te(x)))
```

         chain every_path      total
    0.07545039 0.36740438 0.53856776 

| Call | Counts |
|----|----|
| `nie(x)` | the full chain through both mediators only |
| `nie(x, type = "total")` | every path through at least one mediator, including the ones that skip |
| `te(x)`, `pm(x)` | every path ([`te()`](https://data-wise.github.io/medfit/reference/te.md) is the total effect, [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) the proportion mediated) |

## Limits

- The order of `mediator_models` is checked against the `mediator`
  vector; a misordered list fails with an error.
- The lm/glm route fits the equations separately, so the stored
  covariance sets the covariances among the chain paths to zero; a
  lavaan fit or a nonparametric bootstrap captures them. See [Model
  Extraction](https://data-wise.github.io/medfit/articles/extraction.md).
- `tidy(x, type = "effects", conf.int = TRUE)` gives delta-method
  intervals for the effects; for a bootstrap interval see [Bootstrap
  Inference](https://data-wise.github.io/medfit/articles/bootstrap.md).

## Related

[Parallel
mediation](https://data-wise.github.io/medfit/articles/model-parallel.md)
\| [Joint
mediation](https://data-wise.github.io/medfit/articles/model-joint.md)
\| [Cookbook recipe
5](https://data-wise.github.io/medfit/articles/cookbook.html#two-mediators-in-a-chain)
\| [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md)
