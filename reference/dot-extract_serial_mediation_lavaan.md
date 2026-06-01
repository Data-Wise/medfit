# Extract Serial Mediation Structure from a lavaan Model

Internal worker for the serial branch of
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
on lavaan objects. It is invoked by
[`extract_mediation_lavaan()`](https://data-wise.github.io/medfit/reference/extract_mediation_lavaan.md)
when `mediator` is a character vector of length \>= 2, and returns a
[SerialMediationData](https://data-wise.github.io/medfit/reference/SerialMediationData.md)
object describing the chain X -\> M1 -\> M2 -\> ... -\> Mk -\> Y.

## Usage

``` r
.extract_serial_mediation_lavaan(
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

  Fitted lavaan model object.

- treatment:

  Character scalar: treatment variable name.

- mediators:

  Character vector (length \>= 2): mediator names in causal order
  (`M1 -> M2 -> ... -> Mk`).

- outcome:

  Character scalar, or `NULL` to auto-detect from the variable predicted
  by the last mediator.

- standardized:

  Logical: extract standardized coefficients?

- ...:

  Additional arguments (ignored).

## Value

A
[SerialMediationData](https://data-wise.github.io/medfit/reference/SerialMediationData.md)
object.

## Details

Paths are located in the lavaan parameter table by variable name:

- `a` : `M1 ~ X`

- `d_i`: `M_{i+1} ~ M_i` for `i = 1 .. k-1` (the `k - 1` inter-mediator
  paths)

- `b` : `Y ~ Mk`

- `c'` : `Y ~ X` (defaults to 0 with a warning if absent – full
  mediation)

As in the simple-mediation extractor, named structural aliases (`a`,
`d1`, ..., `d{k-1}`, `b`, `c_prime`) are appended to `estimates` and the
variance-covariance matrix is expanded so that the FULL covariance
row/column of each source parameter is preserved. This lets downstream
code recover the true joint covariance of the chain (including
off-diagonals) via, for example,
`vcov[c("a", "d1", "b"), c("a", "d1", "b")]` – which is required for
serial indirect-effect standard errors.
