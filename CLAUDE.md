# CLAUDE.md for medfit Package

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## About This Package

**medfit** is a foundation package providing unified infrastructure for fitting mediation models, extracting path coefficients, and performing bootstrap inference. It eliminates redundancy across the mediation analysis ecosystem (probmed, RMediation, medrobust) by providing shared S7-based classes and methods.

### Core Mission

Provide clean, efficient, type-safe infrastructure for mediation model handling that can be shared across multiple effect size computation packages, reducing code duplication and ensuring consistency.

### Package Ecosystem Context

**medfit is the foundation for**:

1. **probmed** - P_med (probabilistic effect size)
   - Uses medfit for: model fitting, extraction, bootstrap
   - Adds: P_med computation, visualization

2. **RMediation** - Confidence intervals (DOP, MBCO)
   - Uses medfit for: model extraction, bootstrap utilities
   - Adds: Distribution of Product, MBCO tests, MC methods

3. **medrobust** - Sensitivity analysis
   - Uses medfit for: optional naive estimates, bootstrap
   - Adds: Bounds computation, falsification tests

**Key Principle**: medfit provides infrastructure, not effect sizes. Each dependent package focuses on its unique methodological contribution.

### Key References

- Tofighi, D. (2025). medfit: Infrastructure for mediation analysis in R. (In preparation)
- Related: probmed, RMediation, medrobust package documentation

---

## Common Development Commands

**Preferred Tools**: Use `devtools` and `usethis` packages for all R package development tasks. These provide convenient wrappers and best practices for package development workflows.

### Package Building and Checking

```r
# Install package dependencies
remotes::install_deps(dependencies = TRUE)

# Check package (standard R CMD check)
rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "error")

# Build package
devtools::build()

# Install and reload during development
devtools::load_all()
```

### Documentation

```r
# Generate documentation from roxygen2 comments
devtools::document()

# Build vignettes
devtools::build_vignettes()

# Build pkgdown site
pkgdown::build_site()
```

### Testing

```r
# Run all tests
devtools::test()

# Run specific test file
testthat::test_file("tests/testthat/test-classes.R")

# Check coverage
covr::package_coverage()
```

---

## Coding Standards

### R Version and Style

- **Minimum R version**: 4.1.0 (native pipe `|>` support)
- **OOP Framework**: S7 (modern object system)
- **Style**: tidyverse style guide with native pipe
- **Roxygen2**: Use roxygen2 for documentation (>= 7.3.0)
- **Clarity priority**: Code must be readable and maintainable

### Naming Conventions

The package uses **snake_case** consistently:

**Functions:**
- Main exports: `fit_mediation()`, `extract_mediation()`, `bootstrap_mediation()`
- Internal functions prefix with dot: `.fit_mediation_glm()`, `.bootstrap_parametric()`

**Arguments:**
- `formula_y`, `formula_m` for model specifications
- `treatment`, `mediator`, `outcome` for variable names
- `engine` for modeling engine: "glm", "lmer", "brms"
- `method` for inference method: "parametric", "nonparametric", "plugin"
- `n_boot` for number of bootstrap samples
- `ci_level` for confidence level (default: 0.95)

**S7 Classes:**
- CamelCase: `MediationData`, `BootstrapResult`
- Properties use snake_case: `@a_path`, `@boot_estimates`

### Code Organization

```
R/
├── aaa-imports.R           # Package imports and setup
├── medfit-package.R        # Package documentation
├── classes.R               # S7 class definitions
├── generics.R              # S7 generic functions
├── fit-glm.R              # GLM engine implementation
├── extract-lm.R           # lm/glm extraction
├── extract-lavaan.R       # lavaan extraction
├── extract-openmx.R       # OpenMx extraction (if included)
├── bootstrap.R            # Bootstrap infrastructure
├── utils.R                # Utility functions
└── zzz.R                  # .onLoad() for dynamic dispatch
```

---

## Code Architecture

### S7 Object System

