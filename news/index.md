# Changelog

## medfit (development version)

### medfit 0.1.0

**Initial development release**

#### Major Features

- **S7 Class Architecture** (Phase 2 Complete)
  - `MediationData` class for standardized mediation model structure
  - `BootstrapResult` class for bootstrap inference results
  - Comprehensive validators ensuring data integrity
  - Print, summary, and show methods for both classes
- **Generics Defined**
  - [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) -
    Extract mediation structure from fitted models
  - [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md) -
    Fit mediation models (stub)
  - [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md) -
    Bootstrap inference (stub)

#### Infrastructure

- **Testing**: 51 comprehensive tests with full coverage of S7 classes
- **CI/CD**: GitHub Actions workflows for R-CMD-check, test coverage,
  and pkgdown
- **Documentation**: Roxygen2 documentation for all exported functions
  and classes

#### Development Status

**Current Phase**: Phase 2 Complete (S7 Classes) **Next**: Phase 3
(Model Extraction)

Phase 1: Package setup

Phase 2: S7 class architecture

Phase 3: Model extraction (in progress)

Phase 4: Model fitting

Phase 5: Bootstrap infrastructure

Phase 6: Testing & documentation

Phase 7: Polish & release

#### Known Issues

- S7 method dispatch in installed package context (R CMD check) needs
  investigation
- [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  and
  [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
  are stubs awaiting implementation
- [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  methods need implementation for lm/glm, lavaan

#### Internal

- Package skeleton created with proper structure
- GitHub repository initialized with `dev` branch workflow
- pkgdown website configuration
- Comprehensive CLAUDE.md and roadmap documentation

------------------------------------------------------------------------

*This is a development version. Breaking changes may occur.*
