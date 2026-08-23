# Locate a treatment-by-mediator interaction term in a model formula

Formula-level counterpart of
[`.find_interaction_term()`](https://data-wise.github.io/medfit/reference/dot-find_interaction_term.md)
(which inspects a fitted model's coefficient names). Returns the term
label of the `X:M` product term in `formula`, trying both orderings, or
`NA_character_` when no such term is present. Used by the `"regmedint"`
engine to decide between
[MediationData](https://data-wise.github.io/medfit/reference/MediationData.md)
and
[InteractionMediationData](https://data-wise.github.io/medfit/reference/InteractionMediationData.md)
before any model is fitted, mirroring
`extract_mediation(decomposition = "auto")`'s convention.

## Usage

``` r
.find_interaction_term_formula(formula, treatment, mediator)
```

## Arguments

- formula:

  A model formula (e.g. `Y ~ X * M + C`).

- treatment, mediator:

  Variable names.

## Value

A single string (the matching term label) or `NA_character_`.
