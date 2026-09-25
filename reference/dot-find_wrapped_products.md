# Find function-wrapped product terms

A product written inside a function call, such as `I(X * M)`, is a
single order-1 term, so the `":"`-based scans miss it and the product is
treated as an unrelated covariate. This flags order-1 terms whose
variables (via [`all.vars()`](https://rdrr.io/r/base/allnames.html))
include at least two distinct names and involve `vars`: any of them by
default, or all of them when `require_all = TRUE`. Single-variable
transforms such as `I(X^2)` or `log(C)` are not flagged. Products
precomputed as a data column cannot be detected from the formula.

## Usage

``` r
.find_wrapped_products(models, vars, require_all = FALSE)
```

## Arguments

- models:

  List of fitted lm/glm models (`NULL` entries are skipped).

- vars:

  Character vector: treatment and mediator names.

- require_all:

  Logical: flag only terms involving every name in `vars`.

## Value

`"<response>: <term>"` labels, or `character(0)`.
