# Introduction to medfit

## Overview

**medfit** provides unified infrastructure for mediation analysis in R.
It offers:

- **S7-based classes** for standardized mediation data structures
- **Generic functions** for model fitting, extraction, and inference
- **Foundation** for the mediation analysis ecosystem (probmed,
  RMediation, medrobust)

The package eliminates code duplication across mediation packages by
providing shared infrastructure while allowing each package to focus on
its unique methodological contributions.

## Core S7 Classes

medfit defines three main S7 classes to represent mediation structures:

### MediationData

Stores simple mediation models (X -\> M -\> Y):

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
  n_obs = 100L,
  converged = TRUE,
  source_package = "medfit"
)

# Print method shows key information
print(med_data)

# Summary method provides details
summary(med_data)
```

The indirect effect is computed as `a * b`:

``` r
# Access path coefficients
med_data@a_path
med_data@b_path

# Indirect effect
med_data@a_path * med_data@b_path
```

### SerialMediationData

Stores serial mediation models (X -\> M1 -\> M2 -\> … -\> Y):

``` r
# Example: Two-mediator serial mediation (X -> M1 -> M2 -> Y)
serial_data <- SerialMediationData(
  a_path = 0.4,           # X -> M1
  d_path = 0.5,           # M1 -> M2 (scalar for 2 mediators)
  b_path = 0.3,           # M2 -> Y
  c_prime = 0.2,          # X -> Y direct effect
  treatment = "X",
  mediators = c("M1", "M2"),
  outcome = "Y",
  estimates = c(a = 0.4, d = 0.5, b = 0.3, c_prime = 0.2),
  vcov = diag(4) * 0.01,
  mediator_predictors = list(M1 = "X", M2 = c("X", "M1")),
  outcome_predictors = c("X", "M1", "M2"),
  n_obs = 100L,
  converged = TRUE,
  source_package = "medfit"
)

print(serial_data)
```

For two mediators, the serial indirect effect is `a * d * b`:

``` r
# Serial indirect effect (product-of-three)
serial_data@a_path * serial_data@d_path * serial_data@b_path
```

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
  method = "parametric",
  converged = TRUE
)

print(boot_result)
summary(boot_result)
```

## Main Functions

medfit provides three generic functions that work across different model
types:

### extract_mediation()

Extract mediation structure from fitted models:

``` r
# From lm/glm models
med <- extract_mediation(
  model_m,           # Mediator model (M ~ X)
  model_y,           # Outcome model (Y ~ X + M)
  treatment = "X",
  mediator = "M"
)

# From lavaan SEM models
med <- extract_mediation(
  lavaan_fit,
  treatment = "X",
  mediator = "M",
  outcome = "Y"
)
```

See `vignette("extraction")` for details.

### fit_mediation()

Fit mediation models directly:

``` r
# Fit using GLM engine
med <- fit_mediation(
  data = mydata,
  treatment = "X",
  mediator = "M",
  outcome = "Y",
  engine = "glm",
  family_m = gaussian(),
  family_y = gaussian()
)
```

### bootstrap_mediation()

Perform bootstrap inference on indirect effects:

``` r
# Parametric bootstrap
boot_result <- bootstrap_mediation(
  med_data,
  method = "parametric",
  n_boot = 1000,
  ci_level = 0.95,
  parallel = TRUE
)

# Nonparametric bootstrap (resamples data, refits models)
boot_result <- bootstrap_mediation(
  med_data,
  method = "nonparametric",
  n_boot = 1000
)
```

See `vignette("bootstrap")` for details.

## Package Ecosystem

medfit serves as the foundation for specialized mediation packages:

- **probmed**: Probabilistic mediation effect size (P_med)
  - Uses medfit for infrastructure
  - Adds P_med computation and visualization
- **RMediation**: Confidence intervals via distribution methods
  - Uses medfit for extraction
  - Adds Distribution of Product (DOP), MBCO tests
- **medrobust**: Sensitivity analysis
  - Uses medfit for baseline estimates
  - Adds bounds computation, falsification tests

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
  extraction](https://data-wise.github.io/medfit/dev/articles/extraction.md)
  from different sources
- Explore [bootstrap inference
  methods](https://data-wise.github.io/medfit/dev/articles/bootstrap.md)
- See the reference documentation for detailed API information

## Development Status

medfit is under active development. Current status:

- ✅ Phase 2 Complete: S7 class architecture
- ✅ Phase 3 Complete: Model extraction (lm/glm, lavaan)
- 🚧 Phase 4 In Progress: Model fitting
- 📋 Planned: Bootstrap infrastructure

See `NEWS.md` for the latest updates.