The package uses S7 for type-safe, modern object-oriented programming.

**Key S7 Classes:**

1. **`MediationData`** - Standardized mediation model structure
   - Properties: `a_path`, `b_path`, `c_prime`, `estimates`, `vcov`, `data`, etc.
   - Validator ensures internal consistency
   - Base class that dependent packages can extend

2. **`BootstrapResult`** - Bootstrap inference results
   - Properties: `estimate`, `ci_lower`, `ci_upper`, `boot_estimates`, `method`
   - Validator checks consistency
   - Used by all packages for inference

**S7 Generics:**

1. **`extract_mediation()`** - Extract mediation structure from models
   - Methods: `lm`, `glm`, `lavaan`, (future: `lmerMod`, `brmsfit`)
   - Returns: `MediationData` object

2. **`fit_mediation()`** - Fit mediation models
   - Dispatcher to engine-specific functions
   - Returns: `MediationData` object

3. **`bootstrap_mediation()`** - Perform bootstrap inference
   - Methods: parametric, nonparametric, plugin
   - Returns: `BootstrapResult` object

**S7 Documentation Patterns:**

When documenting S7 classes and methods with roxygen2:

1. **S7 Class Constructors**: Use explicit `@param` tags for all properties
   ```r
   #' MediationData S7 Class
   #'
   #' @description
   #' S7 class containing standardized mediation model structure
   #'
   #' @param a_path Numeric scalar: effect of treatment on mediator
   #' @param b_path Numeric scalar: effect of mediator on outcome
   #' # ... document ALL properties explicitly
   #'
   #' @return A MediationData S7 object
   #' @export
   MediationData <- S7::new_class(...)
   ```

2. **S7 Methods**: Use `@noRd` to prevent namespace export issues
   ```r
   #' Print Method for MediationData
   #'
   #' @param x A MediationData object
   #' @param ... Additional arguments (ignored)
   #' @noRd
   S7::method(print, MediationData) <- function(x, ...) { ... }
   ```

   **Important**:
   - Do NOT use `@export` for S7 methods (causes namespace errors)
   - Do NOT use `@name` tag (causes duplicate .Rd files)
   - Use `@noRd` to document internally without generating .Rd files
   - S7 methods work via automatic dispatch, not namespace exports

3. **S7 Generics**: Only document generic parameters, not method-specific ones
   ```r
   #' Extract Mediation Structure
   #'
   #' @param object Fitted model object
   #' @param ... Additional arguments passed to methods. Common arguments include:
   #'   - `treatment`: Character string (document in prose, not as @param)
   #'   - `mediator`: Character string (document in prose, not as @param)
   #' @export
   extract_mediation <- S7::new_generic("extract_mediation", dispatch_args = "object")
   ```

4. **Testing S7 Methods**: Method dispatch may not work in installed package context
   ```r
   test_that("MediationData print method works", {
     skip_if_not(interactive(), "S7 method dispatch issue in non-interactive mode")
     # ... test code
   })
   ```

5. **S7 Method Registration in .onLoad()**: Do NOT use `S7::methods_register()`
   ```r
   # INCORRECT - causes load-time errors
   .onLoad <- function(libname, pkgname) {
     S7::methods_register()  # DON'T DO THIS
   }

   # CORRECT - rely on S4 registration
   .onLoad <- function(libname, pkgname) {
     # S7 methods work automatically after S7::S4_register() in class definitions
     # No additional registration needed
   }
   ```

   **Why**:
   - `S7::methods_register()` in `.onLoad()` tries to register methods before classes are defined
   - S7 methods are defined at package build time, not load time
   - S7 method dispatch works automatically after `S7::S4_register()` calls
   - Always call `S7::S4_register(ClassName)` immediately after each class definition

**S7 and S3 Class Integration:**

When working with S3 classes in S7 packages, follow this guide:

1. **Mandatory Package Setup**: Call `S7::methods_register()` in `.onLoad()`
   - Required for dynamic method registration
   - Especially important for methods on generics from other packages
   - **Note**: In medfit, this causes errors during package load because classes aren't defined yet
   - Our approach: rely on `S7::S4_register()` immediately after class definitions

2. **Formalizing S3 Classes**: Use `new_S3_class()` to wrap S3 classes
   ```r
   # Register method for S3 class
   method(my_generic, new_S3_class("data.frame")) <- function(x) {...}

   # Use in property definitions
   MyClass <- new_class("MyClass",
     properties = list(
       data = new_S3_class("data.frame")
     )
   )

   # Use in unions
   my_union <- new_union(class_numeric, new_S3_class("Date"))
   ```

   **Built-in S3 wrappers**: S7 provides `class_data.frame`, `class_Date`, `class_factor`, etc.

3. **Inheriting from S3 Classes**: Requires custom constructor
   ```r
   # When inheriting from S3 via parent argument
   MyS7Class <- new_class("MyS7Class",
     parent = new_S3_class("integer",
       constructor = function(.data, ...) {
         # .data must be first argument
         # Add S3 class attributes
       }
     )
   )
   ```

4. **Calling Parent S3 Methods**: Use `S7_data()`, not `super()`
   ```r
   # INCORRECT - S3 generics don't understand super()
   method(print, MyClass) <- function(x) {
     super(x, print)  # FAILS
   }

   # CORRECT - Extract underlying S3 object
   method(print, MyClass) <- function(x) {
     print(S7_data(x))  # Dispatches to S3 print method
   }
   ```

5. **Migrating S3 Packages to S7**: Incremental approach
   - Add `S7::methods_register()` to `.onLoad()`
   - Wrap existing S3 classes with `new_S3_class()`
   - Gradually replace informal S3 with formal `new_class()` definitions
   - Existing S3 code continues to work because S7 objects retain S3 class attribute

### Core Function Hierarchy

**User-Facing Functions:**

1. **`fit_mediation()`** - Fit models with formula interface
   - Most convenient for users
   - Internally uses engine-specific functions
   - Currently supports GLM engine

2. **`extract_mediation()`** - Extract from fitted models
   - Generic with methods for different model types
   - Standardizes across packages
   - Returns `MediationData`

3. **`bootstrap_mediation()`** - Bootstrap inference
   - Three methods: parametric, nonparametric, plugin
   - Parallel processing support
   - Returns `BootstrapResult`

**Internal Functions:**

- `.fit_mediation_glm()`: GLM engine implementation
- `.bootstrap_parametric()`: Parametric bootstrap
- `.bootstrap_nonparametric()`: Nonparametric bootstrap
- `.bootstrap_plugin()`: Plugin estimator
- Utility functions for validation, formatting, etc.

### Key Dependencies

**Required:**
- **S7**: Modern object system
- **stats**: GLM fitting, statistical functions
- **methods**: S4 compatibility

**Suggested:**
- **MASS**: `mvrnorm()` for parametric bootstrap
- **lavaan**: SEM model extraction
- **OpenMx**: SEM model extraction
- **lme4**: Mixed models (future)

### Explicit Namespacing

**CRITICAL**: All non-base functions MUST use explicit namespacing:

```r
# CORRECT
stats::glm(formula, data = data)
MASS::mvrnorm(n, mu, Sigma)
lavaan::sem(model, data = data)

# INCORRECT
glm(formula, data = data)
mvrnorm(n, mu, Sigma)
sem(model, data = data)
```

---

## Important Implementation Details

### S7 Class Design

