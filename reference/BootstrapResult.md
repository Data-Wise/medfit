# BootstrapResult Class

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

## Details

This class standardizes bootstrap inference results across different
bootstrap methods (parametric, nonparametric, plugin).

### Properties

**Point estimates**:

- `estimate`: Point estimate of the statistic

**Confidence intervals**:

- `ci_lower`: Lower bound of confidence interval

- `ci_upper`: Upper bound of confidence interval

- `ci_level`: Confidence level (e.g., 0.95 for 95% CI)

**Bootstrap distribution**:

- `boot_estimates`: Vector of bootstrap estimates

- `n_boot`: Number of bootstrap samples

**Method**:

- `method`: Bootstrap method ("parametric", "nonparametric", or
  "plugin")

**Metadata**:

- `call`: Original function call (optional)
