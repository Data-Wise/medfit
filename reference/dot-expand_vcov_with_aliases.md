# Expand a Source Covariance Matrix with Full-Copy Path Aliases

Appends named structural aliases (e.g. `a`, `b`, `c_prime`, `d1`, ...)
to a source variance-covariance matrix, copying the FULL covariance
row/column of each alias's source parameter rather than just its
diagonal variance. This preserves every covariance the aliased parameter
has – both with the original parameters and with the other aliases.

## Usage

``` r
.expand_vcov_with_aliases(vcov_src, source_idx, aliases_to_add)
```

## Arguments

- vcov_src:

  Numeric matrix: the source covariance with row/column names. For lm
  this is the block-diagonal stack of the per-model
  [`vcov()`](https://rdrr.io/r/stats/vcov.html)s; for lavaan it is
  `lavaan::vcov(object)`.

- source_idx:

  Named integer vector mapping each alias name to the row index of its
  source parameter in `vcov_src`. Entries may be `NA_integer_` when a
  source could not be resolved (that alias is then left as a
  zero-variance placeholder). Must contain an entry for every name in
  `aliases_to_add`.

- aliases_to_add:

  Character vector of alias names to append as new rows/columns (those
  not already present in `vcov_src`).

## Value

A symmetric numeric matrix of dimension
`nrow(vcov_src) + length(aliases_to_add)`, with the original block
intact, each alias row/column populated from its source, and the
alias-to-alias intersections filled from the corresponding
source-to-source covariances.

## Details

This is the shared engine behind the alias-vcov contract used by the
lm/glm and lavaan
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
methods (simple and serial). Factoring it here keeps the two extractors
from drifting: each computes its own `source_idx` mapping (the lavaan
path tries labels then variable names; the lm path maps to the prefixed
coefficient names) and then hands the mechanical expansion to this
single routine.
