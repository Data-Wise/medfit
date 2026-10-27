# Native engine: categorical covariates

Use a factor, character or logical column as a covariate in syntax. Part
of the [Models](https://data-wise.github.io/medfit/articles/models.md)
collection, with the other [native
engine](https://data-wise.github.io/medfit/articles/model-native.md)
pages. This page needs medfit 0.11.0 or later (GitHub; CRAN has 0.3.2).

|  |  |
|----|----|
| **What it does** | replaces a categorical column on a regression’s right side with one 0/1 dummy per non-reference level |
| **Class returned** | `SEMFit` |
| **Syntax** | `y ~ x + group`, `z*group_mid` (label one dummy), `group:m` (one product per dummy) |
| **Limit** | a categorical outcome, mediator or treatment is not supported (see Limits) |

The page cuts `covariate1` into three groups to have a factor to use:

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
dat <- transform(mediation_demo,
                 group = cut(covariate1, c(-Inf, -0.5, 0.5, Inf), labels = c("low", "mid", "high")))
base <- "
  mediator1 ~ a * treatment + group
  outcome ~ b * mediator1 + cp * treatment + group
"
```

## Fit and read it

Write `group` where a numeric covariate would go:

``` r
fit <- fit_sem(paste0(base, "ab := a * b"), dat)
tidy(fit)[1:7, c("term", "estimate", "std_error")]
```

    # A tibble: 7 × 3
      term                 estimate std_error
      <chr>                   <dbl>     <dbl>
    1 a                       0.549    0.102
    2 mediator1~group_mid     0.328    0.125
    3 mediator1~group_high    0.948    0.124
    4 b                       0.618    0.0524
    5 cp                      0.128    0.110
    6 outcome~group_mid       0.463    0.132
    7 outcome~group_high      0.729    0.139 

`group` became `group_mid` and `group_high`, named `<column>_<level>`.
The reference level is the first factor level (`low`), so each dummy is
read against it. A character column is sorted in the C locale, so its
reference does not depend on your session. A logical column gives one
dummy, `<column>_TRUE`. The fit equals one with the dummies written by
hand, and `a`, `b` and `ab` mean what they always mean.

## Label or constrain one dummy

A label names one coefficient, so it goes on a dummy, never on the
factor (`b*group` stops with a message that names the dummies). A
constraint names a label:

``` r
pinned <- fit_sem("
  mediator1 ~ a * treatment + group
  outcome ~ b * mediator1 + cp * treatment + group + z * group_mid
  z == 0
", dat)
tidy(pinned)[grepl("group", tidy(pinned)$term, fixed = TRUE), c("term", "estimate")]
```

    # A tibble: 10 × 2
       term                   estimate
       <chr>                     <dbl>
     1 mediator1~group_mid      0.328
     2 mediator1~group_high     0.948
     3 outcome~group_high       0.474
     4 treatment~~group_mid     0.0329
     5 treatment~~group_high   -0.0359
     6 group_mid~~group_mid     0.224
     7 group_mid~~group_high   -0.118
     8 group_high~~group_high   0.228
     9 group_mid~1              0.338
    10 group_high~1             0.35  

`group_mid` in the outcome equation is pinned at 0 and the other rows
are free.

## Missing values

Dummies are built from the full column before rows with missing values
are dropped, and a missing value in the factor drops the row once:

``` r
dat_na <- dat
dat_na$group[c(3, 40)] <- NA
fit_na <- suppressMessages(fit_sem(paste0(base, "ab := a * b"), dat_na))
c(rows_used = fit_na@n_obs, rows_dropped = fit_na@n_dropped)
```

       rows_used rows_dropped
             398            2 

A level that occurs only in dropped rows gives a dummy with no
variation, and the fit stops with a message that names the dummy.

## Fixed covariates, tests and refits

`fixed_x = "group"` fixes every dummy at its sample moments, and a dummy
name fixes one.
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
refits through a stored factor map, so the data it needs is already in
the fit:

``` r
mbco_sem(fit, paths = c("a", "b"))
```


        Minimum-of-two likelihood-ratio tests (MBCO) for an indirect effect

    data:  a * b = 0
    MBCO = 28.121, df = 1, p-value = 1.14e-07

## Products and the four-way decomposition

`group:mediator1` expands to one product per dummy, each a product term
under the rules in [the native model
page](https://data-wise.github.io/medfit/articles/model-native.md). The
fit warns that the global test is not valid with a product, so the chunk
silences it and asks for the sandwich:

``` r
prod <- suppressWarnings(fit_sem("
  mediator1 ~ a * treatment + group
  outcome_int ~ b * mediator1 + treatment + group + group:mediator1
", dat, se_type = "sandwich"))
tidy(prod)[grepl(":", tidy(prod)$term, fixed = TRUE) & tidy(prod)$op == "~", c("term", "estimate")]
```

    # A tibble: 2 × 2
      term                             estimate
      <chr>                               <dbl>
    1 outcome_int~group_mid:mediator1    0.0219
    2 outcome_int~group_high:mediator1   0.0139

A factor covariate in the mediator equation works with the four-way
decomposition, entering the covariate means through its dummies:

``` r
fw <- suppressWarnings(fit_sem("
  mediator1 ~ treatment + group
  outcome_int ~ treatment + mediator1 + treatment:mediator1 + covariate2
", dat, se_type = "sandwich"))
tidy(extract_mediation(fw, treatment = "treatment", mediator = "mediator1",
                       decomposition = "four_way"), type = "components")[, 1:3]
```

    # A tibble: 4 × 3
      term    estimate std_error
      <chr>      <dbl>     <dbl>
    1 cde       0.0423    0.119
    2 int_ref   0.0540    0.0380
    3 int_med   0.273     0.0749
    4 pie       0.392     0.0837

## Limits

- **A categorical outcome, mediator or treatment** is not supported in
  the native engine: only a covariate on a regression’s right side is
  expanded. The supported routes today:
  - *A two-level treatment or mediator:* recode it as a 0/1 numeric
    column.
  - *A treatment with more than two levels:* compare two levels at a
    time. Keep the rows of those two levels and code the pair 0/1; each
    comparison is one ordinary fit. There is no single set of effects
    for all levels yet.
  - *A binary or count outcome or mediator:* use
    [`fit_mediation(engine = "glm")`](https://data-wise.github.io/medfit/articles/model-glm-families.md)
    with a `binomial` or `poisson` family. Ordinal variables are not
    supported by any medfit engine.

  These are on the roadmap as separate items, not scheduled.
- **A label, fixed value, start or bound on the factor** stops
  (`b*group`); put it on one dummy. A **constraint** names the label,
  never the factor or a bare dummy.
- **Ordered factors, a one-level factor, a level that makes an invalid
  name, and a product of two categorical columns** each stop with a
  message that says why. The full list of messages is in the
  [Troubleshooting
  guide](https://data-wise.github.io/medfit/articles/guide-troubleshooting.md)
  and in
  [`?"medfit-syntax"`](https://data-wise.github.io/medfit/reference/medfit-syntax.md).
- **A refit from raw data** (a nonparametric bootstrap that calls
  [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
  on each resample) rebuilds the factor each time, so a level missing
  from a character column’s resample changes the reference level.

## Related

[Cookbook recipe
21](https://data-wise.github.io/medfit/articles/cookbook.html#a-categorical-covariate-in-a-native-fit)
\| [Native engine: paths and defined
parameters](https://data-wise.github.io/medfit/articles/model-native.md)
\|
[Troubleshooting](https://data-wise.github.io/medfit/articles/guide-troubleshooting.md)
\|
[`?"medfit-syntax"`](https://data-wise.github.io/medfit/reference/medfit-syntax.md)
