# Split multi-mediator product hits into supported and unsupported terms

A product is supported only when it sits in the outcome model, involves
the treatment and exactly one mediator, and is written with `:` or `*`
(an order-2 term). Everything else – products in a mediator model,
mediator-by-mediator, three-way, covariate products, function-wrapped
terms such as `I(X * M2)` – is unsupported.

## Usage

``` r
.partition_joint_products(hits, model_y, treatment, mediators)
```

## Arguments

- hits:

  `"<response>: <term>"` labels from
  [`.find_product_terms()`](https://data-wise.github.io/medfit/reference/dot-find_product_terms.md).

- model_y:

  Outcome model.

- treatment, mediators:

  Variable names.

## Value

`list(interactions = <mediators with a supported product, in mediator order>, unsupported = <labels>)`.
