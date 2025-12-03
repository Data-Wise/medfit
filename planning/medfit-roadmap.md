# medfit Package Development Roadmap

**Package**: medfit - Mediation model fitting and extraction infrastructure
**Status**: Phase 2 Complete + Documentation → Phase 3 (Model Extraction)
**Timeline**: 4-6 weeks for MVP (Started December 2024)
**Last Updated**: December 2, 2025

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
- lme4 (future - mixed models)
- testthat (>= 3.0.0)
- knitr
- rmarkdown

**Future Consideration**:
- OpenMx (>= 2.13) - SEM extraction (postponed for future release)

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
├── bootstrap.R            # Bootstrap infrastructure
├── utils.R                # Utility functions
└── zzz.R                  # .onLoad() for dynamic dispatch
```

**Note**: OpenMx extraction (`extract-openmx.R`) postponed for future release.

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

## Phase 3: Model Extraction API (Week 2) 🚧 IN PROGRESS

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

### 3.4 Method: OpenMx (POSTPONED)

**Status**: Postponed for future release

OpenMx integration has been deferred to a future version. Reasons:
- Complexity of OpenMx model structure
- Focus MVP on lm/glm and lavaan extraction
- OpenMx can be added in a future release when needed

**Future Implementation** (when added):
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

**Deliverables** (MVP scope revised):
- `extract_mediation()` generic
- Methods for lm/glm (required)
- Method for lavaan (required)
- ~~Method for OpenMx~~ (postponed to future release)
- Comprehensive tests
- Examples in documentation

**Time**: 3-4 days

---

## Phase 4: Model Fitting API (Week 2-3)

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

## Phase 5: Bootstrap Infrastructure (Week 3-4)

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

## Phase 6: Testing & Documentation (Week 4)

**Goal**: Comprehensive testing and documentation

### 6.1 Test Suite

**Test files**:
```
tests/testthat/
├── test-classes.R          # S7 class validation
├── test-extract-lm.R       # lm/glm extraction
├── test-extract-lavaan.R   # lavaan extraction
├── test-fit-glm.R          # GLM fitting
├── test-bootstrap.R        # Bootstrap methods
├── test-utils.R            # Utility functions
└── helper-test-data.R      # Test data generators
```

**Test coverage targets**:
- Overall: >90%
- Core functions: 100%
- Classes: 100%
- Bootstrap: >95%

**Test scenarios**:
- [ ] S7 class validation catches errors
- [ ] Extraction from lm/glm matches manual
- [ ] Extraction from lavaan consistent
- [ ] GLM fitting produces valid MediationData
- [ ] Parametric bootstrap reproducible with seed
- [ ] Nonparametric bootstrap reproducible with seed
- [ ] Plugin method fast and accurate
- [ ] Edge cases handled (small n, non-convergence)

### 6.2 Documentation

**Function documentation**:
- [ ] All exported functions have roxygen2 docs
- [ ] Examples that run (not just \dontrun)
- [ ] @param descriptions clear and complete
- [ ] @return descriptions specify object types
- [ ] @seealso cross-references where appropriate

**Vignettes**:
1. **Introduction to medfit** (`vignettes/introduction.qmd`)
   - What is medfit?
   - When to use it?
   - Quick start examples
   - How it fits in the ecosystem

2. **Model Extraction** (`vignettes/extraction.qmd`)
   - Extracting from different model types
   - Understanding MediationData objects
   - Troubleshooting common issues

3. **Bootstrap Inference** (`vignettes/bootstrap.qmd`)
   - Three bootstrap methods
   - When to use each
   - Parallelization
   - Reproducibility

**README.md**:
- [ ] Clear package description
- [ ] Installation instructions (GitHub)
- [ ] Quick start example
- [ ] Links to documentation
- [ ] Ecosystem diagram

**CLAUDE.md**:
- [ ] Package architecture
- [ ] Coding standards
- [ ] Development workflow
- [ ] Integration with sister packages

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
- >90% test coverage
- All functions documented
- 3 comprehensive vignettes
- README and CLAUDE.md complete
- pkgdown website ready

**Time**: 3-4 days

---

## Phase 7: Interaction Support - VanderWeele Four-Way Decomposition (Future)

**Goal**: Support treatment-mediator interactions using VanderWeele's potential outcomes framework

**Status**: Planned for future release (after MVP)

### 7.1 Theoretical Foundation

Based on [VanderWeele (2014)](https://pubmed.ncbi.nlm.nih.gov/25000145/) "A unification of mediation and interaction: a 4-way decomposition" (*Epidemiology*, 25(5):749-61).

**Key Insight**: When treatment and mediator interact, the total effect decomposes into four components:

| Component | Interpretation | Due to |
|-----------|----------------|--------|
| **CDE** (Controlled Direct Effect) | Effect of X when M held constant | Neither mediation nor interaction |
| **INTref** (Reference Interaction) | Interaction at reference mediator level | Interaction only |
| **INTmed** (Mediated Interaction) | Interaction operating through mediator change | Both mediation and interaction |
| **PIE** (Pure Indirect Effect) | Mediated effect without interaction | Mediation only |

**Decomposition**: Total Effect = CDE + INTref + INTmed + PIE

**Relationships to traditional effects**:
- Natural Direct Effect (NDE) = CDE + INTref
- Natural Indirect Effect (NIE) = INTmed + PIE

### 7.2 Regression Model Specifications

**Mediator Model** (same as simple mediation):
```
M = β₀ + β₁X + β₂'C + εₘ
```

**Outcome Model with Interaction**:
```
Y = θ₀ + θ₁X + θ₂M + θ₃(X×M) + θ₄'C + εᵧ
```

Where:
- `θ₁` = main effect of treatment on outcome
- `θ₂` = main effect of mediator on outcome
- `θ₃` = treatment × mediator interaction coefficient
- `β₁` = effect of treatment on mediator (a path)

### 7.3 Four-Way Decomposition Formulas (Continuous Y and M)

For binary exposure (X: 0 → 1) and reference mediator level m*:

| Effect | Formula |
|--------|---------|
| **CDE(m*)** | θ₁ + θ₃m* |
| **INTref** | θ₃(β₀ + β₂'c - m*) |
| **INTmed** | θ₃β₁ |
| **PIE** | θ₂β₁ |

**Special case (m* = 0)**:
- CDE = θ₁
- INTref = θ₃(β₀ + β₂'c)
- INTmed = θ₃β₁
- PIE = θ₂β₁

**Note**: When θ₃ = 0 (no interaction):
- CDE = NDE = θ₁
- INTref = INTmed = 0
- NIE = PIE = θ₂β₁ (standard indirect effect)

### 7.4 InteractionMediationData Class Design

```r
#' @title InteractionMediationData
#' @description S7 class for mediation with treatment-mediator interaction
InteractionMediationData <- S7::new_class(
 "InteractionMediationData",
 package = "medfit",
 properties = list(
   # Path coefficients (extended)
   a_path = S7::class_numeric,           # β₁: X → M
   b_path = S7::class_numeric,           # θ₂: M → Y (main effect)
   c_prime = S7::class_numeric,          # θ₁: X → Y (main effect)
   interaction = S7::class_numeric,      # θ₃: X×M interaction

   # Four-way decomposition components
   cde = S7::class_numeric,              # Controlled Direct Effect
   int_ref = S7::class_numeric,          # Reference Interaction
   int_med = S7::class_numeric,          # Mediated Interaction
   pie = S7::class_numeric,              # Pure Indirect Effect

   # Derived effects
   nde = S7::class_numeric,              # Natural Direct Effect
   nie = S7::class_numeric,              # Natural Indirect Effect
   total_effect = S7::class_numeric,     # Total Effect

   # Reference values for decomposition
   m_star = S7::class_numeric,           # Reference mediator value

   # Standard MediationData properties
   estimates = S7::class_numeric,
   vcov = S7::class_matrix,
   sigma_m = S7::class_numeric | NULL,
   sigma_y = S7::class_numeric | NULL,
   treatment = S7::class_character,
   mediator = S7::class_character,
   outcome = S7::class_character,
   mediator_predictors = S7::class_character,
   outcome_predictors = S7::class_character,
   data = S7::class_data.frame | NULL,
   n_obs = S7::class_integer,
   converged = S7::class_logical,
   source_package = S7::class_character
 ),

 validator = function(self) {
   # Validate interaction is scalar
   if (length(self@interaction) != 1) "interaction must be scalar"
   # Validate four-way components sum to total
   else if (abs((self@cde + self@int_ref + self@int_med + self@pie) -
                self@total_effect) > 1e-10) {
     "Four-way components must sum to total effect"
   }
   # Validate NDE = CDE + INTref
   else if (abs((self@cde + self@int_ref) - self@nde) > 1e-10) {
     "NDE must equal CDE + INTref"
   }
   # Validate NIE = INTmed + PIE
   else if (abs((self@int_med + self@pie) - self@nie) > 1e-10) {
     "NIE must equal INTmed + PIE"
   }
 }
)
```

### 7.5 Formula Interface Extension

```r
# Extended fit_mediation() for interactions
fit_mediation(
 formula_y = Y ~ X + M + X:M + C,    # Includes X:M interaction
 formula_m = M ~ X + C,
 data = data,
 treatment = "X",
 mediator = "M",
 m_star = 0,                          # Reference mediator value
 decomposition = "four_way",          # "two_way" | "four_way"
 engine = "glm"
)
```

### 7.6 Extraction from Models with Interaction

The `extract_mediation()` function will detect interaction terms:

```r
# Automatic detection of X:M interaction in outcome model
fit_m <- lm(M ~ X + C, data = data)
fit_y <- lm(Y ~ X + M + X:M + C, data = data)

