# Native engine in five minutes

Fit a path model from syntax, read it, test it, and turn it into a
mediation object, with no package besides medfit. The native engine is
experimental. For the full picture see [the native engine
guide](https://data-wise.github.io/medfit/articles/native-guide.md).

|              |                                                          |
|--------------|----------------------------------------------------------|
| **You need** | medfit 0.8.0 or later; the bundled `mediation_demo` data |
| **You get**  | a `SEMFit`, then a `MediationData`                       |
| **Time**     | five minutes                                             |

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

## 1. Write the model

One statement per line. Label a path with `name * variable`, and define
a new quantity with `:=`:

``` r
syntax <- "
  mediator1 ~ a * treatment + covariate1
  outcome ~ b * mediator1 + cp * treatment + covariate1
  ab := a * b
"
```

## 2. Fit it

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

`Converged: Yes` and the defined parameter `ab` with its delta-method
standard error are the first things to read.

## 3. Read the estimates

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

`summary(fit)` adds the optimizer diagnostics (active bounds, improper
solution); `glance(fit)` gives the chi-square, AIC and BIC.

## 4. Test the indirect effect

[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
refits with `a == 0` and with `b == 0` and takes the smaller
likelihood-ratio statistic:

``` r
mbco_sem(fit, "a", "b")
```


        Minimum-of-two likelihood-ratio tests (MBCO) for an indirect effect

    data:  a * b = 0
    MBCO = 33.353, df = 1, p-value = 7.685e-09

## 5. Constrain something

Add a line, and the engine solves the constrained problem. Setting the
direct effect equal to the indirect effect is a nonlinear constraint:

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

## 6. Get the usual mediation object

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

## Where next

- [Native engine, step by
  step](https://data-wise.github.io/medfit/articles/native-tutorial.md):
  the same path in ten checked steps, with a chain of three paths.
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
