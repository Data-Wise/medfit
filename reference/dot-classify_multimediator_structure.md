# Classify a multi-mediator structure as serial or parallel

Conservative, backward-compatible inference for `structure = "auto"`.
Returns `"parallel"` only on POSITIVE evidence of a parallel structure
(no mediator is regressed on another, and every mediator enters the
outcome model); otherwise defaults to `"serial"` (the historical default
for vector `mediator`). It never errors – malformed inputs fall through
to the chosen worker's own validation, which emits specific, directed
messages. Users can always set `structure` explicitly to override.

## Usage

``` r
.classify_multimediator_structure(med_models, mediators, treatment, model_y)
```

## Arguments

- med_models:

  Ordered list of the k mediator models (`med_models[[j]]` is intended
  to be the model for `mediators[j]`).

- mediators:

  Character vector of mediator names (length k).

- treatment:

  Treatment variable name.

- model_y:

  The outcome model.

## Value

`"serial"` or `"parallel"`.
