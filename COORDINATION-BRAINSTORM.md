# mediationverse Coordination Brainstorming

**Date**: 2025-12-15 **Context**: medfit MVP nearing completion, need to
coordinate integration with mediationverse ecosystem **Decision Made**:
medfit is the foundation package (per
three-package-ecosystem-strategy.md, Dec 2, 2025)

------------------------------------------------------------------------

## 🎯 Executive Summary

**Strategic Decision Already Made**: Create medfit as foundation package
providing: - Model fitting API:
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md) -
Model extraction API:
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) -
Bootstrap infrastructure:
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md) -
S7 base classes: `MediationData`, `SerialMediationData`,
`BootstrapResult`

**This Document**: Implementation coordination mechanics for
mediationverse loading, generic functions, and CMAverse integration.

------------------------------------------------------------------------

## 📋 Findings from Strategic Planning Documents

### Key Document: `probmed/planning/three-package-ecosystem-strategy.md`

**Date**: Dec 2, 2025 **Decision**: Option B (medfit) ✅ DECIDED

**Current Redundancies Identified**: - Bootstrap code duplicated 3x
(probmed, RMediation, medrobust) - lavaan extraction duplicated 2x
(probmed, RMediation) - S7 class definitions duplicated across
packages - Formula parsing logic duplicated

**Solution Architecture**:

    medfit (foundation package)
    ├── fit_mediation()      # Formula interface
    ├── extract_mediation()  # Generic with lm/glm/lavaan methods
    ├── bootstrap_mediation() # Three methods (parametric/nonparametric/plugin)
    └── S7 Classes           # MediationData, SerialMediationData, BootstrapResult
        ↓ Imports
    probmed | RMediation | medrobust

**Migration Strategy**: 1. Complete medfit MVP (current sprint) 2.
probmed migrates to medfit (next sprint) 3. RMediation migrates to
medfit (following sprint) 4. medrobust integrates optionally (parallel
track)

------------------------------------------------------------------------

## 🔧 Generic Functions Strategy

### Core Generics (medfit provides)

#### 1. `extract_mediation()` - Model Extraction Generic

**Purpose**: Extract path coefficients and covariance matrices from
fitted models

**Current Methods** (medfit MVP): - `extract_mediation.lm()` -
`extract_mediation.glm()` - `extract_mediation.lavaan()`

**Planned Methods** (post-MVP): - `extract_mediation.lmerMod()` - Mixed
models - `extract_mediation.brmsfit()` - Bayesian models -
`extract_mediation.stanreg()` - rstanarm models

**Design Pattern**:

``` r
# Generic signature
extract_mediation <- S7::new_generic(
  "extract_mediation",
  dispatch_args = "object"
)

# Each method returns standardized MediationData
S7::method(extract_mediation, class_lm) <- function(
  object,
  model_y,
  treatment,
  mediator,
  ...
) {
  # Extract parameters
  # Return MediationData object
}
```

**Coordination Point**: All packages use this generic, add methods as
needed

------------------------------------------------------------------------

#### 2. `fit_mediation()` - Model Fitting Generic

**Purpose**: Fit mediation models from formulas

**Current Implementation**:

``` r
fit_mediation(
  formula_y = Y ~ X + M + C,
  formula_m = M ~ X + C,
  data = data,
  treatment = "X",
  mediator = "M",
  engine = "glm",       # Default
  engine_args = list()
)
```

**Engine Architecture** (CMAverse Integration):

| Engine       | Package      | Method                 | Status     | Priority |
|--------------|--------------|------------------------|------------|----------|
| `"glm"`      | stats (base) | Regression             | ✅ MVP     | P0       |
| `"gformula"` | CMAverse     | G-computation          | 🔮 Planned | P1       |
| `"ipw"`      | CMAverse     | Inverse prob weighting | 🔮 Planned | P1       |
| `"tmle"`     | tmle3        | Targeted learning      | 🔮 Future  | P2       |
| `"dml"`      | DoubleML     | Double ML              | 🔮 Future  | P3       |

**CMAverse Integration Pattern**:

