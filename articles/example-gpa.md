# Worked example: study hours, engagement and GPA

A complete mediation analysis on **simulated** data, with the technical
details and the numerical checks written out. Because the data are
simulated, the true effects are known, so every estimate is checked
against the truth as well as against independent oracles (`lm`, lavaan,
a hand-computed delta-method standard error, a bootstrap, and a Monte
Carlo study). Nothing here is a finding about real students.

|  |  |
|----|----|
| **You need** | medfit 0.11.0 or later; lavaan is used for one cross-check and the page skips that row when it is absent |
| **You get** | a fitted `MediationData`, delta-method and bootstrap intervals, a native-engine fit, and a table of pass/fail checks |
| **Time** | about 10 minutes to read, under a minute to run |

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

## 1. The question and the model

Does time spent studying raise GPA *because* it raises engagement with
the course?

- **Treatment** \\X\\: weekly study hours (`hours`).
- **Mediator** \\M\\: a course-engagement score (`engagement`).
- **Outcome** \\Y\\: semester GPA (`gpa`).
- **Covariates** \\C\\: prior GPA (`prior_gpa`) and first-generation
  status (`first_gen`).

The two linear models are

\\ M = i_M + aX + \gamma_M^\top C + \varepsilon_M, \qquad Y = i_Y + bM +
c'X + \gamma_Y^\top C + \varepsilon_Y . \\

With no treatment-by-mediator interaction the natural indirect effect is
\\\mathrm{NIE}=ab\\, the natural direct effect is \\\mathrm{NDE}=c'\\,
and the total effect is \\\mathrm{TE}=c'+ab\\ per extra study hour.
These are causal effects only under the usual sequential-ignorability
assumptions (section 9).

### The data-generating process

`sim_gpa()` is the whole truth. The coefficients below are what the
analysis should recover.

``` r
sim_gpa <- function(n, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  prior_gpa <- stats::rnorm(n, 3.0, 0.4)
  first_gen <- stats::rbinom(n, 1, 0.3)
  hours <- stats::rnorm(n, 10, 3) - 0.5 * first_gen
  engagement <- 2 + 0.30 * hours + 0.4 * (prior_gpa - 3) + stats::rnorm(n, 0, 1)
  gpa <- 1.2 + 0.12 * engagement + 0.03 * hours + 0.45 * prior_gpa -
    0.10 * first_gen + stats::rnorm(n, 0, 0.35)
  data.frame(hours, engagement, gpa, prior_gpa, first_gen)
}

truth <- c(a = 0.30, b = 0.12, cp = 0.03)
truth <- c(truth, nie = unname(truth["a"] * truth["b"]))
truth <- c(truth, nde = unname(truth["cp"]), te = unname(truth["cp"] + truth["nie"]))
round(truth, 4)
```

        a     b    cp   nie   nde    te
    0.300 0.120 0.030 0.036 0.030 0.066 

Proportion mediated is \\0.036 / 0.066 \approx 55\\\\ in the population.

``` r
n <- 500
d <- sim_gpa(n, seed = 20261017)
summary(d)
```

         hours          engagement         gpa          prior_gpa
     Min.   : 1.646   Min.   :1.136   Min.   :1.795   Min.   :1.880
     1st Qu.: 7.776   1st Qu.:3.962   1st Qu.:3.055   1st Qu.:2.697
     Median : 9.838   Median :4.947   Median :3.354   Median :2.922
     Mean   : 9.802   Mean   :4.905   Mean   :3.361   Mean   :2.941
     3rd Qu.:11.975   3rd Qu.:5.820   3rd Qu.:3.677   3rd Qu.:3.191
     Max.   :19.585   Max.   :8.918   Max.   :4.736   Max.   :3.955
       first_gen
     Min.   :0.000
     1st Qu.:0.000
     Median :0.000
     Mean   :0.286
     3rd Qu.:1.000
     Max.   :1.000  

``` r
round(stats::cor(d), 2)
```

               hours engagement   gpa prior_gpa first_gen
    hours       1.00       0.66  0.45     -0.06     -0.13
    engagement  0.66       1.00  0.53      0.01     -0.11
    gpa         0.45       0.53  1.00      0.34     -0.15
    prior_gpa  -0.06       0.01  0.34      1.00      0.01
    first_gen  -0.13      -0.11 -0.15      0.01      1.00

