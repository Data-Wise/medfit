# Simple Mediation Analysis

A simplified entry point for mediation analysis. Specify the data and
variable names, and get results with minimal configuration.

This is the recommended starting point for most mediation analyses. For
more control over model specifications, use
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
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

  Logical: compute a bootstrap confidence interval for the indirect
  effect? (default: FALSE for speed). Uses a parametric bootstrap of \\a
  b\\ with a 95% percentile interval, attached to the result as the
  `"bootstrap"` attribute; call
  [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
  directly for another method or level.

- n_boot:

  Integer: number of bootstrap samples (default: 1000)

- seed:

  Integer: random seed for reproducibility (optional)

- ...:

  Additional arguments passed to
  [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)

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

[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
for full control,
[`quick()`](https://data-wise.github.io/medfit/reference/quick.md) for
instant summary,
[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
[`te()`](https://data-wise.github.io/medfit/reference/te.md),
[`pm()`](https://data-wise.github.io/medfit/reference/pm.md) for
extracting effects

## Examples

``` r
# mediation_demo is simulated data bundled with medfit; its covariates
# confound the mediator-outcome relation, so adjust for them
result <- med(
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1",
  outcome = "outcome",
  covariates = c("covariate1", "covariate2")
)
print(result)
#> MediationData object
#> ====================
#> 
#> Path coefficients:
#>   a (X -> M):        0.5826
#>   b (M -> Y|X):      0.5711
#>   c' (X -> Y|M):     0.2058
#>   Indirect (a*b):    0.3328
#> 
#> Variables:
#>   Treatment: treatment
#>   Mediator:  mediator1
#>   Outcome:   outcome
#> 
#> Model info:
#>   N observations: 400
#>   Converged:      Yes
#>   Source:         stats::glm
#> 
#> Residual SDs:
#>   Mediator model:   0.9792
#>   Outcome model:    1.0426

# Quick summary
quick(result)
#> NIE = 0.333  | NDE = 0.206 | PM = 61.8 %

# \donttest{
# With bootstrap CI (slower)
result_boot <- med(
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1",
  outcome = "outcome",
  covariates = c("covariate1", "covariate2"),
  boot = TRUE,
  n_boot = 1000,
  seed = 42
)
# }
```
