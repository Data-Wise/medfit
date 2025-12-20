# Extract All Path Coefficients

Extract all path coefficients from a mediation analysis result.

## Usage

``` r
paths(x, ...)
```

## Arguments

- x:

  A MediationData or SerialMediationData object

- ...:

  Additional arguments passed to methods

## Value

A named numeric vector of path coefficients

## Details

For simple mediation (MediationData):

- `a`: Treatment -\> Mediator (X -\> M)

- `b`: Mediator -\> Outcome (M -\> Y \| X)

- `c_prime`: Direct effect (X -\> Y \| M)

For serial mediation (SerialMediationData):

- `a`: Treatment -\> First mediator

- `d21`, `d32`, ...: Mediator-to-mediator paths

- `b`: Last mediator -\> Outcome

- `c_prime`: Direct effect

## See also

[`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
[`te()`](https://data-wise.github.io/medfit/reference/te.md),
[`pm()`](https://data-wise.github.io/medfit/reference/pm.md)

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

paths(med_data)
#>         a         b   c_prime 
#> 0.4475284 0.4238113 0.1549228 
```
