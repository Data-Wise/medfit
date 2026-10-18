# Native engine: paths and defined parameters

Write the model as syntax and fit it by maximum likelihood with no other
package. This is the first of five pages on the native engine. Part of
the [Models](https://data-wise.github.io/medfit/articles/models.md)
collection.

|  |  |
|----|----|
| **Structure** | any path model you can write as syntax; this page uses simple mediation |
| **Class returned** | `SEMFit`, then `MediationData` from [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) |
| **Routes** | `fit_sem(syntax, data)`, or `fit_mediation(model = syntax, engine = "native")` |
| **Syntax** | [`?"medfit-syntax"`](https://data-wise.github.io/medfit/reference/medfit-syntax.md) lists every statement |

The five pages: this one (paths and defined parameters), [a latent
mediator](https://data-wise.github.io/medfit/articles/model-native-latent.md),
[constraints and the MBCO
test](https://data-wise.github.io/medfit/articles/model-native-constraints.md),
and [several mediators and
weights](https://data-wise.github.io/medfit/articles/model-native-multi.md),
and [categorical
covariates](https://data-wise.github.io/medfit/articles/model-native-factors.md).

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

Label a path with `name * variable`; `:=` defines a new quantity from
labels and gives it a delta-method standard error.

``` r
syntax <- "
  mediator1 ~ a * treatment + covariate1 + covariate2
  outcome ~ b * mediator1 + cp * treatment + covariate1 + covariate2
  ab := a * b
  total := cp + a * b
"
fit <- fit_sem(syntax, mediation_demo)
fit
```

    SEMFit (native maximum likelihood)
    ==================================

      Observations:  400
      Parameters:    15 free, 0 df
      Information:   observed
      Std. errors:   model-based
      Converged:     Yes

    Defined parameters:
      ab              0.3328  (SE 0.0642)
      total           0.5386  (SE 0.1187)

    Use summary() for the parameter table and diagnostics.

[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
returns a `SEMFit`. Read the defined parameters straight from it:

``` r
fit@defined
```

       name       expr       est         se
    1    ab      a * b 0.3327695 0.06415544
    2 total cp + a * b 0.5385678 0.11873128

`summary(fit)` prints the full parameter table and the optimizer
diagnostics.

## Get the usual objects

[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
turns the fit into a `MediationData`, so
[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) and the
bootstrap work as on any other page:

``` r
x <- extract_mediation(fit, treatment = "treatment", mediator = "mediator1",
                       outcome = "outcome")
class(x)[1]
```

    [1] "medfit::MediationData"

``` r
tidy(x, type = "effects", conf_int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std_error conf_low conf_high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.333    0.0642  0.207       0.459
    2 nde      0.206    0.109  -0.00801     0.420
    3 te       0.539    0.119   0.306       0.771

For one mediator,
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
does both steps:

``` r
x2 <- fit_mediation(model = syntax, data = mediation_demo,
                    treatment = "treatment", mediator = "mediator1",
                    engine = "native")
nie(x2)
```

    Natural Indirect Effect (NIE): 0.3328

## Intercepts

Writing any intercept (`y ~ 1`, or `1` as a term, `y ~ 1 + x`) turns the
mean structure on and frees an intercept for every observed variable you
did not mention, as lavaan does. The paths, variances and their standard
errors are then the same as without it; the fit also reports the
intercepts and the mean of each exogenous variable.

``` r
paths <- "mediator1 ~ a * treatment\noutcome ~ b * mediator1 + cp * treatment"
free <- fit_sem(paste0(paths, "\noutcome ~ 1"), mediation_demo)
tidy(free)[tidy(free)$op == "~1", c("term", "estimate", "std_error")]
```

    # A tibble: 3 × 3
      term        estimate std_error
      <chr>          <dbl>     <dbl>
    1 outcome~1      0.231    0.0774
    2 mediator1~1    0.155    0.0763
    3 treatment~1    0.502    0.0250

An intercept you fix or constrain is a restriction, so it can change the
other estimates. Fixing the outcome intercept at 0 costs one degree of
freedom, and [`anova()`](https://rdrr.io/r/stats/anova.html) compares
the two fits:

``` r
zero <- fit_sem(paste0(paths, "\noutcome ~ 0*1"), mediation_demo)
c(free = free@theta[["cp"]], fixed_at_zero = zero@theta[["cp"]])
```

             free fixed_at_zero
       0.04057665    0.26236776 

``` r
anova(free, zero)
```

    Likelihood-ratio (chi-square difference) test for SEMFit models

    n = 400; Chisq is n times the minimized discrepancy

         Df  Chisq Chisq diff Df diff Pr(>Chisq)
    free  0 0.0000
    zero  1 8.8141     8.8141       1   0.002989 **
    ---
    Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1

Equating two intercepts works the same way (`i1 == i2` with labels `i1`
and `i2`). `meanstructure = TRUE` turns the mean structure on without
writing any intercept, and `meanstructure = FALSE` fits covariances
only. A latent variable’s mean is fixed at 0, and a free latent
intercept stops with “latent means are planned for a later release”.
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
reads the paths exactly as before; add a product term and it returns the
four-way decomposition ([below](#product-terms)).

## Compared with the `glm` engine

The two engines agree on the estimates and differ slightly in the
standard errors, because the native engine uses maximum-likelihood (not
least-squares) variances:

``` r
glm_fit <- fit_mediation(
  outcome ~ treatment + mediator1 + covariate1 + covariate2,
  mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo, treatment = "treatment", mediator = "mediator1"
)
rbind(native = tidy(x, type = "effects")$std_error,
      glm = tidy(glm_fit, type = "effects")$std_error)
```

                 [,1]      [,2]      [,3]
    native 0.06415544 0.1090891 0.1187313
    glm    0.06449767 0.1097774 0.1194466

## Product terms

`x:m` (the colon, no spaces) on the right side of a regression is the
product of two observed variables, as in lavaan. The engine builds the
column `x * m` from `data` after listwise deletion and treats it as an
observed exogenous variable, so the likelihood, the constraints and the
mean structure are the same as for any other regressor. `x:m` and `m:x`
are one term, stored under the canonical name (the two names sorted in
the C locale, `m:x`), and a label (`b*x:m`) names the coefficient. A
product turns the mean structure on. Writing the treatment-by-mediator
product in the outcome equation makes
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
return the four-way decomposition; the [interaction
page](https://data-wise.github.io/medfit/articles/model-interaction.html#the-native-engine)
runs a worked example, including why centering the mediator matters.

``` r
four <- fit_sem(
  "mediator1 ~ treatment
   outcome_int ~ treatment + mediator1 + mediator1:treatment",
  mediation_demo, se_type = "sandwich"
)
```

    Warning: the model test is not valid for this model: the product
    'mediator1:treatment' has an endogenous factor ('mediator1'). `glance()` and
    `summary()` report the chi-square, df and p-value as NA, and `anova()` and
    `mbco_sem()` refuse. The coefficients equal equation-wise OLS, and the sandwich
    standard errors (observed information) are unaffected.

``` r
tidy(four)[1:4, c("term", "estimate", "std_error")]
```

    # A tibble: 4 × 3
      term                            estimate std_error
      <chr>                              <dbl>     <dbl>
    1 mediator1~treatment               0.456     0.108
    2 outcome_int~treatment             0.0405    0.119
    3 outcome_int~mediator1             0.713     0.0699
    4 outcome_int~mediator1:treatment   0.500     0.102 

The warning above says the global model test is not available for this
model, because the product contains the mediator, which is a regression
target (details below). The coefficients and the sandwich standard
errors are unaffected.

A product is fitted only in the class below. Anything else stops, naming
the feature, with a message that says it is not yet supported with
products; the same model works without the product. Each row gives the
limit and the start of its message.

| Limit | Message (starts with, or contains) |
|:---|:---|
| A space around `:` | “a product ‘:’ needs a variable name on each side, written without spaces (x:m)” |
| `x:x`, `x:m:w` | “of a variable with itself is not supported”, “a three-way or higher product” |
| A product as a left side (`x:m ~ y`, `x:m ~~ y`) | “cannot be a left side” |
| A product in `=~` or in a constraint expression | “is only valid on the right side of a regression” |
| A latent variable in a product | “products with latent variables are not supported in this version” |
| One product twice in an equation | “are the same product (canonical name” |
| A factor that is the target or downstream of it (`y ~ x + x:y`) | “(rule 8: no outcome-derived regressors)” |
| A loop of regressions | “The model is not recursive” |
| A residual covariance between outcomes | “A product model cannot have a residual covariance (rule 9)” |
| A label shared by two rows | “is used on more than one parameter” |
| A fixed coefficient | “has a fixed coefficient (rule 9)” |
| An inline bound on a coefficient or intercept (`lower(0)*x`) | “has a bound (rule 9” |
| `==`, `<` or `>` naming a coefficient label (`a < 1` too) | “names the coefficient label” |
| A fixed, shared or constrained intercept | “(rule 9, intercept clause” |
| `meanstructure = FALSE` | “`meanstructure = FALSE`, but the model has a product term” |
| A data column `m:x` that is not `x * m` | “is not the product of” |
| A product input that is not numeric, factor, character or logical (a date) | “needs numeric variables” |
| `information = "expected"`, endogenous factor | “is not available for a model with a product of an endogenous variable” |
| [`anova()`](https://rdrr.io/r/stats/anova.html) or [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md), endogenous factor | “is not available for” … “a model with a product term” |
| [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) with another product on the treatment or mediator | “the native extraction does not support the product” |

Two more facts are not errors. The covariance that completion would add
between two pure outcomes is fixed at 0 in a product model, with one
note; and
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
warns once when a product is fitted without `se_type = "sandwich"`,
which is the standard-error choice because a product is not normal.
`fixed_x = TRUE` fixes the product columns with the other exogenous
variables.

The global chi-square is not valid when a factor of the product is
itself a regression target (the model treats the product as exogenous
although it is a function of that variable), or when the exogenous
(co)variance block is restricted.
[`glance()`](https://generics.r-lib.org/reference/glance.html) then
reports chi-square, df and p-value as `NA` with a note, and
[`anova()`](https://rdrr.io/r/stats/anova.html) and
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
refuse. A product of exogenous variables with a free block keeps the
ordinary test. [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.html#products-and-observed-information)
gives the reason.

## Limits

- **Observed means only.** A free latent mean or intercept stops with
  “latent means are planned for a later release”; the latent variable’s
  mean is fixed at 0 (see [Intercepts](#intercepts)).
- **Constraints on an intercept** are checked up to a data mean about
  1,000 times the standard deviation; beyond that the fit may stop with
  “no start converged”. Constraints that leave every intercept free have
  no such limit.
- **A label must be defined** before `:=` can use it; an unknown label
  stops with “unknown parameter label”.
- **Exogenous variables get free variances and covariances**, as lavaan
  does with `fixed.x = FALSE`, so they appear in the parameter table.
  `fixed_x = TRUE` (or a vector of names) fixes the selected ones at the
  sample moments, as `fixed.x = TRUE` does: the structural estimates,
  their standard errors and the degrees of freedom do not change, the
  parameter count falls, and
  [`logLik()`](https://rdrr.io/r/stats/logLik.html), AIC and BIC become
  conditional on the fixed variables, so fits with different fixed sets
  cannot be compared.
- **AIC and BIC across product and no-product fits are not comparable.**
  The product column is an extra observed variable in the joint
  likelihood, so a fit with `x:m` and the same model without it describe
  different data (on `mediation_demo`, the same outcome gives AIC 3934.7
  with the product and 2994.1 without). `AIC(fit_a, fit_b)`,
  `BIC(fit_a, fit_b)`, [`anova()`](https://rdrr.io/r/stats/anova.html)
  and
  [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
  refuse such a pair, naming the observed variables that differ.
- **Products** are limited to two observed variables inside the class in
  the table above; latent products, `x:x` and three-way products stop
  with the messages listed there.
- **Factor covariates** (a factor, character or logical column on a
  regression’s right side) become 0/1 dummies named `g_b`, `g_c`
  (reference: the first level), as
  [`lm()`](https://rdrr.io/r/stats/lm.html) builds them. A label on the
  factor (`b*g`) stops; label one dummy (`b*g_b`). A factor as an
  outcome, a mediator or a four-way treatment is not supported, and
  `g:m` expands to one product per dummy (see
  [`?"medfit-syntax"`](https://data-wise.github.io/medfit/reference/medfit-syntax.md)).
- [`summary()`](https://rdrr.io/r/base/summary.html) reports
  diagnostics, including an improper solution and any active bound or
  constraint; read them before trusting a fit.

## Stability

The exported signatures of
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
and
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md),
the `SEMFit` properties and the model syntax in
[`?"medfit-syntax"`](https://data-wise.github.io/medfit/reference/medfit-syntax.md)
change only through a deprecation. New syntax and new properties can be
added: a name, a table row or a property that exists today keeps its
meaning. This matters for the features listed under Limits (a
categorical mediator or outcome, for example): they will arrive as
additions, not as a rename of `g_b`-style dummy names or of the `m:x`
product name. A test (`test-api-freeze.R`) pins the current names.
Numerical fixes are not breaking changes.

## Related

[Cookbook recipe
11](https://data-wise.github.io/medfit/articles/cookbook.html#a-latent-mediator-native-engine)
\| [Cookbook recipe
19](https://data-wise.github.io/medfit/articles/cookbook.html#observed-intercepts-and-means)
\| [Cookbook recipe
20](https://data-wise.github.io/medfit/articles/cookbook.html#four-way-decomposition-from-a-native-fit)
\| [Native engine
book](https://data-wise.github.io/medfit/articles/native-book-1-mean-structure.md)
\| [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md) \|
[`?"medfit-syntax"`](https://data-wise.github.io/medfit/reference/medfit-syntax.md)
