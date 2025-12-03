# Fit Mediation Models

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

  Character string: modeling engine to use. Options:

  - `"glm"`: Generalized linear models (current)

  - `"lmer"`: Mixed-effects models (future)

  - `"brms"`: Bayesian regression models (future)

- family_y:

  Family object for outcome model (default:
  [`gaussian()`](https://rdrr.io/r/stats/family.html))

- family_m:

  Family object for mediator model (default:
  [`gaussian()`](https://rdrr.io/r/stats/family.html))

- ...:

  Additional arguments passed to the engine-specific function

## Value

A
[MediationData](https://data-wise.github.io/medfit/reference/MediationData.md)
object containing the fitted mediation structure

## Details

The `fit_mediation()` function fits both the mediator model and outcome
model using the specified engine, then extracts the mediation structure
using
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md).

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

## See also

[MediationData](https://data-wise.github.io/medfit/reference/MediationData.md),
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md),
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)

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
```
