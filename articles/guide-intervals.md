# Which interval should I use?

medfit gives several intervals. This page says which to reach for, shows
them side by side on one dataset, and states what each one assumes. It
makes no coverage claim beyond what the package’s tests show.

The table below describes objects with the indicated inference methods.
The [bounded FIML
workflow](https://data-wise.github.io/medfit/articles/native-guide.html#bounded-fiml)
currently supports normal path/effect intervals only; bootstrap
intervals, profiles, MBCO and fit tests refuse those objects. Its local
numerical checks do not establish interval coverage. See the native
guide for its model and missingness assumptions.

## Pick by situation

| Your situation | Use | Why |
|----|----|----|
| A quick look, one mediator, a decent sample | `tidy(fit, conf_int = TRUE)` or [`confint()`](https://rdrr.io/r/stats/confint.html) | delta method: instant, and assumes the estimate is roughly normal |
| The indirect effect `a * b`, a final result | parametric bootstrap: `med(boot = TRUE)` | draws from the estimated normal distribution of the paths, so the skew of a product shows up |
| You doubt that normality | nonparametric bootstrap | resamples rows and refits, so it does not rely on a normal approximation |
| Serial mediators fitted from `lm` objects | nonparametric bootstrap, or a lavaan fit | the lm route sets the covariances among chain paths to zero; see [Serial mediation](https://data-wise.github.io/medfit/articles/model-serial.md) |
| Weights | `se_type = "sandwich"` | robust (heteroskedasticity-consistent) standard errors; see [Weights and robust SEs](https://data-wise.github.io/medfit/articles/model-weights.md) |
| Treatment assigned to clusters, 25 or more | model-based intervals for the paths | the engine warns below 25 clusters |
| Treatment assigned to clusters, fewer than 25 | `se_type = "kr"` for the paths; `bootstrap_mediation(cluster = )` for the products | see [Cluster-randomized trials](https://data-wise.github.io/medfit/articles/model-cluster.md) |
| A test that the indirect effect is zero | [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) (native engine) | minimum of two likelihood-ratio tests; see [constraints and MBCO](https://data-wise.github.io/medfit/articles/model-native-constraints.md) |
| Only a point estimate | the plugin method | it has no interval; the bounds are `NA` |

## The same fit, four ways

One simple mediation on `mediation_demo`:

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
fy <- outcome ~ treatment + mediator1 + covariate1 + covariate2
fm <- mediator1 ~ treatment + covariate1 + covariate2
fit <- fit_mediation(fy, fm, data = mediation_demo,
                     treatment = "treatment", mediator = "mediator1")
```

**Delta method** (the default in
[`tidy()`](https://generics.r-lib.org/reference/tidy.html)):

``` r
tidy(fit, type = "effects", conf_int = TRUE)[1, ]
```

    # A tibble: 1 × 5
      term  estimate std_error conf_low conf_high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.333    0.0645    0.206     0.459

**Parametric bootstrap** (what `med(boot = TRUE)` runs). The statistic
is the product of the two paths, named as
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
sees them:

``` r
indirect <- function(theta) theta["m_treatment"] * theta["y_mediator1"]
par_boot <- bootstrap_mediation(indirect, method = "parametric",
                                mediation_data = fit, n_boot = 2000, seed = 1)
c(lower = par_boot@ci_lower, upper = par_boot@ci_upper)
```

        lower     upper
    0.2107017 0.4689658 

**Nonparametric bootstrap** (resamples rows and refits):

``` r
refit_nie <- function(d) {
  unname(nie(fit_mediation(fy, fm, data = d, treatment = "treatment",
                           mediator = "mediator1")))
}
np_boot <- bootstrap_mediation(refit_nie, method = "nonparametric",
                               data = mediation_demo, n_boot = 1000, seed = 1)
c(lower = np_boot@ci_lower, upper = np_boot@ci_upper)
```

        lower     upper
    0.2100149 0.4682970 

**Plugin** (a point estimate only):

``` r
plug <- bootstrap_mediation(indirect, method = "plugin", mediation_data = fit)
c(estimate = unname(plug@estimate), lower = plug@ci_lower, upper = plug@ci_upper)
```

     estimate     lower     upper
    0.3327695        NA        NA 

On this dataset the three intervals agree to within about 0.01, which is
what to expect when the sample is large and the model is simple. They
part ways with small samples, skewed variables, weights or few clusters.

## What each one assumes

| Interval | Assumes | Cost |
|----|----|----|
| Delta method | the estimate is approximately normal, with the standard error from the model | none |
| Parametric bootstrap | the path estimates are approximately jointly normal | fast; no refitting |
| Nonparametric bootstrap | the rows are independent draws | slow; refits every time |
| Plugin | nothing; it gives no interval | none |
| Kenward-Roger | a linear mixed model with a random intercept | needs `pbkrtest` |
| Cluster bootstrap | clusters are the independent units | refits every time; some refits may fail |

All the bootstrap intervals are **percentile** intervals (the 2.5th and
97.5th percentiles for a 95% interval). BCa and studentized intervals
are not implemented.

## Two messages to expect

`confint(fit, parm = "effects")` warns that the normal approximation for
the indirect effect may be inaccurate. That is a nudge toward the
bootstrap, not an error;
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) gives the
same delta-method interval without the warning.

A bootstrap warns when refits fail and are dropped; see
[Troubleshooting](https://data-wise.github.io/medfit/articles/guide-troubleshooting.md).

## Limits

- **No coverage claim.** This page shows intervals from one dataset; it
  does not show that they cover 95% of the time. The evidence for the
  cluster bootstrap on the 2-1-1 design is thin; [Methods and
  Formulas](https://data-wise.github.io/medfit/articles/methods.md) says
  so.
- **Percentile intervals only.**
- **Standard errors under weights** need `se_type = "sandwich"` (the
  sandwich treats observations as independent).

## Related

[Bootstrap
Inference](https://data-wise.github.io/medfit/articles/bootstrap.md) \|
[Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md) \|
[Troubleshooting](https://data-wise.github.io/medfit/articles/guide-troubleshooting.md)
