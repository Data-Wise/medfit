# medfit Package Development Roadmap

**Package**: medfit - Mediation model fitting and extraction infrastructure
**Status**: Phase 6 Complete → Phase 7 (Polish & Release)
**Timeline**: 4-6 weeks for MVP (Started December 2024)
**Last Updated**: December 16, 2025

---

## Mission Statement

> **medfit** provides unified infrastructure for fitting and extracting mediation models in R, enabling consistent model handling across the mediation analysis ecosystem.

---

## Package Specifications

### Core Identity

**Package Name**: medfit
**Title**: Infrastructure for Mediation Model Fitting and Extraction
**Description**: Provides S7-based infrastructure for fitting mediation models, extracting path coefficients, and performing bootstrap inference. Designed as a foundation package for probmed, RMediation, and medrobust.

**Version**: 0.1.0 (MVP)
**License**: GPL-3
**R Version**: >= 4.1.0
**Repository**: https://github.com/data-wise/medfit

### Dependencies

**Imports**:
- S7 (>= 0.1.0)
- stats (>= 4.1.0)
- methods

**Suggests**:
- MASS (for mvrnorm in parametric bootstrap)
- lavaan (>= 0.6-0) - SEM extraction
- OpenMx (>= 2.13) - SEM extraction
- lme4 (future - mixed models)
- testthat (>= 3.0.0)
- knitr
- rmarkdown

---

## Phase 1: Package Setup (Week 1) ✅ COMPLETE

**Goal**: Create package skeleton with basic infrastructure

### 1.1 Repository & Structure

- [x] Create GitHub repository: `data-wise/medfit`
- [x] Initialize R package structure
- [x] Set up `.Rbuildignore`, `.gitignore`
- [x] Create DESCRIPTION file
- [x] Create LICENSE file (GPL-3)
- [x] Set up GitHub Actions CI/CD
  - [x] R-CMD-check.yaml (multi-platform with Quarto support)
  - [x] test-coverage.yaml
  - [x] pkgdown.yaml (with Quarto rendering)

### 1.2 Documentation Setup

- [x] Create README.md with:
  - Package overview
  - Installation instructions
  - Quick start examples
  - Links to documentation
  - Ecosystem diagram
- [x] Create CLAUDE.md with:
  - Package architecture
  - Coding standards
  - Development workflow
  - S7 documentation patterns
  - Quarto vignette workflow
- [x] Create NEWS.md
- [x] Set up pkgdown configuration (_pkgdown.yml)

### 1.3 Package Files

**R/ directory structure**:
```
R/
├── aaa-imports.R           # Package imports
├── medfit-package.R        # Package documentation
├── classes.R               # S7 class definitions
├── generics.R              # S7 generic functions
├── fit-glm.R              # GLM fitting methods
├── extract-lm.R           # lm/glm extraction
├── extract-lavaan.R       # lavaan extraction
├── extract-openmx.R       # OpenMx extraction
├── bootstrap.R            # Bootstrap infrastructure
├── utils.R                # Utility functions
└── zzz.R                  # .onLoad() for dynamic dispatch
```

**Deliverables**:
- Clean package skeleton
- Passing R CMD check (even if functions are stubs)
- CI/CD workflows configured

**Time**: 2-3 days

---

## Phase 2: S7 Class Architecture (Week 1-2) ✅ COMPLETE

**Goal**: Define and implement core S7 classes

**Status**: Extended beyond original scope to include SerialMediationData for complex mediation structures.

### 2.1 MediationData Class

**Purpose**: Standardized container for mediation model structure

```r
#' @title MediationData
#' @description Base S7 class for mediation model information
MediationData <- S7::new_class(
  "MediationData",
  package = "medfit",
  properties = list(
    # Core paths
    a_path = S7::class_numeric,              # X → M
    b_path = S7::class_numeric,              # M → Y
    c_prime = S7::class_numeric,             # X → Y (direct)

    # Parameters
    estimates = S7::class_numeric,           # All parameter estimates
    vcov = S7::class_matrix,                 # Variance-covariance matrix

    # Residual variances (for Gaussian models)
    sigma_m = S7::class_numeric,             # Residual SD for M model
    sigma_y = S7::class_numeric,             # Residual SD for Y model

    # Variable names
    treatment = S7::class_character,
    mediator = S7::class_character,
    outcome = S7::class_character,
    mediator_predictors = S7::class_character,
    outcome_predictors = S7::class_character,

    # Data and metadata
    data = S7::class_data.frame | NULL,
    n_obs = S7::class_integer,
    converged = S7::class_logical,
    source_package = S7::class_character
  ),

  validator = function(self) {
    # Validate paths
    if (length(self@a_path) != 1) "a_path must be scalar"
    else if (length(self@b_path) != 1) "b_path must be scalar"
    else if (length(self@c_prime) != 1) "c_prime must be scalar"

    # Validate vcov is square
    else if (nrow(self@vcov) != ncol(self@vcov)) "vcov must be square"

    # Validate n_obs
    else if (self@n_obs < 1) "n_obs must be positive"
  }
)
```

