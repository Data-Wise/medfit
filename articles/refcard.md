# medfit Reference Card

Quick lookup for users who already know medfit. Explanations are in the
[articles](https://data-wise.github.io/medfit/articles/getting-started.md);
formulas are in [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md); task
recipes are in the
[Cookbook](https://data-wise.github.io/medfit/articles/cookbook.md).

## Start here

``` r
library(medfit)
```


    Attaching package: 'medfit'

    The following object is masked from 'package:stats':

        decompose

``` r
med(mediation_demo, treatment = "treatment", mediator = "mediator1",
    outcome = "outcome", covariates = c("covariate1", "covariate2"))
```

    MediationData object
    ====================

    Path coefficients:
      a (X -> M):        0.5826
      b (M -> Y|X):      0.5711
      c' (X -> Y|M):     0.2058
      Indirect (a*b):    0.3328

    Variables:
      Treatment: treatment
      Mediator:  mediator1
      Outcome:   outcome

    Model info:
      N observations: 400
      Converged:      Yes
      Source:         stats::glm

    Residual SDs:
      Mediator model:   0.9792
      Outcome model:    1.0426

## I have, run

| I have | Run |
|----|----|
| Data frame, one mediator | [`med()`](https://data-wise.github.io/medfit/reference/med.md), then [`quick()`](https://data-wise.github.io/medfit/reference/quick.md) |
| Fitted `lm`/`glm` pair | `extract_mediation(model_m, model_y = , treatment = , mediator = )` |
| Formulas and data | `fit_mediation(formula_y, formula_m, data, treatment, mediator)` |
| Several mediators (chain) | `extract_mediation(..., mediator = c(...), mediator_models = list(...))` |
| Several mediators (side by side) | same call with `structure = "parallel"` |
| Treatment-by-mediator term | [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) on an outcome with `X * M` |
| `lmer` pair, cluster treatment | `extract_mediation(..., cluster = )` |
| Formulas, cluster treatment | `fit_mediation(engine = "lmer", cluster = )` with plain formulas, no `(1 \| id)` |
| `lavaan` fit | `extract_mediation(lavaan_fit, ...)` |
| IPW weights | `fit_mediation(weights = , se_type = "sandwich")` |

## Which object

| Structure                 | Class                      | NIE                  |
|---------------------------|----------------------------|----------------------|
| X to M to Y               | `MediationData`            | \\a \\ b\\           |
| Chain X to M1 to M2 to Y  | `SerialMediationData`      | \\a \\ d \\ b\\      |
| X to M_j to Y             | `ParallelMediationData`    | \\\sum a_j b_j\\     |
| X by M term               | `InteractionMediationData` | INTmed + PIE         |
| Several M with X by M     | `JointMediationData`       | joint over the block |
| Cluster treatment, `lmer` | `ClusterMediationData`     | \\a \\ b_B\\         |

## Effects

| Call                      | Gives                                |
|---------------------------|--------------------------------------|
| `nie(x)`                  | Natural indirect effect              |
| `nde(x)`                  | Natural direct effect                |
| `te(x)`                   | Total effect                         |
| `pm(x)`                   | Proportion mediated                  |
| `paths(x)`                | Path coefficients                    |
| `decompose(x)`            | Interaction, joint and cluster parts |
| `nie(x, type = "total")`  | Every indirect path (serial)         |
| `joint_effects(x, theta)` | Joint effects for bootstrapping      |

## Tables and intervals

| Call | Gives |
|----|----|
| `tidy(x, type = "effects")` | Effects with delta-method SEs |
| `tidy(x, type = "paths", conf.int = TRUE)` | Paths with intervals |
| `glance(x)` | One-row summary |
| `confint(x, parm = "effects")` | Effect intervals |
| `confint(x, parm = "paths")` | Path intervals |
| `coef(x)`, `vcov(x)`, `nobs(x)` | Estimates, covariance, sample size |

## Standard errors

| `se_type`    | Use                                            |
|--------------|------------------------------------------------|
| `"model"`    | Default, model-based                           |
| `"sandwich"` | Weights, robust (HC3)                          |
| `"kr"`       | Cluster fits, REML only, t intervals for paths |

## Bootstrap

| Call | Draws |
|----|----|
| `bootstrap_mediation(f, "parametric", mediation_data = x)` | From N(estimates, vcov) |
| `bootstrap_mediation(f, "nonparametric", data = d)` | Resampled rows, refit |
| `bootstrap_mediation(f, "nonparametric", data = d, cluster = "id")` | Resampled clusters, refit |
| `bootstrap_mediation(f, "plugin", mediation_data = x)` | Point estimate only |

Every call returns a `BootstrapResult`: use
[`print()`](https://rdrr.io/r/base/print.html),
[`summary()`](https://rdrr.io/r/base/summary.html),
[`coef()`](https://rdrr.io/r/stats/coef.html),
[`confint()`](https://rdrr.io/r/stats/confint.html),
[`tidy()`](https://generics.r-lib.org/reference/tidy.html).

## Cluster designs (2-1-1)

| Quantity                           | Formula                           |
|------------------------------------|-----------------------------------|
| NIE                                | \\a \\ b_B\\                      |
| Own (approximate)                  | \\a \\ b_W\\                      |
| Spillover (approximate)            | \\a (b_B - b_W)\\                 |
| Own, exact in a cluster of \\n_j\\ | \\a \[b_W + (b_B - b_W) / n_j\]\\ |
| NDE                                | \\c'\\                            |

## Warnings

| Message | Action |
|----|----|
| Fewer than 25 clusters, model SEs | Use `se_type = "kr"`, bootstrap clusters |
| Fewer than 10 clusters | Treat intervals as rough |
| Own-effect approximation gap | Read the split with care, small clusters |
| Bootstrap samples failed | Check the count, interval uses the rest |
| Normal approximation for the indirect effect | Prefer [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md) |
| Total effect near zero | Proportion mediated undefined |