## 2. Fit with `fit_mediation()`

Two formulas, the outcome model first, then the mediator model;
`treatment` and `mediator` name the variables. The default engine is
`"glm"` (ordinary least squares here, since both families are Gaussian).

``` r
fit <- fit_mediation(
  gpa ~ hours + engagement + prior_gpa + first_gen,
  engagement ~ hours + prior_gpa + first_gen,
  data = d, treatment = "hours", mediator = "engagement"
)
class(fit)[1]
```

    [1] "medfit::MediationData"

``` r
tidy(fit, type = "paths", conf_int = TRUE)
```

    # A tibble: 3 × 5
      term    estimate std_error conf_low conf_high
      <chr>      <dbl>     <dbl>    <dbl>     <dbl>
    1 a         0.283    0.0146    0.254     0.311
    2 b         0.128    0.0156    0.0971    0.158
    3 c_prime   0.0316   0.00673   0.0184    0.0448

``` r
tidy(fit, type = "effects", conf_int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std_error conf_low conf_high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie     0.0361   0.00480   0.0267    0.0455
    2 nde     0.0316   0.00673   0.0184    0.0448
    3 te      0.0677   0.00541   0.0571    0.0784

Reading the output: each extra study hour raises engagement by `a`, each
engagement point raises GPA by `b` holding hours fixed, and the indirect
effect is their product with a delta-method interval (next section).
`pm(fit)` gives the proportion mediated:

``` r
pm(fit)
```

    Proportion Mediated (PM): 0.5329

## 3. Technical details

### Estimator

[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
fits the mediator and outcome models by least squares and stores the
path coefficients \\\hat a, \hat b, \hat c'\\ with their joint
covariance in `fit@estimates` and `fit@vcov`. The two regressions use
disjoint parameters and independent errors, so \\\mathrm{Cov}(\hat
a,\hat b)=0\\ in the stacked covariance.

### Delta-method standard error

For \\\mathrm{NIE}=ab\\ the gradient is \\(b, a)\\, so

\\ \widehat{\mathrm{se}}(\widehat{ab}) = \sqrt{\hat
b^2\\\widehat{\mathrm{se}}(\hat a)^2 + \hat
a^2\\\widehat{\mathrm{se}}(\hat b)^2} \\

(the first-order, Sobel form). For \\\mathrm{TE}=c'+ab\\ the gradient is
\\(1, b, a)\\ over \\(c', a, b)\\. Intervals are \\\text{estimate} \pm
z\_{0.975}\\\widehat{\mathrm{se}}\\. The product \\ab\\ is skewed in
small samples, so the delta interval is symmetric where the sampling
distribution is not; section 6 measures how much that matters here, and
the [interval
guide](https://data-wise.github.io/medfit/articles/guide-intervals.md)
says when to prefer a bootstrap.

### What the numerical checks compare

`chk()` records one row per check: the value, its reference, a tolerance
and whether the value is within it. A check that cannot fail is not a
check, so each row compares against something computed independently of
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md).

``` r
checks <- data.frame(check = character(), value = numeric(), reference = numeric(),
                     tolerance = numeric(), pass = logical())
