# Covariate means for the reference mediator mean (four-way decomposition)

Sample (or case-weighted) means of the mediator model's covariate design
columns: from `mm` when given (the extractor passes
`model.matrix(model_m)`), else the means the extractor stored on `dat`
(attribute `medfit_covariate_means`), else rebuilt from a model frame's
`terms` attribute, else plain numeric columns of `dat` (e.g. the lavaan
data matrix). Uses [`mean()`](https://rdrr.io/r/base/mean.html) per
column so numeric-covariate results match the column means exactly.

## Usage

``` r
.interaction_covariate_means(dat, covs, mm = NULL, w = NULL)
```

## Arguments

- dat:

  Data frame (the object's `@data`), or `NULL`.

- covs:

  Covariate coefficient names (mediator model, excluding the intercept
  and the treatment).

- mm:

  Optional design matrix of the mediator model.

- w:

  Optional case weights over the rows of `mm`; `NULL` for unweighted
  means. A model frame's `(weights)` column is used when rebuilding.

## Value

Named numeric vector over `covs`.
