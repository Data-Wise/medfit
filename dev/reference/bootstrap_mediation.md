# Perform Bootstrap Inference for Mediation Statistics

Conduct bootstrap inference to compute confidence intervals for
mediation statistics. Supports parametric, nonparametric, and plugin
methods.

Conduct bootstrap inference to compute confidence intervals for
mediation statistics. Supports parametric, nonparametric, and plugin
methods.

## Usage

``` r
bootstrap_mediation(
  statistic_fn,
  method = c("parametric", "nonparametric", "plugin"),
  mediation_data = NULL,
  data = NULL,
  n_boot = 1000L,
  ci_level = 0.95,
  parallel = FALSE,
  ncores = NULL,
  seed = NULL,
  ...
)

bootstrap_mediation(
  statistic_fn,
  method = c("parametric", "nonparametric", "plugin"),
  mediation_data = NULL,
  data = NULL,
  n_boot = 1000L,
  ci_level = 0.95,
  parallel = FALSE,
  ncores = NULL,
  seed = NULL,
  ...
)
```

## Arguments

- statistic_fn:

  Function that computes the statistic of interest.

  - For parametric bootstrap: receives named parameter vector, returns
    scalar

  - For nonparametric bootstrap: receives data frame, returns scalar

  - For plugin: receives named parameter vector, returns scalar

- method:

  Character string: bootstrap method. Options:

  - `"parametric"`: Sample from multivariate normal (fast, assumes
    normality)

  - `"nonparametric"`: Resample data and refit (robust, slower)

  - `"plugin"`: Point estimate only, no CI (fastest)