chk <- function(name, value, reference, tolerance) {
  env <- parent.frame()
  tab <- get("checks", envir = env)
  tab[nrow(tab) + 1L, ] <- list(name, value, reference, tolerance,
                                abs(value - reference) <= tolerance)
  assign("checks", tab, envir = env)
  invisible(NULL)
}
est <- stats::setNames(tidy(fit, type = "effects")$estimate, tidy(fit, type = "effects")$term)
se <- stats::setNames(tidy(fit, type = "effects")$std_error, tidy(fit, type = "effects")$term)
pth <- stats::setNames(tidy(fit, type = "paths")$estimate, tidy(fit, type = "paths")$term)
pse <- stats::setNames(tidy(fit, type = "paths")$std_error, tidy(fit, type = "paths")$term)
```

## 4. Check 1: recovery of the known truth

Each estimate should lie within three of its own standard errors of the
true value (a 0.3% miss rate per check if the model is right).

``` r
chk("a within 3 se of truth", pth[["a"]], truth[["a"]], 3 * pse[["a"]])
chk("b within 3 se of truth", pth[["b"]], truth[["b"]], 3 * pse[["b"]])
chk("c' within 3 se of truth", pth[["c_prime"]], truth[["cp"]], 3 * pse[["c_prime"]])
chk("NIE within 3 se of truth", est[["nie"]], truth[["nie"]], 3 * se[["nie"]])
chk("TE within 3 se of truth", est[["te"]], truth[["te"]], 3 * se[["te"]])
```

## 5. Check 2: independent oracles

### Plain `lm`

Both effects have exact closed forms in ordinary least squares. The
product of the two `lm` coefficients is the indirect effect, and the
total effect equals the treatment coefficient in the outcome model that
omits the mediator (the “total-effect regression”). Equality is exact up
to floating-point error because OLS coefficients are the same estimator.

``` r
lm_m <- lm(engagement ~ hours + prior_gpa + first_gen, d)
lm_y <- lm(gpa ~ hours + engagement + prior_gpa + first_gen, d)
lm_t <- lm(gpa ~ hours + prior_gpa + first_gen, d)
a_lm <- coef(lm_m)[["hours"]]
b_lm <- coef(lm_y)[["engagement"]]
chk("NIE equals a*b from lm", est[["nie"]], a_lm * b_lm, 1e-10)
chk("TE equals total-effect regression", est[["te"]], coef(lm_t)[["hours"]], 1e-10)
```

The second line is an identity of OLS (\\c = c' + ab\\ with the same
covariates), so a failure points at the fit rather than at sampling
noise.

### Hand-computed Sobel standard error

``` r
sa <- summary(lm_m)$coefficients["hours", "Std. Error"]
sb <- summary(lm_y)$coefficients["engagement", "Std. Error"]
sobel <- sqrt(b_lm^2 * sa^2 + a_lm^2 * sb^2)
c(medfit = se[["nie"]], sobel = sobel, ratio = se[["nie"]] / sobel)
```

         medfit       sobel       ratio
    0.004795335 0.004795335 1.000000000 

``` r
chk("NIE se equals Sobel from lm", se[["nie"]], sobel, 1e-8 * sobel)
```

The ratio is 1 to printed precision: for a Gaussian `glm` fit medfit
takes the least-squares standard errors from the two regressions, so the
delta-method value is the Sobel value, not an approximation of it. (The
native engine below divides by \\n\\ rather than \\n-p\\ and differs by
a fraction of a percent.)

## 6. Check 3: the native engine and lavaan

The native maximum-likelihood engine fits the same model from syntax.
Defined parameters (`:=`) carry the indirect and total effects with
their own delta-method standard errors.

``` r
syntax <- "
  engagement ~ a * hours + prior_gpa + first_gen
  gpa ~ b * engagement + cp * hours + prior_gpa + first_gen
  ab := a * b
  total := cp + a * b
"
sem <- fit_sem(syntax, d)
tsem <- tidy(sem)
tsem[tsem$term %in% c("a", "b", "cp", "ab", "total"), c("term", "estimate", "std_error")]
```

    # A tibble: 5 × 3
      term  estimate std_error
      <chr>    <dbl>     <dbl>
    1 a       0.283    0.0145
    2 b       0.128    0.0155
    3 cp      0.0316   0.00670
    4 ab      0.0361   0.00477
    5 total   0.0677   0.00539

``` r
glance(sem)[, c("nobs", "npar", "df", "chisq")]
```

    # A tibble: 1 × 4
       nobs  npar    df chisq
      <int> <int> <dbl> <dbl>
    1   500    15     0     0

The model is saturated (`df = 0`), so there is no global chi-square to
read: it fits exactly by construction, and the interesting content is
the parameters.

``` r
sem_est <- stats::setNames(tsem$estimate, tsem$term)
sem_se <- stats::setNames(tsem$std_error, tsem$term)
chk("native ab equals medfit NIE", sem_est[["ab"]], est[["nie"]], 1e-5)
chk("native total equals medfit TE", sem_est[["total"]], est[["te"]], 1e-5)
chk("native ab se vs medfit NIE se (ML vs OLS scaling, 2%)", sem_se[["ab"]], se[["nie"]],
    0.02 * se[["nie"]])
