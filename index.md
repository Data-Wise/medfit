# medfit: Infrastructure for Mediation Analysis in R ![R-CMD-check](https://github.com/data-wise/medfit/actions/workflows/R-CMD-check.yaml/badge.svg)![Codecov](https://codecov.io/gh/data-wise/medfit/graph/badge.svg)![Lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg)![Status](https://www.repostatus.org/badges/latest/wip.svg)

## Overview

**medfit** provides unified S7-based infrastructure for fitting
mediation models, extracting path coefficients, and performing bootstrap
inference. It serves as the foundation package for the mediation
analysis ecosystem, supporting
[probmed](https://github.com/data-wise/probmed),
[RMediation](https://github.com/data-wise/rmediation), and
[medrobust](https://github.com/data-wise/medrobust).

### Key Features

- **Unified Model Extraction**: Extract mediation structure from various
  model types (lm, glm, lavaan, OpenMx)
- **Flexible Model Fitting**: Fit mediation models using different
  engines (GLM, with future support for mixed models and Bayesian
  methods)
- **Robust Bootstrap Inference**: Three bootstrap methods (parametric,
  nonparametric, plugin) with parallel processing support
- **Type-Safe S7 Classes**: Modern object-oriented design ensuring data
  integrity
- **Ecosystem Foundation**: Shared infrastructure eliminating redundancy
  across mediation packages

## Installation

You can install the development version of medfit from GitHub:

``` r
# install.packages("pak")
pak::pak("data-wise/medfit")
```

Or using remotes:

``` r
# install.packages("remotes")
remotes::install_github("data-wise/medfit")
```

## Quick Start

### Extract Mediation Structure from Fitted Models

``` r
library(medfit)

# Simulate data
set.seed(123)
n <- 200
X <- rnorm(n)
M <- 0.5 * X + rnorm(n)
Y <- 0.3 * M + 0.2 * X + rnorm(n)
data <- data.frame(X = X, M = M, Y = Y)

# Fit models
fit_m <- lm(M ~ X, data = data)
fit_y <- lm(Y ~ X + M, data = data)

# Extract mediation structure
med_data <- extract_mediation(
  fit_m,
  model_y = fit_y,
  treatment = "X",
  mediator = "M"
)

print(med_data)
```

### Fit Mediation Models Directly

``` r
# Coming soon: fit_mediation() for direct model fitting
med_data <- fit_mediation(
  formula_y = Y ~ X + M,
  formula_m = M ~ X,
  data = data,
  treatment = "X",
  mediator = "M",
  engine = "glm"
)
```

### Bootstrap Inference

``` r
# Coming soon: bootstrap_mediation() for inference
result <- bootstrap_mediation(
  statistic_fn = function(theta) theta["a"] * theta["b"],
  method = "parametric",
  mediation_data = med_data,
  n_boot = 5000,
  ci_level = 0.95,
  seed = 12345
)

print(result)
```

## Core Components

### S7 Classes

- **`MediationData`**: Standardized container for mediation model
  structure
  - Path coefficients (a, b, c’)
  - Parameter estimates and variance-covariance matrix
  - Residual variances (for Gaussian models)
  - Variable names and metadata
- **`BootstrapResult`**: Container for bootstrap inference results
  - Point estimates and confidence intervals
  - Bootstrap distribution
  - Method metadata

### Main Functions

- **[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)**:
  Extract mediation structure from fitted models
  - Methods for: lm, glm, lavaan (OpenMx coming soon)
- **[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)**:
  Fit mediation models with formula interface
  - Engines: GLM (lmer, brms coming soon)
- **[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)**:
  Perform bootstrap inference
  - Methods: parametric, nonparametric, plugin
  - Parallel processing support

## Package Ecosystem

medfit is the foundation for three specialized mediation packages:

                        ┌─────────────┐
                        │   medfit    │
                        │ (Foundation)│
                        └──────┬──────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
          ┌─────▼─────┐  ┌────▼────┐  ┌──────▼──────┐
          │  probmed  │  │RMediation│  │  medrobust  │
          │   (P_med) │  │(DOP,MBCO)│  │(Sensitivity)│
          └───────────┘  └─────────┘  └─────────────┘

- **[probmed](https://github.com/data-wise/probmed)**: Probabilistic
  effect size (P_med)
- **[RMediation](https://github.com/data-wise/rmediation)**: Confidence
  intervals via Distribution of Product
- **[medrobust](https://github.com/data-wise/medrobust)**: Sensitivity
  analysis for unmeasured confounding

## Development Status

**Current Phase**: MVP Development (Phase 2 Complete)

Phase 1: Package setup

Phase 2: S7 class architecture

Phase 3: Model extraction (in progress)

Phase 4: Model fitting

Phase 5: Bootstrap infrastructure

Phase 6: Testing & documentation

Phase 7: Polish & release

See
[planning/medfit-roadmap.md](https://data-wise.github.io/medfit/planning/medfit-roadmap.md)
for detailed development plan.

## Contributing

This package is in active development. Contributions are welcome!
Please:

1.  Fork the repository
2.  Create a feature branch from `dev`
3.  Make your changes with tests
4.  Submit a pull request to `dev`

## Code of Conduct

Please note that the medfit project is released with a [Contributor Code
of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.

## License

GPL (\>= 3)

## Citation

If you use medfit in your research, please cite:

    Tofighi, D. (2025). medfit: Infrastructure for mediation analysis in R.
    R package version 0.1.0. https://github.com/data-wise/medfit

## Related Resources

- [Package Documentation](https://data-wise.github.io/medfit/)
- [Development Guide](https://data-wise.github.io/medfit/CLAUDE.md)
- [Roadmap](https://data-wise.github.io/medfit/planning/medfit-roadmap.md)
- [Ecosystem
  Strategy](https://data-wise.github.io/medfit/planning/ECOSYSTEM.md)

## Contact

- **Author**: Davood Tofighi
- **Email**: <dtofighi@gmail.com>
- **ORCID**:
  [0000-0001-8523-7776](https://orcid.org/0000-0001-8523-7776)
- **Issues**: [GitHub
  Issues](https://github.com/data-wise/medfit/issues)
