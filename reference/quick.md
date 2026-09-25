# Quick Summary of Mediation Results

Print a one-line summary of mediation results, perfect for quick checks
or ADHD-friendly workflows.

## Usage

``` r
quick(x, digits = 3, ...)
```

## Arguments

- x:

  A
  [MediationData](https://data-wise.github.io/medfit/reference/MediationData.md)
  or
  [SerialMediationData](https://data-wise.github.io/medfit/reference/SerialMediationData.md)
  object (or result from
  [`med()`](https://data-wise.github.io/medfit/reference/med.md)). Other
  classes error; use [`print()`](https://rdrr.io/r/base/print.html) or
  [`summary()`](https://rdrr.io/r/base/summary.html) for them.

- digits:

  Integer: number of significant digits (default: 3)

- ...:

  Additional arguments (ignored)

## Value

Invisibly returns x

## Details

Prints a compact one-line summary showing:

- NIE (Natural Indirect Effect) with CI if available

- NDE (Natural Direct Effect)

- Proportion Mediated (PM)

If bootstrap results are available (from `med(..., boot = TRUE)`),
confidence intervals are shown for NIE.

## See also

[`med()`](https://data-wise.github.io/medfit/reference/med.md),
[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
[`pm()`](https://data-wise.github.io/medfit/reference/pm.md)

## Examples

``` r
result <- med(
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1",
  outcome = "outcome",
  covariates = c("covariate1", "covariate2")
)

# One-line summary
quick(result)
#> NIE = 0.333  | NDE = 0.206 | PM = 61.8 %
```
