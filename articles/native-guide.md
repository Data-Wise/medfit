# The native engine guide

The native engine fits models from lavaan-style syntax by maximum
likelihood, with a covariance structure and, when you write intercepts,
observed means. This guide covers the whole workflow in one place:
syntax, fitting, inference, constraints, model comparison, diagnostics
and the route to the mediation objects. For a first look, read [the
five-minute
quickstart](https://data-wise.github.io/medfit/articles/native-quickstart.md).

|  |  |
|----|----|
| **Entry points** | `fit_sem(syntax, data)`; `fit_mediation(model = syntax, engine = "native")` for one mediator |
| **Class returned** | `SEMFit`, then `MediationData`, `SerialMediationData` or `ParallelMediationData` from [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) |
| **Syntax reference** | [`?"medfit-syntax"`](https://data-wise.github.io/medfit/reference/medfit-syntax.md) |
| **Not covered** | latent means, latent products, groups, categorical outcomes, other estimators; see [the limits](#limits) |

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
```

## 1. Syntax

| Statement | Meaning |
|----|----|
| `y ~ x1 + x2` | regression of `y` on `x1` and `x2` |
| `f =~ y1 + y2 + y3` | latent variable `f` measured by indicators |
| `y1 ~~ y2` | covariance; `y1 ~~ y1` is a variance |
| `y ~ a*x` | label a path; equal labels are one parameter |
| `y ~ 0.5*x` | fix a path |
| `start(0.3)*`, `lower(0)*`, `upper(1)*` | starting value, lower and upper bound |
| `ab := a*b` | defined parameter with a delta-method standard error |
| `a == b`, `cp == a*b`, `a*b > 0.1` | equality or inequality constraint on labels, linear or not |
| `y1, y2 ~ x` | comma shorthand (a medfit extension; lavaan reads it differently) |

Exogenous variables get free variances and covariances, as lavaan does
with `fixed.x = FALSE`; `fixed_x = TRUE` in
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
fixes them at the sample moments instead (fewer parameters, the same
structural estimates, a conditional log likelihood). Both sides of a
constraint and the right side of a definition are arithmetic expressions
in the labels (`+ - * / ^`, parentheses, `exp`, `log`, `sqrt`, `abs`,
`min`, `max`, `pnorm`, `qnorm`, and a few more).

## 2. Fit and read

``` r
syntax <- "
  mediator1 ~ a * treatment + covariate1
  outcome ~ b * mediator1 + cp * treatment + covariate1
  ab := a * b
  total := cp + a * b
"
fit <- fit_sem(syntax, d)
summary(fit)
```

    Summary of SEMFit
    =================

    Observations: 400
    Degrees of freedom: 0
    Information: observed
    Standard errors: model-based
    Converged: Yes

    Parameters:
                         name     est     se       z       p
                            a  0.5814 0.0986  5.8977 < 1e-04
       mediator1 ~ covariate1  0.4481 0.0483  9.2711 < 1e-04
                            b  0.5729 0.0531 10.7971 < 1e-04
                           cp  0.2043 0.1091  1.8725 0.06113
         outcome ~ covariate1  0.3559 0.0565  6.2949 < 1e-04
       mediator1 ~~ mediator1  0.9536 0.0674 14.1421 < 1e-04
           outcome ~~ outcome  1.0740 0.0759 14.1421 < 1e-04
       treatment ~~ treatment  0.2500 0.0177 14.1421 < 1e-04
      treatment ~~ covariate1 -0.0700 0.0257 -2.7192 0.00654
     covariate1 ~~ covariate1  1.0398 0.0735 14.1421 < 1e-04

    Defined parameters:
      name       expr    est     se
        ab      a * b 0.3331 0.0644
     total cp + a * b 0.5374 0.1189

    Diagnostics:
      Optimizer status: 3; stationarity 1.27e-08; retries 0
      Active bounds: none
      Active constraints: none
      Improper solution: no
      Multiplier sign check: ok

| To get | Use |
|----|----|
| free-parameter estimates | `coef(fit)`; names are the label, else `lhs op rhs` without spaces (`M~X`, `eta=~m2`), as `lavaan::coef()` |
| the covariance matrix | `vcov(fit)` |
| a table with intervals | `tidy(fit, conf_int = TRUE)`; `confint(fit)` for the matrix |
| defined parameters | `fit@defined`, or the `:=` rows of [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and [`confint()`](https://rdrr.io/r/stats/confint.html) |
| chi-square, df, logLik, AIC, BIC | `glance(fit)`; `logLik(fit)`, `nobs(fit)` |

``` r
tidy(fit, conf_int = TRUE)[, c("term", "estimate", "std_error", "conf_low", "conf_high")]
```

    # A tibble: 12 × 5
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
    12 total                    0.537     0.119   0.304      0.770 

``` r
glance(fit)
```

    # A tibble: 1 × 9
       nobs  npar    df chisq p_value logLik   AIC   BIC fixed_x
      <int> <int> <dbl> <dbl>   <dbl>  <dbl> <dbl> <dbl> <chr>
    1   400    10     0     0      NA -2002. 4032. 4088. ""     

The chi-square is \\n\\ times the minimized discrepancy and has `df`
degrees of freedom. A saturated model (here `df = 0`) fits perfectly by
construction, so the test only means something when there are
restrictions.

## 3. Standard errors and weights

The default information matrix is observed; `information = "expected"`
gives lavaan’s default. `se_type = "sandwich"` gives the HC0 robust
covariance, and `weights` takes case weights.

``` r
w <- seq_len(nrow(d)) %% 3 + 1
robust <- fit_sem(syntax, d, weights = w, se_type = "sandwich")
rbind(model_based = sqrt(diag(vcov(fit)))[1:3], weighted_robust = sqrt(diag(vcov(robust)))[1:3])
```

                             a mediator1~covariate1          b
    model_based     0.09858458           0.04833820 0.05306479
    weighted_robust 0.10207525           0.04774111 0.06498487

## 4. Constraints

A constraint is a line of syntax. The engine classifies it and uses the
cheapest exact route:

| Constraint | Example | How it is solved |
|----|----|----|
| linear equality or bound | `a == b`, `a + b == 1`, `a < 0.3` | constant Jacobian rows; every accepted solution passes a gate on all rows |
| nonlinear equality | `cp == a*b` | Jacobian recomputed at every point; every start tried, the best accepted one kept; a Newton polish after acceptance |
| nonlinear inequality | `a*b > 0.1`, `ab > 0` with `ab := a*b` | same, as rows \\c(\theta) \le 0\\; a warning when the starts disagree |
| product set to zero | `a*b == 0`, `b1*b2*b3 == 0` | exact: one linear fit per factor, smallest discrepancy kept |
| sum of products | `a1*b1 + a2*b2 == 0` | best-effort: the best of the starts; a disagreement warning means a better optimum may exist, so raise `n_starts` |

``` r
tied <- fit_sem(paste0(syntax, "cp == a * b\n"), d)
round(coef(tied)[c("a", "b", "cp")], 4)
```

         a      b     cp
    0.5423 0.5497 0.2981 

``` r
tied@diagnostics$active_constraints
```

    [1] "cp == a * b"

Labels used in a constraint must be defined in the model, and a
constraint with no free parameter is an error. `CONSTRAINT(a == b)` is
the same as the bare `a == b`.

## 5. Compare models and test the indirect effect

[`anova()`](https://rdrr.io/r/stats/anova.html) is the likelihood-ratio
test for nested `SEMFit`s; it refits nothing. Nesting is checked by
parameter-table inclusion, a necessary condition, so two models that
pass but are not nested in substance are your responsibility.
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
tests an indirect effect that is a product of paths:

``` r
anova(tied, fit)
```

    Likelihood-ratio (chi-square difference) test for SEMFit models

    n = 400; Chisq is n times the minimized discrepancy

         Df Chisq Chisq diff Df diff Pr(>Chisq)
    fit   0 0.000
    tied  1 0.938    0.93802       1     0.3328

``` r
mbco_sem(fit, "a", "b")
```


        Minimum-of-two likelihood-ratio tests (MBCO) for an indirect effect

    data:  a * b = 0
    MBCO = 33.353, df = 1, p-value = 7.685e-09

For a chain `a`, `d`, `b`, give the paths:
`mbco_sem(fit, paths = c("a", "d", "b"))` is the minimum of the
single-path tests against a chi-square with one degree of freedom. The
null is a union of hypotheses, so the test is conservative when more
than one path is zero (its size is at most 0.055 at the 5% level in the
package’s simulation gate).

## 6. Diagnostics

Read these before trusting a fit; all are in `summary(fit)` and
`fit@diagnostics`:

| Field | What it says | If it is wrong |
|----|----|----|
| `Converged` | the optimizer returned and the acceptance gate passed | the fit is not returned; the error names the failure |
| `Optimizer status`, `stationarity` | the solver’s code and the Newton decrement at the solution | a large decrement means a stall; try `n_starts` |
| `Active bounds` / `Active constraints` | which bounds or constraints bind | a binding bound means the estimate is on the edge |
| `Improper solution` | a negative variance or non-positive definite covariance | respecify, or bound the variance |
| `Multiplier sign check` | active inequality multipliers have the right sign | a wrong sign means an active bound was not optimal |

``` r
b <- fit_sem(paste0(syntax, "outcome ~~ lower(2) * outcome\n"), d)
b@diagnostics$active_bounds
```

    [1] "outcome~~outcome"

When a model with a nonlinear constraint warns that the starts reached
different optima, the constraint has more than one solution (`a*b > 0.1`
holds for two positive or two negative paths). The kept fit is the best,
but say so in a report.

## 7. From a fit to mediation objects

``` r
x <- extract_mediation(fit, treatment = "treatment", mediator = "mediator1",
                       outcome = "outcome")
class(x)[1]
```

    [1] "medfit::MediationData"

`fit_mediation(model = syntax, engine = "native", treatment =, mediator =)`
does both steps for **one** mediator. For several mediators, fit with
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
and call `extract_mediation(fit, mediator = c("m1", "m2"), outcome = )`:
a chain gives a `SerialMediationData`, mediators side by side a
`ParallelMediationData`. A latent mediator works through the same call.

## Limits

- **Observed means only.** Intercepts (`y ~ 1`, `y ~ 1 + x`) are
  estimated for observed variables; a free latent mean or intercept
  stops with “latent means are planned for a later release”.
- **One group**, listwise deletion for missing data, **numeric variables
  only**.
- **ML only**, plus the HC0 sandwich; no robust chi-square, no fit
  indices beyond the chi-square, AIC and BIC.
- **Products** (`x:m`, which give the four-way decomposition) work for
  two observed variables inside a supported class; the table of limits
  and messages is on [the native model
  page](https://data-wise.github.io/medfit/articles/model-native.html#product-terms).
  The model test is `NA` when a product factor is a regression target.
- **AIC and BIC of a fit with a product are not comparable** with those
  of a fit without one (the product column enters the likelihood), so
  `AIC(fit_a, fit_b)` and [`BIC()`](https://rdrr.io/r/stats/AIC.html)
  refuse such a pair; see [the native model
  page](https://data-wise.github.io/medfit/articles/model-native.html#limits).
- For latent means, groups, categorical outcomes or fit indices use
  lavaan; the extraction route accepts a `lavaan` fit as well. See
  [lavaan and the native
  engine](https://data-wise.github.io/medfit/articles/lavaan-comparison.md).

## Related

[Quickstart](https://data-wise.github.io/medfit/articles/native-quickstart.md)
\| [Models: native
engine](https://data-wise.github.io/medfit/articles/model-native.md) \|
[Constraints and the MBCO
test](https://data-wise.github.io/medfit/articles/model-native-constraints.md)
\| [Native engine
book](https://data-wise.github.io/medfit/articles/native-book-1-mean-structure.md)
\| [Cookbook](https://data-wise.github.io/medfit/articles/cookbook.md)
\| [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md) \|
[`?"medfit-syntax"`](https://data-wise.github.io/medfit/reference/medfit-syntax.md)
