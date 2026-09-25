# Internal Implementation for lm/glm Extraction

Internal Implementation for lm/glm Extraction

## Usage

``` r
.extract_mediation_lm_impl(
  model_m,
  model_y,
  treatment,
  mediator,
  mediator_models = NULL,
  outcome = NULL,
  data = NULL,
  structure = c("auto", "serial", "parallel"),
  decomposition = c("auto", "four_way", "two_way"),
  m_star = 0,
  vcov_fun = stats::vcov,
  m_star_supplied = FALSE
)
```

## Arguments

- model_m:

  Fitted model for mediator

- model_y:

  Fitted model for outcome

- treatment:

  Treatment variable name

- mediator:

  Mediator variable name (scalar) or ordered mediator vector (length \>=
  2, serial mediation)

- mediator_models:

  List of fitted mediator models 2..k (serial only)

- outcome:

  Outcome variable name (auto-detected if NULL)

- data:

  Original data (extracted from model if NULL)

- structure, decomposition, m_star:

  See
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md).

- vcov_fun:

  Function returning a model's coefficient covariance (default
  [`stats::vcov()`](https://rdrr.io/r/stats/vcov.html)); passed to every
  worker.

- m_star_supplied:

  Logical: was `m_star` given at the call site? Set by the S7 methods
  from `!missing(m_star)`; an unused supplied value errors.

## Value

MediationData object, or SerialMediationData when `mediator` is a vector
of length \>= 2