# Returns InteractionMediationData when interaction detected
med_int <- extract_mediation(
 fit_m,
 model_y = fit_y,
 treatment = "X",
 mediator = "M",
 m_star = 0                           # Reference for decomposition
)

# Access four-way components
med_int@cde       # Controlled Direct Effect
med_int@int_ref   # Reference Interaction
med_int@int_med   # Mediated Interaction
med_int@pie       # Pure Indirect Effect
```

### 7.7 Standard Error Computation

Use delta method for variance of decomposition components:

```r
# Variance formulas (simplified for continuous Y, M)
# Var(PIE) = β₁²Var(θ₂) + θ₂²Var(β₁) + 2β₁θ₂Cov(θ₂,β₁)
# Var(INTmed) = β₁²Var(θ₃) + θ₃²Var(β₁) + 2β₁θ₃Cov(θ₃,β₁)
# etc.
```

Alternative: Bootstrap inference (already implemented).

### 7.8 Identification Assumptions

Per VanderWeele (2014), causal interpretation requires:
1. No unmeasured exposure-outcome confounding given C
2. No unmeasured mediator-outcome confounding given C
3. No unmeasured exposure-mediator confounding given C
4. No mediator-outcome confounder affected by exposure

**Note**: medfit computes the decomposition; causal interpretation is user's responsibility.

### 7.9 Implementation Priority

| Priority | Feature | Complexity |
|----------|---------|------------|
| High | InteractionMediationData class | Medium |
| High | Detection of X:M interaction in extraction | Low |
| High | Four-way decomposition formulas (continuous) | Medium |
| Medium | Delta method SEs for decomposition | High |
| Medium | Binary outcome formulas | High |
| Low | Binary mediator formulas | High |
| Low | Survival outcome formulas | High |

### 7.10 Key References

- **VanderWeele TJ (2014)**. A unification of mediation and interaction: a 4-way decomposition. *Epidemiology*, 25(5):749-61. [PubMed](https://pubmed.ncbi.nlm.nih.gov/25000145/)
- **Valeri L, VanderWeele TJ (2013)**. Mediation analysis allowing for exposure–mediator interactions and causal interpretation. *Psychological Methods*, 18(2):137-150.
- **VanderWeele TJ (2015)**. *Explanation in Causal Inference: Methods for Mediation and Interaction*. Oxford University Press.
- **Discacciati A et al. (2019)**. Med4way: A Stata command to investigate mediating and interactive mechanisms. *Int J Epidemiol*, 48(1):15-20.

### 7.11 Deliverables

- [ ] InteractionMediationData S7 class
- [ ] Interaction detection in extract_mediation()
- [ ] Four-way decomposition computation
- [ ] Delta method or bootstrap SEs
- [ ] Documentation with examples
- [ ] Tests comparing to med4way/regmedint

**Time**: 1-2 weeks (after MVP)

---

## Phase 7b: Estimation Engine Architecture (Future)

**Goal**: Unified estimation infrastructure supporting multiple causal mediation methods

**Status**: Design phase - brainstorming complete

### 7b.1 User Interface Design

**Design Decision**: Hybrid approach combining simple strings for common cases with helper functions for advanced control.

#### Simple Interface (80% of users)

```r
estimate_mediation(
  formula_y = Y ~ X + M + C,
  formula_m = M ~ X + C,
  data = df,
  treatment = "X",
  mediator = "M",
  effects = "natural",     # DEFAULT: NDE + NIE
  engine = "regression"
)
```

#### Effect Specification Options

| `effects =` | Returns | Use Case |
|-------------|---------|----------|
| `"natural"` (default) | NDE, NIE | Standard mediation |
| `"interventional"` | IDE, IIE | Exposure-induced confounding |
| `"controlled"` | CDE | Policy questions |

#### Advanced Interface (helper functions)

```r
estimate_mediation(
  ...,
  effects = natural_effects(variant = "total"),     # TDE + TNIE
  effects = controlled_effects(m = 5),              # CDE at m=5
  effects = interventional_effects()                # IDE + IIE
)
```

#### Interaction Handling

When `X:M` interaction detected in formula → automatically compute BOTH decompositions:

```r
# formula_y = Y ~ X + M + X:M + C triggers both:
result@decompositions$two_way   # NDE, NIE
result@decompositions$four_way  # CDE, INTref, INTmed, PIE
```

### 7b.2 Decomposition S7 Class

**Design Decision**: Decomposition as separate S7 class for flexibility and future extensibility.

```r
#' @title Decomposition
#' @description S7 class for effect decomposition results
Decomposition <- S7::new_class(
  "Decomposition",
  package = "medfit",
  properties = list(
    type = S7::class_character,        # "two_way", "four_way", "custom"
    components = S7::class_list,       # Named list of effects
    total = S7::class_numeric,         # Total effect
    formula = S7::class_character      # Human-readable decomposition
  ),
  validator = function(self) {
    comp_sum <- sum(unlist(self@components))
    if (abs(comp_sum - self@total) > 1e-10) {
      "Components must sum to total effect"
    }
  }
)
```

#### Built-in Decomposition Constructors

```r
# Two-way (natural effects)
two_way <- function(nde, nie) {
  Decomposition(
    type = "two_way",
    components = list(nde = nde, nie = nie),
    total = nde + nie,
    formula = "NDE + NIE"
  )
}

