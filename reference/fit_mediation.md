# Fit Mediation Models

Fit mediation models using a specified modeling engine. This function
provides a convenient formula-based interface for fitting both the
mediator and outcome models simultaneously.

Fit mediation models using a specified modeling engine. This function
provides a convenient formula-based interface for fitting both the
mediator and outcome models simultaneously.

## Usage

``` r
fit_mediation(
  formula_y,
  formula_m,
  data,
  treatment,
  mediator,
  engine = "glm",
  family_y = stats::gaussian(),
  family_m = stats::gaussian(),
  weights = NULL,
  se_type = c("model", "sandwich"),
  engine_args = list(),
  m_star = 0,
  ...
)

fit_mediation(
  formula_y,
  formula_m,
  data,
  treatment,
  mediator,
  engine = "glm",
  family_y = stats::gaussian(),
  family_m = stats::gaussian(),
  weights = NULL,
  se_type = c("model", "sandwich"),
  engine_args = list(),
  m_star = 0,
  ...
)
```

## Arguments

- formula_y:

  Formula for outcome model (e.g., `Y ~ X + M + C`)

- formula_m:

  Formula for mediator model (e.g., `M ~ X + C`)

- data:

  Data frame containing all variables

- treatment:

  Character string: name of treatment variable

- mediator:

  Character string: name of mediator variable

- engine:

  Character string: modeling engine to use. Currently supports:

  - `"glm"`: Generalized linear models (default)

  - `"regmedint"`: Closed-form regression-based (in)direct effects via
    the suggested regmedint package (VanderWeele's regression approach,
    with optional treatment-mediator interaction)

