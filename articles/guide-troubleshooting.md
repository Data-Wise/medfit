# Troubleshooting: errors and warnings

Find your message in the tables below (use your browser’s search), read
the cause, and apply the fix. Every message here is quoted from the
package and checked by a test, so the wording matches what you see.

> **First, check your version**
>
> Examples on this site need medfit 0.9.0 or later. If `mediation_demo`
> or
> [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
> is “not found”, you have CRAN’s 0.3.2. See [What changed since CRAN
> 0.3.2](https://data-wise.github.io/medfit/articles/guide-changes.md).

## Fitting with `fit_mediation()` and `med()`

| You see | Cause | Fix |
|----|----|----|
| `Treatment variable 'treatment' must be in formula_m` | the treatment is missing from the mediator formula | add it: `mediator1 ~ treatment + ...` |
| `Mediator variable 'mediator1' must be in formula_y` | the mediator is missing from the outcome formula | add it: `outcome ~ treatment + mediator1 + ...` |
| `must be in data` | [`med()`](https://data-wise.github.io/medfit/reference/med.md) was given a variable name that is not a column | check the spelling; the message lists the valid names |
| `Must be element of set {'glm','regmedint','lmer','native'}` | `engine` is misspelled | use one of the four engines |
| `is only used with engine = "native"` | `model =` was given to another engine | use `engine = "native"`, or pass formulas instead of `model` |
| `engine = "lmer" needs` | the `lmer` engine has no `cluster` | add `cluster = "school"` (the cluster variable’s name) |
| `is only used with engine = "lmer"` | `cluster =` was given to another engine | add `engine = "lmer"`, or drop `cluster` |
| `contains the random-effect term` | a random-effect term (written with a vertical bar) is in a formula for the `lmer` engine | write fixed effects only; the engine adds the random intercept. For a slope use `engine_args = list(random_y = ~ M)` |

## The `regmedint` engine

| You see | Cause | Fix |
|----|----|----|
| `engine = "regmedint" does not support` | `weights` was given | use the `glm` engine for weights |
| `supports se_type = "model" only` | `se_type = "sandwich"` was given | use the `glm` engine for sandwich standard errors |
| `must be a numeric 0/1 variable for engine = "regmedint"` | the treatment is not coded 0/1 | recode it as 0/1, or pass `engine_args = list(a0 = , a1 = )` |
| `regmedint fits the mediator model with the same covariates as the outcome model` | the two formulas have different covariates | give both formulas the same covariates |

## Extracting from fitted models

| You see | Cause | Fix |
|----|----|----|
| `Can't find method for` | a raw `lm` or `glm` was passed to [`nie()`](https://data-wise.github.io/medfit/reference/nie.md), [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and so on | call [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) first and use its result |
| `requires 'mediator_models'` | two or more mediators and no `mediator_models` | pass a list of the models for mediators 2 to k, in order |
| `must be the model for mediator 2` | `mediator_models` is in the wrong order | put each model in the order of the `mediator` vector |
| `applies only when the outcome model has a treatment-by-mediator` | `m_star` was given but the outcome model has no `treatment * mediator` term | drop `m_star`, or add the product term |
| `requires an interaction term` | `decomposition = "four_way"` without a `treatment:mediator` term | add the product term, or use `decomposition = "two_way"` |
| `Four-way decomposition currently supports continuous (Gaussian)` | the four-way decomposition with a binary or count variable | fit the interaction on continuous variables; see [Treatment-by-mediator interaction](https://data-wise.github.io/medfit/articles/model-interaction.md) |
| `quick() requires a MediationData` | [`quick()`](https://data-wise.github.io/medfit/reference/quick.md) got something other than a medfit result | use [`med()`](https://data-wise.github.io/medfit/reference/med.md) or [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md) first |
| `parm must be 'paths' or 'effects'` | [`confint()`](https://rdrr.io/r/stats/confint.html) got another `parm` | use `"paths"` or `"effects"` |

## Bootstrap and intervals

| You see | Cause | Fix |
|----|----|----|
| `mediation_data is required for parametric bootstrap` | the parametric and plugin methods need a fitted result | pass `mediation_data = fit`, or use `method = "nonparametric"` with `data` |
| `resamples whole clusters and needs method = "nonparametric"` | `cluster =` was combined with another method | set `method = "nonparametric"` |
| `Too many bootstrap samples failed` | your statistic function errors on most resamples | run `statistic_fn` once on your data and fix the error it raises |
| `bootstrap samples failed and were excluded` (a warning) | a few refits failed; the interval uses the rest | no action if it is a small share; otherwise check the statistic and the model |

## Cluster engine

| You see | Cause | Fix |
|----|----|----|
| `varies within clusters; 1-1-1 designs are not supported yet` | the treatment differs among members of a cluster | the engine needs the treatment assigned to whole clusters |
| `has no cluster-mean term for` | an `lmer` pair was passed without the mediator’s cluster mean | add the cluster mean and the within-cluster term to the outcome model; see [Cluster-randomized trials](https://data-wise.github.io/medfit/articles/model-cluster.md) |
| `clusters: inference on the cluster-level paths is unreliable` (a warning, fewer than 10 clusters) | too few clusters for any model-based interval | use `bootstrap_mediation(cluster = )` for the products |
| `fewer than 25` (a warning) | 10 to 24 clusters with model-based standard errors | add `se_type = "kr"`, and bootstrap clusters for the products |

## Native engine

| You see | Cause | Fix |
|----|----|----|
| `unknown parameter label` | a label in `:=` or a constraint is not defined in the model | label the path first: `y ~ b * m` |
| `meanstructure = FALSE, but the model writes an intercept` | `meanstructure = FALSE` was given with an intercept statement (`y ~ 1`) | drop the statement, or leave `meanstructure` unset |
| `` `fixed_x` names variables that are not exogenous observed variables `` | `fixed_x` named a variable that is an outcome, a mediator or a latent variable | name only variables that appear as predictors and are never outcomes |
| `` `fixed_x` fixes the moments of the selected variables, but the model has a statement on them `` | the model writes `x ~~ x` or `x ~ 1` for a selected variable (lavaan would keep it free) | remove the statement, or leave that variable out of `fixed_x` |
| `have different`fixed_x`sets` | [`AIC()`](https://rdrr.io/r/stats/AIC.html), [`BIC()`](https://rdrr.io/r/stats/AIC.html), [`anova()`](https://rdrr.io/r/stats/anova.html) or [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) got fits whose fixed sets differ, so their likelihoods condition on different variables | refit with the same `fixed_x`, or compare only fits that share it |
| `variables in the model are not columns of` | the syntax names a variable that is not in `data` | check the names against `names(data)` |
| `Must have length 1` | `fit_mediation(engine = "native")` was given several mediators | fit with [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md) and call [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md); see [several mediators](https://data-wise.github.io/medfit/articles/model-native-multi.md) |

## Messages that are not errors

| You see | Meaning |
|----|----|
| `Model-based standard errors are not valid under inverse-probability weighting` | you gave `weights` with `se_type = "model"`. Shown once per session. Add `se_type = "sandwich"` |
| the estimates use fewer rows than your data has | the model fits drop rows with missing values on their variables. [`nobs()`](https://rdrr.io/r/stats/nobs.html) reports the rows used in the development version; 0.7.0 reported every row of `data`, so there, count them with [`complete.cases()`](https://rdrr.io/r/stats/complete.cases.html) |

## Still stuck?

Run the failing call on `mediation_demo` with the same arguments. If
that works, the difference is in your data. If it fails the same way,
open an [issue](https://github.com/Data-Wise/medfit/issues) with the
call and the full message.