# Four-way (VanderWeele)
four_way <- function(cde, int_ref, int_med, pie) {
  Decomposition(
    type = "four_way",
    components = list(cde = cde, int_ref = int_ref,
                      int_med = int_med, pie = pie),
    total = cde + int_ref + int_med + pie,
    formula = "CDE + INTref + INTmed + PIE"
  )
}

# Custom (future extensibility)
custom_decomposition <- function(..., formula = NULL) {
  comps <- list(...)
  Decomposition(
    type = "custom",
    components = comps,
    total = sum(unlist(comps)),
    formula = formula %||% paste(names(comps), collapse = " + ")
  )
}
```

### 7b.3 MediationData with Decompositions

**Design Decision**: MediationData stores multiple decompositions in a list.

```r
MediationData <- S7::new_class(
  "MediationData",
  properties = list(
    # Path coefficients (raw)
    a_path = S7::class_numeric,
    b_path = S7::class_numeric,
    c_prime = S7::class_numeric,
    interaction = S7::class_numeric | NULL,

    # Decomposition results (flexible)
    decompositions = S7::class_list,  # list(two_way = Decomposition, ...)

    # Standard properties
    estimates = S7::class_numeric,
    vcov = S7::class_matrix,
    # ... other properties
  )
)
```

### 7b.4 User-Friendly Access

```r
result <- estimate_mediation(...)

