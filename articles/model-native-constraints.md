# Native engine: constraints and the MBCO test

Fix, bound or equate parameters, and test the indirect effect with one
call. Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection; the third of four [native
engine](https://data-wise.github.io/medfit/articles/model-native.md)
pages. The engine is experimental.

|  |  |
|----|----|
| **What it does** | equality, inequality and fixed-value constraints on labeled paths; [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) for the indirect effect |
| **Class returned** | `SEMFit` |
| **Syntax** | `a == b`, `a + b == 1`, `a < 0.3`, `y ~ 0.5 * x`, `CONSTRAINT(a == b)` |
| **Limit** | constraints must be linear in the labels |

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
base <- "
  mediator1 ~ a * treatment + covariate1 + covariate2
  outcome ~ b * mediator1 + cp * treatment + covariate1 + covariate2
"
```

## Equal paths

Write the constraint on its own line, bare or inside `CONSTRAINT()`:

``` r
free <- fit_sem(paste0(base, "ab := a * b"), mediation_demo)
equal <- fit_sem(paste0(base, "CONSTRAINT(a == b)\nab := a * b"), mediation_demo)
rbind(free = coef(free)[c("a", "b")], constrained = coef(equal)[c("a", "b")])
```

                        a         b
    free        0.5826425 0.5711384
    constrained 0.5737394 0.5737394

The constrained fit has one more degree of freedom, and `summary(equal)`
lists the constraint as active under Diagnostics.

## Bounds and fixed values

``` r
bounded <- fit_sem(paste0(base, "a < 0.3\nab := a * b"), mediation_demo)
round(coef(bounded)[c("a", "b")], 4)
```

         a      b
    0.3000 0.5711 

``` r
fixed <- fit_sem(sub("cp \\*", "0 *", paste0(base, "ab := a * b")), mediation_demo)
round(coef(fixed)[c("a", "b")], 4)
```

         a      b
    0.5826 0.5996 

`a < 0.3` pushed `a` onto the bound, and `cp` was fixed at 0 in the
second fit. A parameter that sits on a bound has a standard error of 0
in the table; read the “Active bounds” line of
[`summary()`](https://rdrr.io/r/base/summary.html) before using it.

## Test the indirect effect

[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
is the minimum-of-two likelihood-ratio test (MBCO): it refits with `a`
fixed at 0 and with `b` fixed at 0, and the smaller statistic tests \\a
\\ b = 0\\.

``` r
mbco_sem(free, "a", "b")
```


        Minimum-of-two likelihood-ratio tests (MBCO) for an indirect effect

    data:  a * b = 0
    MBCO = 33.63, df = 1, p-value = 6.666e-09

The result is an `htest`; the two component tests are in its `tests`
element.

## Limits

- **Constraints must be linear in the labels.** `a + b == 1` is fine;
  `a * b == 0.1` stops with “nonlinear constraints are not supported in
  this version”.
- **A constraint needs a free parameter** and **labels must be defined**
  in the model.
- **Equal labels are one parameter.** Giving two paths the same label
  equates them without a constraint line.

## Related

[Cookbook recipe
11](https://data-wise.github.io/medfit/articles/cookbook.html#a-latent-mediator-native-engine)
\| [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md) \|
[`?"medfit-syntax"`](https://data-wise.github.io/medfit/reference/medfit-syntax.md)
