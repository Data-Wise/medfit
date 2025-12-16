# medfit: Infrastructure for Mediation Analysis in R

[![R-CMD-check](https://github.com/data-wise/medfit/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/data-wise/medfit/actions/workflows/R-CMD-check.yaml)
[![Codecov](https://codecov.io/gh/data-wise/medfit/graph/badge.svg)](https://codecov.io/gh/data-wise/medfit)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![Repo Status](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)

## Overview

**medfit** provides unified S7-based infrastructure for fitting mediation models, extracting path coefficients, and performing bootstrap inference. It serves as the foundation package for the mediation analysis ecosystem, supporting [probmed](https://github.com/data-wise/probmed), [RMediation](https://github.com/data-wise/rmediation), and [medrobust](https://github.com/data-wise/medrobust).

### Key Features

- **Unified Model Extraction**: Extract mediation structure from various model types (lm, glm, lavaan, OpenMx)
- **Flexible Model Fitting**: Fit mediation models using different engines (GLM, with future support for mixed models and Bayesian methods)
- **Robust Bootstrap Inference**: Three bootstrap methods (parametric, nonparametric, plugin) with parallel processing support
- **Type-Safe S7 Classes**: Modern object-oriented design ensuring data integrity
- **Ecosystem Foundation**: Shared infrastructure eliminating redundancy across mediation packages

## Installation

You can install the development version of medfit from GitHub:

```r
# install.packages("pak")
pak::pak("data-wise/medfit")
```

Or using remotes:

```r
# install.packages("remotes")
remotes::install_github("data-wise/medfit")
```

## Quick Start

### Extract Mediation Structure from Fitted Models

```r
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

```r
# Fit both mediator and outcome models with one call
med_data <- fit_mediation(
  formula_y = Y ~ X + M,
  formula_m = M ~ X,
  data = data,
  treatment = "X",
  mediator = "M"
)

print(med_data)
```

### Bootstrap Inference

```r
# Define indirect effect function using parameter names
indirect_fn <- function(theta) theta["m_X"] * theta["y_M"]

# Parametric bootstrap (fast, recommended for n > 50)
result <- bootstrap_mediation(
  statistic_fn = indirect_fn,
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

- **`MediationData`**: Standardized container for simple mediation (X -> M -> Y)
  - Path coefficients (a, b, c')
  - Parameter estimates and variance-covariance matrix
  - Residual variances (for Gaussian models)
  - Variable names and metadata

- **`SerialMediationData`**: Container for serial mediation (X -> M1 -> M2 -> ... -> Y)
  - Supports product-of-three (2 mediators) and product-of-k (3+ mediators)
  - Flexible design compatible with lavaan extraction patterns
  - Extensible to complex mediation structures

- **`BootstrapResult`**: Container for bootstrap inference results
  - Point estimates and confidence intervals
  - Bootstrap distribution
  - Method metadata

### Main Functions

- **`extract_mediation()`**: Extract mediation structure from fitted models
  - Methods for: lm, glm, lavaan (OpenMx coming soon)

- **`fit_mediation()`**: Fit mediation models with formula interface
  - Engines: GLM (lmer, brms coming soon)

- **`bootstrap_mediation()`**: Perform bootstrap inference
  - Methods: parametric, nonparametric, plugin
  - Parallel processing support

## Package Ecosystem

medfit is the foundation for three specialized mediation packages:

```
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
```

- **[probmed](https://github.com/data-wise/probmed)**: Probabilistic effect size (P_med)
- **[RMediation](https://github.com/data-wise/rmediation)**: Confidence intervals via Distribution of Product
- **[medrobust](https://github.com/data-wise/medrobust)**: Sensitivity analysis for unmeasured confounding

## Documentation

Comprehensive Quarto vignettes are available:

- **[Get Started](https://data-wise.github.io/medfit/articles/medfit.html)**: Quick introduction to medfit
- **[Introduction](https://data-wise.github.io/medfit/articles/introduction.html)**: Detailed S7 class documentation
- **[Model Extraction](https://data-wise.github.io/medfit/articles/extraction.html)**: Extract from lm/glm/lavaan models
- **[Bootstrap Inference](https://data-wise.github.io/medfit/articles/bootstrap.html)**: Parametric and nonparametric bootstrap methods

## Development Status

**Current Phase**: Extended Testing (Phase 6)

- [x] Phase 1: Package setup
- [x] Phase 2: S7 class architecture (with SerialMediationData)
- [x] Phase 2.5: Comprehensive Quarto documentation
- [x] Phase 3: Model extraction (lm/glm, lavaan)
- [x] Phase 4: Model fitting (GLM engine)
- [x] Phase 5: Bootstrap infrastructure (parametric, nonparametric, plugin)
- [ ] Phase 6: Extended testing (in progress)
- [ ] Phase 7: Polish & release

See [planning/medfit-roadmap.md](planning/medfit-roadmap.md) for detailed development plan.

## Contributing

This package is in active development. Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch from `dev`
3. Make your changes with tests
4. Submit a pull request to `dev`

## Code of Conduct

Please note that the medfit project is released with a [Contributor Code of Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html). By contributing to this project, you agree to abide by its terms.

## License

GPL (>= 3)

## Citation

If you use medfit in your research, please cite:

```
Tofighi, D. (2025). medfit: Infrastructure for mediation analysis in R.
R package version 0.1.0. https://github.com/data-wise/medfit
```

## Related Resources

- [Package Documentation](https://data-wise.github.io/medfit/)
- [Development Guide](CLAUDE.md)
- [Roadmap](planning/medfit-roadmap.md)
- [Ecosystem Strategy](planning/ECOSYSTEM.md)

## Contact

- **Author**: Davood Tofighi
- **Email**: dtofighi@gmail.com
- **ORCID**: [0000-0001-8523-7776](https://orcid.org/0000-0001-8523-7776)
- **Issues**: [GitHub Issues](https://github.com/data-wise/medfit/issues)
