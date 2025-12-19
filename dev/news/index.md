# Changelog

## medfit (development version)

### medfit 0.1.0.9000 (2025-12-17)

#### New Features

##### Phase 6.5: ADHD-Friendly API

- **[`med()`](https://data-wise.github.io/medfit/dev/reference/med.md)
  function** - Simple one-function mediation analysis
  - Fits mediator and outcome models automatically
  - Optional bootstrap inference with `boot = TRUE`
  - Supports covariates via `covariates` argument
  - Returns `MediationData` object
  - The recommended entry point for most users
- **[`quick()`](https://data-wise.github.io/medfit/dev/reference/quick.md)
  function** - One-line summary of mediation results
  - Works with any medfit object (`MediationData`,
    `SerialMediationData`)
  - Shows NIE, NDE, and PM in compact format
  - Includes bootstrap CI when available
  - Example output: `NIE = 0.19 [0.08, 0.32] | NDE = 0.16 | PM = 55%`

##### Phase 6: Generic Functions

- **Effect Extractors** - Dedicated functions for mediation effects
  - [`nie()`](https://data-wise.github.io/medfit/dev/reference/nie.md):
    Natural Indirect Effect (a × b)
  - [`nde()`](https://data-wise.github.io/medfit/dev/reference/nde.md):
    Natural Direct Effect (c’)
  - [`te()`](https://data-wise.github.io/medfit/dev/reference/te.md):
    Total Effect (nie + nde)
  - [`pm()`](https://data-wise.github.io/medfit/dev/reference/pm.md):
    Proportion Mediated
  - [`paths()`](https://data-wise.github.io/medfit/dev/reference/paths.md):
    All path coefficients (a, b, c’)
  - All return `mediation_effect` class with custom print method
- **Tidyverse Integration** -
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
  [`glance()`](https://generics.r-lib.org/reference/glance.html) methods
  - [`tidy()`](https://generics.r-lib.org/reference/tidy.html): Convert
    results to tibble with term, estimate, std.error
  - `tidy(x, type = "paths")`: Just path coefficients
  - `tidy(x, type = "effects")`: Just nie, nde, te
  - `tidy(x, conf.int = TRUE)`: Include confidence intervals
  - [`glance()`](https://generics.r-lib.org/reference/glance.html):
    One-row model summary (nie, nde, te, pm, nobs, converged)
  - Works on `MediationData`, `SerialMediationData`, and
    `BootstrapResult`
- **Base R Generics** - Standard S3/S7 methods for medfit classes
  - [`coef()`](https://rdrr.io/r/stats/coef.html): Extract coefficients
    (paths or effects)
  - [`vcov()`](https://rdrr.io/r/stats/vcov.html): Variance-covariance
    matrix
  - [`confint()`](https://rdrr.io/r/stats/confint.html): Confidence
    intervals (Wald-based)
  - [`nobs()`](https://rdrr.io/r/stats/nobs.html): Number of
    observations
  - Full S7/S3 dispatch compatibility

##### Previous Features (Phase 4-5)

- **[`fit_mediation()`](https://data-wise.github.io/medfit/dev/reference/fit_mediation.md)
  function** - Fit mediation models with formula interface
  - GLM engine for linear and generalized linear models
  - Support for continuous and binary outcomes (`family_y` argument)
  - Covariates supported in both mediator and outcome models
  - Full checkmate input validation
  - Returns `MediationData` object for downstream analysis
- **[`bootstrap_mediation()`](https://data-wise.github.io/medfit/dev/reference/bootstrap_mediation.md)
  function** - Bootstrap inference for mediation statistics
  - **Parametric bootstrap**: Fast, samples from multivariate normal
  - **Nonparametric bootstrap**: Robust, resamples data and refits
    models
  - **Plugin estimator**: Point estimate only, fastest method
  - Parallel processing support (`parallel = TRUE`, `ncores` argument)
  - Seed-based reproducibility
  - Returns `BootstrapResult` object with point estimate and CI

#### Documentation

- **Major documentation update** reflecting new API:
  - README.md: Complete rewrite of Quick Start with med()/quick()
    examples
  - getting-started.qmd: Full vignette rewrite with ADHD-friendly
    workflow
  - introduction.qmd: Updated with effect extractors, tidy/glance, base
    R methods
  - pkgdown reference: Reorganized into Quick Start, Effect Extractors,
    S7 Classes sections

#### Development Status

**Feature Complete (97%)**

- ✅ Phase 2: S7 class architecture
- ✅ Phase 3: Model extraction (lm/glm, lavaan)
- ✅ Phase 4: Model fitting
  ([`fit_mediation()`](https://data-wise.github.io/medfit/dev/reference/fit_mediation.md))
- ✅ Phase 5: Bootstrap infrastructure
- ✅ Phase 6: Generic functions (coef, vcov, confint, nobs, effect
  extractors, tidy, glance)
- ✅ Phase 6.5: ADHD-friendly API (med, quick)
- 🚧 Phase 7: Polish & release

**Code Quality**: 427 tests passing, 0 errors, 0 warnings

------------------------------------------------------------------------

### medfit 0.1.0

**Initial development release**

#### Major Features

- **Defensive Programming Infrastructure**
  - Added `checkmate` package for fail-fast input validation
  - All extraction functions now use `checkmate::assert_*` for argument
    validation
  - Provides fast (C-based), memory-efficient assertions with
    informative error messages
  - Complements S7 validators: checkmate for function entry, S7 for
    class integrity
- **Code Quality Tools** (NEW)
  - Added `.lintr` configuration for static code analysis
  - Added `lint.yaml` GitHub Action for automated linting on PRs
  - Comprehensive CLAUDE.md section on defensive programming best
    practices
  - 167+ tests passing with 0 errors, 0 warnings, 0 notes
- **S7 Class Architecture** (Phase 2 Complete + Extended)
  - `MediationData` class for simple mediation (X -\> M -\> Y)
  - **`SerialMediationData` class for serial mediation** (X -\> M1 -\>
    M2 -\> … -\> Y) **NEW**
    - Supports product-of-three (2 mediators: a \* d \* b)
    - Extensible to product-of-k (3+ mediators: a \* d21 \* d32 \* … \*
      b)
    - Flexible `d_path` design: scalar for 2 mediators, vector for 3+
    - Compatible with lavaan extraction patterns
  - `BootstrapResult` class for bootstrap inference results
  - Comprehensive validators ensuring data integrity
  - Print, summary, and show methods for all classes
- **Generics Defined**
  - [`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md) -
    Extract mediation structure from fitted models
  - [`fit_mediation()`](https://data-wise.github.io/medfit/dev/reference/fit_mediation.md) -
    Fit mediation models (stub)
  - [`bootstrap_mediation()`](https://data-wise.github.io/medfit/dev/reference/bootstrap_mediation.md) -
    Bootstrap inference (stub)

#### Documentation

- **Comprehensive Quarto Vignettes** (NEW)
  - **Get Started** (`vignettes/medfit.qmd`): Quick introduction with
    examples
  - **Introduction** (`vignettes/articles/introduction.qmd`): Detailed
    S7 class architecture
  - **Model Extraction** (`vignettes/articles/extraction.qmd`): Extract
    from lm/glm/lavaan
  - **Bootstrap Inference** (`vignettes/articles/bootstrap.qmd`):
    Parametric/nonparametric methods
  - All vignettes use native Quarto format with `execute:` options in
    YAML
  - Published at <https://data-wise.github.io/medfit/>
- **Roxygen2 Documentation**: Complete API documentation for all
  exported functions and classes
  - ASCII-compliant (replaced non-ASCII arrows and multiplication
    symbols)
  - Explicit `@param` tags for all S7 class properties
  - `@noRd` for S7 methods to prevent namespace export issues

#### Infrastructure

- **Testing**: 184 comprehensive tests (0 errors, 0 warnings, 1 skip)
  - Full coverage of simple and serial mediation S7 classes
  - Validation tests ensure data integrity across all mediation types
  - Tests updated for checkmate error message format
  - 1 skip: cannot test lavaan-not-installed path when lavaan is
    installed
- **CI/CD**: GitHub Actions workflows with Quarto support
  - R-CMD-check on Ubuntu (release, devel, oldrel-1), macOS, Windows
  - `lint.yaml` for static code analysis with lintr
  - pkgdown deployment with Quarto rendering
  - Test coverage tracking with Codecov
  - Dependabot for automated GitHub Actions updates
- **pkgdown Website**: <https://data-wise.github.io/medfit/>
  - Bootstrap 5 with Flatly theme
  - Comprehensive reference documentation
  - Four Quarto vignettes with rich examples
  - Auto-deployment on push to main branch

#### Development Status (at 0.1.0 release)

**Phase 5 Complete** - Bootstrap infrastructure implemented

Phase 1: Package setup (CI/CD, documentation, Dependabot)

Phase 2: S7 class architecture (MediationData, SerialMediationData,
BootstrapResult)

Phase 2.5: Comprehensive Quarto documentation (4 vignettes, pkgdown
website)

Phase 3: Model extraction (lm/glm, lavaan methods)

Phase 4: Model fitting
([`fit_mediation()`](https://data-wise.github.io/medfit/dev/reference/fit_mediation.md)
with GLM engine)

Phase 5: Bootstrap infrastructure (parametric, nonparametric, plugin)

*See 0.1.0.9000 above for Phase 6/6.5 additions.*

#### Documentation Improvements

- **S7 Class Documentation**: Added explicit `@param` tags for all class
  properties
- **S7 Method Documentation**: Updated to use `@noRd` to prevent
  namespace export issues
- **Generic Documentation**: Fixed
  [`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md)
  to only document generic parameters
- **CLAUDE.md**: Added comprehensive S7 documentation patterns section
  for future reference

#### Fixes

- **CI Failures**: Removed OpenMx from Suggests (was failing to compile
  on Ubuntu oldrel-1)
  - OpenMx integration postponed to future release
  - All GitHub Actions workflows now passing
- **S7 Method Registration**: Fixed proper registration order in
  `.onLoad()`
  - Call
    [`S7::S4_register()`](https://rconsortium.github.io/S7/reference/S4_register.html)
    for each class BEFORE `methods_register()`
  - Import full `methods` package (not just `@importFrom methods is`)
  - Per official S7 documentation:
    <https://rconsortium.github.io/S7/articles/packages.html>
  - SerialMediationData print/summary methods now work in installed
    package context
  - Removed 4 previously skipped tests (now all passing)
- **LICENSE**: Added `+ file LICENSE` to DESCRIPTION to properly
  reference LICENSE file
- **Codoc warnings**: Suppressed S7 constructor codoc checks with
  `--no-codoc` argument
  - S7-generated constructor defaults have whitespace formatting
    differences
  - This is a known S7/roxygen2 limitation

#### Known Issues

- OpenMx integration postponed (compilation issues on Ubuntu oldrel-1)

#### Ecosystem Notes

- Foundation package for the mediationverse ecosystem
- RMediation integration planned
- Tested with R 4.1.0+, S7 0.1.0+
- See [Ecosystem
  Coordination](https://data-wise.github.io/medfit/dev/news/planning/ECOSYSTEM.md)
  for cross-package guidelines

#### Internal

- Package skeleton created with proper structure
- GitHub repository initialized with `dev` branch workflow
- pkgdown website configuration
- Comprehensive CLAUDE.md and roadmap documentation

------------------------------------------------------------------------

*This is a development version. Breaking changes may occur.*
