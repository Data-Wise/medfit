# lavaan fits

You fitted the model as a structural equation model with lavaan and want
the same effects and tables. Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection.

|  |  |
|----|----|
| **Structure** | simple, serial or parallel mediation, written as lavaan syntax |
| **Class returned** | `MediationData`, `SerialMediationData` or `ParallelMediationData` |
| **Route** | `extract_mediation(<lavaan fit>, treatment = , mediator = , outcome = )` |
| **Needs** | `lavaan` |

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
has_lavaan <- requireNamespace("lavaan", quietly = TRUE)
covs <- "covariate1 + covariate2"
```

## Simple mediation

Label the paths in the syntax, fit with
[`lavaan::sem()`](https://rdrr.io/pkg/lavaan/man/sem.html), then
extract:

``` r
syntax <- paste0("
  mediator1 ~ a * treatment + ", covs, "
  outcome ~ b * mediator1 + c_prime * treatment + ", covs)
fit <- lavaan::sem(syntax, data = mediation_demo)
x <- extract_mediation(fit, treatment = "treatment", mediator = "mediator1",
                       outcome = "outcome")
class(x)[1]
```

    [1] "medfit::MediationData"

``` r
tidy(x, type = "effects", conf.int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std.error conf.low conf.high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.333    0.0642  0.207       0.459
    2 nde      0.206    0.109  -0.00801     0.420
    3 te       0.539    0.119   0.306       0.771

Every function from the [simple mediation
page](https://data-wise.github.io/medfit/articles/model-simple.md) works
on `x`.

## Serial mediation

Give `mediator` two names, in chain order. The class follows the
structure:

``` r
syntax_s <- paste0("
  mediator1 ~ a * treatment + ", covs, "
  mediator2 ~ d * mediator1 + a2 * treatment + ", covs, "
  outcome ~ b * mediator2 + b1 * mediator1 + c_prime * treatment + ", covs)
xs <- extract_mediation(lavaan::sem(syntax_s, data = mediation_demo),
                        treatment = "treatment",
                        mediator = c("mediator1", "mediator2"),
                        outcome = "outcome")
class(xs)[1]
```

    [1] "medfit::SerialMediationData"

``` r
tidy(xs, type = "effects", conf.int = TRUE)
```

    # A tibble: 4 × 5
      term      estimate std.error conf.low conf.high
      <chr>        <dbl>     <dbl>    <dbl>     <dbl>
    1 nie         0.0755    0.0211   0.0342     0.117
    2 nie_total   0.367     0.0690   0.232      0.503
    3 nde         0.171     0.106   -0.0366     0.379
    4 te          0.539     0.119    0.306      0.771

The row `nie` is the chain through both mediators; `nie_total` adds the
paths that skip a mediator. See [Serial
mediation](https://data-wise.github.io/medfit/articles/model-serial.md).

## Parallel mediation

``` r
syntax_p <- paste0("
  mediator1 ~ a1 * treatment + ", covs, "
  mediator3 ~ a2 * treatment + ", covs, "
  outcome ~ b1 * mediator1 + b2 * mediator3 + c_prime * treatment + ", covs)
xp <- extract_mediation(lavaan::sem(syntax_p, data = mediation_demo),
                        treatment = "treatment",
                        mediator = c("mediator1", "mediator3"),
                        outcome = "outcome", structure = "parallel")
class(xp)[1]
```

    [1] "medfit::ParallelMediationData"

``` r
nie(xp)
```

    Natural Indirect Effect (NIE): 0.4324

## Why use a lavaan fit

The equations are fitted together, so the stored covariance includes the
covariances among the paths. That matters most for serial chains, where
the lm/glm route sets them to zero (see [Serial
mediation](https://data-wise.github.io/medfit/articles/model-serial.md)).

## Limits

- **The regressions must name the variables.**
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  finds each path by the variable names, so the model must contain
  `outcome ~ mediator1`; if it does not, extraction stops with “Could
  not find b path (mediator -\> outcome)”.
- **Four-way effects** (a treatment-by-mediator product) need the mean
  structure and a specific syntax; see [Model
  Extraction](https://data-wise.github.io/medfit/articles/extraction.md)
  for what is supported before relying on it.
- To write a model as syntax **without** lavaan, with latent mediators
  and constraints, use the [native
  engine](https://data-wise.github.io/medfit/articles/model-native.md).

## Related

[Cookbook recipe
10](https://data-wise.github.io/medfit/articles/cookbook.html#i-use-lavaan)
\| [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md)
\| [Native
engine](https://data-wise.github.io/medfit/articles/model-native.md)
