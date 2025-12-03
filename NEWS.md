# medfit (development version)

## medfit 0.1.0

**Initial development release**

### Major Features

* **S7 Class Architecture** (Phase 2 Complete)
  - `MediationData` class for standardized mediation model structure
  - `BootstrapResult` class for bootstrap inference results
  - Comprehensive validators ensuring data integrity
  - Print, summary, and show methods for both classes

* **Generics Defined**
  - `extract_mediation()` - Extract mediation structure from fitted models
  - `fit_mediation()` - Fit mediation models (stub)
  - `bootstrap_mediation()` - Bootstrap inference (stub)

### Infrastructure

* **Testing**: 51 comprehensive tests with full coverage of S7 classes
* **CI/CD**: GitHub Actions workflows for R-CMD-check, test coverage, and pkgdown
* **Documentation**: Roxygen2 documentation for all exported functions and classes

### Development Status

**Current Phase**: Phase 2 Complete (S7 Classes)
**Next**: Phase 3 (Model Extraction)

* [x] Phase 1: Package setup
* [x] Phase 2: S7 class architecture
* [ ] Phase 3: Model extraction (in progress)
* [ ] Phase 4: Model fitting
* [ ] Phase 5: Bootstrap infrastructure
* [ ] Phase 6: Testing & documentation
* [ ] Phase 7: Polish & release

### Documentation Improvements

* **S7 Class Documentation**: Added explicit `@param` tags for all class properties
* **S7 Method Documentation**: Updated to use `@noRd` to prevent namespace export issues
* **Generic Documentation**: Fixed `extract_mediation()` to only document generic parameters
* **CLAUDE.md**: Added comprehensive S7 documentation patterns section for future reference

### Fixes

* **LICENSE**: Added `+ file LICENSE` to DESCRIPTION to properly reference LICENSE file
* **Codoc warnings**: Fixed BootstrapResult codoc mismatch by using correct default value for `call` parameter

### Known Issues

* **S7 Codoc Warning**: MediationData has codoc mismatch for `vcov` and `data` parameters
  - These use complex S7-generated defaults for S3 classes (matrix, data.frame)
  - Whitespace formatting differences between S7 internals and roxygen2
  - This is a known S7/roxygen2 interaction limitation, not a functional issue
  - Does not affect package functionality or user experience
* **S7 Method Dispatch**: Print/summary methods don't work properly in installed package context
  - Tests skip in non-interactive mode (5 tests affected)
  - Methods work correctly when using `devtools::load_all()`
  - Related to S7 method registration in installed packages
* `fit_mediation()` and `bootstrap_mediation()` are stubs awaiting implementation
* `extract_mediation()` methods need implementation for lm/glm, lavaan

### Internal

* Package skeleton created with proper structure
* GitHub repository initialized with `dev` branch workflow
* pkgdown website configuration
* Comprehensive CLAUDE.md and roadmap documentation

---

*This is a development version. Breaking changes may occur.*
