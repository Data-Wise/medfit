# Extract Natural Indirect Effect (NIE)

Extract the natural indirect effect from a mediation analysis result.
The NIE represents the effect of treatment on outcome that operates
through the mediator.

## Usage

``` r
nie(x, ...)
```

## Arguments

- x:

  A MediationData, SerialMediationData, or BootstrapResult object

- ...:

  Additional arguments passed to methods

## Value

A numeric value (or named vector for SerialMediationData) with optional
attributes for confidence intervals if available

## Details

For simple mediation (MediationData): \$\$NIE = a \times b\$\$

For serial mediation (SerialMediationData): \$\$NIE = a \times d\_{21}
\times d\_{32} \times \ldots \times b\$\$

## See also

[`nde()`](https://data-wise.github.io/medfit/dev/reference/nde.md),
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

nie(med_data)
#> [1] 0.1896676
#> attr(,"class")
#> [1] "mediation_effect" "numeric"         
#> attr(,"type")
#> [1] "nie"
```