```

The point estimates agree to optimizer tolerance; the standard errors
agree to about the \\\sqrt{(n-p)/n}\\ difference between maximum
likelihood and least squares (the second check uses a 2% tolerance
because that factor is about 0.5% to 1% here).

### lavaan

``` r
if (requireNamespace("lavaan", quietly = TRUE)) {
  lf <- lavaan::sem(syntax, d, meanstructure = TRUE)
  pe <- lavaan::parameterEstimates(lf)
  ab_row <- pe[pe$label == "ab", ]
  tot_row <- pe[pe$label == "total", ]
  chk("lavaan ab equals native ab", ab_row$est, sem_est[["ab"]], 1e-5)
  chk("lavaan ab se equals native ab se", ab_row$se, sem_se[["ab"]], 1e-4)
  chk("lavaan total equals native total", tot_row$est, sem_est[["total"]], 1e-5)
  ab_row[, c("label", "est", "se", "ci.lower", "ci.upper")]
} else {
  cat("lavaan is not installed; the three lavaan rows are skipped.\n")
}
```

       label   est    se ci.lower ci.upper
    21    ab 0.036 0.005    0.027    0.045

Both engines are maximum likelihood with the same expected-information
standard errors, so they should agree closely; any gap larger than the
tolerance is a defect in one of them. (lavaan is fitted with its default
mean structure, which only adds the intercepts and leaves the structural
parameters and their covariance unchanged.)

## 7. Check 4: bootstrap against the delta interval

The product \\ab\\ is not normal, so the delta interval is an
approximation. A nonparametric bootstrap refits both models on resampled
students and makes no normality claim about \\ab\\.

``` r
nie_refit <- function(dd) {
  fm <- lm(engagement ~ hours + prior_gpa + first_gen, dd)
  fy <- lm(gpa ~ hours + engagement + prior_gpa + first_gen, dd)
  coef(fm)[["hours"]] * coef(fy)[["engagement"]]
}
boot <- bootstrap_mediation(nie_refit, method = "nonparametric", data = d,
                            n_boot = 2000, seed = 123)
