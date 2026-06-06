# Classify a multi-mediator lavaan structure as serial or parallel

Conservative, backward-compatible inference for `structure = "auto"` on
lavaan objects – the SEM analogue of
[`.classify_multimediator_structure()`](https://data-wise.github.io/medfit/reference/dot-classify_multimediator_structure.md)
for lm/glm. Returns `"parallel"` only on POSITIVE evidence (no mediator
is regressed on another); otherwise defaults to `"serial"` (the
historical default for vector `mediator`). It never errors – malformed
inputs fall through to the chosen worker's own directed validation.
Users can always set `structure` explicitly to override.

## Usage

``` r
.classify_multimediator_structure_lavaan(
  object,
  mediators,
  standardized = FALSE
)
```

## Arguments

- object:

  Fitted lavaan model.

- mediators:

  Character vector of mediator names (length \>= 2).

- standardized:

  Logical: passed through for table selection (the rows used for
  detection are identical, but keeping it consistent avoids a second
  solver call surprising the caller).

## Value

`"serial"` or `"parallel"`.

## Details

Detection reads only `op == "~"` (regression) rows, so residual
covariances (`~~`) among mediators cannot masquerade as serial chain
edges. Like the lm/glm classifier, it returns `"parallel"` only on
POSITIVE evidence: no mediator-on-mediator edge AND every mediator
enters a single common outcome equation. Anything else (e.g. one
mediator missing from the outcome model) falls back to `"serial"`,
preserving the historical vector-mediator behavior.
