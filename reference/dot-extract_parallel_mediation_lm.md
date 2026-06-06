# Extract Parallel Mediation Structure from lm/glm Models

Internal worker for parallel mediation (`X -> M_j -> Y`, independent
mediators). Mirrors
[`.extract_serial_mediation_lm()`](https://data-wise.github.io/medfit/reference/dot-extract_serial_mediation_lm.md)
but the mediator models are NOT chained: `mediator_models[[j - 1]]` is
the model for `mediators[j]` regressed on the treatment (and
covariates), in mediator-index order.

## Usage

``` r
.extract_parallel_mediation_lm(
  object,
  mediator_models,
  model_y,
  treatment,
  mediators,
  outcome = NULL,
  data = NULL
)
```

## Arguments

- object:

  Model for the first mediator (`mediators[1] ~ treatment`).

- mediator_models:

  List of the remaining mediator models 2..k, in index order (each
  `mediators[j] ~ treatment (+ C)`).

- model_y:

  Outcome model (`Y ~ treatment + M1 + ... + Mk (+ C)`).

- treatment, mediators, outcome, data:

  See
  [`.extract_serial_mediation_lm()`](https://data-wise.github.io/medfit/reference/dot-extract_serial_mediation_lm.md).

## Value

A `ParallelMediationData` object.
