# Glossary and symbols

Every term and symbol medfit prints, in one place. Each links to the
page that uses it. The formulas are the ones in [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md), which
also states the assumptions.

## Variables and paths

| Symbol | Meaning |
|----|----|
| \\X\\ | the treatment |
| \\M\\, \\M_1, \dots, M_K\\ | the mediator or mediators |
| \\Y\\ | the outcome |
| \\C\\ | covariates (the same set in every model unless stated) |
| \\a\\ | the path from treatment to mediator (`a_path`) |
| \\b\\ | the path from mediator to outcome, adjusting for the treatment (`b_path`) |
| \\c'\\ | the direct path from treatment to outcome, adjusting for the mediator (`c_prime`) |
| \\d\\ | a path from one mediator to the next in a chain ([serial](https://data-wise.github.io/medfit/articles/model-serial.md)) |
| \\\theta_3\\ | the coefficient of the treatment-by-mediator product ([interaction](https://data-wise.github.io/medfit/articles/model-interaction.md)) |

In the model \\M = \beta_0 + \beta_1 X + \gamma^\top C + e_M\\ and \\Y =
\theta_0 + \theta_1 X + \theta_2 M + \theta_4^\top C + e_Y\\, the paths
are \\a = \beta_1\\, \\b = \theta_2\\ and \\c' = \theta_1\\.

## Effects

| Term | Meaning | Function |
|----|----|----|
| **NIE** | natural indirect effect: the part of the effect that goes through the mediator; \\a b\\ for one mediator | [`nie()`](https://data-wise.github.io/medfit/reference/nie.md) |
| **NDE** | natural direct effect: the part that does not; \\c'\\ for one mediator | [`nde()`](https://data-wise.github.io/medfit/reference/nde.md) |
| **TE** | total effect: NIE + NDE | [`te()`](https://data-wise.github.io/medfit/reference/te.md) |
| **PM** | proportion mediated: NIE / TE | [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) |
| **chain effect** | the indirect effect through every mediator in a chain, \\a \\ d_1 \cdots b\\ | [`nie()`](https://data-wise.github.io/medfit/reference/nie.md) on a serial object |
| **total indirect effect** | the indirect effect summed over every path through at least one mediator | `nie(x, type = "total")` |

Effects are for a unit change in the treatment. They have a causal
reading only under the assumptions in [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md);
medfit computes the numbers, and the interpretation is yours.

## The four-way decomposition

For one mediator and a treatment-by-mediator product, the total effect
splits into four parts
([page](https://data-wise.github.io/medfit/articles/model-interaction.md)):

| Term | Meaning | Formula |
|----|----|----|
| **CDE** | controlled direct effect: the effect of the treatment with the mediator held at \\m^\*\\ | \\\theta_1 + \theta_3 m^\*\\ |
| **INTref** | reference interaction: interaction that would exist even if the treatment did not change the mediator | \\\theta_3 \left( E\[M \mid X = 0, \bar c\] - m^\* \right)\\ |
| **INTmed** | mediated interaction: interaction that depends on the treatment changing the mediator | \\\theta_3 \beta_1\\ |
| **PIE** | pure indirect effect: mediation with no interaction | \\\theta_2 \beta_1\\ |

They add up: TE = CDE + INTref + INTmed + PIE, NDE = CDE + INTref, and
NIE = INTmed + PIE.

| Term | Meaning |
|----|----|
| **`m_star`** (\\m^\*\\) | the reference mediator level at which the CDE is evaluated (default 0) |

## Several mediators

| Term | Meaning | Page |
|----|----|----|
| **serial** | mediators in a chain: X to \\M_1\\ to \\M_2\\ to Y | [Serial mediation](https://data-wise.github.io/medfit/articles/model-serial.md) |
| **parallel** | mediators side by side, with no path between them; NIE is \\\sum_j a_j b_j\\ | [Parallel mediation](https://data-wise.github.io/medfit/articles/model-parallel.md) |
| **joint** | the joint natural effects of several mediators when the outcome has treatment-by-mediator products | [Joint mediation](https://data-wise.github.io/medfit/articles/model-joint.md) |
| **skip path** | a path that jumps over a mediator in a chain, such as X to \\M_2\\ | [Serial mediation](https://data-wise.github.io/medfit/articles/model-serial.md) |

## Clusters

| Term | Meaning |
|----|----|
| **2-1-1 design** | treatment assigned to clusters; mediator and outcome measured on individuals |
| **\\b_B\\ (`b_between`)** | the effect of a cluster’s mean mediator on the outcome |
| **\\b_W\\ (`b_within`)** | the effect of an individual’s deviation from the cluster mean |
| **own** | the part of the indirect effect that acts through a person’s own mediator |
| **spillover** | the part that acts through the rest of the cluster |
| **Kenward-Roger** (`se_type = "kr"`) | a small-sample correction for mixed models that gives t intervals for the paths |

See [Cluster-randomized
trials](https://data-wise.github.io/medfit/articles/model-cluster.md).
The own and spillover split is a large-cluster approximation.

## Inference

| Term | Meaning | Page |
|----|----|----|
| **delta method** | a standard error for a function of estimates (such as \\a b\\), from their covariance | [Which interval?](https://data-wise.github.io/medfit/articles/guide-intervals.md) |
| **parametric bootstrap** | draws the paths from their estimated normal distribution | [Which interval?](https://data-wise.github.io/medfit/articles/guide-intervals.md) |
| **nonparametric bootstrap** | resamples rows and refits | [Bootstrap Inference](https://data-wise.github.io/medfit/articles/bootstrap.md) |
| **plugin** | the point estimate only, with no interval | [Bootstrap Inference](https://data-wise.github.io/medfit/articles/bootstrap.md) |
| **percentile interval** | the 2.5th and 97.5th percentiles of the bootstrap draws, for a 95% interval | [Bootstrap Inference](https://data-wise.github.io/medfit/articles/bootstrap.md) |
| **sandwich** | a robust standard error, used with weights (`se_type = "sandwich"`); HC3 for the `glm` engine, HC0-type for the native engine | [Weights and robust SEs](https://data-wise.github.io/medfit/articles/model-weights.md) |
| **MBCO** | the minimum over the paths of the likelihood-ratio tests (two or k paths), for the hypothesis that an indirect effect is zero ([`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)) | [constraints and MBCO](https://data-wise.github.io/medfit/articles/model-native-constraints.md) |

## The native engine

| Term | Meaning | Page |
|----|----|----|
| **`SEMFit`** | the result of [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md); [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) turns it into the classes above | [Native engine](https://data-wise.github.io/medfit/articles/model-native.md) |
| **label** | a name given to a path in syntax, as in `y ~ b * m`; equal labels are one parameter | [Native engine](https://data-wise.github.io/medfit/articles/model-native.md) |
| **defined parameter** (`:=`) | a quantity defined from labels, such as `ab := a * b`, with a delta-method standard error | [Native engine](https://data-wise.github.io/medfit/articles/model-native.md) |
| **latent variable** (`=~`) | a variable measured by indicators, as in `eta =~ m1 + m2 + m3` | [a latent mediator](https://data-wise.github.io/medfit/articles/model-native-latent.md) |
| **constraint** | an equality or inequality on labels, such as `a == b` | [constraints and MBCO](https://data-wise.github.io/medfit/articles/model-native-constraints.md) |
| **mean structure** | the observed means modeled together with the covariances: intercepts (`y ~ 1`) are estimated; `meanstructure = TRUE`, the default since 0.15.0, or any `~1` statement turns it on and frees every unwritten observed intercept; `meanstructure = NULL` fits it only when the syntax writes an intercept or a product | [Intercepts](https://data-wise.github.io/medfit/articles/model-native.html#intercepts) |
| **intercept** | the mean of an observed variable that its equation leaves unexplained, written `y ~ 1` or `y ~ 1 + x`; `y ~ 0*1` fixes it at 0 and is a restriction | [Intercepts](https://data-wise.github.io/medfit/articles/model-native.html#intercepts) |
| **`fixed_x`** | fixes the mean, variances and covariances of exogenous observed variables at their sample values, as lavaan’s `fixed.x = TRUE`; the structural estimates and standard errors do not change. Since 0.15.0 it is on by default, for every exogenous observed variable the model does not name in a `~~` or `~1` statement | [Fix exogenous covariates](https://data-wise.github.io/medfit/articles/cookbook.html#fix-exogenous-covariates-fixed_x) |
| **product term** | `x:m` on the right side of a regression, an observed column equal to `x * m`; it gives the four-way decomposition and turns the mean structure on | [Product terms](https://data-wise.github.io/medfit/articles/model-native.html#product-terms) |
| **dummy** (`group_mid`) | the 0/1 column a categorical covariate becomes in a native fit, one per non-reference level, named `<column>_<level>` | [Cookbook recipe 21](https://data-wise.github.io/medfit/articles/cookbook.html#a-categorical-covariate-in-a-native-fit) |
| **reference level** | the first level of a categorical covariate, which gets no dummy; the other levels are read against it | [Cookbook recipe 21](https://data-wise.github.io/medfit/articles/cookbook.html#a-categorical-covariate-in-a-native-fit) |
| **canonical name** (`m:x`) | the one name a product is stored under: the two variable names sorted in the C locale, so `x:m` and `m:x` are the same term | [Product terms](https://data-wise.github.io/medfit/articles/model-native.html#product-terms) |
| **nested comparison** ([`anova()`](https://rdrr.io/r/stats/anova.html)) | the likelihood-ratio test of a restricted fit against a fuller one; it refits nothing and refuses fits that are not nested | [Compare nested fits](https://data-wise.github.io/medfit/articles/model-native-constraints.html#compare-nested-fits) |
| **conditional log likelihood** | the log likelihood given the fixed variables under `fixed_x` (the default since 0.15.0), so [`logLik()`](https://rdrr.io/r/stats/logLik.html), AIC and BIC of fits with different fixed sets cannot be compared | [Limits](https://data-wise.github.io/medfit/articles/model-native.html#limits) |
| **outcome ledger** (`fit@diagnostics$ledger`) | the record of how a native fit, each zero-product branch and each [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) null was reached; an unresolved node is unknown, and only a literal contradiction is certified empty | [Errors that carry evidence](https://data-wise.github.io/medfit/articles/guide-troubleshooting.html#errors-that-carry-evidence) |

## Related

[Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md) \|
[Reference Card](https://data-wise.github.io/medfit/articles/refcard.md)
\| [Models](https://data-wise.github.io/medfit/articles/models.md)
