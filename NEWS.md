# medfit (development version)

## medfit 0.1.0

**Initial development release**

### Major Features

* **Defensive Programming Infrastructure** (NEW)
  - Added `checkmate` package for fail-fast input validation
  - All extraction functions now use `checkmate::assert_*` for argument validation
  - Provides fast (C-based), memory-efficient assertions with informative error messages
  - Complements S7 validators: checkmate for function entry, S7 for class integrity

* **Code Quality Tools** (NEW)
  - Added `.lintr` configuration for static code analysis
  - Added `lint.yaml` GitHub Action for automated linting on PRs
  - Comprehensive CLAUDE.md section on defensive programming best practices
  - 167+ tests passing with 0 errors, 0 warnings, 0 notes

* **S7 Class Architecture** (Phase 2 Complete + Extended)
  - `MediationData` class for simple mediation (X -> M -> Y)
  - **`SerialMediationData` class for serial mediation** (X -> M1 -> M2 -> ... -> Y) **NEW**
    - Supports product-of-three (2 mediators: a * d * b)
    - Extensible to product-of-k (3+ mediators: a * d21 * d32 * ... * b)
    - Flexible `d_path` design: scalar for 2 mediators, vector for 3+
    - Compatible with lavaan extraction patterns
  - `BootstrapResult` class for bootstrap inference results
  - Comprehensive validators ensuring data integrity
  - Print, summary, and show methods for all classes

* **Generics Defined**
  - `extract_mediation()` - Extract mediation structure from fitted models
  - `fit_mediation()` - Fit mediation models (stub)
  - `bootstrap_mediation()` - Bootstrap inference (stub)

### Documentation

* **Comprehensive Quarto Vignettes** (NEW)
  - **Get Started** (`vignettes/medfit.qmd`): Quick introduction with examples
  - **Introduction** (`vignettes/articles/introduction.qmd`): Detailed S7 class architecture
  - **Model Extraction** (`vignettes/articles/extraction.qmd`): Extract from lm/glm/lavaan
  - **Bootstrap Inference** (`vignettes/articles/bootstrap.qmd`): Parametric/nonparametric methods
  - All vignettes use native Quarto format with `execute:` options in YAML
  - Published at https://data-wise.github.io/medfit/

* **Roxygen2 Documentation**: Complete API documentation for all exported functions and classes
  - ASCII-compliant (replaced non-ASCII arrows and multiplication symbols)
  - Explicit `@param` tags for all S7 class properties
  - `@noRd` for S7 methods to prevent namespace export issues

### Infrastructure

* **Testing**: 184 comprehensive tests (0 errors, 0 warnings, 1 skip)
  - Full coverage of simple and serial mediation S7 classes
  - Validation tests ensure data integrity across all mediation types
  - Tests updated for checkmate error message format
  - 1 skip: cannot test lavaan-not-installed path when lavaan is installed

* **CI/CD**: GitHub Actions workflows with Quarto support
  - R-CMD-check on Ubuntu (release, devel, oldrel-1), macOS, Windows
  - `lint.yaml` for static code analysis with lintr
  - pkgdown deployment with Quarto rendering
  - Test coverage tracking with Codecov
  - Dependabot for automated GitHub Actions updates

* **pkgdown Website**: https://data-wise.github.io/medfit/
  - Bootstrap 5 with Flatly theme
  - Comprehensive reference documentation
  - Four Quarto vignettes with rich examples
  - Auto-deployment on push to main branch

### Development Status

**Current Phase**: Phase 3 Complete
**Next**: Phase 4 (Model Fitting)

* [x] Phase 1: Package setup
* [x] Phase 2: S7 class architecture (simple + serial mediation)
* [x] Phase 2.5: Comprehensive Quarto documentation
* [x] Phase 3: Model extraction (lm/glm, lavaan)
* [ ] Phase 4: Model fitting (in progress)
* [ ] Phase 5: Bootstrap infrastructure
* [ ] Phase 6: Extended testing
* [ ] Phase 7: Polish & release

### Documentation Improvements

* **S7 Class Documentation**: Added explicit `@param` tags for all class properties
* **S7 Method Documentation**: Updated to use `@noRd` to prevent namespace export issues
* **Generic Documentation**: Fixed `extract_mediation()` to only document generic parameters
* **CLAUDE.md**: Added comprehensive S7 documentation patterns section for future reference

### Fixes

* **CI Failures**: Removed OpenMx from Suggests (was failing to compile on Ubuntu oldrel-1)
  - OpenMx integration postponed to future release
  - All GitHub Actions workflows now passing
* **S7 Method Registration**: Fixed proper registration order in `.onLoad()`
  - Call `S7::S4_register()` for each class BEFORE `methods_register()`
  - Import full `methods` package (not just `@importFrom methods is`)
  - Per official S7 documentation: https://rconsortium.github.io/S7/articles/packages.html
  - SerialMediationData print/summary methods now work in installed package context
  - Removed 4 previously skipped tests (now all passing)
* **LICENSE**: Added `+ file LICENSE` to DESCRIPTION to properly reference LICENSE file
* **Codoc warnings**: Suppressed S7 constructor codoc checks with `--no-codoc` argument
  - S7-generated constructor defaults have whitespace formatting differences
  - This is a known S7/roxygen2 limitation

### Known Issues

* `fit_mediation()` and `bootstrap_mediation()` are stubs awaiting implementation

### Internal

* Package skeleton created with proper structure
* GitHub repository initialized with `dev` branch workflow
* pkgdown website configuration
* Comprehensive CLAUDE.md and roadmap documentation

---

*This is a development version. Breaking changes may occur.*