# Helper functions (recommended)
get_effect(result, "nde")                    # → 0.3
get_effect(result, "four_way")               # → list(cde, int_ref, int_med, pie)
get_decomposition(result, "two_way")         # → Decomposition object

# Print method
print(result)
# Mediation Analysis Results
# ==========================
# Two-way decomposition:
#   NDE: 0.30 (95% CI: 0.20, 0.40)
#   NIE: 0.20 (95% CI: 0.12, 0.28)
#   Total: 0.50
#
# Four-way decomposition:
#   CDE:     0.20   INTref: 0.10
#   INTmed:  0.08   PIE:    0.12
#   Total: 0.50
```

### 7b.5 Estimation Engine Layer (Future)

**Planned engines** based on causal mediation literature:

| Engine | Method | Key Reference |
|--------|--------|---------------|
| `"regression"` | VanderWeele closed-form (MVP) | Valeri & VanderWeele (2013) |
| `"simulation"` | Monte Carlo / quasi-Bayesian | Imai et al. (2010) |
| `"gformula"` | G-computation | Robins (1986) |
| `"ipw"` | Inverse probability weighting | VanderWeele (2009) |
| `"tmle"` | Targeted learning | Zheng & van der Laan (2012) |
| `"dml"` | Double machine learning | Chernozhukov et al. (2018) |

```r
# Engine specification
estimate_mediation(
  ...,
  engine = "regression",          # Default (MVP)
  engine_args = list(...)         # Engine-specific options
)
```

### 7b.6 Inference Options

**Design Decision**: Single `inference` argument with bootstrap as default.

```r
estimate_mediation(
  ...,
  # Inference method
  inference = "bootstrap",        # Default
  # inference = "delta",          # Delta method (analytical)
  # inference = "none",           # Point estimates only

  # Bootstrap options (when inference = "bootstrap")
  n_boot = 1000,
  ci_level = 0.95,
  ci_type = "percentile",         # or "bca", "normal"
  parallel = FALSE,
  seed = NULL
)
```

| `inference =` | Description | Use Case |
|---------------|-------------|----------|
| `"bootstrap"` (default) | Nonparametric bootstrap | General use, robust |
| `"delta"` | Delta method (analytical SEs) | Fast, large samples |
| `"none"` | Point estimates only | Quick exploration |

### 7b.7 Output and Reporting

**Summary tables:**
```r
summary(result)
#                  Estimate    SE   95% CI         p
# Total Effect        0.50  0.08  [0.34, 0.66]  <.001
# Natural Direct      0.30  0.06  [0.18, 0.42]  <.001
# Natural Indirect    0.20  0.04  [0.12, 0.28]  <.001
# Prop. Mediated      0.40  0.10  [0.21, 0.59]  <.001

