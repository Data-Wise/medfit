# Getting Started with medfit

## What is medfit?

**medfit** provides unified infrastructure for mediation analysis in R.
It offers:

- **ADHD-friendly API** with
  [`med()`](https://data-wise.github.io/medfit/dev/reference/med.md) for
  quick analysis and
  [`quick()`](https://data-wise.github.io/medfit/dev/reference/quick.md)
  for instant results
- **Effect extractors** like
  [`nie()`](https://data-wise.github.io/medfit/dev/reference/nie.md),
  [`nde()`](https://data-wise.github.io/medfit/dev/reference/nde.md),
  [`te()`](https://data-wise.github.io/medfit/dev/reference/te.md),
  [`pm()`](https://data-wise.github.io/medfit/dev/reference/pm.md), and
  [`paths()`](https://data-wise.github.io/medfit/dev/reference/paths.md)
- **Tidyverse integration** with
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
  [`glance()`](https://generics.r-lib.org/reference/glance.html) methods
- **S7-based classes** for standardized mediation data structures
- **Foundation** for the mediation analysis ecosystem (RMediation,
  mediationverse)

## Quick Start: The Simplest Way

### One Function: `med()`

``` r
library(medfit)

# Create example data
set.seed(123)
n <- 200
mydata <- data.frame(X = rnorm(n))
mydata$M <- 0.5 * mydata$X + rnorm(n)
mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

# Run mediation analysis
result <- med(
  data = mydata,
  treatment = "X",
  mediator = "M",
  outcome = "Y"
)

# View results
print(result)
```

### Instant Results: `quick()`

``` r
# One-line summary
quick(result)
#> NIE = 0.19 | NDE = 0.16 | PM = 55%
```

### With Covariates

``` r
# Add a covariate
mydata$C <- rnorm(n)

result_cov <- med(
  data = mydata,
  treatment = "X",
  mediator = "M",
  outcome = "Y",
  covariates = "C"
)

quick(result_cov)
```

### With Bootstrap CI

``` r
# Get bootstrap confidence intervals
result_boot <- med(
  data = mydata,
  treatment = "X",
  mediator = "M",
  outcome = "Y",
  boot = TRUE,
  n_boot = 1000,
  seed = 42
)

quick(result_boot)
#> NIE = 0.19 [0.08, 0.32] | NDE = 0.16 | PM = 55%
```

## Extract Individual Effects

Use dedicated extractor functions:

``` r
# Natural Indirect Effect (a * b)
nie(result)

# Natural Direct Effect (c')
nde(result)

# Total Effect (nie + nde)
te(result)

# Proportion Mediated
pm(result)

# All path coefficients
paths(result)
#> Named num [1:3] 0.448 0.424 0.155
#> - attr(*, "names")= chr [1:3] "a" "b" "c_prime"
```

## Tidyverse Integration

Use [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
[`glance()`](https://generics.r-lib.org/reference/glance.html) for
tibble-based workflows:

``` r
library(generics)

# Tidy tibble of all estimates
tidy(result)
#> # A tibble: 6 × 3
#>   term    estimate std.error
#>   <chr>      <dbl>     <dbl>
#> 1 a          0.448    0.107
#> 2 b          0.424    0.099
#> 3 c_prime    0.155    0.114
#> 4 nie        0.190       NA
#> 5 nde        0.155       NA
#> 6 te         0.345       NA

# Just paths with CIs
tidy(result, type = "paths", conf.int = TRUE)

# Just effects
tidy(result, type = "effects")
```

``` r
# One-row model summary
glance(result)
#> # A tibble: 1 × 6
#>     nie   nde    te    pm  nobs converged
#>   <dbl> <dbl> <dbl> <dbl> <int> <lgl>
#> 1 0.190 0.155 0.345  0.55   200 TRUE
```

## Base R Methods

Standard R generics work on medfit objects:

``` r
# Coefficients
coef(result)                    # Path coefficients (a, b, c')
coef(result, type = "effects")  # Effects (nie, nde, te)
coef(result, type = "all")      # All parameters

# Variance-covariance matrix
vcov(result)

# Confidence intervals
confint(result)                       # 95% CI for paths
confint(result, level = 0.90)         # 90% CI
confint(result, type = "effects")     # CI for effects

# Number of observations
nobs(result)
```

## Serial Mediation

For serial mediation (X -\> M1 -\> M2 -\> Y):

``` r
serial_data <- SerialMediationData(
  a_path = 0.4,           # X -> M1
  d_path = 0.5,           # M1 -> M2
  b_path = 0.3,           # M2 -> Y
  c_prime = 0.2,          # X -> Y direct effect
  treatment = "X",
  mediators = c("M1", "M2"),
  outcome = "Y",
  estimates = c(a = 0.4, d = 0.5, b = 0.3, c_prime = 0.2),
  vcov = diag(4) * 0.01,
  mediator_predictors = list(M1 = "X", M2 = c("X", "M1")),
  outcome_predictors = c("X", "M1", "M2"),
  n_obs = 100L,
  converged = TRUE,
  source_package = "medfit"
)

# Same extractors work
nie(serial_data)   # a * d * b
nde(serial_data)   # c'
quick(serial_data)
#> [2 mediators] NIE = 0.06 | NDE = 0.2 | PM = 23%
```

## Advanced Usage

### Extract from Fitted Models

If you already have fitted models:

``` r
# Fit models separately
fit_m <- lm(M ~ X, data = mydata)
fit_y <- lm(Y ~ X + M, data = mydata)

# Extract mediation structure
med_data <- extract_mediation(
  fit_m,
  model_y = fit_y,
  treatment = "X",
  mediator = "M"
)

# All the same methods work
nie(med_data)
tidy(med_data)
quick(med_data)
```

### fit_mediation() for Full Control

``` r
med_data <- fit_mediation(
  formula_y = Y ~ X + M,
  formula_m = M ~ X,
  data = mydata,
  treatment = "X",
  mediator = "M"
)

# Access path coefficients directly
med_data@a_path  # X -> M
med_data@b_path  # M -> Y
med_data@c_prime # X -> Y (direct)
```

### Custom Bootstrap

``` r
# Define custom statistic function
indirect_effect <- function(theta) {
  theta["m_X"] * theta["y_M"]
}

# Run bootstrap
boot_result <- bootstrap_mediation(
  statistic_fn = indirect_effect,
  method = "parametric",
  mediation_data = med_data,
  n_boot = 1000,
  ci_level = 0.95,
  seed = 123
)

# Bootstrap results also support tidy/glance
tidy(boot_result)
glance(boot_result)
```

## Learn More

- [Introduction to
  medfit](https://data-wise.github.io/medfit/dev/articles/introduction.md) -
  Detailed S7 class documentation
- [Model
  Extraction](https://data-wise.github.io/medfit/dev/articles/extraction.md) -
  Extract from lm, glm, lavaan models
- [Bootstrap
  Inference](https://data-wise.github.io/medfit/dev/articles/bootstrap.md) -
  Parametric and nonparametric bootstrap

## Development Status

medfit is feature complete:

- ✅ Phase 2: S7 class architecture
- ✅ Phase 3: Model extraction (lm/glm, lavaan)
- ✅ Phase 4: Model fitting
  ([`fit_mediation()`](https://data-wise.github.io/medfit/dev/reference/fit_mediation.md))
- ✅ Phase 5: Bootstrap infrastructure
  ([`bootstrap_mediation()`](https://data-wise.github.io/medfit/dev/reference/bootstrap_mediation.md))
- ✅ Phase 6: Generic functions (`coef`, `vcov`, `confint`, `nobs`,
  `nie`, `nde`, `te`, `pm`, `paths`, `tidy`, `glance`)
- ✅ Phase 6.5: ADHD-friendly API (`med`, `quick`)

See `NEWS.md` for the latest updates.
