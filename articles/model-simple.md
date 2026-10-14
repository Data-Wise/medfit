# Simple mediation

One treatment, one mediator, one outcome: the model behind most
mediation analyses. This page runs it three ways and reads the result.
Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection; for a one-page lookup see the [Reference
Card](https://data-wise.github.io/medfit/articles/refcard.md).

|  |  |
|----|----|
| **Structure** | X to M to Y, with the direct path X to Y |
| **Class returned** | `MediationData` |
| **Indirect effect** | \\a \\ b\\ |
| **Routes** | [`med()`](https://data-wise.github.io/medfit/reference/med.md), [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md), [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) on `lm`/`glm`, lavaan, or [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md) |

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
covs <- c("covariate1", "covariate2")
```

## When to use it

Use it when one mediator carries the effect of the treatment and you
have no reason to expect a treatment-by-mediator interaction. If the
mediator and the outcome interact with the treatment, see
[interaction](https://data-wise.github.io/medfit/articles/model-interaction.md);
for two or more mediators see
[serial](https://data-wise.github.io/medfit/articles/model-serial.md)
and
[parallel](https://data-wise.github.io/medfit/articles/model-parallel.md).

## Route 1: one line

[`med()`](https://data-wise.github.io/medfit/reference/med.md) fits both
models, extracts the structure and returns the result.

``` r
res <- med(mediation_demo, treatment = "treatment", mediator = "mediator1",
           outcome = "outcome", covariates = covs)
quick(res)
```

    NIE = 0.333  | NDE = 0.206 | PM = 61.8 %

## Route 2: formulas

[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
takes one formula per model, so each model can carry its own covariates.

``` r
fit <- fit_mediation(
  formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
  formula_m = mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo, treatment = "treatment", mediator = "mediator1"
)
tidy(fit, type = "effects", conf_int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std_error conf_low conf_high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.333    0.0645  0.206       0.459
    2 nde      0.206    0.110  -0.00936     0.421
    3 te       0.539    0.119   0.304       0.773

## Route 3: models you already fitted

``` r
fit_m <- lm(mediator1 ~ treatment + covariate1 + covariate2, mediation_demo)
fit_y <- lm(outcome ~ treatment + mediator1 + covariate1 + covariate2,
            mediation_demo)
x <- extract_mediation(fit_m, model_y = fit_y,
                       treatment = "treatment", mediator = "mediator1")
paths(x)
```

            a         b   c_prime
    0.5826425 0.5711384 0.2057983 

The same object comes from a lavaan fit
(`extract_mediation(lavaan_fit, ...)`) or from the native engine
(`extract_mediation(fit_sem(...), ...)`); see [Cookbook recipe
10](https://data-wise.github.io/medfit/articles/cookbook.html#i-use-lavaan)
and [recipe
11](https://data-wise.github.io/medfit/articles/cookbook.html#a-latent-mediator-native-engine).

## Reading the result

| Quantity | Call | Meaning |
|----|----|----|
| `a` | `paths(x)` | effect of the treatment on the mediator |
| `b` | `paths(x)` | effect of the mediator on the outcome, holding the treatment fixed |
| `c_prime` | `paths(x)`, `nde(x)` | direct effect of the treatment |
| NIE | `nie(x)` | indirect effect, \\a \\ b\\ |
| TE | `te(x)` | total effect, NIE plus NDE |
| PM | `pm(x)` | proportion mediated, NIE over TE |

``` r
c(nie = unname(nie(x)), nde = unname(nde(x)), te = unname(te(x)),
  pm = unname(pm(x)))
```

          nie       nde        te        pm
    0.3327695 0.2057983 0.5385678 0.6178786 

Intervals for the effects come from the delta method
([`tidy()`](https://generics.r-lib.org/reference/tidy.html),
[`confint()`](https://rdrr.io/r/stats/confint.html)). For a bootstrap
interval see [Bootstrap
Inference](https://data-wise.github.io/medfit/articles/bootstrap.md).

## Assumptions and limits

- The treatment is randomized, or the models adjust for every confounder
  of the treatment-outcome, treatment-mediator and mediator-outcome
  relations.
- The mediator-outcome confounders must be in **both** models; leaving a
  covariate out of one biases that path.
- A near-zero total effect makes the proportion mediated unstable.
- The default `glm` engine is maximum likelihood on independent
  observations; for clustered data see [Cookbook recipe
  9](https://data-wise.github.io/medfit/articles/cookbook.html#cluster-randomized-trial).

## Related

[Getting
Started](https://data-wise.github.io/medfit/articles/getting-started.md)
\| [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md)
\| [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md) \|
[Cookbook](https://data-wise.github.io/medfit/articles/cookbook.md)
