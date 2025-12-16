# medfit API Design Decisions

**Date**: 2025-12-15
**Status**: Finalized strategic planning
**Purpose**: Consolidated summary of all API design decisions

---

## Executive Summary

This document consolidates all strategic planning decisions for the medfit package API design. After extensive research and brainstorming, we have finalized an **ADHD-friendly, ecosystem-compatible API** that uses:

1. **S7 classes** for type-safe data structures
2. **Hybrid generics**: Standard R generics + custom S3 generics
3. **Short, clear function names**: `mediate()`, `boot()`, `paths()`
4. **Pipeline-friendly workflow** with smart defaults
5. **No namespace conflicts** via S7 methods on custom S3 generics

---

## Core Design Principles

### 1. ADHD-Friendly Design

**Goals**:
- Minimize cognitive load
- Reduce decision fatigue
- Support flow state
- Short, memorable names
- Pipeline-friendly

**Implementation**:
- Short verbs: `mediate()`, `boot()`, `paths()`
- Smart defaults: parametric, 1000 reps, 95% CI
- One continuous pipeline: `data %>% mediate(...) %>% boot() %>% confint()`
- Minimal intermediate objects (0-1)

### 2. Ecosystem Integration

**Goals**:
- Work with existing R tools
- Follow R conventions
- Enable interoperability

**Implementation**:
- Standard generics: `confint()`, `coef()`, `vcov()`, `summary()`, `print()`
- Works with: broom, sandwich, car, lmtest, emmeans
- S7 + S3 compatibility

### 3. Type Safety

**Goals**:
- Catch errors early
- Validate data structures
- Clear contracts

**Implementation**:
- S7 classes with property validation
- Comprehensive validators
- Type-checked method dispatch

---

## Decision 1: Object System - S7

**Decision**: Use S7 for classes and methods

**Alternatives considered**:
- S3: Too loose, no type safety
- S4: Too verbose, firewall with S7
- R6: Wrong paradigm (encapsulated OOP)

**Rationale**:
- Modern, future-proof (backed by R Consortium, tidyverse, Bioconductor)
- Type safety without S4 verbosity
- Excellent interoperability (works with S3, S4)
- Clean syntax
- ggplot2 4.0.0 migration validates production-readiness

**Performance**: ~24ms overhead in typical workflow (negligible)

**References**: `planning/GENERIC-FUNCTIONS-RESEARCH.md`

---

## Decision 2: Generic System - Hybrid S3

**Decision**: Use standard R generics + custom S3 generics (both with S7 methods)

**Alternatives considered**:
- S7 generics only: Slower dispatch, less familiar
- S3 generics only: Missing features (no super(), limited multiple dispatch)
- Custom generics only: Breaks ecosystem integration

**Rationale**:
- Standard generics ensure ecosystem compatibility
- Custom S3 generics allow ADHD-friendly short names
- S7 method registration works with ANY generic (S3, S4, S7)
- No namespace conflicts (medfit::boot ≠ boot::boot)

**Implementation**:

```r
# Standard R generics (register S7 methods on existing generics)
S7::method(confint, MediationData) <- function(object, ...) { ... }
S7::method(coef, MediationData) <- function(object, ...) { ... }
S7::method(vcov, MediationData) <- function(object, ...) { ... }

# Custom S3 generics (define our own, register S7 methods)
mediate <- function(outcome, ...) UseMethod("mediate")
S7::method(mediate, new_S3_class("data.frame")) <- function(...) { ... }

boot <- function(object, ...) UseMethod("boot")
S7::method(boot, MediationData) <- function(...) { ... }

paths <- function(object, ...) UseMethod("paths")
S7::method(paths, MediationData) <- function(...) { ... }
```

**References**:
- `planning/GENERIC-NAMING-STRATEGY.md`
- `planning/ADHD-FRIENDLY-WORKFLOW.md`

---

## Decision 3: Function Names

### Core Workflow Function: `mediate()`

**Decision**: Use `mediate()` as main workflow function

**Alternatives considered**:
- `med()`: Too ambiguous (could mean mediate/mediation/mediator/medicine)
- `fit_med()`: Not a natural verb
- `medfit()`: Noun, not verb (but acceptable alternative)
- `estimate()`: Too generic
- `fit_mediation()`: Too verbose

