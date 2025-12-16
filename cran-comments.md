# CRAN Submission Comments

## medfit 0.1.0

This is the first submission of the medfit package.

### R CMD check results

0 errors | 0 warnings | 0 notes

### Test environments

* local: macOS (aarch64-apple-darwin20), R 4.4.0
* GitHub Actions:
  - macOS-latest (release)
  - windows-latest (release)
  - ubuntu-latest (release, devel, oldrel-1)

### Package Description

medfit provides S7-based infrastructure for fitting mediation models, extracting path coefficients, and performing bootstrap inference. It serves as a foundation package for the mediation analysis ecosystem (probmed, RMediation, medrobust).

### Dependencies

**Imports**: S7 (>= 0.1.0), stats, methods

**Suggests**: MASS, lavaan (>= 0.6-0), OpenMx (>= 2.13), testthat (>= 3.0.0), knitr, rmarkdown

### Notes

* This package uses S7 for modern object-oriented programming in R
* The `_R_CHECK_CODOC_S4_METHODS_` environment variable is set to `false` in CI to avoid false positive warnings from S7-generated constructors
* lavaan and OpenMx extraction methods are dynamically registered when those packages are available
* Parallel bootstrap processing is only available on Unix systems (uses mclapply)

### Downstream Dependencies

None (new package). This package is designed to be a foundation for:
- probmed: Probabilistic mediation effect size
- RMediation: Distribution of product confidence intervals
- medrobust: Sensitivity analysis for unmeasured confounding