### 2.2 BootstrapResult Class

**Purpose**: Container for bootstrap inference results

```r
#' @title BootstrapResult
#' @description Results from bootstrap inference
BootstrapResult <- S7::new_class(
  "BootstrapResult",
  package = "medfit",
  properties = list(
    # Point estimates
    estimate = S7::class_numeric,

    # Confidence intervals
    ci_lower = S7::class_numeric,
    ci_upper = S7::class_numeric,
    ci_level = S7::class_numeric,

    # Bootstrap distribution
    boot_estimates = S7::class_numeric,
    n_boot = S7::class_integer,

    # Method
    method = S7::class_character,  # "parametric", "nonparametric", "plugin"

    # Metadata
    call = S7::class_call | NULL
  ),

  validator = function(self) {
    # Validate CI
    if (self@ci_lower > self@ci_upper) "ci_lower must be <= ci_upper"
    else if (self@ci_level <= 0 || self@ci_level >= 1) "ci_level must be in (0, 1)"

    # Validate method
    else if (!(self@method %in% c("parametric", "nonparametric", "plugin"))) {
      "method must be 'parametric', 'nonparametric', or 'plugin'"
    }
  }
)
```

### 2.3 S7 Methods

Implement basic methods for both classes:

```r
# Print methods
S7::method(print, MediationData) <- function(x, ...) { ... }
S7::method(print, BootstrapResult) <- function(x, ...) { ... }

# Summary methods
S7::method(summary, MediationData) <- function(object, ...) { ... }
S7::method(summary, BootstrapResult) <- function(object, ...) { ... }

# Show methods (for compatibility)
S7::method(show, MediationData) <- function(object) print(object)
S7::method(show, BootstrapResult) <- function(object) print(object)
```

**Deliverables**:
- [x] S7 classes defined and validated (MediationData, SerialMediationData, BootstrapResult)
- [x] Basic methods (print, summary, show) for all classes
- [x] Unit tests for class validation (87 tests total)
- [x] Documentation for classes (roxygen2 + man pages)
- [x] S7 method registration via .onAttach() for installed package context

**Time**: 2-3 days (completed)

---

## Phase 2.5: Comprehensive Documentation (Added) ✅ COMPLETE

**Goal**: Create comprehensive Quarto vignettes and documentation infrastructure

**Status**: Added comprehensive documentation beyond original scope to provide clear usage examples and architectural guidance.

### 2.5.1 Quarto Vignettes Created

- [x] **Get Started** (`vignettes/medfit.qmd`)
  - Quick introduction to medfit
  - Basic S7 class usage examples
  - Simple and serial mediation examples

- [x] **Introduction** (`vignettes/articles/introduction.qmd`)
  - Detailed S7 class architecture
  - All three S7 classes (MediationData, SerialMediationData, BootstrapResult)
  - Design principles and extensibility
  - Package ecosystem context

- [x] **Model Extraction** (`vignettes/articles/extraction.qmd`)
  - Extraction patterns from lm/glm models
  - Planned lavaan extraction patterns
  - Compatibility with RMediation
  - Error handling and validation

- [x] **Bootstrap Inference** (`vignettes/articles/bootstrap.qmd`)
  - Three bootstrap methods (parametric, nonparametric, plugin)
  - Parallel processing guidance
  - Reproducibility with seeds
  - Best practices and diagnostics

### 2.5.2 Documentation Infrastructure

- [x] All vignettes use native Quarto format
  - `format: html` in YAML frontmatter
  - `execute:` options for chunk behavior
  - No knitr setup chunks needed

