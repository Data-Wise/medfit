# Methods and Formulas

This article collects, in one place, the estimands medfit computes, the
formulas behind every effect, and how each standard error and interval
is obtained. It describes what the code does; the other articles show
how to call it.

medfit computes effects from fitted models. Whether an effect has a
causal interpretation depends on identification assumptions (no
unmeasured confounding of the relevant relations), which medfit does not
check. Each section says which assumptions the estimand needs.

## Notation and conventions

| Symbol | Meaning |
|----|----|
| \\X\\ | treatment |
| \\M\\, \\M_1, \dots, M_K\\ | mediator(s) |
| \\Y\\ | outcome |
| \\C\\ | covariates (the same set in every model unless stated) |
| \\\bar c\\ | sample means of the covariate design columns |
| \\\hat\theta\\, \\\hat\Sigma\\ | stacked estimates and their covariance (`@estimates`, `@vcov`) |

Mediator models are \\M = \beta_0 + \beta_1 X + \gamma^\top C + e_M\\
and the outcome model is \\Y = \theta_0 + \theta_1 X + \theta_2 M +
\theta_4^\top C + e_Y\\, with a product term \\\theta_3 X M\\ where
noted. In the path notation medfit prints, \\a = \beta_1\\, \\b =
\theta_2\\, and \\c' = \theta_1\\.

Effects are for a **unit contrast** of the treatment (from \\x\\ to
\\x + 1\\; from 0 to 1 when the treatment is binary). The four-way and
joint decompositions use the contrast from 0 to 1 and linear (Gaussian
identity-link) models. The simple, serial and parallel products apply to
any continuous or binary treatment with linear models. A non-identity
link (for example a logistic outcome) puts `b` and `c'` on the link
scale, where the product \\a b\\ is no longer a natural indirect effect
on the outcome scale.

## Which object you get

| Fit | Class | Indirect effect |
|----|----|----|
| one mediator, no product | `MediationData` | \\a b\\ |
| one mediator, \\X \times M\\ in the outcome | `InteractionMediationData` | \\\text{INTmed} + \text{PIE}\\ |
| several mediators in a chain, no product | `SerialMediationData` | \\a \\ d_1 \cdots d\_{K-1} \\ b\\ (chain; `type = "total"` for all paths) |
| several mediators, not chained, no product | `ParallelMediationData` | \\\sum_j a_j b_j\\ |
| several mediators, \\X \times M_i\\ in the outcome | `JointMediationData` | joint NIE through all mediators |

