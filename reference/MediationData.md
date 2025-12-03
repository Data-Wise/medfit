# MediationData Class

S7 class containing standardized mediation model structure, including
path coefficients, parameter estimates, variance-covariance matrix, and
metadata.

## Usage

``` r
MediationData(
  a_path = integer(0),
  b_path = integer(0),
  c_prime = integer(0),
  estimates = integer(0),
  vcov = (function (.data) 
 {
    
    stop(sprintf("S3 class <%s> doesn't have a constructor", class[[1]]), call. =
    FALSE)
 })(),
  sigma_m = integer(0),
  sigma_y = integer(0),
  treatment = character(0),
  mediator = character(0),
  outcome = character(0),
  mediator_predictors = character(0),
  outcome_predictors = character(0),
  data = (function (.data = list(), row.names = NULL) 
 {
     if (is.null(row.names)) {

            list2DF(.data)
     }
     else {
         out <- list2DF(.data,
    length(row.names))
attr(out, "row.names") <- row.names
         out
     }

    })(),
  n_obs = integer(0),
  converged = logical(0),
  source_package = character(0)
)
```

## Details

This class provides a unified container for mediation model information
extracted from various model types (lm, glm, lavaan, OpenMx, etc.). It
ensures consistency across the mediation analysis ecosystem.

### Properties

**Core paths**:

- `a_path`: Effect of treatment on mediator (X → M)

- `b_path`: Effect of mediator on outcome controlling for treatment (M →
  Y\|X)

- `c_prime`: Direct effect of treatment on outcome (X → Y\|M)

**Parameters**:

- `estimates`: Vector of all parameter estimates

- `vcov`: Variance-covariance matrix of estimates

**Residual variances** (for Gaussian models):

- `sigma_m`: Residual standard deviation for mediator model

- `sigma_y`: Residual standard deviation for outcome model

**Variable names**:

- `treatment`: Name of treatment variable

- `mediator`: Name of mediator variable

- `outcome`: Name of outcome variable

- `mediator_predictors`: Character vector of predictors in mediator
  model

- `outcome_predictors`: Character vector of predictors in outcome model

**Data and metadata**:

- `data`: Original data frame (optional)

- `n_obs`: Number of observations

- `converged`: Logical indicating model convergence

- `source_package`: Name of package/engine used for fitting
