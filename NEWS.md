# medfit (development version)

## New features

* New S7 class `ParallelMediationData` for **parallel mediation**
  (`X -> M_j -> Y` for independent mediators `j = 1..k`). The total indirect
  effect is the sum of per-mediator products, `sum(a_j * b_j)`. Completes the
  structural trio alongside `MediationData` (simple) and `SerialMediationData`
  (serial). Effect extractors (`nie`, `nde`, `te`, `pm`, `paths`) have methods
  for the new class; `paths()` returns interleaved `a1, b1, a2, b2, ..., c_prime`.

* `extract_mediation()` now builds `ParallelMediationData` from **lm/glm** fits:
  pass the per-mediator models via `mediator_models` and the new
  `structure = "parallel"` argument. `structure = "auto"` (default) infers serial
  vs parallel from the mediator models' predictors and errors on an ambiguous mix.
  The returned `@vcov` is named `a1, b1, ..., c_prime`; the `b_j` (jointly fit in
  the outcome model) keep their mutual covariances and `cov(b_j, c')`, while the
  `a_j` (separate mediator regressions) are independent. (lavaan support to follow.)

* New `confint()` method for `ParallelMediationData` (`parm = "paths"` or
  `"effects"`). The indirect-effect variance uses the delta method over the full
  `{a1, b1, ..., ak, bk}` covariance block, so correlated `b_j` are handled
  correctly; `method = "boot"` directs to `bootstrap_mediation()`.

# medfit 0.2.0 (2026-05-31)

## New features

* `extract_mediation()` now supports **serial mediation**
  (`X -> M1 -> M2 -> ... -> Mk -> Y`), returning a `SerialMediationData` object.
  For **lavaan** fits, pass an ordered vector of mediator names
  (`mediator = c("M1", "M2")`); for **lm/glm** sequential regressions, pass the
  per-mediator models via the new `mediator_models` argument. The returned
  `@vcov` is named with the path aliases `a`, `d1`, ..., `b`, `c_prime` and
  preserves the full covariance structure (single-equation lavaan SEM keeps the
  off-diagonals; the separately-fitted lm equations are block-diagonal among
  chain paths with `cov(b, c')` preserved), so downstream serial
  indirect-effect confidence intervals are correct.

## Bug Fixes

* `extract_mediation()` for lavaan models now preserves the **off-diagonal**
  covariances among the `a`, `b`, and `c_prime` path aliases in the returned
  `@vcov`. Previously only the diagonal variances were copied, so
  `vcov[c("a", "b"), c("a", "b")]` reported `cov(a, b) = 0` even when the
  underlying lavaan fit had a genuinely non-zero covariance (e.g. single-equation
  SEM with correlated residuals, or the within-equation `cov(b, c')`). This
  silently biased downstream indirect-effect confidence intervals; the alias
  block now reproduces the true `lavaan::vcov()` covariances exactly.

* `print()` on the effect objects returned by `nie()`, `nde()`, `te()`, and
  `pm()` (class `mediation_effect`) now reliably shows the formatted label
  (e.g. `Natural Indirect Effect (NIE): 0.1897`). Because `mediation_effect`
  is layered on the base `numeric` type, S3 dispatch could miss
  `print.mediation_effect` and fall back to the bare numeric value plus raw
  attributes. The method is now explicitly registered in `.onLoad()` so
  dispatch works whether the package is installed or loaded via `load_all()`.

* The **lm/glm** extractor now copies the full within-equation covariance onto
  the `a`/`b`/`c_prime` aliases, so `cov(b, c_prime)` is preserved (previously
  only the diagonal variance was copied). The indirect effect `a * b` is
  unchanged; `cov(a, b)` remains `0` (separate equations).

## Internal

* Overall test coverage raised to >90% (enforced via `codecov`), and all
  repo-wide `lintr` warnings cleared. A shared alias-vcov helper
  (`.expand_vcov_with_aliases()`) now backs both the lm/glm and lavaan
  extractors so the two engines cannot drift.


# medfit 0.1.0 (2025-12-20)

**Initial CRAN release**

## Overview

medfit provides S7-based infrastructure for fitting mediation models, extracting path coefficients, and performing bootstrap inference. It serves as the foundation package for the mediationverse ecosystem.

## Major Features

### User-Friendly API

* **`med()` function** - Recommended entry point for most users
  - Fits mediator and outcome models automatically
  - Optional bootstrap inference with `boot = TRUE`
  - Supports covariates and different model families
  - Example: `med(data, treatment = "X", mediator = "M", outcome = "Y")`

* **`quick()` function** - One-line summary of results
  - Compact display: `NIE = 0.19 [0.08, 0.32] | NDE = 0.16 | PM = 55%`
  - Works with all medfit objects

### Effect Extractors

* **Dedicated functions for mediation effects**
  - `nie()`: Natural Indirect Effect (a × b)
  - `nde()`: Natural Direct Effect (c')
  - `te()`: Total Effect
  - `pm()`: Proportion Mediated
  - `paths()`: Path coefficients (a, b, c')

### Model Fitting and Extraction

* **`fit_mediation()` function** - Fit mediation models with formula interface
  - GLM engine for linear and generalized linear models
  - Support for continuous and binary outcomes
  - Covariates in both mediator and outcome models
  - Returns `MediationData` object

* **`extract_mediation()` generic** - Extract from fitted models
  - Methods for lm, glm objects
  - Optional lavaan support (when installed)
  - Extracts path coefficients and variance-covariance matrices

### Bootstrap Inference

* **`bootstrap_mediation()` function** - Three bootstrap methods
  - **Parametric**: Fast, assumes multivariate normality
  - **Nonparametric**: Robust, resamples data and refits models
  - **Plugin**: Point estimate only
  - Parallel processing support
  - Returns `BootstrapResult` with confidence intervals

### Tidyverse and Base R Integration

* **`tidy()` and `glance()` methods** for broom compatibility
  - `tidy()`: Convert to tibble (paths, effects, or both)
  - `tidy(conf.int = TRUE)`: Include confidence intervals
  - `glance()`: One-row model summary

* **Base R generics**: `coef()`, `vcov()`, `confint()`, `nobs()`

### S7 Class Architecture

* **Modern S7 object system** for type safety and extensibility
  - `MediationData`: Simple mediation (X → M → Y)
  - `SerialMediationData`: Serial mediation (X → M1 → M2 → ... → Y)
  - `BootstrapResult`: Bootstrap inference results
  - All classes include validators, print, summary, and show methods

### Input Validation

* **Defensive programming** with `checkmate` package
  - Fast, informative error messages
  - All user-facing functions validate inputs
  - Complements S7 class validators

## Documentation

* **Four comprehensive articles** (on the package website)
  - Getting Started: Quick introduction with examples
  - Introduction: Detailed package overview
  - Model Extraction: Extract from lm, glm, lavaan objects
  - Bootstrap Inference: Parametric and nonparametric methods

* **pkgdown website**: https://data-wise.github.io/medfit/

## Testing and Quality

* **427 comprehensive tests** (0 errors, 0 warnings)
  - Full coverage of S7 classes and methods
  - Validation tests for data integrity
  - Edge case handling

* **CI/CD**: GitHub Actions workflows
  - R CMD check on Ubuntu, macOS, Windows
  - Test coverage tracking with Codecov
  - Automated pkgdown deployment

## Ecosystem

* Foundation package for the **mediationverse** ecosystem
* Supports future integration with probmed, RMediation, medrobust
* Tested with R >= 4.1.0, S7 >= 0.1.0
