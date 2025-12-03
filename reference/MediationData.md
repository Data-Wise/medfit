# MediationData S7 Class

S7 class containing standardized mediation model structure, including
path coefficients, parameter estimates, variance-covariance matrix, and
metadata.

## Arguments

- a_path:

  Numeric scalar: effect of treatment on mediator (a path)

- b_path:

  Numeric scalar: effect of mediator on outcome (b path)

- c_prime:

  Numeric scalar: direct effect of treatment on outcome (c' path)

- estimates:

  Numeric vector: all parameter estimates

- vcov:

  Numeric matrix: variance-covariance matrix of estimates

- sigma_m:

  Numeric scalar or NULL: residual SD for mediator model

- sigma_y:

  Numeric scalar or NULL: residual SD for outcome model

- treatment:

  Character scalar: name of treatment variable

- mediator:

  Character scalar: name of mediator variable

- outcome:

  Character scalar: name of outcome variable

- mediator_predictors:

  Character vector: predictor names in mediator model

- outcome_predictors:

  Character vector: predictor names in outcome model

- data:

  Data frame or NULL: original data

- n_obs:

  Integer scalar: number of observations

- converged:

  Logical scalar: whether models converged

- source_package:

  Character scalar: package/engine used for fitting

## Value

A MediationData S7 object

## Details

This class provides a unified container for mediation model information
extracted from various model types (lm, glm, lavaan, OpenMx, etc.). It
ensures consistency across the mediation analysis ecosystem.

The class includes comprehensive validation to ensure data integrity.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a MediationData object
med_data <- MediationData(
  a_path = 0.5,
  b_path = 0.3,
  c_prime = 0.2,
  estimates = c(0.5, 0.3, 0.2),
  vcov = diag(3) * 0.01,
  sigma_m = 1.0,
  sigma_y = 1.2,
  treatment = "X",
  mediator = "M",
  outcome = "Y",
  mediator_predictors = "X",
  outcome_predictors = c("X", "M"),
  data = NULL,
  n_obs = 100L,
  converged = TRUE,
  source_package = "stats"
)
} # }
```
