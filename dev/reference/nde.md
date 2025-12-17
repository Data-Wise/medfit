# Extract Natural Direct Effect (NDE)

Extract the natural direct effect from a mediation analysis result. The
NDE represents the effect of treatment on outcome that does NOT operate
through the mediator.

## Usage

``` r
nde(x, ...)
```

## Arguments

- x:

  A MediationData, SerialMediationData, or BootstrapResult object

- ...:

  Additional arguments passed to methods

## Value

A numeric value with optional attributes for confidence intervals

## Details

For both simple and serial mediation: \$\$NDE = c'\$\$

where c' is the direct effect coefficient.

## See also

[`nie()`](https://data-wise.github.io/medfit/dev/reference/nie.md),
[`te()`](https://data-wise.github.io/medfit/dev/reference/te.md),
[`pm()`](https://data-wise.github.io/medfit/dev/reference/pm.md),
[`paths()`](https://data-wise.github.io/medfit/dev/reference/paths.md)

## Examples

``` r
# Generate example data
set.seed(123)
n <- 100
mydata <- data.frame(X = rnorm(n))
mydata$M <- 0.5 * mydata$X + rnorm(n)
mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

med_data <- fit_mediation(
  formula_y = Y ~ X + M,
  formula_m = M ~ X,
  data = mydata,
  treatment = "X",
  mediator = "M"
)

nde(med_data)
#> [1] 0.1549228
#> attr(,"class")
#> [1] "mediation_effect" "numeric"         
#> attr(,"type")
#> [1] "nde"
```
