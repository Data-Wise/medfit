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
| treatment assigned to whole clusters, `lmer` fits | `ClusterMediationData` | \\a \\ b_B\\, split into own \\a \\ b_W\\ and spillover \\a (b_B - b_W)\\ |

[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
chooses the class from the models;
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
fits single-mediator models and returns the first two, or, with
`engine = "lmer"` and a `cluster`, the cluster class.

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
object is built. A native
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
fit with the product `x:m` in the outcome equation gives the same object
([the native product term](#products-and-observed-information)).

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

## Cluster-level treatment: the 2-1-1 design

### Model and effects

When the treatment \\X_j\\ is assigned to whole clusters \\j = 1, \dots,
J\\ (for example schools) and the mediator \\M\_{ij}\\ and outcome
\\Y\_{ij}\\ are measured on the \\n_j\\ individuals in each, medfit uses
the observed cluster mean \\\bar M_j\\ of the mediator over the analysis
rows. With cluster-level covariates \\W_j\\ and level-1 covariates
\\C\_{ij}\\ (entered centered, with their cluster means),

\\ \begin{aligned} M\_{ij} &= \beta_0 + a X_j + \beta_2^\top C\_{ij} +
\beta_3^\top W_j + v_j + r\_{ij}, \\ Y\_{ij} &= \theta_0 + c' X_j + b_W
(M\_{ij} - \bar M_j) + b_B \bar M_j + \theta_4^\top (C\_{ij} - \bar
C_j) + \theta_5^\top \bar C_j + \theta_6^\top W_j + u_j + e\_{ij},
\end{aligned} \\

with random cluster intercepts \\v_j\\ and \\u_j\\. The raw
parameterization writes \\b_W M\_{ij} + \kappa \bar M_j\\ instead, so
\\b_B = b_W + \kappa\\ (identity R1, a medfit-side derivation); medfit
finds these terms **by value** (constant within clusters and an exact
affine function of \\\bar M_j\\, and so on), so grand-mean centering and
[`scale()`](https://rdrr.io/r/base/scale.html) work, and maps the raw
form to the within form with \\\hat\Sigma\\ transformed as \\J
\hat\Sigma J^\top\\.

| Effect | Formula | Accessor |
|----|----|----|
| NIE | \\a \\ b_B\\ | [`nie()`](https://data-wise.github.io/medfit/reference/nie.md) |
| NDE | \\c'\\ | [`nde()`](https://data-wise.github.io/medfit/reference/nde.md) |
| TE | \\a \\ b_B + c'\\ | [`te()`](https://data-wise.github.io/medfit/reference/te.md) |
| Own-mediator (within) indirect | \\a \\ b_W\\ | [`decompose()`](https://data-wise.github.io/medfit/reference/decompose.md) |
| Spillover (contextual) indirect | \\a (b_B - b_W)\\ | [`decompose()`](https://data-wise.github.io/medfit/reference/decompose.md) |

### Indirect effect and the own/spillover split

**The NIE needs no weighting.** Changing \\X_j\\ shifts every member’s
mediator by \\a\\. The deviations \\M\_{ij} - \bar M_j\\ do not change
and \\\bar M_j\\ moves by \\a\\, so \\Y\\ moves by \\a \\ b_B\\ in every
cluster. This holds with a random slope on the within term, because
\\X\\ is constant within a cluster and \\\bar M_j\\ carries no slope
(medfit’s argument).

**The own/spillover split is an approximation.** Shifting only
individual \\i\\’s mediator by \\a\\ moves \\\bar M_j\\ by \\a / n_j\\,
so with the observed cluster mean the exact effects in a cluster of
\\n_j\\ members are

\\ \text{own} = a \Big\[ b_W + \frac{b_B - b_W}{n_j} \Big\], \qquad
\text{spillover} = a (b_B - b_W) \frac{n_j - 1}{n_j}, \\

which add to \\a \\ b_B\\ at every cluster size. Expanding the outcome
model in the members’ mediators gives the derivation: member \\i\\’s own
mediator enters once in the deviation and once in the mean, with
coefficient \\b_W + (b_B - b_W) / n_j\\, and each of the \\n_j - 1\\
peers’ enters only through the mean, with coefficient \\(b_B - b_W) /
n_j\\; every mediator moves by \\a\\.

medfit’s tests check the formulas against exact counterfactuals.
[`decompose()`](https://data-wise.github.io/medfit/reference/decompose.md)
reports the large-cluster limits \\a \\ b_W\\ and \\a (b_B - b_W)\\,
labeled the cluster-average, large-cluster approximation. The own
estimate is off by \\a (b_B - b_W) / H\\ with equal cluster weights,
\\H\\ the harmonic mean cluster size, and
[`decompose()`](https://data-wise.github.io/medfit/reference/decompose.md)
warns when that gap exceeds half the own effect’s standard error;
[`summary()`](https://rdrr.io/r/base/summary.html) always prints it.

Under the peer-mean model of Talloen et al. (2016, p. 364), whose
outcome equation has a coefficient \\b_p\\ on the member’s own mediator
and \\g\\ on the mean of the other members, a fixed cluster size \\N\\
gives \\b_W = b_p - g / (N - 1)\\ and \\b_B = b_p + g\\. The exact own
effect is then \\a \\ b_p\\, Talloen et al.’s own-mediator effect, while
the reported \\a \\ b_W\\ differs from it by \\a g / N\\ (not zero).

### Covariance and assumptions

**Covariance.** Given \\(X, M, C, W)\\ the outcome errors have mean zero
under the model and \\\hat a\\ depends only on \\(X, M, C, W)\\, so
\\\text{Cov}(\hat a, \hat b_B)\\ and \\\text{Cov}(\hat a, \hat c')\\ are
zero to first order, and `@vcov` is block-diagonal between the mediator
model and the outcome model (a simulation gate checks the
cross-replication correlation of \\\hat a\\ and \\\hat b_B\\). The
argument fails under upper-level mediator–outcome confounding, the same
condition that biases the NIE.

**What the estimands need.** In every row the models are linear with no
mediator-by-treatment or mediator-by-covariate products, \\X\\ is
randomized, and clusters are intact.

| Quantity | Also needs |
|----|----|
| Own \\a \\ b_W\\ | no unmeasured lower-level mediator–outcome confounding; unmeasured upper-level confounders are allowed if additive, **provided level-1 covariates are cluster-mean centered** |
| Spillover, NIE, NDE | also no unmeasured upper-level mediator–outcome confounding; under it the direct and contextual estimators are biased while their sum \\c' + a \kappa\\ is not |
| TE | nothing beyond randomization |
| The own/spillover split | a cross-world assumption across individuals in a cluster; no treatment-induced mediator–outcome confounding |
| All | interference only through the observed cluster mean, none between clusters; members missing from the analysis rows do not drive their peers’ outcomes (the observed cluster mean stands for the realized mean of every member; with a sample of each cluster it is a noisy stand-in and the contextual effect \\b_B - b_W\\ is biased toward zero, Lüdtke et al. 2008) |

[`print()`](https://rdrr.io/r/base/print.html) and
[`summary()`](https://rdrr.io/r/base/summary.html) print this table,
with the upper-level claim dropped when a level-1 covariate has no
cluster-mean companion.

### Estimation

**Estimation.** Pass the mediator model and the outcome model, both
fitted by [`lme4::lmer()`](https://rdrr.io/pkg/lme4/man/lmer.html) on
the same rows, to
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md),
or let `fit_mediation(engine = "lmer", cluster = )` build them: it drops
incomplete rows once, forms `<M>_cm` and `<M>_cwc` (and the same for
each level-1 covariate) on the remaining rows, and fits both models by
REML with a random cluster intercept. Standard errors are the
delta-method standard errors of the section below, from lme4’s
model-based covariance.

``` r
library(medfit)
```


    Attaching package: 'medfit'

    The following object is masked from 'package:stats':

        decompose

``` r
library(generics)
```


    Attaching package: 'generics'

    The following objects are masked from 'package:base':

        as.difftime, as.factor, as.ordered, intersect, is.element, setdiff,
        setequal, union

``` r
set.seed(2026)
J <- 40
n <- 10
cl <- rep(seq_len(J), each = n)
x_j <- sample(rep(0:1, length.out = J))
v <- rnorm(J, sd = 0.5)
u <- rnorm(J, sd = 0.5)
cdat <- data.frame(school = factor(cl), X = x_j[cl])
cdat$M <- 0.5 * cdat$X + v[cl] + rnorm(J * n)
mbar <- ave(cdat$M, cdat$school)
cdat$Y <- 0.2 * cdat$X + 0.3 * (cdat$M - mbar) + 0.6 * mbar + u[cl] + rnorm(J * n)

fit <- fit_mediation(
  Y ~ X + M, M ~ X, data = cdat, treatment = "X", mediator = "M",
  engine = "lmer", cluster = "school"
)
tidy(fit, type = "effects", conf_int = TRUE)
```

    # A tibble: 5 × 5
      term      estimate std_error conf_low conf_high
      <chr>        <dbl>     <dbl>    <dbl>     <dbl>
    1 nie         0.209     0.127  -0.0397      0.458
    2 nde         0.0772    0.227  -0.368       0.522
    3 te          0.287     0.241  -0.186       0.760
    4 own         0.103     0.0543 -0.00323     0.210
    5 spillover   0.106     0.0886 -0.0675      0.280

``` r
decompose(fit)
```

          own spillover       nie
    0.1032345 0.1061099 0.2093444
    attr(,"label")
    [1] "cluster-average, large-cluster approximation"

### Few clusters and Kenward–Roger

With few clusters the model-based standard errors can be too small.
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
warns when \\J \< 25\\ with model-based standard errors, and whatever
the standard error type when \\J \< 10\\. `se_type = "kr"` replaces each
model’s covariance by the Kenward–Roger adjusted one
([`pbkrtest::vcovAdj()`](https://rdrr.io/pkg/pbkrtest/man/kr-vcovAdj.html),
REML fits only) and stores a Kenward–Roger denominator degrees of
freedom for each path; `confint(parm = "paths")` and
`tidy(conf_int = TRUE)` then give \\t\\ intervals for the paths, while
the intervals for the products (NIE, own, spillover, TE) stay normal.
The Kenward–Roger adjustment changes the standard errors very little
(ratios of 1.000 to 1.002 at \\J = 15\\); its value is the degrees of
freedom. The product intervals are the weak point at small \\J\\.

`bootstrap_mediation(cluster = )` needs no normal approximation for
them; no few-cluster threshold is established, and the published
evidence for resampling whole clusters is for treatment varying within
clusters with 30 or more clusters (Falk et al. 2024), not for this
design. The treatment’s effect on the mediator rests on \\J\\
cluster-level contrasts however many members each cluster has, so the
number of clusters, not of members, is the sample size for it.

``` r
fit_kr <- fit_mediation(
  Y ~ X + M, M ~ X, data = cdat, treatment = "X", mediator = "M",
  engine = "lmer", cluster = "school", se_type = "kr"
)
fit_kr@kr_df
```

            a   c_prime  b_within b_between
           38        37       359        37 

``` r
confint(fit_kr)
```

                     2.5 %    97.5 %
    a         -0.008940371 0.5529108
    b_within   0.283502528 0.4756161
    b_between  0.257098644 1.2822819
    c_prime   -0.382891954 0.5373482

### What is not supported

medfit does not support, in this design: treatment varying within
clusters (1-1-1), non-Gaussian outcomes or mediators,
treatment-by-mediator or covariate-by-mediator products, random slopes
on anything but the within-cluster mediator term, or individual-average
effects.

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
| Cluster | NIE \\= a b_B\\ | \\\partial/\partial a = b_B\\, \\\partial/\partial b_B = a\\ |
| Cluster | own \\= a b_W\\ | \\\partial/\partial a = b_W\\, \\\partial/\partial b_W = a\\ |
| Cluster | spillover \\= a (b_B - b_W)\\ | \\b_B - b_W\\ on \\a\\, \\a\\ on \\b_B\\, \\-a\\ on \\b_W\\ |
| Cluster | NDE, TE | \\1\\ on \\c'\\; TE adds the NIE gradient |

For the joint effects the chain rule through the propagated terms is
carried by backward recursions, \\\lambda_j = (\theta\_{2j} +
\theta\_{3j}) + \sum\_{i\>j} d\_{ij} \lambda_i\\ and \\\kappa_j =
\theta\_{3j} + \sum\_{i\>j} d\_{ij} \kappa_i\\.

The covariate means \\\bar c\\ are treated as fixed, so standard errors
that involve them (the four-way INT_(ref) and the joint NDE) are
conditional on the observed covariates; they omit the sampling variance
of the estimated mean (the derivative of INT_(ref) with respect to
\\\bar c\\ is \\\theta_3\gamma\\), so they can understate the
uncertainty of a population-average effect.
`options(medfit.covariate_mean_variance = TRUE)` adds the omitted
variance, \\(\theta_3\gamma)^2 \operatorname{Var}(c)/n\\, to INT_(ref),
the NDE and the TE.

**Intervals.** [`confint()`](https://rdrr.io/r/stats/confint.html) and
`tidy(conf_int = TRUE)` report normal intervals, \\\hat g \pm
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
- **Cluster** (`method = "nonparametric"` with `cluster =`): resamples
  whole clusters with replacement and gives each draw a fresh cluster id
  before the refit, so a cluster drawn twice is refit as two clusters,
  not one larger one. A refit that is singular or warns about
  convergence counts as a failure, is excluded, and is counted in the
  warning.

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
scale, as regmedint reports them. `engine = "lmer"` fits the two linear
mixed models of the cluster design above (REML, random cluster
intercepts, the mediator and level-1 covariates split into
within-cluster deviation and cluster mean) and passes them to
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md);
it returns a `ClusterMediationData`. `engine = "native"` fits model
syntax with the engine described in the next section, then extracts the
mediation structure through the same workers as the lavaan route.

## Native SEM engine

[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
and `fit_mediation(engine = "native")` fit a model written in medfit
model syntax
([`?"medfit-syntax"`](https://data-wise.github.io/medfit/reference/medfit-syntax.md))
by maximum likelihood to raw data. Rows with missing values in the model
variables are dropped once (listwise deletion) and counted.

### Model form

The model is written in RAM form. With \\A\\ the matrix of directed
paths, \\S\_{\text{ram}}\\ the matrix of variances and covariances, and
\\F\\ the selection matrix that picks the observed variables, the
implied covariance of the observed variables is

\\ \Sigma(\theta) = F (I - A)^{-1} S\_{\text{ram}} (I - A)^{-\top}
F^\top . \\

### Discrepancy

With \\S\\ the sample covariance with divisor \\n\\ and \\p\\ the number
of observed variables, the engine minimizes

\\ F\_{ML}(\theta) = \log \|\Sigma(\theta)\| + \operatorname{tr}\left(S
\Sigma(\theta)^{-1}\right) - \log \|S\| - p , \\

which is twice lavaan’s `fmin`. With the means free, \\-2 \log L = n
\left(F\_{ML} + \log \|S\| + p + p \log 2\pi\right)\\, and
[`logLik()`](https://rdrr.io/r/stats/logLik.html) reports this value.
The gradient is analytic. A parameter vector whose implied covariance is
not positive definite gets a large finite value and a zero gradient, so
the optimizer can step back from it.

### Mean structure

An intercept statement adds the vector \\m\\ of intercepts to the RAM
form, and the implied means are

\\ \mu(\theta) = F (I - A)^{-1} m , \\

with a latent variable’s entry of \\m\\ fixed at 0. With \\\bar x\\ the
sample mean (weighted when weights are used) and \\\Sigma\\ as above,
the discrepancy gains the term

\\ F\_{ML}(\theta) = \log \|\Sigma\| + \operatorname{tr}\left(S
\Sigma^{-1}\right) - \log \|S\| - p + (\bar x - \mu)^\top \Sigma^{-1}
(\bar x - \mu) . \\

Under normality the information has no cross term between the mean and
covariance parts: it is the sum \\I\_{kl} = n\\ \partial_k \mu^\top
\Sigma^{-1} \partial_l \mu + (n/2)\operatorname{tr}\left(\Sigma^{-1}
\partial_k \Sigma\\ \Sigma^{-1} \partial_l \Sigma\right)\\, and the
casewise scores of the sandwich gain the mean part \\w_i\\ \partial_k
\mu^\top \Sigma^{-1} (x_i - \mu)\\, with \\d_i = x_i - \mu(\theta)\\ in
the covariance part. The degrees of freedom count \\p(p+1)/2 + p\\
moments, so a fixed intercept (`y ~ 0*1`) is a restriction that costs
one. A fit without any intercept statement is the same model with every
observed intercept free: its discrepancy, estimates and standard errors
are those of the covariance-only fit, and
[`anova()`](https://rdrr.io/r/stats/anova.html) treats it that way.

**Conditioning.** The path entries of a variable with a free intercept
change that intercept by the mean times the path, so in the raw
parameters the information is nearly singular when the mean is large
relative to the standard deviation. The gate, the information and its
inverse are computed in centered coordinates \\\tilde m_v = m_v - (\bar
x_v - \sum_c A\_{v,c} \bar x_c)\\ (an affine map \\\theta = T(\phi +
c_0)\\, with the Hessian taken directly in \\\phi\\), and the covariance
is mapped back as \\V = T V\_\phi T^\top\\. When no constraint, bound or
starting value touches an intercept, the whole fit runs on mean-centered
data and the solution is mapped back.

### Fixed exogenous moments

With `fixed_x`, the selected exogenous variables \\x_f\\ keep their mean
\\\bar x_f\\, variance and covariances at the sample values (divisor
\\n\\, weighted when weights are used), so those entries of \\\Sigma\\
and \\\mu\\ are constants, not parameters. They leave the parameter
count and the moment count together, so the degrees of freedom and the
chi-square do not change, and the estimates and standard errors of the
remaining parameters equal the free fit’s: the expected information has
no cross block between the fixed moments and the rest at the solution.
The log likelihood is conditional on \\x_f\\, the joint value minus the
marginal normal term of the fixed block,

\\ \log L\_{\mid x_f} = \log L - \left\[ -\frac{n}{2} \left( \log
\|S\_{ff}\| + k + k \log 2\pi \right) \right\] , \\

with \\S\_{ff}\\ the sample covariance (divisor \\n\\) of the \\k\\
fixed variables; this is lavaan’s `fixed.x = TRUE` value. Without a mean
structure, the likelihood counts one saturated mean for each of the
\\p - k\\ variables that are not fixed. Because \\\log L\_{\mid x_f}\\
conditions on different variables for different fixed sets, fits compare
only when their fixed sets and data agree.

### Products and observed information

A product term `x:m` is a data-level transformation, not a quantity
inside the likelihood. The engine builds \\p_i = x_i m_i\\ for every row
kept after listwise deletion, names it \\m{:}x\\ (the two names sorted
in the C locale, so `x:m` and `m:x` are one term), and treats it as one
more observed exogenous variable: a free variance, free covariances with
the other exogenous variables, and a free mean. The RAM, the discrepancy
and the mean structure are unchanged, which is how lavaan reads `x:m`.
In a recursive model with no residual covariance between outcomes, with
every coefficient free and used once, the maximum-likelihood estimate of
each equation’s coefficients is the least-squares estimate of that
equation, so the four-way parts
([above](#treatmentmediator-interaction-the-four-way-decomposition))
computed from a native fit equal the `lm`/`glm` route; outside that
class the equality can fail (a residual covariance gives a generalized
least squares estimator, a shared or fixed coefficient changes it),
which is why a product model outside the class is refused.

The product is a function of \\m\\ but the model treats it as exogenous,
so a model with \\m \sim x\\ and \\y \sim x + m + x{:}m\\ implies
\\\operatorname{Cov}(e_m, p) = 0\\. In the data
\\\operatorname{Cov}(e_m, p) = E\[x e_m^2\]\\, about
\\E\[x\]\sigma_m^2\\ when \\e_m\\ is independent of \\x\\, so the
restriction is wrong unless \\x\\ is centered. The coefficients stay
equal to their equation-wise least-squares estimates, but the global
chi-square is not a chi-square: in a checked example (\\n = 20000\\,
\\x\\ normal with mean 2) it was 22113.7 on 1 degree of freedom, and
4.89 with \\x\\ centered. That is why
[`glance()`](https://generics.r-lib.org/reference/glance.html) reports
chi-square, df and p-value as `NA` for a product with an endogenous
factor, and why [`anova()`](https://rdrr.io/r/stats/anova.html) and
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
refuse.

Expected information is \\(n/2)\operatorname{tr}\left(\Sigma^{-1}
\partial_k \Sigma\\ \Sigma^{-1} \partial_l \Sigma\right)\\ at the
model-implied \\\Sigma\\, which carries the false restriction above, so
the standard errors built from it are wrong, and the sandwich built on
it is wrong too. Observed information is the numerical Jacobian of the
gradient of \\F\_{ML}\\ at the estimate, and with the sandwich
covariance the standard errors do not rest on the implied moments of the
product; `information = "expected"` is therefore refused for a product
with an endogenous factor. A product of two exogenous variables implies
no such restriction. With the exogenous block free, the ordinary test is
calibrated: 1000 replications at \\n = 500\\ rejected 0.055 and 0.056 at
the nominal 0.05 for normal and centered-exponential factors. If the
exogenous block is restricted (a variance or covariance fixed, labeled,
bounded, or left out), the test is unavailable for the same reason,
because a skewed or product-valued variable breaks the normal-theory
variance of its own moments.

### Standard errors

The covariance of \\\hat\theta\\ is the inverse of the information for
the log likelihood. The default, observed information, is \\(n/2)\\
times the central-difference Jacobian of the analytic gradient of
\\F\_{ML}\\ (step \\\epsilon^{1/3} \max(\|x\|, 1)\\). Expected
information is \\(n/2)\\ \operatorname{tr}\left(\Sigma^{-1} \partial_k
\Sigma\\ \Sigma^{-1} \partial_l \Sigma\right)\\. A singular information
matrix gives an `NA` covariance and one warning. Defined parameters
(`:=`) get delta-method standard errors, \\\sqrt{g^\top V g}\\, with the
gradient \\g\\ taken by central differences over the labels.

### Sampling weights and the sandwich

With case weights \\w_i\\ rescaled to sum to \\n\\, the fit minimizes
\\F\_{ML}\\ on the weighted mean and the weighted covariance (divisor
\\n\\). The robust covariance of \\\hat\theta\\ is \\A^{-1} B A^{-1}\\,
with \\A\\ the information above and \\B = \sum_i s_i s_i^\top\\ the
cross product of the casewise scores

\\ s\_{i,k} = w_i \\ \frac{1}{2} \operatorname{tr}\left(\Sigma^{-1} (d_i
d_i^\top - \Sigma) \Sigma^{-1} \partial_k \Sigma\right), \qquad d_i =
x_i - \bar{x}\_w . \\

The means are free and do not involve \\\theta\\, so \\A\\ is block
diagonal and only the \\\theta\\ block of \\B\\ enters. Under
constraints the same projection applies, \\Z (Z^\top A Z)^{-1} Z^\top B
Z (Z^\top A Z)^{-1} Z^\top\\. The estimator is invariant to the scale of
the weights and has no leverage correction (HC0): it equals
`sandwich::vcovHC(type = "HC0")` for each regression equation and
lavaan’s robust standard errors with `sampling.weights`, and is narrower
than the HC3 default of
`fit_mediation(engine = "glm", se_type = "sandwich")` by a factor that
shrinks like \\1/n\\. The weighted likelihood is a pseudo likelihood, so
[`logLik()`](https://rdrr.io/r/stats/logLik.html) is not defined for a
weighted fit.

### Constraints

Equality and inequality constraints that are linear in the labels become
rows \\a^\top\theta + b\\, normalized to unit length, with constant
Jacobians for the optimizer (SLSQP through nloptr). A nonlinear equality
(`cp == a*b`) is a row whose value is \\\text{lhs} - \text{rhs}\\ and
whose Jacobian is a central difference, both recomputed at every point;
a nonlinear inequality is the same row with the sign chosen so that it
reads \\c(\theta) \le 0\\.

A nonlinear row can bend away from its tangent plane, so the acceptance
test uses the Hessian of the Lagrangian, \\H + \sum_i \lambda_i \nabla^2
c_i\\ over the active nonlinear rows (the multipliers from \\\nabla F +
\sum_i \lambda_i \nabla c_i = 0\\), in the reduced Hessian; the
objective’s Hessian alone can call a saddle of the restricted problem a
minimum.

A model with a nonlinear constraint can have several local optima, so
all `n_starts` starts are tried and the best accepted one is kept. SLSQP
stops along a flat constraint tangent, up to about \\3\times10^{-5}\\
from the optimum, so an accepted fit with an active nonlinear row takes
full Newton steps on the KKT system of the active set (using the same
Lagrangian Hessian); the polished point replaces the solution only when
the acceptance test accepts it again and the discrepancy does not rise.
A product of labels set to zero (\\ab = 0\\, \\b_1 b_2 b_3 = 0\\) is not
solved this way, because its Jacobian vanishes at the solution: it holds
exactly when one factor is zero, so the model is refitted once per
factor from the default start and the smallest discrepancy is kept. At
the solution the active constraints and active bounds define a
null-space basis \\Z\\ of the feasible directions, and the covariance is
projected,

\\ V = Z \left(Z^\top I Z\right)^{-1} Z^\top , \\

so a parameter pinned by a constraint has zero variance and `a == b`
returns the standard error of the model with `a` and `b` collapsed to
one label.

Redundant rows are handled in two layers. Equality rows that are
linearly dependent (a duplicate, `a == b` with `b == a`) are reduced to
an independent subset before the solve, because a rank-deficient
Jacobian stops SLSQP although the constraints are consistent; the
dropped rows are still checked by the acceptance gate, so contradictory
equalities (`a == 1` with `a == 2`) are reported. This is the standard
remedy: the linear independence constraint qualification (LICQ) fails
when an active constraint is redundant, and solver presolve routines
remove duplicate and dependent rows for that reason.

An inequality whose row lies in the span of the equality rows has a
constant value on the equality set. When that value satisfies it
(`a == b` with `a - b < 0`, or `a + b == 0.8` with `a + b > 0.8`) the
inequality is active at every feasible point and would reproduce the
same degeneracy, so it is dropped from the solver’s rows too, and the
acceptance gate still checks it.

Such a row is detected when its gradient is within \\10^{-12}\\ of the
span of the independent equality rows (rows have unit length), a
distance that only rows dependent to rounding error meet; a row that is
merely close to the span, such as `a - b + 1e-9*cp > 1e-7` with
`a == b`, stays with the solver, because near-dependence does not show
that the set is infeasible.

An implied inequality that the equality rows violate (`a + b == 0.8`
with `a + b < 0.5`) is kept, and the acceptance gate reports the
violated row. The multiplier sign check skips a fit whose active
constraints are linearly dependent, which includes a dropped row, since
that row has no meaningful multiplier. The estimates equal those of the
model with the redundant inequality deleted. An inequality that is
inactive on the equality set (`a + b == 0.8` with `a + b < 0.9`), and
parallel inequalities with no equality (`a + b < 0.2` with
`2*a + 2*b < 0.4`), are not affected.

### Acceptance

A solution is accepted only if the optimizer status is a success code,
every constraint holds to \\10^{-6}\\ in the solver’s natural units, and
the Newton decrement \\\sqrt{g_r^\top H_r^{-1} g_r}\\ on the reduced
gradient and Hessian of the active-constraint null space is at most
\\10^{-3}\\, with a positive definite reduced Hessian. The decrement is
scale free, so rescaling the data does not change the verdict.

The sign of each active inequality’s or bound’s multiplier is checked: a
wrong sign means the point may not be a local minimum.

A wrong-signed active bound rejects the solution, the same verdict the
fit without constraints gives (the gradient at an active bound points
into the interior), whether or not the model also has constraint lines:
each bound is judged by its own statistic \\\|g_k\| / \sqrt{H\_{kk}}\\
against \\10^{-3}\\, which needs only the Hessian diagonal, so an
indefinite Hessian cannot hide it. A wrong-signed active inequality
constraint only warns. The check asks whether non-negative multipliers
on the active inequalities and bounds (free-sign ones on the equalities)
reproduce the gradient, using non-negative least squares, so linearly
dependent active rows (an equality with a parallel inequality) get a
verdict like any others.

### Starts

The first start is moment based. If it is not accepted, up to
`n_starts - 1` retries use perturbed starts drawn under a fixed seed
derived from the model, restoring the caller’s random number state
afterward, so a fit is reproducible and never changes a simulation
around it. When no start is accepted the error names the best attempt’s
status and stationarity, and for an infeasible constraint set, the
violated constraint.

``` r
fit <- fit_sem(
  "mediator1 ~ a*treatment + covariate1
   outcome ~ b*mediator1 + treatment + covariate1
   ab := a*b",
  data = mediation_demo
)
fit@defined
```

      name expr       est         se
    1   ab  a*b 0.3331241 0.06436069

### Testing the indirect effect: MBCO

`mbco_sem(object, a, b)` tests \\H_0\colon ab = 0\\ as the minimum of
two likelihood-ratio tests (MBCO). It refits the model with \\a = 0\\
and with \\b = 0\\; each is a linear equality constraint, so each refit
is one solve. With \\F\\ the minimized maximum-likelihood discrepancy
and \\n\\ the number of rows used,

\\ D_a = n\\(F\_{a=0} - F), \qquad D_b = n\\(F\_{b=0} - F), \qquad T =
\min(D_a, D_b), \\

and \\T\\ is referred to \\\chi^2_1\\. A product of \\k\\ paths (a
serial indirect effect \\a\\d\\b = 0\\,
`mbco_sem(fit, paths = c("a", "d", "b"))`) is the same test with \\k\\
refits, one per path, \\T = \min_j D_j\\: the product is zero exactly
when one factor is, so the null is a union of \\k\\ hypotheses, each
tested by a \\\chi^2_1\\ likelihood-ratio statistic, and the minimum is
conservative (at most the nominal size when one factor is zero, smaller
when several are). The nonlinear constraint \\ab = 0\\ is not solved: a
nonlinear solver can stop at the branch with the larger statistic
(OpenMx’s does on RMediation’s `memory_exp`, reporting 221.05 where the
minimum is 0.083). A fit with sampling weights or one that did not
converge is refused, since the weighted discrepancy is not a likelihood.
If a bound or an inequality on the tested path is active at its refit
(`a > 0` with the null at \\a = 0\\), the null lies on the boundary of
the parameter space, the statistic is a mixture of chi-squares, and the
function warns that the p-value is not valid.

``` r
mbco_sem(fit, "a", "b")
```


        Minimum-of-two likelihood-ratio tests (MBCO) for an indirect effect

    data:  a * b = 0
    MBCO = 33.353, df = 1, p-value = 7.685e-09

### Comparing nested fits: `anova()`

`anova(fit_full, fit_restricted)` is the general likelihood-ratio test
for two fits that were already made; it never refits, so each restricted
fit starts from the engine’s own start values (starting a restricted fit
from the full fit’s estimates is how OpenMx lands on an infeasible point
with a statistic of 0). The statistic and its degrees of freedom are

\\ D = n\\(F\_{r} - F\_{f}), \qquad \text{df} = \text{df}\_r -
\text{df}\_f, \\

with \\F\\ the minimized discrepancy and \\\text{df}\\ the model degrees
of freedom of each fit, which already count the equality constraints.
\\D\\ is referred to \\\chi^2\_{\text{df}}\\.
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
differences the same quantity for each of its two refits, so
[`anova()`](https://rdrr.io/r/stats/anova.html) reproduces its per-refit
statistics (221.05 and 0.083 on `memory_exp`). Several fits give one row
each, ordered by degrees of freedom, each tested against the row above
it.

Two fits are accepted only if they use the same observed variables and
the same rows, neither has sampling weights, both converged, and the
restricted fit frees no parameter the other leaves out and has more
degrees of freedom. That parameter-table inclusion is necessary for
nesting and not sufficient: two models with different latent structures
but the same row labels pass, and whether they are nested in substance
is the analyst’s responsibility. A restricted fit with a smaller
discrepancy than the model it restricts means one of the fits is not at
its global optimum, and is an error. As in
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md),
a bound or an inequality on a tested parameter that is active at the
restricted fit puts the null on the boundary of the parameter space, so
the statistic is a mixture of chi-squares and the function warns that
the p-value is not valid.

``` r
fit0 <- fit_sem(paste0(fit@model, "\nb == 0"), data = mediation_demo)
anova(fit, fit0)
```

    Likelihood-ratio (chi-square difference) test for SEMFit models

    n = 400; Chisq is n times the minimized discrepancy

         Df Chisq Chisq diff Df diff Pr(>Chisq)
    fit   0   0.0
    fit0  1 102.3      102.3       1  < 2.2e-16 ***
    ---
    Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1

## References

Falk, C. F., Vogel, T. A., Hammami, S., & Miočević, M. (2024).
Multilevel mediation analysis in R: A comparison of bootstrap and
Bayesian approaches. *Behavior Research Methods*, 56(2), 750–764.
<https://doi.org/10.3758/s13428-023-02079-4>

Lüdtke, O., Marsh, H. W., Robitzsch, A., Trautwein, U., Asparouhov, T.,
& Muthén, B. (2008). The multilevel latent covariate model: A new, more
reliable approach to group-level effects in contextual studies.
*Psychological Methods*, 13(3), 203–229.
<https://doi.org/10.1037/a0012869>

Talloen, W., Moerkerke, B., Loeys, T., De Naeghel, J., Van Keer, H., &
Vansteelandt, S. (2016). Estimation of indirect effects in the presence
of unmeasured confounding for the mediator–outcome relationship in a
multilevel 2-1-1 mediation model. *Journal of Educational and Behavioral
Statistics*, 41(4), 359–391. <https://doi.org/10.3102/1076998616636855>

VanderWeele, T. J. (2010). Direct and indirect effects for
neighborhood-based clustered and longitudinal data. *Sociological
Methods & Research*, 38(4), 515–544.
<https://doi.org/10.1177/0049124110366236>

VanderWeele, T. J. (2014). A unification of mediation and interaction: A
4-way decomposition. *Epidemiology*, 25(5), 749–761.

VanderWeele, T. J., & Vansteelandt, S. (2014). Mediation analysis with
multiple mediators. *Epidemiologic Methods*, 2(1), 95–115.
<https://doi.org/10.1515/em-2012-0010>
