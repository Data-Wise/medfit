# medfit Cookbook

Ten task-sized recipes. Each says when to use it, runs on
`mediation_demo` (except the cluster recipe), and links to the article
that explains it. For a one-page lookup see the [Reference
Card](https://data-wise.github.io/medfit/articles/refcard.md).

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
covs <- c("covariate1", "covariate2")
```

## 1. One-line mediation

*When:* one mediator, one outcome, a data frame, and you want an answer
now.

``` r
res <- med(mediation_demo, treatment = "treatment", mediator = "mediator1",
           outcome = "outcome", covariates = covs)
quick(res)
```

    NIE = 0.333  | NDE = 0.206 | PM = 61.8 %

More: [Getting
Started](https://data-wise.github.io/medfit/articles/getting-started.md).

## 2. I already have `lm` fits

*When:* you fitted the mediator and outcome models yourself.

``` r
fit_m <- lm(mediator1 ~ treatment + covariate1 + covariate2, mediation_demo)
fit_y <- lm(outcome ~ treatment + mediator1 + covariate1 + covariate2,
            mediation_demo)
x <- extract_mediation(fit_m, model_y = fit_y,
                       treatment = "treatment", mediator = "mediator1")
tidy(x, type = "effects", conf.int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std.error conf.low conf.high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.333    0.0645  0.206       0.459
    2 nde      0.206    0.110  -0.00936     0.421
    3 te       0.539    0.119   0.304       0.773

More: [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md).

## 3. Binary outcome

*When:* the outcome is 0/1. Fit the outcome with
[`glm()`](https://rdrr.io/r/stats/glm.html); the `b` path and `c'` are
on the logit scale.

``` r
d <- mediation_demo
d$outcome_bin <- as.integer(d$outcome > median(d$outcome))
fit_yb <- glm(outcome_bin ~ treatment + mediator1 + covariate1 + covariate2,
              data = d, family = binomial())
xb <- extract_mediation(fit_m, model_y = fit_yb,
                        treatment = "treatment", mediator = "mediator1")
paths(xb)
```

            a         b   c_prime
    0.5826425 0.8632919 0.1271924 

More: [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md).

## 4. Weights and robust standard errors

*When:* inverse-probability or survey weights. Pair them with
`se_type = "sandwich"`; model-based standard errors are not valid under
inverse-probability weights.

``` r
ps <- glm(treatment ~ covariate1 + covariate2, family = binomial(),
          data = mediation_demo)
p_t <- fitted(ps)
p_m <- mean(mediation_demo$treatment)
ipw <- ifelse(mediation_demo$treatment == 1, p_m / p_t, (1 - p_m) / (1 - p_t))
xw <- fit_mediation(
  outcome ~ treatment + mediator1 + covariate1 + covariate2,
  mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo, treatment = "treatment", mediator = "mediator1",
  weights = ipw, se_type = "sandwich"
)
tidy(xw, type = "effects", conf.int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std.error conf.low conf.high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.335    0.0657   0.206      0.463
    2 nde      0.208    0.115   -0.0180     0.433
    3 te       0.542    0.119    0.308      0.776

More: [Getting
Started](https://data-wise.github.io/medfit/articles/getting-started.md).

## 5. Two mediators in a chain

*When:* treatment, then mediator 1, then mediator 2, then outcome. Put
every mediator in the outcome model.

``` r
fit_m1 <- lm(mediator1 ~ treatment + covariate1 + covariate2, mediation_demo)
fit_m2 <- lm(mediator2 ~ treatment + mediator1 + covariate1 + covariate2,
             mediation_demo)
fit_ys <- lm(outcome ~ treatment + mediator1 + mediator2 + covariate1 +
               covariate2, mediation_demo)
xs <- extract_mediation(fit_m1, model_y = fit_ys, treatment = "treatment",
                        mediator = c("mediator1", "mediator2"),
                        mediator_models = list(fit_m2))
c(chain = unname(nie(xs)), every_path = unname(nie(xs, type = "total")),
  total = unname(te(xs)))
```

         chain every_path      total
    0.07545039 0.36740438 0.53856776 

[`nie()`](https://data-wise.github.io/medfit/reference/nie.md) is the
full chain `a d b`; `type = "total"` adds the paths that skip a
mediator. More: [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md).

## 6. Two mediators side by side

*When:* both mediators are driven by the treatment, neither by the
other.

``` r
fit_m3 <- lm(mediator3 ~ treatment + covariate1 + covariate2, mediation_demo)
fit_yp <- lm(outcome ~ treatment + mediator1 + mediator3 + covariate1 +
               covariate2, mediation_demo)
xp <- extract_mediation(fit_m1, model_y = fit_yp, treatment = "treatment",
                        mediator = c("mediator1", "mediator3"),
                        mediator_models = list(fit_m3), structure = "parallel")
paths(xp)
```

           a1        b1        a2        b2   c_prime
    0.5826425 0.5685676 0.4760604 0.2124038 0.1061791 

``` r
nie(xp)
```

    Natural Indirect Effect (NIE): 0.4324

The effect is the sum of the per-mediator products. More: [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md).

## 7. Treatment-by-mediator interaction

*When:* the outcome model has `treatment * mediator`. You get the
four-way decomposition (CDE, INTref, INTmed, PIE) at a reference
mediator level `m_star`.

``` r
fit_yi <- lm(outcome_int ~ treatment * mediator1 + covariate1 + covariate2,
             mediation_demo)
xi <- extract_mediation(fit_m, model_y = fit_yi, treatment = "treatment",
                        mediator = "mediator1", m_star = 0)
decompose(xi)
```

           cde    int_ref    int_med        pie        nde        nie      total
    0.21521278 0.04353909 0.27709549 0.34001758 0.25875187 0.61711307 0.87586495 

More: [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md).

## 8. Many mediators with products

*When:* several mediators and a treatment-by-mediator term. The result
is the joint effect over the mediator block; bootstrap it with
[`joint_effects()`](https://data-wise.github.io/medfit/reference/joint_effects.md).

``` r
fit_yj <- lm(outcome_int ~ treatment * mediator1 + mediator2 + covariate1 +
               covariate2, mediation_demo)
xj <- extract_mediation(fit_m1, model_y = fit_yj, treatment = "treatment",
                        mediator = c("mediator1", "mediator2"),
                        mediator_models = list(fit_m2))
boot_j <- bootstrap_mediation(
  function(theta) joint_effects(xj, theta)[["nie"]],
  method = "parametric", mediation_data = xj, n_boot = 1000, seed = 1
)
c(estimate = unname(nie(xj)), lower = boot_j@ci_lower, upper = boot_j@ci_upper)
```

     estimate     lower     upper
    0.6560315 0.4351678 0.8930074 

More: [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md).

## 9. Cluster-randomized trial

*When:* the treatment is assigned to whole clusters (schools) and the
mediator and outcome are measured on individuals. Formulas hold fixed
effects only; the engine adds the random cluster intercept.

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
xc <- fit_mediation(Y ~ X + M, M ~ X, data = cdat, treatment = "X",
                    mediator = "M", engine = "lmer", cluster = "school")
tidy(xc, type = "effects", conf.int = TRUE)
```

    # A tibble: 5 × 5
      term      estimate std.error conf.low conf.high
      <chr>        <dbl>     <dbl>    <dbl>     <dbl>
    1 nie         0.209     0.127  -0.0397      0.458
    2 nde         0.0772    0.227  -0.368       0.522
    3 te          0.287     0.241  -0.186       0.760
    4 own         0.103     0.0543 -0.00323     0.210
    5 spillover   0.106     0.0886 -0.0675      0.280

``` r
decompose(xc)
```

          own spillover       nie
    0.1032345 0.1061099 0.2093444
    attr(,"label")
    [1] "cluster-average, large-cluster approximation"

With few clusters add `se_type = "kr"` (needs `pbkrtest`), and bootstrap
whole clusters for the product effects:

``` r
nie_of <- function(dd) {
  unname(nie(fit_mediation(Y ~ X + M, M ~ X, data = dd, treatment = "X",
                           mediator = "M", engine = "lmer", cluster = "school")))
}
boot_c <- bootstrap_mediation(
  nie_of, method = "nonparametric", data = cdat, cluster = "school",
  n_boot = 200, seed = 123
)
```

    Warning in .bootstrap_nonparametric_cluster(data, statistic_fn, n_boot, : 3
    bootstrap samples failed and were excluded (3 of them singular or
    non-convergent refits)

``` r
boot_c
```

    BootstrapResult object
    ======================

    Method:   nonparametric
    Estimate:   0.2093
    N bootstrap samples: 197

    95% Confidence Interval:
      Lower:  -0.0038
      Upper:   0.5241

The warning, when it appears, counts the draws dropped as singular or
non-convergent refits; the interval uses the rest. The own and spillover
split is a large-cluster approximation, and the interval evidence for
the cluster bootstrap is for other designs; see [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md) and
[Bootstrap
Inference](https://data-wise.github.io/medfit/articles/bootstrap.md).

## 10. I use lavaan

*When:* you fitted the model as a structural equation model. The same
accessors apply.

``` r
syntax <- "
  mediator1 ~ a * treatment + covariate1 + covariate2
  outcome ~ b * mediator1 + c_prime * treatment + covariate1 + covariate2
"
sem_fit <- lavaan::sem(syntax, data = mediation_demo)
xl <- extract_mediation(sem_fit, treatment = "treatment",
                        mediator = "mediator1", outcome = "outcome")
tidy(xl, type = "effects", conf.int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std.error conf.low conf.high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.333    0.0642  0.207       0.459
    2 nde      0.206    0.109  -0.00801     0.420
    3 te       0.539    0.119   0.306       0.771

More: [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md).