**MediationData** is the central data structure:
- Contains all information about mediation model
- Path coefficients (a, b, c')
- Full parameter vector and covariance matrix
- Residual variances (for Gaussian models)
- Variable names and metadata
- Data and sample size

**Design principle**: Complete information for downstream packages

### Model Extraction Pattern

All `extract_mediation()` methods follow this pattern:

1. **Validate inputs** (check variable names exist)
2. **Extract parameters** (a, b, c' paths)
3. **Extract covariance matrix** (for inference)
4. **Extract residual variances** (if Gaussian)
5. **Get data** (if available)
6. **Create MediationData** object
7. **Return**

### Bootstrap Implementation

**Three methods with different trade-offs**:

1. **Parametric** (`method = "parametric"`):
   - Samples from N(θ̂, Σ̂)
   - Fast, requires normality
   - Default for most applications

2. **Nonparametric** (`method = "nonparametric"`):
   - Resamples data, refits models
   - Robust, computationally intensive
   - Use when normality questionable

3. **Plugin** (`method = "plugin"`):
   - Point estimate only, no CI
   - Fastest, for quick checks

**Parallel processing**:
- Uses `parallel::mclapply()` (Unix) or similar
- Auto-detects cores if not specified
- Set seed for reproducibility

### Dynamic S7/S4 Dispatch

For S4 classes from suggested packages (lavaan, OpenMx):

```r
# In R/zzz.R
.onLoad <- function(libname, pkgname) {
  # Register lavaan method if available
  if (requireNamespace("lavaan", quietly = TRUE)) {
    lavaan_class <- S7::as_class(methods::getClass("lavaan", where = "lavaan"))
    S7::method(extract_mediation, lavaan_class) <- extract_mediation_lavaan
  }

  # Register OpenMx method if available
  if (requireNamespace("OpenMx", quietly = TRUE)) {
    # Similar pattern
  }
}
```

This allows methods to work without hard dependencies.

---

## Testing Strategy

### Unit Tests Should Cover

1. **S7 Class Validation**
   - Property type checking
   - Validators catch invalid inputs
   - Edge cases (empty, NA, wrong dimensions)

2. **Model Extraction**
   - lm/glm extraction accuracy
   - lavaan extraction consistency
   - Identical results to manual extraction
   - Proper handling of different model types

3. **Model Fitting**
   - GLM engine produces valid MediationData
   - Formula parsing correct
   - Family specifications work
   - Error handling for convergence failures

4. **Bootstrap Methods**
   - Parametric bootstrap reproducible with seed
   - Nonparametric bootstrap reproducible with seed
   - Plugin method fast and accurate
   - CI coverage in simulations (~95% for 95% CI)
   - Parallel and sequential give same results (with seed)

5. **Edge Cases**
   - Small sample sizes (n < 50)
   - Non-convergent models
   - Singular covariance matrices
   - Missing data
   - Zero effects

### Test Organization

```
tests/testthat/
├── helper-test-data.R      # Test data generators
├── test-classes.R          # S7 class validation
├── test-extract-lm.R       # lm/glm extraction
├── test-extract-lavaan.R   # lavaan extraction
├── test-fit-glm.R          # GLM fitting
├── test-bootstrap.R        # Bootstrap methods
└── test-utils.R            # Utility functions
```

### Coverage Expectations

- **Target**: >90% overall coverage
- **Critical paths**: 100% coverage
  - S7 class definitions
  - Core extraction functions
  - Bootstrap methods

---

## Integration with Dependent Packages

### probmed Integration

**probmed will**:
- Import medfit
- Replace extraction code with `medfit::extract_mediation()`
- Replace bootstrap code with `medfit::bootstrap_mediation()`
- Keep its formula interface as wrapper around medfit
- Add P_med-specific computation

**Backward compatibility critical**: probmed users should see no changes

### RMediation Integration

**RMediation will**:
- Import medfit
- Replace extraction code with `medfit::extract_mediation()`
- Optionally use bootstrap utilities
- Keep its unique methods (DOP, MBCO, MC)

### medrobust Integration

**medrobust will**:
- Suggest medfit (optional)
- Optionally use for naive estimates
- Keep its unique methods (bounds, falsification)

### Coordination

**When making changes that affect**:
- S7 class structure → Coordinate with all packages
- Extraction API → Coordinate with probmed and RMediation
- Bootstrap API → Coordinate with all packages

**Versioning**:
- Use semantic versioning
- Breaking changes → major version bump
- New features → minor version bump
- Bug fixes → patch version bump

---

## Development Roadmap

See `planning/medfit-roadmap.md` for detailed implementation plan.

### Current Phase: MVP Development

- [x] Package skeleton
- [ ] S7 classes implemented
- [ ] Extraction methods (lm/glm, lavaan)
- [ ] Fitting API (GLM engine)
- [ ] Bootstrap infrastructure
- [ ] Comprehensive tests
- [ ] Documentation and vignettes

### Future Enhancements

- [ ] lmer engine (mixed models)
- [ ] brms engine (Bayesian)
- [ ] Additional extraction methods
- [ ] Performance optimizations
- [ ] Extended documentation

---

## Statistical Assumptions

### Key Assumptions for Inference

1. **Correct model specification**
   - Mediator model correctly specified
   - Outcome model correctly specified
   - Appropriate family/link functions

2. **Parameter normality** (for parametric bootstrap)
   - (θ̂) ~ N(θ, Σ)
   - Generally holds for large n (CLT)
   - Check with Q-Q plots

3. **No unmeasured confounding** (for causal interpretation)
   - Standard causal mediation assumptions
   - Not testable, requires subject-matter knowledge
   - **Note**: medfit computes statistics; causal interpretation is user's responsibility

### Diagnostics

Users should:
- Check bootstrap distributions (histograms, Q-Q plots)
- Verify model convergence
- Assess residual plots
- Consider sensitivity analyses

---

## Common Pitfalls to Avoid

1. **Don't mix up variable names**: Ensure treatment/mediator names match model
2. **Don't ignore convergence warnings**: Check `converged` property
3. **Don't use plugin for inference**: Always bootstrap for CIs
4. **Don't skip input validation**: Use validators rigorously
5. **Don't break backward compatibility**: Coordinate with dependent packages

---

## Key Mathematical Formulas

### Indirect Effect

For simple mediation (X → M → Y):
```
Indirect effect = a × b
```

where:
- a = effect of X on M
- b = effect of M on Y (controlling for X)

### Parametric Bootstrap

Sample from:
```
θ* ~ N(θ̂, Σ̂)
```

Compute statistic for each θ*, extract quantiles for CI.

### Nonparametric Bootstrap

1. Resample data: D* ~ D (with replacement)
2. Refit models on D*
3. Extract θ*
4. Compute statistic
5. Repeat, extract quantiles for CI

---

## Additional Resources

### Package Ecosystem Documentation

- **probmed**: `probmed/CLAUDE.md`, `probmed/planning/`
- **RMediation**: `rmediation/CLAUDE.md`
- **medrobust**: `medrobust/CLAUDE.md`
- **Ecosystem strategy**: `probmed/planning/three-package-ecosystem-strategy.md`

### Key Planning Documents

Located in `planning/`:
- **medfit-roadmap.md**: Detailed implementation plan
- **ECOSYSTEM.md**: Connection to dependent packages

### Related Packages

- probmed: https://github.com/data-wise/probmed
- RMediation: https://github.com/data-wise/rmediation
- medrobust: https://github.com/data-wise/medrobust

---

## Troubleshooting

### lavaan Dispatch Issues

If `extract_mediation()` doesn't work with lavaan objects:
- Check that lavaan is installed
- Verify `.onLoad()` is registering the method
- Test with `methods(extract_mediation)` to see registered methods

### Bootstrap Reproducibility

If bootstrap results not reproducible:
- Ensure seed is set before calling
- Check that parallel=FALSE or seed is set before parallel call
- Verify n_boot is the same

### Performance Issues

If bootstrap is slow:
- Use `parallel=TRUE`
- Consider parametric instead of nonparametric
- Reduce `n_boot` for testing (use 1000+ for production)

---

**Last Updated**: 2025-12-02
**Maintained by**: medfit development team