# Tidy export
as.data.frame(result)            # Data frame
```
**Plotting** (ggplot2 in Suggests with base R fallback):
```r
plot(result)                     # Default: effect comparison
plot(result, type = "decomposition")  # Stacked bar (4-way)
plot(result, type = "bootstrap")      # Bootstrap distribution
```

### 7b.8 Variable Types

**MVP scope**: Continuous and binary variables only.

| Variable | Type | Model |
|----------|------|-------|
| Outcome (Y) | Continuous | `gaussian()` |
| Outcome (Y) | Binary | `binomial()` |
| Mediator (M) | Continuous | `gaussian()` |
| Mediator (M) | Binary | `binomial()` |

**Future**: Count (Poisson), survival (Cox, AFT).

### 7b.9 Design Principles

1. **Sensible defaults**: `effects = "natural"`, `engine = "regression"`, `inference = "bootstrap"`
2. **Progressive disclosure**: Simple for beginners, powerful for experts
3. **Future-proof**: Decomposition class allows custom decompositions
4. **Consistent output**: All engines return same MediationData structure
5. **Multiple decompositions**: One result can hold two-way AND four-way
6. **ggplot2 optional**: Suggests dependency with base R fallback

### 7b.10 Key References (Estimation Methods)

- **Imai K et al. (2010)**. A general approach to causal mediation analysis. *Psych Methods*.
- **Valeri L, VanderWeele TJ (2013)**. Mediation analysis allowing for exposure-mediator interactions. *Psych Methods*.
- **VanderWeele TJ (2015)**. *Explanation in Causal Inference*. Oxford University Press.
- **Zheng W, van der Laan MJ (2012)**. Targeted maximum likelihood estimation of natural direct effects. *Int J Biostat*.

---

## Phase 7c: Engine Adapter Architecture (Future)

**Goal**: Standardize integration with external packages for advanced estimation methods

**Status**: Design phase - architecture documented

### 7c.1 Motivation

Rather than reimplementing complex estimation methods (g-formula, IPW, TMLE), medfit will wrap existing validated packages through a standardized adapter pattern. This provides:

- **Reliability**: Leverage battle-tested implementations
- **Reduced maintenance**: No need to maintain complex statistical code
- **Flexibility**: Users can choose their preferred backend
- **Consistency**: All engines return the same MediationData structure

### 7c.2 Adapter Pattern Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      User Interface                          │
│  estimate_mediation(..., engine = "gformula", ...)          │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                    Engine Dispatcher                         │
│  .dispatch_engine(engine, formula_y, formula_m, data, ...)  │
└─────────────────────────┬───────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ Internal │    │ CMAverse │    │  tmle3   │
    │ Engines  │    │ Adapter  │    │ Adapter  │
    └────┬─────┘    └────┬─────┘    └────┬─────┘
         │               │               │
         ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────┐
│                 Standardized MediationData                   │
│   (Same output structure regardless of estimation method)    │
└─────────────────────────────────────────────────────────────┘
```

### 7c.3 Adapter Interface Contract

Each external engine adapter must implement:

```r
#' Engine Adapter Interface (Internal)
#'
#' All adapters must accept these standard arguments and return MediationData.
#'
#' @param formula_y Formula for outcome model
#' @param formula_m Formula for mediator model (or list for multiple)
#' @param data Data frame
#' @param treatment Character: treatment variable name
#' @param mediator Character: mediator variable name (or vector)
#' @param outcome Character: outcome variable name
#' @param effects Character: estimand type ("natural", "controlled", etc.)
#' @param engine_args List: engine-specific options passed through
#' @param ... Additional arguments
#'
#' @return MediationData object with standardized structure
.adapter_template <- function(formula_y, formula_m, data,
                              treatment, mediator, outcome,
                              effects, engine_args, ...) {
  # 1. Validate engine-specific requirements
  # 2. Transform medfit inputs → external package format
  # 3. Call external package function
  # 4. Transform results → MediationData
  # 5. Return standardized output
}
```

### 7c.4 CMAverse Adapter (First Priority)