delta <- unlist(tidy(fit, type = "effects", conf_int = TRUE)[1, c("conf_low", "conf_high")])
rbind(delta = delta, bootstrap = c(boot@ci_lower, boot@ci_upper))
```

                conf_low  conf_high
    delta     0.02670604 0.04550340
    bootstrap 0.02616054 0.04593167

``` r
chk("bootstrap CI lower within 0.003 of delta", boot@ci_lower, delta[["conf_low"]], 0.003)
chk("bootstrap CI upper within 0.003 of delta", boot@ci_upper, delta[["conf_high"]], 0.003)
covers <- boot@ci_lower <= truth[["nie"]] && truth[["nie"]] <= boot@ci_upper
chk("bootstrap CI covers the true NIE", as.numeric(covers), 1, 0)
```

At \\n=500\\ with \\a/\mathrm{se}(a)\approx 19\\ and
\\b/\mathrm{se}(b)\approx 8\\ both paths are far from zero, which is the
regime where the product is close to normal. The agreement is expected
here and is not guaranteed for a weak path or a small sample; the Monte
Carlo study next measures that.

## 8. Check 5: does the interval do what it says?

One data set cannot show that a 95% interval is 95%. A Monte Carlo study
draws many data sets from `sim_gpa()`, fits each, and records whether
the interval contains the truth and how far the estimate is from it. The
study is run at the sample size of the example and at \\n=100\\, where
the product \\ab\\ is further from normal.

``` r
mc <- function(n, reps, seed) {
  set.seed(seed)
  out <- matrix(NA_real_, reps, 3, dimnames = list(NULL, c("est", "se", "cover")))
  for (r in seq_len(reps)) {
    dd <- sim_gpa(n)
    f <- fit_mediation(gpa ~ hours + engagement + prior_gpa + first_gen,
                       engagement ~ hours + prior_gpa + first_gen,
                       data = dd, treatment = "hours", mediator = "engagement")
    e <- tidy(f, type = "effects", conf_int = TRUE)
    e <- e[e$term == "nie", ]
    out[r, ] <- c(e$estimate, e$std_error,
                  e$conf_low <= truth[["nie"]] && truth[["nie"]] <= e$conf_high)
  }
  out
}
reps <- 400
mc500 <- mc(500, reps, seed = 1)
mc100 <- mc(100, reps, seed = 2)
summ <- function(m, n) {
  c(n = n, reps = nrow(m), mean_est = mean(m[, "est"]),
    bias = mean(m[, "est"]) - truth[["nie"]],
    mc_se_bias = stats::sd(m[, "est"]) / sqrt(nrow(m)),
    emp_sd = stats::sd(m[, "est"]), mean_se = mean(m[, "se"]),
    coverage = mean(m[, "cover"]))
}
mc_table <- rbind(summ(mc500, 500), summ(mc100, 100))
round(mc_table, 4)
```

           n reps mean_est   bias mc_se_bias emp_sd mean_se coverage
    [1,] 500  400   0.0356 -4e-04      3e-04 0.0053  0.0050   0.9275
    [2,] 100  400   0.0360  0e+00      6e-04 0.0111  0.0116   0.9650

How to read it: `bias` should be within a few `mc_se_bias`; `emp_sd`
(the real spread of the estimate) should match `mean_se` (what the delta
formula reports); `coverage` should be near 0.95. With 400 replications
the Monte Carlo error of a coverage figure is \\\sqrt{0.95 \cdot 0.05 /
400}\approx 0.011\\, and that of a standard deviation is about
\\1/\sqrt{2 \cdot 400}\approx 3.5\\\\ of it. Differences of that size
are noise, so the tolerances below are three Monte Carlo errors rather
than a demand for exact agreement.

``` r
chk("MC bias at n=500 within 3 MC se", mc_table[1, "bias"], 0, 3 * mc_table[1, "mc_se_bias"])
chk("MC mean delta se matches empirical sd at n=500 (10%, about 3 MC se)", mc_table[1, "mean_se"],
    mc_table[1, "emp_sd"], 0.10 * mc_table[1, "emp_sd"])
chk("MC coverage at n=500 within 0.035 of 0.95 (3 MC se)", mc_table[1, "coverage"], 0.95, 0.035)
chk("MC coverage at n=100 within 0.035 of 0.95 (3 MC se)", mc_table[2, "coverage"], 0.95, 0.035)
```

## 9. Check 6: assumptions and robustness

### Linearity, normality and constant variance

The delta interval and the least-squares standard errors assume the
residuals are roughly symmetric with constant variance. With simulated
Gaussian errors both hold by construction, so this section shows the
form of the diagnostics rather than a surprise.

``` r
skew <- function(x) mean((x - mean(x))^3) / stats::sd(x)^3
kurt <- function(x) mean((x - mean(x))^4) / stats::sd(x)^4
bp <- function(m) {
  r2 <- summary(lm(resid(m)^2 ~ fitted(m)))$r.squared
  stats::pchisq(length(resid(m)) * r2, df = 1, lower.tail = FALSE)
}
data.frame(model = c("mediator", "outcome"),
           skewness = c(skew(resid(lm_m)), skew(resid(lm_y))),
           kurtosis = c(kurt(resid(lm_m)), kurt(resid(lm_y))),
           bp_p = c(bp(lm_m), bp(lm_y)))
```

         model    skewness kurtosis      bp_p
    1 mediator -0.02725761 2.864326 0.7295578
    2  outcome  0.07790820 2.847683 0.5005689

Normal residuals have skewness 0 and kurtosis 3; `bp_p` is a
Breusch-Pagan test (small means non-constant variance).

``` r
chk("mediator residual skewness near 0", skew(resid(lm_m)), 0, 0.3)
chk("outcome residual skewness near 0", skew(resid(lm_y)), 0, 0.3)
chk("outcome residuals: constant variance not rejected (p above 0.01)",
    as.numeric(bp(lm_y) > 0.01), 1, 0)