**Rationale**:
- Clear, unambiguous verb
- Natural language: "mediate the relationship between X and Y through M"
- Only 7 characters (3 more than `med()`)
- Familiar pattern (matches mediation::mediate)
- Pipeline-friendly

**Usage**:
```r
mediate(Y ~ X + M, M ~ X, data, treatment = "X")
```

### Bootstrap Function: `boot()`

**Decision**: Use `boot()` as custom S3 generic

**No conflict** with boot::boot() - they're separate functions in separate packages

**Rationale**:
- Short (4 characters)
- Clear purpose
- S7 method registration on OUR generic

**Usage**:
```r
boot(med_obj, n = 1000, method = "parametric")
```

### Path Extraction: `paths()`

**Decision**: Use `paths()` for mediation structure extraction

**Alternatives considered**:
- `mediation_paths()`: Too long (15 characters)
- `structure()`: Conflicts with base R
- `effects()`: Conflicts with stats::effects()
- `coef(obj, type = "paths")`: More typing

**Rationale**:
- Short (5 characters)
- Clear in mediation context
- No conflicts
- Natural complement to `coef()` (paths vs all parameters)

**Usage**:
```r
paths(med_obj)
# Returns: list(a, b, c_prime, indirect, total)
```

### Effect Extraction Functions

**Decision**: Custom generics for effect components

```r
indirect_effect(object)  # Just indirect effect (scalar)
direct_effect(object)    # Just direct effect (scalar)
total_effect(object)     # Just total effect (scalar)
```

**Rationale**:
- Convenience functions
- Clear, descriptive names
- No abbreviations (spell out "effect")

**References**: `planning/FUNCTION-NAMING-DEEP-DIVE.md`

---

## Decision 4: Standard R Generics

**Decision**: Implement standard R generics for ecosystem integration

**Must implement**:
- `confint()` - Confidence intervals (NOT `ci()`)
- `coef()` - All model parameters
- `vcov()` - Variance-covariance matrix
- `summary()` - Model summary
- `print()` - Print method
- `nobs()` - Sample size

**Should implement** (when applicable):
- `fitted()` - Fitted values
- `residuals()` - Residuals
- `predict()` - Predictions

**Future consideration**:
- `logLik()` - Log-likelihood
- `AIC()` / `BIC()` - Information criteria
- `simulate()` - Simulate from model

**Rationale**:
- Universal R standard
- Expected by users
- Required for broom, sandwich, car, lmtest, emmeans
- Ensures interoperability

**References**: `planning/GENERIC-NAMING-STRATEGY.md`

---

## Decision 5: Workflow Pattern

**Decision**: Pipeline-friendly workflow with smart defaults

**Pattern**:
```r
library(medfit)

result <- data %>%
  mediate(Y ~ X + M, M ~ X, treatment = "X") %>%
  boot() %>%
  confint()
```

**Smart defaults**:
- `mediate()`: engine = "glm"
- `boot()`: method = "parametric", n = 1000, ci_level = 0.95
- All overridable when needed

**Progressive disclosure**:
```r
# Simple (defaults)
mediate(Y ~ X + M, M ~ X, data, "X")

# Advanced (override)
mediate(Y ~ X + M, M ~ X, data, "X", engine = "gformula",
        engine_args = list(EMint = TRUE))
```

**Rationale**:
- Minimal cognitive load
- Flow state support
- 0-1 intermediate objects
- Common case optimized

**References**: `planning/ADHD-FRIENDLY-WORKFLOW.md`

---

## Decision 6: Broom Integration

**Decision**: Implement S3 methods for broom generics

**Methods to implement**:
```r
tidy.MediationData()
tidy.SerialMediationData()
tidy.BootstrapResult()
glance.MediationData()
glance.SerialMediationData()
```

**Returns**: Tidy data frames (tibbles)