**Package**: [CMAverse](https://bs1125.github.io/CMAverse/) (Shi et al., 2021)

**Why CMAverse first**:
- Comprehensive: g-formula, IPW, TMLE, MSM, and more
- Well-documented with active maintenance
- Supports binary/continuous treatments, mediators, outcomes
- Handles interactions and multiple mediators

**Dependency strategy**: Add to Suggests (load on demand)

```r
# In DESCRIPTION
Suggests:
    CMAverse (>= 0.1.0)
```

**Adapter implementation**:

```r
#' CMAverse Adapter
#'
#' @keywords internal
.adapter_cmaverse <- function(formula_y, formula_m, data,
                               treatment, mediator, outcome,
                               effects, engine_args, ...) {
  # Check dependency

if (!requireNamespace("CMAverse", quietly = TRUE)) {
    stop("CMAverse package required for engine = 'gformula'/'ipw'/'tmle'.\n",
         "Install with: install.packages('CMAverse')",
         call. = FALSE)
  }

  # Map medfit effects to CMAverse
  cmaverse_effect <- switch(effects,
    "natural" = "NDE_NIE",
    "controlled" = "CDE",
    "interventional" = "interventional",
    stop("Effect type '", effects, "' not supported by CMAverse adapter")
  )

  # Build CMAverse arguments
  cma_args <- list(
    data = data,
    exposure = treatment,
    mediator = mediator,
    outcome = outcome,
    EMint = engine_args$interaction %||% FALSE,
    model = engine_args$model %||% "rb",     # regression-based
    inference = engine_args$inference %||% "bootstrap"
  )

  # Merge user-provided engine_args (engine-specific options)
  cma_args <- utils::modifyList(cma_args, engine_args)

  # Call CMAverse
  cma_result <- do.call(CMAverse::cmest, cma_args)

  # Transform to MediationData
  .cmaverse_to_mediation_data(cma_result, effects = effects)
}

#' Transform CMAverse result to MediationData
#' @keywords internal
.cmaverse_to_mediation_data <- function(cma_result, effects) {
  # Extract estimates based on effect type
  estimates <- switch(effects,
    "natural" = c(
      nde = cma_result$effect.pe["pnde"],
      nie = cma_result$effect.pe["tnie"]
    ),
    "controlled" = c(
      cde = cma_result$effect.pe["cde"]
    )
  )

  # Build MediationData
  MediationData(
    a_path = cma_result$reg.output$mreg$coefficients[treatment],
    b_path = cma_result$reg.output$yreg$coefficients[mediator],
    c_prime = cma_result$reg.output$yreg$coefficients[treatment],
    estimates = as.numeric(estimates),
    vcov = .extract_cmaverse_vcov(cma_result),
    # ... additional properties
    source_package = "CMAverse"
  )
}
```

**Supported CMAverse methods via `engine_args`**:

| `engine_args$model` | CMAverse Method | Description |
|---------------------|-----------------|-------------|
| `"rb"` | Regression-based | Default, VanderWeele formulas |
| `"wb"` | Weighting-based | IPW approach |
| `"iorw"` | IORW | Inverse odds ratio weighting |
| `"msm"` | MSM | Marginal structural models |
| `"gformula"` | G-formula | Parametric g-computation |
| `"ne"` | Natural effect | Natural effect models |

### 7c.5 Engine-Specific Options via engine_args

**Design decision**: Use `engine_args = list(...)` for engine-specific options (Option A).

**Rationale**:
- Clean separation: standard arguments vs engine-specific
- Self-documenting: users see what's engine-specific
- Flexible: each adapter defines its own options
- No namespace pollution in main function signature

**Usage examples**:

```r
# CMAverse with g-formula and bootstrap
estimate_mediation(
  formula_y = Y ~ X + M + C,
  formula_m = M ~ X + C,
  data = df,
  treatment = "X",
  mediator = "M",
  effects = "natural",
  engine = "gformula",
  engine_args = list(
    model = "gformula",           # CMAverse-specific
    EMint = TRUE,                 # Exposure-mediator interaction
    mreg = list(family = "binomial"),  # Binary mediator
    yreg = list(family = "gaussian"),  # Continuous outcome
    astar = 0,                    # Reference exposure level
    a = 1,                        # Active exposure level
    nboot = 500                   # CMAverse bootstrap samples
  )
)

# tmle3 adapter (future)
estimate_mediation(
  ...,
  engine = "tmle",
  engine_args = list(
    learner_list = list(          # tmle3-specific
      A = sl3::Lrnr_glm$new(),
      M = sl3::Lrnr_ranger$new()
    ),
    max_iter = 100
  )
)
```

### 7c.6 Engine Registration System

```r
# Internal registry of available engines
.engine_registry <- new.env(parent = emptyenv())

#' Register an estimation engine
#' @keywords internal
.register_engine <- function(name, adapter_fn, package = NULL, methods = NULL) {
  .engine_registry[[name]] <- list(
    adapter = adapter_fn,
    package = package,
    methods = methods,
    available = is.null(package) || requireNamespace(package, quietly = TRUE)
  )
}

#' Initialize built-in engines
#' @keywords internal
.init_engines <- function() {
  # Internal engines (always available)
  .register_engine("regression", .adapter_regression, package = NULL,
                   methods = c("natural", "controlled"))

  # External engine adapters (available if package installed)
  .register_engine("gformula", .adapter_cmaverse, package = "CMAverse",
                   methods = c("natural", "controlled", "interventional"))
  .register_engine("ipw", .adapter_cmaverse, package = "CMAverse",
                   methods = c("natural"))

  # Future adapters
  # .register_engine("tmle", .adapter_tmle3, package = "tmle3", ...)
  # .register_engine("dml", .adapter_doubleml, package = "DoubleML", ...)
}

#' Dispatch to appropriate engine
#' @keywords internal
.dispatch_engine <- function(engine, ...) {
  if (!exists(engine, envir = .engine_registry)) {
    stop("Unknown engine: '", engine, "'. ",
         "Available: ", paste(ls(.engine_registry), collapse = ", "))
  }

  reg <- .engine_registry[[engine]]

  if (!reg$available) {
    stop("Engine '", engine, "' requires package '", reg$package, "'.\n",
         "Install with: install.packages('", reg$package, "')")
  }

  reg$adapter(...)
}
```

### 7c.7 Future Engine Adapters

| Priority | Engine | Package | Methods | Complexity |
|----------|--------|---------|---------|------------|
| **High** | gformula | CMAverse | G-computation | Medium |
| **High** | ipw | CMAverse | Weighting | Medium |
| Medium | tmle | tmle3/AIPW | Targeted ML | High |
| Medium | dml | DoubleML | Double ML | High |
| Low | bart | bartCause | Bayesian trees | High |
| Low | msm | CMAverse | Marginal structural | Medium |

### 7c.8 Error Handling and Validation

```r
#' Validate engine compatibility
#' @keywords internal
.validate_engine_request <- function(engine, effects, formula_y, ...) {
  reg <- .engine_registry[[engine]]

  # Check effect type supported
  if (!effects %in% reg$methods)

    stop("Engine '", engine, "' does not support effects = '", effects, "'.\n",
         "Supported: ", paste(reg$methods, collapse = ", "))
  }

  # Check for interaction if required
  has_interaction <- .formula_has_interaction(formula_y)
  if (effects == "four_way" && !has_interaction) {
    stop("Four-way decomposition requires X:M interaction in formula_y")
  }

  # Engine-specific validation
  if (engine == "gformula" && has_interaction) {
    message("Note: G-formula with interaction uses simulation-based estimation")
  }
}
```

### 7c.9 Testing Strategy for Adapters

```r
# tests/testthat/test-adapter-cmaverse.R

test_that("CMAverse adapter returns valid MediationData", {
  skip_if_not_installed("CMAverse")

  result <- estimate_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = test_data,
    treatment = "X",
    mediator = "M",
    engine = "gformula"
  )

  expect_s7_class(result, MediationData)
  expect_equal(result@source_package, "CMAverse")
})

test_that("CMAverse adapter matches direct CMAverse output", {
  skip_if_not_installed("CMAverse")

  # Direct CMAverse call
  cma_direct <- CMAverse::cmest(...)

  # Via adapter
  result <- estimate_mediation(..., engine = "gformula")

  # Compare estimates
  expect_equal(result@nde, cma_direct$effect.pe["pnde"], tolerance = 1e-6)
})
```

### 7c.10 Documentation for Users

```r
#' Estimation Engines
#'
#' @description
#' medfit supports multiple estimation engines for causal mediation analysis.
#'
#' @section Built-in Engines:
#' \describe{
#'   \item{regression}{VanderWeele closed-form formulas. Fast, parametric.
#'     Default engine, always available.}
#' }
#'
#' @section External Engines (require additional packages):
#' \describe{
#'   \item{gformula}{G-computation via CMAverse. Handles complex confounding.}
#'   \item{ipw}{Inverse probability weighting via CMAverse.}
#'   \item{tmle}{Targeted learning via tmle3 (future).}
#' }
#'
#' @section Engine-Specific Options:
#' Pass engine-specific options via \code{engine_args}:
#' \preformatted{
#' estimate_mediation(
#'   ...,
#'   engine = "gformula",
#'   engine_args = list(
#'     model = "gformula",
#'     EMint = TRUE,
#'     nboot = 500
#'   )
#' )
#' }
#'
#' @name engines
#' @seealso \code{\link{estimate_mediation}}
NULL
```

### 7c.11 Key References

- **Shi B et al. (2021)**. CMAverse: A suite of functions for reproducible causal mediation analyses. *Epidemiology*, 32(5):e20-e22.
- **van der Laan MJ, Rose S (2011)**. *Targeted Learning*. Springer.
- **Chernozhukov V et al. (2018)**. Double/debiased machine learning. *Econometrics J*, 21(1):C1-C68.
- **Hill JL (2011)**. Bayesian nonparametric modeling for causal inference. *J Comp Graph Stat*, 20(1):217-240.

### 7c.12 Deliverables

- [ ] Engine registry system
- [ ] Adapter interface specification
- [ ] CMAverse adapter implementation
- [ ] Engine-specific option documentation
- [ ] Validation and error handling
- [ ] Tests for adapter correctness
- [ ] User documentation

**Time**: 1-2 weeks (after MVP + Phase 7b)

---

## Phase 8: Polish & Release (Week 5)

**Goal**: Finalize for release and integration

### 8.1 R CMD check

- [ ] R CMD check passes on all platforms
  - [ ] macOS (latest R)
  - [ ] Windows (latest R)
  - [ ] Ubuntu (latest R and R-devel)
- [ ] 0 errors, 0 warnings, 0 notes

### 8.2 CI/CD

- [ ] GitHub Actions passing
  - [ ] R-CMD-check on multi-platform
  - [ ] test-coverage reporting
  - [ ] pkgdown site builds
- [ ] Coverage badges in README
- [ ] Build status badges

### 8.3 Documentation Website

- [ ] pkgdown site deployed to GitHub Pages
- [ ] All vignettes render correctly
- [ ] Function reference complete
- [ ] NEWS.md formatted properly
- [ ] Search functionality works

### 8.4 Prepare for CRAN (Optional)

**If submitting to CRAN**:
- [ ] CRAN comments file prepared
- [ ] All examples run < 5 seconds
- [ ] No calls to external services in tests
- [ ] Appropriate use of `\donttest{}`
- [ ] DESCRIPTION fields complete
- [ ] cran-comments.md written

**Deliverables**:
- Production-ready package
- Clean R CMD check
- Deployed documentation
- Ready for integration with probmed

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
| 7. **Interaction Support** | 1-2 weeks | Post-MVP | - | VanderWeele 4-way decomposition |
| 7b. **Estimation Engine** | 1 week | Post-MVP | - | User interface, Decomposition class |
| 7c. **Engine Adapters** | 1-2 weeks | Post-MVP | - | CMAverse integration |
| 8. Polish | 2-3 days | Day 21 | Day 24 | Production ready |

**MVP Total**: 17-24 days (3.5-5 weeks) - Phases 1-6 + 8

**Post-MVP**: Phase 7 (Interaction support) - 1-2 weeks

**Buffer**: +1 week for unforeseen issues

**Total with buffer**: 4-6 weeks (MVP), +2 weeks (with interactions)

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
   - **Decision**: ~~Include if straightforward, defer if complex~~ **RESOLVED: Postponed to future release**. Focus MVP on lm/glm and lavaan.

2. **Should MVP include parallel bootstrap?**
   - Pro: Performance benefit
   - Con: Additional testing complexity
   - **Decision**: Include, it's straightforward

3. **CRAN submission timing?**
   - Option 1: Submit medfit to CRAN before integration
   - Option 2: Submit after probmed integration
   - **Decision**: After probmed integration (reduces risk)

---

**Status**: ✅ Phase 3 Complete → Phase 4 (Model Fitting) Next

**Completed**:
- ✅ Phase 1: Package Setup
- ✅ Phase 2: S7 Class Architecture (extended with SerialMediationData)
- ✅ Phase 2.5: Comprehensive Quarto Documentation (4 vignettes, pkgdown website)
- ✅ Phase 3: Model Extraction (lm/glm and lavaan methods implemented)

**Current**:
- ⏳ Phase 4: Model Fitting (fit_mediation with GLM engine)

**Next (MVP)**:
- Phase 5: Bootstrap Infrastructure
- Phase 6: Extended Testing
- Phase 8: Polish & Release

**Post-MVP**:
- Phase 7: Interaction Support (VanderWeele four-way decomposition)
- Phase 7b: Estimation Engine Architecture (user interface, Decomposition class)
- Phase 7c: Engine Adapters (CMAverse, tmle3, etc.)

**Next Review**: After Phase 4 completion
**Last Updated**: 2025-12-03