```

### Robust standard errors

If the variance were not constant the model-based standard errors would
be wrong. The HC3 sandwich covariance does not assume constant variance;
here it should land close to the model-based value.

``` r
fit_rob <- fit_mediation(
  gpa ~ hours + engagement + prior_gpa + first_gen,
  engagement ~ hours + prior_gpa + first_gen,
  data = d, treatment = "hours", mediator = "engagement", se_type = "sandwich"
)
rob <- tidy(fit_rob, type = "effects")
se_rob <- stats::setNames(rob$std_error, rob$term)
c(model = se[["nie"]], sandwich = se_rob[["nie"]], ratio = se_rob[["nie"]] / se[["nie"]])
```

          model    sandwich       ratio
    0.004795335 0.004953187 1.032917859 

``` r
chk("sandwich NIE se within 15% of model-based", se_rob[["nie"]], se[["nie"]], 0.15 * se[["nie"]])
```

### Treatment-by-mediator interaction

If study hours raised GPA through engagement more for some engagement
levels than others, the single product \\ab\\ would be the wrong summary
and the four-way decomposition would be needed. The data here have no
such term, and a Wald test of the product coefficient says so:

``` r
lm_yi <- lm(gpa ~ hours * engagement + prior_gpa + first_gen, d)
theta3 <- summary(lm_yi)$coefficients["hours:engagement", ]
theta3
```

         Estimate    Std. Error       t value      Pr(>|t|)
    -0.0003036296  0.0032911000 -0.0922577841  0.9265306292 

``` r
xi <- extract_mediation(lm_m, model_y = lm_yi, treatment = "hours",
                        mediator = "engagement", m_star = mean(d$engagement))
