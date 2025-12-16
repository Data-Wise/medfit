# medfit Generic Function Naming Strategy

**Purpose**: Research-based proposal for medfit's generic function naming conventions
**Date**: December 2024
**Status**: Proposal for discussion

---

## Executive Summary

This document proposes a naming strategy for medfit's generic functions based on research into R's standard model generics, similar packages (lavaan, CMAverse, mediation), and the broom/tidyverse conventions. The recommendation is a **hybrid approach** that uses standard R generics where applicable while introducing domain-specific generics for mediation-specific operations.

**Key Recommendation**: Use `confint()` instead of `ci()`, implement standard model generics (`coef()`, `vcov()`, etc.), and reserve custom generics only for mediation-specific operations that have no standard R equivalent.

---

## Research Findings

### 1. Standard R Model Generics (Base R)

The following generics are universally used across statistical modeling packages in R:

| Generic | Purpose | Returns | Notes |
|---------|---------|---------|-------|
| **`coef()`** | Extract coefficients | Named numeric vector | Primary way to get parameter estimates |
| **`vcov()`** | Variance-covariance matrix | Square matrix | Must match `coef()` dimensions |
| **`confint()`** | Confidence intervals | 2-column matrix | Standard for all model types |
| **`fitted()`** | Fitted values | Numeric vector | Predicted values for training data |
| **`residuals()`** | Residuals | Numeric vector | Observed - fitted |
| **`predict()`** | Predictions | Varies | New data predictions |
| **`summary()`** | Model summary | Summary object | Comprehensive model info |
| **`print()`** | Print method | Invisible object | Console display |
| **`plot()`** | Diagnostic plots | NULL (side effect) | Visual diagnostics |
| **`update()`** | Update model | Updated model | Re-fit with changes |
| **`anova()`** | ANOVA table | ANOVA object | Model comparison |
| **`logLik()`** | Log-likelihood | logLik object | For information criteria |
| **`AIC()`** / **`BIC()`** | Information criteria | Numeric scalar | Model selection |
| **`nobs()`** | Number of observations | Integer | Sample size |
| **`formula()`** | Extract formula | Formula object | Model specification |
| **`model.frame()`** | Model frame | Data frame | Data used in fitting |
| **`model.matrix()`** | Design matrix | Matrix | Predictor matrix |
| **`deviance()`** | Model deviance | Numeric scalar | Goodness of fit |
| **`df.residual()`** | Residual df | Integer | Degrees of freedom |
| **`effects()`** | Effects | Numeric vector | Orthogonal effects |
| **`influence()`** | Influence measures | List | Diagnostic measures |
| **`hatvalues()`** | Leverage | Numeric vector | Hat matrix diagonal |
| **`simulate()`** | Simulate from model | Data frame/list | Generate synthetic data |

**Key Insight**: R has a well-established ecosystem of model generics. Packages that deviate from these conventions face usability issues and poor integration with other tools.

