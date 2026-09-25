# Find product regressors involving the treatment or a mediator in a lavaan fit

Flags regression predictors written as `a:b` with a component in `vars`,
plus any explicit `interaction` column name that appears as a predictor.
A product precomputed as a plain data column (e.g. `XM`) is only
recognized when named through `interaction`.

## Usage

``` r
.find_product_terms_lavaan(object, vars, interaction = NULL)
```

## Arguments

- object:

  A fitted lavaan object.

- vars:

  Character vector: treatment and mediator names.

- interaction:

  Optional character: product column name(s).
