# Tidy, Glance, and Inference Methods for medfit Objects

[`tidy()`](https://generics.r-lib.org/reference/tidy.html) converts a
mediation data object or a
[BootstrapResult](https://data-wise.github.io/medfit/reference/BootstrapResult.md)
into a tidy tibble, one row per path coefficient or effect.
[`glance()`](https://generics.r-lib.org/reference/glance.html) returns a
one-row summary. The base generics
[`stats::coef()`](https://rdrr.io/r/stats/coef.html),
[`stats::vcov()`](https://rdrr.io/r/stats/vcov.html),
[`stats::confint()`](https://rdrr.io/r/stats/confint.html), and
[`stats::nobs()`](https://rdrr.io/r/stats/nobs.html) also have methods
for every mediation class; see Details.

## Usage

``` r
tidy_s7_object(x, ...)

glance_s7_object(x, ...)
```

## Arguments

- x:

  A
  [MediationData](https://data-wise.github.io/medfit/reference/MediationData.md),
  [SerialMediationData](https://data-wise.github.io/medfit/reference/SerialMediationData.md),
  [ParallelMediationData](https://data-wise.github.io/medfit/reference/ParallelMediationData.md),
  [InteractionMediationData](https://data-wise.github.io/medfit/reference/InteractionMediationData.md),
  [JointMediationData](https://data-wise.github.io/medfit/reference/JointMediationData.md),
  [ClusterMediationData](https://data-wise.github.io/medfit/reference/ClusterMediationData.md),
  [BootstrapResult](https://data-wise.github.io/medfit/reference/BootstrapResult.md),
  or [SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)
  object (a `SEMFit` has its own columns; see
  [SEMFit-methods](https://data-wise.github.io/medfit/reference/SEMFit-methods.md)).

- ...:

  Passed to the class method: `type` (`"all"`, `"paths"`, `"effects"`,
  and for interaction objects `"components"`), `conf_int` (logical, add
  `conf_low`/`conf_high`), and `conf_level` (default 0.95).

## Value

[`tidy()`](https://generics.r-lib.org/reference/tidy.html): a tibble (a
data frame if tibble is not installed) with columns `term`, `estimate`,
`std_error`, and, when `conf_int = TRUE`, `conf_low` and `conf_high`.

[`glance()`](https://generics.r-lib.org/reference/glance.html): a
one-row tibble with `nie`, `nde`, `te`, `pm`, `nobs`, and `converged`;
interaction objects add `interaction` and `m_star`, and joint objects
add `cde`, `structure`, `n_mediators`, `interactions`, and `m_star`.

## Details

Path standard errors are the square roots of the diagonal of `@vcov`.
Effect standard errors (NIE, NDE, TE, and for interaction objects the
four-way components) use the delta method over the full `@vcov`, the
same computation as `confint(parm = "effects")`, so
`tidy(conf_int = TRUE)` reproduces
[`confint()`](https://rdrr.io/r/stats/confint.html) exactly. Intervals
are normal approximations (\\\hat{\theta} \pm z \\ SE\\); the sampling
distribution of a product of coefficients is skewed, so for inference on
indirect effects prefer
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md).
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) raises no
warning about this; [`confint()`](https://rdrr.io/r/stats/confint.html)
does.

For a serial chain fitted as separate lm/glm regressions, `@vcov` has
zero covariances between equations, and the effect standard errors
inherit that. The proportion mediated (reported by
[`glance()`](https://generics.r-lib.org/reference/glance.html)) has no
standard error: it is a ratio whose delta-method standard error is
unstable when the total effect is near zero, so bootstrap it instead.

### Bounded FIML

For data extracted from a bounded FIML fit,
[`tidy()`](https://generics.r-lib.org/reference/tidy.html),
coefficients, covariance and normal path/effect intervals are supported,
but [`glance()`](https://generics.r-lib.org/reference/glance.html),
[`pm()`](https://data-wise.github.io/medfit/reference/pm.md) and
bootstrap intervals refuse. The bootstrap recommendations above apply
only to other supported objects.
[`glance()`](https://generics.r-lib.org/reference/glance.html) on the
source [SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)
instead retains likelihood and information-criterion fields, with model
tests unavailable. See
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
for the bounded model, assumptions and inference limits.

### Base methods

- `coef(object, type = "paths")`: the path coefficients;
  `type = "effects"` gives the effects, `"all"` both, and for
  interaction objects `"components"` gives the four-way components.

- `vcov(object)`: the stored `@vcov`, covering every entry of
  `@estimates`.

- `confint(object, parm = "paths", level = 0.95)`: normal intervals for
  the paths, or with `parm = "effects"` for the effects using the
  delta-method standard errors above (interaction objects also accept
  `parm = "components"`). With `parm = "effects"` it warns that the
  normal approximation may be inaccurate for an indirect effect.

- `nobs(object)`: the number of observations.

## See also

[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md),
[MediationData](https://data-wise.github.io/medfit/reference/MediationData.md)

## Examples

``` r
med_data <- fit_mediation(
  formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
  formula_m = mediator1 ~ treatment + covariate1 + covariate2,
  data = mediation_demo,
  treatment = "treatment",
  mediator = "mediator1"
)
# tidy() is the generic from the generics package (also re-exported by broom)
generics::tidy(med_data)
#> # A tibble: 6 × 3
#>   term    estimate std_error
#>   <chr>      <dbl>     <dbl>
#> 1 a          0.583    0.0989
#> 2 b          0.571    0.0535
#> 3 c_prime    0.206    0.110 
#> 4 nie        0.333    0.0645
#> 5 nde        0.206    0.110 
#> 6 te         0.539    0.119 
generics::tidy(med_data, type = "effects", conf_int = TRUE)
#> # A tibble: 3 × 5
#>   term  estimate std_error conf_low conf_high
#>   <chr>    <dbl>     <dbl>    <dbl>     <dbl>
#> 1 nie      0.333    0.0645  0.206       0.459
#> 2 nde      0.206    0.110  -0.00936     0.421
#> 3 te       0.539    0.119   0.304       0.773
```