**Sources**:
- [R Manual: confint()](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/confint.html)
- [RDocumentation: vcov()](https://rdrr.io/r/stats/vcov.html)
- [SSCC: Regression Inference in R](https://www.ssc.wisc.edu/sscc/pubs/RFR/RFR_RegInference.html)

### 2. Broom Package Conventions (Tidyverse)

The broom package provides a tidy interface to model objects:

| Generic | Purpose | Returns | Format |
|---------|---------|---------|--------|
| **`tidy()`** | Coefficient table | Tibble | term, estimate, std.error, statistic, p.value |
| **`glance()`** | One-row summary | Tibble | Model-level stats (R², AIC, etc.) |
| **`augment()`** | Add to data | Tibble | Original data + .fitted, .resid, etc. |

**Key Insight**: Broom complements base R generics (doesn't replace them). It provides tidy data frames while base generics remain the primary interface.

### 3. lavaan Package Pattern (SEM)

lavaan uses a **hybrid approach**:

**Standard R generics implemented**:
- `coef()`, `vcov()`, `fitted()`, `residuals()`, `predict()`, `update()`, `anova()`, `logLik()`, `AIC()`, `BIC()`, `summary()`, `print()`, `nobs()`

**lavaan-specific functions** (NOT generics):
- `inspect()` / `lavInspect()` - Extract various model components
- `parameterEstimates()` - Detailed parameter table
- `standardizedSolution()` - Standardized coefficients
- `fitMeasures()` - Fit indices
- `modindices()` - Modification indices
- `lavPredict()` - Factor scores
- `lavResiduals()` - Various residuals

**Key Insight**: lavaan uses standard generics for standard operations, but introduces package-prefixed functions (lav*) for SEM-specific operations. This ensures compatibility while providing specialized functionality.

### 4. CMAverse Package (Causal Mediation Analysis)

CMAverse uses **custom named functions**, NOT generics:

**Main API functions**:
- `cmdag()` - DAG visualization (cm = causal mediation prefix)
- `cmest()` - Estimation (returns cmest object)
- `cmsens()` - Sensitivity analysis

**Pattern**: CMAverse uses a consistent prefix (`cm*`) for all functions. It does NOT implement standard R model generics like `coef()` or `confint()`. This makes it less integrated with the R ecosystem.

**Key Insight**: CMAverse's approach works for a self-contained package but limits interoperability. Users cannot use standard tools (e.g., `confint()`, `tidy()`) with CMAverse objects.

**Sources**:
- [CMAverse Website](https://bs1125.github.io/CMAverse/)
- [CMAverse GitHub](https://github.com/BS1125/CMAverse)

### 5. Mediation Package

The mediation package exports custom functions:

**Main functions**:
- `mediate()` - Main mediation analysis function
- `medsens()` - Sensitivity analysis
- `test.modmed()` - Test for moderated mediation
- `test.TMint()` - Test for treatment-mediator interaction

**Pattern**: Similar to CMAverse, uses custom function names without implementing standard R generics.

### 6. Best Practices from Research

From "Robust and clustered standard errors" tutorials and R documentation:

**Key principles**:
1. **`confint()` depends on `coef()` and `vcov()`**: The default `confint()` method uses `coef()` ± critical value × sqrt(diag(vcov()))`
2. **Robust standard errors**: Use sandwich package (`vcovHC()`, `vcovCL()`) which integrates with standard generics
3. **Aliased coefficients**: `vcov()` should contain NA rows/columns where `coef()` has NAs (since R 3.5.0)
4. **Integration**: Standard generics enable integration with tools like car, lmtest, sandwich, emmeans, etc.

**Sources**:
- [Program Evaluation: Standard Errors](https://evalf21.classes.andrewheiss.com/example/standard-errors/)

---

## Mediation-Specific Operations

These operations are unique to mediation analysis and have NO standard R equivalents:

| Operation | Current API | Purpose |
|-----------|-------------|---------|
| Extract mediation structure | `extract_mediation()` | Get a/b/c' paths from models |
| Fit mediation models | `fit_mediation()` | Fit mediator + outcome models |
| Bootstrap mediation | `bootstrap_mediation()` | Bootstrap inference |
| Get path coefficients | (none) | Extract specific paths (a, b, c', ab) |
| Decompose effects | (none) | Natural/controlled/interventional decomposition |
| Compute indirect effect | (none) | a × b (simple) or more complex |
| Compute direct effect | (none) | c' |
| Compute total effect | (none) | c' + ab |

---

## Four Strategic Options

### Option A: Standard R Generics Only

**Approach**: Use ONLY standard R generics, no custom generics.

**Implementation**:
```r
# S7 Classes
MediationData <- new_class("MediationData", ...)
BootstrapResult <- new_class("BootstrapResult", ...)

# Standard generics
coef(MediationData)        # Returns c(a=..., b=..., c_prime=..., ...)
vcov(MediationData)        # Returns full variance-covariance matrix
confint(MediationData)     # Returns CIs for all parameters
confint(BootstrapResult)   # Returns bootstrap CI
summary(MediationData)     # Comprehensive summary
print(MediationData)       # Print method
fitted(MediationData)      # Fitted values (if data available)
residuals(MediationData)   # Residuals (if data available)

# Regular functions for mediation-specific operations
extract_mediation(model)   # Returns MediationData
fit_mediation(...)         # Returns MediationData
bootstrap_mediation(...)   # Returns BootstrapResult

# Accessor functions (NOT generics)
paths(MediationData)       # Returns list(a=, b=, c_prime=, indirect=)
indirect_effect(MediationData)  # Returns a*b
direct_effect(MediationData)    # Returns c'
total_effect(MediationData)     # Returns c' + a*b
```

**Pros**:
- Maximum compatibility with existing R ecosystem
- Users can immediately use `confint()`, `coef()`, `vcov()`, `summary()`
- Works seamlessly with broom, car, lmtest, emmeans, etc.
- Familiar interface for R users
- No namespace collisions

**Cons**:
- Mediation-specific operations require function calls, not method dispatch
- Less discoverable (users must know function names like `paths()`, `indirect_effect()`)
- No polymorphism for mediation-specific operations
- Slightly less elegant for mediation-specific workflow

**Example workflow**:
```r
# Extract from models
med_data <- extract_mediation(fit_m, model_y = fit_y,
                              treatment = "X", mediator = "M")

# Use standard generics
coef(med_data)       # All coefficients
confint(med_data)    # CIs for all
summary(med_data)    # Full summary

# Use accessor functions for paths
paths(med_data)              # list(a=..., b=..., c_prime=..., indirect=...)
indirect_effect(med_data)    # 0.15

# Bootstrap
boot_res <- bootstrap_mediation(...)
confint(boot_res)    # Bootstrap CI
```

---

### Option B: Custom Generics Only

**Approach**: Define custom generics for ALL operations, including those with standard R equivalents.

**Implementation**:
```r
# Custom generics for everything
paths(object)          # Generic for path extraction
ci(object)             # Generic for confidence intervals (instead of confint)
parameters(object)     # Generic for parameter extraction (instead of coef)
variance(object)       # Generic for vcov (instead of vcov)
indirect(object)       # Generic for indirect effect
direct(object)         # Generic for direct effect
total(object)          # Generic for total effect
effects(object)        # Generic for effect decomposition
bootstrap(object, ...) # Generic for bootstrap inference
```

**Pros**:
- Completely self-contained API
- Mediation-specific naming (e.g., `indirect()`, `direct()`)
- Consistent with CMAverse approach
- Full control over all interfaces

**Cons**:
- Breaks compatibility with R ecosystem
- Cannot use `confint()`, `coef()`, `vcov()` from base R
- Incompatible with broom (`tidy()` expects `coef()`, `vcov()`, `confint()`)
- Incompatible with sandwich, car, lmtest, emmeans
- Steeper learning curve for R users
- Name collisions (e.g., `effects()` already exists in stats)
- Poor integration with existing tools
- Violates principle of least surprise

**Example workflow**:
```r
med_data <- extract_mediation(...)

# Custom API
paths(med_data)       # Path coefficients
ci(med_data)          # Custom CI method
parameters(med_data)  # Custom parameter extraction
indirect(med_data)    # Indirect effect
direct(med_data)      # Direct effect

# But cannot do:
confint(med_data)     # Doesn't work
coef(med_data)        # Doesn't work
tidy(med_data)        # Doesn't work (broom integration broken)
```

**Assessment**: This option is **NOT recommended**. It sacrifices ecosystem integration for minimal benefit.

---

### Option C: Hybrid Approach (RECOMMENDED)

**Approach**: Use standard R generics where applicable + custom generics for mediation-specific operations.

**Implementation**:
```r
# Standard R generics (for ecosystem integration)
coef(MediationData)        # All parameters
vcov(MediationData)        # Full variance-covariance
confint(MediationData)     # CIs for all parameters
confint(BootstrapResult)   # Bootstrap CI
summary(MediationData)     # Model summary
print(MediationData)       # Print method
nobs(MediationData)        # Sample size
fitted(MediationData)      # Fitted values (if data available)
residuals(MediationData)   # Residuals (if data available)

# Custom S7 generics for mediation-specific operations
paths(object)              # Extract path coefficients (a, b, c')
indirect_effect(object)    # Compute indirect effect
direct_effect(object)      # Compute direct effect
total_effect(object)       # Compute total effect
decompose_effects(object, type = c("natural", "controlled", "interventional"))

# Regular functions for workflow operations
extract_mediation(...)     # Extract from models
fit_mediation(...)         # Fit models
bootstrap_mediation(...)   # Bootstrap inference
```

**Pros**:
- Best of both worlds: standard compatibility + mediation-specific functionality
- Works with broom, car, lmtest, sandwich, emmeans
- Discoverable via `methods(class = "MediationData")`
- Follows lavaan's successful pattern
- Familiar to R users while providing specialized tools
- Clear separation: standard for standard, custom for domain-specific

**Cons**:
- More generics to maintain
- Need to document both standard and custom interfaces
- Potential confusion about which to use when

**Example workflow**:
```r
# Extract mediation structure
med_data <- extract_mediation(fit_m, model_y = fit_y,
                              treatment = "X", mediator = "M")

# Standard R generics work
coef(med_data)       # c(a=0.5, b=0.3, c_prime=0.2, ...)
vcov(med_data)       # Full variance-covariance matrix
confint(med_data)    # CIs for all parameters
summary(med_data)    # Comprehensive summary

# Mediation-specific generics
paths(med_data)              # list(a=0.5, b=0.3, c_prime=0.2)
indirect_effect(med_data)    # 0.15 (a*b)
direct_effect(med_data)      # 0.2 (c')
total_effect(med_data)       # 0.35 (c' + a*b)

# Works with broom
library(broom)
tidy(med_data)       # Tibble with estimates, std.error, conf.low, conf.high

# Works with sandwich
library(sandwich)
vcovHC(med_data)     # Robust standard errors (if we implement it)

# Bootstrap
boot_res <- bootstrap_mediation(
  statistic_fn = function(theta) theta["a"] * theta["b"],
  mediation_data = med_data,
  method = "parametric",
  n_boot = 5000
)
confint(boot_res)    # Bootstrap CI using standard generic
```

**Function Mapping**:

| Operation | Standard Generic | Custom Generic | Function |
|-----------|-----------------|----------------|----------|
| All coefficients | `coef()` | | |
| Variance-covariance | `vcov()` | | |
| Confidence intervals | `confint()` | | |
| Summary | `summary()` | | |
| Print | `print()` | | |
| Path coefficients | | `paths()` | |
| Indirect effect | | `indirect_effect()` | |
| Direct effect | | `direct_effect()` | |
| Total effect | | `total_effect()` | |
| Effect decomposition | | `decompose_effects()` | |
| Extract from models | | | `extract_mediation()` |
| Fit models | | | `fit_mediation()` |
| Bootstrap | | | `bootstrap_mediation()` |

---

### Option D: Package-Prefixed Hybrid

**Approach**: Standard generics + package-prefixed functions (like lavaan's lav* pattern).

**Implementation**:
```r
# Standard R generics
coef(MediationData)
vcov(MediationData)
confint(MediationData)
summary(MediationData)

# Package-prefixed functions (NOT generics)
medPaths(MediationData)       # Like lavInspect()
medIndirect(MediationData)    # Package-specific computation
medDirect(MediationData)
medTotal(MediationData)
medDecompose(MediationData, type = "natural")

# Workflow functions
extract_mediation(...)
fit_mediation(...)
bootstrap_mediation(...)
```

**Pros**:
- Clear namespace (med* prefix)
- Standard generics for standard operations
- No namespace collisions
- Follows lavaan pattern (proven successful)
- Easy to discover with tab completion (med<TAB>)

**Cons**:
- Longer function names
- No polymorphism for mediation-specific operations
- Package-specific functions instead of generics (less flexible)
- Cannot extend easily to other classes

**Example workflow**:
```r
med_data <- extract_mediation(...)

# Standard generics
coef(med_data)
confint(med_data)

# Package-prefixed functions
medPaths(med_data)          # Path coefficients
medIndirect(med_data)       # Indirect effect
medDecompose(med_data, "natural")  # Effect decomposition
```

---

## Comparison Matrix

| Feature | Option A (Standard Only) | Option B (Custom Only) | Option C (Hybrid) ★ | Option D (Prefixed) |
|---------|-------------------------|------------------------|-------------------|---------------------|
| **Ecosystem Integration** | ✅✅✅ Excellent | ❌ Poor | ✅✅✅ Excellent | ✅✅ Very Good |
| **Works with broom** | ✅ Yes | ❌ No | ✅ Yes | ✅ Yes |
| **Works with sandwich/car** | ✅ Yes | ❌ No | ✅ Yes | ✅ Yes |
| **Familiar to R users** | ✅✅✅ Very | ❌ Not at all | ✅✅ Yes | ✅✅ Yes |
| **Mediation-specific elegance** | ⚠️ Moderate | ✅✅ Good | ✅✅✅ Excellent | ✅ Good |
| **Namespace cleanliness** | ✅✅ Very clean | ⚠️ Potential conflicts | ✅ Clean | ✅✅✅ Very clean |
| **Discoverability** | ⚠️ Function names | ⚠️ Non-standard | ✅✅ Generic methods | ✅✅ Prefix pattern |
| **Extensibility** | ⚠️ Functions only | ✅ Generics | ✅✅ Generics | ⚠️ Functions only |
| **Polymorphism** | ❌ Limited | ✅✅ Full | ✅✅ Full | ❌ Limited |
| **Learning curve** | ✅✅✅ Low | ❌ High | ✅ Low-Moderate | ✅ Low-Moderate |
| **Implementation complexity** | ✅✅ Low | ⚠️ Moderate | ⚠️ Moderate | ✅✅ Low |
| **Maintenance burden** | ✅✅ Low | ⚠️ Moderate | ⚠️ Moderate | ✅✅ Low |

**Legend**: ✅✅✅ Excellent, ✅✅ Very Good, ✅ Good, ⚠️ Moderate/Caution, ❌ Poor

---

## Recommendations

### Primary Recommendation: Option C (Hybrid Approach)

**Rationale**:

1. **Ecosystem Integration**: medfit is a *foundation package* used by probmed, RMediation, and medrobust. It must integrate seamlessly with the R ecosystem.

2. **User Expectations**: R users expect `confint()`, `coef()`, `vcov()` to work. Deviating from this creates friction.

3. **Tool Compatibility**: Many packages (broom, car, sandwich, lmtest, emmeans) depend on standard generics. Breaking this compatibility limits medfit's usefulness.

4. **Successful Precedent**: lavaan uses this pattern successfully. It implements standard generics while providing package-specific functions for SEM operations.

5. **Clear Separation**: Standard generics for standard operations (confidence intervals, coefficients), custom generics for mediation-specific operations (paths, indirect effects).

### Specific Recommendations

#### 1. Implement Standard R Generics

**Must implement**:
```r
# Core model interface
coef(MediationData)           # Return all parameters
vcov(MediationData)           # Return variance-covariance matrix
confint(MediationData, ...)   # Return CIs (uses confint.default or custom)
summary(MediationData)        # Return summary object
print(MediationData)          # Print method

# Bootstrap results
confint(BootstrapResult)      # Return bootstrap CI
print(BootstrapResult)        # Print method

# Metadata
nobs(MediationData)           # Return n_obs
```

**Should implement** (if data available):
```r
fitted(MediationData)         # Fitted values
residuals(MediationData)      # Residuals
predict(MediationData, ...)   # Predictions
```

**Future consideration**:
```r
logLik(MediationData)         # Log-likelihood (if applicable)
AIC(MediationData)            # Information criteria
simulate(MediationData, ...)  # Simulate from model
```

#### 2. Define Custom S7 Generics for Mediation Operations

```r
#' Extract Path Coefficients from Mediation Object
#'
#' @param object A mediation object (MediationData, SerialMediationData)
#' @param ... Additional arguments
#' @return Named list with path coefficients
#' @export
paths <- S7::new_generic("paths", dispatch_args = "object")

#' Compute Indirect Effect
#'
#' @param object A mediation object
#' @param ... Additional arguments
#' @return Numeric scalar or vector
#' @export
indirect_effect <- S7::new_generic("indirect_effect", dispatch_args = "object")

#' Compute Direct Effect
#'
#' @param object A mediation object
#' @param ... Additional arguments
#' @return Numeric scalar
#' @export
direct_effect <- S7::new_generic("direct_effect", dispatch_args = "object")

#' Compute Total Effect
#'
#' @param object A mediation object
#' @param ... Additional arguments
#' @return Numeric scalar
#' @export
total_effect <- S7::new_generic("total_effect", dispatch_args = "object")

#' Decompose Effects
#'
#' @param object A mediation object
#' @param type Character: "natural", "controlled", "interventional"
#' @param ... Additional arguments
#' @return Decomposition object
#' @export
decompose_effects <- S7::new_generic("decompose_effects", dispatch_args = "object")
```

#### 3. Keep Workflow Functions as Regular Functions

```r
#' Extract Mediation Structure from Fitted Models
#'
#' @param object Fitted model object
#' @param ... Additional arguments
#' @return MediationData or SerialMediationData object
#' @export
extract_mediation <- S7::new_generic("extract_mediation", dispatch_args = "object")

#' Fit Mediation Models
#'
#' @param formula_y Outcome formula
#' @param formula_m Mediator formula
#' @param ... Additional arguments
#' @return MediationData object
#' @export
fit_mediation <- function(formula_y, formula_m, ...) { ... }

#' Bootstrap Inference for Mediation
#'
#' @param statistic_fn Function to compute statistic
#' @param ... Additional arguments
#' @return BootstrapResult object
#' @export
bootstrap_mediation <- function(statistic_fn, ...) { ... }
```

#### 4. Integration with Broom

Implement S3 methods for broom generics:

```r
#' Tidy Method for MediationData
#'
#' @param x MediationData object
#' @param conf.int Logical: include confidence intervals?
#' @param conf.level Numeric: confidence level
#' @param ... Additional arguments
#' @return Tibble with tidy coefficient table
#' @export
tidy.MediationData <- function(x, conf.int = TRUE, conf.level = 0.95, ...) {
  # Use coef() and vcov() to construct tidy output
  # Include path labels (a, b, c_prime, indirect)
}

#' Glance Method for MediationData
#'
#' @param x MediationData object
#' @param ... Additional arguments
#' @return One-row tibble with model-level statistics
#' @export
glance.MediationData <- function(x, ...) {
  # Model-level stats: n_obs, indirect effect, etc.
}
```

---

## Migration Strategy

### Current State (as of December 2024)

**Existing generics** (in `R/aab-generics.R`):
- `extract_mediation()` - S7 generic ✅ Keep
- `fit_mediation()` - Regular function ✅ Keep
- `bootstrap_mediation()` - Regular function ✅ Keep

**Existing classes** (in `R/classes.R`):
- `MediationData` - S7 class with print/summary methods ✅ Keep
- `SerialMediationData` - S7 class with print/summary methods ✅ Keep
- `BootstrapResult` - S7 class with print/summary methods ✅ Keep

### Phase 1: Add Standard R Generics (Week 1)

**Goal**: Implement `coef()`, `vcov()`, `confint()` for all mediation classes.

**Tasks**:
1. Create `R/methods-standard.R`
2. Implement S7 methods for standard generics:
   - `coef.MediationData` / `coef.SerialMediationData`
   - `vcov.MediationData` / `vcov.SerialMediationData`
   - `confint.MediationData` / `confint.SerialMediationData` / `confint.BootstrapResult`
   - `nobs.MediationData` / `nobs.SerialMediationData`
3. Write tests in `tests/testthat/test-methods-standard.R`
4. Update documentation

**Implementation notes**:
- `coef()` returns ALL parameters (a, b, c', plus any covariates in estimates)
- `vcov()` returns the full variance-covariance matrix
- `confint()` can use default method or custom (e.g., bootstrap-based)

### Phase 2: Add Mediation-Specific Generics (Week 2)

**Goal**: Implement custom generics for mediation operations.

**Tasks**:
1. Update `R/aab-generics.R` with new generic definitions
2. Create `R/methods-mediation.R`
3. Implement S7 methods:
   - `paths()` for MediationData and SerialMediationData
   - `indirect_effect()`, `direct_effect()`, `total_effect()`
4. Write tests in `tests/testthat/test-methods-mediation.R`
5. Update documentation

### Phase 3: Broom Integration (Week 3)

**Goal**: Enable `tidy()`, `glance()` for mediation objects.

**Tasks**:
1. Add broom to Suggests in DESCRIPTION
2. Create `R/methods-broom.R`
3. Implement S3 methods:
   - `tidy.MediationData`, `tidy.SerialMediationData`, `tidy.BootstrapResult`
   - `glance.MediationData`, `glance.SerialMediationData`
4. Write tests
5. Update vignettes to show broom workflow

### Phase 4: Documentation and Vignettes (Week 4)

**Goal**: Comprehensive documentation of new API.

**Tasks**:
1. Update CLAUDE.md with new generic naming strategy
2. Create vignette: "Using medfit with Standard R Tools"
3. Create vignette: "Mediation-Specific Operations"
4. Update README with new examples
5. Update function documentation with cross-references

---

## Answers to Specific Questions

### 1. Should medfit use `confint()` or custom `ci()` for confidence intervals?

**Answer**: **Use `confint()`**

**Rationale**:
- `confint()` is the universal R standard for confidence intervals
- Works with all model types (lm, glm, nls, etc.)
- Expected by users and downstream tools
- Integrates with broom (`tidy(..., conf.int = TRUE)`)
- Custom `ci()` would break compatibility with no real benefit

**Implementation**:
```r
# For MediationData: confint() uses delta method or bootstrap
S7::method(confint, MediationData) <- function(object, parm, level = 0.95, ...) {
  # Implementation using vcov() and normal approximation
  # Or bootstrap if available
}

# For BootstrapResult: confint() returns bootstrap CI
S7::method(confint, BootstrapResult) <- function(object, parm, level = 0.95, ...) {
  # Return ci_lower and ci_upper
}
```

### 2. Should path extraction use `coef()` or custom `paths()`?

**Answer**: **Use BOTH**

**Rationale**:
- `coef()` returns ALL model parameters (for ecosystem compatibility)
- `paths()` returns mediation-specific path coefficients (a, b, c', ab)
- Different use cases: `coef()` for general tools, `paths()` for mediation workflow

**Implementation**:
```r
# Standard generic: all parameters
S7::method(coef, MediationData) <- function(object, ...) {
  object@estimates  # All parameters including covariates
}

# Custom generic: just paths
S7::method(paths, MediationData) <- function(object, ...) {
  list(
    a = object@a_path,
    b = object@b_path,
    c_prime = object@c_prime,
    indirect = object@a_path * object@b_path
  )
}
```

### 3. How to handle mediation-specific concepts not in base R?

**Answer**: **Use custom S7 generics with clear names**

**Rationale**:
- Operations like "indirect effect", "direct effect", "effect decomposition" have no R standard
- Create generics with descriptive names: `indirect_effect()`, `decompose_effects()`
- Use generics (not functions) to enable polymorphism across mediation types
- Avoid overly generic names (e.g., `effect()` is too broad)

**Guidelines**:
- Prefix with domain concept: `indirect_effect()` not `ie()`
- Use full words: `decompose_effects()` not `decomp()`
- Make intent clear from name: `total_effect()` not `te()`

### 4. What's the convention in similar packages (lavaan, sem, etc.)?

**Answer**: **Hybrid approach: standard generics + package-specific functions**

**lavaan pattern**:
- Implements: `coef()`, `vcov()`, `fitted()`, `residuals()`, `predict()`, `anova()`, `logLik()`, `AIC()`, `BIC()`, `summary()`, `print()`, `nobs()`
- Package-specific functions: `inspect()`, `lavInspect()`, `parameterEstimates()`, `standardizedSolution()`, `fitMeasures()`
- **Key insight**: Standard for standard, custom for SEM-specific

**sem package pattern**:
- Similar to lavaan
- Standard generics implemented
- Custom functions for SEM operations

**CMAverse/mediation pattern**:
- Custom functions only (no standard generics)
- Less integrated with R ecosystem
- **NOT recommended to follow**

---

## Implementation Roadmap

### Immediate Actions (Next Sprint)

1. **Add standard generics** (`coef()`, `vcov()`, `confint()`) to existing classes
2. **Define custom generics** for mediation operations in `R/aab-generics.R`
3. **Update tests** to cover new methods
4. **Update documentation** in CLAUDE.md and function roxygen2

### Short-term (Next Month)

1. **Broom integration**: Implement `tidy()` and `glance()` methods
2. **Vignette**: Create "medfit and the R Ecosystem" vignette
3. **Examples**: Add workflow examples using standard generics
4. **pkgdown**: Update website with new API

### Medium-term (Next Quarter)

1. **Sandwich integration**: Enable robust standard errors with `sandwich::vcovHC()`
2. **emmeans integration**: Support marginal effects computation
3. **Advanced decompositions**: Implement `decompose_effects()` generic
4. **Comprehensive testing**: Ensure compatibility with major R packages

---

## Conclusion

The **Hybrid Approach (Option C)** is strongly recommended for medfit:

**Use standard R generics** (`confint()`, `coef()`, `vcov()`, `summary()`, etc.) for operations that have R standards. This ensures:
- Ecosystem integration
- User familiarity
- Tool compatibility

**Use custom S7 generics** (`paths()`, `indirect_effect()`, `direct_effect()`, `decompose_effects()`) for mediation-specific operations. This provides:
- Domain-appropriate interface
- Polymorphism across mediation types
- Extensibility

**Keep workflow functions** (`extract_mediation()`, `fit_mediation()`, `bootstrap_mediation()`) as regular functions/generics. These orchestrate the workflow.

This approach follows the successful pattern established by lavaan and ensures medfit serves its role as a foundation package for the mediation analysis ecosystem.

---

## References

- [R Manual: confint()](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/confint.html)
- [RDocumentation: vcov()](https://rdrr.io/r/stats/vcov.html)
- [SSCC: Regression Inference in R](https://www.ssc.wisc.edu/sscc/pubs/RFR/RFR_RegInference.html)
- [Program Evaluation: Standard Errors](https://evalf21.classes.andrewheiss.com/example/standard-errors/)
- [CMAverse Website](https://bs1125.github.io/CMAverse/)
- [CMAverse GitHub](https://github.com/BS1125/CMAverse)
- lavaan package documentation
- broom package documentation
- R Packages book (Hadley Wickham & Jennifer Bryan)

---

**Document Status**: Ready for review and discussion
**Next Steps**: Discuss with team, finalize decision, implement Phase 1
