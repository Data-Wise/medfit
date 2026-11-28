# The sem engine: paths and defined parameters

Write the model as syntax and fit it by maximum likelihood with no other
package. This is the first of five pages on the sem engine. Part of the
[Models](https://data-wise.github.io/medfit/dev/articles/models.md)
collection.

|  |  |
|----|----|
| **Structure** | any path model you can write as syntax; this page uses simple mediation |
| **Class returned** | `SEMFit`, then `MediationData` from [`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md) |
| **Routes** | `fit_sem(syntax, data)`, or `fit_mediation(model = syntax, engine = "sem")` |
| **Syntax** | [`?"medfit-syntax"`](https://data-wise.github.io/medfit/dev/reference/medfit-syntax.md) lists every statement |

The five pages: this one (paths and defined parameters), [a latent
mediator](https://data-wise.github.io/medfit/dev/articles/model-sem-latent.md),
[constraints and the MBCO
test](https://data-wise.github.io/medfit/dev/articles/model-sem-constraints.md),
and [several mediators and
weights](https://data-wise.github.io/medfit/dev/articles/model-sem-multi.md),
and [categorical
covariates](https://data-wise.github.io/medfit/dev/articles/model-sem-factors.md).

These examples use the default listwise path. For the separate bounded
FIML opt-in (0.16.0 and 0.17.0) and its narrower support, see the [sem
engine
guide](https://data-wise.github.io/medfit/dev/articles/sem-guide.html#bounded-fiml).

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
      Parameters:    11 free, 0 df
      Information:   observed
      Std. errors:   model-based
      Converged:     Yes
      logLik is conditional on: treatment, covariate1, covariate2

    Defined parameters:
      ab              0.3328  (SE 0.0642)
      total           0.5386  (SE 0.1187)

    Use summary() for the parameter table and diagnostics.

[`fit_sem()`](https://data-wise.github.io/medfit/dev/reference/fit_sem.md)
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

[`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md)
turns the fit into a `MediationData`, so
[`nie()`](https://data-wise.github.io/medfit/dev/reference/nie.md),
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
[`fit_mediation()`](https://data-wise.github.io/medfit/dev/reference/fit_mediation.md)
does both steps:

``` r
x2 <- fit_mediation(model = syntax, data = mediation_demo,
                    treatment = "treatment", mediator = "mediator1",
                    engine = "sem")
nie(x2)
```

    Natural Indirect Effect (NIE): 0.3328

## Intercepts

Since 0.15.0 every native fit has a mean structure by default
(`meanstructure` left unset is `TRUE`), with a free intercept for every
observed variable you did not mention, as lavaan does with
`meanstructure = TRUE`. You write an intercept (`y ~ 1`, or `1` as a
term, `y ~ 1 + x`) to restrict it or to give it a label. The paths,
variances and their standard errors are the same as without the mean
structure; the fit also reports the intercepts and the mean of each
exogenous variable (fixed with the other exogenous moments by default,
so those rows have no standard error).

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
    3 treatment~1    0.502   NA     

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
and `i2`). `meanstructure = NULL` fits a mean structure only when the
model writes an intercept or a product (the 0.14.x rule), and
`meanstructure = FALSE` fits covariances only. A latent variable’s mean
is fixed at 0, and a free latent intercept stops with “latent means are
planned for a later release”.
[`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md)
reads the paths exactly as before; add a product term and it returns the
four-way decomposition ([below](#product-terms)).

## Compared with the `glm` engine

The two engines agree on the estimates and differ slightly in the
standard errors, because the sem engine uses maximum-likelihood (not
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
product needs the mean structure, which is on by default. Writing the
treatment-by-mediator product in the outcome equation makes
[`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md)
return the four-way decomposition; the [interaction
page](https://data-wise.github.io/medfit/dev/articles/model-interaction.html#the-native-engine)
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
| [`anova()`](https://rdrr.io/r/stats/anova.html) or [`mbco_sem()`](https://data-wise.github.io/medfit/dev/reference/mbco_sem.md), endogenous factor | “is not available for” … “a model with a product term” |
| [`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md) with another product on the treatment or mediator | “the native extraction does not support the product” |
| [`AIC()`](https://rdrr.io/r/stats/AIC.html) or [`BIC()`](https://rdrr.io/r/stats/AIC.html) on fits with different observed variables | “different observed variables” |
| A product of two categorical columns (`g:h`) | “both sides are categorical columns” |
| `fixed_x` naming a column that appears only inside products | “appears only inside products” |
| A product in a modifier (`y ~ a:b*x`) | “malformed modifier” |
| Four-way on a native fit without the treatment-by-mediator product | “needs the treatment-by-mediator product” |
| `extract_mediation(interaction = )` that is not a `:` product | “must be the product written with `:`” |
| `extract_mediation(interaction = )` that is not treatment by mediator | “is not the product of the treatment” |

Each error has one of the classes below and also the class
`medfit_error_product`, so a handler can match the class and a reader
the message. The warning that the model test is not valid has the class
`medfit_warning_product_modeltest`.

| Class | Raised for |
|:---|:---|
| `medfit_error_product_syntax` | spacing, `x:x`, three-way, left side, `=~`, constraint expression |
| `medfit_error_product_latent` | a latent variable in a product |
| `medfit_error_product_duplicate` | one product twice in an equation |
| `medfit_error_product_outcome_regressor` | rule 8 |
| `medfit_error_product_recursive` | a loop of regressions |
| `medfit_error_product_residual_covariance` | residual covariance between outcomes |
| `medfit_error_product_shared_label` | a label on two rows |
| `medfit_error_product_fixed_coefficient` | a fixed coefficient |
| `medfit_error_product_bound` | an inline bound |
| `medfit_error_product_constraint` | a constraint names a coefficient label |
| `medfit_error_product_intercept` | a fixed, shared or constrained intercept |
| `medfit_error_product_meanstructure` | `meanstructure = FALSE` |
| `medfit_error_product_column` | a data column that is not the product |
| `medfit_error_product_nonnumeric` | a non-numeric product input |
| `medfit_error_product_information` | `information = "expected"`, endogenous factor |
| `medfit_error_product_modeltest` | [`anova()`](https://rdrr.io/r/stats/anova.html) or [`mbco_sem()`](https://data-wise.github.io/medfit/dev/reference/mbco_sem.md) |
| `medfit_error_product_observed` | [`AIC()`](https://rdrr.io/r/stats/AIC.html) or [`BIC()`](https://rdrr.io/r/stats/AIC.html) across observed variables |
| `medfit_error_product_extract` | [`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md) refusals |

Two more facts are not errors. The covariance that completion would add
between two pure outcomes is fixed at 0 in a product model, with one
note; and
[`fit_sem()`](https://data-wise.github.io/medfit/dev/reference/fit_sem.md)
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
[`mbco_sem()`](https://data-wise.github.io/medfit/dev/reference/mbco_sem.md)
refuse. A product of exogenous variables with a free block keeps the
ordinary test. [Methods and
Formulas](https://data-wise.github.io/medfit/dev/articles/methods.html#products-and-observed-information)
gives the reason.

## Robust standard errors and a scaled test (MLR)

`estimator = "MLR"` keeps the ML estimates and, as lavaan’s
`estimator = "MLR"` does, reports sandwich standard errors and the
Yuan-Bentler scaled chi-square (`test = "yuan.bentler.mplus"`).
[`glance()`](https://generics.r-lib.org/reference/glance.html) adds the
scaled test after the plain one. The model above is saturated
(`df = 0`), so this example drops the direct effect to leave one
restriction:

``` r
syntax_mlr <- "
  mediator1 ~ a * treatment + covariate1 + covariate2
  outcome ~ b * mediator1 + covariate1 + covariate2
"
fit_mlr <- fit_sem(syntax_mlr, mediation_demo, estimator = "MLR")
glance(fit_mlr)[, c("df", "chisq", "chisq_scaled", "scaling_factor", "p_value_scaled")]
```

    # A tibble: 1 × 5
         df chisq chisq_scaled scaling_factor p_value_scaled
      <dbl> <dbl>        <dbl>          <dbl>          <dbl>
    1     1  3.54         3.46           1.02         0.0629

Coefficients and `chisq` equal the default fit; the standard errors and
the scaled columns differ. The same numbers come from
`lavaan::sem(model, data, estimator = "MLR")` read with
`lavaan::fitMeasures(fit, c("chisq.scaled", "chisq.scaling.factor", "pvalue.scaled"))`;
the agreement is tested to 1e-5. MLR needs single-level complete data
and linear equality constraints; the Satorra-Bentler `"MLM"` and the
other estimators stop with `medfit_error_estimator`. [Methods and
Formulas](https://data-wise.github.io/medfit/dev/articles/methods.html#mlr-scaled)
gives the formula. [`summary()`](https://rdrr.io/r/base/summary.html)
prints no chi-square, so read the scaled test from
[`glance()`](https://generics.r-lib.org/reference/glance.html).

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
- **Exogenous variables are fixed at their sample moments by default**,
  as lavaan does with `fixed.x = TRUE`: the structural estimates, their
  standard errors and the degrees of freedom do not change, the
  parameter count is smaller, and
  [`logLik()`](https://rdrr.io/r/stats/logLik.html), AIC and BIC are
  conditional on the fixed variables, so fits with different fixed sets
  cannot be compared. The fixed rows stay in the parameter table without
  a standard error. `fixed_x = FALSE` estimates them (the 0.14.x
  default), and a vector of names fixes only those. AIC and BIC count
  the free intercepts and means; they equal a
  [`lavaan::sem()`](https://rdrr.io/pkg/lavaan/man/sem.html) fit with
  `meanstructure = TRUE`, and exceed a default
  [`lavaan::sem()`](https://rdrr.io/pkg/lavaan/man/sem.html) (no mean
  structure) by 2 per free intercept in AIC and by log(n) per free
  intercept in BIC.
- **AIC and BIC across product and no-product fits are not comparable.**
  The product column is an extra observed variable in the joint
  likelihood, so a fit with `x:m` and the same model without it describe
  different data (on `mediation_demo`, the same outcome gives AIC 2335.6
  with the product and 2333.6 without under the default settings; the
  gap can look small, but the two likelihoods are over different data).
  `AIC(fit_a, fit_b)`, `BIC(fit_a, fit_b)`,
  [`anova()`](https://rdrr.io/r/stats/anova.html) and
  [`mbco_sem()`](https://data-wise.github.io/medfit/dev/reference/mbco_sem.md)
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
  [`?"medfit-syntax"`](https://data-wise.github.io/medfit/dev/reference/medfit-syntax.md)).
- [`summary()`](https://rdrr.io/r/base/summary.html) reports
  diagnostics, including an improper solution and any active bound or
  constraint; read them before trusting a fit.

## The outcome ledger

`fit@diagnostics$ledger` records how the fit was reached: the optimizer
state, likelihood and covariance status of the fit and of each
zero-product branch, with the notices raised on the way. An unresolved
node is unknown, not infeasible; only a literal contradiction between
equalities is certified empty. A fit that cannot be trusted stops with
an error that carries the ledger as `$ledger`: see [errors that carry
evidence](https://data-wise.github.io/medfit/dev/articles/guide-troubleshooting.html#errors-that-carry-evidence)
and [how the branches are
built](https://data-wise.github.io/medfit/dev/articles/computation-algorithms.html#a-zero-product-is-a-union-of-simpler-models).

## Stability

The exported signatures of
[`fit_sem()`](https://data-wise.github.io/medfit/dev/reference/fit_sem.md)
and
[`mbco_sem()`](https://data-wise.github.io/medfit/dev/reference/mbco_sem.md),
the `SEMFit` properties and the model syntax in
[`?"medfit-syntax"`](https://data-wise.github.io/medfit/dev/reference/medfit-syntax.md)
change only through a deprecation. New syntax and new properties can be
added: a name, a table row or a property that exists today keeps its
meaning. This matters for the features listed under Limits (a
categorical mediator or outcome, for example): they will arrive as
additions, not as a rename of `g_b`-style dummy names or of the `m:x`
product name. A test (`test-api-freeze.R`) pins the current names.
Numerical fixes are not breaking changes.

**Next:** Constrain paths and test the indirect effect: [The sem engine:
constraints and the MBCO
test](https://data-wise.github.io/medfit/dev/articles/model-sem-constraints.md)

## Related

[Cookbook recipe
11](https://data-wise.github.io/medfit/dev/articles/cookbook.html#a-latent-mediator-native-engine)
\| [Cookbook recipe
19](https://data-wise.github.io/medfit/dev/articles/cookbook.html#observed-intercepts-and-means)
\| [Cookbook recipe
20](https://data-wise.github.io/medfit/dev/articles/cookbook.html#four-way-decomposition-from-a-native-fit)
\| [Methods and
Formulas](https://data-wise.github.io/medfit/dev/articles/methods.md) \|
[`?"medfit-syntax"`](https://data-wise.github.io/medfit/dev/reference/medfit-syntax.md)