[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
chooses the class from the models;
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
fits single-mediator models and returns the first two.

## Simple mediation

With one mediator and no product term,

\\ \text{NIE} = a b, \qquad \text{NDE} = c', \qquad \text{TE} = a b +
c', \qquad \text{PM} = \frac{\text{NIE}}{\text{TE}} . \\

[`pm()`](https://data-wise.github.io/medfit/reference/pm.md) returns
`NA` with a warning when \\\|\text{TE}\|\\ is numerically zero, because
the ratio is undefined; it has no standard error for the same reason
(bootstrap it instead).

Read causally, NIE and NDE are the natural indirect and direct effects
under no unmeasured treatment–outcome, mediator–outcome and
treatment–mediator confounding given \\C\\, and no mediator–outcome
confounder affected by the treatment.

## Serial mediation (chain)

For a chain \\X \to M_1 \to \cdots \to M_K \to Y\\ fit as separate
regressions (each \\M_j\\ on \\X\\, the earlier mediators and \\C\\; the
outcome on \\X\\, all mediators and \\C\\),
[`nie()`](https://data-wise.github.io/medfit/reference/nie.md) reports
by default the effect through the **full chain only**:

\\ \text{NIE}\_{\text{chain}} = a \\ d_1 \cdots d\_{K-1} \\ b , \\

where \\a\\ is the \\X\\ coefficient of \\M_1\\, \\d_j\\ the coefficient
of \\M_j\\ in the model for \\M\_{j+1}\\, and \\b\\ the coefficient of
\\M_K\\ in the outcome model. Paths that skip a mediator (for example
\\X \to M_2 \to Y\\, or \\M_1 \to Y\\ directly) are not part of it.
`nie(x, type = "total")` returns the total indirect effect, the sum over
every path from \\X\\ to \\Y\\ through at least one mediator; with two
mediators it is \\a_1 b_1 + a_2 b_2 + a_1 d \\ b_2\\, the same as the
joint NIE below when there is no product term.

[`te()`](https://data-wise.github.io/medfit/reference/te.md) is the full
total effect, the sum over every directed path from \\X\\ to \\Y\\,
including \\c'\\:

\\ \text{TE} = \big\[(I - B)^{-1}\big\]\_{Y,X}, \qquad \text{TE} = c' +
a_1 b_1 + a_2 b_2 + a_1 d \\ b_2 \quad (K = 2), \\

where \\B\\ holds the path coefficients among \\(X, M_1, \dots, M_K,
Y)\\. With linear models and the same covariates in every equation it
equals the treatment coefficient of the outcome regressed on the
treatment and covariates alone.
[`pm()`](https://data-wise.github.io/medfit/reference/pm.md) is the
total indirect effect divided by
[`te()`](https://data-wise.github.io/medfit/reference/te.md). The
skip-path coefficients are stored as `a2`, …, `b1`, …, and `d1_3`-style
aliases in `@estimates`, and the delta-method standard error of
[`te()`](https://data-wise.github.io/medfit/reference/te.md)
differentiates the whole sum. A path that is not in its model counts as
zero; a hand-built object that lists a path without its coefficient gets
`NA` and a warning.

A causal reading of the chain effect needs the simple-mediation
assumptions for every mediator, plus no unmeasured confounding of each
mediator–mediator relation.

## Parallel mediation

With mediators that do not affect each other, each \\M_j\\ regressed on
\\X\\ and \\C\\ and all of them in one outcome model,

\\ \text{NIE} = \sum\_{j=1}^{K} a_j b_j , \qquad \text{NDE} = c' . \\

The sum is the effect through the mediators together. Reading each \\a_j
b_j\\ as the effect through \\M_j\\ alone additionally requires that the
mediators do not affect one another.

## Treatment–mediator interaction: the four-way decomposition

When the outcome model carries \\\theta_3 X M\\,
`InteractionMediationData` splits the total effect of a 0/1 treatment
into four components (VanderWeele 2014), with reference mediator level
\\m^\*\\ (`m_star`, default 0):

\\ \begin{aligned} \text{CDE} &= \theta_1 + \theta_3 m^\* \\
\text{INT}\_{\text{ref}} &= \theta_3 \left( E\[M \mid X = 0, \bar c\] -
m^\* \right) \\ \text{INT}\_{\text{med}} &= \theta_3 \beta_1 \\
\text{PIE} &= \theta_2 \beta_1 \end{aligned} \\

with \\E\[M \mid X = 0, \bar c\] = \beta_0 + \gamma^\top \bar c\\,
\\\text{NDE} = \text{CDE} + \text{INT}\_{\text{ref}}\\, \\\text{NIE} =
\text{INT}\_{\text{med}} + \text{PIE}\\, and \\\text{TE} = \text{NDE} +
\text{NIE}\\. NDE, NIE and TE do not depend on \\m^\*\\; only the split
of the NDE between CDE and INT_(ref) does. The assumptions are those of
simple mediation; the CDE alone needs only no unmeasured
treatment–outcome and mediator–outcome confounding. With \\\theta_3 =
0\\ the decomposition reduces to simple mediation. The
`InteractionMediationData` validator checks each identity when the
object is built.

## Several mediators with products: joint natural effects

When a serial or parallel fit has treatment-by-mediator products in the
outcome model,

\\ Y = \theta_0 + \theta_1 X + \sum_i \theta\_{2i} M_i + \sum\_{i \in I}
\theta\_{3i} X M_i + \theta_4^\top C + e_Y , \\

`JointMediationData` reports the **joint** natural effects of the
mediators as a block (VanderWeele and Vansteelandt 2014), where \\I\\ is
the set of mediators with a product (\\\theta\_{3i} = 0\\ otherwise).
The formulas need each mediator’s mean given the treatment and
covariates only. For a serial chain, whose models condition on earlier
mediators, medfit obtains these by substitution down the chain:

\\ \beta^\*\_{1i} = \beta\_{1i} + \sum\_{j\<i} d\_{ij}\\ \beta^\*\_{1j},
\qquad \mu^\*\_{0i} = \beta\_{0i} + \gamma_i^\top \bar c + \sum\_{j\<i}
d\_{ij}\\ \mu^\*\_{0j}, \\

where \\d\_{ij}\\ is the coefficient of \\M_j\\ in the model for \\M_i\\
(\\d\_{ij} = 0\\ for parallel mediators, so the raw and propagated
coefficients coincide). \\\beta^\*\_{1i}\\ is the total effect of the
treatment on \\M_i\\, printed as `a*`, and \\\mu^\*\_{0i}\\ is \\E\[M_i
\mid X = 0, \bar c\]\\. Then

\\ \begin{aligned} \text{NIE} &= \sum_i (\theta\_{2i} + \theta\_{3i})\\
\beta^\*\_{1i} \\ \text{NDE} &= \theta_1 + \sum\_{i \in I}
\theta\_{3i}\\ \mu^\*\_{0i} \\ \text{CDE} &= \theta_1 + \sum\_{i \in I}
\theta\_{3i}\\ m^\*\_i \\ \text{TE} &= \text{NDE} + \text{NIE}
\end{aligned} \\

`m_star` is a scalar or a vector named by the interacting mediators.
With one mediator these are the four-way NDE, NIE and CDE above.

The NIE is the effect through the mediators together; there is no
per-mediator split, and no part of it is “the effect through \\M_1\\”.
The identifying assumptions are stated for the whole mediator vector: no
unmeasured treatment–outcome, mediators–outcome or treatment–mediators
confounding, and no mediator–outcome confounder affected by the
treatment **outside the mediator vector**. Earlier mediators in a chain
are affected by the treatment and confound later ones; that is allowed
because they belong to the vector.

medfit requires every model to carry the same covariates, Gaussian
identity-link unweighted fits with intercepts on the same rows, every
mediator in the outcome model, and mediators listed in causal order;
each violation errors. A product written in the formula (`X * M1`,
`X:M1`) is recognized; a product precomputed as a data column is not,
and would be ignored silently.

## Covariance of the estimates

Every effect’s standard error comes from \\\hat\Sigma\\ (`@vcov`), whose
rows are named by the model coefficients and by path aliases (`a`, `b`,
`c_prime`, `d1`, `a1`, `b2`, `theta3`, …).

**lm/glm engines.** Each equation’s block is its model’s
[`vcov()`](https://rdrr.io/r/stats/vcov.html) (or, with
`fit_mediation(se_type = "sandwich")`, the HC3 sandwich estimator
`sandwich::vcovHC(type = "HC3")`, recommended with inverse-probability
`weights`). For ordinary least squares fits of several equations to the
same rows, the covariance between two equations’ coefficients is

\\ \operatorname{Cov}(\hat\beta_e, \hat\beta_f) = \hat\sigma\_{ef}\\
(X_e^\top X_e)^{-1} X_e^\top X_f\\ (X_f^\top X_f)^{-1}, \\

where \\\hat\sigma\_{ef}\\ is the residual cross-product. It is exactly
zero when one equation’s residual lies in the other’s column space,
which holds when the later equation contains every regressor of the
earlier one. So for simple mediation, serial chains and the four-way
model with shared covariates, the cross-equation blocks are zero and a
block-diagonal \\\hat\Sigma\\ is exact.

- `SerialMediationData`, `ParallelMediationData`, `MediationData` and
  `InteractionMediationData` from lm/glm store a block-diagonal
  \\\hat\Sigma\\. For parallel mediators whose errors are correlated
  this omits the \\\operatorname{Cov}(a_j, a\_{j'})\\ term, so the NIE
  standard error can be off.
- `JointMediationData` stores the full stacked covariance above, with
  \\\hat\sigma\_{ef}\\ scaled by \\\sqrt{(n - p_e)(n - p_f)}\\ so each
  diagonal block equals its model’s
  [`vcov()`](https://rdrr.io/r/stats/vcov.html). Only parallel mediator
  pairs have non-zero cross-blocks. It refuses a non-default `vcov_fun`,
  because the formula assumes OLS.

**lavaan engine.** A single
[`sem()`](https://rdrr.io/pkg/lavaan/man/sem.html) fit estimates all
equations jointly, so \\\hat\Sigma\\ carries every covariance. For the
same data its intervals can differ from the lm/glm ones.

## Delta-method standard errors

For an effect \\g(\theta)\\, the delta-method variance is \\\nabla
g^\top \hat\Sigma \\ \nabla g\\, evaluated at \\\hat\theta\\. medfit
uses one gradient builder per class, shared by
`confint(parm = "effects")`,
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
[`summary()`](https://rdrr.io/r/base/summary.html), so they agree
exactly. The gradients are analytic:

| Class | Effect | Non-zero partial derivatives |
|----|----|----|
| Simple | NIE \\= ab\\ | \\\partial/\partial a = b\\, \\\partial/\partial b = a\\ |
| Serial | NIE \\= a \prod d_j \\ b\\ | each factor: the product of the others |
| Serial | TE \\= \[(I - B)^{-1}\]\_{Y,X}\\ | on each path \\f \to t\\: \\\[(I - B)^{-1}\]\_{Y,t} \\ \[(I - B)^{-1}\]\_{f,X}\\, the sum of the path products through it with it removed; the total NIE drops \\c'\\ |
| Parallel | NIE \\= \sum a_j b_j\\ | \\\partial/\partial a_j = b_j\\, \\\partial/\partial b_j = a_j\\ |
| all three | NDE \\= c'\\ | \\1\\ on \\c'\\ |
| Simple, parallel | TE | the sum of the NIE and NDE gradients |
| Four-way | CDE, INT_(ref), INT_(med), PIE | in \\\theta_1, \theta_2, \theta_3, \beta_0, \beta_1\\ and the covariate coefficients (weighted by \\\bar c\\) |
| Joint | NIE | \\\lambda_j\\ on \\\beta\_{1j}\\, \\\lambda_i \beta^\*\_{1j}\\ on \\d\_{ij}\\, \\\beta^\*\_{1i}\\ on \\\theta\_{2i}\\ and \\\theta\_{3i}\\ |
| Joint | NDE | \\1\\ on \\\theta_1\\, \\\mu^\*\_{0i}\\ on \\\theta\_{3i}\\, \\\kappa_j\\ on \\\beta\_{0j}\\, \\\kappa_j \bar c\\ on \\\gamma_j\\, \\\kappa_i \mu^\*\_{0j}\\ on \\d\_{ij}\\ |

For the joint effects the chain rule through the propagated terms is
carried by backward recursions, \\\lambda_j = (\theta\_{2j} +
\theta\_{3j}) + \sum\_{i\>j} d\_{ij} \lambda_i\\ and \\\kappa_j =
\theta\_{3j} + \sum\_{i\>j} d\_{ij} \kappa_i\\.

The covariate means \\\bar c\\ are treated as fixed, so standard errors
that involve them (the four-way INT_(ref) and the joint NDE) are
conditional on the observed covariates; they slightly understate the
uncertainty of a population-average effect.

**Intervals.** [`confint()`](https://rdrr.io/r/stats/confint.html) and
`tidy(conf.int = TRUE)` report normal intervals, \\\hat g \pm
z\_{1-\alpha/2}\\ \widehat{\text{SE}}\\. The sampling distribution of a
product of coefficients is skewed, so these can be inaccurate for
indirect effects; [`confint()`](https://rdrr.io/r/stats/confint.html)
warns about this for effects,
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) stays silent.
Prefer a bootstrap for inference on an indirect effect.

## Bootstrap

[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
has three methods, each returning a `BootstrapResult` with the point
estimate and a **percentile** interval (the \\\alpha/2\\ and \\1 -
\alpha/2\\ quantiles of the bootstrap distribution).

- **Parametric**: draws \\\theta^{\*(r)} \sim N(\hat\theta,
  \hat\Sigma)\\, \\r = 1, \dots, R\\ (`n_boot`), and applies
  `statistic_fn` to each named draw. Fast; it assumes the estimates are
  approximately normal and inherits \\\hat\Sigma\\ (including its block
  structure).
- **Nonparametric**: resamples rows with replacement, refits the models,
  and recomputes the statistic. Slower; it needs no normality assumption
  and captures every covariance, including the covariate means.
- **Plugin**: evaluates the statistic at \\\hat\theta\\ only, with no
  interval.

`statistic_fn` receives the named `@estimates` vector. For the simple,
serial and parallel classes the aliases suffice (for example
`function(theta) theta[["a"]] * theta[["b"]]`). The joint NDE also needs
the intercept and covariate rows and \\\bar c\\; use
[`joint_effects()`](https://data-wise.github.io/medfit/reference/joint_effects.md)
as the statistic:

``` r
bootstrap_mediation(
  function(theta) joint_effects(fit, theta)[["nie"]],
  method = "parametric", mediation_data = fit, n_boot = 2000
)
```

## Fitting engines

`fit_mediation(engine = "glm")` fits the mediator and outcome models
with [`glm()`](https://rdrr.io/r/stats/glm.html) and passes them to
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md),
so every formula above applies. `engine = "regmedint"` delegates to
[`regmedint::regmedint()`](https://kaz-yos.github.io/regmedint/reference/regmedint.html),
a closed-form regression-based implementation, and maps its point
estimates and its own delta-method covariance of the effects onto
`MediationData` or `InteractionMediationData`. The adapter requires a
linear mediator model and a unit treatment contrast; see
[`?fit_mediation`](https://data-wise.github.io/medfit/reference/fit_mediation.md).
For a non-Gaussian outcome model the components are on that model’s link
scale, as regmedint reports them.

## References

VanderWeele, T. J. (2014). A unification of mediation and interaction: A
4-way decomposition. *Epidemiology*, 25(5), 749–761.

VanderWeele, T. J., & Vansteelandt, S. (2014). Mediation analysis with
multiple mediators. *Epidemiologic Methods*, 2(1), 95–115.
<https://doi.org/10.1515/em-2012-0010>
