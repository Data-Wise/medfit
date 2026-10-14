# Treatment-by-mediator interaction

When the effect of the mediator depends on the treatment, the outcome
model carries a `treatment * mediator` term and the effect splits into
four parts. Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection.

|  |  |
|----|----|
| **Structure** | X to M to Y, with an X by M term in the outcome model |
| **Class returned** | `InteractionMediationData` |
| **Routes** | [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md) (glm or `regmedint` engine), [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) on `lm`/`glm`, lavaan or a native [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md) fit |
| **Needs** | Gaussian identity-link models and a reference mediator level `m_star` |

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

Write the product in the outcome formula; medfit recognizes it and
returns the four-way class. `m_star` is the mediator level at which the
controlled direct effect is evaluated (default 0).

``` r
fit <- fit_mediation(
  outcome_int ~ treatment * mediator1 + covariate1 + covariate2,
  mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo, treatment = "treatment", mediator = "mediator1",
  m_star = 0
)
class(fit)[1]
```

    [1] "medfit::InteractionMediationData"

``` r
decompose(fit)
```

           cde    int_ref    int_med        pie        nde        nie      total
    0.21521278 0.04353909 0.27709549 0.34001758 0.25875187 0.61711307 0.87586495 

## The four parts

| Part | Name | Reads as |
|----|----|----|
| `cde` | controlled direct effect | effect of the treatment with the mediator held at `m_star` |
| `int_ref` | reference interaction | interaction due to the mediator’s level without the treatment |
| `int_med` | mediated interaction | interaction that operates through the treatment’s effect on the mediator |
| `pie` | pure indirect effect | effect through the mediator with no interaction |

``` r
parts <- decompose(fit)
c(nde = unname(parts["cde"] + parts["int_ref"]),
  nie = unname(parts["int_med"] + parts["pie"]),
  total = unname(sum(parts[c("cde", "int_ref", "int_med", "pie")])))
```

          nde       nie     total
    0.2587519 0.6171131 0.8758649 

The natural direct effect is `cde + int_ref`, the natural indirect
effect is `int_med + pie`, and the four add to the total effect.

## Same result from the closed-form engine

`engine = "regmedint"` computes the same quantities from the closed-form
regression formulas, with analytical standard errors (needs the
suggested `regmedint` package).

``` r
fit_rm <- fit_mediation(
  outcome_int ~ treatment * mediator1 + covariate1 + covariate2,
  mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo, treatment = "treatment", mediator = "mediator1",
  engine = "regmedint"
)
all.equal(decompose(fit_rm), decompose(fit))
```

    [1] TRUE

## The native engine

[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
reads the product as `treatment:mediator1` (the colon, no spaces) and
fits it by maximum likelihood with no other package. A product turns the
mean structure on, because the four-way parts need the mediator
intercept. The sandwich covariance is the standard-error choice for a
product, and the fit warns once when the global model test is not
available (here the product contains the mediator, which is itself a
regression target).

``` r
syntax <- "
  mediator1 ~ treatment + covariate1 + covariate2
  outcome_int ~ treatment + mediator1 + treatment:mediator1 + covariate1 + covariate2
"
sem <- fit_sem(syntax, mediation_demo, se_type = "sandwich")
```

    Warning: the model test is not valid for this model: the product
    'mediator1:treatment' has an endogenous factor ('mediator1'). `glance()` and
    `summary()` report the chi-square, df and p-value as NA, and `anova()` and
    `mbco_sem()` refuse. The coefficients equal equation-wise OLS, and the sandwich
    standard errors (observed information) are unaffected.

``` r
x_sem <- extract_mediation(sem, treatment = "treatment", mediator = "mediator1",
                           outcome = "outcome_int")
class(x_sem)[1]
```

    [1] "medfit::InteractionMediationData"

``` r
all.equal(decompose(x_sem), decompose(fit))
```

    [1] TRUE

The parts equal the `lm`/`glm` route, since each coefficient equals its
equation-wise least-squares estimate. `m:x` is the stored name whichever
order you write the product in (`treatment:mediator1` and
`mediator1:treatment` are one term), so `tidy(sem)` shows
`outcome_int~mediator1:treatment`.

**Centering matters.** The reference level `m_star = 0` and the mediator
mean at `treatment = 0` depend on where the mediator is centered. The
natural direct and indirect effects and the total do not; the split of
the direct effect between CDE and INTref does. Center the mediator at
the mean (or another meaningful value) before you read CDE:

``` r
d <- mediation_demo
d$m_c <- d$mediator1 - mean(d$mediator1)
sem_c <- suppressWarnings(fit_sem(
  "m_c ~ treatment + covariate1 + covariate2
   outcome_int ~ treatment + m_c + treatment:m_c + covariate1 + covariate2",
  d, se_type = "sandwich"
))
x_c <- extract_mediation(sem_c, treatment = "treatment", mediator = "m_c",
                         outcome = "outcome_int")
rbind(raw = decompose(x_sem), centered = decompose(x_c))
```

                   cde     int_ref   int_med       pie       nde       nie
    raw      0.2152128  0.04353909 0.2770955 0.3400176 0.2587519 0.6171131
    centered 0.3979924 -0.13924048 0.2770955 0.3400176 0.2587519 0.6171131
                 total
    raw      0.8758649
    centered 0.8758649

CDE and INTref move with the centering; NDE, NIE and the total stay put.

The chi-square, df and p-value are `NA` for this fit,
[`anova()`](https://rdrr.io/r/stats/anova.html) and
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
refuse, and `information = "expected"` is refused, because the product
contains a regression target;
[`logLik()`](https://rdrr.io/r/stats/logLik.html), AIC and BIC stay
defined, but those of a fit with the product are not comparable with
those of a fit without it, so `AIC(fit_a, fit_b)` and
[`BIC()`](https://rdrr.io/r/stats/AIC.html) refuse such a pair. The
[supported class and each
limit](https://data-wise.github.io/medfit/articles/model-native.html#product-terms)
lists what else a product model cannot contain, with the message for
each.

``` r
glance(sem)[c("chisq", "df", "p_value")]
```

    # A tibble: 1 × 3
      chisq    df p_value
      <dbl> <dbl>   <dbl>
    1    NA    NA      NA

``` r
tryCatch(anova(sem, sem), error = function(e) conditionMessage(e))
```

    [1] "anova() is not available for 'sem', a model with a product term: the product 'mediator1:treatment' has an endogenous factor ('mediator1'). The model test and a likelihood-ratio contrast against another fit are not chi-square there. The coefficients and the sandwich standard errors (`se_type = \"sandwich\"`, observed information) are unaffected."

## Limits

- Only products written with `:` or `*` in the **outcome** model are
  recognized. A product precomputed as a data column cannot be seen and
  would be ignored, so write it in the formula.
- Non-Gaussian outcomes or mediators error; see [glm
  families](https://data-wise.github.io/medfit/articles/model-glm-families.md)
  for what is supported there.
- The native route reads a product written in the model syntax
  (`treatment:mediator1`), not a precomputed data column, and only
  inside the [supported
  class](https://data-wise.github.io/medfit/articles/model-native.html#product-terms):
  recursive, no residual covariance between outcomes, free coefficients
  and intercepts, none shared. Without the product,
  `decomposition = "four_way"` is refused with a message that says to
  add it.

## Related

[Simple
mediation](https://data-wise.github.io/medfit/articles/model-simple.md)
\| [Cookbook recipe
7](https://data-wise.github.io/medfit/articles/cookbook.html#treatment-by-mediator-interaction)
\| [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md)
\| [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md)
