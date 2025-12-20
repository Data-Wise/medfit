# Changelog

## medfit 0.1.0 (2025-12-20)

**Initial CRAN release**

### Overview

medfit provides S7-based infrastructure for fitting mediation models,
extracting path coefficients, and performing bootstrap inference. It
serves as the foundation package for the mediationverse ecosystem.

### Major Features

#### User-Friendly API

- **[`med()`](https://data-wise.github.io/medfit/reference/med.md)
  function** - Recommended entry point for most users
  - Fits mediator and outcome models automatically
  - Optional bootstrap inference with `boot = TRUE`
  - Supports covariates and different model families
  - Example: `med(data, treatment = "X", mediator = "M", outcome = "Y")`
- **[`quick()`](https://data-wise.github.io/medfit/reference/quick.md)
  function** - One-line summary of results
  - Compact display: `NIE = 0.19 [0.08, 0.32] | NDE = 0.16 | PM = 55%`
  - Works with all medfit objects

#### Effect Extractors

- **Dedicated functions for mediation effects**
  - [`nie()`](https://data-wise.github.io/medfit/reference/nie.md):
    Natural Indirect Effect (a × b)
  - [`nde()`](https://data-wise.github.io/medfit/reference/nde.md):
    Natural Direct Effect (c’)
  - [`te()`](https://data-wise.github.io/medfit/reference/te.md): Total
    Effect
  - [`pm()`](https://data-wise.github.io/medfit/reference/pm.md):
    Proportion Mediated
  - [`paths()`](https://data-wise.github.io/medfit/reference/paths.md):
    Path coefficients (a, b, c’)

#### Model Fitting and Extraction

- **[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  function** - Fit mediation models with formula interface
  - GLM engine for linear and generalized linear models
  - Support for continuous and binary outcomes
  - Covariates in both mediator and outcome models
  - Returns `MediationData` object
- **[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  generic** - Extract from fitted models
  - Methods for lm, glm objects
  - Optional lavaan support (when installed)
  - Extracts path coefficients and variance-covariance matrices

#### Bootstrap Inference

- **[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
  function** - Three bootstrap methods
  - **Parametric**: Fast, assumes multivariate normality
  - **Nonparametric**: Robust, resamples data and refits models
  - **Plugin**: Point estimate only
  - Parallel processing support
  - Returns `BootstrapResult` with confidence intervals

#### Tidyverse and Base R Integration

- **[`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
  [`glance()`](https://generics.r-lib.org/reference/glance.html)
  methods** for broom compatibility
  - [`tidy()`](https://generics.r-lib.org/reference/tidy.html): Convert
    to tibble (paths, effects, or both)
  - `tidy(conf.int = TRUE)`: Include confidence intervals
  - [`glance()`](https://generics.r-lib.org/reference/glance.html):
    One-row model summary
- **Base R generics**: [`coef()`](https://rdrr.io/r/stats/coef.html),
  [`vcov()`](https://rdrr.io/r/stats/vcov.html),
  [`confint()`](https://rdrr.io/r/stats/confint.html),
  [`nobs()`](https://rdrr.io/r/stats/nobs.html)

#### S7 Class Architecture

- **Modern S7 object system** for type safety and extensibility
  - `MediationData`: Simple mediation (X → M → Y)
  - `SerialMediationData`: Serial mediation (X → M1 → M2 → … → Y)
  - `BootstrapResult`: Bootstrap inference results
  - All classes include validators, print, summary, and show methods

#### Input Validation

- **Defensive programming** with `checkmate` package
  - Fast, informative error messages
  - All user-facing functions validate inputs
  - Complements S7 class validators

### Documentation

- **Four comprehensive vignettes**
  - Getting Started: Quick introduction with examples
  - Introduction: Detailed package overview
  - Model Extraction: Extract from lm, glm, lavaan objects
  - Bootstrap Inference: Parametric and nonparametric methods
- **pkgdown website**: <https://data-wise.github.io/medfit/>

### Testing and Quality

- **427 comprehensive tests** (0 errors, 0 warnings)
  - Full coverage of S7 classes and methods
  - Validation tests for data integrity
  - Edge case handling
- **CI/CD**: GitHub Actions workflows
  - R CMD check on Ubuntu, macOS, Windows
  - Test coverage tracking with Codecov
  - Automated pkgdown deployment

### Ecosystem

- Foundation package for the **mediationverse** ecosystem
- Supports future integration with probmed, RMediation, medrobust
- Tested with R \>= 4.1.0, S7 \>= 0.1.0
