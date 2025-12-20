# Bootstrap Inference

## Overview

Bootstrap inference provides confidence intervals for indirect effects
without assuming normality. medfit implements three bootstrap methods:

1.  **Parametric bootstrap**: Sample from parameter distribution (fast,
    assumes normality)
2.  **Nonparametric bootstrap**: Resample data and refit models (robust,
    slower)
3.  **Plugin estimator**: Point estimate only (fastest, no CI)

All methods return a `BootstrapResult` object with consistent structure.

## Quick Start: Bootstrap with med()

The easiest way to get bootstrap confidence intervals:

``` r
library(medfit)

# One-line bootstrap mediation
result <- med(
  data = mydata,
  treatment = "X",
  mediator = "M",
  outcome = "Y",
  boot = TRUE,
  n_boot = 1000,
  seed = 123
)

# Instant results with CI
quick(result)
#> NIE = 0.19 [0.08, 0.32] | NDE = 0.16 | PM = 55%

# Access bootstrap result
result@bootstrap
```

For more control over bootstrap methods, use
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
directly.

## Why Bootstrap for Mediation?

The sampling distribution of indirect effects (\\a \times b\\) is
typically:

- **Non-normal**: Even when a and b are normal, their product is not
- **Skewed**: Often right-skewed
- **Complex**: No closed-form distribution for general case

Bootstrap methods: - Don’t assume normality - Provide accurate coverage
(closer to nominal 95%) - Handle complex indirect effects (serial
mediation, moderated mediation)

## Parametric Bootstrap

Samples from the estimated parameter distribution:

``` r
library(medfit)

# Fit mediation models
fit_m <- lm(M ~ X, data = mydata)
fit_y <- lm(Y ~ X + M, data = mydata)

# Extract mediation structure
med <- extract_mediation(fit_m, model_y = fit_y, treatment = "X", mediator = "M")

# Define statistic function for indirect effect
# Parameter names follow pattern: m_X (mediator model), y_M, y_X (outcome model)
indirect_effect <- function(theta) {
  theta["m_X"] * theta["y_M"]
}

# Parametric bootstrap
boot_result <- bootstrap_mediation(
  statistic_fn = indirect_effect,
  method = "parametric",
  mediation_data = med,
  n_boot = 1000,
  ci_level = 0.95,
  seed = 123
)

print(boot_result)
summary(boot_result)
```

### How It Works

1.  Extract parameter estimates: \\\hat{\theta} = (\hat{a}, \hat{b},
    ...)\\
2.  Extract covariance matrix: \\\hat{\Sigma}\\
3.  For each bootstrap iteration \\i = 1, ..., B\\:
    - Sample \\\theta^\*\_i \sim N(\hat{\theta}, \hat{\Sigma})\\
    - Compute indirect effect: \\IE^\*\_i = a^\*\_i \times b^\*\_i\\
4.  Compute percentile CI from bootstrap distribution

### When to Use

- **Fast**: No model refitting required
- **Appropriate when**: Parameters are approximately normal (large n)
- **Inappropriate when**: Small samples, non-normal parameters

### Advantages

- Very fast (no refitting)
- Reproducible with seed
- Works with extracted models (no need for original data)

### Disadvantages

- Assumes multivariate normality of parameters
- May underestimate uncertainty in small samples

## Nonparametric Bootstrap

Resamples data and refits models:

``` r
# Statistic function that refits models on resampled data
statistic_fn_refit <- function(boot_data) {
  # Fit models on bootstrap sample
  fit_m <- lm(M ~ X, data = boot_data)
  fit_y <- lm(Y ~ X + M, data = boot_data)

  # Extract and compute indirect effect
  med_boot <- extract_mediation(fit_m, model_y = fit_y,
                                treatment = "X", mediator = "M")
  med_boot@a_path * med_boot@b_path
}

# Nonparametric bootstrap (requires original data)
boot_result <- bootstrap_mediation(
  statistic_fn = statistic_fn_refit,
  method = "nonparametric",
  data = mydata,
  n_boot = 1000,
  ci_level = 0.95,
  seed = 123,
  parallel = TRUE,
  ncores = 4
)

print(boot_result)
```

### How It Works

1.  For each bootstrap iteration \\i = 1, ..., B\\:
    - Resample data with replacement: \\D^\*\_i\\
    - Refit mediator model on \\D^\*\_i\\
    - Refit outcome model on \\D^\*\_i\\
    - Extract paths: \\a^\*\_i\\, \\b^\*\_i\\
    - Compute indirect effect: \\IE^\*\_i = a^\*\_i \times b^\*\_i\\
