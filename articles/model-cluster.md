# Cluster-randomized trials (2-1-1)

The treatment is assigned to whole clusters (schools, clinics); the
mediator and outcome are measured on individuals. Part of the
[Models](https://data-wise.github.io/medfit/articles/models.md)
collection.

|  |  |
|----|----|
| **Structure** | cluster-level X to individual M to individual Y (a “2-1-1” design) |
| **Class returned** | `ClusterMediationData` |
| **Indirect effect** | \\a \\ b\_{\text{between}}\\, split into an own-mediator and a spillover part |
| **Routes** | `fit_mediation(engine = "lmer", cluster = )`, or [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) on a pair of `lmer` fits |
| **Needs** | `lme4`; `pbkrtest` for `se_type = "kr"` |

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
has_lme4 <- requireNamespace("lme4", quietly = TRUE)
has_pbkr <- requireNamespace("pbkrtest", quietly = TRUE)
```

## Fit it

The data below are simulated: 40 schools of 10 students, treatment
assigned by school. The formulas hold fixed effects only; the engine
adds the random cluster intercept and the cluster-mean and
within-cluster terms of the mediator.

``` r
set.seed(2026)
J <- 40
n <- 10
cl <- rep(seq_len(J), each = n)
x_j <- sample(rep(0:1, length.out = J))
v <- rnorm(J, sd = 0.5)
u <- rnorm(J, sd = 0.5)
cdat <- data.frame(school = factor(cl), X = x_j[cl])
cdat$M <- 0.5 * cdat$X + v[cl] + rnorm(J * n)
mbar <- ave(cdat$M, cdat$school)
cdat$Y <- 0.2 * cdat$X + 0.3 * (cdat$M - mbar) + 0.6 * mbar + u[cl] + rnorm(J * n)
```

``` r
x <- fit_mediation(Y ~ X + M, M ~ X, data = cdat, treatment = "X",
                   mediator = "M", engine = "lmer", cluster = "school")
class(x)[1]
```

    [1] "medfit::ClusterMediationData"

``` r
paths(x)
```

             a   b_within  b_between    c_prime
    0.27198520 0.37955931 0.76969028 0.07722813 

The path `b_between` is the effect of a cluster’s mean mediator on the
outcome, `b_within` the effect of an individual’s deviation from the
cluster mean. The indirect effect uses the between-cluster path, because
the treatment moves whole clusters.

## Read it

``` r
tidy(x, type = "effects", conf_int = TRUE)
```

    # A tibble: 5 × 5
      term      estimate std_error conf_low conf_high
      <chr>        <dbl>     <dbl>    <dbl>     <dbl>
    1 nie         0.209     0.127  -0.0397      0.458
    2 nde         0.0772    0.227  -0.368       0.522
    3 te          0.287     0.241  -0.186       0.760
    4 own         0.103     0.0543 -0.00323     0.210
    5 spillover   0.106     0.0886 -0.0675      0.280

``` r
decompose(x)
```

          own spillover       nie
    0.1032345 0.1061099 0.2093444
    attr(,"label")
    [1] "cluster-average, large-cluster approximation"

[`decompose()`](https://data-wise.github.io/medfit/reference/decompose.md)
splits the indirect effect: **own** is the part acting through a
student’s own mediator, **spillover** the part acting through the rest
of the cluster. The split is a large-cluster approximation (the label on
the result says so).

## Few clusters

With fewer than 25 clusters and model-based standard errors, medfit
warns that the intervals can be too small. Two remedies:

``` r
few <- cdat[cdat$school %in% levels(cdat$school)[1:12], ]
few$school <- droplevels(few$school)
fit_few <- function(se) {
  suppressWarnings(fit_mediation(Y ~ X + M, M ~ X, data = few, treatment = "X",
                                 mediator = "M", engine = "lmer",
                                 cluster = "school", se_type = se))
}
rbind(model = confint(fit_few("model"))["b_between", ],
      kr = confint(fit_few("kr"))["b_between", ])
```

               2.5 %   97.5 %
    model -0.7218072 1.236564
    kr    -0.8727810 1.387538

- **`se_type = "kr"`** gives Kenward-Roger t intervals for the paths.
  They are wider, as they should be with 12 clusters (the example above
  shows the `b_between` interval widening).
- **A cluster bootstrap** resamples whole clusters, which is the safer
  interval for the product effects:

``` r
nie_of <- function(dd) {
  unname(nie(fit_mediation(Y ~ X + M, M ~ X, data = dd, treatment = "X",
                           mediator = "M", engine = "lmer", cluster = "school")))
}
bootstrap_mediation(nie_of, method = "nonparametric", data = cdat,
                    cluster = "school", n_boot = 200, seed = 123)
```

    Warning in .bootstrap_nonparametric_cluster(data, statistic_fn, n_boot, : 3
    bootstrap samples failed and were excluded (3 of them singular or
    non-convergent refits)

    BootstrapResult object
    ======================

    Method:   nonparametric
    Estimate:   0.2093
    N bootstrap samples: 197

    95% Confidence Interval:
      Lower:  -0.0038
      Upper:   0.5241

A warning, when it appears, counts the draws dropped as singular or
non-convergent refits; the interval uses the rest.

## Already have `lmer` fits?

[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
takes the pair. The outcome model must carry the mediator’s cluster mean
and its within-cluster deviation as two terms, and both models need the
same rows and the random intercept for the cluster:

``` r
cdat$M_cm <- ave(cdat$M, cdat$school)
cdat$M_cwc <- cdat$M - cdat$M_cm
fm <- lme4::lmer(M ~ X + (1 | school), cdat)
fy <- lme4::lmer(Y ~ X + M_cwc + M_cm + (1 | school), cdat)
x2 <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")
c(from_lmer_pair = unname(nie(x2)), from_engine = unname(nie(x)))
```

    from_lmer_pair    from_engine
         0.2093444      0.2093444 

## Limits

- **The treatment must be constant within a cluster.** If it varies,
  [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  stops with “Treatment `X` varies within clusters; 1-1-1 designs are
  not supported yet”.
- **Gaussian linear mixed models only; no `glmer`.** The default is a
  random intercept. A random slope on the within-cluster mediator term
  is accepted (`engine_args = list(random_y = ~ M)`); a slope on the
  treatment, the cluster mean or the raw mediator is not (for the
  treatment: “A random slope on the treatment (`X`) is not supported: it
  is constant within clusters”).
- **An outcome model without the cluster-mean term fails** with a
  message that names the term to add (for example `M_cwc + M_cm`).
- The own and spillover split is a large-cluster approximation, and the
  interval evidence for the cluster bootstrap is thin; see [Methods and
  Formulas](https://data-wise.github.io/medfit/articles/methods.md).

## Related

[Cookbook recipe
9](https://data-wise.github.io/medfit/articles/cookbook.html#cluster-randomized-trial)
\| [Bootstrap
Inference](https://data-wise.github.io/medfit/articles/bootstrap.md) \|
[Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md) \|
[Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md)
