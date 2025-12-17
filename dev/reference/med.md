# Simple Mediation Analysis

A simplified entry point for mediation analysis. Specify the data and
variable names, and get results with minimal configuration.

This is the recommended starting point for most mediation analyses. For
more control over model specifications, use
[`fit_mediation()`](https://data-wise.github.io/medfit/dev/reference/fit_mediation.md)
directly.

## Usage

``` r
med(
  data,
  treatment,
  mediator,
  outcome,
  covariates = NULL,
  boot = FALSE,
  n_boot = 1000L,
  seed = NULL,
  ...
)
```

## Arguments

- data:

  A data frame containing all variables

- treatment:

  Character: name of treatment (exposure) variable

- mediator:

  Character: name of mediator variable

- outcome:

  Character: name of outcome variable

- covariates:

  Character vector: names of covariates to include (optional, default:
  none)

- boot:

  Logical: compute bootstrap confidence intervals? (default: FALSE for
  speed)

- n_boot:

  Integer: number of bootstrap samples (default: 1000)

- seed:

  Integer: random seed for reproducibility (optional)

- ...:

  Additional arguments passed to
  [`fit_mediation()`](https://data-wise.github.io/medfit/dev/reference/fit_mediation.md)

## Value

A MediationData object with mediation results

## Details

`med()` is designed to be the simplest way to run a mediation analysis.
It constructs the model formulas automatically from variable names.

### Default Behavior

- Fits Gaussian (continuous) mediator and outcome models

- No covariates unless specified

- No bootstrap unless requested (use `boot = TRUE`)

### Accessing Results

After running `med()`, use:

- `nie(result)`: Natural indirect effect

- `nde(result)`: Natural direct effect

- `te(result)`: Total effect

- `pm(result)`: Proportion mediated

- `quick(result)`: One-line summary

- `summary(result)`: Detailed summary

## See also

[`fit_mediation()`](https://data-wise.github.io/medfit/dev/reference/fit_mediation.md)
for full control,
[`quick()`](https://data-wise.github.io/medfit/dev/reference/quick.md)
for instant summary,
[`nie()`](https://data-wise.github.io/medfit/dev/reference/nie.md),
[`nde()`](https://data-wise.github.io/medfit/dev/reference/nde.md),
[`te()`](https://data-wise.github.io/medfit/dev/reference/te.md),
[`pm()`](https://data-wise.github.io/medfit/dev/reference/pm.md) for
extracting effects

## Examples

``` r
# Generate example data
set.seed(123)
n <- 200
mydata <- data.frame(
  treatment = rnorm(n),
  covariate = rnorm(n)
)
mydata$mediator <- 0.5 * mydata$treatment + 0.2 * mydata$covariate + rnorm(n)
mydata$outcome <- 0.3 * mydata$treatment + 0.4 * mydata$mediator +
                  0.1 * mydata$covariate + rnorm(n)

# Simple mediation (no covariates)
result <- med(
  data = mydata,
  treatment = "treatment",
  mediator = "mediator",
  outcome = "outcome"
)
print(result)
#> MediationData object
#> ====================
#> 
#> Path coefficients:
#>   a (X -> M):        0.4632
#>   b (M -> Y|X):      0.4644
#>   c' (X -> Y|M):     0.2168
#>   Indirect (a*b):    0.2151
#> 
#> Variables:
#>   Treatment: treatment
#>   Mediator:  mediator
#>   Outcome:   outcome
#> 
#> Model info:
#>   N observations: 200
#>   Converged:      Yes
#>   Source:         stats::glm
#> 
#> Residual SDs:
#>   Mediator model:   0.9769
#>   Outcome model:    1.0395

# With covariates
result_cov <- med(
  data = mydata,
  treatment = "treatment",
  mediator = "mediator",
  outcome = "outcome",
  covariates = "covariate"
)

# Quick summary
quick(result)
#> NIE = 0.215  | NDE = 0.217 | PM = 49.8 %

# \donttest{
# With bootstrap CI (slower)
result_boot <- med(
  data = mydata,
  treatment = "treatment",
  mediator = "mediator",
  outcome = "outcome",
  boot = TRUE,
  n_boot = 1000,
  seed = 42
)
# }
```
