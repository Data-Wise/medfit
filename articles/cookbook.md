# medfit Cookbook

Eighteen task-sized recipes. Each says when to use it, runs on
`mediation_demo` (except the cluster and latent-mediator recipes, which
simulate their data), and links to the article that explains it. For a
one-page lookup see the [Reference
Card](https://data-wise.github.io/medfit/articles/refcard.md).

These recipes need medfit 0.8.0 or later (recipe 18 needs 0.9.0, and the
native route in recipe 7 needs 0.10.0). CRAN has 0.3.2, which lacks
`mediation_demo` and the native, joint and cluster functions; install
from GitHub or r-universe (see the [home
page](https://data-wise.github.io/medfit/#installation)).

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
tidy(x, type = "effects", conf_int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std_error conf_low conf_high
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
fit_m <- lm(mediator1 ~ treatment + covariate1 + covariate2, mediation_demo)
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

*When:* inverse-probability weights, or case weights for independent
observations. Pair them with `se_type = "sandwich"`; model-based
standard errors are not valid under inverse-probability weights. The
sandwich (HC3) standard errors treat the observations as independent, so
they do not handle survey clusters, strata or replicate weights.

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
tidy(xw, type = "effects", conf_int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std_error conf_low conf_high
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
fit_m1 <- lm(mediator1 ~ treatment + covariate1 + covariate2, mediation_demo)
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
fit_m <- lm(mediator1 ~ treatment + covariate1 + covariate2, mediation_demo)
fit_yi <- lm(outcome_int ~ treatment * mediator1 + covariate1 + covariate2,
             mediation_demo)
xi <- extract_mediation(fit_m, model_y = fit_yi, treatment = "treatment",
                        mediator = "mediator1", m_star = 0)
decompose(xi)
```

           cde    int_ref    int_med        pie        nde        nie      total
    0.21521278 0.04353909 0.27709549 0.34001758 0.25875187 0.61711307 0.87586495 

The native engine gives the same parts from model syntax (0.10.0 or
later): write the product as `treatment:mediator1`. The fit warns once
that the global model test is not available for a product of a
regression target.

``` r
sem_i <- suppressWarnings(fit_sem(
  "mediator1 ~ treatment + covariate1 + covariate2
   outcome_int ~ treatment + mediator1 + treatment:mediator1 + covariate1 + covariate2",
  mediation_demo, se_type = "sandwich"
))
decompose(extract_mediation(sem_i, treatment = "treatment", mediator = "mediator1",
                            outcome = "outcome_int"))
```

           cde    int_ref    int_med        pie        nde        nie      total
    0.21521278 0.04353909 0.27709549 0.34001758 0.25875187 0.61711307 0.87586495 

More: [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md),
[the native product
term](https://data-wise.github.io/medfit/articles/model-native.html#product-terms).

## 8. Many mediators with products

*When:* several mediators and a treatment-by-mediator term. The result
is the joint effect over the mediator block; bootstrap it with
[`joint_effects()`](https://data-wise.github.io/medfit/reference/joint_effects.md).

``` r
fit_m1 <- lm(mediator1 ~ treatment + covariate1 + covariate2, mediation_demo)
fit_m2 <- lm(mediator2 ~ treatment + mediator1 + covariate1 + covariate2,
             mediation_demo)
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
    0.6560315 0.4349603 0.8927176 

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
tidy(xc, type = "effects", conf_int = TRUE)
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
tidy(xl, type = "effects", conf_int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std_error conf_low conf_high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.333    0.0642  0.207       0.459
    2 nde      0.206    0.109  -0.00801     0.420
    3 te       0.539    0.119   0.306       0.771

More: [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md).

## 11. A latent mediator, native engine

*When:* the mediator is a construct measured by several indicators, and
you want its indirect effect without first averaging the indicators into
a score. The mediator `eta` is not a column of the data; the model
syntax defines it. The native engine is experimental.

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

``` r
syntax <- "
  eta =~ m1 + m2 + m3
  eta ~ a * X
  Y ~ b * eta + cp * X
"
xs <- fit_mediation(model = syntax, data = ldat, treatment = "X",
                    mediator = "eta", engine = "native")
tidy(xs, type = "effects", conf_int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std_error conf_low conf_high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.169    0.0310    0.108     0.229
    2 nde      0.255    0.0487    0.159     0.350
    3 te       0.423    0.0445    0.336     0.510

[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
fits the same syntax and returns the `SEMFit`.
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
tests the indirect effect as the minimum of two likelihood-ratio tests,
refitting with `a == 0` and with `b == 0`:

``` r
mbco_sem(fit_sem(syntax, ldat), "a", "b")
```


        Minimum-of-two likelihood-ratio tests (MBCO) for an indirect effect

    data:  a * b = 0
    MBCO = 46.753, df = 1, p-value = 8.054e-12

## 12. A nonlinear constraint or a longer chain, native engine

*When:* you want to fix the direct effect at the indirect effect
(`cp == a*b`), or test the indirect effect of a three-mediator-step
chain, which is a product of three paths. Constraints may be nonlinear
in the labels. The native engine is experimental.

``` r
base <- "
  mediator1 ~ a * treatment
  outcome ~ b * mediator1 + cp * treatment
"
free <- fit_sem(base, mediation_demo)
tied <- fit_sem(paste0(base, "cp == a * b"), mediation_demo)
rbind(free = coef(free)[c("a", "b", "cp")], tied = coef(tied)[c("a", "b", "cp")])
```

                 a         b         cp
    free 0.4559961 0.7134287 0.04057666
    tied 0.3381172 0.6831633 0.23098930

The tied fit has one more degree of freedom and its standard errors
respect the constraint. `anova(tied, free)` is the likelihood-ratio test
of it. For a chain `a`, `d`, `b`,
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
takes the paths and returns the minimum of the single-path tests,
referred to a chi-square with one degree of freedom (conservative when
several paths are zero):

``` r
chain <- "
  mediator1 ~ a * treatment
  mediator2 ~ d * mediator1 + treatment
  outcome ~ b * mediator2 + mediator1 + treatment
"
mbco_sem(fit_sem(chain, mediation_demo), paths = c("a", "d", "b"))
```


        Minimum-of-3 likelihood-ratio tests (MBCO) for an indirect effect

    data:  a * d * b = 0
    MBCO = 17.557, df = 1, p-value = 2.788e-05

## 13. Joint significance for a binary or count outcome

*When:* the outcome is binary or a count and you want to know whether
the mediated path exists, without an outcome-scale effect. Test `a = 0`
and `b = 0` separately and take the larger p-value (conservative). Each
test is a likelihood-ratio test for a binomial or Poisson model and an F
test for a Gaussian, Gamma or `quasi*` model, whose dispersion is
estimated.

``` r
d <- mediation_demo
d$outcome_bin <- as.integer(d$outcome > median(d$outcome))
```

``` r
joint_test <- function(fit_a, term_a, fit_b, term_b) {
  one <- function(fit, term) {
    known <- fit$family$family %in% c("binomial", "poisson")
    col <- if (known) "Pr(>Chi)" else "Pr(>F)"
    drop1(fit, scope = term, test = if (known) "LRT" else "F")[term, col]
  }
  p <- c(a = one(fit_a, term_a), b = one(fit_b, term_b))
  c(p, joint = max(p))
}
fit_a <- glm(mediator1 ~ treatment + covariate1 + covariate2, data = d)
fit_b <- glm(outcome_bin ~ treatment + mediator1 + covariate1 + covariate2,
             data = d, family = binomial())
joint_test(fit_a, "treatment", fit_b, "mediator1")
```

               a            b        joint
    8.096703e-09 2.024938e-12 8.096703e-09 

More: [GLM
families](https://data-wise.github.io/medfit/articles/model-glm-families.html#joint-significance-test-for-the-indirect-effect).

## 14. Compare two native models

*When:* you want to know whether a path or a constraint is needed, on
the native engine. [`anova()`](https://rdrr.io/r/stats/anova.html) is
the likelihood-ratio test for nested `SEMFit`s; it refits nothing.
[`glance()`](https://generics.r-lib.org/reference/glance.html) gives AIC
and BIC side by side.

``` r
full <- fit_sem("
  mediator1 ~ a * treatment
  outcome ~ b * mediator1 + cp * treatment
", mediation_demo)
reduced <- fit_sem("
  mediator1 ~ a * treatment
  outcome ~ b * mediator1
", mediation_demo)
anova(reduced, full)
```

    Likelihood-ratio (chi-square difference) test for SEMFit models

    n = 400; Chisq is n times the minimized discrepancy

            Df  Chisq Chisq diff Df diff Pr(>Chisq)
    full     0 0.0000
    reduced  1 0.1335    0.13346       1     0.7149

``` r
rbind(reduced = glance(reduced)[, c("npar", "chisq", "AIC", "BIC")],
      full = glance(full)[, c("npar", "chisq", "AIC", "BIC")])
```

    # A tibble: 2 × 4
       npar chisq   AIC   BIC
    * <int> <dbl> <dbl> <dbl>
    1     5 0.133 2992. 3024.
    2     6 0     2994. 3030.

The restricted model is the one with more degrees of freedom. A small
chi-square difference says dropping `cp` costs little.

## 15. A defined parameter and its interval

*When:* you want the indirect effect, the total effect or the proportion
mediated with a standard error and an interval, from one fit. Define
each with `:=`; the delta method gives the standard error.

``` r
dfit <- fit_sem("
  mediator1 ~ a * treatment + covariate1
  outcome ~ b * mediator1 + cp * treatment + covariate1
  ab := a * b
  total := cp + a * b
  pm := ab / total
", mediation_demo)
dfit@defined
```

       name       expr       est         se
    1    ab      a * b 0.3331241 0.06436069
    2 total cp + a * b 0.5373844 0.11890026
    3    pm ab / total 0.6198991 0.13949633

``` r
confint(dfit)[c("ab", "total", "pm"), ]
```

              2.5 %    97.5 %
    ab    0.2069795 0.4592688
    total 0.3043441 0.7704246
    pm    0.3464914 0.8933069

The interval for `pm` is wide because a ratio is unstable when the total
is small;
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
on the extracted object is the alternative.

## 16. Bound a variance or fix a path

*When:* a variance should not go below a floor, or a path is known.
Write the bound or the value in the syntax and read the diagnostics: an
active bound means the estimate sits on the edge.

``` r
bounded <- fit_sem("
  mediator1 ~ a * treatment
  outcome ~ b * mediator1 + 0 * treatment
  outcome ~~ lower(2) * outcome
", mediation_demo)
bounded@diagnostics$active_bounds
```

    [1] "outcome~~outcome"

``` r
round(coef(bounded)[c("a", "b")], 3)
```

        a     b
    0.456 0.717 

`lower(2)` is above the variance the data want (about 1.2), so the bound
binds and is reported. `0 * treatment` fixes the direct effect at zero.

## 17. Check a native fit before trusting it

*When:* before you report a native fit. Read the diagnostics, then ask
whether the model fits when it has restrictions (`df > 0`).

``` r
chk <- fit_sem("
  mediator1 ~ treatment
  mediator2 ~ treatment
  outcome ~ mediator1 + mediator2
", mediation_demo)
chk@diagnostics[c("status", "active_bounds", "improper", "sign_check")]
```

    $status
    [1] 3

    $active_bounds
    character(0)

    $improper
    character(0)

    $sign_check
    [1] "ok"

``` r
glance(chk)[, c("df", "chisq", "p_value")]
```

    # A tibble: 1 × 3
         df chisq  p_value
      <dbl> <dbl>    <dbl>
    1     2  138. 9.35e-31

No active bound, no improper solution and a passing sign check mean the
optimizer is fine. The chi-square on 2 degrees of freedom is large, so
the model leaves out something the data contain (here, the covariance of
the two mediators’ residuals): the fit converged, and the model is still
wrong.

More: [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md).

## 18. Fix exogenous covariates (`fixed_x`)

*When:* a native model with many covariates is slow or has too many
parameters, and you want the structural results lavaan reports with
`fixed.x = TRUE`. `fixed_x = TRUE` fixes the means, variances and
covariances of the exogenous observed variables at their sample values
instead of estimating them.

``` r
syntax <- "
  mediator1 ~ a * treatment + covariate1 + covariate2
  outcome ~ b * mediator1 + covariate1 + covariate2
  ab := a * b
"
free <- fit_sem(syntax, mediation_demo)
fixed <- fit_sem(syntax, mediation_demo, fixed_x = TRUE)
rbind(free = coef(free)[c("a", "b")], fixed_x = coef(fixed)[c("a", "b")])
```

                    a         b
    free    0.5826425 0.5996207
    fixed_x 0.5826425 0.5996207

``` r
rbind(free = sqrt(diag(vcov(free)))[c("a", "b")], fixed_x = sqrt(diag(vcov(fixed)))[c("a", "b")])
```

                     a          b
    free    0.09836669 0.05120516
    fixed_x 0.09836669 0.05120516

``` r
rbind(free = free@defined[, c("est", "se")], fixed_x = fixed@defined[, c("est", "se")])
```

                  est         se
    free    0.3493645 0.06609875
    fixed_x 0.3493645 0.06609875

The estimates, standard errors and the defined parameter `ab` agree to
the digits shown. What changes is how many parameters the optimizer
carries:

``` r
cbind(fit = c("free", "fixed_x"), rbind(glance(free), glance(fixed))[, c("npar", "df", "chisq", "fixed_x")])
```

          fit npar df    chisq                           fixed_x
    1    free   14  1 3.543201
    2 fixed_x    8  1 3.543201 treatment, covariate1, covariate2

The parameter count falls from 14 to 8 while `df` and `chisq` stay put.
`glance()$fixed_x` lists what is fixed (`""` when nothing is). With
`fixed_x`, the fixed rows stay in
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) flagged
`fixed_x = TRUE`, with no standard error, and the log likelihood,
[`AIC()`](https://rdrr.io/r/stats/AIC.html) and
[`BIC()`](https://rdrr.io/r/stats/AIC.html) become conditional on the
fixed variables, so they differ from the free fit’s.

``` r
tf <- tidy(fixed)
tf[tf$fixed_x, c("term", "estimate", "std_error")]
```

    # A tibble: 6 × 3
      term                   estimate std_error
      <chr>                     <dbl>     <dbl>
    1 treatment~~treatment    0.250          NA
    2 treatment~~covariate1  -0.0700         NA
    3 treatment~~covariate2  -0.00246        NA
    4 covariate1~~covariate1  1.04           NA
    5 covariate1~~covariate2  0.00266        NA
    6 covariate2~~covariate2  0.250          NA

``` r
tryCatch(anova(free, fixed), error = function(e) cat(conditionMessage(e), "\n"))
```

    the fits have different `fixed_x` sets (free: none; fixed: covariate1, covariate2, treatment): their likelihoods condition on different variables, so they cannot be compared 

Compare fits only when they fix the same variables.
[`anova()`](https://rdrr.io/r/stats/anova.html),
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
and
[`AIC()`](https://rdrr.io/r/stats/AIC.html)/[`BIC()`](https://rdrr.io/r/stats/AIC.html)
across several fits stop when the fixed sets differ, as above. Pass a
character vector (for example `fixed_x = "treatment"`) to fix a subset.

More: [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md), [the
native engine
guide](https://data-wise.github.io/medfit/articles/native-guide.md).
