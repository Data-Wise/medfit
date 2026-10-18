# Native engine: a latent mediator

The mediator is a construct measured by several indicators, and you want
its indirect effect without first averaging the indicators into a score.
Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection; the second of five [native
engine](https://data-wise.github.io/medfit/articles/model-native.md)
pages.

|  |  |
|----|----|
| **Structure** | X to a latent mediator \\\eta\\ (with indicators) to Y |
| **Class returned** | `SEMFit`, then `MediationData` |
| **Syntax** | `eta =~ m1 + m2 + m3` defines the latent variable |
| **Indirect effect** | \\a \\ b\\ through the latent \\\eta\\ |

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

## Simulated data

The mediator `eta` is not a column of the data. Three noisy indicators
measure it, and the true indirect effect is \\0.5 \times 0.4 = 0.2\\.

``` r
set.seed(11)
n <- 400
X <- rnorm(n)
eta <- 0.5 * X + rnorm(n, sd = 0.9)
ldat <- data.frame(
  X = X,
  m1 = eta + rnorm(n, sd = 0.7),
  m2 = 0.8 * eta + rnorm(n, sd = 0.7),
  m3 = 0.7 * eta + rnorm(n, sd = 0.8)
)
ldat$Y <- 0.4 * eta + 0.2 * X + rnorm(n, sd = 0.8)
```

## Fit it

``` r
syntax <- "
  eta =~ m1 + m2 + m3
  eta ~ a * X
  Y ~ b * eta + cp * X
  ab := a * b
"
fit <- fit_sem(syntax, ldat)
summary(fit)
```

    Summary of SEMFit
    =================

    Observations: 400
    Degrees of freedom: 4
    Information: observed
    Standard errors: model-based
    Converged: Yes

    Parameters:
           name    est     se       z      p
      eta =~ m2 0.8299 0.0607 13.6674 <1e-04
      eta =~ m3 0.7772 0.0570 13.6332 <1e-04
              a 0.4606 0.0546  8.4336 <1e-04
              b 0.3659 0.0548  6.6766 <1e-04
             cp 0.2546 0.0487  5.2291 <1e-04
       m1 ~~ m1 0.5502 0.0658  8.3637 <1e-04
       m2 ~~ m2 0.5067 0.0523  9.6837 <1e-04
       m3 ~~ m3 0.5272 0.0500 10.5339 <1e-04
         Y ~~ Y 0.6353 0.0472 13.4558 <1e-04
     eta ~~ eta 0.7955 0.0959  8.2924 <1e-04
         X ~~ X 0.9356 0.0662 14.1421 <1e-04

    Defined parameters:
     name  expr    est    se
       ab a * b 0.1685 0.031

    Diagnostics:
      Optimizer status: 3; stationarity 7.32e-09; retries 0
      Active bounds: none
      Active constraints: none
      Improper solution: no
      Multiplier sign check: ok

The first indicator’s loading is fixed at 1 to set the scale of `eta`,
so the table lists loadings only for `m2` and `m3`.

``` r
x <- extract_mediation(fit, treatment = "X", mediator = "eta", outcome = "Y")
tidy(x, type = "effects", conf_int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std_error conf_low conf_high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.169    0.0310    0.108     0.229
    2 nde      0.255    0.0487    0.159     0.350
    3 te       0.423    0.0445    0.336     0.510

## Why not average the indicators

An average of the indicators contains measurement error, which pulls the
indirect effect toward zero. In this simulation:

``` r
ldat$M_avg <- rowMeans(ldat[, c("m1", "m2", "m3")])
avg <- fit_mediation(Y ~ X + M_avg, M_avg ~ X, data = ldat,
                     treatment = "X", mediator = "M_avg")
c(latent = unname(nie(x)), average_of_indicators = unname(nie(avg)), truth = 0.2)
```

                   latent average_of_indicators                 truth
                0.1685311             0.1300765             0.2000000 

One simulated dataset shows the direction, not the size of the
difference.

## Limits

- **The variables in the syntax must be columns of the data**, except
  the latent ones. A variable that is missing stops the fit with
  “variables in the model are not columns of `data`”.
- **One latent mediator per `fit_mediation(engine = "native")` call**,
  as with any single mediator; for several, use
  [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
  and
  [extract](https://data-wise.github.io/medfit/articles/model-native-multi.md)
  the structure.

## Related

[Cookbook recipe
11](https://data-wise.github.io/medfit/articles/cookbook.html#a-latent-mediator-native-engine)
\| [Constraints and the MBCO
test](https://data-wise.github.io/medfit/articles/model-native-constraints.md)
\| [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md)
