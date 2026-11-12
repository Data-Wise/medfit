# RMediation and medfit

RMediation builds on medfit’s objects: it computes confidence intervals
for a product of coefficients from the exact distribution of the product
(DOP) or Monte Carlo draws, and the model-based constrained-likelihood
(MBCO) test for a pair of fits. medfit supplies the fitting and
extraction, its own delta-method intervals and
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md).
This page runs both on one fit and lists what RMediation accepts from
medfit, with a status for each row that a test checks against a live
call on each build.

|  |  |
|----|----|
| **Use medfit when** | you want every effect and path from one object, a native `SEMFit`, or an interval from the bootstrap infrastructure |
| **Use RMediation when** | you want an interval from the distribution of a product (not a normal approximation), or `mbco()` on a restricted and a full `SEMFit` |
| **Both** | read the same `MediationData` and `SerialMediationData`; the `mbco()` p-value agrees with [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) on a product null |

The statements below were checked against RMediation 1.11.1 (a GitHub
release) with medfit 0.16.0. RMediation is not a dependency of medfit,
so the chunks run only where RMediation 1.11.1 or later is installed; a
site built without it shows the code and the numbers quoted in the text.
CRAN has 1.6.1, whose `mbco()` accepts only OpenMx models.

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
ok <- requireNamespace("RMediation", quietly = TRUE) && utils::packageVersion("RMediation") >= "1.11.1"
```

## Three intervals for one indirect effect

``` r
fit <- fit_mediation(outcome ~ treatment + mediator1, mediator1 ~ treatment,
                     data = mediation_demo, treatment = "treatment", mediator = "mediator1")
dop <- RMediation::ci(fit, type = "dop")
mc <- RMediation::ci(fit, type = "MC", n.mc = 1e5)
delta <- suppressWarnings(confint(fit, parm = "effects"))["nie", ]
rbind(dop = dop$CI, monte_carlo = mc$CI, delta = unname(delta))
```

The indirect effect is 0.325. The exact-distribution interval is 0.172
to 0.488, the Monte Carlo interval agrees to about 0.001, and medfit’s
delta-method interval is 0.168 to 0.483: symmetric around the estimate,
where the product’s distribution is skewed. Which to report is in [Which
interval should I
use?](https://data-wise.github.io/medfit/articles/guide-intervals.md).

## MBCO from medfit and from RMediation

`mbco()` takes the restricted fit first. The product null `a * b = 0` is
the union of `a = 0` and `b = 0`, and its p-value is the larger of the
two; medfit’s
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
does that in one call.

``` r
model <- "mediator1 ~ a*treatment
outcome ~ b*mediator1 + cp*treatment"
full <- fit_sem(model, mediation_demo)
null_a <- fit_sem(paste0(model, "\na == 0"), mediation_demo)
null_b <- fit_sem(paste0(model, "\nb == 0"), mediation_demo)
p_branch <- c(a = RMediation::mbco(null_a, full)$p_value, b = RMediation::mbco(null_b, full)$p_value)
c(rmediation_max = max(p_branch), medfit = mbco_sem(full, "a", "b")$p.value)
```

Both give 2.79e-05: the `a = 0` branch (chi-square 17.6 on 1 df) is the
weaker one. RMediation’s `mbco()` tests the one restriction that
separates the two fits you give it, so the product null takes two calls.

## Feature table

Status describes RMediation 1.11.1 acting on the medfit object in the
first column.

| Feature | medfit | RMediation | Status |
|----|----|----|----|
| Interval for the NIE of a `MediationData` | [`confint()`](https://rdrr.io/r/stats/confint.html), [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md) | `ci()` | Supported |
| Interval for the NIE of a `SerialMediationData` | [`confint()`](https://rdrr.io/r/stats/confint.html), [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md) | `ci()` | Supported |
| Interval from a `ParallelMediationData` | [`confint()`](https://rdrr.io/r/stats/confint.html), [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md) | no method | Unsupported |
| Interval from an `InteractionMediationData` | [`confint()`](https://rdrr.io/r/stats/confint.html), [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md) | no method | Unsupported |
| Interval from a `SEMFit` directly | [`tidy()`](https://generics.r-lib.org/reference/tidy.html), [`confint()`](https://rdrr.io/r/stats/confint.html) | no method | Unsupported |
| Interval from a `SEMFit` after [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) | `extract_mediation(<SEMFit>)` | `ci()` | Supported |
| MBCO for a restricted and a full `SEMFit` | [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) | `mbco()` | Supported |
| Quantile of a product of two normals | none | `qprodnormal()` | Supported |

“Unsupported” means the call fails today with a message that names the
missing method, not that it never will; check RMediation’s own `NEWS.md`
before relying on a row. medfit’s `ClusterMediationData`,
`TwoLevelMediationData`, `JointMediationData` and the FIML classes are
not in the table: they were not exercised here.

## What RMediation adds, and what it does not

- **Adds:** intervals from the distribution of a product
  (`ci(type = "dop")` and the Monte Carlo variant `type = "MC"`), the
  product-normal distribution functions (`pprodnormal()`,
  `qprodnormal()`), and `mbco()` for two fits.
- **Does not add:** fitting, extraction, effects beyond the product of
  coefficients, or a model class. It reads the properties of
  `MediationData`, `SerialMediationData` and `SEMFit` that medfit’s
  `test-dependents-contract.R` pins.

Back to the [Reference
Card](https://data-wise.github.io/medfit/articles/refcard.md), the
[Cookbook](https://data-wise.github.io/medfit/articles/cookbook.md) or
[the probmed
comparison](https://data-wise.github.io/medfit/articles/probmed-comparison.md).