- [x] GitHub Actions Quarto support
  - `quarto-dev/quarto-actions/setup@v2` in workflows
  - Automatic Quarto installation for .qmd files
  - Both R-CMD-check and pkgdown workflows updated

- [x] pkgdown website configuration
  - Bootstrap 5 with Flatly theme
  - All vignettes in reference index
  - Website URL in DESCRIPTION
  - Auto-deployment to https://data-wise.github.io/medfit/

- [x] CLAUDE.md documentation
  - Quarto vignettes workflow best practices
  - pkgdown configuration patterns
  - Articles vs vignettes guidance

**Deliverables**:
- [x] Four comprehensive Quarto vignettes (>1000 lines total)
- [x] Native Quarto format throughout
- [x] Quarto support in CI/CD workflows
- [x] Published pkgdown website with all documentation
- [x] Development workflow documentation in CLAUDE.md

**Time**: 1 day (completed December 2, 2025)

---

## Phase 3: Model Extraction API (Week 2) ✅ COMPLETE

**Goal**: Implement `extract_mediation()` generic and core methods

### 3.1 Generic Definition

```r
#' Extract Mediation Structure from Fitted Models
#'
#' @description
#' Generic function to extract mediation structure (a, b, c' paths and
#' variance-covariance matrices) from fitted models.
#'
#' @param object Fitted model object
#' @param treatment Character: name of treatment variable
#' @param mediator Character: name of mediator variable
#' @param outcome Character: name of outcome variable (optional for some models)
#' @param ... Additional arguments passed to methods
#'
#' @return MediationData object
#' @export
extract_mediation <- S7::new_generic(
  "extract_mediation",
  dispatch_args = "object"
)
```

### 3.2 Method: lm/glm

**Source**: Extract from probmed `R/methods-extract.R`

```r
#' @export
S7::method(extract_mediation, lm_class) <- function(object,
                                                     treatment,
                                                     mediator,
                                                     model_y = NULL,
                                                     data = NULL,
                                                     ...) {
  # Validate inputs
  # Extract coefficients and vcov
  # Create MediationData object
  # Return
}
```

**Key steps**:
1. Copy code from probmed
2. Adapt to return MediationData (not MediationExtract)
3. Ensure explicit namespacing
4. Add comprehensive input validation
5. Handle edge cases (missing data, convergence)

### 3.3 Method: lavaan

**Source**: Extract from probmed `R/methods-extract-lavaan.R`

**Requires**: Dynamic S7/S4 dispatch (via .onLoad)

```r
# In R/zzz.R
.onLoad <- function(libname, pkgname) {
  if (requireNamespace("lavaan", quietly = TRUE)) {
    lavaan_class <- S7::as_class(methods::getClass("lavaan", where = "lavaan"))
    S7::method(extract_mediation, lavaan_class) <- extract_mediation_lavaan
  }
}

# In R/extract-lavaan.R
extract_mediation_lavaan <- function(object, treatment, mediator,
                                     outcome = NULL, standardized = FALSE, ...) {
  # Extract parameters from lavaan object
  # Auto-detect outcome if needed
  # Extract paths and vcov
  # Create MediationData object
  # Return
}
```

### 3.4 Method: OpenMx

**Source**: Extract patterns from RMediation (if available)

```r
#' @export
S7::method(extract_mediation, openmx_class) <- function(object,
                                                         treatment,
                                                         mediator,
                                                         outcome = NULL,
                                                         ...) {
  # Extract from OpenMx fitted model
  # Similar pattern to lavaan
}
```

**Note**: May defer OpenMx to Phase 3 if complex

**Deliverables**:
- `extract_mediation()` generic
- Methods for lm/glm (required)
- Method for lavaan (required)
- Method for OpenMx (nice-to-have)
- Comprehensive tests
- Examples in documentation

**Time**: 3-4 days

---

## Phase 4: Model Fitting API (Week 2-3) ✅ COMPLETE

**Goal**: Implement `fit_mediation()` for GLM engine

### 4.1 Generic Definition

