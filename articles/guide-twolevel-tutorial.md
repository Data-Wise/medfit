# Two-level mediation: a step-by-step workflow

This guide walks one analysis from a `lavaan` fit to a reported result,
and says what to check at each step. It uses the same simulated data as
[Two-level
mediation](https://data-wise.github.io/medfit/articles/model-twolevel.md),
which is the reference page for every option; read that page when a step
here needs more detail. The route needs `lavaan` (Suggests).

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
has_lavaan <- requireNamespace("lavaan", quietly = TRUE)
```

## Step 1: fit the same regressions at both levels

Treatment, mediator and outcome are measured on level-1 units nested in
clusters. Write the same three regressions at `level: 1` (within) and
`level: 2` (between) and fit with `cluster =`.

``` r
set.seed(2026)
J <- 100
n <- 5
id <- rep(seq_len(J), each = n)
xb <- rnorm(J)[id]
xw <- rnorm(J * n)
x <- xb + xw
m <- 0.4 * xw + 0.7 * xb + 0.5 * rnorm(J)[id] + rnorm(J * n)
mbar <- ave(m, id)
y <- 0.3 * xw + 0.2 * xb + 0.5 * (m - mbar) + 0.9 * mbar + 0.5 * rnorm(J)[id] + rnorm(J * n)
d <- data.frame(id = id, X = x, M = m, Y = y)

model <- "
  level: 1
    M ~ X
    Y ~ M + X
  level: 2
    M ~ X
    Y ~ M + X
"
```

``` r
fit <- lavaan::sem(model, data = d, cluster = "id")
```

## Step 2: extract, then check the fit before reading any effect

[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
reads the fit and never refits. Name the three roles; the paths are
found by variable name and level, not by label.

``` r
td <- extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y")
```

Three properties decide whether the between-level numbers can be
trusted. Read them first.

``` r
td@icc
```

            X         M         Y
    0.5031045 0.3233019 0.4001454 

``` r
td@between_identified
```

    [1] TRUE

``` r
td@admissible
```

    [1] TRUE

``` r
td@n_clusters
```

    [1] 100

``` r
td@cross_level_equal
```

    character(0)

| Check | What it means | If it fails |
|----|----|----|
| `between_identified` | the treatment and the mediator vary enough between clusters (ICC at least 0.01) | only the within effects are returned; between effects and the contrast stop with class `medfit_between_unidentified` |
| `admissible` | lavaan’s post-check passed (no negative variance) | inspect the fit; standard errors on a negative variance are `NA` with a `medfit_warning_vcov_diagonal` warning |
| `n_clusters` | fewer than 50 clusters triggers a warning (a judgment, not a published cutoff) | treat between results as rough |
| `cross_level_equal` | paths constrained equal across levels (`a`, `b`, or both) | with both equated the contrast is `NA` by constraint |

## Step 3: read the effects at each level

``` r
nie(td)
```

    Natural Indirect Effect (NIE): 0.2446

``` r
nie(td, level = "between")
```

    Natural Indirect Effect (NIE), between level: 0.5344

``` r
tidy(td, conf_int = TRUE)
```

    # A tibble: 15 × 5
       term            estimate std_error conf_low conf_high
       <chr>              <dbl>     <dbl>    <dbl>     <dbl>
     1 a_within           0.443    0.0495   0.346     0.540
     2 b_within           0.552    0.0506   0.453     0.651
     3 c_prime_within     0.268    0.0550   0.161     0.376
     4 a_between          0.559    0.0732   0.416     0.703
     5 b_between          0.955    0.194    0.575     1.34
     6 c_prime_between    0.229    0.134   -0.0331    0.491
     7 nie_within         0.245    0.0354   0.175     0.314
     8 nde_within         0.268    0.0550   0.161     0.376
     9 te_within          0.513    0.0571   0.401     0.625
    10 pm_within          0.477    0.0697   0.340     0.613
    11 nie_between        0.534    0.127    0.285     0.784
    12 nde_between        0.229    0.134   -0.0331    0.491
    13 te_between         0.763    0.0935   0.580     0.947
    14 pm_between         0.700    0.163    0.380     1.02
    15 nie_contrast      -0.290    0.137   -0.559    -0.0209

The within and between indirect effects are separate quantities: \\a_w
b_w\\ and \\a_b b_b\\. Standard errors use the delta method over the
joint covariance, so the covariance between a within and a between slope
is part of every one. The intervals are Wald intervals.

## Step 4: treat the contrast as descriptive

`nie(td, level = "contrast")` is the within effect minus the between
effect. It is returned unless both `a` and `b` are equated across
levels. It describes a difference between two quantities; it is not a
test that the levels differ.

``` r
nie(td, level = "contrast")
```

    Natural Indirect Effect (NIE), within - between contrast: -0.2899

## Step 5: choose an interval

The delta-method interval from Step 3 is the default. When you want a
distribution-based interval, use the cluster bootstrap: pass the
`lavaan` fit to
[`twolevel_statistic()`](https://data-wise.github.io/medfit/reference/twolevel_statistic.md)
and give
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
the data and `cluster =`. Whole clusters are resampled and the model is
refitted in every replicate. The example uses 30 replicates only to keep
the page fast; use several hundred in a real analysis.

``` r
b <- bootstrap_mediation(
  twolevel_statistic(fit, "nie_between", treatment = "X", mediator = "M", outcome = "Y"),
  method = "nonparametric", data = d, cluster = "id", n_boot = 30, seed = 1
)
c(estimate = b@estimate, lower = b@ci_lower, upper = b@ci_upper, n_used = b@n_boot)
```

      estimate      lower      upper     n_used
     0.5344197  0.3379050  0.7479089 30.0000000 

Report the percentile interval (`ci_lower`, `ci_upper`), not the
standard deviation of the draws: refits with a negative between variance
are kept, and at a few dozen clusters they give heavy tails. Replicates
that fail are excluded and counted in a warning, so check `n_boot` in
the result.

## Step 6: report

State, at minimum: the number of clusters and the cluster sizes; the ICC
of the treatment and the mediator; whether the fit was admissible; the
within and between indirect effects with their intervals and the
interval type; and, if you give the contrast, that it is descriptive.
`summary(td)` prints the provenance of the fit and the assumptions in
full.

``` r
glance(td)
```

    # A tibble: 1 × 8
      nie_within nie_between nie_contrast n_clusters  nobs converged
           <dbl>       <dbl>        <dbl>      <int> <int> <lgl>
    1      0.245       0.534       -0.290        100   500 TRUE
    # ℹ 2 more variables: between_identified <lgl>, admissible <lgl>

## When something goes wrong

Each condition carries a class. The [Troubleshooting
guide](https://data-wise.github.io/medfit/articles/guide-troubleshooting.html#two-level-mediation)
lists every two-level message with its cause and fix, and [Which
interval should I
use?](https://data-wise.github.io/medfit/articles/guide-intervals.md)
compares the interval types.
