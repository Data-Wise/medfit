# medfit: Infrastructure for Mediation Analysis in R

[![CRAN status](https://www.r-pkg.org/badges/version/medfit)](https://CRAN.R-project.org/package=medfit)
[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![R-CMD-check](https://github.com/Data-Wise/medfit/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Data-Wise/medfit/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/Data-Wise/medfit/graph/badge.svg)](https://app.codecov.io/gh/Data-Wise/medfit)
[![pkgdown](https://github.com/Data-Wise/medfit/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/Data-Wise/medfit/actions/workflows/pkgdown.yaml)

<!-- badges: start -->
[![r-universe](https://data-wise.r-universe.dev/badges/medfit)](https://data-wise.r-universe.dev/medfit)
<!-- badges: end -->

## Overview

**medfit** provides unified S7-based infrastructure for fitting mediation models, extracting path coefficients, and performing bootstrap inference. It serves as the foundation package for the mediation analysis ecosystem, supporting [RMediation](https://github.com/data-wise/rmediation) and [mediationverse](https://github.com/data-wise/mediationverse).

### Key Features

- **ADHD-Friendly API**: Simple `med()` function for quick mediation analysis, `quick()` for instant results
- **Mediation Structures**: simple, serial, and parallel mediators; a treatment-by-mediator interaction with VanderWeele's four-way decomposition (`decompose()`); and joint natural effects of several mediators with treatment-by-mediator products (`joint_effects()`)
- **Effect Extractors**: `nie()`, `nde()`, `te()`, `pm()`, `paths()` for extracting mediation effects
- **Tidyverse Integration**: `tidy()` and `glance()` methods, with delta-method standard errors for the effects
- **Unified Model Extraction**: Extract mediation structure from lm, glm, and lavaan fits
- **Flexible Model Fitting**: `fit_mediation()` with the `glm` and `regmedint` engines, optional case weights (IPW), and sandwich (HC3) standard errors
- **Bundled Example Data**: `mediation_demo`, a simulated dataset for every workflow
- **Robust Bootstrap Inference**: Three bootstrap methods (parametric, nonparametric, plugin) with parallel processing
- **Type-Safe S7 Classes**: Modern object-oriented design with `coef()`, `vcov()`, `confint()`, `nobs()` methods

## Installation

Install the stable version from CRAN:

```r
install.packages("medfit")
```

> **Known issues in CRAN 0.3.2:** serial `te()`/`pm()` omit paths that skip a
> mediator, and `confint()` path intervals can use the wrong covariance rows.
> Both are fixed in the development version; see
> [#83](https://github.com/Data-Wise/medfit/issues/83) for details and workarounds.

Or install the development version from GitHub:

```r
# install.packages("pak")
pak::pak("data-wise/medfit")
```

Or from the [Data-Wise r-universe](https://data-wise.r-universe.dev/medfit)
(pre-built binaries — no compiler needed):

```r
install.packages(
  "medfit",
  repos = c("https://data-wise.r-universe.dev", "https://cloud.r-project.org")
)
```

## Quick Start

### The Simplest Way: `med()` + `quick()`

```r
library(medfit)

# Simulate data
set.seed(123)
n <- 200
mydata <- data.frame(X = rnorm(n))
mydata$M <- 0.5 * mydata$X + rnorm(n)
mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

# Run mediation analysis in one line
result <- med(
  data = mydata,
  treatment = "X",
  mediator = "M",
  outcome = "Y"
)

# One-line summary
quick(result)
#> NIE = 0.164  | NDE = 0.293 | PM = 36 %
```

### Extract Effects

```r
# Individual effect extractors
nie(result)   # Natural Indirect Effect (a * b)
nde(result)   # Natural Direct Effect (c')
te(result)    # Total Effect (nie + nde)
pm(result)    # Proportion Mediated
paths(result) # All path coefficients (a, b, c')
```

### Tidyverse Integration

```r
library(generics)

# Tidy tibble of all effects
tidy(result)
#> # A tibble: 6 × 3
#>   term    estimate std.error
#>   <chr>      <dbl>     <dbl>
#> 1 a          0.471    0.0750
#> 2 b          0.349    0.0689
#> 3 c_prime    0.293    0.0797
#> 4 nie        0.164    0.0417
#> 5 nde        0.293    0.0797
#> 6 te         0.457    0.0773

# One-row model summary
glance(result)
#> # A tibble: 1 × 6
#>     nie   nde    te    pm  nobs converged
#>   <dbl> <dbl> <dbl> <dbl> <int> <lgl>
#> 1 0.164 0.293 0.457 0.360   200 TRUE
```

### Base R Methods

```r
coef(result)              # Path coefficients
coef(result, "effects")   # NIE, NDE, TE
vcov(result)              # Variance-covariance matrix
confint(result)           # 95% confidence intervals
nobs(result)              # Number of observations
```

### Bootstrap Inference

```r
# With bootstrap CI
result_boot <- med(
  data = mydata,
  treatment = "X",
  mediator = "M",
  outcome = "Y",
  boot = TRUE,
  n_boot = 1000,
  seed = 42
)

quick(result_boot)
#> NIE = 0.19 [0.08, 0.32] | NDE = 0.16 | PM = 55%
```

### Advanced: Extract from Fitted Models

```r
# If you already have fitted models
fit_m <- lm(M ~ X, data = mydata)
fit_y <- lm(Y ~ X + M, data = mydata)

med_data <- extract_mediation(
  fit_m,
  model_y = fit_y,
  treatment = "X",
  mediator = "M"
)

# Same extractors work
nie(med_data)
tidy(med_data)
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
  - `nie()` gives the chain effect; `nie(type = "total")`, `te()` and `pm()` count every path, including paths that skip a mediator
  - Flexible design compatible with lavaan extraction patterns
  - Extensible to complex mediation structures

- **`ParallelMediationData`**: Container for parallel mediators (indirect effect = sum of a_j * b_j)

- **`InteractionMediationData`**: Simple mediation with a treatment-by-mediator interaction, carrying the four-way decomposition (CDE, INTref, INTmed, PIE)

- **`JointMediationData`**: Joint natural effects of two or more mediators when the outcome model has treatment-by-mediator products

- **`BootstrapResult`**: Container for bootstrap inference results
  - Point estimates and confidence intervals
  - Bootstrap distribution
  - Method metadata

### Main Functions

**Quick Start:**
- **`med()`**: One-function mediation analysis (recommended starting point)
- **`quick()`**: One-line summary of results

**Effect Extractors:**
- **`nie()`**, **`nde()`**, **`te()`**: Natural indirect/direct and total effects
- **`pm()`**: Proportion mediated
- **`paths()`**: All path coefficients
- **`decompose()`**: Four-way or joint decomposition of the total effect
- **`joint_effects()`**: Joint effects at any parameter vector (for bootstrapping)

**Tidyverse Methods:**
- **`tidy()`**: Convert results to tidy tibble
- **`glance()`**: One-row model summary

**Base R Methods:**
- **`coef()`**, **`vcov()`**, **`confint()`**, **`nobs()`**: Standard generics

**Advanced:**
- **`extract_mediation()`**: Extract from fitted lm/glm/lavaan models
- **`fit_mediation()`**: Fit with formula interface (`glm` or `regmedint` engine)
- **`bootstrap_mediation()`**: Bootstrap inference (parametric, nonparametric, plugin)

## Mediationverse Ecosystem

medfit is the foundation for the **mediationverse** ecosystem:

| Package | Purpose | Role |
|---------|---------|------|
| **medfit** (this) | Model fitting, extraction, bootstrap | Foundation |
| [RMediation](https://github.com/data-wise/rmediation) | Confidence intervals (DOP, MBCO) | Application |
| [probmed](https://github.com/data-wise/probmed) | Probabilistic effect size (P_med) | Application |
| [medrobust](https://github.com/data-wise/medrobust) | Sensitivity analysis | Application (independent of medfit) |
| [medsim](https://github.com/data-wise/medsim) | Simulation infrastructure | Support |
| [mediationverse](https://github.com/data-wise/mediationverse) | Meta-package | Ecosystem |

See [Ecosystem Coordination](https://github.com/data-wise/medfit/blob/main/planning/ECOSYSTEM.md) for version compatibility and development guidelines.

## Documentation

Comprehensive articles are available on the package website:

- **[Get Started](https://data-wise.github.io/medfit/articles/getting-started.html)**: Quick introduction to medfit
- **[Introduction](https://data-wise.github.io/medfit/articles/introduction.html)**: Detailed S7 class documentation
- **[Model Extraction](https://data-wise.github.io/medfit/articles/extraction.html)**: Extract from lm/glm/lavaan models
- **[Bootstrap Inference](https://data-wise.github.io/medfit/articles/bootstrap.html)**: Parametric and nonparametric bootstrap methods
- **[Methods and Formulas](https://data-wise.github.io/medfit/articles/methods.html)**: Estimands, formulas, covariance, and standard errors for every class

## Development Status

medfit is on CRAN. Current development adds mediation structures and inference
on the `dev` branch; see `NEWS.md` for what each release contains.

### Code Quality

- **Defensive Programming**: checkmate for input validation, S7 validators for class integrity
- **Testing**: 1,400+ tests with testthat (>90% coverage, enforced via codecov)
- **CI/CD**: R CMD check, lintr, coverage reporting via GitHub Actions

See the [roadmap](https://github.com/data-wise/medfit/blob/main/planning/medfit-roadmap.md) for the detailed development plan.

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
Tofighi, D. (2026). medfit: Infrastructure for mediation analysis in R.
R package version 0.4.0. https://CRAN.R-project.org/package=medfit
```

For the entry matching your installed version, run `citation("medfit")`.

## Related Resources

- [Package Documentation](https://data-wise.github.io/medfit/)
- [Development Guide](https://github.com/data-wise/medfit/blob/main/CLAUDE.md)
- [Roadmap](https://github.com/data-wise/medfit/blob/main/planning/medfit-roadmap.md)
- [Ecosystem Strategy](https://github.com/data-wise/medfit/blob/main/planning/ECOSYSTEM.md)

## Contact

- **Author**: Davood Tofighi
- **Email**: dtofighi@gmail.com
- **ORCID**: [0000-0001-8523-7776](https://orcid.org/0000-0001-8523-7776)
- **Issues**: [GitHub Issues](https://github.com/data-wise/medfit/issues)