```r
#' Fit Mediation Models
#'
#' @description
#' Fit mediation models using specified engine. Currently supports GLM.
#'
#' @param formula_y Formula for outcome model (Y ~ X + M + C)
#' @param formula_m Formula for mediator model (M ~ X + C)
#' @param data Data frame
#' @param treatment Character: treatment variable name
#' @param mediator Character: mediator variable name
#' @param engine Character: modeling engine ("glm", future: "lmer", "brms")
#' @param family_y Family for outcome model (default: gaussian())
#' @param family_m Family for mediator model (default: gaussian())
#' @param engine_args Named list of additional arguments for engine
#' @param ... Additional arguments
#'
#' @return MediationData object
#' @export
fit_mediation <- function(formula_y,
                          formula_m,
                          data,
                          treatment,
                          mediator,
                          engine = "glm",
                          family_y = stats::gaussian(),
                          family_m = stats::gaussian(),
                          engine_args = list(),
                          ...) {
  # Validate inputs
  # Dispatch to engine-specific function
  # Return MediationData
}
```

### 4.2 GLM Engine Implementation

```r
#' @keywords internal
.fit_mediation_glm <- function(formula_y, formula_m, data,
                               treatment, mediator,
                               family_y, family_m,
                               engine_args, ...) {
  # Fit mediator model
  fit_m <- stats::glm(formula_m, data = data, family = family_m)

  # Fit outcome model
  fit_y <- stats::glm(formula_y, data = data, family = family_y)

  # Extract mediation structure
  extract_mediation(fit_m, model_y = fit_y,
                   treatment = treatment, mediator = mediator,
                   data = data)
}
```

**Key features**:
- Uses `extract_mediation()` internally
- Validates formula structure
- Handles family specifications
- Error handling for convergence issues

### 4.3 Engine Dispatcher

```r
fit_mediation <- function(...) {
  engine <- match.arg(engine, c("glm"))  # Add more later

  switch(engine,
    glm = .fit_mediation_glm(...),
    stop("Engine '", engine, "' not implemented")
  )
}
```

**Deliverables**:
- `fit_mediation()` function
- GLM engine implementation
- Comprehensive tests
- Documentation with examples

**Time**: 2-3 days

---

## Phase 5: Bootstrap Infrastructure (Week 3-4) ✅ COMPLETE

**Goal**: Implement bootstrap methods

### 5.1 Bootstrap Function

```r
#' Bootstrap Mediation Statistics
#'
#' @description
#' Perform bootstrap inference for mediation statistics
#'
#' @param data Data frame
#' @param statistic_fn Function to compute statistic (receives data, returns scalar)
#' @param method Character: "parametric", "nonparametric", or "plugin"
#' @param mediation_data MediationData object (for parametric bootstrap)
#' @param n_boot Integer: number of bootstrap samples
#' @param ci_level Numeric: confidence level (default: 0.95)
#' @param parallel Logical: use parallel processing?
#' @param ncores Integer: number of cores (NULL = auto-detect)
#' @param seed Integer: random seed for reproducibility
#'
#' @return BootstrapResult object
#' @export
bootstrap_mediation <- function(data = NULL,
                                statistic_fn,
                                method = c("parametric", "nonparametric", "plugin"),
                                mediation_data = NULL,
                                n_boot = 1000,
                                ci_level = 0.95,
                                parallel = FALSE,
                                ncores = NULL,
                                seed = NULL) {
  method <- match.arg(method)

  # Set seed if provided
  if (!is.null(seed)) set.seed(seed)

  # Dispatch to appropriate method
  switch(method,
    parametric = .bootstrap_parametric(...),
    nonparametric = .bootstrap_nonparametric(...),
    plugin = .bootstrap_plugin(...)
  )
}
```

### 5.2 Parametric Bootstrap

**Source**: Adapt from probmed `R/compute-bootstrap.R`

```r
.bootstrap_parametric <- function(mediation_data, statistic_fn,
                                  n_boot, ci_level, parallel, ncores, ...) {
  # Extract parameters and vcov from mediation_data
  mu <- mediation_data@estimates
  Sigma <- mediation_data@vcov

  # Generate bootstrap samples
  if (!requireNamespace("MASS", quietly = TRUE)) {
    stop("MASS package required for parametric bootstrap")
  }

  boot_params <- MASS::mvrnorm(n = n_boot, mu = mu, Sigma = Sigma)

  # Compute statistic for each sample
  if (parallel) {
    # Parallel implementation
    boot_estimates <- parallel::mclapply(
      1:n_boot,
      function(i) statistic_fn(boot_params[i, ]),
      mc.cores = ncores %||% parallel::detectCores() - 1
    ) |> unlist()
  } else {
    # Sequential
    boot_estimates <- apply(boot_params, 1, statistic_fn)
  }

  # Compute CI
  alpha <- 1 - ci_level
  ci <- stats::quantile(boot_estimates, probs = c(alpha/2, 1 - alpha/2))

  # Return BootstrapResult
  BootstrapResult(
    estimate = mean(boot_estimates),
    ci_lower = ci[1],
    ci_upper = ci[2],
    ci_level = ci_level,
    boot_estimates = boot_estimates,
    n_boot = as.integer(n_boot),
    method = "parametric"
  )
}
```

