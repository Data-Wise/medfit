# Missing data: bounded FIML

Keep partly observed rows instead of deleting them. Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection.

|  |  |
|----|----|
| **Structure** | X to M to Y, two parallel mediators, or two serial mediators (the saturated graph or the pure chain), each with no, one or two covariates |
| **Class returned** | `FIMLMediationData` (simple), `FIMLParallelMediationData` (parallel) and `FIMLSerialMediationData` (serial) |
| **Route** | `fit_sem(model, data, missing = "fiml", fixed_x = FALSE)` then [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md), or `fit_mediation(engine = "native", engine_args = list(missing = "fiml", ...))` |
| **Standard errors** | observed information, model-based; delta-method effect intervals |
| **Availability** | simple model from 0.16.0; covariates, parallel and serial forms in the development version |

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

## What it is, and what it assumes

Ordinary fits delete every row with a missing value on a model variable.
Full-information maximum likelihood (FIML) keeps a row that has at least
one observed model variable and uses what it has. It assumes the
variables are jointly normal and that the missingness is ignorable under
that model (missing at random). It does not impute values, and a fixed
pattern of missing values in a real study is not evidence that
missingness is ignorable.

The opt-in is deliberately narrow and explicit. It requires continuous
X, M and Y, independent Gaussian disturbances, free intercepts,
`fixed_x = FALSE`, `meanstructure = TRUE`, observed information and
model-based standard errors. A failed FIML fit never falls back to
listwise deletion or to another engine.

## A simple example

``` r
d <- withr::with_seed(271L, {
  n <- 400L
  x <- .8 + stats::rnorm(n, sd = 1.1)
  m <- -.4 + .5 * x + stats::rnorm(n, sd = .8)
  y <- .7 + .6 * m + .25 * x + stats::rnorm(n, sd = .9)
  data.frame(treatment = x, mediator1 = m, outcome = y)
})
d$mediator1[seq(1, nrow(d), by = 7)] <- NA_real_
```

``` r
syntax <- "mediator1 ~ a*treatment
outcome ~ b*mediator1 + cp*treatment"
fit <- fit_sem(syntax, d, missing = "fiml", fixed_x = FALSE,
               meanstructure = TRUE, information = "observed", se_type = "model")
nobs(fit)   # every row with an observed model variable is kept
```

    [1] 400

``` r
z <- extract_mediation(fit, treatment = "treatment", mediator = "mediator1")
tidy(z, type = "effects")
```

    # A tibble: 3 × 3
      term  estimate std_error
      <chr>    <dbl>     <dbl>
    1 nie      0.279    0.0365
    2 nde      0.247    0.0508
    3 te       0.527    0.0457

## Which models are covered

| Model | Covariates | Notes |
|----|----|----|
| X, M, Y | 0, 1 or 2 | direct path free or fixed at exactly zero |
| Two parallel mediators | 0, 1 or 2 | the mediator disturbances independent (`M1 ~~ 0*M2`) or free |
| Two serial mediators, saturated | 0, 1 or 2 | both shortcut paths `X -> M2` and `M1 -> Y` written and free |
| Two serial mediators, pure chain | 0, 1 or 2 | both shortcut paths absent; a restriction the data can reject |

In the serial forms all three disturbance covariances (`M1 ~~ 0*M2`,
`M1 ~~ 0*Y`, `M2 ~~ 0*Y`) must be written. With covariates, every
covariate predicts every equation and the exogenous covariances are all
written or none. The syntax rules, parameter counts and the extraction
details are in the [native
guide](https://data-wise.github.io/medfit/articles/native-guide.html#bounded-fiml).

In a serial fit,
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
names both mediators in the fitted order. In the pure chain the
treatment is the variable with no path to the second mediator, so a
covariate cannot be named as the treatment there. In the saturated graph
any exogenous variable may be the treatment when no direct path is
fixed, and a direct path fixed at zero marks the treatment.
[`print()`](https://rdrr.io/r/base/print.html) and
[`summary()`](https://rdrr.io/r/base/summary.html) of a serial FIML
object name the variant and the covariates.

## What is not available

- Case weights, fit tests
  ([`anova()`](https://rdrr.io/r/stats/anova.html)), profiles and MBCO.
- Source-fit bootstrap intervals:
  `bootstrap_mediation(source_fit = ...)` is implemented but withheld
  until statistical admission, and raises
  `medfit_error_fiml_inference_unavailable`. Delta-method (normal)
  intervals from
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
  [`confint()`](https://rdrr.io/r/stats/confint.html) are available.
- [`quick()`](https://data-wise.github.io/medfit/reference/quick.md),
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) and
  [`glance()`](https://generics.r-lib.org/reference/glance.html) on an
  extracted FIML object.
- Three or more covariates, three or more mediators, constraints, ties,
  bounds, latent variables, factors and products.

## Evidence

The fits are compared with lavaan raw-data FIML (and OpenMx on one cell
per form) on complete, missing-completely-at-random, missing-at-random
and sparse patterns, with an independent likelihood check and
planted-defect tests (the `fiml` and `fiml-ext` simulation gates).
Nothing here is a coverage claim for intervals under missing data.

## Related

[Native: paths and defined
parameters](https://data-wise.github.io/medfit/articles/model-native.md)
\| [Parallel
mediation](https://data-wise.github.io/medfit/articles/model-parallel.md)
\| [Serial
mediation](https://data-wise.github.io/medfit/articles/model-serial.md)
\| [Choosing an
interval](https://data-wise.github.io/medfit/articles/guide-intervals.md)
\| [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.html#fiml-source-intervals)
