# Quick Summary of Mediation Results

Print a one-line summary of mediation results, perfect for quick checks
or ADHD-friendly workflows.

## Usage

``` r
quick(x, digits = 3, ...)
```

## Arguments

- x:

  A MediationData object (or result from
  [`med()`](https://data-wise.github.io/medfit/reference/med.md))

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
# Generate example data
set.seed(123)
n <- 100
mydata <- data.frame(X = rnorm(n))
mydata$M <- 0.5 * mydata$X + rnorm(n)
mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

result <- med(
  data = mydata,
  treatment = "X",
  mediator = "M",
  outcome = "Y"
)

# One-line summary
quick(result)
#> NIE = 0.19  | NDE = 0.155 | PM = 55 %
```
