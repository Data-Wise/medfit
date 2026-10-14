# Weights and robust standard errors

Inverse-probability weights, or case weights for independent
observations, change the fit and the standard errors. Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection.

|  |  |
|----|----|
| **Structure** | any single-mediator model, fitted with weights |
| **Class returned** | `MediationData` |
| **Set with** | `weights =` and `se_type = "sandwich"` in [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md) |
| **Needs** | the suggested `sandwich` package for `se_type = "sandwich"` |

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

> **Pair weights with `se_type = "sandwich"`**
>
> Model-based standard errors assume the weights are known precision
> weights, which inverse-probability weights are not. medfit prints a
> once-per-session message when you use `weights` with the default
> `se_type`.

## Build stabilized weights

``` r
ps <- glm(treatment ~ covariate1 + covariate2, family = binomial(),
          data = mediation_demo)
p_t <- fitted(ps)
p_m <- mean(mediation_demo$treatment)
ipw <- ifelse(mediation_demo$treatment == 1, p_m / p_t, (1 - p_m) / (1 - p_t))
summary(ipw)
```

       Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
     0.7044  0.8933  0.9841  0.9997  1.0954  1.5436 

`mediation_demo`’s treatment is randomized, so these weights stay close
to 1; they illustrate the call, not a confounded design.

## Fit with the sandwich covariance

``` r
fit <- fit_mediation(
  outcome ~ treatment + mediator1 + covariate1 + covariate2,
  mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo, treatment = "treatment", mediator = "mediator1",
  weights = ipw, se_type = "sandwich"
)
tidy(fit, type = "effects", conf_int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std_error conf_low conf_high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.335    0.0657   0.206      0.463
    2 nde      0.208    0.115   -0.0180     0.433
    3 te       0.542    0.119    0.308      0.776

## What each choice does

| Choice | Effect |
|----|----|
| `weights = ipw` | both models are fitted with the weights |
| `se_type = "sandwich"` | heteroskedasticity-consistent (HC3) covariance for the estimates |
| `se_type = "model"` (default) | model-based covariance; not valid under inverse-probability weights |

## Limits

- HC3 treats the observations as independent. It does **not** handle
  survey clusters, strata or replicate weights.
- The `regmedint` engine accepts neither `weights` nor
  `se_type = "sandwich"`.
- The native engine takes weights too, in
  [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md),
  with its own sandwich (HC0-type) covariance; see [Methods and
  Formulas](https://data-wise.github.io/medfit/articles/methods.md).

## Related

[Simple
mediation](https://data-wise.github.io/medfit/articles/model-simple.md)
\| [Cookbook recipe
4](https://data-wise.github.io/medfit/articles/cookbook.html#weights-and-robust-standard-errors)
\| [Getting
Started](https://data-wise.github.io/medfit/articles/getting-started.md)
