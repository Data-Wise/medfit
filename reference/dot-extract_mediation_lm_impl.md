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
  m_star = 0
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

## Value

MediationData object, or SerialMediationData when `mediator` is a vector
of length \>= 2
