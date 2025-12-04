# BootstrapResult S7 Class

S7 class containing results from bootstrap inference, including point
estimates, confidence intervals, and bootstrap distribution.

## Usage

``` r
BootstrapResult(
  estimate = integer(0),
  ci_lower = integer(0),
  ci_upper = integer(0),
  ci_level = integer(0),
  boot_estimates = integer(0),
  n_boot = integer(0),
  method = character(0),
  call = quote({
 })
)
```

## Arguments

- estimate:

  Numeric scalar: point estimate of the statistic

- ci_lower:

  Numeric scalar: lower bound of confidence interval

- ci_upper:

  Numeric scalar: upper bound of confidence interval

- ci_level:

  Numeric scalar: confidence level (e.g., 0.95 for 95% CI)

- boot_estimates:

  Numeric vector: bootstrap distribution of estimates

- n_boot:

  Integer scalar: number of bootstrap samples

- method:

  Character scalar: bootstrap method ("parametric", "nonparametric", or
  "plugin")

- call:

  Call object or NULL: original function call

## Value

A BootstrapResult S7 object

## Details

This class standardizes bootstrap inference results across different
bootstrap methods (parametric, nonparametric, plugin).

The class includes validation to ensure consistency between method type
and required fields.

## Examples

``` r
if (FALSE) { # \dontrun{
# Parametric bootstrap result
result <- BootstrapResult(
  estimate = 0.15,
  ci_lower = 0.10,
  ci_upper = 0.20,
  ci_level = 0.95,
  boot_estimates = rnorm(1000, 0.15, 0.02),
  n_boot = 1000L,
  method = "parametric",
  call = NULL
)
} # }
```
