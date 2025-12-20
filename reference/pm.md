# Extract Proportion Mediated (PM)

Extract the proportion of the total effect that is mediated (operates
through the mediator).

## Usage

``` r
pm(x, ...)
```

## Arguments

- x:

  A MediationData, SerialMediationData, or BootstrapResult object

- ...:

  Additional arguments passed to methods

## Value

A numeric value between 0 and 1 (or negative/greater than 1 in cases of
suppression effects)

## Details

\$\$PM = \frac{NIE}{TE} = \frac{NIE}{NIE + NDE}\$\$

The proportion mediated can be:

- Between 0 and 1: Normal mediation

- Greater than 1: Suppression (direct and indirect effects have opposite
  signs)

- Negative: Inconsistent mediation

## See also

[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
[`te()`](https://data-wise.github.io/medfit/reference/te.md),
[`paths()`](https://data-wise.github.io/medfit/reference/paths.md)

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

pm(med_data)
#> [1] 0.5504146
#> attr(,"class")
#> [1] "mediation_effect" "numeric"         
#> attr(,"type")
#> [1] "pm"
```
