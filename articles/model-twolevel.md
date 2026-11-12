# Two-level mediation (1-1-1)

Treatment, mediator and outcome are all measured on the same level-1
units (students, patients, days) nested in clusters (schools, clinics,
people), and you want the indirect effect at the within level and at the
between level. Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection.

**Experimental.** The two-level API (`TwoLevelMediationData`,
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
on two-level fits, `nie(level = )`,
[`twolevel_statistic()`](https://data-wise.github.io/medfit/reference/twolevel_statistic.md))
may change in a later release without the usual deprecation period.

|  |  |
|----|----|
| **Structure** | X, M and Y on level-1 units, with a within part and a between (cluster) part each (a “1-1-1” design) |
| **Class returned** | `TwoLevelMediationData` |
| **Indirect effect** | \\a_w b_w\\ at the within level and \\a_b b_b\\ at the between level; their difference is a descriptive contrast |
| **Route** | [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) on a two-level `lavaan` fit (`level:` blocks, `cluster =`) |
| **Needs** | `lavaan` (Suggests) |
| **Availability** | version 0.17.0 (**experimental**) |

If the treatment is assigned to whole clusters (a 2-1-1 design), use the
[cluster-randomized
page](https://data-wise.github.io/medfit/articles/model-cluster.md)
instead. If you have a single-level fit that only sets `cluster =` for
robust standard errors, nothing changes: it still extracts as a
`MediationData`.

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

## What is estimated

lavaan’s two-level model splits each variable into a within part (a
unit’s deviation from its cluster) and a between part (the cluster’s own
level, a *latent* cluster mean). The same three regressions, M on X, Y
on M and X, are fitted at both levels. medfit reads the six slopes and
their joint covariance from the fit and reports, per level,

- the indirect effect NIE = \\a \\ b\\, the direct effect NDE = \\c'\\
  and the total effect TE = NIE + \\c'\\;
- the proportion mediated NIE / TE.

The estimand is the **fixed-slope** one: the paths do not vary across
clusters (no random slopes, so the covariance of the cluster-specific
\\a_j\\ and \\b_j\\ is taken to be zero), and the between effects run
through latent cluster means. Nothing is defined across levels, so there
is no cross-level total effect and no cross-level proportion mediated.
The formulas, the gradients and the cross-level covariance are in the
[Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.html#two-level-mediation-1-1-1)
article.

Two caveats belong to the estimand, not to the software:

- **Fixed versus random slopes.** With random slopes the average
  indirect effect in the population of clusters is \\ab +
  \sigma\_{ab}\\, not \\ab\\ (Kenny, Korchmaros and Bolger, 2003; Bauer,
  Preacher and Gil, 2006). medfit’s number is the fixed-slope \\ab\\ and
  equals the average only when the covariance of the cluster-specific
  \\a_j\\ and \\b_j\\ is zero. The adapter does not fit random slopes.
- **Latent versus manifest cluster means.** Using latent cluster means
  (what lavaan’s two-level model does) or observed cluster means is a
  modeling choice with a causal story attached, not a technicality
  (Preacher, Zyphur and Zhang, 2010; Lüdtke et al., 2008). Observed
  means carry sampling error when clusters are small, which biases the
  between slopes. medfit stores `between_parameterization = "latent"`
  and does not offer the manifest alternative.

## Fit it and extract it

The data are simulated: 100 clusters of 5 units, a treatment with within
and between variance, and known within and between slopes. The model
writes the same regressions at both levels.

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
td <- extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y")
td
```

    <TwoLevelMediationData>
      X -> M -> Y  (clusters: id; lavaan fit; between level: latent cluster means)
      n = 500 in 100 clusters (sizes 5 to 5)   |   ICC: X 0.503, M 0.323, Y 0.400
      a_within = +0.4432   b_within = +0.5518   c_prime_within = +0.2685
      a_between = +0.5594   b_between = +0.9553   c_prime_between = +0.2289
      NIE within  (a_within * b_within)   = +0.2446
      NIE between (a_between * b_between) = +0.5344
      Contrast (within - between)         = -0.2899  (descriptive, not a test)

[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
reads the fit; it never refits. It finds each path by the variable names
and the level, not by label, and takes the covariance of the six slopes
as the matching sub-block of lavaan’s joint covariance, so the
covariance between a within and a between slope is carried into every
standard error. The object also stores the intraclass correlation (ICC)
of each variable, the cluster sizes, and how the fit was made
(`fixed_x`, the information matrix, the estimator and how missing data
were handled).

## Read it

[`nie()`](https://data-wise.github.io/medfit/reference/nie.md) takes a
`level`: `"within"` (the default), `"between"`, `"contrast"` (within
minus between) or `"both"`.
[`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
[`te()`](https://data-wise.github.io/medfit/reference/te.md) and
[`pm()`](https://data-wise.github.io/medfit/reference/pm.md) take
`"within"`, `"between"` or `"both"`.

``` r
nie(td)
```

    Natural Indirect Effect (NIE): 0.2446

``` r
nie(td, level = "between")
```

    Natural Indirect Effect (NIE), between level: 0.5344

``` r
nie(td, level = "both")
```

    Natural Indirect Effect (NIE), both levels: within = 0.2446, between = 0.5344

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

[`tidy()`](https://generics.r-lib.org/reference/tidy.html) lists the six
paths, the four effects at each level, and the contrast. Standard errors
come from the delta method over the joint covariance; the intervals are
Wald (normal) intervals with no small-sample correction. `summary(td)`
adds the provenance of the fit and prints the assumptions in full, and
`glance(td)` gives one row.

``` r
summary(td)
```

    Summary of TwoLevelMediationData
    ================================

    X -> M -> Y, clusters `id`

    Path coefficients:
                    estimate std_error
    a_within          0.4432    0.0495
    b_within          0.5518    0.0506
    c_prime_within    0.2685    0.0550
    a_between         0.5594    0.0732
    b_between         0.9553    0.1940
    c_prime_between   0.2289    0.1337

    Effects (unit contrast 0 -> 1):
                 estimate std_error conf_low conf_high
    nie_within     0.2446    0.0354   0.1752    0.3139
    nde_within     0.2685    0.0550   0.1608    0.3762
    te_within      0.5130    0.0571   0.4010    0.6250
    pm_within      0.4767    0.0697   0.3400    0.6134
    nie_between    0.5344    0.1272   0.2852    0.7837
    nde_between    0.2289    0.1337  -0.0331    0.4909
    te_between     0.7634    0.0935   0.5801    0.9466
    pm_between     0.7001    0.1632   0.3802    1.0200
    nie_contrast  -0.2899    0.1372  -0.5589   -0.0209
      95% Wald intervals (delta method over the joint covariance).
      The contrast (within - between NIE) is descriptive, not a test.

    Sample Size: 500 in 100 clusters (sizes 5 to 5)
    ICC:         X 0.503, M 0.323, Y 0.400
    Fit:         lavaan 0.7.3 (estimator ML, fixed_x TRUE, information observed, h1_information structured, se standard, missing listwise)

    Estimand and assumptions:
      Design: treatment `X`, mediator `M` and outcome `Y` measured on level-1 units in 100
        clusters (`id`); the paths are estimated separately at the within and the between
        level.
      - Fixed slopes (no random slopes); between effects are through latent cluster means.
      - Linear paths with no mediator-by-treatment product; no confounding of the paths
        beyond the model.
      - Per level NIE = a * b, NDE = c', TE = NIE + c'; the contrast is within minus
        between NIE.
      - No cross-level total effect or proportion mediated is defined.
      - Intervals are Wald (delta method); there is no small-sample correction.
      - fixed_x is TRUE: the between-path standard errors are conditional on the sample
        between-level moments of the treatment; refit with fixed.x = FALSE for the
        unconditional ones.

### Check it against something simple

The within paths are the least-squares slopes on data centered at each
cluster’s mean. The maximum-likelihood and least-squares estimates
differ slightly, so the two agree closely, not exactly:

``` r
dc <- data.frame(Xc = d$X - ave(d$X, d$id), Mc = d$M - ave(d$M, d$id), Yc = d$Y - ave(d$Y, d$id))
ols <- c(a = unname(coef(lm(Mc ~ 0 + Xc, dc))["Xc"]),
         b = unname(coef(lm(Yc ~ 0 + Mc + Xc, dc))["Mc"]),
         c_prime = unname(coef(lm(Yc ~ 0 + Mc + Xc, dc))["Xc"]))
round(rbind(medfit = paths(td)[1:3], ols_on_centered_data = ols), 4)
```

                         a_within b_within c_prime_within
    medfit                 0.4432   0.5518         0.2685
    ols_on_centered_data   0.4432   0.5518         0.2685

The between slopes have no such shortcut: a regression on observed
cluster means is a different (manifest) model. Compare them with
lavaan’s own defined parameters instead:

``` r
labeled <- "
  level: 1
    M ~ aw*X
    Y ~ bw*M + cw*X
  level: 2
    M ~ ab*X
    Y ~ bb*M + cb*X
  nie_within := aw*bw
  nie_between := ab*bb
  nie_contrast := aw*bw - ab*bb
"
pe <- lavaan::parameterEstimates(lavaan::sem(labeled, data = d, cluster = "id"))
rbind(lavaan = pe[pe$op == ":=", "se"],
      medfit = tidy(td, type = "effects")$std_error[c(1, 5, 9)])
```

                 [,1]      [,2]      [,3]
    lavaan 0.03536782 0.1271784 0.1372484
    medfit 0.03536782 0.1271784 0.1372484

## The contrast is descriptive

`nie(td, level = "contrast")` is the within NIE minus the between NIE,
with a delta-method standard error. It describes how the two levels
differ in this fit. It is **not a test**: medfit makes no claim that a
contrast interval excluding zero shows the levels differ in the
population, and no source supports the contrast as a named test. It is
returned unless both `a` and `b` are equated across levels (see below).
`decompose(td)` returns the within, between and contrast values without
a standard error and labels them descriptive.

``` r
decompose(td)
```

        within    between   contrast
     0.2445538  0.5344197 -0.2898659
    attr(,"label")
    [1] "descriptive; the contrast is not a test"

## When the between level is not identified

The between slopes need between-cluster variance in the treatment (for
\\a_b\\) and in the mediator (for \\b_b\\). When the ICC of either is
below 0.01, a between covariance is not finite, the joint covariance of
the paths is not positive definite, or the fit did not converge, the
object is **within-only**: the between properties are `NA`, the between
rows are absent from `estimates` and `vcov`, and extraction warns with
class `medfit_between_unidentified`. The between effects and the
contrast then return `NA` with the same warning, never an error and
never `0 +/- 0`.

The chunk below removes the treatment’s between variance by centering it
within clusters (lavaan may warn about the degenerate between level; the
warning is lavaan’s, so the fit is wrapped in
[`suppressWarnings()`](https://rdrr.io/r/base/warning.html)):

``` r
d0 <- d
d0$X <- d$X - ave(d$X, d$id)
fit0 <- suppressWarnings(lavaan::sem(model, data = d0, cluster = "id"))
caught <- NULL
td0 <- withCallingHandlers(
  extract_mediation(fit0, treatment = "X", mediator = "M", outcome = "Y"),
  warning = function(w) {
    caught <<- w
    invokeRestart("muffleWarning")
  }
)
class(caught)[1]
```

    [1] "medfit_between_unidentified"

``` r
td0@between_identified
```

    [1] FALSE

``` r
paths(td0)
```

           a_within        b_within  c_prime_within       a_between       b_between
          0.4432175       0.5517617       0.2684714              NA              NA
    c_prime_between
                 NA 

``` r
suppressWarnings(nie(td0, level = "between"))
```

    Natural Indirect Effect (NIE), between level: NA

A treatment ICC between 0.01 and 0.05 (or the same for the mediator)
keeps the between results and warns with class
`medfit_warning_between_weak`: they may be imprecise. These thresholds,
0.01 and 0.05, are judgments, not published cutoffs; they are the
options `medfit.between_icc_error` and `medfit.between_icc_warn`.

## Paths equated across levels

If you give the same label to a path at both levels (`M ~ a*X` in both
blocks) or add `a == a2`, lavaan estimates one parameter for both. The
object lists the equated paths in `cross_level_equal`. medfit finds an
equated path three ways: a shared free parameter or label, an `==` row
between the two labels, and a numeric check of the fit itself. The
numeric check records a path as equated when the estimated difference of
its two level estimates and the variance of that difference are both
effectively zero: \\\|\hat\theta_w - \hat\theta_b\| \le 10^{-6} \max(1,
\|\hat\theta_w\|, \|\hat\theta_b\|)\\ and
\\\operatorname{Var}(\hat\theta_w - \hat\theta_b) \le 10^{-10}
(V\_{ww} + V\_{bb})\\. Those two defaults are the options
`medfit.twolevel_equal_diff` and `medfit.twolevel_equal_var`. The check
finds an algebraic equality that lavaan keeps as two parameters (for
example `a^2 - a2^2 == 0`). A constant offset between the two levels
(`a2 == a + 0.01`) is a constraint but not an equality, so it is not
flagged unless it is smaller than the tolerance, where the paths are
equal to that precision. It never uses the correlation of the two
estimates: a correlation of \\-1\\, or of \\+1\\ between proportional
but unequal paths, does not mean the paths are equal, and the contrast
would silently become `NA`.

The contrast follows the equated paths. With **only one** of `a` or `b`
equated, the contrast stays an estimate: with `a` equated it is \\a
(b_w - b_b)\\, with `b` equated it is \\(a_w - a_b) b\\, each with a
delta-method standard error from the joint covariance (the cross-level
covariance of the equated pair enters the gradient). It is still
descriptive, not a test. Only when **both** `a` and `b` are equated is
the contrast zero by constraint, not an estimate: it is `NA` and carries
the warning `medfit_warning_twolevel_constrained`. The chunk below
checks the `a`-only contrast and its standard error against lavaan’s own
`:=` definition.

``` r
shared <- "
  level: 1
    M ~ a*X
    Y ~ b*M + X
  level: 2
    M ~ a*X
    Y ~ b2*M + X
  nc := a*b - a*b2
"
fit_eq <- suppressWarnings(lavaan::sem(shared, data = d, cluster = "id"))
td_eq <- extract_mediation(fit_eq, treatment = "X", mediator = "M", outcome = "Y")
td_eq@cross_level_equal
```

    [1] "a"

``` r
eff_eq <- tidy(td_eq, type = "effects")
eff_eq[eff_eq$term == "nie_contrast", ]
```

    # A tibble: 1 × 3
      term         estimate std_error
      <chr>           <dbl>     <dbl>
    1 nie_contrast   -0.199     0.102

``` r
pe_eq <- lavaan::parameterEstimates(fit_eq)
pe_eq[pe_eq$op == ":=", c("est", "se")]
```

          est    se
    19 -0.199 0.102

``` r
nie(td_eq, level = "between")
```

    Natural Indirect Effect (NIE), between level: 0.4644

With both equated, the contrast is `NA` and
[`twolevel_statistic()`](https://data-wise.github.io/medfit/reference/twolevel_statistic.md)
refuses it.

``` r
shared_ab <- "
  level: 1
    M ~ a*X
    Y ~ b*M + X
  level: 2
    M ~ a*X
    Y ~ b*M + X
"
fit_eq2 <- suppressWarnings(lavaan::sem(shared_ab, data = d, cluster = "id"))
td_eq2 <- extract_mediation(fit_eq2, treatment = "X", mediator = "M", outcome = "Y")
td_eq2@cross_level_equal
```

    [1] "a" "b"

``` r
suppressWarnings(nie(td_eq2, level = "contrast"))
```

    Natural Indirect Effect (NIE), within - between contrast: NA

## Few clusters

The adapter warns, and never errors, when the fit has fewer than 50
clusters (class `medfit_warning_twolevel_few_clusters`). The 50 is a
judgment: no source gives a cluster count below which two-level
estimates or between-level standard errors are trustworthy. In medfit’s
development simulations with 20 clusters, lavaan’s admissibility check
failed in a noticeable share of fits and the between indirect effect’s
intervals covered below the nominal level. The threshold is editable
with `options(medfit.twolevel_min_clusters = )`.

## Standard errors under `fixed.x = TRUE`

lavaan’s [`sem()`](https://rdrr.io/pkg/lavaan/man/sem.html) fixes the
exogenous variables at their sample values by default
(`fixed.x = TRUE`), and the object records this as `fixed_x`. Under it
the between-path standard errors are conditional on the sample
between-level moments of the treatment; refit with `fixed.x = FALSE` for
the unconditional ones. medfit reads the standard errors lavaan reports
and does not adjust them;
[`summary()`](https://rdrr.io/r/base/summary.html) prints a note when
`fixed_x` is `TRUE`.

## Bootstrap

[`twolevel_statistic()`](https://data-wise.github.io/medfit/reference/twolevel_statistic.md)
turns one two-level effect into the scalar statistic that
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
needs. The `effect` is `"nie_within"`, `"nie_between"`,
`"nie_contrast"`, the other per-level effects (`"nde_*"`, `"te_*"`,
`"pm_*"`) or one of the six paths. The first argument decides the route:

- **Parametric** (and `"plugin"`): pass the `TwoLevelMediationData`.
  Each draw comes from the normal distribution of the six paths with
  their joint covariance, so the cross-level covariance is part of every
  draw. This is fast and has the same normality assumption as the delta
  method.
- **Cluster (nonparametric)**: pass the `lavaan` fit and the roles
  (`treatment`, `mediator`, `outcome`), and give
  [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
  the data and `cluster =`. Each replicate resamples whole clusters and
  refits the model stored in the fit’s own call, with only the standard
  errors, the model test and lavaan’s post-check switched off
  (`se = "none"`, `test = "none"`, `check.post = FALSE`; none changes
  the point estimates). A cluster drawn twice is refitted as two
  clusters.

``` r
b_par <- bootstrap_mediation(
  twolevel_statistic(td, "nie_between"),
  method = "parametric", mediation_data = td, n_boot = 1000, seed = 1
)
b_par
```

    BootstrapResult object
    ======================

    Method:   parametric
    Estimate:   0.5344
    N bootstrap samples: 1000

    95% Confidence Interval:
      Lower:   0.2901
      Upper:   0.8234

``` r
b_cl <- bootstrap_mediation(
  twolevel_statistic(fit, "nie_between", treatment = "X", mediator = "M", outcome = "Y"),
  method = "nonparametric", data = d, cluster = "id", n_boot = 30, seed = 1
)
c(estimate = b_cl@estimate, n_boot = b_cl@n_boot)
```

      estimate     n_boot
     0.5344197 30.0000000 

Both routes report the point estimate of the original fit, which equals
`nie(td, level = "between")`. The cluster call here uses 30 replicates
only to keep the page fast; use at least several hundred for an
interval.

Three things to know about the cluster route:

- **Report the percentile interval, not the standard deviation.** Refits
  that are inadmissible (for example, a negative between variance) are
  kept, because the point estimate keeps them too and the percentile
  interval is defined on the same footing. At a few dozen clusters such
  boundary refits give the between effects and the contrast heavy tails,
  so the plain standard deviation of the draws can exceed the delta
  standard error while the percentile interval stays close to it. Use
  `ci_lower` and `ci_upper` and do not treat the standard deviation of
  `boot_estimates` as a standard error.
- **Failed replicates are counted.** A refit that errors, warns, does
  not converge, or leaves the between level unidentified in that
  resample (an ICC below `medfit.between_icc_error`) is excluded and the
  count is reported in a warning
  (`bootstrap samples failed and were excluded`); `n_boot` in the result
  is the number of replicates that were used.
- **Constructing the callback can fail.** A between effect or the
  contrast of a within-only fit stops with class
  `medfit_between_unidentified`, and the contrast of a fit that equates
  both a and b across levels stops with class
  `medfit_error_twolevel_constrained`, instead of bootstrapping a
  distribution of `NA`. A `lavaan` fit without `treatment`, `mediator`
  and `outcome` stops with class `medfit_error_twolevel_unsupported`.

``` r
err_within_only <- tryCatch(
  twolevel_statistic(td0, "nie_between"),
  medfit_between_unidentified = function(e) class(e)[1]
)
err_constrained <- tryCatch(
  twolevel_statistic(td_eq2, "nie_contrast"),
  medfit_error_twolevel_constrained = function(e) class(e)[1]
)
c(err_within_only, err_constrained)
```

    [1] "medfit_between_unidentified"       "medfit_error_twolevel_constrained"

Passing an object to
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
and having it choose the cluster route by itself is not available; the
two calls above are the supported ones.

## Limits

- **One mediator, linear paths, observed variables.** A second mediator
  stops extraction with class `medfit_error_twolevel_unsupported`.
  Latent variables and non-Gaussian outcomes are not part of this
  adapter.
- **No `standardized = TRUE`.** A standardized two-level path mixes the
  within and the between variances; extraction stops with class
  `medfit_error_twolevel_standardized`.
- **No product terms.** A `:` term in a regression, or `interaction =`,
  stops extraction with class `medfit_error_twolevel_product`.
- **No random slopes.** See the estimand above.
- **Three-level and multigroup fits are refused**, with classes
  `medfit_error_lavaan_multilevel` and `medfit_error_lavaan_multigroup`.
- **The treatment and the mediator must be in the model at both
  levels.** A treatment assigned to whole clusters is a 2-1-1 design and
  is fitted with `fit_mediation(engine = "lmer", cluster = )`; the error
  is class `medfit_error_twolevel_unsupported`.
- **Each path must appear once at each level** (`M ~ X`, `Y ~ M`,
  `Y ~ X`). A path that is absent at a level is not assumed to be 0; the
  error is class `medfit_error_twolevel_path_missing`.
- **`level = "contrast"` belongs to
  [`nie()`](https://data-wise.github.io/medfit/reference/nie.md) only.**
  [`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
  [`te()`](https://data-wise.github.io/medfit/reference/te.md) and
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) refuse it
  (class `medfit_error_twolevel_level`); use
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) for those
  contrasts.

## Conditions it can signal

Each class is a condition class, so
[`tryCatch()`](https://rdrr.io/r/base/conditions.html) and
[`withCallingHandlers()`](https://rdrr.io/r/base/conditions.html) can
target one. A warning that you have decided to accept can be muffled by
class (see
[Troubleshooting](https://data-wise.github.io/medfit/articles/guide-troubleshooting.html#two-level-mediation)).

| Class | Kind | When |
|----|----|----|
| `medfit_between_unidentified` | warning (error from [`twolevel_statistic()`](https://data-wise.github.io/medfit/reference/twolevel_statistic.md)) | the between level is not identified: the result is within-only. Also from a between accessor on a within-only object; [`twolevel_statistic()`](https://data-wise.github.io/medfit/reference/twolevel_statistic.md) stops with this class for a between effect or the contrast |
| `medfit_warning_between_weak` | warning | the ICC of the treatment or the mediator is in \[0.01, 0.05) |
| `medfit_warning_twolevel_constrained` | warning | the contrast is `NA` because both a and b are equated across levels |
| `medfit_warning_twolevel_inadmissible` | warning | lavaan’s `post.check` is `FALSE` (for example a negative variance) |
| `medfit_warning_twolevel_few_clusters` | warning | fewer than 50 clusters |
| `medfit_warning_twolevel_labels_ignored` | warning | `a_label`, `b_label` or `cp_label` was set: the paths are read by variable names and level, not by label |
| `medfit_error_twolevel_standardized` | error | `standardized = TRUE` |
| `medfit_error_twolevel_product` | error | a product term or `interaction =` |
| `medfit_error_twolevel_unsupported` | error | more than one mediator, a variable missing at a level (2-1-1), or an argument that does not apply |
| `medfit_error_twolevel_path_missing` | error | a, b or c’ absent at a level |
| `medfit_error_twolevel_unusable` | error | the within block is unusable: the fit did not converge, or the within covariance is missing or not positive definite |
| `medfit_error_twolevel_level` | error | `level = "contrast"` for [`nde()`](https://data-wise.github.io/medfit/reference/nde.md), [`te()`](https://data-wise.github.io/medfit/reference/te.md) or [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) |
| `medfit_error_twolevel_constrained` | error | `twolevel_statistic(effect = "nie_contrast")` for a fit that equates both a and b across levels |

The messages they carry are quoted in
[Troubleshooting](https://data-wise.github.io/medfit/articles/guide-troubleshooting.html#two-level-mediation).

## Related

[Cookbook recipe
23](https://data-wise.github.io/medfit/articles/cookbook.html#a-two-level-lavaan-fit-within-and-between)
\| [lavaan
fits](https://data-wise.github.io/medfit/articles/model-lavaan.md) \|
[Cluster-randomized
trials](https://data-wise.github.io/medfit/articles/model-cluster.md) \|
[Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.html#two-level-mediation-1-1-1)

## References

Bauer, D. J., Preacher, K. J., & Gil, K. M. (2006). Conceptualizing and
testing random indirect effects and moderated mediation in multilevel
models. *Psychological Methods*, 11(2), 142-163.
<https://doi.org/10.1037/1082-989X.11.2.142>

Kenny, D. A., Korchmaros, J. D., & Bolger, N. (2003). Lower level
mediation in multilevel models. *Psychological Methods*, 8(2), 115-128.
<https://doi.org/10.1037/1082-989X.8.2.115>

Lüdtke, O., Marsh, H. W., Robitzsch, A., Trautwein, U., Asparouhov, T.,
& Muthén, B. (2008). The multilevel latent covariate model: A new, more
reliable approach to group-level effects in contextual studies.
*Psychological Methods*, 13(3), 203-229.
<https://doi.org/10.1037/a0012869>

Preacher, K. J., Zyphur, M. J., & Zhang, Z. (2010). A general multilevel
SEM framework for assessing multilevel mediation. *Psychological
Methods*, 15(3), 209-233. <https://doi.org/10.1037/a0020141>
