# Native engine, step by step

Nine steps from a model written as syntax to a tested, constrained and
extracted mediation result. It sits between [the five-minute
quickstart](https://data-wise.github.io/medfit/articles/native-quickstart.md)
and [the native engine
guide](https://data-wise.github.io/medfit/articles/native-guide.md). The
native engine is experimental.

|  |  |
|----|----|
| **You need** | medfit 0.8.0 or later (step 9 needs 0.9.0 or later); the bundled `mediation_demo` data |
| **You get** | a `SEMFit`, a test of the indirect effect, a constrained comparison, a `MediationData` |
| **Time** | about 20 minutes |

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

## Step 1. Write the model

One statement per line. `name * variable` labels a path, and `:=`
defines a quantity computed from labels:

``` r
syntax <- "
  mediator1 ~ a * treatment + covariate1
  outcome ~ b * mediator1 + cp * treatment + covariate1
  ab := a * b
"
```

Check: the labels `a`, `b` and `cp` are the three paths; `ab` is the
indirect effect.

## Step 2. Fit it

``` r
fit <- fit_sem(syntax, mediation_demo)
fit
```

    SEMFit (native maximum likelihood)
    ==================================

      Observations:  400
      Parameters:    10 free, 0 df
      Information:   observed
      Std. errors:   model-based
      Converged:     Yes

    Defined parameters:
      ab              0.3331  (SE 0.0644)

    Use summary() for the parameter table and diagnostics.

Check: `Converged: Yes`, and `ab` appears with a standard error.

## Step 3. Read the estimates

``` r
tidy(fit, conf_int = TRUE)[, c("term", "estimate", "std_error", "conf_low", "conf_high")]
```

    # A tibble: 11 × 5
       term                   estimate std_error conf_low conf_high
       <chr>                     <dbl>     <dbl>    <dbl>     <dbl>
     1 a                        0.581     0.0986  0.388      0.775
     2 mediator1~covariate1     0.448     0.0483  0.353      0.543
     3 b                        0.573     0.0531  0.469      0.677
     4 cp                       0.204     0.109  -0.00954    0.418
     5 outcome~covariate1       0.356     0.0565  0.245      0.467
     6 mediator1~~mediator1     0.954     0.0674  0.821      1.09
     7 outcome~~outcome         1.07      0.0759  0.925      1.22
     8 treatment~~treatment     0.250     0.0177  0.215      0.285
     9 treatment~~covariate1   -0.0700    0.0257 -0.120     -0.0195
    10 covariate1~~covariate1   1.04      0.0735  0.896      1.18
    11 ab                       0.333     0.0644  0.207      0.459 

`confint(fit)` gives the same intervals on their own. Parameter names
follow lavaan: a label if you gave one, otherwise `lhs~rhs`, `X~~X` for
a variance and `eta=~m2` for a loading.

## Step 4. Check the fit

``` r
glance(fit)[, c("npar", "df", "chisq", "p_value", "AIC", "BIC")]
```

    # A tibble: 1 × 6
       npar    df chisq p_value   AIC   BIC
      <int> <dbl> <dbl>   <dbl> <dbl> <dbl>
    1    10     0     0      NA 4032. 4088.

A model with no restriction has 0 degrees of freedom, so there is
nothing to reject yet. Step 6 adds a restriction and a test.

## Step 5. Test the indirect effect

The product `a * b` is zero if either factor is, so a plain test of `ab`
is unreliable.
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
refits with `a == 0` and with `b == 0` and uses the smaller
likelihood-ratio statistic:

``` r
mbco_sem(fit, "a", "b")
```


        Minimum-of-two likelihood-ratio tests (MBCO) for an indirect effect

    data:  a * b = 0
    MBCO = 33.353, df = 1, p-value = 7.685e-09

## Step 6. Constrain a path and compare

Add a line to the syntax. Setting the direct effect equal to the
indirect effect is a nonlinear constraint:

``` r
tied <- fit_sem(paste0(syntax, "cp == a * b\n"), mediation_demo)
round(coef(tied)[c("a", "b", "cp")], 3)
```

        a     b    cp
    0.542 0.550 0.298 

``` r
anova(tied, fit)
```

    Likelihood-ratio (chi-square difference) test for SEMFit models

    n = 400; Chisq is n times the minimized discrepancy

         Df Chisq Chisq diff Df diff Pr(>Chisq)
    fit   0 0.000
    tied  1 0.938    0.93802       1     0.3328

[`anova()`](https://rdrr.io/r/stats/anova.html) refits nothing; it
compares the two fits’ chi-squares. A large p-value means the data do
not reject the restriction.

## Step 7. A chain of three paths

For a serial model, the indirect effect is a product of three paths, and
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
takes all of them:

``` r
chain <- "
  mediator1 ~ a * treatment
  mediator2 ~ d * mediator1 + treatment
  outcome ~ b * mediator2 + mediator1 + treatment
"
mbco_sem(fit_sem(chain, mediation_demo), paths = c("a", "d", "b"))
```


        Minimum-of-3 likelihood-ratio tests (MBCO) for an indirect effect

    data:  a * d * b = 0
    MBCO = 17.557, df = 1, p-value = 2.788e-05

## Step 8. Get the usual mediation object

``` r
x <- extract_mediation(fit, treatment = "treatment", mediator = "mediator1",
                       outcome = "outcome")
tidy(x, type = "effects", conf_int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std_error conf_low conf_high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.333    0.0644  0.207       0.459
    2 nde      0.204    0.109  -0.00954     0.418
    3 te       0.537    0.119   0.304       0.770

From here
[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`confint()`](https://rdrr.io/r/stats/confint.html) and
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
work as on any other fit.

## Step 9. Fix exogenous covariates

Needs medfit 0.9.0 or later. With many covariates, most parameters are
the exogenous variances and covariances (and the means, when the model
has a mean structure). `fixed_x = TRUE` fixes them at their sample
values, as lavaan’s `fixed.x = TRUE` does, and leaves the structural
paths alone. The restricted model of Step 6 shows that the test does not
move either:

``` r
tied_fx <- fit_sem(paste0(syntax, "cp == a * b\n"), mediation_demo, fixed_x = TRUE)
round(coef(tied_fx)[c("a", "b", "cp")], 3)
```

        a     b    cp
    0.542 0.550 0.298 

``` r
rbind(
  free  = glance(tied)[, c("npar", "df", "chisq", "logLik", "fixed_x")],
  fixed = glance(tied_fx)[, c("npar", "df", "chisq", "logLik", "fixed_x")]
)
```

    # A tibble: 2 × 5
       npar    df chisq logLik fixed_x
    * <int> <dbl> <dbl>  <dbl> <chr>
    1     9     1 0.938 -2002. ""
    2     6     1 0.938 -1140. "treatment, covariate1"

Check: `a`, `b` and `cp` match Step 6, and `df` and `chisq` are the
same, but `npar` is smaller. The log likelihood is conditional on the
fixed variables, so it is not comparable with the free fit’s, and
[`anova()`](https://rdrr.io/r/stats/anova.html) refuses to compare the
two fits. `fixed_x` also takes a character vector, such as
`fixed_x = "covariate1"`, to fix only some of the exogenous variables.

## Where next

- [The native engine
  guide](https://data-wise.github.io/medfit/articles/native-guide.md):
  syntax, inference, constraints, diagnostics and limits in one place.
- [Cookbook recipes 11 to
  20](https://data-wise.github.io/medfit/articles/cookbook.md): a latent
  mediator, a nonlinear constraint, comparing models, defined
  parameters, bounds, checks, fixed covariates and intercepts.
- [Native engine
  book](https://data-wise.github.io/medfit/articles/native-book-1-mean-structure.md):
  seven chapters on the mean structure, scale, constraints, `fixed_x`,
  inference, the product term and the four-way decomposition.
- [lavaan and the native
  engine](https://data-wise.github.io/medfit/articles/lavaan-comparison.md):
  what the native engine does and does not do compared with lavaan.
