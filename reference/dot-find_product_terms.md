# Find product terms involving the treatment or a mediator

Scans each model's [`terms()`](https://rdrr.io/r/stats/terms.html) for
interaction terms (order \> 1) with at least one component in `vars`,
plus function-wrapped products such as `I(X * M1)` (see
[`.find_wrapped_products()`](https://data-wise.github.io/medfit/reference/dot-find_wrapped_products.md)).
Products among covariates alone are allowed. Returns
`"<response>: <term>"` labels, or `character(0)` when none are found.

## Usage

``` r
.find_product_terms(models, vars)
```

## Arguments

- models:

  List of fitted lm/glm models (`NULL` entries are skipped).

- vars:

  Character vector: treatment and mediator names.
