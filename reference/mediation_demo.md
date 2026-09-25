# Simulated Mediation Data for Examples

A simulated dataset for demonstrating medfit's simple, serial, parallel,
and treatment-by-mediator interaction workflows with one running
example. The data are **simulated**: they describe no real study,
population, or finding.

## Usage

``` r
mediation_demo
```

## Format

A data frame with 400 rows and 8 variables:

- treatment:

  Integer, 0/1. Randomized treatment assignment.

- mediator1:

  Numeric. First mediator; affected by `treatment`.

- mediator2:

  Numeric. Serial mediator; affected by `treatment` and `mediator1`.

- mediator3:

  Numeric. Parallel mediator; affected by `treatment` only.

- covariate1:

  Numeric. Continuous confounder of the mediator-outcome relations.

- covariate2:

  Integer, 0/1. Binary confounder of the mediator-outcome relations.

- outcome:

  Numeric. Outcome with no product terms; use it for the simple, serial,
  and parallel models.

- outcome_int:

  Numeric. `outcome` plus a `treatment` by `mediator1` interaction; use
  it only for models with that interaction: the four-way decomposition
  with a single mediator, or joint effects with several mediators
  ([JointMediationData](https://data-wise.github.io/medfit/reference/JointMediationData.md)).

## Source

Simulated for package demonstration; not drawn from or representing any
real study. The generating script is `data-raw/mediation_demo.R` in the
package source repository.

## Details

The variables follow a fictional workplace-training story, used only so
the examples read concretely: randomized assignment to a training
program (`treatment`) raises skill confidence (`mediator1`), which
builds task mastery (`mediator2`); the assignment also triggers
supervisor check-ins (`mediator3`); `outcome` is job performance.

All errors are independent standard normal. The generating equations are
\$\$M_1 = 0.5X + 0.3C_1 + 0.3C_2 + e_1\$\$ \$\$M_2 = 0.2X + 0.5M_1 +
0.2C_1 + e_2\$\$ \$\$M_3 = 0.5X + e_3\$\$ \$\$Y = 0.2X + 0.4M_1 +
0.3M_2 + 0.3M_3 + 0.3C_1 + 0.2C_2 + e_4\$\$ and `outcome_int` adds \\0.5
X M_1\\.

Because the covariates confound the mediator-outcome relations, every
model should adjust for both `covariate1` and `covariate2`. A model that
omits a downstream mediator estimates reduced-form coefficients rather
than the structural ones above: for example, the simple model
`outcome ~ treatment + mediator1 + covariates` has limiting coefficients
0.55 for `mediator1` and 0.41 for `treatment`. For a serial model,
include `mediator1` in the outcome model as well; the serial indirect
effect \\a \times d \times b\\ is then the effect through the chain
`mediator1` to `mediator2` only.

## Examples

``` r
data(mediation_demo)
str(mediation_demo)
#> 'data.frame':    400 obs. of  8 variables:
#>  $ treatment  : int  1 1 1 1 1 0 1 0 0 1 ...
#>  $ mediator1  : num  1.045 0.872 1.053 1.898 -0.89 ...
#>  $ mediator2  : num  1 0.598 1.017 2.046 -2.256 ...
#>  $ mediator3  : num  1.669 2.148 0.464 1.219 1.295 ...
#>  $ covariate1 : num  0.921 -1.253 0.665 1.14 0.285 ...
#>  $ covariate2 : int  1 1 1 1 0 1 1 0 0 0 ...
#>  $ outcome    : num  0.0951 -0.4877 1.817 2.2182 1.1867 ...
#>  $ outcome_int: num  0.6176 -0.0516 2.3433 3.1671 0.7416 ...

# Simple mediation, adjusting for both covariates
fit <- fit_mediation(
  formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
  formula_m = mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1"
)
nie(fit)
#> Natural Indirect Effect (NIE): 0.3328
```
