# Sample means of the covariate design columns of a joint object

Reads the means the extractor stored on `@data` (attribute
`medfit_covariate_means`, the exact vector the point estimate used),
else rebuilds the design from a model frame's `terms` attribute, else
plain numeric columns for a hand-built `data`.

## Usage

``` r
.joint_covariate_means(x, covs)
```

## Arguments

- x:

  A JointMediationData object.

- covs:

  Covariate coefficient names.

## Value

Named numeric vector (length 0 when there are no covariates).