### 5.3 Nonparametric Bootstrap

```r
.bootstrap_nonparametric <- function(data, statistic_fn,
                                     n_boot, ci_level, parallel, ncores, ...) {
  n <- nrow(data)

  # Bootstrap function
  boot_fn <- function(i) {
    # Resample data
    boot_data <- data[sample(n, replace = TRUE), ]

    # Compute statistic
    statistic_fn(boot_data)
  }

  # Generate bootstrap samples
  if (parallel) {
    boot_estimates <- parallel::mclapply(
      1:n_boot, boot_fn,
      mc.cores = ncores %||% parallel::detectCores() - 1
    ) |> unlist()
  } else {
    boot_estimates <- vapply(1:n_boot, boot_fn, numeric(1))
  }

  # Compute CI
  alpha <- 1 - ci_level
  ci <- stats::quantile(boot_estimates, probs = c(alpha/2, 1 - alpha/2))

  # Return
  BootstrapResult(
    estimate = mean(boot_estimates),
    ci_lower = ci[1],
    ci_upper = ci[2],
    ci_level = ci_level,
    boot_estimates = boot_estimates,
    n_boot = as.integer(n_boot),
    method = "nonparametric"
  )
}
```

### 5.4 Plugin Estimator

```r
.bootstrap_plugin <- function(mediation_data, statistic_fn, ...) {
  # Compute point estimate only
  estimate <- statistic_fn(mediation_data@estimates)

  BootstrapResult(
    estimate = estimate,
    ci_lower = NA_real_,
    ci_upper = NA_real_,
    ci_level = NA_real_,
    boot_estimates = numeric(0),
    n_boot = 0L,
    method = "plugin"
  )
}
```

**Deliverables**:
- `bootstrap_mediation()` function
- Parametric, nonparametric, and plugin methods
- Parallel processing support
- Tests for reproducibility and accuracy
- Documentation

**Time**: 3-4 days

---

## Phase 6: Testing & Documentation (Week 4) ✅ COMPLETE

**Goal**: Comprehensive testing and documentation

### 6.1 Test Suite

**Test files**:
```
tests/testthat/
├── test-classes.R          # S7 class validation (33 tests)
├── test-extract-lm.R       # lm/glm extraction (12 tests)
├── test-extract-lavaan.R   # lavaan extraction (10 tests)
├── test-fit-glm.R          # GLM fitting (9 tests)
├── test-bootstrap.R        # Bootstrap methods (14 tests)
└── helper-test-data.R      # Test data generators
```

**Test coverage targets**:
- Overall: >90%
- Core functions: 100%
- Classes: 100%
- Bootstrap: >95%

**Test scenarios**:
- [x] S7 class validation catches errors
- [x] Extraction from lm/glm matches manual
- [x] Extraction from lavaan consistent
- [x] GLM fitting produces valid MediationData
- [x] Parametric bootstrap reproducible with seed
- [x] Nonparametric bootstrap reproducible with seed
- [x] Plugin method fast and accurate
- [x] Edge cases handled (small n, non-convergence)

### 6.2 Documentation

**Function documentation**:
- [x] All exported functions have roxygen2 docs
- [x] Examples that run (not just \dontrun)
- [x] @param descriptions clear and complete
- [x] @return descriptions specify object types
- [x] @seealso cross-references where appropriate

**Vignettes** (all with working, executable code):
1. **Getting Started** (`vignettes/articles/getting-started.qmd`) ✅
   - Quick start with fit_mediation(), extract_mediation(), bootstrap_mediation()
   - S7 class creation examples

2. **Introduction to medfit** (`vignettes/articles/introduction.qmd`) ✅
   - S7 class architecture
   - Main functions overview
   - Package ecosystem context

