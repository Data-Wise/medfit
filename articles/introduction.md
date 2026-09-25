# Introduction to medfit

## Overview

**medfit** provides unified infrastructure for mediation analysis in R.
It offers:

- **ADHD-friendly API**:
  [`med()`](https://data-wise.github.io/medfit/reference/med.md) for
  quick analysis,
  [`quick()`](https://data-wise.github.io/medfit/reference/quick.md) for
  instant results
- **Effect extractors**:
  [`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
  [`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
  [`te()`](https://data-wise.github.io/medfit/reference/te.md),
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md),
  [`paths()`](https://data-wise.github.io/medfit/reference/paths.md) for
  mediation effects
- **Tidyverse integration**:
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
  [`glance()`](https://generics.r-lib.org/reference/glance.html) methods
  for tibble workflows
- **Base R generics**: [`coef()`](https://rdrr.io/r/stats/coef.html),
  [`vcov()`](https://rdrr.io/r/stats/vcov.html),
  [`confint()`](https://rdrr.io/r/stats/confint.html),
  [`nobs()`](https://rdrr.io/r/stats/nobs.html) for S7 classes
- **S7-based classes** for standardized mediation data structures
- **Foundation** for the mediation analysis ecosystem (RMediation,
  mediationverse)

The package eliminates code duplication across mediation packages by
providing shared infrastructure while allowing each package to focus on
its unique methodological contributions.

## Core S7 Classes

medfit defines S7 classes for each mediation structure: `MediationData`
(simple), `InteractionMediationData` (simple with a
treatment-by-mediator interaction), `SerialMediationData`,
`ParallelMediationData`, `JointMediationData` (several mediators with
treatment-by-mediator products), and `BootstrapResult`. The three most
common are introduced here; see [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md)
for the others.

### MediationData

Stores simple mediation models (X -\> M -\> Y):

``` r
library(medfit)
```


    Attaching package: 'medfit'

    The following object is masked from 'package:stats':

        decompose

``` r
# Example: Create a MediationData object
med_data <- MediationData(
  a_path = 0.5,           # X -> M effect
  b_path = 0.3,           # M -> Y effect (controlling for X)
  c_prime = 0.2,          # X -> Y direct effect
  treatment = "X",
  mediator = "M",
  outcome = "Y",
  estimates = c(a = 0.5, b = 0.3, c_prime = 0.2),
  vcov = diag(3) * 0.01,  # Covariance matrix
  sigma_m = 1.0,          # residual SD of the mediator model
  sigma_y = 1.2,          # residual SD of the outcome model
  mediator_predictors = "X",
  outcome_predictors = c("X", "M"),
  data = NULL,
  n_obs = 100L,
  converged = TRUE,
  source_package = "medfit"
)

# Print method shows key information
print(med_data)
```

    MediationData object
    ====================

    Path coefficients:
      a (X -> M):        0.5000
      b (M -> Y|X):      0.3000
      c' (X -> Y|M):     0.2000
      Indirect (a*b):    0.1500

    Variables:
      Treatment: X
      Mediator:  M
      Outcome:   Y

    Model info:
      N observations: 100
      Converged:      Yes
      Source:         medfit

    Residual SDs:
      Mediator model:   1.0000
      Outcome model:    1.2000

``` r
# Summary method provides details
summary(med_data)
```

    Summary of MediationData
    ========================

    Path Coefficients:
           a        b  c_prime indirect
        0.50     0.30     0.20     0.15

    Variables:
    treatment  mediator   outcome
          "X"       "M"       "Y"

    Sample Size:  100
    Converged:    Yes
    Source:       medfit

    Residual Standard Deviations:
      Mediator model: 1
      Outcome model:  1.2

    Parameter Estimates:
          a       b c_prime
        0.5     0.3     0.2

    Variance-Covariance Matrix:
         [,1] [,2] [,3]
    [1,] 0.01 0.00 0.00
    [2,] 0.00 0.01 0.00
    [3,] 0.00 0.00 0.01

The indirect effect is computed as `a * b`. Use the effect extractors:

``` r
# Effect extractors (recommended)
nie(med_data)   # Natural Indirect Effect (a * b)
```

    Natural Indirect Effect (NIE): 0.15

``` r
nde(med_data)   # Natural Direct Effect (c')
```

    Natural Direct Effect (NDE): 0.2

``` r
te(med_data)    # Total Effect (nie + nde)
```

    Total Effect (TE): 0.35

``` r
pm(med_data)    # Proportion Mediated
```

    Proportion Mediated (PM): 0.4286

``` r
paths(med_data) # All path coefficients
```

          a       b c_prime
        0.5     0.3     0.2 

``` r
# Direct slot access (advanced)
med_data@a_path
```

    [1] 0.5

``` r
med_data@b_path
```

    [1] 0.3

``` r
med_data@a_path * med_data@b_path
```

    [1] 0.15

### Tidyverse Methods

``` r
library(generics)
```


    Attaching package: 'generics'

    The following objects are masked from 'package:base':

        as.difftime, as.factor, as.ordered, intersect, is.element, setdiff,
        setequal, union

``` r
# Tidy tibble of estimates
tidy(med_data)
```

    # A tibble: 6 × 3
      term    estimate std.error
      <chr>      <dbl>     <dbl>
    1 a           0.5         NA
    2 b           0.3         NA
    3 c_prime     0.2         NA
    4 nie         0.15        NA
    5 nde         0.2         NA
    6 te          0.35        NA

``` r
tidy(med_data, type = "paths")    # Just a, b, c'
```

    # A tibble: 3 × 3
      term    estimate std.error
      <chr>      <dbl>     <dbl>
    1 a            0.5        NA
    2 b            0.3        NA
    3 c_prime      0.2        NA

``` r
tidy(med_data, type = "effects")  # Just nie, nde, te
```

    # A tibble: 3 × 3
      term  estimate std.error
      <chr>    <dbl>     <dbl>
    1 nie       0.15        NA
    2 nde       0.2         NA
    3 te        0.35        NA

``` r
# One-row model summary
glance(med_data)
```

    # A tibble: 1 × 6
        nie   nde    te    pm  nobs converged
      <dbl> <dbl> <dbl> <dbl> <int> <lgl>
    1  0.15   0.2  0.35 0.429   100 TRUE     

### Base R Methods

``` r
# Standard generics work on medfit objects
coef(med_data)               # Path coefficients
```

          a       b c_prime
        0.5     0.3     0.2 

``` r
coef(med_data, "effects")    # nie, nde, te
```

     nie  nde   te
    0.15 0.20 0.35 

``` r
vcov(med_data)               # Variance-covariance matrix
```

         [,1] [,2] [,3]
    [1,] 0.01 0.00 0.00
    [2,] 0.00 0.01 0.00
    [3,] 0.00 0.00 0.01

``` r
confint(med_data)            # Confidence intervals
```

                  2.5 %    97.5 %
    a       0.304003602 0.6959964
    b       0.104003602 0.4959964
    c_prime 0.004003602 0.3959964

``` r
nobs(med_data)               # Number of observations
```

    [1] 100

### SerialMediationData

Stores serial mediation models (X -\> M1 -\> M2 -\> … -\> Y):

``` r
# Example: Two-mediator serial mediation (X -> M1 -> M2 -> Y)
serial_data <- SerialMediationData(
  a_path = 0.4,           # treatment to first mediator
  d_path = 0.5,           # M1 -> M2 (scalar for 2 mediators)
  b_path = 0.3,           # second mediator to outcome
  c_prime = 0.2,          # X -> Y direct effect
  treatment = "X",
  mediators = c("M1", "M2"),
  outcome = "Y",
  estimates = c(a = 0.4, d = 0.5, b = 0.3, c_prime = 0.2),
  vcov = diag(4) * 0.01,
  sigma_mediators = c(1.0, 1.1),  # residual SDs of the M1 and M2 models
  sigma_y = 1.2,
  # A pure chain: M2 depends on M1 only, and Y on X and M2 only. Paths that
  # skip a mediator would need their own coefficients (extract_mediation()
  # records them), or te() and pm() return NA.
  mediator_predictors = list(M1 = "X", M2 = "M1"),
  outcome_predictors = c("X", "M2"),
  data = NULL,
  n_obs = 100L,
  converged = TRUE,
  source_package = "medfit"
)

print(serial_data)
```

    SerialMediationData object
    ==========================

    Serial mediation chain:
      X -> M1 -> M2 -> Y

    Path coefficients:
      a  (X -> M1):         0.4000
      d  (M1 -> M2):         0.5000
      b  (M2 -> Y):         0.3000
      c' (X -> Y|M):       0.2000

    Indirect effect:
      a * d * b =   0.0600

    Model info:
      N mediators:    2
      N observations: 100
      Converged:      Yes
      Source:         medfit

    Residual SDs:
      M1 model:   1.0000
      M2 model:   1.1000
      Outcome model:    1.2000

For two mediators, the serial indirect effect is `a * d * b`:

``` r
# Use extractors (recommended)
nie(serial_data)    # product a, d, b
```

    Natural Indirect Effect (NIE): 0.06

``` r
nde(serial_data)    # c'
```

    Natural Direct Effect (NDE): 0.2

``` r
quick(serial_data)  # One-line summary
```

    [2 mediators] NIE chain = 0.06 | NIE total = 0.06 | NDE = 0.2 | PM = 23.1%

``` r
# Direct computation
serial_data@a_path * serial_data@d_path * serial_data@b_path
```

    [1] 0.06

**Design for extensibility**: For 3+ mediators, `d_path` becomes a
vector: - 3 mediators: `a * d21 * d32 * b` (product-of-four) - k
mediators: product-of-(k+1)

### BootstrapResult

Stores bootstrap inference results:

``` r
# Example: Bootstrap result for indirect effect
boot_result <- BootstrapResult(
  estimate = 0.15,        # Point estimate (a * b)
  ci_lower = 0.08,        # Lower CI bound
  ci_upper = 0.25,        # Upper CI bound
  ci_level = 0.95,        # Confidence level
  boot_estimates = rnorm(1000, mean = 0.15, sd = 0.04),  # Bootstrap distribution
  n_boot = 1000L,
  method = "parametric"
)

print(boot_result)
```

    BootstrapResult object
    ======================

    Method:   parametric
    Estimate:   0.1500
    N bootstrap samples: 1000

    95% Confidence Interval:
      Lower:   0.0800
      Upper:   0.2500

``` r
summary(boot_result)
```

    Summary of BootstrapResult
    ==========================

    Method:    parametric
    Estimate:  0.15
    N bootstrap samples: 1000

    95% Confidence Interval:
      Lower: 0.08
      Upper: 0.25

    Bootstrap Distribution Summary:
       Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
    0.03542 0.12213 0.14801 0.14943 0.17852 0.26576 

## Main Functions

### Quick Start Functions

The simplest way to run mediation analysis:

``` r
library(medfit)

# mediation_demo: simulated data bundled with medfit (see ?mediation_demo).
# Its covariates confound the mediator-outcome relation, so adjust for them.
result <- med(
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1",
  outcome = "outcome",
  covariates = c("covariate1", "covariate2")
)

# Instant summary
quick(result)
```

    NIE = 0.333  | NDE = 0.206 | PM = 61.8 %

``` r
# With bootstrap CI
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

### Effect Extractors

Dedicated functions for extracting mediation effects:

``` r
nie(result)   # Natural Indirect Effect (a * b)
```

    Natural Indirect Effect (NIE): 0.3328

``` r
nde(result)   # Natural Direct Effect (c')
```

    Natural Direct Effect (NDE): 0.2058

``` r
te(result)    # Total Effect (nie + nde)
```

    Total Effect (TE): 0.5386

``` r
pm(result)    # Proportion Mediated
```

    Proportion Mediated (PM): 0.6179

``` r
paths(result) # All path coefficients (a, b, c')
```

            a         b   c_prime
    0.5826425 0.5711384 0.2057983 

### extract_mediation()

Extract mediation structure from pre-fitted models:

``` r
# From lm/glm models
fit_m <- lm(mediator1 ~ treatment + covariate1 + covariate2,
            data = mediation_demo)
fit_y <- lm(outcome ~ treatment + mediator1 + covariate1 + covariate2,
            data = mediation_demo)

med_data <- extract_mediation(
  fit_m,
  model_y = fit_y,
  treatment = "treatment",
  mediator = "mediator1"
)

# From a fitted lavaan SEM model (paths labeled a, b, cp)
sem_model <- "
  mediator1 ~ a * treatment + covariate1 + covariate2
  outcome ~ cp * treatment + b * mediator1 + covariate1 + covariate2
"
lavaan_fit <- lavaan::sem(sem_model, data = mediation_demo)
med_data <- extract_mediation(
  lavaan_fit,
  treatment = "treatment",
  mediator = "mediator1",
  outcome = "outcome"
)
```

See [Model
Extraction](https://data-wise.github.io/medfit/articles/extraction.md)
for details.

### fit_mediation()

Fit mediation models with formula interface:

``` r
# Fit using GLM engine
med_data <- fit_mediation(
  formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
  formula_m = mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1"
)
```

### bootstrap_mediation()

Perform bootstrap inference on indirect effects:

``` r
# Define statistic function
indirect_fn <- function(theta) {
  theta["m_treatment"] * theta["y_mediator1"]
}

# Parametric bootstrap
boot_result <- bootstrap_mediation(
  statistic_fn = indirect_fn,
  method = "parametric",
  mediation_data = med_data,
  n_boot = 1000,
  ci_level = 0.95,
  seed = 12345
)

# tidy/glance work on bootstrap results too
tidy(boot_result)
```

    # A tibble: 1 × 5
      term     estimate std.error conf.low conf.high
      <chr>       <dbl>     <dbl>    <dbl>     <dbl>
    1 estimate    0.333    0.0658    0.216     0.467

``` r
glance(boot_result)
```

    # A tibble: 1 × 4
      estimate ci_level method     n_boot
         <dbl>    <dbl> <chr>       <int>
    1    0.333     0.95 parametric   1000

See [Bootstrap
Inference](https://data-wise.github.io/medfit/articles/bootstrap.md) for
details.

## Package Ecosystem

medfit serves as the foundation for specialized mediation packages:

- **RMediation**: Confidence intervals via distribution methods
  - Uses medfit for extraction
  - Adds Distribution of Product (DOP), MBCO tests
- **mediationverse**: Meta-package for the ecosystem
  - Loads medfit and RMediation together
  - Provides unified documentation

## Design Principles

1.  **Type safety**: S7 classes with validators ensure data integrity
2.  **Defensive programming**: checkmate assertions for fail-fast input
    validation
3.  **Consistency**: Standardized interfaces across model types
4.  **Extensibility**: Easy to add new model engines and methods
5.  **Minimal dependencies**: Core functionality with minimal external
    dependencies
6.  **Infrastructure focus**: Provides tools, not effect sizes

## Next Steps

- Learn about [model
  extraction](https://data-wise.github.io/medfit/articles/extraction.md)
  from different sources
- Explore [bootstrap inference
  methods](https://data-wise.github.io/medfit/articles/bootstrap.md)
- Read the [formulas behind every effect and standard
  error](https://data-wise.github.io/medfit/articles/methods.md)
- See the reference documentation for detailed API information

See `NEWS.md` for the latest updates.
