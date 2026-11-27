# Two-level mediation (1-1-1)

[Models](https://data-wise.github.io/medfit/articles/models.md) ›
Clusters and latent variables › Two-level mediation (1-1-1)

Treatment, mediator and outcome are all measured on the same level-1
units (students, patients, days) nested in clusters (schools, clinics,
people), and you want the indirect effect at the within level and at the
between level. Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection.

**Experimental.** The two-level API (`TwoLevelMediationData`,
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
on two-level fits, `fit_sem(cluster = )`, `nie(level = )`,
[`twolevel_statistic()`](https://data-wise.github.io/medfit/reference/twolevel_statistic.md))
may change in a later release without the usual deprecation period.

|  |  |
|----|----|
| **Structure** | X, M and Y on level-1 units, with a within part and a between (cluster) part each (a “1-1-1” design) |
| **Class returned** | `TwoLevelMediationData` |
| **Indirect effect** | \\a_w b_w\\ at the within level and \\a_b b_b\\ at the between level; their difference is a descriptive contrast |
| **Route** | [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) on a two-level `lavaan` fit (`level:` blocks, `cluster =`), or on a two-level fit from medfit’s sem engine, `fit_sem(model, data, cluster = )` ([The sem engine route](#the-sem-engine-route)) |
| **Needs** | `lavaan` (Suggests) for the lavaan route; nothing extra for the sem engine |
| **Availability** | lavaan route: version 0.17.0; sem engine route: version 0.20.0 (both **experimental**) |

If the treatment is assigned to whole clusters (a 2-1-1 design), use the
[cluster-randomized
page](https://data-wise.github.io/medfit/articles/model-cluster.md)
instead. If you have a single-level fit that only sets `cluster =` for
robust standard errors, nothing changes: it still extracts as a
`MediationData`.

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
      X -> M -> Y  (clusters: id; lavaan 0.7.3 fit; between level: latent cluster means)
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
`glance(td)` gives one row. The provenance (`summary(td)$provenance`)
records the fitting source, the version of the package that made the fit
(`source_version`; the [`print()`](https://rdrr.io/r/base/print.html)
header shows it too) and the estimation settings.

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

### Which ICC the rule reads

The rule reads the unrestricted (h1) ICC: the between variance over the
total in the saturated two-level model, which `@icc` stores. On the
lavaan route it is `lavaan::lavInspect(fit, "icc")`, with a between-only
variable counted as 1; on the native route medfit estimates the same
saturated moments by an EM algorithm on the per-size cluster summaries.
It is not the ratio the fitted model implies. A fit whose model-implied
level-2 variance is negative used to have that ratio clamped to 0 and so
came out within-only; its h1 ICC is usually above 0.01, so such a fit is
now weak or identified (`admissible` still reports the negative
variance). Within-only is therefore rarer than in earlier development
builds.

Two conditions cover the cases where the h1 ICC is missing or not
settled. A lavaan fit without an h1 estimate (`h1 = FALSE`), or a native
fit whose summaries cannot give one, uses the model-implied ICC and
warns with class `medfit_warning_twolevel_icc_h1_unavailable`. A native
EM that does not converge keeps its last iterate and warns with class
`medfit_warning_twolevel_icc_h1_unconverged`.

The two routes agree on the ICC to about 3e-5 when lavaan’s h1 EM is run
to convergence, but lavaan’s default h1 EM stops early. When an ICC sits
near 0.01 or 0.05 the routes can then fall on opposite sides of a cut:
in about 1 of 50 boundary-heavy simulated datasets we checked, the
within-only or weak call differed between the lavaan route and the
native route. When an ICC is near a cut, tighten the EM in the lavaan
fit with `em.h1.args = list(tol = 1e-10, max_iter = 100000L)` (lavaan
0.7; lavaan 0.6 takes `em.h1.tol = 1e-10` and
`em.h1.iter.max = 100000`), an argument of
[`lavaan::lavaan()`](https://rdrr.io/pkg/lavaan/man/lavaan.html) and
[`lavaan::sem()`](https://rdrr.io/pkg/lavaan/man/sem.html). The
tolerance alone can stop at the default iteration cap and leave the ICC
off the converged value.

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

[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
warns, and never errors, when the fit has fewer than 50 clusters (class
`medfit_warning_twolevel_few_clusters`), on both routes. The 50 is a
judgment: no source gives a cluster count below which two-level
estimates or between-level standard errors are trustworthy. The
threshold is editable with `options(medfit.twolevel_min_clusters = )`.

With few clusters the between-level results are unreliable, and the
within-level results are less affected. Treat the warning, and
`medfit_warning_between_weak` (an ICC below 0.05), as the signal that
the between interval may be missing, wide or too narrow; the
[troubleshooting
guide](https://data-wise.github.io/medfit/articles/guide-troubleshooting.md)
lists both.

The guidance below comes from a simulation study of the lavaan two-level
adapter, fitted with delta-method and Monte Carlo intervals and the
settings medfit ships. It did not run the cluster bootstrap beyond a
small pilot, so it says nothing about how well that bootstrap performs
with few clusters. A fit counts as a failure when lavaan errors, does
not converge or the adapter errors. The study used 5 or 20 units per
cluster and 10 to 100 clusters, and ran before the within-only rule
moved to the unrestricted ICC.

- **Equal cluster sizes** failed in at most .18 of fits at any number of
  clusters in the grid. With 5 units per cluster and an ICC of 0.05 the
  rate stayed above .05 at every number of clusters tried (.097 at 50,
  .059 at 100).
- **Unequal cluster sizes** failed far more often, most of all with 5
  units per cluster and an ICC of 0.05: .93 of fits at 10 clusters, .31
  at 50 and .06 at 100. Failure first fell below .20 for every ICC
  studied only at 100 clusters, the largest number tried. Unequal
  clusters of 5 units therefore fail often even with 50 clusters when
  the ICC is low.
- **The within indirect effect** covered near the nominal level in the
  fits that returned an interval (median .94 to .95 at every number of
  clusters tried). Its overall coverage fell short because failed fits
  return no interval.
- **The between indirect effect** is the weak spot. With an ICC of 0.05
  and 100 clusters its coverage was about .81 (median over the cells),
  because the between interval was available in only about .69 of fits:
  the rest were within-only, failed or inadmissible. More clusters did
  not remove that.

These are simulation results for a few designs, not guarantees. With
fewer than about 50 clusters, and especially with unequal sizes, report
the between-level results as exploratory.

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

## The sem engine route

medfit’s own maximum-likelihood SEM engine (the sem engine) fits the
same model from the same `level:` syntax, without lavaan: give
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
the cluster column. This route is experimental, and new in the
development version. `level: 1` and `level: within` name the within
block; `level: 2`, `level: between` and the cluster column’s name name
the between block.

``` r
nfit <- fit_sem(model, data = d, cluster = "id")
ntd <- extract_mediation(nfit, treatment = "X", mediator = "M", outcome = "Y")
ntd
```

    <TwoLevelMediationData>
      X -> M -> Y  (clusters: id; native 0.21.3 fit; between level: latent cluster means)
      n = 500 in 100 clusters (sizes 5 to 5)   |   ICC: X 0.503, M 0.323, Y 0.400
      a_within = +0.4432   b_within = +0.5518   c_prime_within = +0.2685
      a_between = +0.5595   b_between = +0.9553   c_prime_between = +0.2289
      NIE within  (a_within * b_within)   = +0.2446
      NIE between (a_between * b_between) = +0.5344
      Contrast (within - between)         = -0.2899  (descriptive, not a test)

``` r
ntd@source
```

    [1] "native"

[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
returns the same `TwoLevelMediationData` as the lavaan route, with
`@source` set to `"native"`, so
[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`tidy()`](https://generics.r-lib.org/reference/tidy.html),
[`decompose()`](https://data-wise.github.io/medfit/reference/decompose.md)
and the bootstrap work on it unchanged. The engine fits every exogenous
variable’s moments (the `fixed.x = FALSE` setting; an explicit
`fixed_x = TRUE` is refused) and uses the observed information. It
matches lavaan fitted with
`fixed.x = FALSE, information = "observed", h1.information = "structured"`:

``` r
lfit <- lavaan::sem(model, data = d, cluster = "id", fixed.x = FALSE, information = "observed",
                    h1.information = "structured")
ltd <- extract_mediation(lfit, treatment = "X", mediator = "M", outcome = "Y")
cbind(native = coef(ntd), lavaan = coef(ltd))
```

                       native    lavaan
    a_within        0.4432190 0.4432169
    b_within        0.5517596 0.5517596
    c_prime_within  0.2684745 0.2684742
    a_between       0.5594504 0.5594438
    b_between       0.9552588 0.9552714
    c_prime_between 0.2289369 0.2289345

``` r
cbind(native = sqrt(diag(ntd@vcov)), lavaan = sqrt(diag(ltd@vcov)))
```

                        native     lavaan
    a_within        0.04954385 0.04954396
    b_within        0.05063172 0.05063169
    c_prime_within  0.05496003 0.05496000
    a_between       0.07326930 0.07326872
    b_between       0.19402040 0.19402385
    c_prime_between 0.13375489 0.13375574

The standard errors agree as well. The between-path standard errors of
the default lavaan fit in [Fit it and extract
it](#fit-it-and-extract-it) are slightly different, because that fit
uses `fixed.x = TRUE` ([Standard errors under
`fixed.x = TRUE`](#standard-errors-under-fixed-x-true)).

[`glance()`](https://generics.r-lib.org/reference/glance.html) on the
fit reports the cluster count and the range of cluster sizes, counted
after incomplete rows are dropped. The chi-square test and its p-value
are `NA`, with a note, because the engine fits no saturated two-level
model; `df` and the log likelihood (of both levels together) are
reported.

``` r
glance(nfit)[, c("nobs", "n_clusters", "cluster_size_min", "cluster_size_max", "df", "logLik", "chisq")]
```

    # A tibble: 1 × 7
       nobs n_clusters cluster_size_min cluster_size_max    df logLik chisq
      <int>      <int>            <int>            <int> <int>  <dbl> <dbl>
    1   500        100                5                5     0 -2287.    NA

Level-2 variances are fitted without a floor, so a between-level
variance can come out negative, most often with few or small clusters.
The engine then stops with class `medfit_error_twolevel_inadmissible`
rather than return the solution; the condition carries the fit (`fit`)
and the outcome ledger (`ledger`), whose `admissibility` entry gives the
verdict and the reasons per level. The data below have 30 clusters of 3
and a small between-level variance of the mediator and the outcome:

``` r
d_neg <- withr::with_seed(1, {
  n_neg <- 30
  cl <- sort(rep(seq_len(n_neg), 3))
  xb <- rnorm(n_neg)
  mb <- 0.5 * xb + rnorm(n_neg, sd = 0.3)
  yb <- 0.3 * mb + 0.2 * xb
  x <- xb[cl] + rnorm(length(cl))
  m <- mb[cl] + 0.4 * x + rnorm(length(cl))
  y <- yb[cl] + 0.3 * m + 0.2 * x + rnorm(length(cl), sd = 1.5)
  data.frame(id = cl, X = x, M = m, Y = y)
})

err <- tryCatch(fit_sem(model, data = d_neg, cluster = "id"), error = function(e) e)
class(err)[1]
```

    [1] "medfit_error_twolevel_inadmissible"

``` r
conditionMessage(err)
```

    [1] "the two-level solution is inadmissible: negative level-2 variance: M~~M.l2, Y~~Y.l2; the implied between covariance Sigma_B is not positive definite. Level-2 variances are fitted without a floor (experimental); the fit is kept in the condition (`fit`) as evidence"

``` r
err$ledger$admissibility$between$reasons
```

    [1] "negative level-2 variance: M~~M.l2, Y~~Y.l2"
    [2] "the implied between covariance Sigma_B is not positive definite"

The lavaan route on the same data returns the estimates with the warning
`medfit_warning_twolevel_inadmissible` instead. The sem engine route
refuses latent variables, product terms, `weights`, `missing = "fiml"`,
nonlinear constraints, `fixed_x = TRUE`, `meanstructure = FALSE`,
`information = "expected"` and a variable named only in `level: 1` rows,
each with a classed error whose name starts `medfit_error_twolevel_`;
the full table of messages is in the “Two-level models” section of
[`?"medfit-syntax"`](https://data-wise.github.io/medfit/reference/medfit-syntax.md).
A labeled path, a linear equality across levels and a variable named
only in `level: 2` rows (constant within each cluster) are accepted.

### Cluster-robust standard errors

`se_type = "sandwich"` on a two-level fit gives cluster-robust standard
errors: the sandwich \\A^{-1} B A^{-1}\\ with the observed information
as \\A\\ and \\B = \sum_j s_j s_j'\\ summed over the per-cluster scores
\\s_j\\, with no small-sample factor (CR0). Under an active linear
constraint, such as a path equated across levels, the sandwich is
projected onto the constraint, as in a single-level fit. The estimates
are the same as with the default `se_type = "model"`; only the
covariance changes. It matches lavaan’s `se = "robust.huber.white"` for
the same model:

``` r
nfit_r <- fit_sem(model, data = d, cluster = "id", se_type = "sandwich")
ntd_r <- extract_mediation(nfit_r, treatment = "X", mediator = "M", outcome = "Y")
```

``` r
lfit_r <- lavaan::sem(model, data = d, cluster = "id", fixed.x = FALSE, information = "observed",
                      h1.information = "structured", se = "robust.huber.white")
ltd_r <- extract_mediation(lfit_r, treatment = "X", mediator = "M", outcome = "Y")
cbind(model = sqrt(diag(ntd@vcov)), sandwich = sqrt(diag(ntd_r@vcov)), lavaan = sqrt(diag(ltd_r@vcov)))
```

                         model   sandwich     lavaan
    a_within        0.04954385 0.04901290 0.04901297
    b_within        0.05063172 0.05359923 0.05359928
    c_prime_within  0.05496003 0.05498679 0.05498685
    a_between       0.07326930 0.07204548 0.07204560
    b_between       0.19402040 0.20326265 0.20326800
    c_prime_between 0.13375489 0.13829954 0.13830160

[`print()`](https://rdrr.io/r/base/print.html) and
[`summary()`](https://rdrr.io/r/base/summary.html) of the fit name the
standard errors as cluster-robust with the number of clusters, and
[`glance()`](https://generics.r-lib.org/reference/glance.html) reports
`se_type`. The intervals of
[`confint()`](https://rdrr.io/r/stats/confint.html) and
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) use the
normal reference, and the few-clusters warning still applies: the
cluster sandwich is biased downward with few clusters, and medfit adds
no small-sample correction. Sampling `weights`, product terms, nonlinear
constraints and `information = "expected"` stay refused with
`se_type = "sandwich"` as with the default.

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
      Lower:   0.2980
      Upper:   0.8209

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

## Several parallel mediators

With two or more mediators, none regressed on another,
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
returns the experimental `TwoLevelParallelMediationData`. Each mediator
has its own `a` and `b` path at each level, and the effects come per
level as for one mediator.
[`nie()`](https://data-wise.github.io/medfit/reference/nie.md) adds
`type`: `"total"` (the default) is the sum of the specific effects, and
`"specific"` gives one value per mediator. The contrast is again within
minus between and descriptive. A mediator’s contrast is `NA` only when
both its `a` and its `b` are equated across levels, and the total
contrast only when that holds for every mediator. The formulas and
gradients are in the [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.html#several-parallel-mediators-experimental)
article.

``` r
set.seed(2027)
id_k <- rep(seq_len(100), each = 5)
xb_k <- rnorm(100)[id_k]
xw_k <- rnorm(500)
m1 <- 0.4 * xw_k + 0.7 * xb_k + 0.5 * rnorm(100)[id_k] + rnorm(500)
m2 <- 0.3 * xw_k + 0.5 * xb_k + 0.5 * rnorm(100)[id_k] + rnorm(500)
y_k <- 0.3 * xw_k + 0.2 * xb_k + 0.5 * (m1 - ave(m1, id_k)) + 0.9 * ave(m1, id_k) +
  0.4 * (m2 - ave(m2, id_k)) + 0.6 * ave(m2, id_k) + 0.5 * rnorm(100)[id_k] + rnorm(500)
d_k <- data.frame(id = id_k, X = xb_k + xw_k, M1 = m1, M2 = m2, Y = y_k)
model_k <- "
  level: 1
    M1 ~ X
    M2 ~ X
    Y ~ M1 + M2 + X
  level: 2
    M1 ~ X
    M2 ~ X
    Y ~ M1 + M2 + X
"
fit_k <- lavaan::sem(model_k, data = d_k, cluster = "id")
tk <- extract_mediation(fit_k, treatment = "X", mediator = c("M1", "M2"), outcome = "Y")
nie(tk, level = "both")
```

    Natural Indirect Effect (NIE), both levels: within = 0.3794, between = 1.4093

``` r
nie(tk, type = "specific")
```

    Natural Indirect Effect (NIE): M1 = 0.2294, M2 = 0.1499

``` r
nie(tk, level = "contrast", type = "specific")
```

    Natural Indirect Effect (NIE), within - between contrast: M1 = -0.5667, M2 = -0.4632

``` r
decompose(tk)
```

             within   between   contrast
    M1    0.2294339 0.7961111 -0.5666772
    M2    0.1499245 0.6131525 -0.4632281
    total 0.3793584 1.4092637 -1.0299053
    attr(,"label")
    [1] "descriptive; the contrast is not a test"

``` r
tidy(tk, type = "effects")
```

    # A tibble: 15 × 3
       term            estimate std_error
       <chr>              <dbl>     <dbl>
     1 nie_M1_within      0.229    0.0359
     2 nie_M2_within      0.150    0.0277
     3 nie_within         0.379    0.0451
     4 nde_within         0.255    0.0548
     5 te_within          0.635    0.0618
     6 pm_within          0.598    0.0648
     7 nie_M1_between     0.796    0.161
     8 nie_M2_between     0.613    0.170
     9 nie_between        1.41     0.244
    10 nde_between       -0.201    0.234
    11 te_between         1.21     0.113
    12 pm_between         1.17     0.197
    13 nie_M1_contrast   -0.567    0.170
    14 nie_M2_contrast   -0.463    0.177
    15 nie_contrast      -1.03     0.254 

[`tidy()`](https://generics.r-lib.org/reference/tidy.html) lists each
specific effect, the total, NDE, TE and PM at each level, then the
specific and total contrasts. The standard errors use the joint
covariance of all the paths, so the covariance between two mediators’
paths enters the standard error of the total. Here `@vcov` carries the
covariance of `a_M1` and `a_M2`, which the lm/glm
`ParallelMediationData` leaves out. The between level is kept only when
the ICC of the treatment and of every mediator is at least 0.01; one
mediator without a between part makes the whole result within-only
(`medfit_between_unidentified`).

### Check it against lavaan

[`paths()`](https://data-wise.github.io/medfit/reference/paths.md) names
each path by mediator and level. Label the same model and define the
effects with `:=`; the estimates and standard errors match
[`tidy()`](https://generics.r-lib.org/reference/tidy.html):

``` r
paths(tk)
```

        a_M1_within     a_M2_within     b_M1_within     b_M2_within  c_prime_within
          0.3867350       0.3482710       0.5932587       0.4304822       0.2552809
       a_M1_between    a_M2_between    b_M1_between    b_M2_between c_prime_between
          0.6936137       0.5418557       1.1477732       1.1315790      -0.2008242 

``` r
labeled_k <- "
  level: 1
    M1 ~ a1w*X
    M2 ~ a2w*X
    Y ~ b1w*M1 + b2w*M2 + cw*X
  level: 2
    M1 ~ a1b*X
    M2 ~ a2b*X
    Y ~ b1b*M1 + b2b*M2 + cb*X
  nie_M1_within := a1w*b1w
  nie_within := a1w*b1w + a2w*b2w
  nie_between := a1b*b1b + a2b*b2b
  nie_contrast := (a1w*b1w + a2w*b2w) - (a1b*b1b + a2b*b2b)
"
pe_k <- lavaan::parameterEstimates(lavaan::sem(labeled_k, data = d_k, cluster = "id"))
pe_k <- pe_k[pe_k$op == ":=", ]
tidy_k <- tidy(tk, type = "effects")
tidy_k <- tidy_k[match(pe_k$lhs, tidy_k$term), ]
round(cbind(lavaan_est = pe_k$est, medfit_est = tidy_k$estimate,
            lavaan_se = pe_k$se, medfit_se = tidy_k$std_error), 5)
```

         lavaan_est medfit_est lavaan_se medfit_se
    [1,]    0.22943    0.22943   0.03594   0.03594
    [2,]    0.37936    0.37936   0.04512   0.04512
    [3,]    1.40926    1.40926   0.24362   0.24362
    [4,]   -1.02991   -1.02991   0.25438   0.25438

### One mediator’s paths equated across levels

When both `a` and `b` of one mediator carry the same label at the two
levels, that mediator’s contrast is zero by constraint and is `NA`, with
the warning `medfit_warning_twolevel_constrained`. The other mediator’s
contrast and the total contrast are still returned (lavaan warns that
level-specific fit measures are not available with cross-level
constraints; that warning is lavaan’s, so the fit is wrapped in
[`suppressWarnings()`](https://rdrr.io/r/base/warning.html)):

``` r
model_k_eq <- "
  level: 1
    M1 ~ a1*X
    M2 ~ X
    Y ~ b1*M1 + M2 + X
  level: 2
    M1 ~ a1*X
    M2 ~ X
    Y ~ b1*M1 + M2 + X
"
fit_k_eq <- suppressWarnings(lavaan::sem(model_k_eq, data = d_k, cluster = "id"))
tk_eq <- extract_mediation(fit_k_eq, treatment = "X", mediator = c("M1", "M2"), outcome = "Y")
nie(tk_eq, level = "contrast", type = "specific")
```

    Warning: The contrast NIE_within - NIE_between is NA for nie_M1_contrast: both
    a and b of the mediator are equated across levels, so the contrast is zero by
    constraint. The within and between effects are still reported.

    Natural Indirect Effect (NIE), within - between contrast: M1 =      NA, M2 = -0.4251

``` r
nie(tk_eq, level = "contrast")
```

    Natural Indirect Effect (NIE), within - between contrast: -0.4251

The total contrast equals the M2 contrast here, because the M1 part is
zero by constraint.

[`twolevel_statistic()`](https://data-wise.github.io/medfit/reference/twolevel_statistic.md)
builds the bootstrap callback for several mediators too. `effect` is
`"nie"` (the total, the default), `"nie_j"` (the specific effect of the
mediator named in `specific`), `"nde"` or `"te"`, and `level` is
`"within"` (the default), `"between"` or `"contrast"` (within minus
between, for `"nie"` and `"nie_j"` only). Pass the object for the
parametric bootstrap:

``` r
b_k <- bootstrap_mediation(
  twolevel_statistic(tk, "nie", level = "between"),
  method = "parametric", mediation_data = tk, n_boot = 200, seed = 1
)
b_k_m1 <- bootstrap_mediation(
  twolevel_statistic(tk, "nie_j", specific = "M1"),
  method = "parametric", mediation_data = tk, n_boot = 200, seed = 1
)
rbind(
  total_between = c(estimate = b_k@estimate, lower = b_k@ci_lower, upper = b_k@ci_upper),
  M1_within = c(estimate = b_k_m1@estimate, lower = b_k_m1@ci_lower, upper = b_k_m1@ci_upper)
)
```

                   estimate     lower     upper
    total_between 1.4092637 0.9201005 1.9129799
    M1_within     0.2294339 0.1573649 0.3040551

For the cluster bootstrap, pass the `lavaan` fit with all the mediators,
as in
`twolevel_statistic(fit_k, "nie", level = "between", treatment = "X", mediator = c("M1", "M2"), outcome = "Y")`,
and give
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
the data and `cluster =`, as for one mediator. A refit’s between level
counts as identified only when the treatment and every mediator pass the
ICC check. An invalid `level`, or a contrast asked of `"nde"` or `"te"`,
stops with class `medfit_error_twolevel_level`; an unknown effect or a
missing or unknown `specific` stops with class
`medfit_error_twolevel_unsupported`.

### Testing the indirect effect at one level

[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
tests the indirect effect at one level of a sem engine fit. It needs
labeled paths, so the model below labels them at each level. Each null
refits the model with one path set to 0, on both levels and with the
same clusters; the statistic is the smaller of the likelihood ratios,
referred to chi-square(1) ([Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md)). The
result adds `level` and `n_clusters`.

``` r
model_lab <- "
  level: 1
    M ~ a_w*X
    Y ~ b_w*M + X
  level: 2
    M ~ a_b*X
    Y ~ b_b*M + X
"
nfit_lab <- fit_sem(model_lab, data = d, cluster = "id")
mbco_between <- mbco_sem(nfit_lab, "a_b", "b_b")
mbco_between
```


        Minimum-of-two likelihood-ratio tests (MBCO) for an indirect effect

    data:  a_b * b_b = 0
    MBCO = 19.729, df = 1, p-value = 8.924e-06

``` r
mbco_between$level
```

    [1] "between"

``` r
mbco_between$n_clusters
```

    [1] 100

`mbco_sem(nfit_lab, "a_w", "b_w")` tests the within indirect effect the
same way. On these data the refit with `b_w == 0` gives the outcome a
negative level-2 variance, so that null solution is inadmissible: the
result is unresolved (statistic `NA`), with a warning of class
`medfit_warning_twolevel_inadmissible` that names the refit, and
`$tests` shows which null failed. The statistic is not taken from the
other null alone:

``` r
mbco_within <- mbco_sem(nfit_lab, "a_w", "b_w")
```

    Warning: the refit with `b_w == 0` converged to an inadmissible solution (negative level-2 variance: Y~~Y.l2; the implied between covariance Sigma_B is not positive definite).
    The MBCO statistic is not available (NA); `$tests` lists each refit.

``` r
mbco_within$unresolved
```

    [1] TRUE

``` r
mbco_within$tests[, c("constraint", "converged")]
```

      constraint converged
    1   a_w == 0      TRUE
    2   b_w == 0     FALSE

The test is conservative when both paths are zero, and it is not a test
of the between-minus-within contrast, which stays descriptive ([The
contrast is descriptive](#the-contrast-is-descriptive)). Paths from
different levels (`mbco_sem(fit, "a_w", "b_b")`) stop with class
`medfit_error_twolevel_unsupported`. A null refit with an inadmissible
solution gives statistic `NA` with the warning
`medfit_warning_twolevel_inadmissible`; one that does not converge gives
statistic `NA` with a warning. A warning also flags a level-2 variance
below 0.01 of its implied between plus within variance at a refit, where
chi-square(1) may not hold.
[`compare_lr()`](https://data-wise.github.io/medfit/reference/compare_lr.md)
is not available for a two-level fit yet. A test that the two levels’
indirect effects are equal is a separate function,
`twolevel_equal_indirect(fit)`: the likelihood ratio of the free fit
against the fit with `a_w*b_w == a_b*b_b`, referred to chi-square(1)
(singular where all four paths are 0, and asymptotic in the number of
clusters; `n_boot` gives a parametric bootstrap p-value for few
clusters; replications whose refit is not admissible are dropped and
counted in `boot$n_dropped`, so that p-value is conditional on
admissible refits). The constrained surface has sign twins (flipping the
signs of the within pair, the between pair or both keeps the equality),
which are worse optima of the same constraint: the optimizer’s
starts-disagree warning is not raised when every disagreeing start is
such a twin, and the best start is kept. The twins of the kept fit are
also tried from its estimates (a twin certificate): up to three
single-start local solves at every `n_starts`, a twin refit that fails
is skipped, and the result is not a proof of a global optimum. A worse
twin is therefore not kept with `n_starts = 1`; a twin that ends
inadmissible below the kept fit (a level-2 variance on its boundary) or
with a covariance that is not positive definite makes the result
unresolved, as it does with more starts. The row allows eight sign
patterns; the certificate flips pairs together and reaches the four of
the kept fit’s orbit. The other orbit does hold local optima (30 of 35
small cells, closest gap 0.02 LR), and the kept orbit still won every
time tested (evidence, not a proof). The result’s `twin` element records
what the certificate did (`tried`, `replaced`, `flipped`, `f_gain`,
`unresolved`); `flipped` is read from the signs of the adopted fit
against the kept fit’s: `"within"` or `"between"` when both paths of
that pair changed sign, `"other"` once for any other sign change
(including a path that reaches or leaves zero), and empty when no sign
changed. It costs about 3 to 4 times the time at `n_starts = 1`, about
twice at the default and about 1.3 times at 30 starts; `n_boot` p-values
for a given `seed` can differ from 0.19.0. A constrained fit that is
inadmissible, not positive definite or not converged gives an unresolved
result (statistic `NA`) with a warning, never a number. The descriptive
contrast carries no p-value.

## Limits

- **One mediator or several parallel ones, linear paths, observed
  variables.** Two or more mediators return the experimental
  `TwoLevelParallelMediationData` ([Several parallel
  mediators](#several-parallel-mediators)); a mediator regressed on
  another mediator (serial) stops extraction with class
  `medfit_error_twolevel_unsupported`. Latent variables and non-Gaussian
  outcomes are not part of this adapter.
- **No `standardized = TRUE`.** A standardized two-level path mixes the
  within and the between variances; extraction stops with class
  `medfit_error_twolevel_standardized`.
- **No product terms.** A `:` term in a regression, or `interaction =`,
  stops extraction with class `medfit_error_twolevel_product`.
- **No random slopes.** See the estimand above.
- **The sem engine route has its own refusals** (latent variables,
  products, weights, FIML and more); see [The sem engine
  route](#the-sem-engine-route).
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
| `medfit_warning_between_weak` | warning | the ICC of the treatment or of a mediator is in \[0.01, 0.05) |
| `medfit_warning_twolevel_icc_h1_unavailable` | warning | no h1 ICC (a lavaan fit with `h1 = FALSE`, or native summaries too thin or collinear): the model-implied ICC is used for the within-only rule |
| `medfit_warning_twolevel_icc_h1_unconverged` | warning | native route: the EM for the h1 ICC did not converge; its last iterate is used |
| `medfit_warning_twolevel_constrained` | warning | the contrast is `NA` because both a and b are equated across levels (with several mediators, those of that mediator, or of every mediator for the total) |
| `medfit_warning_twolevel_inadmissible` | warning | lavaan’s `post.check` is `FALSE` (for example a negative variance) |
| `medfit_warning_twolevel_few_clusters` | warning | fewer than 50 clusters |
| `medfit_error_twolevel_inadmissible` | error | sem engine route only: a negative level-2 variance or a non-positive-definite implied covariance at either level. Level-2 variances are fitted without a floor; the condition carries the fit (`fit`) and the ledger (`ledger`). Its message is shown in [The sem engine route](#the-sem-engine-route) |
| `medfit_warning_twolevel_labels_ignored` | warning | `a_label`, `b_label` or `cp_label` was set: the paths are read by variable names and level, not by label |
| `medfit_error_twolevel_standardized` | error | `standardized = TRUE` |
| `medfit_error_twolevel_product` | error | a product term or `interaction =` |
| `medfit_error_twolevel_unsupported` | error | a mediator regressed on another mediator (serial), a covariate passed as a mediator, a duplicate or overlapping role, a variable missing at a level (2-1-1), or an argument that does not apply |
| `medfit_error_twolevel_path_missing` | error | a, b or c’ absent at a level |
| `medfit_error_twolevel_unusable` | error | the within block is unusable: the fit did not converge, or the within covariance is missing or not positive definite |
| `medfit_error_twolevel_level` | error | `level = "contrast"` for [`nde()`](https://data-wise.github.io/medfit/reference/nde.md), [`te()`](https://data-wise.github.io/medfit/reference/te.md) or [`pm()`](https://data-wise.github.io/medfit/reference/pm.md); from [`twolevel_statistic()`](https://data-wise.github.io/medfit/reference/twolevel_statistic.md) with several mediators, an invalid `level` or `level = "contrast"` with `"nde"` or `"te"` |
| `medfit_error_twolevel_constrained` | error | `twolevel_statistic(effect = "nie_contrast")` for a fit that equates both a and b across levels; with several mediators, `level = "contrast"` when both a and b of the mediator (`"nie_j"`) or of every mediator (`"nie"`) are equated |

The messages they carry are quoted in
[Troubleshooting](https://data-wise.github.io/medfit/articles/guide-troubleshooting.html#two-level-mediation).

**Next:** Work a full example: [Two-level workflow, step by
step](https://data-wise.github.io/medfit/articles/guide-twolevel-tutorial.md)

## Related

[Cookbook recipe
23](https://data-wise.github.io/medfit/articles/cookbook.html#a-two-level-lavaan-fit-within-and-between)
\| [Cookbook recipe
24](https://data-wise.github.io/medfit/articles/cookbook.html#two-parallel-mediators-in-a-two-level-lavaan-fit)
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