2.  Compute percentile CI from bootstrap distribution

### When to Use

- **Robust**: Makes no parametric assumptions
- **Appropriate when**: Small samples, non-normal data, GLMs
- **Gold standard**: Most widely accepted method

### Advantages

- No distributional assumptions
- Robust to outliers
- Captures full sampling variability

### Disadvantages

- Computationally intensive (refits models B times)
- Requires original data
- Can be slow for complex models

### Parallel Processing

Speed up with parallel processing:

``` r
# Detect available cores
ncores <- parallel::detectCores() - 1

# Run in parallel
boot_result <- bootstrap_mediation(
  statistic_fn = statistic_fn_refit,
  method = "nonparametric",
  data = mydata,
  n_boot = 5000,
  parallel = TRUE,
  ncores = ncores,
  seed = 123
)
```

## Plugin Estimator

Point estimate only, no confidence interval:

``` r
# Plugin estimator (fastest)
plugin_result <- bootstrap_mediation(
  statistic_fn = indirect_effect,
  method = "plugin",
  mediation_data = med
)

print(plugin_result)
```

### When to Use

- Quick checks
- Point estimates for simulation studies
- When CI is not needed

### How It Works

Simply computes \\\hat{a} \times \hat{b}\\ from the fitted model. No
resampling.

## Interpreting Results

### Bootstrap Distribution

The bootstrap distribution shows the sampling variability:

``` r
# Access bootstrap estimates
boot_estimates <- boot_result@boot_estimates

# Histogram
hist(
  boot_estimates,
  breaks = 50,
  main = "Bootstrap Distribution of Indirect Effect",
  xlab = "Indirect Effect (a * b)"
)

# Add percentile CI
abline(v = boot_result@ci_lower, col = "red", lwd = 2)
abline(v = boot_result@ci_upper, col = "red", lwd = 2)
abline(v = boot_result@estimate, col = "blue", lwd = 2)

# Check for normality
qqnorm(boot_estimates)
qqline(boot_estimates)
```

### Confidence Interval

The percentile bootstrap CI is computed as:

- Lower bound: 2.5th percentile (for 95% CI)
- Upper bound: 97.5th percentile (for 95% CI)

``` r
# 95% CI
c(boot_result@ci_lower, boot_result@ci_upper)

# Change confidence level
boot_90 <- bootstrap_mediation(
  statistic_fn = indirect_effect,
  method = "parametric",
  mediation_data = med,
  n_boot = 1000,
  ci_level = 0.90,
  seed = 123
)
c(boot_90@ci_lower, boot_90@ci_upper) # Narrower
```

### Statistical Significance

If the confidence interval excludes zero, the indirect effect is
statistically significant:

``` r
# Check if CI excludes zero
if (boot_result@ci_lower > 0 || boot_result@ci_upper < 0) {
  print("Indirect effect is statistically significant")
} else {
  print("Indirect effect is not statistically significant")
}
```

## Serial Mediation Bootstrap

Works the same for serial mediation:

``` r
# Serial mediation (X -> M1 -> M2 -> Y)
serial_med <- extract_mediation(
  fit_serial,
  treatment = "X",
  mediators = c("M1", "M2"),
  outcome = "Y"
)

# Bootstrap the serial indirect effect (a * d * b)
boot_serial <- bootstrap_mediation(
  serial_med,
  method = "parametric",
  n_boot = 1000,
  ci_level = 0.95
)

# Serial indirect effect
print(boot_serial)

# Point estimate
serial_med@a_path * serial_med@d_path * serial_med@b_path
```

## Reproducibility

Set a seed for reproducible results:

``` r
# Same seed = same results
boot1 <- bootstrap_mediation(
  statistic_fn = indirect_effect,
  method = "parametric",
  mediation_data = med,
  n_boot = 1000,
  seed = 123
)
boot2 <- bootstrap_mediation(
  statistic_fn = indirect_effect,
  method = "parametric",
  mediation_data = med,
  n_boot = 1000,
  seed = 123
)

# Identical results
all.equal(boot1@boot_estimates, boot2@boot_estimates) # TRUE

# Different seed = different results
boot3 <- bootstrap_mediation(
  statistic_fn = indirect_effect,
  method = "parametric",
  mediation_data = med,
  n_boot = 1000,
  seed = 456
)
all.equal(boot1@boot_estimates, boot3@boot_estimates) # FALSE
```

