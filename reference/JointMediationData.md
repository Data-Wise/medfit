# JointMediationData: Joint Natural Effects of Multiple Mediators

S7 class for the **joint** natural effects of two or more mediators,
serial or parallel, when the outcome model may contain
treatment-by-mediator product terms (VanderWeele and Vansteelandt 2014).
The mediators are treated as one block: the natural indirect effect
(NIE) runs through every mediator and every path among them, and the
natural direct effect (NDE) is the remainder. medfit computes the
effects; causal interpretation is the user's responsibility.

## Usage

``` r
JointMediationData(structure, mediators, treatment, outcome, interactions,
  a_total, b_paths, theta3, c_prime, cde, nde, nie, total_effect, m_star,
  estimates, vcov, data, n_obs, converged, source_package)
```

## Arguments

- structure:

  Single string, `"serial"` or `"parallel"`.

- mediators:

  Character vector of mediator names, in causal order.

- treatment, outcome:

  Single character strings.

- interactions:

  Character vector naming the mediators that carry a
  treatment-by-mediator product in the outcome model (may be empty).

- a_total:

  Numeric vector named by `mediators`: total effect of the treatment on
  each mediator (\\\beta^\*\_{1i}\\).

- b_paths:

  Numeric vector named by `mediators`: outcome main effect of each
  mediator (\\\theta\_{2i}\\).

- theta3:

  Numeric vector named by `interactions`: product coefficients
  (\\\theta\_{3i}\\).

- c_prime:

  Numeric scalar: treatment main effect on the outcome (\\\theta_1\\).

- cde, nde, nie, total_effect:

  Numeric scalars: controlled direct, natural direct, natural indirect
  and total effects.

- m_star:

  Numeric vector named by `interactions`: reference mediator levels for
  the CDE.

- estimates:

  Named numeric vector of parameter estimates.

- vcov:

  Square variance-covariance matrix of `estimates`.

- data:

  Optional data frame, or NULL.

- n_obs:

  Integer number of observations.

- converged:

  Logical convergence flag.

- source_package:

  Character name of the originating package.

## Value

A `JointMediationData` S7 object.

## Details

With outcome model \\Y = \theta_1 X + \sum_i (\theta\_{2i} +
\theta\_{3i} X) M_i + \dots\\ and \\\beta^\*\_{1i}\\ the total
(propagated) effect of the treatment on mediator \\i\\ (for a serial
chain this includes the paths through earlier mediators), the
unit-contrast effects are \$\$NIE = \sum_i (\theta\_{2i} + \theta\_{3i})
\beta^\*\_{1i}\$\$ \$\$NDE = \theta_1 + \sum_i \theta\_{3i}
\mu^\*\_{0i}\$\$ \$\$CDE = \theta_1 + \sum_i \theta\_{3i} m^\*\_i\$\$
and \\TE = NDE + NIE\\. \\\theta\_{3i}\\ is zero for a mediator without
a product term, and \\\mu^\*\_{0i}\\ is the mean of mediator \\i\\ under
no treatment at the covariate means (propagated down a serial chain like
\\\beta^\*\_{1i}\\). The validator enforces the NIE and CDE identities,
so an object with inconsistent numbers cannot be built.

### What the joint NIE is, and is not

The NIE is the effect through the mediators **as a block**: every path
from the treatment through any mediator, including paths among the
mediators. It is not split into per-mediator or per-path pieces, and
none of its parts should be reported as the effect "through M1". For a
serial chain it therefore differs from the default
[`nie()`](https://data-wise.github.io/medfit/reference/nie.md) of a
[SerialMediationData](https://data-wise.github.io/medfit/reference/SerialMediationData.md)
(`a * d * b`, the effect through the full chain only): with no product
term, the joint NIE of `M1 -> M2` is \\a_1 b_1 + (a_2 + d a_1) b_2\\,
not \\a_1 d b_2\\. The effects use the unit contrast of a 0/1 treatment
(0 to 1).

### Assumptions

The joint effects are identified under no-unmeasured-confounding
assumptions stated for the whole mediator vector: none for the treatment
and outcome, none for the mediators and the outcome, none for the
treatment and the mediators, and no mediator-outcome confounder affected
by the treatment **outside the mediator vector** (VanderWeele and
Vansteelandt 2014). In a serial chain the earlier mediators are affected
by the treatment and confound the later ones; that is allowed precisely
because they are part of the vector. Mediator-outcome and
treatment-mediator confounders must be controlled for **every**
mediator.

### medfit's requirements

- Every model (each mediator model and the outcome model) must carry the
  **same covariates**. This is a medfit limitation that keeps the
  serial-chain algebra and the covariance exact, not a requirement of
  the method; differing sets error, naming the terms.

- The models must be Gaussian with the identity link, unweighted, with
  an intercept, fit to the same rows; every mediator must appear in the
  outcome model; `mediator` lists the mediators in causal order.

- A product must be written in the outcome formula with `:` or `*`. A
  product **precomputed as a data column** (for example `XM <- X * M1`
  added to the data and then used as `Y ~ X + M1 + M2 + XM`) cannot be
  recognized from the formula: medfit treats it as an ordinary covariate
  and the effects ignore the interaction, with no error. Write `X * M1`
  in the formula instead.

### Covariates and standard errors

The NDE depends on the covariates; it is evaluated at their sample
means. The effects are linear in the covariates, so this equals the
sample average of the per-observation effects. Standard errors use the
delta method with analytic gradients over a stacked-OLS covariance that
includes the correlation between parallel mediator equations. They treat
the covariate means as fixed, so they are conditional on the observed
covariates and slightly understate the uncertainty of a
population-average effect. For a parametric bootstrap use
[`joint_effects()`](https://data-wise.github.io/medfit/reference/joint_effects.md)
as the statistic.

## References

VanderWeele, T. J., & Vansteelandt, S. (2014). Mediation analysis with
multiple mediators. *Epidemiologic Methods*, 2(1), 95–115.
[doi:10.1515/em-2012-0010](https://doi.org/10.1515/em-2012-0010)

## Examples

``` r
# Hand-built parallel object with an X x M2 product (m2* = 0)
jmd <- JointMediationData(
  structure = "parallel", mediators = c("M1", "M2"),
  treatment = "X", outcome = "Y", interactions = "M2",
  a_total = c(M1 = 0.5, M2 = 0.3), b_paths = c(M1 = 0.3, M2 = 0.4),
  theta3 = c(M2 = 0.2), c_prime = 0.1,
  cde = 0.1, nde = 0.12, nie = 0.33, total_effect = 0.45,
  m_star = c(M2 = 0),
  estimates = c(a1 = 0.5, a2 = 0.3, b1 = 0.3, b2 = 0.4,
                theta3_M2 = 0.2, c_prime = 0.1),
  vcov = diag(0.01, 6),
  n_obs = 200L, converged = TRUE, source_package = "medfit"
)
jmd@nie  # (0.3 + 0) * 0.5 + (0.4 + 0.2) * 0.3 = 0.33
#> [1] 0.33
```
