# Internal Implementation for lm/glm Extraction

Internal Implementation for lm/glm Extraction

## Usage

``` r
.extract_mediation_lm_impl(
  model_m,
  model_y,
  treatment,
  mediator,
  outcome = NULL,
  data = NULL
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

  Mediator variable name

- outcome:

  Outcome variable name (auto-detected if NULL)

- data:

  Original data (extracted from model if NULL)

## Value

MediationData object