``` r
# User interface
result <- fit_mediation(
  ...,
  engine = "gformula",
  engine_args = list(
    EMint = TRUE,        # Exposure-mediator interaction
    mreg = "linear",     # Mediator regression type
    yreg = "linear",     # Outcome regression type
    nboot = 500          # CMAverse-specific bootstrap
  )
)

# Internal adapter (simplified)
.fit_mediation_gformula <- function(formula_y, formula_m, data,
                                     treatment, mediator,
                                     engine_args) {
  # Check CMAverse available
  if (!requireNamespace("CMAverse", quietly = TRUE)) {
    stop("CMAverse required for gformula engine")
  }

  # Call CMAverse::cmest()
  cma_result <- CMAverse::cmest(
    data = data,
    model = "gformula",
    outcome = all.vars(formula_y)[1],
    exposure = treatment,
    mediator = mediator,
    EMint = engine_args$EMint %||% FALSE,
    # ... more CMAverse arguments
  )

  # Extract to standardized MediationData
  MediationData(
    a_path = cma_result$effect.pe["a"],
    b_path = cma_result$effect.pe["b"],
    # ... extract all components
  )
}
```

**Coordination Point**: - medfit provides adapter infrastructure -
CMAverse in `Suggests`, not `Imports` - Each engine adapter is
self-contained function - All engines return `MediationData`

------------------------------------------------------------------------

#### 3. `bootstrap_mediation()` - Bootstrap Inference Generic

**Purpose**: Compute bootstrap CIs for indirect effects

**Current Methods**:

``` r
bootstrap_mediation(
  object,              # MediationData object
  statistic = indirect_effect,  # Function: MediationData -> scalar
  method = "parametric",         # or "nonparametric", "plugin"
  n_boot = 1000,
  ci_level = 0.95,
  parallel = FALSE,
  seed = NULL
)
```

**Statistic Functions** (helper-test-data.R pattern):

``` r
# Indirect effect (default)
indirect_effect <- function(med_data) {
  med_data@a_path * med_data@b_path
}

# Total effect
total_effect <- function(med_data) {
  med_data@a_path * med_data@b_path + med_data@c_prime
}

# Proportion mediated
proportion_mediated <- function(med_data) {
  indirect <- med_data@a_path * med_data@b_path
  total <- indirect + med_data@c_prime
  indirect / total
}
```

**Coordination Point**: probmed/RMediation can provide custom statistic
functions for P_med/DOP/MBCO

------------------------------------------------------------------------

## 🌐 mediationverse Loading Coordination

### Current mediationverse Structure

From `mediationverse/R/attach.R`:

``` r
core <- c("medfit", "probmed", "RMediation", "medrobust", "medsim")

# Startup message shows:
# - Package versions
# - Conflicts
```

### Proposed Loading Strategy

#### Option 1: Load All Packages (tidyverse pattern)

``` r
library(mediationverse)
# Attaches: medfit, probmed, RMediation, medrobust, medsim
# Message:
# ── Attaching mediationverse 0.1.0 ──────────────────
# ✔ medfit     0.1.0     ✔ probmed    0.2.0
# ✔ RMediation 2.1.0     ✔ medrobust  0.1.0
# ✔ medsim     1.0.0
# ── Conflicts ───────────────────────────────────────
# ✖ medfit::fit_mediation() masks probmed::fit_mediation()
```

**Pros**: - Convenient for users - Full ecosystem available

**Cons**: - Loads packages user may not need - Potential namespace
conflicts

------------------------------------------------------------------------

#### Option 2: Selective Loading (recommended)

``` r
library(mediationverse)
# Attaches ONLY: medfit (foundation always loaded)
# Message:
# ── Attaching mediationverse 0.1.0 ──────────────────
# ✔ medfit 0.1.0 (foundation package)
# ℹ Use library(probmed) for P_med effect size
# ℹ Use library(RMediation) for DOP/MBCO inference
# ℹ Use library(medrobust) for sensitivity analysis
# ℹ Use library(medsim) for simulation utilities
```

**Implementation**:

``` r
# mediationverse/R/attach.R
.onAttach <- function(libname, pkgname) {
  # Only attach medfit by default
  require(medfit, quietly = TRUE)

  packageStartupMessage(
    "── Attaching mediationverse ", utils::packageVersion("mediationverse"), " ──\n",
    "✔ medfit ", utils::packageVersion("medfit"), " (foundation package)\n",
    "ℹ Use library(probmed) for P_med effect size\n",
    "ℹ Use library(RMediation) for DOP/MBCO inference\n",
    "ℹ Use library(medrobust) for sensitivity analysis\n",
    "ℹ Use library(medsim) for simulation utilities\n"
  )
}
```

**Pros**: - Clean namespace - User loads only what they need - medfit
always available (foundation)

**Cons**: - Requires explicit library() calls for other packages

------------------------------------------------------------------------

#### Option 3: Hybrid (tidyverse::tidyverse_packages() pattern)

``` r
library(mediationverse)
# Attaches: medfit (foundation)

# User can load selectively
mediationverse_packages()
# Returns: c("medfit", "probmed", "RMediation", "medrobust", "medsim")

# Or load all
mediationverse_load_all()
# Attaches all packages
```

**Pros**: Flexibility, clear default, opt-in for full load **Cons**:
More complex API

------------------------------------------------------------------------

### Recommended: Option 2 (Selective Loading)

**Rationale**: - medfit is foundation, always needed - Other packages
serve different use cases - User typically needs 1-2 packages per
analysis - Clean namespace reduces conflicts

------------------------------------------------------------------------

## 🔀 Package Integration Workflows

### Workflow 1: probmed Integration

**Before medfit**:

``` r
library(probmed)

# probmed had its own extraction
fit_m <- lm(M ~ X, data = data)
fit_y <- lm(Y ~ X + M, data = data)
result <- compute_pmed(fit_m, fit_y, treatment = "X", mediator = "M")
```

**After medfit**:

``` r
library(mediationverse)  # Loads medfit
library(probmed)

# probmed uses medfit extraction
med_data <- medfit::extract_mediation(
  fit_m, model_y = fit_y,
  treatment = "X", mediator = "M"
)
result <- probmed::compute_pmed(med_data)

# Or, probmed wrapper maintains backward compatibility
result <- probmed::compute_pmed(fit_m, fit_y, treatment = "X", mediator = "M")
# Internally calls medfit::extract_mediation()
```

**Migration Strategy**: 1. probmed adds `medfit` to Imports 2. probmed
keeps formula interface, calls medfit internally 3. probmed removes
duplicated extraction code 4. probmed adds `compute_pmed.MediationData`
method 5. Backward compatibility maintained

------------------------------------------------------------------------

### Workflow 2: RMediation Integration

**Before medfit**:

``` r
library(RMediation)

# RMediation had its own extraction (from lavaan)
fit <- lavaan::sem(model, data = data)
result <- medci(fit, type = "dop")
```

**After medfit**:

``` r
library(mediationverse)
library(RMediation)

# RMediation uses medfit extraction
med_data <- medfit::extract_mediation(fit, treatment = "X", mediator = "M")
result <- RMediation::medci(med_data, type = "dop")

# Or, RMediation wrapper maintains backward compatibility
result <- RMediation::medci(fit, type = "dop")
# Internally calls medfit::extract_mediation()
```

------------------------------------------------------------------------

### Workflow 3: medrobust Integration

**medrobust uses medfit optionally**:

``` r
library(mediationverse)
library(medrobust)

# medrobust can compute naive estimate via medfit
naive <- medfit::fit_mediation(
  formula_y = Y ~ X + M,
  formula_m = M ~ X,
  data = data,
  treatment = "X",
  mediator = "M"
)

# Then sensitivity bounds
bounds <- medrobust::sensitivity_bounds(
  naive = naive,
  rho_range = c(-0.5, 0.5)
)
```

**medrobust doesn’t require medfit**, but can use it for convenience.

------------------------------------------------------------------------

## 🗓️ Implementation Timeline

### Phase 1: medfit MVP (This Week, Dec 15-21)

**Status**: 75% complete, 241 tests ready

**Remaining Tasks**: - \[ \] Implement
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
(3-4 hr, 27 tests activate) - \[ \] Implement
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
(2-3 hr, 30 tests activate) - \[ \] Roxygen2 documentation (2 hr) - \[
\] R CMD check passing (1 hr) - \[ \] Intro vignette (2 hr) - \[ \] Tag
v0.1.0

