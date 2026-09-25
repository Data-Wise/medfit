# Model Extraction

## Overview

The
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
function provides a standardized interface for extracting mediation
structures from fitted models. It works with: - **lm/glm** models (base
R) - implemented - **lavaan** SEM models - implemented - **lmer** mixed
models (future)

Extraction returns the S7 class that matches the structure:
`MediationData`, `InteractionMediationData`, `SerialMediationData`,
`ParallelMediationData`, or `JointMediationData`. All share one
interface
([`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`confint()`](https://rdrr.io/r/stats/confint.html),
[`tidy()`](https://generics.r-lib.org/reference/tidy.html),
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md),
…) across modeling frameworks.

**Note:** For quick analysis, consider using
[`med()`](https://data-wise.github.io/medfit/reference/med.md) instead -
it handles fitting and extraction in one step. Use
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
when you need more control or already have fitted models.

## Quick Comparison: med() vs extract_mediation()

``` r
library(medfit)
```


    Attaching package: 'medfit'

    The following object is masked from 'package:stats':

        decompose

``` r
# mediation_demo: simulated data bundled with medfit (see ?mediation_demo).
# Its covariates confound the mediator-outcome relation, so adjust for them.
covs <- c("covariate1", "covariate2")

# Simple way: med() does everything
result <- med(data = mediation_demo, treatment = "treatment",
              mediator = "mediator1", outcome = "outcome", covariates = covs)
quick(result)
```

    NIE = 0.333  | NDE = 0.206 | PM = 61.8 %

``` r
# Advanced way: fit models separately, then extract
fit_m <- lm(mediator1 ~ treatment + covariate1 + covariate2, data = mediation_demo)
fit_y <- lm(outcome ~ treatment + mediator1 + covariate1 + covariate2,
            data = mediation_demo)
result <- extract_mediation(fit_m, model_y = fit_y, treatment = "treatment",
                            mediator = "mediator1")
quick(result)
```

    NIE = 0.333  | NDE = 0.206 | PM = 61.8 %

## Extraction Pattern

All extraction methods follow this pattern:

1.  Validate inputs (check variable names exist)
2.  Extract path coefficients (a, b, c’ paths)
3.  Extract covariance matrix (for inference)
4.  Extract residual variances (if Gaussian)
5.  Retrieve data (if available)
6.  Create MediationData object
7.  Return standardized structure

## Extracting from lm/glm Models

### Simple Mediation

For simple mediation (X -\> M -\> Y), fit two models. Both adjust for
the covariates, which confound the mediator-outcome relation in
`mediation_demo`:

``` r
# Fit mediation models
model_m <- lm(mediator1 ~ treatment + covariate1 + covariate2,
              data = mediation_demo)
model_y <- lm(outcome ~ treatment + mediator1 + covariate1 + covariate2,
              data = mediation_demo)

# Extract mediation structure
med_data <- extract_mediation(
  model_m,           # Mediator model
  model_y,           # Outcome model
  treatment = "treatment",
  mediator = "mediator1"
)

# View results
print(med_data)
```

    MediationData object
    ====================

    Path coefficients:
      a (X -> M):        0.5826
      b (M -> Y|X):      0.5711
      c' (X -> Y|M):     0.2058
      Indirect (a*b):    0.3328

    Variables:
      Treatment: treatment
      Mediator:  mediator1
      Outcome:   outcome

    Model info:
      N observations: 400
      Converged:      Yes
      Source:         stats::lm

    Residual SDs:
      Mediator model:   0.9792
      Outcome model:    1.0426

``` r
summary(med_data)
```

    Summary of MediationData
    ========================

    Path Coefficients:
            a         b   c_prime  indirect
    0.5826425 0.5711384 0.2057983 0.3327695

    Variables:
      treatment    mediator     outcome
    "treatment" "mediator1"   "outcome"

    Sample Size:  400
    Converged:    Yes
    Source:       stats::lm

    Residual Standard Deviations:
      Mediator model: 0.9792151
      Outcome model:  1.042567

    Parameter Estimates:
    m_(Intercept)   m_treatment  m_covariate1  m_covariate2 y_(Intercept)
       0.02052158    0.58264246    0.44789496    0.13109906    0.17120346
      y_treatment   y_mediator1  y_covariate1  y_covariate2             a
       0.20579826    0.57113843    0.35665236    0.05259769    0.58264246
                b       c_prime
       0.57113843    0.20579826

    Variance-Covariance Matrix:
                  m_(Intercept)   m_treatment  m_covariate1  m_covariate2
    m_(Intercept)  0.0071554488 -4.965720e-03 -3.621581e-04 -4.677171e-03
    m_treatment   -0.0049657198  9.773742e-03  6.574305e-04  8.913315e-05
    m_covariate1  -0.0003621581  6.574305e-04  2.349599e-03 -1.859182e-05
    m_covariate2  -0.0046771705  8.913315e-05 -1.859182e-05  9.601458e-03
    y_(Intercept)  0.0000000000  0.000000e+00  0.000000e+00  0.000000e+00
    y_treatment    0.0000000000  0.000000e+00  0.000000e+00  0.000000e+00
    y_mediator1    0.0000000000  0.000000e+00  0.000000e+00  0.000000e+00
    y_covariate1   0.0000000000  0.000000e+00  0.000000e+00  0.000000e+00
    y_covariate2   0.0000000000  0.000000e+00  0.000000e+00  0.000000e+00
    a             -0.0049657198  9.773742e-03  6.574305e-04  8.913315e-05
    b              0.0000000000  0.000000e+00  0.000000e+00  0.000000e+00
    c_prime        0.0000000000  0.000000e+00  0.000000e+00  0.000000e+00
                  y_(Intercept)   y_treatment   y_mediator1  y_covariate1
    m_(Intercept)  0.0000000000  0.0000000000  0.0000000000  0.0000000000
    m_treatment    0.0000000000  0.0000000000  0.0000000000  0.0000000000
    m_covariate1   0.0000000000  0.0000000000  0.0000000000  0.0000000000
    m_covariate2   0.0000000000  0.0000000000  0.0000000000  0.0000000000
    y_(Intercept)  0.0081124689 -0.0055948064 -0.0000587445 -0.0003842233
    y_treatment   -0.0055948064  0.0120510683 -0.0016678561  0.0014922734
    y_mediator1   -0.0000587445 -0.0016678561  0.0028625721 -0.0012821316
    y_covariate1  -0.0003842233  0.0014922734 -0.0012821316  0.0032377150
    y_covariate2  -0.0052942389  0.0003196938 -0.0003752805  0.0001470110
    a              0.0000000000  0.0000000000  0.0000000000  0.0000000000
    b             -0.0000587445 -0.0016678561  0.0028625721 -0.0012821316
    c_prime       -0.0055948064  0.0120510683 -0.0016678561  0.0014922734
                   y_covariate2             a             b       c_prime
    m_(Intercept)  0.0000000000 -4.965720e-03  0.0000000000  0.0000000000
    m_treatment    0.0000000000  9.773742e-03  0.0000000000  0.0000000000
    m_covariate1   0.0000000000  6.574305e-04  0.0000000000  0.0000000000
    m_covariate2   0.0000000000  8.913315e-05  0.0000000000  0.0000000000
    y_(Intercept) -0.0052942389  0.000000e+00 -0.0000587445 -0.0055948064
    y_treatment    0.0003196938  0.000000e+00 -0.0016678561  0.0120510683
    y_mediator1   -0.0003752805  0.000000e+00  0.0028625721 -0.0016678561
    y_covariate1   0.0001470110  0.000000e+00 -0.0012821316  0.0014922734
    y_covariate2   0.0109332064  0.000000e+00 -0.0003752805  0.0003196938
    a              0.0000000000  9.773742e-03  0.0000000000  0.0000000000
    b             -0.0003752805  0.000000e+00  0.0028625721 -0.0016678561
    c_prime        0.0003196938  0.000000e+00 -0.0016678561  0.0120510683

``` r
# Use effect extractors (recommended)
nie(med_data)   # Indirect effect (a * b)
```

    Natural Indirect Effect (NIE): 0.3328

``` r
nde(med_data)   # Direct effect (c')
```

    Natural Direct Effect (NDE): 0.2058

``` r
te(med_data)    # Total effect
```

    Total Effect (TE): 0.5386

``` r
pm(med_data)    # Proportion mediated
```

    Proportion Mediated (PM): 0.6179

``` r
quick(med_data) # One-line summary
```

    NIE = 0.333  | NDE = 0.206 | PM = 61.8 %

### What Gets Extracted?

The extraction captures:

- **Path coefficients**:

  - `a_path`: Coefficient of X in mediator model (X -\> M)
  - `b_path`: Coefficient of M in outcome model (M -\> Y, controlling
    for X)
  - `c_prime`: Coefficient of X in outcome model (direct effect)

- **Full parameter vector**: All coefficients from both models

- **Covariance matrix**: For computing standard errors of functions of
  parameters

- **Residual variances**: `sigma_m^2` and `sigma_y^2` for Gaussian
  models

- **Data and metadata**: Sample size, variable names, convergence status

### GLM with Non-Normal Outcomes

Works with any GLM family:

``` r
# Binary outcome: dichotomize the outcome at its median
demo <- mediation_demo
demo$outcome_bin <- as.integer(demo$outcome > median(demo$outcome))

model_y_bin <- glm(outcome_bin ~ treatment + mediator1 + covariate1 + covariate2,
                   data = demo, family = binomial())

med_bin <- extract_mediation(
  model_m,
  model_y_bin,
  treatment = "treatment",
  mediator = "mediator1"
)

# Note: b_path and c_prime are on logit scale
print(med_bin)
```

    MediationData object
    ====================

    Path coefficients:
      a (X -> M):        0.5826
      b (M -> Y|X):      0.8633
      c' (X -> Y|M):     0.1272
      Indirect (a*b):    0.5030

    Variables:
      Treatment: treatment
      Mediator:  mediator1
      Outcome:   outcome_bin

    Model info:
      N observations: 400
      Converged:      Yes
      Source:         stats::lm

    Residual SDs:
      Mediator model:   0.9792

### Controlling for Covariates

Every model above includes `covariate1` and `covariate2` in **both**
equations. In `mediation_demo` they affect the mediator and the outcome,
so leaving them out of the outcome model confounds the `b` path:

``` r
# The same models without the covariates
model_m_unadj <- lm(mediator1 ~ treatment, data = mediation_demo)
model_y_unadj <- lm(outcome ~ treatment + mediator1, data = mediation_demo)

med_unadj <- extract_mediation(
  model_m_unadj,
  model_y_unadj,
  treatment = "treatment",
  mediator = "mediator1"
)

# Compare the b paths: adjusted vs unadjusted
round(c(adjusted = med_data@b_path, unadjusted = med_unadj@b_path), 3)
```

      adjusted unadjusted
         0.571      0.713 

### Serial Mediation with lm/glm

For a serial chain (X -\> M1 -\> M2 -\> … -\> Mk -\> Y) fit as separate
regressions (“sequential regression”), pass an ordered `mediator`
**vector** plus the mediator models 2..k via `mediator_models`. The
first mediator model (`M1 ~ X`) goes in the usual `object` slot; the
outcome model in `model_y`. The result is a `SerialMediationData`
object.

``` r
# Serial chain: treatment -> mediator1 -> mediator2 -> outcome
# First mediator model goes in the object slot; the rest in mediator_models
fit_m1 <- lm(mediator1 ~ treatment + covariate1 + covariate2,
             data = mediation_demo)
fit_m2 <- lm(mediator2 ~ treatment + mediator1 + covariate1 + covariate2,
             data = mediation_demo)
# Include every mediator in the outcome model, not only the last one
fit_y  <- lm(outcome ~ treatment + mediator1 + mediator2 + covariate1 + covariate2,
             data = mediation_demo)

med_serial_lm <- extract_mediation(
  fit_m1,
  model_y = fit_y,
  treatment = "treatment",
  mediator = c("mediator1", "mediator2"),  # a length-2 vector selects the serial branch
  mediator_models = list(fit_m2)  # the remaining k minus 1 mediator models
)

# Serial indirect effect through the full chain: a * d1 * b
nie(med_serial_lm)
```

    Natural Indirect Effect (NIE): 0.07545

``` r
# Total indirect effect: every path through at least one mediator
nie(med_serial_lm, type = "total")
```

    Natural Indirect Effect (NIE): 0.3674

``` r
# Total effect over every path; it equals the treatment coefficient when the
# outcome is regressed on the treatment and both covariates alone
te(med_serial_lm)
```

    Total Effect (TE): 0.5386

Include the treatment and every earlier mediator in each downstream
model, as the SEM version below does. Only `mediator2`’s coefficient
becomes the `b` path, but `mediator1` also affects `outcome` directly in
`mediation_demo`, so an outcome model without it
(`outcome ~ treatment + mediator2 + ...`) confounds `b`: `mediator1` is
a common cause of `mediator2` and `outcome`. The product `a * d1 * b` is
then the effect through the full chain
`treatment -> mediator1 -> mediator2 -> outcome` only; the direct
`mediator1 -> outcome` path is not part of it. `nie(type = "total")`
adds the paths that skip a mediator, and
[`te()`](https://data-wise.github.io/medfit/reference/te.md) and
[`pm()`](https://data-wise.github.io/medfit/reference/pm.md) use every
path, so here the chain carries about 0.08 of a 0.37 total indirect
effect.

The order of `mediator_models` is cross-checked against the `mediator`
vector: each model’s response and predecessor are validated, so a
misordered list fails fast with an informative error rather than
silently producing wrong `d`-paths.

> **Same data, different CI: lm vs lavaan**
>
> An lm/glm serial chain estimates each equation **separately**, so the
> combined covariance is **block-diagonal** across chain paths:
> `cov(a, d_i)`, `cov(d_i, b)`, and `cov(d_i, d_j)` are stored as zero.
> For least squares this is exact when each downstream equation contains
> every regressor of the earlier ones, as recommended above. (The
> within-outcome-equation covariance, e.g. `cov(b, c')`, is preserved.)
>
> A single lavaan `sem()` fit of the *same equations* estimates them
> jointly by maximum likelihood. Its covariances among chain paths are
> then also zero, so the two engines’ intervals differ only by the
> small-sample difference between the OLS and ML variance estimates.
> They can differ more when the lavaan model specifies different
> equations (for example, omits a path that skips a mediator) or adds
> residual covariances.

### Parallel Mediation with lm/glm

In **parallel** mediation the mediators are not chained (X -\> M_j -\>
Y): each `M_j` is regressed on the treatment (and covariates) only, and
all mediators enter a single outcome model. The total indirect effect is
the **sum** of the per-mediator products, \\\sum_j a_j b_j\\. The API
mirrors the serial case — pass a `mediator` vector and the remaining
mediator models via `mediator_models` — but set `structure = "parallel"`
(or rely on `structure = "auto"`, which infers parallel when no mediator
is regressed on another). The result is a `ParallelMediationData`
object.

``` r
# Parallel mediators mediator1 and mediator3, each driven by the treatment
fit_m1p <- lm(mediator1 ~ treatment + covariate1 + covariate2,
              data = mediation_demo)
fit_m3p <- lm(mediator3 ~ treatment + covariate1 + covariate2,
              data = mediation_demo)
fit_yp  <- lm(outcome ~ treatment + mediator1 + mediator3 + covariate1 + covariate2,
              data = mediation_demo)

med_parallel_lm <- extract_mediation(
  fit_m1p,
  model_y = fit_yp,
  treatment = "treatment",
  mediator = c("mediator1", "mediator3"),
  mediator_models = list(fit_m3p),
  structure = "parallel"
)

# Per-mediator paths and the summed indirect effect
med_parallel_lm@a_paths
```

    [1] 0.5826425 0.4760604

``` r
med_parallel_lm@b_paths
```

    [1] 0.5685676 0.2124038

``` r
nie(med_parallel_lm)               # sum_j a_j * b_j
```

    Natural Indirect Effect (NIE): 0.4324

``` r
confint(med_parallel_lm, parm = "effects")
```

    Warning: Normal (delta-method) approximation for the indirect effect may be
    inaccurate; consider bootstrap_mediation() for robust inference.

                  2.5 %    97.5 %
    indirect  0.2920764 0.5727009
    direct   -0.1094317 0.3217899
    total     0.3044806 0.7726549

[`tidy()`](https://generics.r-lib.org/reference/tidy.html) gives the
effects with delta-method standard errors and normal intervals, and
[`glance()`](https://generics.r-lib.org/reference/glance.html) gives a
one-row summary:

``` r
library(generics)
```


    Attaching package: 'generics'

    The following objects are masked from 'package:base':

        as.difftime, as.factor, as.ordered, intersect, is.element, setdiff,
        setequal, union

``` r
tidy(med_parallel_lm, type = "effects", conf.int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std.error conf.low conf.high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.432    0.0716    0.292     0.573
    2 nde      0.106    0.110    -0.109     0.322
    3 te       0.539    0.119     0.304     0.773

``` r
glance(med_parallel_lm)
```

    # A tibble: 1 × 7
        nie   nde    te    pm n_mediators  nobs converged
      <dbl> <dbl> <dbl> <dbl>       <int> <int> <lgl>
    1 0.432 0.106 0.539 0.803           2   400 TRUE     

The normal interval for `nie` treats a sum of coefficient products as
normal; for inference on the indirect effect prefer
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/articles/bootstrap.md).

This model leaves out `mediator2`, a descendant of `mediator1`, so
`mediator1`’s `b` path (about 0.55 in the population) includes its
effect through `mediator2`; see
[`?mediation_demo`](https://data-wise.github.io/medfit/reference/mediation_demo.md)
for the reduced-form values.

The mediator equations are fit separately, and the stored `@vcov` sets
the covariances between their coefficients to zero. `cov(a_j, b_{j'})`
is exactly zero for least squares, because the outcome equation contains
every regressor of the mediator equations. `cov(a_j, a_{j'})` is not:
when the mediators’ errors are correlated it is nonzero, and the
block-diagonal `@vcov` omits it, so the indirect-effect SE can be off.
The `b_j` (and `c'`) share the single outcome equation, so
`cov(b_j, b_{j'})` and `cov(b_j, c')` are preserved. The
[`confint()`](https://rdrr.io/r/stats/confint.html) indirect-effect SE
uses the delta method over this `@vcov`, not a naive per-mediator sum. A
lavaan fit, or a nonparametric bootstrap, captures the omitted
covariance; see [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md).

### Several Mediators with a Treatment-by-Mediator Product

When the outcome model of a serial or parallel fit carries a
treatment-by-mediator term,
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
returns a `JointMediationData` object with the **joint** natural effects
of the mediators (VanderWeele and Vansteelandt 2014). The mediators are
treated as one block: the NIE runs through every mediator and every path
among them, and it has no per-mediator split. `outcome_int` carries a
`treatment` by `mediator1` product, so it fits the serial chain from
above:

``` r
fit_yj <- lm(outcome_int ~ treatment * mediator1 + mediator2 +
               covariate1 + covariate2, data = mediation_demo)

med_joint <- extract_mediation(
  fit_m1,                  # the serial mediator1 model from above
  model_y = fit_yj,
  treatment = "treatment",
  mediator = c("mediator1", "mediator2"),
  mediator_models = list(fit_m2)   # the serial mediator2 model
)
med_joint
```

    <JointMediationData>
      treatment -> {mediator1 -> mediator2} -> outcome_int  (serial mediators, joint effects)
      Products: treatment x mediator1 (m* = 0)
        mediator1 a* = +0.5826   b = +0.4465   t3 = +0.4906
        mediator2 a* = +0.4248   b = +0.2590
      c' (t1) = +0.1748   CDE = +0.1748   NDE = +0.2197
      Joint NIE (all paths through mediator1, mediator2) = +0.6560
      Total = +0.8757   |   n = 400

``` r
generics::tidy(med_joint, type = "effects", conf.int = TRUE)
```

    # A tibble: 4 × 5
      term  estimate std.error conf.low conf.high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 cde      0.175     0.113 -0.0468      0.396
    2 nde      0.220     0.116 -0.00710     0.447
    3 nie      0.656     0.116  0.428       0.884
    4 te       0.876     0.135  0.611       1.14 

`a*` is each mediator’s **total** treatment effect: for `mediator2` it
includes the path through `mediator1` (`a2 + d * a1`). The joint NIE is
`(b1 + t3) * a*_1 + b2 * a*_2`; its population value in `mediation_demo`
is 0.585. It is not comparable to the serial `a * d * b` (0.075 on the
same data without the product), which counts only the path through the
full chain.

[`decompose()`](https://data-wise.github.io/medfit/reference/decompose.md)
returns the controlled direct effect with the joint natural effects. The
CDE is read at the reference level `m_star` of each interacting mediator
(default 0); the NDE, NIE and total effect do not depend on it:

``` r
decompose(med_joint)
```

          cde       nde       nie     total
    0.1747908 0.2197091 0.6560315 0.8757405 

``` r
# CDE with mediator1 held at 1 instead of 0
med_joint_m1 <- extract_mediation(
  fit_m1,
  model_y = fit_yj,
  treatment = "treatment",
  mediator = c("mediator1", "mediator2"),
  mediator_models = list(fit_m2),
  m_star = c(mediator1 = 1)   # named by the interacting mediator
)
decompose(med_joint_m1)
```

          cde       nde       nie     total
    0.6654399 0.2197091 0.6560315 0.8757405 

The CDE moves by `t3 * (1 - 0) = 0.49`, while the other three stay put.
Unlike the single-mediator four-way decomposition, the joint object has
no INT_(ref)/INT_(med) split: the interaction is absorbed into the joint
NDE and NIE.

Standard errors use the delta method over a stacked covariance of all
the equations, conditional on the observed covariates (the NDE is
evaluated at their means). For a parametric bootstrap, use
[`joint_effects()`](https://data-wise.github.io/medfit/reference/joint_effects.md)
as the statistic; it recomputes the effects from any parameter draw:

``` r
boot_nie <- bootstrap_mediation(
  function(theta) joint_effects(med_joint, theta)[["nie"]],
  method = "parametric", mediation_data = med_joint, n_boot = 2000, seed = 1
)
c(boot_nie@ci_lower, boot_nie@ci_upper)
```

    [1] 0.4483248 0.8930866

The fit must meet a few requirements, and each violation errors with its
cause: every model carries the same covariates (a medfit limitation),
all models are Gaussian identity-link, unweighted, with an intercept,
and fit to the same rows, every mediator appears in the outcome model,
and the treatment is coded 0/1. Only outcome-model products written with
`:` or `*` are supported; a product in a mediator model, between
mediators, with a covariate, or inside
[`I()`](https://rdrr.io/r/base/AsIs.html) errors. A product
**precomputed as a data column** cannot be recognized from the formula
and would be ignored silently, so write it in the formula. The
identification assumptions are stated for the whole mediator vector; see
[`?JointMediationData`](https://data-wise.github.io/medfit/reference/JointMediationData.md).

## Extracting from lavaan Models

### Simple Mediation in SEM

``` r
library(lavaan)
```

    This is lavaan 0.7-2
    lavaan is FREE software! Please report any bugs.

``` r
# Define SEM model
model_syntax <- "
  # Mediator model
  mediator1 ~ a * treatment + covariate1 + covariate2

  # Outcome model
  outcome ~ b * mediator1 + c_prime * treatment + covariate1 + covariate2

  # Indirect effect
  indirect := a * b

  # Total effect
  total := c_prime + a * b
"

# Fit model
fit <- sem(model_syntax, data = mediation_demo)

# Extract mediation structure
med_sem <- extract_mediation(
  fit,
  treatment = "treatment",
  mediator = "mediator1",
  outcome = "outcome"
)

print(med_sem)
```

    MediationData object
    ====================

    Path coefficients:
      a (X -> M):        0.5826
      b (M -> Y|X):      0.5711
      c' (X -> Y|M):     0.2058
      Indirect (a*b):    0.3328

    Variables:
      Treatment: treatment
      Mediator:  mediator1
      Outcome:   outcome

    Model info:
      N observations: 400
      Converged:      Yes
      Source:         lavaan

    Residual SDs:
      Mediator model:   0.9743
      Outcome model:    1.0360

### Serial Mediation in SEM

For serial mediation (treatment -\> mediator1 -\> mediator2 -\>
outcome):

``` r
# Define serial mediation model
serial_syntax <- "
  # First mediator
  mediator1 ~ a * treatment + covariate1 + covariate2

  # Second mediator
  mediator2 ~ d * mediator1 + treatment + covariate1 + covariate2

  # Outcome
  outcome ~ b * mediator2 + mediator1 + c_prime * treatment +
    covariate1 + covariate2

  # Serial indirect effect (product-of-three)
  serial_indirect := a * d * b
"

fit_serial <- sem(serial_syntax, data = mediation_demo)

# Extract as SerialMediationData
med_serial <- extract_mediation(
  fit_serial,
  treatment = "treatment",
  mediator = c("mediator1", "mediator2"),
  outcome = "outcome"
)

print(med_serial)
```

    SerialMediationData object
    ==========================

    Serial mediation chain:
      treatment -> mediator1 -> mediator2 -> outcome

    Path coefficients:
      a  (treatment -> mediator1):         0.5826
      d  (mediator1 -> mediator2):         0.4996
      b  (mediator2 -> outcome):         0.2592
      c' (treatment -> outcome|M):       0.1712

    Indirect effect:
      a * d * b =   0.0755

    Model info:
      N mediators:    2
      N observations: 400
      Converged:      Yes
      Source:         lavaan

    Residual SDs:
      mediator1 model:   0.9743
      mediator2 model:   0.9783
      Outcome model:    1.0045

``` r
# Serial indirect effect
med_serial@a_path * med_serial@d_path * med_serial@b_path
```

    [1] 0.07545039

### Parallel Mediation in SEM

A single `sem()` fit handles parallel mediators directly: regress each
mediator on the treatment and let the outcome depend on all of them.
Passing a `mediator` vector returns a `ParallelMediationData` object
(auto-detected, since no mediator is regressed on another).

``` r
# Parallel model: mediator1 and mediator3 each on the treatment; outcome on both
parallel_syntax <- "
  mediator1 ~ a1 * treatment + covariate1 + covariate2
  mediator3 ~ a2 * treatment + covariate1 + covariate2
  outcome   ~ b1 * mediator1 + b2 * mediator3 + c_prime * treatment +
    covariate1 + covariate2

  # Total indirect effect = sum of per-mediator products
  indirect := a1 * b1 + a2 * b2
"

fit_parallel <- sem(parallel_syntax, data = mediation_demo)

med_parallel <- extract_mediation(
  fit_parallel,
  treatment = "treatment",
  mediator = c("mediator1", "mediator3"),
  outcome = "outcome"
)

print(med_parallel)
```

    <ParallelMediationData>
      treatment -> {mediator1, mediator3} -> outcome  (2 parallel mediators)
        mediator1 a1 = +0.5826   b1 = +0.5686
        mediator3 a2 = +0.4761   b2 = +0.2124
      Direct (c'): +0.1062
      Indirect (sum a_j*b_j): +0.4324
      Total: +0.5386   |   n = 400

``` r
nie(med_parallel)
```

    Natural Indirect Effect (NIE): 0.4324

Unlike the lm/glm engine, the SEM estimates the whole system jointly, so
the extracted `vcov` preserves **all** off-diagonals — including
`cov(a_j, b_j)` and `cov(a_j, a_{j'})`. Standard errors for the indirect
effect therefore reflect the full joint covariance, and (as with serial
mediation) the lavaan interval will generally differ from the lm one for
identical data.

## Treatment-Mediator Interaction (Four-Way Decomposition)

When treatment and mediator **interact**, the total effect splits into
four pieces (VanderWeele 2014): the controlled direct effect (CDE),
reference interaction (INTref), mediated interaction (INTmed), and pure
indirect effect (PIE), with `Total = CDE + INTref + INTmed + PIE`,
`NDE = CDE + INTref`, and `NIE = INTmed + PIE`. medfit computes the
decomposition; the causal interpretation (which requires VanderWeele’s
no-unmeasured-confounding assumptions) is the analyst’s responsibility.

[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
returns an `InteractionMediationData` object whenever the outcome model
carries an `X:M` term. Set the reference mediator level with `m_star`
(default 0).

### Interaction with lm/glm

For lm/glm, the `X:M` term is detected automatically. `mediation_demo`’s
`outcome_int` carries a `treatment` by `mediator1` interaction:

``` r
# Outcome model includes the treatment:mediator1 interaction
fit_mi <- lm(mediator1 ~ treatment + covariate1 + covariate2,
             data = mediation_demo)
fit_yi <- lm(outcome_int ~ treatment * mediator1 + covariate1 + covariate2,
             data = mediation_demo)

med_int <- extract_mediation(
  fit_mi,
  model_y = fit_yi,
  treatment = "treatment",
  mediator = "mediator1",
  m_star = 0           # reference mediator level for the decomposition
)

decompose(med_int)                          # CDE, INTref, INTmed, PIE + effects
```

           cde    int_ref    int_med        pie        nde        nie      total
    0.21521278 0.04353909 0.27709549 0.34001758 0.25875187 0.61711307 0.87586495 

``` r
confint(med_int, parm = "components")       # delta-method CIs for the components
```

    Normal (delta-method) approximation for four-way components; consider bootstrap_mediation() for robust inference.

                  2.5 %    97.5 %
    cde     -0.01242752 0.4428531
    int_ref -0.02378409 0.1108623
    int_med  0.13266955 0.4215214
    pie      0.19952257 0.4805126

[`tidy()`](https://generics.r-lib.org/reference/tidy.html) reports the
four components with `type = "components"` and the natural effects with
`type = "effects"`;
[`glance()`](https://generics.r-lib.org/reference/glance.html) adds the
interaction coefficient and `m_star`:

``` r
library(generics)
tidy(med_int, type = "components", conf.int = TRUE)
```

    # A tibble: 4 × 5
      term    estimate std.error conf.low conf.high
      <chr>      <dbl>     <dbl>    <dbl>     <dbl>
    1 cde       0.215     0.116   -0.0124     0.443
    2 int_ref   0.0435    0.0343  -0.0238     0.111
    3 int_med   0.277     0.0737   0.133      0.422
    4 pie       0.340     0.0717   0.200      0.481

``` r
tidy(med_int, type = "effects")
```

    # A tibble: 3 × 3
      term  estimate std.error
      <chr>    <dbl>     <dbl>
    1 nie      0.617     0.113
    2 nde      0.259     0.118
    3 te       0.876     0.135

``` r
glance(med_int)
```

    # A tibble: 1 × 8
        nie   nde    te    pm interaction m_star  nobs converged
      <dbl> <dbl> <dbl> <dbl>       <dbl>  <dbl> <int> <lgl>
    1 0.617 0.259 0.876 0.705       0.476      0   400 TRUE     

The four-way formulas (continuous `Y` and `M`) are `CDE = θ₁ + θ₃·m*`,
`INTref = θ₃·(E[M|X=0] − m*)`, `INTmed = θ₃·β₁`, and `PIE = θ₂·β₁`,
where `θ₃` is the interaction coefficient and `β₁` the `a` path.
Non-Gaussian outcomes are not yet supported and raise an informative
error.

### Interaction with lavaan

In lavaan the interaction enters as a **product variable** (a column you
create), and the model must be fit with `meanstructure = TRUE` so the
mediator intercept (needed for INTref) is estimated. Name the product
term via `interaction`:

``` r
demo <- mediation_demo
demo$XM <- demo$treatment * demo$mediator1     # product term

fit_int <- sem(
  "mediator1 ~ treatment + covariate1 + covariate2
   outcome_int ~ mediator1 + treatment + XM + covariate1 + covariate2",
  data = demo,
  meanstructure = TRUE
)

med_int_sem <- extract_mediation(
  fit_int,
  treatment = "treatment",
  mediator = "mediator1",
  outcome = "outcome_int",
  interaction = "XM"     # name of the product predictor in the outcome model
)

decompose(med_int_sem)
```

           cde    int_ref    int_med        pie        nde        nie      total
    0.21521278 0.04353909 0.27709549 0.34001758 0.25875187 0.61711307 0.87586495 

When the interaction is absent (or `decomposition = "two_way"`),
extraction falls back to the standard `MediationData` — so existing
two-way workflows are unchanged.

### Interaction via the regmedint engine

The two paths above extract from models **you** fit.
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
can instead delegate the fitting to the
[regmedint](https://cran.r-project.org/package=regmedint) package, which
implements VanderWeele’s regression-based estimators in closed form, and
hand back the same medfit classes:

``` r
# regmedint requires a numeric 0/1 treatment, which mediation_demo has
med_rmi <- fit_mediation(
  formula_y = outcome_int ~ treatment * mediator1 + covariate1 + covariate2,
  formula_m = mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1",
  engine = "regmedint"
)

decompose(med_rmi)                        # same four-way layout as above
```

           cde    int_ref    int_med        pie        nde        nie      total
    0.21521278 0.04353909 0.27709549 0.34001758 0.25875187 0.61711307 0.87586495 

``` r
confint(med_rmi, parm = "components")     # regmedint's analytical SEs
```

    Normal (delta-method) approximation for four-way components; consider bootstrap_mediation() for robust inference.

                  2.5 %    97.5 %
    cde     -0.01242752 0.4428531
    int_ref -0.02378409 0.1108623
    int_med  0.13266955 0.4215214
    pie      0.19952257 0.4805126

The return class follows the same rule as
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md):
an `X:M` term in `formula_y` yields an `InteractionMediationData`, its
absence a plain `MediationData`. Components map from regmedint’s own
output as `CDE = cde`, `INTref = pnde − cde`, `INTmed = tnie − pnie`,
and `PIE = pnie`.

Standard errors come from regmedint’s delta method rather than medfit’s,
so they are analytical — no bootstrap needed — and reproduce the SEs
`regmedint::summary()` reports for the same model.

#### The reference mediator level

The four-way split is read off at a reference mediator level \\m^\*\\:

\\\text{CDE} = \theta_1 + \theta_3 m^\*\\

\\\text{INTref} = \theta_3\\(E\[M \mid X = 0\] - m^\*)\\

Set it with `fit_mediation(m_star = )`, which defaults to `0` on every
engine:

``` r
med_rm_m1 <- fit_mediation(
  formula_y = outcome_int ~ treatment * mediator1 + covariate1 + covariate2,
  formula_m = mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1",
  engine = "regmedint",
  m_star = 1
)

med_rm_m1@m_star   # the reference level that was used
```

    [1] 1

``` r
med_rm_m1@cde      # direct effect, holding the mediator at that level
```

    [1] 0.6907969

The two terms shift in exactly compensating directions, so
[`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`te()`](https://data-wise.github.io/medfit/reference/te.md), and
[`pm()`](https://data-wise.github.io/medfit/reference/pm.md) are
**invariant** to `m_star` — only the CDE/INTref split moves. Passing
`m_star` to a fit with no treatment-by-mediator term is an error, not a
silent no-op.

The engines reach the same answer by different routes. `engine = "glm"`
applies `m_star` at *extraction* time, after the coefficients are fit;
`engine = "regmedint"` hands the same value to
[`regmedint::regmedint()`](https://kaz-yos.github.io/regmedint/reference/regmedint.html)
as its `m_cde` argument, where the closed-form estimator consumes it at
*fitting* time. Because the two names denote one quantity, `m_cde` is
not accepted in `engine_args` — use `m_star`.

#### Other engine settings

Everything regmedint-specific that is *not* the reference level goes
through `engine_args`:

``` r
med_rmi2 <- fit_mediation(
  formula_y = outcome_int ~ treatment * mediator1 + covariate1 + covariate2,
  formula_m = mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1",
  engine = "regmedint",
  m_star = 1,           # reference mediator level (default 0)
  engine_args = list(
    c_cond = c(0, 0),   # covariate levels for the conditional effects (one per covariate)
    interaction = TRUE  # override the formula-based auto-detection
  )
)
```

Recognized names are `interaction`, `cvar`, `mreg`, `yreg`, `a0`, `a1`,
and `c_cond`; each replaces a value the adapter would otherwise derive
from the formulas, families, and data.

**Scope.** The regmedint engine needs a numeric 0/1 treatment and a
linear (Gaussian) mediator model; the outcome may be Gaussian or
binomial. Outside that range regmedint’s closed-form effects stop being
the products of regression coefficients that `MediationData` and
`InteractionMediationData` are defined in terms of, so the adapter
raises an explicit error instead of returning an object whose numbers
would disagree with
[`nie()`](https://data-wise.github.io/medfit/reference/nie.md).
`weights` and `se_type = "sandwich"` are likewise refused rather than
silently ignored. `regmedint` is a suggested package — install it with
`install.packages("regmedint")`.

## Compatibility with RMediation

The extraction design is compatible with RMediation’s lavaan extractor:

``` r
# RMediation extracts parameters for Distribution of Product method
# medfit extracts the same structure but as S7 classes

# Both packages can work with the same fitted models
# medfit provides infrastructure, RMediation adds DOP/MBCO methods
```

## Error Handling

The extraction uses **checkmate** for fail-fast input validation with
informative error messages:

``` r
# Variable not in model
extract_mediation(
  model_m,
  model_y,
  treatment = "NonExistent",
  mediator = "mediator1"
)
```

    Error in `.extract_mediation_lm_impl()`:
    ! Assertion on 'treatment in mediator model' failed: Must be element of set {'(Intercept)','treatment','covariate1','covariate2'}, but is 'NonExistent'.

``` r
# Wrong type for treatment argument
extract_mediation(
  model_m,
  model_y,
  treatment = 123,  # Should be character
  mediator = "mediator1"
)
```

    Error in `.extract_mediation_lm_impl()`:
    ! Assertion on 'treatment' failed: Must be of type 'string', not 'double'.

``` r
# Mediator not in outcome model
model_y_wrong <- lm(outcome ~ treatment + covariate1 + covariate2,
                    data = mediation_demo)  # Missing mediator1
extract_mediation(
  model_m,
  model_y_wrong,
  treatment = "treatment",
  mediator = "mediator1"
)
```

    Error in `.extract_mediation_lm_impl()`:
    ! Assertion on 'mediator in outcome model' failed: Must be element of set {'(Intercept)','treatment','covariate1','covariate2'}, but is 'mediator1'.

This defensive programming approach catches errors early with clear
messages, making debugging easier.

## Advanced Topics

### Extracting Full Parameter Vector

The `estimates` property contains all parameters from both models:

``` r
med_data <- extract_mediation(model_m, model_y, treatment = "treatment",
                              mediator = "mediator1")

# All parameters (intercepts + coefficients)
med_data@estimates
```

    m_(Intercept)   m_treatment  m_covariate1  m_covariate2 y_(Intercept)
       0.02052158    0.58264246    0.44789496    0.13109906    0.17120346
      y_treatment   y_mediator1  y_covariate1  y_covariate2             a
       0.20579826    0.57113843    0.35665236    0.05259769    0.58264246
                b       c_prime
       0.57113843    0.20579826 

``` r
# Access by name
med_data@estimates["a"]  # a_path
```

            a
    0.5826425 

``` r
med_data@estimates["b"]  # b_path
```

            b
    0.5711384 

### Covariance Matrix for Delta Method

Use the covariance matrix for computing standard errors:

``` r
# Covariance matrix of all parameters
vcov_mat <- med_data@vcov

# For delta method SE of indirect effect (a*b):
# Var(ab) = b^2 * Var(a) + a^2 * Var(b) + 2ab*Cov(a,b)

a <- med_data@a_path
b <- med_data@b_path
var_a <- vcov_mat["a", "a"]
var_b <- vcov_mat["b", "b"]
cov_ab <- vcov_mat["a", "b"]

var_indirect <- b^2 * var_a + a^2 * var_b + 2 * a * b * cov_ab
se_indirect <- sqrt(var_indirect)

se_indirect
```

    [1] 0.06449767

## Design for Extensibility

The extraction system is designed to accommodate future extensions:

- **New model types**: Add methods for lmer, brms, etc.
- **Complex mediation**: Moderated mediation
- **Multiple treatments**: Comparative mediation analysis
- **Latent variables**: SEM with measurement models

All classes share the same interface, so new model types plug into the
same effects, intervals and bootstrap.

## Next Steps

- Learn about [bootstrap
  inference](https://data-wise.github.io/medfit/articles/bootstrap.md)
  on extracted models
- See the
  [introduction](https://data-wise.github.io/medfit/articles/introduction.md)
  for S7 class details
- Read the [formulas behind every effect and standard
  error](https://data-wise.github.io/medfit/articles/methods.md)
- Check the reference documentation for
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  methods

## Working with Extracted Results

Once you have a `MediationData` object, you can use all medfit
functions:

### Effect Extractors

``` r
# Individual effects
nie(med_data)    # Natural Indirect Effect (a * b)
```

    Natural Indirect Effect (NIE): 0.3328

``` r
nde(med_data)    # Natural Direct Effect (c')
```

    Natural Direct Effect (NDE): 0.2058

``` r
te(med_data)     # Total Effect (nie + nde)
```

    Total Effect (TE): 0.5386

``` r
pm(med_data)     # Proportion Mediated
```

    Proportion Mediated (PM): 0.6179

``` r
# All path coefficients
paths(med_data)  # Named vector: a, b, c_prime
```

            a         b   c_prime
    0.5826425 0.5711384 0.2057983 

### Tidyverse Integration

``` r
library(generics)

# Convert to tibble
tidy(med_data)
```

    # A tibble: 6 × 3
      term    estimate std.error
      <chr>      <dbl>     <dbl>
    1 a          0.583    0.0989
    2 b          0.571    0.0535
    3 c_prime    0.206    0.110
    4 nie        0.333    0.0645
    5 nde        0.206    0.110
    6 te         0.539    0.119 

``` r
# Just path coefficients or effects
tidy(med_data, type = "paths")
```

    # A tibble: 3 × 3
      term    estimate std.error
      <chr>      <dbl>     <dbl>
    1 a          0.583    0.0989
    2 b          0.571    0.0535
    3 c_prime    0.206    0.110 

``` r
tidy(med_data, type = "effects")
```

    # A tibble: 3 × 3
      term  estimate std.error
      <chr>    <dbl>     <dbl>
    1 nie      0.333    0.0645
    2 nde      0.206    0.110
    3 te       0.539    0.119 

``` r
# With confidence intervals
tidy(med_data, conf.int = TRUE)
```

    # A tibble: 6 × 5
      term    estimate std.error conf.low conf.high
      <chr>      <dbl>     <dbl>    <dbl>     <dbl>
    1 a          0.583    0.0989  0.389       0.776
    2 b          0.571    0.0535  0.466       0.676
    3 c_prime    0.206    0.110  -0.00936     0.421
    4 nie        0.333    0.0645  0.206       0.459
    5 nde        0.206    0.110  -0.00936     0.421
    6 te         0.539    0.119   0.304       0.773

``` r
# One-row summary
glance(med_data)
```

    # A tibble: 1 × 6
        nie   nde    te    pm  nobs converged
      <dbl> <dbl> <dbl> <dbl> <int> <lgl>
    1 0.333 0.206 0.539 0.618   400 TRUE     

### Base R Methods

``` r
# Standard generics
coef(med_data)                # Path coefficients
```

            a         b   c_prime
    0.5826425 0.5711384 0.2057983 

``` r
coef(med_data, "effects")     # NIE, NDE, TE
```

          nie       nde        te
    0.3327695 0.2057983 0.5385678 

``` r
vcov(med_data)                # Variance-covariance matrix
```

                  m_(Intercept)   m_treatment  m_covariate1  m_covariate2
    m_(Intercept)  0.0071554488 -4.965720e-03 -3.621581e-04 -4.677171e-03
    m_treatment   -0.0049657198  9.773742e-03  6.574305e-04  8.913315e-05
    m_covariate1  -0.0003621581  6.574305e-04  2.349599e-03 -1.859182e-05
    m_covariate2  -0.0046771705  8.913315e-05 -1.859182e-05  9.601458e-03
    y_(Intercept)  0.0000000000  0.000000e+00  0.000000e+00  0.000000e+00
    y_treatment    0.0000000000  0.000000e+00  0.000000e+00  0.000000e+00
    y_mediator1    0.0000000000  0.000000e+00  0.000000e+00  0.000000e+00
    y_covariate1   0.0000000000  0.000000e+00  0.000000e+00  0.000000e+00
    y_covariate2   0.0000000000  0.000000e+00  0.000000e+00  0.000000e+00
    a             -0.0049657198  9.773742e-03  6.574305e-04  8.913315e-05
    b              0.0000000000  0.000000e+00  0.000000e+00  0.000000e+00
    c_prime        0.0000000000  0.000000e+00  0.000000e+00  0.000000e+00
                  y_(Intercept)   y_treatment   y_mediator1  y_covariate1
    m_(Intercept)  0.0000000000  0.0000000000  0.0000000000  0.0000000000
    m_treatment    0.0000000000  0.0000000000  0.0000000000  0.0000000000
    m_covariate1   0.0000000000  0.0000000000  0.0000000000  0.0000000000
    m_covariate2   0.0000000000  0.0000000000  0.0000000000  0.0000000000
    y_(Intercept)  0.0081124689 -0.0055948064 -0.0000587445 -0.0003842233
    y_treatment   -0.0055948064  0.0120510683 -0.0016678561  0.0014922734
    y_mediator1   -0.0000587445 -0.0016678561  0.0028625721 -0.0012821316
    y_covariate1  -0.0003842233  0.0014922734 -0.0012821316  0.0032377150
    y_covariate2  -0.0052942389  0.0003196938 -0.0003752805  0.0001470110
    a              0.0000000000  0.0000000000  0.0000000000  0.0000000000
    b             -0.0000587445 -0.0016678561  0.0028625721 -0.0012821316
    c_prime       -0.0055948064  0.0120510683 -0.0016678561  0.0014922734
                   y_covariate2             a             b       c_prime
    m_(Intercept)  0.0000000000 -4.965720e-03  0.0000000000  0.0000000000
    m_treatment    0.0000000000  9.773742e-03  0.0000000000  0.0000000000
    m_covariate1   0.0000000000  6.574305e-04  0.0000000000  0.0000000000
    m_covariate2   0.0000000000  8.913315e-05  0.0000000000  0.0000000000
    y_(Intercept) -0.0052942389  0.000000e+00 -0.0000587445 -0.0055948064
    y_treatment    0.0003196938  0.000000e+00 -0.0016678561  0.0120510683
    y_mediator1   -0.0003752805  0.000000e+00  0.0028625721 -0.0016678561
    y_covariate1   0.0001470110  0.000000e+00 -0.0012821316  0.0014922734
    y_covariate2   0.0109332064  0.000000e+00 -0.0003752805  0.0003196938
    a              0.0000000000  9.773742e-03  0.0000000000  0.0000000000
    b             -0.0003752805  0.000000e+00  0.0028625721 -0.0016678561
    c_prime        0.0003196938  0.000000e+00 -0.0016678561  0.0120510683

``` r
confint(med_data)             # 95% confidence intervals
```

                  2.5 %    97.5 %
    a        0.38887603 0.7764089
    b        0.46627446 0.6760024
    c_prime -0.00936141 0.4209579

``` r
confint(med_data, level = 0.90)
```

                   5 %      95 %
    a       0.42002855 0.7452564
    b       0.48313381 0.6591431
    c_prime 0.02523057 0.3863659

``` r
nobs(med_data)                # Sample size
```

    [1] 400

## Development Status

Model extraction is **complete**:

- ✅ S7 class definitions (MediationData, InteractionMediationData,
  SerialMediationData, ParallelMediationData, JointMediationData)
- ✅ lm/glm extraction with checkmate validation
- ✅ lavaan extraction with checkmate validation
- ✅ Effect extractors (nie, nde, te, pm, paths)
- ✅ Tidyverse methods (tidy, glance)
- ✅ Base R generics (coef, vcov, confint, nobs)
- 📋 lmer extraction (future)

See `NEWS.md` for updates.