decompose(xi)
```

              cde       int_ref       int_med           pie           nde
     3.164772e-02  8.415932e-04 -8.586007e-05  3.693997e-02  3.248931e-02
              nie         total
     3.685411e-02  6.934342e-02 

``` r
chk("no hours-by-engagement interaction (p above 0.01)", as.numeric(theta3[["Pr(>|t|)"]] > 0.01), 1, 0)
```

With the reference level `m_star` at the mean engagement the interaction
parts (`int_ref`, `int_med`) should be close to zero and the four parts
should sum to the total effect.

``` r
fw <- decompose(xi)
fw
```

              cde       int_ref       int_med           pie           nde
     3.164772e-02  8.415932e-04 -8.586007e-05  3.693997e-02  3.248931e-02
              nie         total
     3.685411e-02  6.934342e-02 

### What the data cannot check

Sequential ignorability cannot be tested from these data: no unmeasured
confounder of the engagement-GPA relation, none of the hours-GPA
relation, and none of the hours-engagement relation given the
covariates. Here the model is correct by construction. In a real study
each of those is an argument about the design, and a sensitivity
analysis (for example the sibling package medrobust) is the honest
companion to the numbers above.

## 10. The check table

``` r
checks$value <- signif(checks$value, 6)
checks$reference <- signif(checks$reference, 6)
checks$tolerance <- signif(checks$tolerance, 3)
checks
```

                                                                     check
    1                                               a within 3 se of truth
    2                                               b within 3 se of truth
    3                                              c' within 3 se of truth
    4                                             NIE within 3 se of truth
    5                                              TE within 3 se of truth
    6                                               NIE equals a*b from lm
    7                                    TE equals total-effect regression
    8                                          NIE se equals Sobel from lm
    9                                          native ab equals medfit NIE
    10                                       native total equals medfit TE
    11               native ab se vs medfit NIE se (ML vs OLS scaling, 2%)
    12                                          lavaan ab equals native ab
    13                                    lavaan ab se equals native ab se
    14                                    lavaan total equals native total
    15                            bootstrap CI lower within 0.003 of delta
    16                            bootstrap CI upper within 0.003 of delta
    17                                    bootstrap CI covers the true NIE
    18                                     MC bias at n=500 within 3 MC se
    19 MC mean delta se matches empirical sd at n=500 (10%, about 3 MC se)
    20                 MC coverage at n=500 within 0.035 of 0.95 (3 MC se)
    21                 MC coverage at n=100 within 0.035 of 0.95 (3 MC se)
    22                                   mediator residual skewness near 0
    23                                    outcome residual skewness near 0
    24    outcome residuals: constant variance not rejected (p above 0.01)
    25                           sandwich NIE se within 15% of model-based
    26                   no hours-by-engagement interaction (p above 0.01)
              value  reference tolerance pass
    1   0.282779000 0.30000000  4.38e-02 TRUE
    2   0.127678000 0.12000000  4.69e-02 TRUE
    3   0.031644900 0.03000000  2.02e-02 TRUE
    4   0.036104700 0.03600000  1.44e-02 TRUE
    5   0.067749600 0.06600000  1.62e-02 TRUE
    6   0.036104700 0.03610470  1.00e-10 TRUE
    7   0.067749600 0.06774960  1.00e-10 TRUE
    8   0.004795330 0.00479533  4.80e-11 TRUE
    9   0.036104700 0.03610470  1.00e-05 TRUE
    10  0.067749600 0.06774960  1.00e-05 TRUE
    11  0.004772030 0.00479533  9.59e-05 TRUE
    12  0.036104700 0.03610470  1.00e-05 TRUE
    13  0.004772030 0.00477203  1.00e-04 TRUE
    14  0.067749600 0.06774960  1.00e-05 TRUE
    15  0.026160500 0.02670600  3.00e-03 TRUE
    16  0.045931700 0.04550340  3.00e-03 TRUE
    17  1.000000000 1.00000000  0.00e+00 TRUE
    18 -0.000376421 0.00000000  7.97e-04 TRUE
    19  0.005018670 0.00531395  5.31e-04 TRUE
    20  0.927500000 0.95000000  3.50e-02 TRUE
    21  0.965000000 0.95000000  3.50e-02 TRUE
    22 -0.027257600 0.00000000  3.00e-01 TRUE
    23  0.077908200 0.00000000  3.00e-01 TRUE
    24  1.000000000 1.00000000  0.00e+00 TRUE
    25  0.004953190 0.00479533  7.19e-04 TRUE
    26  1.000000000 1.00000000  0.00e+00 TRUE

``` r
cat(sum(checks$pass), "of", nrow(checks), "checks pass\n")
```

    26 of 26 checks pass

``` r
stopifnot(all(checks$pass))
```

The last line stops the page build if any check fails, so a regression
in the package breaks the site build instead of quietly publishing a
wrong example.

## 11. Reproducibility

``` r
c(medfit = as.character(utils::packageVersion("medfit")),
  R = paste(R.version$major, R.version$minor, sep = "."),
  lavaan = if (requireNamespace("lavaan", quietly = TRUE)) {
    as.character(utils::packageVersion("lavaan"))
  } else {
    "not installed"
  })
```

      medfit        R   lavaan
    "0.14.0"  "4.6.1"  "0.7.3" 

Seeds: data `20261017`; bootstrap `123`; Monte Carlo `1` (n = 500) and
`2` (n = 100). The simulation functions use
[`stats::rnorm()`](https://rdrr.io/r/stats/Normal.html) and
[`stats::rbinom()`](https://rdrr.io/r/stats/Binomial.html) only, so the
numbers are stable across platforms up to the last printed digits.

## Where next

- [Model
  Extraction](https://data-wise.github.io/medfit/articles/extraction.md):
  the same fit from your own `lm` objects.
- [Bootstrap](https://data-wise.github.io/medfit/articles/bootstrap.md)
  and [Which interval should I
  use?](https://data-wise.github.io/medfit/articles/guide-intervals.md):
  choosing the interval.
- [Native engine, step by
  step](https://data-wise.github.io/medfit/articles/native-tutorial.md):
  model syntax, constraints and
  [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md).
- [Cookbook](https://data-wise.github.io/medfit/articles/cookbook.md):
  one-screen recipes for the variations (binary outcome, weights, serial
  and parallel mediators).
