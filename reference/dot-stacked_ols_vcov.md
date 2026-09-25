# Stacked-OLS covariance of several equations fit to the same rows

Diagonal blocks are each model's
[`stats::vcov()`](https://rdrr.io/r/stats/vcov.html). Off-diagonal
blocks are \\\hat\sigma\_{ef} (X_e'X_e)^{-1} X_e'X_f (X_f'X_f)^{-1}\\,
with the residual cross-product divided by \\\sqrt{(n - p_e)(n -
p_f)}\\, so the formula reduces to
[`vcov()`](https://rdrr.io/r/stats/vcov.html) on the diagonal. A block
is exactly zero when one equation's residual lies in the other's column
space (serial chains with shared covariates; the outcome against every
mediator).

## Usage

``` r
.stacked_ols_vcov(models, prefixes)
```

## Arguments

- models:

  List of fitted lm/glm (Gaussian identity) models.

- prefixes:

  Character prefixes for the stacked coefficient names.

## Value

Named covariance matrix of the stacked coefficients.
