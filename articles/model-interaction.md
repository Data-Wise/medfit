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
| **Routes** | [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md) (glm or `regmedint` engine), [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) on `lm`/`glm` or lavaan |
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

## Limits

- Only products written with `:` or `*` in the **outcome** model are
  recognized. A product precomputed as a data column cannot be seen and
  would be ignored, so write it in the formula.
- Non-Gaussian outcomes or mediators error; see [glm
  families](https://data-wise.github.io/medfit/articles/model-glm-families.md)
  for what is supported there.
- The native engine does not support the four-way decomposition (it
  estimates no mediator intercept).

## Related

[Simple
mediation](https://data-wise.github.io/medfit/articles/model-simple.md)
\| [Cookbook recipe
7](https://data-wise.github.io/medfit/articles/cookbook.html#treatment-by-mediator-interaction)
\| [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md)
\| [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md)
