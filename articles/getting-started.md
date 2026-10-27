# Getting Started with medfit

> **Note**
>
> This site documents medfit 0.15.0. CRAN has 0.3.2, which lacks
> `mediation_demo` and the native, joint and cluster functions; install
> from GitHub or r-universe (see the [home
> page](https://data-wise.github.io/medfit/#install)).

**Four steps.** By the end you will have fitted a mediation model, read
its effects, and added an interval.

1.  Fit: [`med()`](https://data-wise.github.io/medfit/reference/med.md)
2.  Read:
    [`quick()`](https://data-wise.github.io/medfit/reference/quick.md),
    then [`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
    [`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
    [`te()`](https://data-wise.github.io/medfit/reference/te.md),
    [`pm()`](https://data-wise.github.io/medfit/reference/pm.md)
3.  Tabulate: [`tidy()`](https://generics.r-lib.org/reference/tidy.html)
4.  Add an interval: `boot = TRUE`

Then pick your model on the
[Models](https://data-wise.github.io/medfit/articles/models.md) page.

## Step 1. Fit

`mediation_demo` is a simulated dataset that ships with the package. Its
two covariates affect both the mediator and the outcome, so every
example adjusts for them (see
[`?mediation_demo`](https://data-wise.github.io/medfit/reference/mediation_demo.md)).

``` r
library(medfit)
```


    Attaching package: 'medfit'

    The following object is masked from 'package:stats':

        decompose

``` r
data(mediation_demo)

result <- med(
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1",
  outcome = "outcome",
  covariates = c("covariate1", "covariate2")
)
```

## Step 2. Read

One line first:

``` r
quick(result)
```

    NIE = 0.333  | NDE = 0.206 | PM = 61.8 %

| Letters | Meaning |
|----|----|
| **NIE** | Indirect effect: through the mediator (`a * b`) |
| **NDE** | Direct effect: treatment to outcome with the mediator held fixed (`c'`) |
| **PM** | Proportion mediated: the share of the total effect that goes through the mediator |

Then each piece on its own:

``` r
nie(result)   # indirect effect
```

    Natural Indirect Effect (NIE): 0.3328

``` r
nde(result)   # direct effect
```

    Natural Direct Effect (NDE): 0.2058

``` r
te(result)    # total effect (indirect + direct)
```

    Total Effect (TE): 0.5386

``` r
pm(result)    # proportion mediated
```

    Proportion Mediated (PM): 0.6179

``` r
paths(result) # a, b and c'
```

            a         b   c_prime
    0.5826425 0.5711384 0.2057983 

## Step 3. Tabulate

[`tidy()`](https://generics.r-lib.org/reference/tidy.html) gives a table
with standard errors;
[`glance()`](https://generics.r-lib.org/reference/glance.html) gives one
row per model.

``` r
library(generics)
```


    Attaching package: 'generics'

    The following objects are masked from 'package:base':

        as.difftime, as.factor, as.ordered, intersect, is.element, setdiff,
        setequal, union

``` r
tidy(result)
```

    # A tibble: 6 × 3
      term    estimate std_error
      <chr>      <dbl>     <dbl>
    1 a          0.583    0.0989
    2 b          0.571    0.0535
    3 c_prime    0.206    0.110
    4 nie        0.333    0.0645
    5 nde        0.206    0.110
    6 te         0.539    0.119 

``` r
glance(result)
```

    # A tibble: 1 × 6
        nie   nde    te    pm  nobs converged
      <dbl> <dbl> <dbl> <dbl> <int> <lgl>
    1 0.333 0.206 0.539 0.618   400 TRUE     

Add confidence intervals, and ask for only the paths or only the
effects:

``` r
tidy(result, type = "effects", conf_int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std_error conf_low conf_high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.333    0.0645  0.206       0.459
    2 nde      0.206    0.110  -0.00936     0.421
    3 te       0.539    0.119   0.304       0.773

The base R generics work too:
[`coef()`](https://rdrr.io/r/stats/coef.html),
[`vcov()`](https://rdrr.io/r/stats/vcov.html),
[`confint()`](https://rdrr.io/r/stats/confint.html) and
[`nobs()`](https://rdrr.io/r/stats/nobs.html).
`confint(result, parm = "effects")` gives delta-method intervals for the
effects.

## Step 4. Add an interval

Set `boot = TRUE`. The default is the parametric bootstrap, which is
fast and assumes the estimates are approximately normal.

``` r
result_boot <- med(
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1",
  outcome = "outcome",
  covariates = c("covariate1", "covariate2"),
  boot = TRUE,
  n_boot = 1000,
  seed = 42
)

quick(result_boot)
```

    NIE = 0.333  [0.21, 0.464] | NDE = 0.206 | PM = 61.8 %

The nonparametric and plugin methods, and a custom statistic, are in
[Bootstrap
Inference](https://data-wise.github.io/medfit/articles/bootstrap.md).

## Already have fitted models?

[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
turns `lm`, `glm`, `lmer` and lavaan fits into the same objects, so
every function above still works:

``` r
fit_m <- lm(mediator1 ~ treatment + covariate1 + covariate2, data = mediation_demo)
fit_y <- lm(outcome ~ treatment + mediator1 + covariate1 + covariate2,
            data = mediation_demo)

med_data <- extract_mediation(
  fit_m,
  model_y = fit_y,
  treatment = "treatment",
  mediator = "mediator1"
)

nie(med_data)
```

    Natural Indirect Effect (NIE): 0.3328

## Want more control?

[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
takes the two formulas and an engine, and returns the same objects. Its
paths are slots on the result:

``` r
med_data <- fit_mediation(
  formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
  formula_m = mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1"
)

med_data@a_path   # treatment to mediator
```

    [1] 0.5826425

``` r
med_data@b_path   # mediator to outcome
```

    [1] 0.5711384

``` r
med_data@c_prime  # treatment to outcome, the direct path
```

    [1] 0.2057983

The engine is `"glm"` by default. Others:

| Engine | Use it when | Page |
|----|----|----|
| `"glm"` | the default; continuous, binary or count variables | [Simple](https://data-wise.github.io/medfit/articles/model-simple.md), [glm families](https://data-wise.github.io/medfit/articles/model-glm-families.md) |
| `"regmedint"` | you want the closed-form regression estimator | [regmedint](https://data-wise.github.io/medfit/articles/model-regmedint.md) |
| `"lmer"` | the treatment is assigned to whole clusters | [Cluster-randomized trials](https://data-wise.github.io/medfit/articles/model-cluster.md) |
| `"native"` | a latent mediator, constraints, or a model written as syntax | [Native engine](https://data-wise.github.io/medfit/articles/model-native.md) |

## Where next

Pick the row that matches your data.

| I have | Read |
|----|----|
| A binary or count variable | [Binary and non-normal variables](https://data-wise.github.io/medfit/articles/model-glm-families.md) |
| Inverse-probability weights | [Weights and robust SEs](https://data-wise.github.io/medfit/articles/model-weights.md) |
| A treatment-by-mediator interaction | [Treatment-by-mediator interaction](https://data-wise.github.io/medfit/articles/model-interaction.md) |
| Two mediators in a chain | [Serial mediation](https://data-wise.github.io/medfit/articles/model-serial.md) |
| Two mediators side by side | [Parallel mediation](https://data-wise.github.io/medfit/articles/model-parallel.md) |
| Several mediators with products | [Joint mediation](https://data-wise.github.io/medfit/articles/model-joint.md) |
| A treatment given to whole clusters | [Cluster-randomized trials](https://data-wise.github.io/medfit/articles/model-cluster.md) |
| A `lavaan` fit | [lavaan models](https://data-wise.github.io/medfit/articles/model-lavaan.md) |
| Model syntax, a latent mediator, constraints, intercepts or a product term | [Native engine](https://data-wise.github.io/medfit/articles/model-native.md) |
| Something else, or not sure | [Models](https://data-wise.github.io/medfit/articles/models.md), the full list |
| An error or warning | [Troubleshooting](https://data-wise.github.io/medfit/articles/guide-troubleshooting.md) |
| Which interval to report | [Which interval should I use?](https://data-wise.github.io/medfit/articles/guide-intervals.md) |
| A term or symbol you do not know | [Glossary and symbols](https://data-wise.github.io/medfit/articles/guide-glossary.md) |

For quick lookups: the [Reference
Card](https://data-wise.github.io/medfit/articles/refcard.md) has every
function on one page, and the
[Cookbook](https://data-wise.github.io/medfit/articles/cookbook.md) has
twenty-one short recipes. To understand the classes, read the
[Introduction](https://data-wise.github.io/medfit/articles/introduction.md);
for the math behind every effect and standard error, [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md); for
extraction from fitted models, [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md).

See `NEWS.md` for the latest updates.
