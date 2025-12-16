# Fit Mediation Models

Fit mediation models using a specified modeling engine. This function
provides a convenient formula-based interface for fitting both the
mediator and outcome models simultaneously.

Fit mediation models using a specified modeling engine. This function
provides a convenient formula-based interface for fitting both the
mediator and outcome models simultaneously.

## Usage

``` r
fit_mediation(
  formula_y,
  formula_m,
  data,
  treatment,
  mediator,
  engine = "glm",
  family_y = stats::gaussian(),
  family_m = stats::gaussian(),
  ...
)

fit_mediation(
  formula_y,
  formula_m,
  data,
  treatment,
  mediator,
  engine = "glm",
  family_y = stats::gaussian(),
  family_m = stats::gaussian(),
  ...
)
```

## Arguments

- formula_y:

  Formula for outcome model (e.g., `Y ~ X + M + C`)

- formula_m:

  Formula for mediator model (e.g., `M ~ X + C`)

- data:

  Data frame containing all variables

- treatment:

  Character string: name of treatment variable

- mediator:

  Character string: name of mediator variable

- engine:

  Character string: modeling engine to use. Currently supports:

  - `"glm"`: Generalized linear models (default)

- family_y:

  Family object for outcome model (default:
  [`gaussian()`](https://rdrr.io/r/stats/family.html))

- family_m:

  Family object for mediator model (default:
  [`gaussian()`](https://rdrr.io/r/stats/family.html))

- ...:

  Additional arguments passed to the fitting function

## Value

A
[MediationData](https://data-wise.github.io/medfit/dev/reference/MediationData.md)
object containing the fitted mediation structure

A
[MediationData](https://data-wise.github.io/medfit/dev/reference/MediationData.md)
object containing the fitted mediation structure

## Details

The `fit_mediation()` function fits both the mediator model and outcome
model using the specified engine, then extracts the mediation structure
using
[`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md).

### Supported Engines

**GLM** (`engine = "glm"`):

- Fits models using [`stats::glm()`](https://rdrr.io/r/stats/glm.html)

- Supports all GLM families (gaussian, binomial, poisson, etc.)

- For Gaussian models, extracts residual variances

**Future Engines**:

- `"lmer"`: Mixed-effects models via lme4

- `"brms"`: Bayesian models via brms

### Model Specification

The formulas should follow standard R formula syntax:

- `formula_m`: Mediator model (e.g., `M ~ X + C1 + C2`)

- `formula_y`: Outcome model (e.g., `Y ~ X + M + C1 + C2`)

The mediator must appear in `formula_y`, and the treatment must appear
in both formulas.

### Model Specification

The function fits two models:

1.  **Mediator model**: `formula_m` (e.g., `M ~ X + C1 + C2`)

2.  **Outcome model**: `formula_y` (e.g., `Y ~ X + M + C1 + C2`)

The treatment variable must appear in both formulas. The mediator
variable must appear in the outcome formula but NOT in the mediator
formula (as it is the response).

### GLM Engine

When `engine = "glm"` (default):

- Models are fit using
  [`stats::glm()`](https://rdrr.io/r/stats/glm.html)

- Supports all GLM families (gaussian, binomial, poisson, etc.)

- For Gaussian models, residual standard deviations are extracted

- Non-Gaussian outcomes have `sigma_y = NULL`

### Common Family Specifications

- [`gaussian()`](https://rdrr.io/r/stats/family.html): Continuous
  outcomes (default)

- [`binomial()`](https://rdrr.io/r/stats/family.html): Binary outcomes

- [`poisson()`](https://rdrr.io/r/stats/family.html): Count outcomes

- [`Gamma()`](https://rdrr.io/r/stats/family.html): Positive continuous
  outcomes

## See also

[MediationData](https://data-wise.github.io/medfit/dev/reference/MediationData.md),
[`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md),
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/dev/reference/bootstrap_mediation.md)

[MediationData](https://data-wise.github.io/medfit/dev/reference/MediationData.md),
[`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md),
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/dev/reference/bootstrap_mediation.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Fit Gaussian mediation model
med_data <- fit_mediation(
  formula_y = Y ~ X + M + C,
  formula_m = M ~ X + C,
  data = mydata,
  treatment = "X",
  mediator = "M",
  engine = "glm"
)

# Fit with binary outcome
med_data <- fit_mediation(
  formula_y = Y ~ X + M + C,
  formula_m = M ~ X + C,
  data = mydata,
  treatment = "X",
  mediator = "M",
  engine = "glm",
  family_y = binomial()
)
} # }

# Generate example data
set.seed(123)
n <- 100
mydata <- data.frame(
  X = rnorm(n),
  C = rnorm(n)
)
mydata$M <- 0.5 * mydata$X + 0.2 * mydata$C + rnorm(n)
mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + 0.1 * mydata$C + rnorm(n)

# Simple mediation with continuous variables
med_data <- fit_mediation(
  formula_y = Y ~ X + M,
  formula_m = M ~ X,
  data = mydata,
  treatment = "X",
  mediator = "M"
)
print(med_data)
#> MediationData object
#> ====================
#> 
#> Path coefficients:
#>   a (X -> M):        0.3551
#>   b (M -> Y|X):      0.3779
#>   c' (X -> Y|M):     0.2524
#>   Indirect (a*b):    0.1342
#> 
#> Variables:
#>   Treatment: X
#>   Mediator:  M
#>   Outcome:   Y
#> 
#> Model info:
#>   N observations: 100
#>   Converged:      Yes
#>   Source:         stats::glm
#> 
#> Residual SDs:
#>   Mediator model:   0.9710
#>   Outcome model:    1.0568

# With covariates
med_data_cov <- fit_mediation(
  formula_y = Y ~ X + M + C,
  formula_m = M ~ X + C,
  data = mydata,
  treatment = "X",
  mediator = "M"
)

# \donttest{
# Binary outcome (takes longer to fit)
mydata$Y_bin <- rbinom(n, 1, plogis(0.3 * mydata$X + 0.4 * mydata$M))
med_data_bin <- fit_mediation(
  formula_y = Y_bin ~ X + M,
  formula_m = M ~ X,
  data = mydata,
  treatment = "X",
  mediator = "M",
  family_y = binomial()
)
# }
```
