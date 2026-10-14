# Native engine: paths and defined parameters

Write the model as syntax and fit it by maximum likelihood with no other
package. This is the first of four pages on the native engine, which is
experimental. Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection.

|  |  |
|----|----|
| **Structure** | any path model you can write as syntax; this page uses simple mediation |
| **Class returned** | `SEMFit`, then `MediationData` from [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) |
| **Routes** | `fit_sem(syntax, data)`, or `fit_mediation(model = syntax, engine = "native")` |
| **Syntax** | [`?"medfit-syntax"`](https://data-wise.github.io/medfit/reference/medfit-syntax.md) lists every statement |

The four pages: this one (paths and defined parameters), [a latent
mediator](https://data-wise.github.io/medfit/articles/model-native-latent.md),
[constraints and the MBCO
test](https://data-wise.github.io/medfit/articles/model-native-constraints.md),
and [several mediators and
weights](https://data-wise.github.io/medfit/articles/model-native-multi.md).

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
reads the paths exactly as before; the four-way decomposition is not
available on this route yet.

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
- **No four-way decomposition** from the native engine.
- [`summary()`](https://rdrr.io/r/base/summary.html) reports
  diagnostics, including an improper solution and any active bound or
  constraint; read them before trusting a fit.

## Related

[Cookbook recipe
11](https://data-wise.github.io/medfit/articles/cookbook.html#a-latent-mediator-native-engine)
\| [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md) \|
[`?"medfit-syntax"`](https://data-wise.github.io/medfit/reference/medfit-syntax.md)
