# lavaan and the native engine

medfit’s native engine fits covariance-structure models, with observed
intercepts and means, from lavaan-style syntax. It is not a replacement
for lavaan: it covers the path models behind mediation analysis and
stops there. This page runs both on the same data, then lists what each
does, with a status for every feature that a test checks against a live
probe on each build.

|  |  |
|----|----|
| **Use medfit native when** | you want the indirect effect, [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md), or a nonlinear constraint such as `cp == a*b` on a path model |
| **Use lavaan when** | you need latent means, groups, categorical outcomes, other estimators, FIML, or fit indices |
| **Both** | read the same `~`, `=~`, `~~`, `:=` and constraint syntax, and agree to about 1e-6 where both apply |

## The same model in both

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
library(lavaan)
```

    This is lavaan 0.7-3
    lavaan is FREE software! Please report any bugs.

``` r
model <- "
  mediator1 ~ a * treatment
  outcome ~ b * mediator1 + cp * treatment
  ab := a * b
"
native <- tidy(fit_sem(model, mediation_demo))
ref <- parameterEstimates(sem(model, mediation_demo, fixed.x = FALSE))
rows <- native[native$term %in% c("a", "b", "cp", "ab"), ]
i <- match(rows$term, ref$label)
data.frame(term = rows$term, native = rows$estimate, lavaan = ref$est[i],
           se_native = rows$std_error, se_lavaan = ref$se[i])
```

      term     native     lavaan  se_native  se_lavaan
    1    a 0.45599612 0.45599612 0.10763360 0.10763360
    2    b 0.71342873 0.71342873 0.05047202 0.05047202
    3   cp 0.04057666 0.04057665 0.11106057 0.11106057
    4   ab 0.32532073 0.32532073 0.08016376 0.08016376

`fixed.x = FALSE` matters: lavaan fixes exogenous covariates by default,
the native engine estimates their variances and covariances unless
`fixed_x = TRUE` (or a vector of names) asks for lavaan’s behavior. The
standard errors, including the delta-method error of `ab`, agree as
well.

## Where they differ by design

The default information matrix is observed in medfit and expected in
lavaan. They agree for a well-fitting model and separate when the model
is misspecified; `information = "expected"` reproduces lavaan:

``` r
bad <- "mediator1 ~ treatment\nmediator2 ~ treatment\noutcome ~ mediator1 + mediator2"
rbind(
  native_observed = sqrt(diag(vcov(fit_sem(bad, mediation_demo))))[3],
  native_expected = sqrt(diag(vcov(fit_sem(bad, mediation_demo, information = "expected"))))[3],
  lavaan = sqrt(diag(vcov(sem(bad, mediation_demo, fixed.x = FALSE))))[3]
)
```

                    outcome~mediator1
    native_observed        0.05642889
    native_expected        0.04715465
    lavaan                 0.04715465

## Feature table

Status is one of **Supported** (matches lavaan where lavaan has it),
**Partial** (a subset), **Different by design** (both exist and differ
on purpose) and **Unsupported** (use lavaan). Each row is checked by
`tests/testthat/test-lavaan-comparison.R`; editing a status without
changing the behavior makes that test fail.

| Feature | lavaan | medfit native | Status |
|----|----|----|----|
| Paths, covariances, labels, fixed values, bounds | yes | yes | Supported |
| Several modifiers on one term | yes | one per term | Unsupported |
| Means and intercepts | yes | observed intercepts and means (`y ~ 1`, `y ~ 1 + x`); latent means are planned | Supported |
| Multiple groups | yes | no | Unsupported |
| Estimators other than ML | yes | ML, plus the HC0 sandwich | Partial |
| Missing data | FIML | listwise deletion | Partial |
| Categorical outcomes | WLSMV and others | numeric variables only; use lavaan (WLSMV) | Unsupported |
| Information matrix | expected | observed by default | Different by design |
| Robust standard errors | yes | `se_type = "sandwich"` equals lavaan’s huber.white | Supported |
| Linear constraints | yes | yes | Supported |
| Nonlinear constraints | yes | yes, including `a*b > k` and sums of products | Supported |
| Defined parameters | `:=` | `:=` with delta-method errors | Supported |
| Chi-square and df | yes | [`glance()`](https://generics.r-lib.org/reference/glance.html) | Supported |
| CFI, RMSEA, SRMR | yes | not reported | Unsupported |
| logLik, AIC, BIC | yes | logLik equal; AIC and BIC count the means | Different by design |
| Standardized estimates, modification indices, fitted values, residuals | yes | no | Unsupported |
| Fixed exogenous covariates | `fixed.x = TRUE` is the default | `fixed_x = TRUE` or names, default `FALSE`; product columns are fixed with the rest; a statement on a selected variable is an error | Different by design |
| Product terms (`x:m`) and four-way effects | `x:m` is an observed exogenous column, kept as written; no mediation effects | `x:m` stored as `m:x`; coefficients and sandwich standard errors equal lavaan’s; [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) gives the four-way parts; chi-square, df and p-value are `NA` and [`anova()`](https://rdrr.io/r/stats/anova.html), [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) refuse when a factor is a regression target; a supported class only | Partial |
| Nested model comparison | [`lavTestLRT()`](https://rdrr.io/pkg/lavaan/man/lavTestLRT.html) | [`anova()`](https://rdrr.io/r/stats/anova.html) | Supported |
| Mediation effects and the MBCO test | no | [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md), [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) | Supported |

The first column names the feature; the probe for a row is in the test,
not here, so the table cannot drift from the code without a failing
test.

### Products, in both

lavaan reads `x:m` as an observed exogenous column and so does medfit,
so the coefficients and the sandwich standard errors agree, with
`fixed.x = TRUE` as well as with `fixed.x = FALSE` (the product column
is fixed with the other exogenous variables):

``` r
prod_model <- "mediator1 ~ treatment
               outcome_int ~ mediator1 + treatment + treatment:mediator1"
nat <- suppressWarnings(fit_sem(prod_model, mediation_demo, se_type = "sandwich"))
lav <- sem(prod_model, mediation_demo, fixed.x = FALSE, se = "robust.huber.white")
nat_fx <- suppressWarnings(fit_sem(prod_model, mediation_demo, se_type = "sandwich", fixed_x = TRUE))
lav_fx <- sem(prod_model, mediation_demo, fixed.x = TRUE, se = "robust.huber.white")
paths <- 1:4
rbind(
  max_diff_estimate = max(abs(coef(nat)[paths] - lavaan::coef(lav)[paths])),
  max_diff_se = max(abs(sqrt(diag(vcov(nat)))[paths] - sqrt(diag(lavaan::vcov(lav)))[paths])),
  max_diff_estimate_fixed_x = max(abs(coef(nat_fx)[paths] - lavaan::coef(lav_fx)[paths]))
)
```

                                      [,1]
    max_diff_estimate         2.220446e-16
    max_diff_se               2.254825e-11
    max_diff_estimate_fixed_x 2.220446e-16

They differ in what follows. lavaan reports a chi-square for this model;
medfit reports `NA`, because the product contains a regression target
(`mediator1`) and the model treats it as exogenous, which makes the
global test invalid (see [the native model
page](https://data-wise.github.io/medfit/articles/model-native.html#product-terms)).
lavaan stores the product under the spelling you wrote
(`treatment:mediator1`); medfit stores `mediator1:treatment`, whichever
order you write. A model medfit rejects (a residual covariance between
outcomes, a shared or fixed coefficient, a constraint on a coefficient,
a bound) is still fitted by lavaan.