**Deliverable**: medfit v0.1.0 ready for ecosystem integration

------------------------------------------------------------------------

### Phase 2: probmed Integration (Week of Dec 22-28)

**Tasks**: 1. **Update probmed DESCRIPTION**
`Imports: medfit (>= 0.1.0), # ... existing imports`

2.  **Refactor probmed extraction**

    - Remove `probmed::extract_mediation_lm()`
    - Remove `probmed::extract_mediation_lavaan()`
    - Call
      [`medfit::extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
      instead

3.  **Add S7 method for P_med**

    ``` r
    # In probmed
    S7::method(compute_pmed, medfit::MediationData) <- function(object, ...) {
      # P_med computation using medfit structure
    }
    ```

4.  **Maintain backward compatibility**

    ``` r
    # probmed wrapper
    compute_pmed <- function(fit_m, fit_y = NULL, ...) {
      if (inherits(fit_m, "medfit::MediationData")) {
        # New path: MediationData provided
        compute_pmed.MediationData(fit_m, ...)
      } else {
        # Old path: fit objects provided, extract with medfit
        med_data <- medfit::extract_mediation(fit_m, model_y = fit_y, ...)
        compute_pmed.MediationData(med_data, ...)
      }
    }
    ```

5.  **Update probmed tests**

    - Test MediationData input
    - Test backward compatibility
    - Integration tests with medfit

6.  **Update probmed documentation**

    - Mention medfit dependency
    - Examples using medfit::extract_mediation()

**Deliverable**: probmed v0.2.0 using medfit

------------------------------------------------------------------------

### Phase 3: mediationverse Loading (Week of Dec 22-28)

**Tasks**: 1. **Update mediationverse DESCRIPTION**
`Imports: medfit (>= 0.1.0), probmed (>= 0.2.0), RMediation (>= 2.1.0), medrobust, medsim`

2.  **Implement selective loading** (Option 2)

    - Update `R/attach.R` to only attach medfit
    - Helpful startup message
    - Document in README

3.  **Add utility functions**

    ``` r
    # mediationverse/R/packages.R
    mediationverse_packages <- function() {
      c("medfit", "probmed", "RMediation", "medrobust", "medsim")
    }

    mediationverse_conflicts <- function() {
      # Show function conflicts across packages
    }
    ```

4.  **Update mediationverse README**

    - Show ecosystem architecture diagram
    - Loading strategy
    - Example workflows

**Deliverable**: mediationverse v0.1.0 meta-package functional

------------------------------------------------------------------------

### Phase 4: RMediation Integration (Week of Dec 29 - Jan 4)

**Tasks**: 1. Update RMediation to use medfit extraction (optional,
since RMediation is on CRAN) 2. Coordinate with maintainer 3. Test
integration

**Deliverable**: RMediation updated (or documented as optional
integration)

------------------------------------------------------------------------

### Phase 5: CMAverse Engine Adapters (Q1 2026)

**Post-MVP feature**: Add gformula and ipw engines

**Tasks**: 1. Design engine adapter interface 2. Implement
`.fit_mediation_gformula()` 3. Implement `.fit_mediation_ipw()` 4. Add
CMAverse to Suggests 5. Documentation and examples 6. Integration tests

**Deliverable**: medfit v0.2.0 with CMAverse support

------------------------------------------------------------------------

## 🎯 Coordination Checkpoints

### Before Releasing medfit v0.1.0

Confirm API stability with probmed team

Confirm API stability with RMediation team

Confirm API stability with medrobust team

API frozen (no breaking changes without coordination)

### Before Releasing probmed v0.2.0 (with medfit)

medfit v0.1.0 on CRAN (or at least stable)

Integration tests passing

Backward compatibility verified

NEWS.md documents migration

### Before Releasing mediationverse v0.1.0

medfit v0.1.0 available

probmed v0.2.0 available

Loading mechanism tested

README shows ecosystem architecture

All cross-package examples work

------------------------------------------------------------------------

## 📊 Success Metrics

### Technical Metrics

Code duplication reduced by \>50%

All integration tests passing

R CMD check passing for all packages

\>90% test coverage in medfit

Zero breaking changes in migration

### User Experience Metrics

Existing probmed code works without changes

Existing RMediation code works without changes

Clear migration guides available

Example workflows documented

Startup message helpful and non-intrusive

------------------------------------------------------------------------

## 🚧 Open Questions

### 1. mediationverse Loading Strategy - NEEDS DECISION

**Question**: Load all packages or just medfit?

**Options**: - A. Load all (tidyverse pattern) - B. Load only medfit
(recommended) - C. Hybrid (opt-in for all)

**Recommendation**: Option B (selective loading)

**Decision needed by**: Before mediationverse v0.1.0 release

------------------------------------------------------------------------

### 2. CMAverse Integration Priority

**Question**: Implement CMAverse engines in medfit v0.1.0 or defer to
v0.2.0?

**Options**: - A. Include in v0.1.0 (delays MVP) - B. Defer to v0.2.0
(recommended, get medfit stable first)

**Recommendation**: Option B (v0.2.0)

**Decision needed by**: medfit MVP milestone

------------------------------------------------------------------------

### 3. Breaking Changes Policy

**Question**: How to handle breaking changes in medfit after ecosystem
adoption?

**Recommendation**: - Semantic versioning (major.minor.patch) - Breaking
changes only in major versions - Deprecation warnings one version
ahead - Coordinated releases across ecosystem

**Decision needed by**: Before medfit v0.1.0 release

------------------------------------------------------------------------

### 4. CRAN Submission Order

**Question**: What order to submit to CRAN?

**Options**: - A. medfit → probmed → mediationverse - B. All
simultaneously - C. medfit alone, others later

**Recommendation**: Option A (sequential, reduces risk)

**Rationale**: - medfit must be on CRAN for others to depend on it -
probmed updates after medfit available - mediationverse releases when
all packages ready

------------------------------------------------------------------------

## 💡 Next Immediate Actions

### This Week (Dec 15-21): Complete medfit MVP

1.  **Implement core functions** (8-10 hrs total)

    - bootstrap_mediation() - 3-4 hr
    - fit_mediation() - 2-3 hr
    - Documentation - 2 hr
    - R CMD check fixes - 1 hr

2.  **Commit and push to dev branch**

3.  **Create medfit v0.1.0-alpha tag**

4.  **Notify ecosystem**

    - Create GitHub discussion in mediationverse
    - Notify probmed/RMediation/medrobust maintainers
    - Share API documentation

------------------------------------------------------------------------

### Next Week (Dec 22-28): Integration Testing

1.  **Test probmed integration** (in separate branch)
    - Update probmed DESCRIPTION
    - Refactor extraction code
    - Run tests
    - Document findings
2.  **Test mediationverse loading**
    - Implement Option 2 (selective loading)
    - Test conflicts
    - Update README
3.  **Integration test suite**
    - Cross-package workflows
    - Backward compatibility tests

------------------------------------------------------------------------

### Following Week (Dec 29 - Jan 4): Polish & Release

1.  **Address integration issues**
2.  **Finalize documentation**
3.  **Prepare CRAN submissions**
4.  **Tag releases**: medfit v0.1.0, probmed v0.2.0, mediationverse
    v0.1.0

------------------------------------------------------------------------

## 📚 Reference Documents

### Strategic Planning (Already Decided)

- `probmed/planning/three-package-ecosystem-strategy.md` - Foundation
  package decision
- `probmed/planning/model-engines-brainstorm.md` - CMAverse discussion
- `medfit/planning/medfit-roadmap.md` - Implementation plan

### Coordination Documents (This Package)

- `ECOSYSTEM-COORDINATION.md` - High-level options and decision matrix
- `COORDINATION-BRAINSTORM.md` - This document (implementation
  mechanics)
- `CLAUDE.md` - Package development guidelines
- `.STATUS` - Current progress tracking

------------------------------------------------------------------------

**Last Updated**: 2025-12-15 **Status**: Active brainstorming,
implementation starting this week **Next Review**: After medfit MVP
complete (Dec 21, 2025)
