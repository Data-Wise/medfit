# Binary and non-normal outcomes or mediators

The default engine fits each model with
[`glm()`](https://rdrr.io/r/stats/glm.html), so the outcome and the
mediator can each take a family. Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection.

|  |  |
|----|----|
| **Structure** | X to M to Y, one model per variable |
| **Class returned** | `MediationData` |
| **Set with** | `family_y =` and `family_m =` in [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md), or fit the [`glm()`](https://rdrr.io/r/stats/glm.html) yourself and extract |
| **Scale** | `b` and `c'` are on the outcome’s link scale; `a` is on the mediator’s |

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
d <- mediation_demo
d$outcome_bin <- as.integer(d$outcome > median(d$outcome))
d$mediator_bin <- as.integer(d$mediator1 > median(d$mediator1))
```

> **Read this first**
>
> With a non-identity link, `b` and `c'` are on the link scale, so the
> product `a * b` is **not** a natural indirect effect on the outcome
> scale. medfit reports the product; the interpretation is yours to
> defend. See [Methods and
> Formulas](https://data-wise.github.io/medfit/articles/methods.md).

## Binary outcome

``` r
fit_y <- fit_mediation(
  outcome_bin ~ treatment + mediator1 + covariate1 + covariate2,
  mediator1 ~ treatment + covariate1 + covariate2,
  data = d, treatment = "treatment", mediator = "mediator1",
  family_y = binomial()
)
paths(fit_y)
```

            a         b   c_prime
    0.5826425 0.8632919 0.1271924 

Here `b` and `c'` are log odds ratios and `a` is a change in the
mediator.

## Binary mediator

``` r
fit_m <- fit_mediation(
  outcome ~ treatment + mediator_bin + covariate1 + covariate2,
  mediator_bin ~ treatment + covariate1 + covariate2,
  data = d, treatment = "treatment", mediator = "mediator_bin",
  family_m = binomial()
)
paths(fit_m)
```

            a         b   c_prime
    1.0525050 0.8880579 0.3334008 

Now `a` is a log odds ratio and `b` is a change in the outcome per unit
of the mediator.

## Other families

Any [`glm()`](https://rdrr.io/r/stats/glm.html) family works the same
way, for example a count outcome:

``` r
set.seed(1)
d$count <- rpois(nrow(d), exp(0.2 + 0.2 * d$mediator1))
fit_c <- fit_mediation(
  count ~ treatment + mediator1 + covariate1,
  mediator1 ~ treatment + covariate1,
  data = d, treatment = "treatment", mediator = "mediator1",
  family_y = poisson()
)
class(fit_c)[1]
```

    [1] "medfit::MediationData"

## Joint significance test for the indirect effect

With a binary or count outcome there is no outcome-scale indirect effect
here, but you can still test whether the mediated path exists. For a
recursive model with no correlated errors the likelihood factors by
equation, so the test reduces to the joint significance test: test
`a = 0` in the mediator model and `b = 0` in the outcome model, and take
the larger p-value. The null is “a = 0 or b = 0”, so the test is
conservative, like
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
on the native engine.

``` r
joint_test <- function(fit_a, term_a, fit_b, term_b) {
  one <- function(fit, term) {
    known <- fit$family$family %in% c("binomial", "poisson")
    col <- if (known) "Pr(>Chi)" else "Pr(>F)"
    drop1(fit, scope = term, test = if (known) "LRT" else "F")[term, col]
  }
  p <- c(a = one(fit_a, term_a), b = one(fit_b, term_b))
  c(p, joint = max(p))
}
fit_a <- glm(mediator1 ~ treatment + covariate1 + covariate2, data = d)
fit_b <- glm(outcome_bin ~ treatment + mediator1 + covariate1 + covariate2,
             data = d, family = binomial())
joint_test(fit_a, "treatment", fit_b, "mediator1")
```

               a            b        joint
    8.096703e-09 2.024938e-12 8.096703e-09 

The test for each path depends on the family:

- **Known dispersion** (binomial, Poisson): a likelihood-ratio test, as
  above for the binary outcome.
- **Estimated dispersion** (Gaussian, Gamma, and every `quasi*` family):
  an F test. These families have no likelihood with the dispersion
  known, so a likelihood-ratio chi-square would be too liberal. The
  helper switches on the family; the mediator above is Gaussian and gets
  the F test.

The result is on the link scale, like the paths; it says that the
mediated path is detectable, not how large the effect is on the outcome
scale. A function that also reports outcome-scale effects is planned.

## Limits

- The four-way and joint decompositions need Gaussian identity-link
  models and stop with an informative error otherwise.
- Intervals for the product still come from the delta method or a
  bootstrap; see [Bootstrap
  Inference](https://data-wise.github.io/medfit/articles/bootstrap.md).
- Fitted [`glm()`](https://rdrr.io/r/stats/glm.html) pairs can be
  extracted instead of fitted here:
  `extract_mediation(fit_m, model_y = fit_y, ...)`.

## Related

[Simple
mediation](https://data-wise.github.io/medfit/articles/model-simple.md)
\| [Cookbook recipe
3](https://data-wise.github.io/medfit/articles/cookbook.html#binary-outcome)
\| [Cookbook recipe
13](https://data-wise.github.io/medfit/articles/cookbook.html#joint-significance-for-a-binary-or-count-outcome)
\| [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md)