**Rationale**:
- Tidy workflow integration
- Complements base generics (doesn't replace)
- Widely used in tidyverse ecosystem

**References**: `planning/GENERIC-NAMING-STRATEGY.md`

---

## Decision 7: mediationverse Loading Strategy

**Decision**: Selective loading (Option 2)

**Implementation**:
```r
library(mediationverse)
# Loads ONLY: medfit (foundation)
# Message suggests loading other packages as needed
```

**Rationale**:
- Clean namespace
- User loads only what they need
- medfit always available (foundation)
- Reduces conflicts

**References**: `planning/COORDINATION-BRAINSTORM.md`

---

## Decision 8: CMAverse Integration

**Decision**: Engine adapter pattern (post-MVP)

**Engines planned**:
- `"glm"` (internal) - VanderWeele closed-form [MVP]
- `"gformula"` (CMAverse) - G-computation [Phase 2]
- `"ipw"` (CMAverse) - Inverse probability weighting [Phase 2]
- `"tmle"` (tmle3) - Targeted learning [Future]
- `"dml"` (DoubleML) - Double machine learning [Future]

**Usage**:
```r
mediate(..., engine = "gformula", engine_args = list(EMint = TRUE))
```

**Rationale**:
- Wrap validated implementations (don't reimplement)
- CMAverse in Suggests (load on demand)
- All engines return standardized MediationData

**References**: `planning/COORDINATION-BRAINSTORM.md`

---

## Complete API Reference

### S7 Classes

```r
MediationData         # Simple mediation (X → M → Y)
SerialMediationData   # Serial mediation (X → M1 → M2 → ... → Y)
BootstrapResult       # Bootstrap inference results
```

### Custom S3 Generics (Workflow)

```r
mediate(outcome, mediator, data, treatment, ...)  # Fit/extract mediation
boot(object, n = 1000, method = "parametric", ...) # Bootstrap inference
paths(object, ...)                                 # Path coefficients
indirect_effect(object, ...)                       # Indirect effect
direct_effect(object, ...)                         # Direct effect
total_effect(object, ...)                          # Total effect
decompose_effects(object, type, ...)               # Effect decomposition
```

### Standard R Generics (Ecosystem)

```r
confint(object, ...)   # Confidence intervals
coef(object, ...)      # All coefficients
vcov(object, ...)      # Variance-covariance
summary(object, ...)   # Model summary
print(object, ...)     # Print method
nobs(object, ...)      # Sample size
fitted(object, ...)    # Fitted values
residuals(object, ...) # Residuals
```

### Broom Generics (Tidy Workflow)

```r
tidy(x, ...)    # Tidy coefficient table
glance(x, ...)  # One-row model summary
```

### Regular Functions (Internal/Legacy)

```r
fit_mediation(...)      # Verbose alternative to mediate()
extract_mediation(...)  # S7 generic for extraction
bootstrap_mediation(...)# Verbose alternative to boot()
```

---

## Implementation Roadmap

### Phase 1: Core API (Week 1)

**Priority**: High

**Tasks**:
1. Define custom S3 generics (`mediate()`, `boot()`, `paths()`)
2. Implement S7 methods on standard generics (`confint()`, `coef()`, `vcov()`)
3. Implement S7 methods on custom generics
4. Update tests

### Phase 2: Bootstrap Implementation (Week 1-2)

**Priority**: High

**Tasks**:
1. Implement `bootstrap_mediation()` (27 tests ready)
2. Implement `boot()` wrapper with smart defaults
3. Implement `confint.BootstrapResult()`
4. Test all three methods (parametric, nonparametric, plugin)

### Phase 3: Fit Implementation (Week 2)

**Priority**: High

**Tasks**:
1. Implement `fit_mediation()` (30 tests ready)
2. Implement `mediate()` wrapper with smart defaults
3. Test GLM engine
4. Add fitted/residuals methods

### Phase 4: Broom Integration (Week 3)

**Priority**: Medium

**Tasks**:
1. Implement `tidy()` methods
2. Implement `glance()` methods
3. Add tests
4. Update vignettes

### Phase 5: Documentation (Week 3-4)

**Priority**: Medium

**Tasks**:
1. Update CLAUDE.md with new API
2. Create "Quick Start" vignette
3. Create "medfit and the R Ecosystem" vignette
4. Update README with examples
5. Update function documentation

### Phase 6: CMAverse Integration (Post-MVP)

**Priority**: Low (future)

**Tasks**:
1. Design engine adapter interface
2. Implement gformula adapter
3. Implement ipw adapter
4. Add tests
5. Document

---

## Testing Strategy

### Unit Tests

**Coverage target**: >90%

**Test files**:
- `test-classes.R` - S7 class validation ✅ (87 tests PASS)
- `test-extract-lm.R` - lm/glm extraction ✅ (57 tests PASS)
- `test-extract-lavaan.R` - lavaan extraction ✅ (40 tests PASS)
- `test-bootstrap.R` - Bootstrap methods (27 tests ready, SKIP)
- `test-fit-glm.R` - GLM fitting (30 tests ready, SKIP)
- `test-methods-standard.R` - Standard generics (NEW)
- `test-methods-custom.R` - Custom generics (NEW)
- `test-methods-broom.R` - Broom integration (NEW)

### Integration Tests

**Priority**: High

**Test scenarios**:
1. Complete workflow: `mediate() %>% boot() %>% confint()`
2. Broom workflow: `mediate() %>% tidy()`
3. Sandwich integration: `vcovHC(med_obj)`
4. Cross-package: probmed using medfit

---

## Documentation Standards

### Function Documentation

**Required sections**:
- `@description` - Brief summary
- `@param` - All parameters with types
- `@return` - Return value with class
- `@details` - Extended explanation
- `@examples` - Working examples
- `@seealso` - Related functions
- `@export` - Export directive

### Vignettes

**Required vignettes**:
1. "Quick Start with medfit" - 5-minute intro
2. "medfit and the R Ecosystem" - Integration guide
3. "Mediation-Specific Operations" - paths(), effects, decomposition

**Optional vignettes**:
1. "Comparison with mediation package"
2. "Extending medfit"
3. "Advanced: Engine Adapters"

---

## Success Metrics

### Technical

- [ ] All 241 tests passing
- [ ] R CMD check clean (0 errors, 0 warnings, 0 notes)
- [ ] >90% code coverage
- [ ] pkgdown site builds successfully

### User Experience

- [ ] Simple workflow requires ≤4 arguments
- [ ] Pipeline example in README
- [ ] Clear error messages with suggestions
- [ ] Tab completion works for all generics

### Ecosystem

- [ ] Works with broom (`tidy()`, `glance()`)
- [ ] Works with sandwich (`vcovHC()`)
- [ ] Works with car, lmtest
- [ ] probmed integration successful

---

## Open Questions

### Resolved

1. ✅ S7 vs S3 vs S4? → **S7**
2. ✅ Standard vs custom generics? → **Hybrid**
3. ✅ `confint()` vs `ci()`? → **`confint()`**
4. ✅ `med()` vs `mediate()`? → **`mediate()`**
5. ✅ Keep `paths()`? → **Yes**
6. ✅ Namespace conflicts? → **No conflicts (S7 + custom S3 generics)**

### Pending User Feedback

1. ⏳ `mediate()` vs `medfit()` - which feels more natural?
2. ⏳ Ready to implement or more brainstorming?

---

## References

### Planning Documents

1. `COORDINATION-BRAINSTORM.md` - Ecosystem coordination
2. `GENERIC-FUNCTIONS-RESEARCH.md` - S3/S4/S7 comparison
3. `GENERIC-NAMING-STRATEGY.md` - Standard vs custom generics
4. `ADHD-FRIENDLY-WORKFLOW.md` - Workflow alternatives
5. `FUNCTION-NAMING-DEEP-DIVE.md` - Function naming analysis
6. `API-DESIGN-DECISIONS.md` - This document

### External References

- S7 documentation: https://rconsortium.github.io/S7/
- lavaan package (hybrid approach): https://lavaan.ugent.be/
- broom package: https://broom.tidymodels.org/
- mediation package: https://cran.r-project.org/package=mediation

---

## Next Steps

1. **User feedback** on final API design
2. **Implement Phase 1** (core API)
3. **Implement Phase 2-3** (bootstrap + fit)
4. **Documentation** (vignettes, README)
5. **Integration testing** (probmed, broom)
6. **Tag v0.1.0** release

---

**Last Updated**: 2025-12-15
**Status**: Strategic planning complete, ready for implementation
**Next Review**: After Phase 1 implementation