- mediation_data:

  [MediationData](https://data-wise.github.io/medfit/dev/reference/MediationData.md)
  object (required for parametric/plugin)

- data:

  Data frame (required for nonparametric bootstrap)

- n_boot:

  Integer: number of bootstrap samples (default: 1000)

- ci_level:

  Numeric: confidence level between 0 and 1 (default: 0.95)

- parallel:

  Logical: use parallel processing? (default: FALSE)

- ncores:

  Integer: number of cores for parallel processing. If NULL, uses
  `parallel::detectCores() - 1`

- seed:

  Integer: random seed for reproducibility (optional but recommended)

- ...:

  Additional arguments (reserved for future use)

## Value

A
[BootstrapResult](https://data-wise.github.io/medfit/dev/reference/BootstrapResult.md)
object containing:

- Point estimate

- Confidence interval bounds

- Bootstrap distribution (for parametric and nonparametric)

- Method used

A
[BootstrapResult](https://data-wise.github.io/medfit/dev/reference/BootstrapResult.md)
object containing:

- Point estimate

- Confidence interval bounds

- Bootstrap distribution (for parametric and nonparametric)

- Method used

## Details

### Bootstrap Methods

**Parametric Bootstrap** (`method = "parametric"`):

- Samples parameter vectors from \\N(\hat{\theta}, \hat{\Sigma})\\

- Fast and efficient

- Assumes asymptotic normality of parameters

- Recommended for most applications with n \> 50

**Nonparametric Bootstrap** (`method = "nonparametric"`):

- Resamples observations with replacement

- Refits models for each bootstrap sample

- More robust, no normality assumption

- Computationally intensive

- Use when normality is questionable or n is small

**Plugin Estimator** (`method = "plugin"`):

- Computes point estimate only

- No confidence interval

- Fastest method

- Use for quick checks or when CI not needed

### Parallel Processing

Set `parallel = TRUE` to use multiple cores:

- Automatically detects available cores

- Falls back to sequential if parallel fails

- Seed handling ensures reproducibility

### Reproducibility

Always set a seed for reproducible results:

    bootstrap_mediation(..., seed = 12345)

### Bootstrap Methods

**Parametric Bootstrap** (`method = "parametric"`):

- Samples parameter vectors from \\N(\hat{\theta}, \hat{\Sigma})\\

- Fast and efficient

- Assumes asymptotic normality of parameters

- Recommended for most applications with n \> 50

- Requires `mediation_data` argument

**Nonparametric Bootstrap** (`method = "nonparametric"`):

- Resamples observations with replacement

- Refits models for each bootstrap sample

- More robust, no normality assumption

- Computationally intensive

- Use when normality is questionable or n is small

- Requires `data` argument

**Plugin Estimator** (`method = "plugin"`):

- Computes point estimate only

- No confidence interval

- Fastest method

- Use for quick checks or when CI not needed

- Requires `mediation_data` argument

### Statistic Function

The `statistic_fn` should be a function that:

- For parametric/plugin: Takes a named numeric vector of parameters

- For nonparametric: Takes a data frame

- Returns a single numeric value

Common statistic functions for indirect effect:

    # Using parameter names from MediationData
    indirect_fn <- function(theta) {
      theta["m_X"] * theta["y_M"]
    }

### Parallel Processing

Set `parallel = TRUE` to use multiple cores:

- Uses
  [`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html) on
  Unix systems

- Falls back to sequential on Windows

- Automatically detects available cores

### Reproducibility

Always set a seed for reproducible results:

    bootstrap_mediation(..., seed = 12345)

## See also

[BootstrapResult](https://data-wise.github.io/medfit/dev/reference/BootstrapResult.md),
[MediationData](https://data-wise.github.io/medfit/dev/reference/MediationData.md),
[`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md)

[BootstrapResult](https://data-wise.github.io/medfit/dev/reference/BootstrapResult.md),
[MediationData](https://data-wise.github.io/medfit/dev/reference/MediationData.md),
[`fit_mediation()`](https://data-wise.github.io/medfit/dev/reference/fit_mediation.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Parametric bootstrap for indirect effect
result <- bootstrap_mediation(
  statistic_fn = function(theta) theta["a"] * theta["b"],
  method = "parametric",
  mediation_data = med_data,
  n_boot = 5000,
  ci_level = 0.95,
  seed = 12345
)

# Nonparametric bootstrap with parallel processing
result <- bootstrap_mediation(
  statistic_fn = function(data) {
    # Refit models and compute statistic
    # ...
  },
  method = "nonparametric",
  data = mydata,
  n_boot = 5000,
  parallel = TRUE,
  seed = 12345
)

# Plugin estimator (no CI)
result <- bootstrap_mediation(
  statistic_fn = function(theta) theta["a"] * theta["b"],
  method = "plugin",
  mediation_data = med_data
)
} # }

# Generate example data
set.seed(123)
n <- 100
mydata <- data.frame(X = rnorm(n))
mydata$M <- 0.5 * mydata$X + rnorm(n)
mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

# Fit mediation model
med_data <- fit_mediation(
  formula_y = Y ~ X + M,
  formula_m = M ~ X,
  data = mydata,
  treatment = "X",
  mediator = "M"
)

# Define indirect effect function
indirect_fn <- function(theta) theta["m_X"] * theta["y_M"]

# Plugin estimator (point estimate only, fastest)
result_plugin <- bootstrap_mediation(
  statistic_fn = indirect_fn,
  method = "plugin",
  mediation_data = med_data
)
print(result_plugin)
#> BootstrapResult object
#> ======================
#> 
#> Method:   plugin
#> Estimate:   0.1897
#> 
#> (No confidence interval for plugin method)

# \donttest{
# Parametric bootstrap (recommended for most applications)
result <- bootstrap_mediation(
  statistic_fn = indirect_fn,
  method = "parametric",
  mediation_data = med_data,
  n_boot = 1000,
  ci_level = 0.95,
  seed = 12345
)
print(result)
#> BootstrapResult object
#> ======================
#> 
#> Method:   parametric
#> Estimate:   0.1897
#> N bootstrap samples: 1000
#> 
#> 95% Confidence Interval:
#>   Lower:   0.0792
#>   Upper:   0.3230

# Nonparametric bootstrap (slower but more robust)
refit_fn <- function(boot_data) {
  fit_m <- lm(M ~ X, data = boot_data)
  fit_y <- lm(Y ~ X + M, data = boot_data)
  unname(coef(fit_m)["X"] * coef(fit_y)["M"])
}

result_np <- bootstrap_mediation(
  statistic_fn = refit_fn,
  method = "nonparametric",
  data = mydata,
  n_boot = 500,
  seed = 12345
)
print(result_np)
#> BootstrapResult object
#> ======================
#> 
#> Method:   nonparametric
#> Estimate:   0.1897
#> N bootstrap samples: 500
#> 
#> 95% Confidence Interval:
#>   Lower:   0.0746
#>   Upper:   0.3331
# }
```
