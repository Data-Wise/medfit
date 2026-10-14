# Native engine: several mediators and weights

Serial and parallel mediators, and sampling weights, with the native
engine. Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection; the last of four [native
engine](https://data-wise.github.io/medfit/articles/model-native.md)
pages. The engine is experimental.

|  |  |
|----|----|
| **Structure** | serial (a chain) or parallel mediators written as syntax |
| **Route** | [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md), then `extract_mediation(fit, mediator = c(...), outcome = )` |
| **Classes returned** | `SerialMediationData` or `ParallelMediationData` |
| **Weights** | `fit_sem(weights = , se_type = "sandwich")` |

> **Not `fit_mediation(engine = "native")`**
>
> `fit_mediation(engine = "native")` takes **one** mediator and stops
> with “Must have length 1” for more. For several, fit with
> [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
> and extract.

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

``` r
covs <- "covariate1 + covariate2"
```

## Serial mediators

``` r
serial_syntax <- paste0("
  mediator1 ~ a * treatment + ", covs, "
  mediator2 ~ d * mediator1 + a2 * treatment + ", covs, "
  outcome ~ b * mediator2 + b1 * mediator1 + cp * treatment + ", covs)
sfit <- fit_sem(serial_syntax, mediation_demo)
xs <- extract_mediation(sfit, treatment = "treatment",
                        mediator = c("mediator1", "mediator2"),
                        outcome = "outcome")
class(xs)[1]
```

    [1] "medfit::SerialMediationData"

``` r
c(chain = unname(nie(xs)), every_path = unname(nie(xs, type = "total")),
  total = unname(te(xs)))
```

         chain every_path      total
    0.07545038 0.36740437 0.53856775 

With the default `structure = "auto"`, medfit classifies the mediators
from the model: here it finds the path from `mediator1` to `mediator2`
and returns the serial class. See [Serial
mediation](https://data-wise.github.io/medfit/articles/model-serial.md)
for what the three numbers mean.

## Parallel mediators

``` r
parallel_syntax <- paste0("
  mediator1 ~ a1 * treatment + ", covs, "
  mediator2 ~ a2 * treatment + ", covs, "
  outcome ~ b1 * mediator1 + b2 * mediator2 + cp * treatment + ", covs)
pfit <- fit_sem(parallel_syntax, mediation_demo)
xp <- extract_mediation(pfit, treatment = "treatment",
                        mediator = c("mediator1", "mediator2"),
                        outcome = "outcome", structure = "parallel")
class(xp)[1]
```

    [1] "medfit::ParallelMediationData"

``` r
tidy(xp, type = "effects", conf_int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std_error conf_low conf_high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.367    0.0604   0.249      0.486
    2 nde      0.171    0.106   -0.0366     0.379
    3 te       0.539    0.114    0.315      0.762

## Sampling weights

`weights` gives weighted maximum likelihood; pair it with
`se_type = "sandwich"` for robust standard errors. The weights below are
random, only to show the call:

``` r
set.seed(1)
w <- runif(nrow(mediation_demo), 0.5, 2)
wsyntax <- "
  mediator1 ~ a * treatment + covariate1 + covariate2
  outcome ~ b * mediator1 + cp * treatment + covariate1 + covariate2
  ab := a * b
"
wfit <- fit_sem(wsyntax, mediation_demo, weights = w, se_type = "sandwich")
wfit@defined
```

      name  expr       est         se
    1   ab a * b 0.3450729 0.07052234

The scale of the weights does not matter. Supplying weights with the
default `se_type = "model"` prints a once-per-session message that
model-based standard errors are not valid under inverse-probability
weighting.

## Limits

- **`fit_mediation(engine = "native")` takes one mediator** (see the
  warning above).
- **Four-way decomposition** needs one mediator and a
  treatment-by-mediator product (`x:m`) in the outcome equation, and a
  model with a product cannot have a residual covariance between the
  mediators (parallel mediators with `m1 ~~ m2` and a product are not
  supported; see [product
  terms](https://data-wise.github.io/medfit/articles/model-native.html#product-terms)).
  Intercepts are estimated; see [the native model
  page](https://data-wise.github.io/medfit/articles/model-native.html#intercepts).
- **The native sandwich is the HC0 type**, with casewise scores; the
  `glm` engine’s sandwich is HC3. They are different estimators, so the
  standard errors need not match.
- **The sandwich treats observations as independent**, so it does not
  handle survey clusters, strata or replicate weights.

## Related

[Serial
mediation](https://data-wise.github.io/medfit/articles/model-serial.md)
\| [Parallel
mediation](https://data-wise.github.io/medfit/articles/model-parallel.md)
\| [Weights and robust
SEs](https://data-wise.github.io/medfit/articles/model-weights.md) \|
[Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md)
