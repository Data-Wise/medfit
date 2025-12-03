# Extract Mediation Structure from Fitted Models

Generic function to extract mediation structure (a, b, c' paths and
variance-covariance matrices) from fitted models. This function provides
a unified interface for extracting mediation information from various
model types (lm, glm, lavaan, OpenMx, lmer, brms, etc.).

## Usage

``` r
extract_mediation(object, ...)
```

## Arguments

- object:

  Fitted model object (lm, glm, lavaan, OpenMx, etc.)

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

- **OpenMx**: Extract from OpenMx models

- **lmerMod**: Extract from mixed-effects models (future)

- **brmsfit**: Extract from Bayesian models (future)

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
if (FALSE) { # \dontrun{
# Extract from lm models
fit_m <- lm(M ~ X + C, data = mydata)
fit_y <- lm(Y ~ X + M + C, data = mydata)
med_data <- extract_mediation(fit_m, model_y = fit_y,
                              treatment = "X", mediator = "M")

# Extract from lavaan model
library(lavaan)
model <- "
  M ~ a*X
  Y ~ b*M + cp*X
"
fit <- sem(model, data = mydata)
med_data <- extract_mediation(fit, treatment = "X", mediator = "M")
} # }
```