3. **Model Extraction** (`vignettes/articles/extraction.qmd`) ✅
   - Extracting from lm/glm models
   - lavaan extraction examples
   - Error handling and validation

4. **Bootstrap Inference** (`vignettes/articles/bootstrap.qmd`) ✅
   - Three bootstrap methods with examples
   - Custom statistics
   - Parallelization and reproducibility

**README.md**:
- [x] Clear package description
- [x] Installation instructions (GitHub)
- [x] Quick start example
- [x] Links to documentation
- [x] Ecosystem diagram

**CLAUDE.md**:
- [x] Package architecture
- [x] Coding standards
- [x] Development workflow
- [x] Integration with sister packages

### 6.3 Package-Level Documentation

```r
#' medfit: Infrastructure for Mediation Model Fitting and Extraction
#'
#' @description
#' Provides S7-based infrastructure for fitting mediation models,
#' extracting path coefficients, and performing bootstrap inference.
#' Designed as a foundation package for probmed, RMediation, and medrobust.
#'
#' @details
#' Key functions:
#' \itemize{
#'   \item \code{\link{fit_mediation}}: Fit mediation models
#'   \item \code{\link{extract_mediation}}: Extract from fitted models
#'   \item \code{\link{bootstrap_mediation}}: Bootstrap inference
#' }
#'
#' Key classes:
#' \itemize{
#'   \item \code{\link{MediationData}}: Mediation model structure
#'   \item \code{\link{BootstrapResult}}: Bootstrap results
#' }
#'
#' @keywords internal
"_PACKAGE"
```

**Deliverables**:
- [x] >90% test coverage (78 tests across 5 files)
- [x] All functions documented
- [x] 4 comprehensive vignettes with working code
- [x] README and CLAUDE.md complete
- [x] pkgdown website ready

**Time**: 3-4 days (completed)

---

## Phase 7: Polish & Release (Week 5) 🚧 IN PROGRESS

**Goal**: Finalize for release and integration

### 7.1 R CMD check

- [ ] R CMD check passes on all platforms (verify after merge to main)
  - [x] macOS (latest R) - workflow configured
  - [x] Windows (latest R) - workflow configured
  - [x] Ubuntu (latest R and R-devel) - workflow configured
- [ ] 0 errors, 0 warnings, 0 notes (pending CI run)

### 7.2 CI/CD

- [x] GitHub Actions configured
  - [x] R-CMD-check on multi-platform (5 configurations)
  - [x] test-coverage reporting (Codecov)
  - [x] pkgdown site builds (with Quarto support)
- [x] Coverage badges in README
- [x] Build status badges

### 7.3 Documentation Website

- [x] pkgdown site configured for GitHub Pages
- [x] All vignettes with working code (4 Quarto vignettes)
- [x] Function reference complete
- [x] NEWS.md formatted properly
- [x] Search functionality configured

### 7.4 Prepare for CRAN (Optional)

**If submitting to CRAN**:
- [x] CRAN comments file prepared (cran-comments.md)
- [x] All examples use minimal data
- [x] No calls to external services in tests
- [x] Tests skip appropriately (lavaan skipped if not installed)
- [x] DESCRIPTION fields complete
- [x] cran-comments.md written

**Deliverables**:
- [x] Production-ready package structure
- [ ] Clean R CMD check (pending CI verification)
- [ ] Deployed documentation (pending merge to main)
- [x] Ready for integration with probmed

**Time**: 2-3 days

---

## Integration Plan (Week 6+)

**After medfit MVP is complete**:

### probmed Integration
1. Add medfit to DESCRIPTION (Imports)
2. Replace extraction code with medfit calls
3. Replace bootstrap code with medfit calls
4. Update tests (verify backward compatibility)
5. Update documentation
6. R CMD check passes

### RMediation Integration
1. Add medfit to DESCRIPTION (Imports)
2. Replace extraction code with medfit calls
3. Optionally use bootstrap infrastructure
4. Update tests
5. Update documentation

### medrobust Integration
1. Add medfit to DESCRIPTION (Suggests)
2. Optionally use for naive estimates
3. Update documentation

---

## Success Metrics

### MVP Success Criteria

medfit is ready for integration when:

