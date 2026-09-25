# Error when a multi-mediator model carries product terms

Serial and parallel extraction estimate main-effect paths only, so a
product term involving the treatment or a mediator would otherwise be
ignored silently. Shared by the lm/glm and lavaan engines.

## Usage

``` r
.stop_on_multimediator_products(hits)
```

## Arguments

- hits:

  Character vector of offending terms (from
  [`.find_product_terms()`](https://data-wise.github.io/medfit/reference/dot-find_product_terms.md)
  or
  [`.find_product_terms_lavaan()`](https://data-wise.github.io/medfit/reference/dot-find_product_terms_lavaan.md)).