## How Many Bootstrap Samples?

General guidelines:

- **Exploratory**: 1000 samples (fast)
- **Publication**: 5000+ samples (stable CI)
- **High stakes**: 10,000+ samples (very stable)

Check stability by varying `n_boot`:

``` r
# Compare different n_boot
boot_1k <- bootstrap_mediation(
  statistic_fn = indirect_effect,
  method = "parametric",
  mediation_data = med,
  n_boot = 1000,
  seed = 123
)
boot_5k <- bootstrap_mediation(
  statistic_fn = indirect_effect,
  method = "parametric",
  mediation_data = med,
  n_boot = 5000,
  seed = 123
)
boot_10k <- bootstrap_mediation(
  statistic_fn = indirect_effect,
  method = "parametric",
  mediation_data = med,
  n_boot = 10000,
  seed = 123
)

# Compare CIs
rbind(
  "1K" = c(boot_1k@ci_lower, boot_1k@ci_upper),
  "5K" = c(boot_5k@ci_lower, boot_5k@ci_upper),
  "10K" = c(boot_10k@ci_lower, boot_10k@ci_upper)
)
```

If CIs are similar, n_boot is sufficient.

## Alternative CI Methods

medfit currently uses **percentile bootstrap** (simplest, most common).

Future versions may add:

- **BCa (bias-corrected and accelerated)**: Adjusts for bias and
  skewness
- **Studentized bootstrap**: Better coverage in some cases
- **Bayesian bootstrap**: Posterior intervals

## Comparison with Delta Method

The delta method provides asymptotic SE for indirect effects:

``` r
# Delta method SE
a <- med@a_path
b <- med@b_path
var_a <- vcov(model_m)["X", "X"]
var_b <- vcov(model_y)["M", "M"]
cov_ab <- 0 # Assumed independent

se_delta <- sqrt(b^2 * var_a + a^2 * var_b)

# Delta method 95% CI (assumes normality)
ci_delta <- med@a_path * med@b_path + c(-1.96, 1.96) * se_delta

# Compare with bootstrap
ci_boot <- c(boot_result@ci_lower, boot_result@ci_upper)

rbind(delta = ci_delta, bootstrap = ci_boot)
```

Bootstrap is generally preferred because it: - Doesn’t assume normality
of indirect effect - Handles skewness correctly - Provides better
coverage

## Best Practices

1.  **Choose method appropriately**:

    - Parametric: Large samples, normal data
    - Nonparametric: Small samples, non-normal data, GLMs
    - Plugin: Quick checks only

2.  **Set seed**: Always set seed for reproducibility

3.  **Use enough bootstraps**: At least 1000, preferably 5000+

4.  **Check convergence**: Ensure models converged on bootstrap samples

5.  **Visualize distribution**: Plot histogram and Q-Q plot

6.  **Use parallel processing**: For nonparametric with large B

## Next Steps

- See
  [introduction](https://data-wise.github.io/medfit/articles/introduction.md)
  for S7 class details
- Learn about [model
  extraction](https://data-wise.github.io/medfit/articles/extraction.md)
- Check reference documentation for
  [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)

## Working with Bootstrap Results

### Tidyverse Integration

``` r
library(generics)

# Convert to tibble
tidy(boot_result)
#> # A tibble: 1 × 5
#>   estimate ci_lower ci_upper ci_level method
#>      <dbl>    <dbl>    <dbl>    <dbl> <chr>
#> 1    0.190   0.0800    0.320     0.95 parametric

# One-row summary
glance(boot_result)
#> # A tibble: 1 × 4
#>   n_boot ci_level method     converged
#>    <int>    <dbl> <chr>      <lgl>
#> 1   1000     0.95 parametric TRUE
```

### Base R Methods

``` r
# Extract estimate
coef(boot_result)

# Confidence interval
confint(boot_result)
confint(boot_result, level = 0.90)
```

## Development Status

Bootstrap infrastructure is **complete**:

- ✅ S7 class for BootstrapResult
- ✅ Parametric bootstrap
- ✅ Nonparametric bootstrap
- ✅ Plugin estimator
- ✅ Parallel processing support
- ✅ Seed-based reproducibility
- ✅ Integration with
  [`med()`](https://data-wise.github.io/medfit/reference/med.md) via
  `boot = TRUE`
- ✅ Tidyverse methods (tidy, glance)
- ✅ Base R methods (coef, confint)
- 📋 BCa confidence intervals (future)

See `NEWS.md` for updates.
