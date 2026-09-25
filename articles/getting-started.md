# Getting Started with medfit

## What is medfit?

**medfit** provides unified infrastructure for mediation analysis in R.
It offers:

- **ADHD-friendly API** with
  [`med()`](https://data-wise.github.io/medfit/reference/med.md) for
  quick analysis and
  [`quick()`](https://data-wise.github.io/medfit/reference/quick.md) for
  instant results
- **Effect extractors** like
  [`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
  [`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
  [`te()`](https://data-wise.github.io/medfit/reference/te.md),
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md), and
  [`paths()`](https://data-wise.github.io/medfit/reference/paths.md)
- **Tidyverse integration** with
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
  [`glance()`](https://generics.r-lib.org/reference/glance.html) methods
- **S7-based classes** for standardized mediation data structures
- **Foundation** for the mediation analysis ecosystem (RMediation,
  mediationverse)

## Quick Start: The Simplest Way

### One Function: `med()`

``` r
library(medfit)
```


    Attaching package: 'medfit'

    The following object is masked from 'package:stats':

        decompose

``` r
# Bundled simulated data (see ?mediation_demo)
data(mediation_demo)

# Run mediation analysis, adjusting for both covariates
result <- med(
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1",
  outcome = "outcome",
  covariates = c("covariate1", "covariate2")
)

# View results
print(result)
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
      Source:         stats::glm

    Residual SDs:
      Mediator model:   0.9792
      Outcome model:    1.0426

### Instant Results: `quick()`

``` r
# One-line summary
quick(result)
```

    NIE = 0.333  | NDE = 0.206 | PM = 61.8 %

### Why the Covariates Matter

`mediation_demo` is simulated so that `covariate1` and `covariate2`
affect both the mediators and the outcome. Leaving them out of either
model would bias the mediator-outcome path, so every example in this
article adjusts for both. The data are described in
[`?mediation_demo`](https://data-wise.github.io/medfit/reference/mediation_demo.md).

### With Bootstrap CI

``` r
# Get bootstrap confidence intervals
result_boot <- med(
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1",
  outcome = "outcome",
  covariates = c("covariate1", "covariate2"),
  boot = TRUE,
  n_boot = 1000,
  seed = 42
)

quick(result_boot)
```

    NIE = 0.333  [0.21, 0.464] | NDE = 0.206 | PM = 61.8 %

## Extract Individual Effects

Use dedicated extractor functions:

``` r
# Natural Indirect Effect (a * b)
nie(result)
```

    Natural Indirect Effect (NIE): 0.3328

``` r
# Natural Direct Effect (c')
nde(result)
```

    Natural Direct Effect (NDE): 0.2058

``` r
# Total Effect (nie + nde)
te(result)
```

    Total Effect (TE): 0.5386

``` r
# Proportion Mediated
pm(result)
```

    Proportion Mediated (PM): 0.6179

``` r
# All path coefficients
paths(result)
```

            a         b   c_prime
    0.5826425 0.5711384 0.2057983 

## Tidyverse Integration

Use [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
[`glance()`](https://generics.r-lib.org/reference/glance.html) for
tibble-based workflows:

``` r
library(generics)
```


    Attaching package: 'generics'

    The following objects are masked from 'package:base':

        as.difftime, as.factor, as.ordered, intersect, is.element, setdiff,
        setequal, union

``` r
# Tidy tibble of all estimates
tidy(result)
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
# Just paths with CIs
tidy(result, type = "paths", conf.int = TRUE)
```

    # A tibble: 3 × 5
      term    estimate std.error conf.low conf.high
      <chr>      <dbl>     <dbl>    <dbl>     <dbl>
    1 a          0.583    0.0989  0.389       0.776
    2 b          0.571    0.0535  0.466       0.676
    3 c_prime    0.206    0.110  -0.00936     0.421

``` r
# Just effects
tidy(result, type = "effects")
```

    # A tibble: 3 × 3
      term  estimate std.error
      <chr>    <dbl>     <dbl>
    1 nie      0.333    0.0645
    2 nde      0.206    0.110
    3 te       0.539    0.119 

``` r
# One-row model summary
glance(result)
```

    # A tibble: 1 × 6
        nie   nde    te    pm  nobs converged
      <dbl> <dbl> <dbl> <dbl> <int> <lgl>
    1 0.333 0.206 0.539 0.618   400 TRUE     

## Base R Methods

Standard R generics work on medfit objects:

``` r
# Coefficients
coef(result)                    # Path coefficients (a, b, c')
```

            a         b   c_prime
    0.5826425 0.5711384 0.2057983 

``` r
coef(result, type = "effects")  # Effects (nie, nde, te)
```

          nie       nde        te
    0.3327695 0.2057983 0.5385678 

``` r
coef(result, type = "all")      # All parameters
```

    m_(Intercept)   m_treatment  m_covariate1  m_covariate2 y_(Intercept)
       0.02052158    0.58264246    0.44789496    0.13109906    0.17120346
      y_treatment   y_mediator1  y_covariate1  y_covariate2             a
       0.20579826    0.57113843    0.35665236    0.05259769    0.58264246
                b       c_prime
       0.57113843    0.20579826 

``` r
# Variance-covariance matrix
vcov(result)
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
# Confidence intervals
confint(result)                       # 95% CI for paths
```

                  2.5 %    97.5 %
    a        0.38887603 0.7764089
    b        0.46627446 0.6760024
    c_prime -0.00936141 0.4209579

``` r
confint(result, level = 0.90)         # 90% CI
```

                   5 %      95 %
    a       0.42002855 0.7452564
    b       0.48313381 0.6591431
    c_prime 0.02523057 0.3863659

``` r
confint(result, parm = "effects")     # delta-method CI for effects
```

    Warning: Normal approximation for NIE may be inaccurate. Consider
    bootstrap_mediation() for robust inference.

              2.5 %    97.5 %
    nie  0.20635638 0.4591826
    nde -0.00936141 0.4209579
    te   0.30445672 0.7726788

``` r
# Number of observations
nobs(result)
```

    [1] 400

## Serial Mediation

For serial mediation (treatment -\> mediator1 -\> mediator2 -\>
outcome), fit one model per mediator plus the outcome model, then
extract:

``` r
fit_m1 <- lm(mediator1 ~ treatment + covariate1 + covariate2, data = mediation_demo)
fit_m2 <- lm(mediator2 ~ treatment + mediator1 + covariate1 + covariate2,
             data = mediation_demo)
# Keep mediator1 in the outcome model: it affects both mediator2 and the
# outcome, so leaving it out would bias the mediator2 -> outcome path
fit_y <- lm(outcome ~ treatment + mediator1 + mediator2 + covariate1 + covariate2,
            data = mediation_demo)

serial_data <- extract_mediation(
  fit_m1,
  model_y = fit_y,
  treatment = "treatment",
  mediator = c("mediator1", "mediator2"),
  mediator_models = list(fit_m2)
)

# Same extractors work
nie(serial_data)   # a * d * b: the effect through the chain mediator1 -> mediator2
```

    Natural Indirect Effect (NIE): 0.07545

``` r
nde(serial_data)   # c'
```

    Natural Direct Effect (NDE): 0.1712

``` r
quick(serial_data)
```

    [2 mediators] NIE chain = 0.0755 | NIE total = 0.367 | NDE = 0.171 | PM = 68.2%

The serial indirect effect covers only the path through both mediators
in order; paths such as mediator1 -\> outcome directly are not part of
it.

## Advanced Usage

### Extract from Fitted Models

If you already have fitted models:

``` r
# Fit models separately
fit_m <- lm(mediator1 ~ treatment + covariate1 + covariate2, data = mediation_demo)
fit_y <- lm(outcome ~ treatment + mediator1 + covariate1 + covariate2,
            data = mediation_demo)

# Extract mediation structure
med_data <- extract_mediation(
  fit_m,
  model_y = fit_y,
  treatment = "treatment",
  mediator = "mediator1"
)

# All the same methods work
nie(med_data)
```

    Natural Indirect Effect (NIE): 0.3328

``` r
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
quick(med_data)
```

    NIE = 0.333  | NDE = 0.206 | PM = 61.8 %

### fit_mediation() for Full Control

``` r
med_data <- fit_mediation(
  formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
  formula_m = mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1"
)

# Access path coefficients directly
med_data@a_path  # treatment to mediator
```

    [1] 0.5826425

``` r
med_data@b_path  # mediator to outcome
```

    [1] 0.5711384

``` r
med_data@c_prime # treatment to outcome, the direct path
```

    [1] 0.2057983

### Case Weights and Robust Standard Errors

`weights` passes case weights (for example survey weights or
inverse-probability weights) to both model fits. Model-based standard
errors assume the weights are known precision weights, which
inverse-probability weights are not, so pair them with
`se_type = "sandwich"` for heteroskedasticity-consistent (HC3) standard
errors; this needs the suggested sandwich package. The example builds
stabilized inverse-probability weights for the treatment from the
covariates. `mediation_demo`’s treatment is randomized, so the weights
stay close to 1 and mainly illustrate the calls:

``` r
# Stabilized inverse-probability-of-treatment weights
ps_fit <- glm(treatment ~ covariate1 + covariate2, family = binomial(),
              data = mediation_demo)
p_treat <- fitted(ps_fit)
p_marg  <- mean(mediation_demo$treatment)
ipw <- ifelse(mediation_demo$treatment == 1,
              p_marg / p_treat, (1 - p_marg) / (1 - p_treat))
summary(ipw)
```

       Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
     0.7044  0.8933  0.9841  0.9997  1.0954  1.5436 

``` r
med_ipw <- fit_mediation(
  formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
  formula_m = mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1",
  weights = ipw,
  se_type = "sandwich"
)

library(generics)
tidy(med_ipw, type = "effects", conf.int = TRUE)
```

    # A tibble: 3 × 5
      term  estimate std.error conf.low conf.high
      <chr>    <dbl>     <dbl>    <dbl>     <dbl>
    1 nie      0.335    0.0657   0.206      0.463
    2 nde      0.208    0.115   -0.0180     0.433
    3 te       0.542    0.119    0.308      0.776

With the default `se_type = "model"` the same fit gives NIE SE 0.0640
and NDE SE 0.109, and
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
prints a once-per-session message that model-based standard errors are
not valid under inverse-probability weighting. The weights also apply to
the covariate means used by the four-way decomposition when `formula_y`
has a treatment-by-mediator term. The regmedint engine supports neither
`weights` nor `se_type = "sandwich"`.

### Choosing an Engine

[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
defaults to `engine = "glm"`, which fits both models with
[`stats::glm()`](https://rdrr.io/r/stats/glm.html). A second engine
delegates to the suggested
[regmedint](https://cran.r-project.org/package=regmedint) package for
closed-form regression-based effects:

``` r
# regmedint requires a numeric 0/1 treatment (mediation_demo$treatment is one)
# and the same covariates in both formulas
med_rm <- fit_mediation(
  formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
  formula_m = mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1",
  engine = "regmedint"
)

nie(med_rm)   # every generic works the same way
```

    Natural Indirect Effect (NIE): 0.3328

If `formula_y` carries a treatment-by-mediator term (for example
`outcome_int ~ treatment * mediator1 + covariate1 + covariate2`), either
engine returns an `InteractionMediationData` with the four-way
decomposition — analytical standard errors in the regmedint case. The
reference mediator level for the CDE is set with `m_star` (default `0`,
on both engines); other engine-specific settings go through
`engine_args`. See [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md)
for the full mapping and its scope limits.

### Custom Bootstrap

``` r
# Define custom statistic function
indirect_effect <- function(theta) {
  theta["m_treatment"] * theta["y_mediator1"]
}

# Run bootstrap
boot_result <- bootstrap_mediation(
  statistic_fn = indirect_effect,
  method = "parametric",
  mediation_data = med_data,
  n_boot = 1000,
  ci_level = 0.95,
  seed = 123
)

# Bootstrap results also support tidy/glance
tidy(boot_result)
```

    # A tibble: 1 × 5
      term     estimate std.error conf.low conf.high
      <chr>       <dbl>     <dbl>    <dbl>     <dbl>
    1 estimate    0.333    0.0618    0.217     0.465

``` r
glance(boot_result)
```

    # A tibble: 1 × 4
      estimate ci_level method     n_boot
         <dbl>    <dbl> <chr>       <int>
    1    0.333     0.95 parametric   1000

## Learn More

- [Introduction to
  medfit](https://data-wise.github.io/medfit/articles/introduction.md) -
  Detailed S7 class documentation
- [Model
  Extraction](https://data-wise.github.io/medfit/articles/extraction.md) -
  Extract from lm, glm, lavaan models
- [Bootstrap
  Inference](https://data-wise.github.io/medfit/articles/bootstrap.md) -
  Parametric and nonparametric bootstrap
- [Methods and
  Formulas](https://data-wise.github.io/medfit/articles/methods.md) -
  Estimands, formulas, and standard errors

## What medfit Covers

- Simple mediation (`MediationData`), with a treatment-by-mediator
  interaction and the four-way decomposition
  (`InteractionMediationData`)
- Serial and parallel mediators (`SerialMediationData`,
  `ParallelMediationData`), and joint natural effects of several
  mediators with treatment-by-mediator products (`JointMediationData`)
- Extraction from lm/glm and lavaan fits; fitting with the `glm` and
  `regmedint` engines, optional case weights and sandwich standard
  errors
- Delta-method standard errors in
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
  [`confint()`](https://rdrr.io/r/stats/confint.html), and parametric,
  nonparametric and plugin bootstrap
- The [Methods and
  Formulas](https://data-wise.github.io/medfit/articles/methods.md)
  article gives the math behind every effect and standard error

See `NEWS.md` for the latest updates.
