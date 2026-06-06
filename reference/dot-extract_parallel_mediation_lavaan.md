# Extract Parallel Mediation Structure from a lavaan Model

Internal worker for the parallel branch of
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
on lavaan objects (`X -> M_j -> Y` for k independent mediators). It is
the SEM analogue of
[`.extract_parallel_mediation_lm()`](https://data-wise.github.io/medfit/reference/dot-extract_parallel_mediation_lm.md)
and returns a `ParallelMediationData` object. Total indirect effect =
`sum_j a_j * b_j`.

## Usage

``` r
.extract_parallel_mediation_lavaan(
  object,
  treatment,
  mediators,
  outcome = NULL,
  standardized = FALSE,
  ...
)
```

## Arguments

- object:

  Fitted lavaan model.

- treatment:

  Character scalar: treatment variable name.

- mediators:

  Character vector (length \>= 2): mediator names (any order; the
  `a_j`/`b_j` indices follow this vector).

- outcome:

  Character scalar, or `NULL` to auto-detect (the common non-mediator
  variable predicted by the mediators).

- standardized:

  Logical: extract standardized coefficients?

- ...:

  Additional arguments (ignored).

## Value

A `ParallelMediationData` object.

## Details

Paths are located in the lavaan parameter table by variable name:

- `a_j`: `M_j ~ X`

- `b_j`: `Y ~ M_j`

- `c'` : `Y ~ X` (defaults to 0 with a warning if absent – full
  mediation)

Unlike the lm/glm engine – where the `M_j` come from separate
regressions so `cov(a_j, b_j) = 0` – lavaan estimates the whole system
jointly, so the expanded `vcov` preserves the FULL off-diagonal
structure (including `cov(a_j, b_j)` and `cov(a_j, a_j')`). Downstream
SEs therefore reflect the true joint covariance; tests must not hardcode
any of these to zero.
