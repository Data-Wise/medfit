# Four-Way Decomposition of a Mediation Effect

Return VanderWeele's (2014) four-way decomposition of the total effect
for an
[InteractionMediationData](https://data-wise.github.io/medfit/reference/InteractionMediationData.md)
object: controlled direct effect (CDE), reference interaction (INTref),
mediated interaction (INTmed), and pure indirect effect (PIE), together
with the derived natural direct/indirect and total effects.

## Usage

``` r
decompose(x, ...)
```

## Arguments

- x:

  An
  [InteractionMediationData](https://data-wise.github.io/medfit/reference/InteractionMediationData.md)
  object.

- ...:

  Additional arguments (ignored).

## Value

A named numeric vector:
`c(cde, int_ref, int_med, pie, nde, nie, total)`.

## See also

[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
[`te()`](https://data-wise.github.io/medfit/reference/te.md)
