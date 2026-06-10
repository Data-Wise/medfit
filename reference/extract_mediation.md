# Extract Mediation Structure from Fitted Models

Generic function to extract mediation structure (a, b, c' paths and
variance-covariance matrices) from fitted models. This function provides
a unified interface for extracting mediation information from various
model types (lm, glm, lavaan, lmer, brms, etc.).

## Usage

``` r
extract_mediation(object, ...)
```

## Arguments

- object:

  Fitted model object (lm, glm, lavaan, etc.)

- ...:

  Additional arguments passed to methods. Common arguments include:

  - `treatment`: Character string specifying treatment variable name

  - `mediator`: Character string specifying mediator variable name

  - Method-specific arguments (see individual method documentation)

## Value

A
[MediationData](https://data-wise.github.io/medfit/reference/MediationData.md)
object containing:

- Path coefficients (a, b, c')

- Full parameter vector and variance-covariance matrix

- Residual variances (for Gaussian models)

- Variable names and metadata

- Original data (if available)

## Details

The `extract_mediation()` generic provides methods for different model
types:

- **lm/glm**: Extract from linear and generalized linear models

- **lavaan**: Extract from structural equation models

- **lmerMod**: Extract from mixed-effects models (future)

- **brmsfit**: Extract from Bayesian models (future)

Note: OpenMx extraction is planned for a future release.

All methods return a standardized
[MediationData](https://data-wise.github.io/medfit/reference/MediationData.md)
object that can be used with other medfit functions and dependent
packages (probmed, RMediation, medrobust).

## See also

[MediationData](https://data-wise.github.io/medfit/reference/MediationData.md),
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md),
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)

## Examples

``` r
# \donttest{
# Simulate data with a single mediator (X -> M -> Y)
set.seed(123)
n <- 200
X <- rnorm(n)
M <- 0.5 * X + rnorm(n)
Y <- 0.3 * M + 0.2 * X + rnorm(n)
dat <- data.frame(X = X, M = M, Y = Y)

# Extract the mediation structure from fitted lm models
fit_m <- lm(M ~ X, data = dat)
fit_y <- lm(Y ~ X + M, data = dat)
med_data <- extract_mediation(fit_m, model_y = fit_y,
                              treatment = "X", mediator = "M")
# }
```