- family_y:

  Family object for outcome model (default:
  [`gaussian()`](https://rdrr.io/r/stats/family.html))

- family_m:

  Family object for mediator model (default:
  [`gaussian()`](https://rdrr.io/r/stats/family.html))

- weights:

  Optional numeric vector of case weights (length `nrow(data)`), passed
  to both the mediator and outcome
  [`stats::glm()`](https://rdrr.io/r/stats/glm.html) fits. Use for
  inverse-probability weighting (IPW). `NULL` (default) fits unweighted.

- se_type:

  Variance-covariance estimator for `@vcov`: `"model"` (default,
  model-based [`stats::vcov`](https://rdrr.io/r/stats/vcov.html)) or
  `"sandwich"` (heteroskedasticity-consistent
  [`sandwich::vcovHC`](https://zeileis.codeberg.page/sandwich/reference/vcovHC.html),
  type HC3, recommended for IPW-weighted fits). The `"sandwich"` option
  requires the suggested sandwich package. Applies to the
  single-mediator path.

- engine_args:

  Named list of engine-specific overrides (default:
  [`list()`](https://rdrr.io/r/base/list.html), no overrides). Ignored
  by `engine = "glm"`. For `engine = "regmedint"`, recognized names are
  `interaction`, `cvar`, `mreg`, `yreg`, `a0`, `a1`, and `c_cond`; each
  replaces the value the adapter would otherwise derive from the
  formulas, families, and data. The reference mediator level is set with
  `m_star`, not here.

- m_star:

  Numeric scalar: reference mediator level \\m^\*\\ at which the
  controlled direct effect is evaluated (default: `0`). Used only when
  `formula_y` carries a treatment-by-mediator term, i.e. when the
  returned object is an
  [InteractionMediationData](https://data-wise.github.io/medfit/reference/InteractionMediationData.md).
  Supplying it for a fit that has no such term is an error rather than a
  silent no-op. That check keys on whether the argument was given at the
  call site, not on whether it differs from the default, so a wrapper
  that forwards `m_star` unconditionally will trigger it on two-way
  fits; forward it only when its own caller supplied one.

- ...:

  Additional arguments passed to the fitting function

## Value

A
[MediationData](https://data-wise.github.io/medfit/reference/MediationData.md)
object containing the fitted mediation structure

A
[MediationData](https://data-wise.github.io/medfit/reference/MediationData.md)
object containing the fitted mediation structure, or an
[InteractionMediationData](https://data-wise.github.io/medfit/reference/InteractionMediationData.md)
object when `formula_y` contains a treatment-by-mediator interaction
term.

## Details

The `fit_mediation()` function fits both the mediator model and outcome
model using the specified engine, then extracts the mediation structure
using
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md).

### Supported Engines

**GLM** (`engine = "glm"`):

- Fits models using [`stats::glm()`](https://rdrr.io/r/stats/glm.html)

- Supports all GLM families (gaussian, binomial, poisson, etc.)

- For Gaussian models, extracts residual variances

**regmedint** (`engine = "regmedint"`):

- Delegates to
  [`regmedint::regmedint()`](https://kaz-yos.github.io/regmedint/reference/regmedint.html)
  (suggested package) for closed-form natural (in)direct effects, with
  or without a treatment-mediator interaction

- Returns
  [MediationData](https://data-wise.github.io/medfit/reference/MediationData.md)
  or
  [InteractionMediationData](https://data-wise.github.io/medfit/reference/InteractionMediationData.md)
  depending on whether `formula_y` contains a treatment-by-mediator
  interaction term; use `engine_args` to override the derived regmedint
  arguments

### Reference Mediator Level

When the fit yields an
[InteractionMediationData](https://data-wise.github.io/medfit/reference/InteractionMediationData.md),
`m_star` fixes the level \\m^\*\\ at which the controlled direct effect
is read off: \\CDE = \theta_1 + \theta_3 m^\*\\ and \\INTref = \theta_3
(E\[M \mid X = 0\] - m^\*)\\. The two shift in compensating directions,
so [`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`te()`](https://data-wise.github.io/medfit/reference/te.md), and
[`pm()`](https://data-wise.github.io/medfit/reference/pm.md) are
invariant to `m_star`; only the CDE/INTref split moves.

The engines reach the same result by different routes. `engine = "glm"`
applies `m_star` at *extraction* time, after the coefficients are fit;
`engine = "regmedint"` passes it to
[`regmedint::regmedint()`](https://kaz-yos.github.io/regmedint/reference/regmedint.html)
as `m_cde`, where it is consumed by that package's closed-form estimator
at *fitting* time. Supplying `m_star` for a fit with no
treatment-by-mediator term is an error, not a silent no-op.

**Future Engines**:

- `"lmer"`: Mixed-effects models via lme4

- `"brms"`: Bayesian models via brms

### Model Specification

The formulas should follow standard R formula syntax:

- `formula_m`: Mediator model (e.g., `M ~ X + C1 + C2`)

- `formula_y`: Outcome model (e.g., `Y ~ X + M + C1 + C2`)

The mediator must appear in `formula_y`, and the treatment must appear
in both formulas.

### Model Specification

The function fits two models:

1.  **Mediator model**: `formula_m` (e.g., `M ~ X + C1 + C2`)

2.  **Outcome model**: `formula_y` (e.g., `Y ~ X + M + C1 + C2`)

The treatment variable must appear in both formulas. The mediator
variable must appear in the outcome formula but NOT in the mediator
formula (as it is the response).

### GLM Engine

When `engine = "glm"` (default):

- Models are fit using
  [`stats::glm()`](https://rdrr.io/r/stats/glm.html)

- Supports all GLM families (gaussian, binomial, poisson, etc.)

- For Gaussian models, residual standard deviations are extracted

- Non-Gaussian outcomes have `sigma_y = NULL`

### Common Family Specifications

- [`gaussian()`](https://rdrr.io/r/stats/family.html): Continuous
  outcomes (default)

- [`binomial()`](https://rdrr.io/r/stats/family.html): Binary outcomes

- [`poisson()`](https://rdrr.io/r/stats/family.html): Count outcomes

- [`Gamma()`](https://rdrr.io/r/stats/family.html): Positive continuous
  outcomes

## See also

[MediationData](https://data-wise.github.io/medfit/reference/MediationData.md),
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md),
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Fit Gaussian mediation model
med_data <- fit_mediation(
  formula_y = Y ~ X + M + C,
  formula_m = M ~ X + C,
  data = mydata,
  treatment = "X",
  mediator = "M",
  engine = "glm"
)

# Fit with binary outcome
med_data <- fit_mediation(
  formula_y = Y ~ X + M + C,
  formula_m = M ~ X + C,
  data = mydata,
  treatment = "X",
  mediator = "M",
  engine = "glm",
  family_y = binomial()
)
} # }

# Generate example data
set.seed(123)
n <- 100
mydata <- data.frame(
  X = rnorm(n),
  C = rnorm(n)
)
mydata$M <- 0.5 * mydata$X + 0.2 * mydata$C + rnorm(n)
mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + 0.1 * mydata$C + rnorm(n)

# Simple mediation with continuous variables
med_data <- fit_mediation(
  formula_y = Y ~ X + M,
  formula_m = M ~ X,
  data = mydata,
  treatment = "X",
  mediator = "M"
)
print(med_data)
#> MediationData object
#> ====================
#> 
#> Path coefficients:
#>   a (X -> M):        0.3551
#>   b (M -> Y|X):      0.3779
#>   c' (X -> Y|M):     0.2524
#>   Indirect (a*b):    0.1342
#> 
#> Variables:
#>   Treatment: X
#>   Mediator:  M
#>   Outcome:   Y
#> 
#> Model info:
#>   N observations: 100
#>   Converged:      Yes
#>   Source:         stats::glm
#> 
#> Residual SDs:
#>   Mediator model:   0.9710
#>   Outcome model:    1.0568

# With covariates
med_data_cov <- fit_mediation(
  formula_y = Y ~ X + M + C,
  formula_m = M ~ X + C,
  data = mydata,
  treatment = "X",
  mediator = "M"
)

# \donttest{
# Binary outcome (takes longer to fit)
mydata$Y_bin <- rbinom(n, 1, plogis(0.3 * mydata$X + 0.4 * mydata$M))
med_data_bin <- fit_mediation(
  formula_y = Y_bin ~ X + M,
  formula_m = M ~ X,
  data = mydata,
  treatment = "X",
  mediator = "M",
  family_y = binomial()
)
# }
```
