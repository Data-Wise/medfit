# Model Extraction

## Overview

The
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
function provides a standardized interface for extracting mediation
structures from fitted models. It works with: - **lm/glm** models (base
R) - implemented - **lavaan** SEM models - implemented - **lmer** mixed
models (future)

All extraction methods return a `MediationData` or `SerialMediationData`
object, ensuring consistency across modeling frameworks.

**Note:** For quick analysis, consider using
[`med()`](https://data-wise.github.io/medfit/reference/med.md) instead -
it handles fitting and extraction in one step. Use
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
when you need more control or already have fitted models.

## Quick Comparison: med() vs extract_mediation()

``` r
library(medfit)

# Simple way: med() does everything
result <- med(data = mydata, treatment = "X", mediator = "M", outcome = "Y")
quick(result)
#> NIE = 0.19 | NDE = 0.16 | PM = 55%

# Advanced way: fit models separately, then extract
fit_m <- lm(M ~ X, data = mydata)
fit_y <- lm(Y ~ X + M, data = mydata)
result <- extract_mediation(fit_m, model_y = fit_y, treatment = "X", mediator = "M")
quick(result)
```

## Extraction Pattern

All extraction methods follow this pattern:

1.  Validate inputs (check variable names exist)
2.  Extract path coefficients (a, b, c’ paths)
3.  Extract covariance matrix (for inference)
4.  Extract residual variances (if Gaussian)
5.  Retrieve data (if available)
6.  Create MediationData object
7.  Return standardized structure

## Extracting from lm/glm Models

### Simple Mediation

For simple mediation (X -\> M -\> Y), fit two models:

``` r
# Generate example data
set.seed(123)
n <- 200
X <- rnorm(n)
M <- 0.5 * X + rnorm(n, sd = 0.8)
Y <- 0.3 * M + 0.2 * X + rnorm(n, sd = 0.8)
data <- data.frame(X = X, M = M, Y = Y)

# Fit mediation models
model_m <- lm(M ~ X, data = data)
model_y <- lm(Y ~ X + M, data = data)

# Extract mediation structure
med <- extract_mediation(
  model_m,           # Mediator model
  model_y,           # Outcome model
  treatment = "X",
  mediator = "M"
)

# View results
print(med)
summary(med)

# Use effect extractors (recommended)
nie(med)   # Indirect effect (a * b)
nde(med)   # Direct effect (c')
te(med)    # Total effect
pm(med)    # Proportion mediated
quick(med) # One-line summary
```

### What Gets Extracted?

The extraction captures:

- **Path coefficients**:

  - `a_path`: Coefficient of X in mediator model (X -\> M)
  - `b_path`: Coefficient of M in outcome model (M -\> Y, controlling
    for X)
  - `c_prime`: Coefficient of X in outcome model (direct effect)

- **Full parameter vector**: All coefficients from both models

- **Covariance matrix**: For computing standard errors of functions of
  parameters

- **Residual variances**: `sigma_m^2` and `sigma_y^2` for Gaussian
  models

- **Data and metadata**: Sample size, variable names, convergence status

### GLM with Non-Normal Outcomes

Works with any GLM family:

``` r
# Binary outcome
y_binary <- rbinom(n, 1, prob = plogis(0.3 * M + 0.2 * X))
data$Y_binary <- y_binary

model_m <- lm(M ~ X, data = data)
model_y <- glm(Y_binary ~ X + M, data = data, family = binomial())

med <- extract_mediation(
  model_m,
  model_y,
  treatment = "X",
  mediator = "M"
)

# Note: b_path and c_prime are on logit scale
print(med)
```

### Controlling for Covariates

Include covariates in both models:

``` r
# Add covariates
data$Z1 <- rnorm(n)
data$Z2 <- rnorm(n)

model_m <- lm(M ~ X + Z1 + Z2, data = data)
model_y <- lm(Y ~ X + M + Z1 + Z2, data = data)

med <- extract_mediation(
  model_m,
  model_y,
  treatment = "X",
  mediator = "M"
)

# Path coefficients adjust for Z1 and Z2
print(med)
```

### Serial Mediation with lm/glm

For a serial chain (X -\> M1 -\> M2 -\> … -\> Mk -\> Y) fit as separate
regressions (“sequential regression”), pass an ordered `mediator`
**vector** plus the mediator models 2..k via `mediator_models`. The
first mediator model (`M1 ~ X`) goes in the usual `object` slot; the
outcome model in `model_y`. The result is a `SerialMediationData`
object.

``` r
# Serial data: a chain from X through M1 and M2 to Y
M1 <- 0.5 * X + rnorm(n)
M2 <- 0.4 * M1 + rnorm(n)
y_serial <- 0.3 * M2 + 0.2 * X + rnorm(n)
data_lm_serial <- data.frame(X = X, M1 = M1, M2 = M2, Y = y_serial)

# First mediator model goes in the object slot; the rest in mediator_models
fit_m1 <- lm(M1 ~ X, data = data_lm_serial)
fit_m2 <- lm(M2 ~ M1, data = data_lm_serial)
fit_y  <- lm(Y ~ M2 + X, data = data_lm_serial)

med_serial_lm <- extract_mediation(
  fit_m1,
  model_y = fit_y,
  treatment = "X",
  mediator = c("M1", "M2"),       # a length-2 vector selects the serial branch
  mediator_models = list(fit_m2)  # the remaining k minus 1 mediator models
)

# Serial indirect effect: a * d1 * b
med_serial_lm@a_path * med_serial_lm@d_path * med_serial_lm@b_path
```

The order of `mediator_models` is cross-checked against the `mediator`
vector: each model’s response and predecessor are validated, so a
mis-ordered list fails fast with an informative error rather than
silently producing wrong `d`-paths.

> **Same data, different CI: lm vs lavaan**
>
> An lm/glm serial chain estimates each equation **separately**, so the
> combined covariance is **block-diagonal** across chain paths:
> `cov(a, d_i)`, `cov(d_i, b)`, and `cov(d_i, d_j)` are all zero by
> construction. (The within-outcome-equation covariance,
> e.g. `cov(b, c')`, is still preserved.)
>
> A single lavaan [`sem()`](https://rdrr.io/pkg/lavaan/man/sem.html) fit
> of the *same data* estimates all equations jointly and yields the
> **full** covariance among chain paths. Because the serial
> indirect-effect standard error depends on these off-diagonal
> covariances, the CI from an lm chain will generally differ from — and
> is often tighter than — the lavaan fit. This is correct given the
> different estimators; just be aware that the engine choice changes the
> interval for identical data.

### Parallel Mediation with lm/glm

In **parallel** mediation the mediators are independent (X -\> M_j -\>
Y) rather than chained: each `M_j` is regressed on the treatment only,
and all mediators enter a single outcome model. The total indirect
effect is the **sum** of the per-mediator products, \\\sum_j a_j b_j\\.
The API mirrors the serial case — pass a `mediator` vector and the
remaining mediator models via `mediator_models` — but set
`structure = "parallel"` (or rely on `structure = "auto"`, which infers
parallel when no mediator is regressed on another). The result is a
`ParallelMediationData` object.

``` r
# Parallel data: two independent mediators, each driven by X
M1p <- 0.5 * X + rnorm(n)
M2p <- 0.4 * X + rnorm(n)
y_par <- 0.3 * M1p + 0.45 * M2p + 0.1 * X + rnorm(n)
data_lm_par <- data.frame(X = X, M1 = M1p, M2 = M2p, Y = y_par)

# Each mediator is regressed on X alone; the outcome holds both mediators + X
fit_m1p <- lm(M1 ~ X, data = data_lm_par)
fit_m2p <- lm(M2 ~ X, data = data_lm_par)
fit_yp  <- lm(Y ~ M1 + M2 + X, data = data_lm_par)

med_parallel_lm <- extract_mediation(
  fit_m1p,
  model_y = fit_yp,
  treatment = "X",
  mediator = c("M1", "M2"),
  mediator_models = list(fit_m2p),
  structure = "parallel"
)

# Per-mediator paths and the summed indirect effect
med_parallel_lm@a_paths
med_parallel_lm@b_paths
nie(med_parallel_lm)               # sum_j a_j * b_j
confint(med_parallel_lm, parm = "effects")
```

Because the mediator equations are fit separately,
`cov(a_j, a_{j'}) = 0` and `cov(a_j, b_{j'}) = 0`; but the `b_j` (and
`c'`) share the single outcome equation, so `cov(b_j, b_{j'})` and
`cov(b_j, c')` are preserved. The
[`confint()`](https://rdrr.io/r/stats/confint.html) indirect-effect SE
uses the full delta method over the joint `a*/b*` block, not a naive
per-mediator sum.

## Extracting from lavaan Models

### Simple Mediation in SEM

``` r
library(lavaan)

# Define SEM model
model_syntax <- "
  # Mediator model
  M ~ a * X

  # Outcome model
  Y ~ b * M + c_prime * X

  # Indirect effect
  indirect := a * b

  # Total effect
  total := c_prime + a * b
"

# Fit model
fit <- sem(model_syntax, data = data)

# Extract mediation structure
med <- extract_mediation(
  fit,
  treatment = "X",
  mediator = "M",
  outcome = "Y"
)

print(med)
```

### Serial Mediation in SEM

For serial mediation (X -\> M1 -\> M2 -\> Y):

``` r
# Generate serial mediation data
M1 <- 0.4 * X + rnorm(n, sd = 0.8)
M2 <- 0.5 * M1 + 0.2 * X + rnorm(n, sd = 0.8)
y_serial <- 0.3 * M2 + 0.1 * M1 + 0.2 * X + rnorm(n, sd = 0.8)
data_serial <- data.frame(X = X, M1 = M1, M2 = M2, Y = y_serial)

# Define serial mediation model
serial_syntax <- "
  # First mediator
  M1 ~ a * X

  # Second mediator
  M2 ~ d * M1 + X

  # Outcome
  Y ~ b * M2 + M1 + c_prime * X

  # Serial indirect effect (product-of-three)
  serial_indirect := a * d * b
"

fit_serial <- sem(serial_syntax, data = data_serial)

# Extract as SerialMediationData
med_serial <- extract_mediation(
  fit_serial,
  treatment = "X",
  mediators = c("M1", "M2"),
  outcome = "Y"
)

print(med_serial)

# Serial indirect effect
med_serial@a_path * med_serial@d_path * med_serial@b_path
```

### Parallel Mediation in SEM

A single [`sem()`](https://rdrr.io/pkg/lavaan/man/sem.html) fit handles
parallel mediators directly: regress each mediator on the treatment and
let the outcome depend on all of them. Passing a `mediator` vector
returns a `ParallelMediationData` object (auto-detected, since no
mediator is regressed on another).

``` r
# Define a parallel mediation model: M1, M2 each on X; Y on both + X
parallel_syntax <- "
  M1 ~ a1 * X
  M2 ~ a2 * X
  Y  ~ b1 * M1 + b2 * M2 + c_prime * X

  # Total indirect effect = sum of per-mediator products
  indirect := a1 * b1 + a2 * b2
"

fit_parallel <- sem(parallel_syntax, data = data_lm_par)

med_parallel <- extract_mediation(
  fit_parallel,
  treatment = "X",
  mediator = c("M1", "M2"),
  outcome = "Y"
)

print(med_parallel)
nie(med_parallel)
```

Unlike the lm/glm engine, the SEM estimates the whole system jointly, so
the extracted `vcov` preserves **all** off-diagonals — including
`cov(a_j, b_j)` and `cov(a_j, a_{j'})`. Standard errors for the indirect
effect therefore reflect the full joint covariance, and (as with serial
mediation) the lavaan interval will generally differ from the lm one for
identical data.

## Treatment-Mediator Interaction (Four-Way Decomposition)

When treatment and mediator **interact**, the total effect splits into
four pieces (VanderWeele 2014): the controlled direct effect (CDE),
reference interaction (INTref), mediated interaction (INTmed), and pure
indirect effect (PIE), with `Total = CDE + INTref + INTmed + PIE`,
`NDE = CDE + INTref`, and `NIE = INTmed + PIE`. medfit computes the
decomposition; the causal interpretation (which requires VanderWeele’s
no-unmeasured-confounding assumptions) is the analyst’s responsibility.

[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
returns an `InteractionMediationData` object whenever the outcome model
carries an `X:M` term. Set the reference mediator level with `m_star`
(default 0).

### Interaction with lm/glm

For lm/glm, the `X:M` term is detected automatically:

``` r
# Outcome model includes the X:M interaction
fit_mi <- lm(M ~ X, data = data)
fit_yi <- lm(Y ~ X + M + X:M, data = data)

med_int <- extract_mediation(
  fit_mi,
  model_y = fit_yi,
  treatment = "X",
  mediator = "M",
  m_star = 0           # reference mediator level for the decomposition
)

decompose(med_int)                          # CDE, INTref, INTmed, PIE + effects
confint(med_int, parm = "components")       # delta-method CIs for the components
```

The four-way formulas (continuous `Y` and `M`) are `CDE = θ₁ + θ₃·m*`,
`INTref = θ₃·(E[M|X=0] − m*)`, `INTmed = θ₃·β₁`, and `PIE = θ₂·β₁`,
where `θ₃` is the interaction coefficient and `β₁` the `a` path.
Non-Gaussian outcomes are not yet supported and raise an informative
error.

### Interaction with lavaan

In lavaan the interaction enters as a **product variable** (a column you
create), and the model must be fit with `meanstructure = TRUE` so the
mediator intercept (needed for INTref) is estimated. Name the product
term via `interaction`:

``` r
data$XM <- data$X * data$M     # product term

fit_int <- sem(
  "M ~ X
   Y ~ M + X + XM",
  data = data,
  meanstructure = TRUE
)

med_int_sem <- extract_mediation(
  fit_int,
  treatment = "X",
  mediator = "M",
  outcome = "Y",
  interaction = "XM"     # name of the product predictor in the outcome model
)

decompose(med_int_sem)
```

When the interaction is absent (or `decomposition = "two_way"`),
extraction falls back to the standard `MediationData` — so existing
two-way workflows are unchanged.

## Compatibility with RMediation

The extraction design is compatible with RMediation’s lavaan extractor:

``` r
# RMediation extracts parameters for Distribution of Product method
# medfit extracts the same structure but as S7 classes

# Both packages can work with the same fitted models
# medfit provides infrastructure, RMediation adds DOP/MBCO methods
```

## Error Handling

The extraction uses **checkmate** for fail-fast input validation with
informative error messages:

``` r
# Variable not in model
extract_mediation(
  model_m,
  model_y,
  treatment = "NonExistent",
  mediator = "M"
)
# Error: Assertion on 'treatment in mediator model' failed:
#        Must be element of set {'(Intercept)','X'}, but is 'NonExistent'.

# Wrong type for treatment argument
extract_mediation(
  model_m,
  model_y,
  treatment = 123,  # Should be character
  mediator = "M"
)
# Error: Assertion on 'treatment' failed: Must be of type 'string', not 'double'.

# Mediator not in outcome model
model_y_wrong <- lm(Y ~ X, data = data)  # Missing M
extract_mediation(
  model_m,
  model_y_wrong,
  treatment = "X",
  mediator = "M"
)
# Error: Assertion on 'mediator in outcome model' failed:
#        Must be element of set {'(Intercept)','X'}, but is 'M'.
```

This defensive programming approach catches errors early with clear
messages, making debugging easier.

## Advanced Topics

### Extracting Full Parameter Vector

The `estimates` property contains all parameters from both models:

``` r
med <- extract_mediation(model_m, model_y, treatment = "X", mediator = "M")

# All parameters (intercepts + coefficients)
med@estimates

# Access by name
med@estimates["a"]  # a_path
med@estimates["b"]  # b_path
```

### Covariance Matrix for Delta Method

Use the covariance matrix for computing standard errors:

``` r
# Covariance matrix of all parameters
vcov_mat <- med@vcov

# For delta method SE of indirect effect (a*b):
# Var(ab) = b^2 * Var(a) + a^2 * Var(b) + 2ab*Cov(a,b)

a <- med@a_path
b <- med@b_path
var_a <- vcov_mat["a", "a"]
var_b <- vcov_mat["b", "b"]
cov_ab <- vcov_mat["a", "b"]

var_indirect <- b^2 * var_a + a^2 * var_b + 2 * a * b * cov_ab
se_indirect <- sqrt(var_indirect)

se_indirect
```

## Design for Extensibility

The extraction system is designed to accommodate future extensions:

- **New model types**: Add methods for lmer, brms, etc.
- **Complex mediation**: Multiple mediators, moderated mediation
- **Multiple treatments**: Comparative mediation analysis
- **Latent variables**: SEM with measurement models

All methods return the same S7 class structure, ensuring consistency.

## Next Steps

- Learn about [bootstrap
  inference](https://data-wise.github.io/medfit/articles/bootstrap.md)
  on extracted models
- See the
  [introduction](https://data-wise.github.io/medfit/articles/introduction.md)
  for S7 class details
- Check the reference documentation for
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  methods

## Working with Extracted Results

Once you have a `MediationData` object, you can use all medfit
functions:

### Effect Extractors

``` r
# Individual effects
nie(med)    # Natural Indirect Effect (a * b)
nde(med)    # Natural Direct Effect (c')
te(med)     # Total Effect (nie + nde)
pm(med)     # Proportion Mediated

# All path coefficients
paths(med)  # Named vector: a, b, c_prime
```

### Tidyverse Integration

``` r
library(generics)

# Convert to tibble
tidy(med)
#> # A tibble: 6 × 3
#>   term    estimate std.error
#>   <chr>      <dbl>     <dbl>
#> 1 a          0.448    0.107
#> ...

# Just path coefficients or effects
tidy(med, type = "paths")
tidy(med, type = "effects")

# With confidence intervals
tidy(med, conf.int = TRUE)

# One-row summary
glance(med)
```

### Base R Methods

``` r
# Standard generics
coef(med)                # Path coefficients
coef(med, "effects")     # NIE, NDE, TE
vcov(med)                # Variance-covariance matrix
confint(med)             # 95% confidence intervals
confint(med, level = 0.90)
nobs(med)                # Sample size
```

## Development Status

Model extraction is **complete**:

- ✅ S7 class definitions (MediationData, SerialMediationData)
- ✅ lm/glm extraction with checkmate validation
- ✅ lavaan extraction with checkmate validation
- ✅ Effect extractors (nie, nde, te, pm, paths)
- ✅ Tidyverse methods (tidy, glance)
- ✅ Base R generics (coef, vcov, confint, nobs)
- 📋 lmer extraction (future)

See `NEWS.md` for updates.
