# Propagate mediator means down a serial chain

The joint effects need each mediator's mean given the treatment and
covariates only. For a serial chain, where `M2 ~ X + M1 + C`, iterated
expectations give reduced-form coefficients by recursion:
\\\beta^\*\_{1i} = \beta\_{1i} + \sum\_{j\<i} d\_{ij} \beta^\*\_{1j}\\,
and likewise for the intercept and covariate coefficients. For parallel
mediators every `d` is 0, so raw and propagated coefficients coincide.

## Usage

``` r
.propagate_mediator_means(b0, b1, gamma, d)
```

## Arguments

- b0, b1:

  Numeric vectors (length K): raw intercepts and treatment coefficients.

- gamma:

  K x p matrix of raw covariate coefficients (p may be 0).

- d:

  K x K strictly lower-triangular matrix: `d[i, j]` is the coefficient
  of mediator j in the model for mediator i.

## Value

`list(b0, b1, gamma)` of propagated coefficients.
