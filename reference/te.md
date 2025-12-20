# Extract Total Effect (TE)

Extract the total effect from a mediation analysis result. The TE is the
sum of the indirect and direct effects.

## Usage

``` r
te(x, ...)
```

## Arguments

- x:

  A MediationData, SerialMediationData, or BootstrapResult object

- ...:

  Additional arguments passed to methods

## Value

A numeric value with optional attributes for confidence intervals

## Details

\$\$TE = NIE + NDE\$\$

## See also

[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
[`pm()`](https://data-wise.github.io/medfit/reference/pm.md),
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

te(med_data)
#> [1] 0.3445904
#> attr(,"class")
#> [1] "mediation_effect" "numeric"         
#> attr(,"type")
#> [1] "te"

# Verify: TE = NIE + NDE
nie(med_data) + nde(med_data)
#> [1] 0.3445904
#> attr(,"class")
#> [1] "mediation_effect" "numeric"         
#> attr(,"type")
#> [1] "nie"
```