- [ ] All core functions implemented and tested
- [ ] S7 classes defined and validated
- [ ] >90% test coverage
- [ ] R CMD check: 0 errors, 0 warnings, 0 notes
- [ ] Documentation complete (functions + vignettes)
- [ ] pkgdown site deployed
- [ ] probmed can use medfit without breaking changes

### Integration Success Criteria

Integration is successful when:

- [ ] probmed uses medfit backend
- [ ] All probmed tests pass
- [ ] probmed R CMD check clean
- [ ] No user-facing breaking changes
- [ ] Documentation updated

---

## Timeline Summary

| Phase | Duration | Start | End | Deliverable |
|-------|----------|-------|-----|-------------|
| 1. Setup | 2-3 days | Day 1 | Day 3 | Package skeleton |
| 2. S7 Classes | 2-3 days | Day 3 | Day 6 | Classes + methods |
| 3. Extraction | 3-4 days | Day 6 | Day 10 | extract_mediation() |
| 4. Fitting | 2-3 days | Day 10 | Day 13 | fit_mediation() |
| 5. Bootstrap | 3-4 days | Day 13 | Day 17 | bootstrap_mediation() |
| 6. Testing & Docs | 3-4 days | Day 17 | Day 21 | Complete documentation |
| 7. Polish | 2-3 days | Day 21 | Day 24 | Production ready |

**Total**: 17-24 days (3.5-5 weeks) for MVP

**Buffer**: +1 week for unforeseen issues

**Total with buffer**: 4-6 weeks

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| S7/S4 dispatch issues | Low | Medium | Use probmed pattern that works |
| Bootstrap implementation complex | Medium | Medium | Extract working code from probmed |
| Test coverage below 90% | Low | Low | Write tests as we go |
| R CMD check failures | Medium | High | Test frequently, fix early |
| API design not flexible enough | Medium | High | Review with collaborators before coding |

---

## Next Actions

### This Week

1. **Review this roadmap** - Discuss and approve
2. **Create GitHub repository** - Set up infrastructure
3. **Begin Phase 1** - Package skeleton

### Week 1

- [ ] Complete Phase 1 (setup)
- [ ] Complete Phase 2 (S7 classes)
- [ ] Begin Phase 3 (extraction)

### Week 2

- [ ] Complete Phase 3 (extraction)
- [ ] Complete Phase 4 (fitting)
- [ ] Begin Phase 5 (bootstrap)

### Weeks 3-4

- [ ] Complete Phase 5 (bootstrap)
- [ ] Complete Phase 6 (testing & docs)
- [ ] Complete Phase 7 (polish)

---

## Open Questions

1. **Should we include OpenMx extraction in MVP?**
   - Pro: RMediation uses it
   - Con: Adds complexity
   - **Decision**: Include if straightforward, defer if complex

2. **Should MVP include parallel bootstrap?**
   - Pro: Performance benefit
   - Con: Additional testing complexity
   - **Decision**: Include, it's straightforward

3. **CRAN submission timing?**
   - Option 1: Submit medfit to CRAN before integration
   - Option 2: Submit after probmed integration
   - **Decision**: After probmed integration (reduces risk)

---

**Status**: ✅ Phase 6 Complete → 🚧 Phase 7 (Polish & Release) Ready

**Completed**:
- ✅ Phase 1: Package Setup
- ✅ Phase 2: S7 Class Architecture (extended with SerialMediationData)
- ✅ Phase 2.5: Comprehensive Quarto Documentation (4 vignettes, pkgdown website)
- ✅ Phase 3: Model Extraction (lm/glm and lavaan methods implemented)
- ✅ Phase 4: Model Fitting (GLM engine with fit_mediation())
- ✅ Phase 5: Bootstrap Infrastructure (parametric, nonparametric, plugin methods)
- ✅ Phase 6: Extended Testing & Documentation (78 tests, 4 vignettes with working code)

**Current**:
- 🚧 Phase 7: Polish & Release

**Next**:
- R CMD check verification
- CI/CD final testing
- probmed integration

**Implementation Summary**:
- `extract_mediation()` methods for lm, glm, lavaan objects
- `fit_mediation()` with formula interface and GLM engine
- `bootstrap_mediation()` with parametric, nonparametric, and plugin methods
- Parallel processing support for bootstrap (Unix)
- Comprehensive test suite (78 tests across 5 test files)
- 4 Quarto vignettes with working, executable code examples

**Last Updated**: 2025-12-16
