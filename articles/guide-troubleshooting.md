# Troubleshooting: errors and warnings

Find your message in the tables below (use your browser’s search), read
the cause, and apply the fix. Every message here is quoted from the
package and checked by a test, so the wording matches what you see.

> **First, check your version**
>
> Examples on this site use medfit 0.13.0. If `mediation_demo` or
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
| `` `fixed_x` fixes the moments of the selected variables, but the model has a statement on them `` | the model writes `x ~~ x` or `x ~ 1` for a selected variable (lavaan would keep it free) | remove the statement, or leave that variable out of `fixed_x`. An unset `fixed_x` does this for you and sends a message instead of an error |
| `have different`fixed_x`sets` | [`AIC()`](https://rdrr.io/r/stats/AIC.html), [`BIC()`](https://rdrr.io/r/stats/AIC.html), [`anova()`](https://rdrr.io/r/stats/anova.html) or [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) got fits whose fixed sets differ, so their likelihoods condition on different variables | refit with the same `fixed_x`, or compare only fits that share it |
| `variables in the model are not columns of` | the syntax names a variable that is not in `data` | check the names against `names(data)` |
| `Must have length 1` | `fit_mediation(engine = "native")` was given several mediators | fit with [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md) and call [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md); see [several mediators](https://data-wise.github.io/medfit/articles/model-native-multi.md) |
| `latent means are planned for a later release` | a latent variable has a free or nonzero mean (`eta ~ 1`, `eta ~ 2*1`) | leave the latent mean at its default of 0 (`eta ~ 0*1` is accepted) |
| `no start converged` | no start satisfied the gates; the tail of the message says why, such as `is violated by` when two constraints contradict each other | read the tail; remove or correct the contradicting constraint, or check the scale of the data |
| `literal zero/nonzero contradiction` | the model holds an explicit `a == 0` and an explicit nonzero literal equality on the same label (`a == 1`, even `a == 1e-9`); the check is exact, with no tolerance, and the error also carries `$ledger` | remove or correct one of the two equalities |
| `the starts disagree` (a warning) | a model with a nonlinear inequality such as `a*b > 0.4` has more than one local optimum, and the starts reached different ones | the lowest discrepancy is kept; raise `n_starts` to search further |
| `is not nested in` | [`anova()`](https://rdrr.io/r/stats/anova.html) got a restricted model that frees a parameter the larger model leaves out, or does not keep one of its constraints | fit the restricted model by constraining or fixing parameters of the larger one |
| `the null lies on the boundary of the parameter space` (a warning) | [`anova()`](https://rdrr.io/r/stats/anova.html) or [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) tested a null that sits on an active bound or inequality, so the statistic is a mixture of chi-squares | do not read the p-value as chi-square(df); bootstrap, or compare on a model without the bound |
| `The MBCO statistic is not available (NA)` (a warning) | a refit inside [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) could not be fitted, usually because the null (`a == 0`) lies outside the constraints (`a > 0.3`) | read `$tests`: the failing row has `converged = FALSE` and the reason in `note`; the statistic and p-value are `NA`, never the minimum of the refits that worked; see [an unresolved result](#an-unresolved-mbco-result) |
| `zero-product branches did not converge` (an error) | a model with `a*b == 0` is fitted as one linear fit per factor, and at least one fit failed, so the best of the others need not be the constrained optimum and no fit is returned; the message lists each failed branch and the best survivor’s discrepancy; the error carries `$ledger` and `$best_survivor` (see [errors that carry evidence](#errors-that-carry-evidence)) | fit the model without the product constraint, or raise `n_starts`; [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) reports the same situation in a refit as an unresolved row |
| `a product ':' needs a variable name on each side` | a space around the colon in a product (`x :m`) | write the product without spaces: `x:m` |
| `(rule 8: no outcome-derived regressors)` | a product has a factor that is its own outcome or downstream of it (`y ~ x + x:y`) | build the product from variables that are not outcomes of that equation |
| `cannot have a residual covariance (rule 9)` | a model with a product has `m1 ~~ m2` between outcomes | drop the residual covariance, or fit without the product |
| `has a fixed coefficient (rule 9)` | a regression in a model with a product has a fixed value (`0.3*x`, `0*x`); the same rule covers bounds, shared labels and loops | free the coefficient; the full list is in the table in [the native model page](https://data-wise.github.io/medfit/articles/model-native.html#product-terms) |
| `names the coefficient label` | `==`, `<` or `>` in a model with a product names a coefficient label (`a == b`) | constrain a defined parameter (`:=`) instead, or fit without the product |
| `the model test is not valid for this model` (a warning) | a product has a factor that is itself an outcome, so the chi-square is not valid | the test is reported as NA and [`anova()`](https://rdrr.io/r/stats/anova.html) and [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) refuse; the coefficients and the sandwich standard errors are unaffected |
| `model-based standard errors assume normality, which a product violates` (a warning) | a model with a product was fitted without `se_type = "sandwich"` | add `se_type = "sandwich"` |
| `is an ordered factor` | a categorical covariate is an ordered factor; polynomial contrasts are not dummies | recode it with `factor(x, ordered = FALSE)` |
| `has only one level` | a categorical covariate has a single level, so it carries no information | drop it from the model |
| `makes the invalid name` | a level gives a dummy name that is not valid (a space, a leading digit) | rename the level; the message shows the dummy name |
| `is already a column of` | `data` already has a column named like a dummy (`group_mid`) | rename that column or the level |
| `expands to 2 terms` | a label, fixed value, start or bound sits on a categorical covariate (`b*group`) | put it on one dummy: `b*group_mid` |
| `is a categorical column, which a regression expands to dummies` | a constraint names the categorical covariate (`group == 0`) | label one dummy (`z*group_mid`) and constrain the label (`z == 0`) |
| `both sides are categorical columns` | a product of two categorical columns (`group:site`) | write the dummy products you need, such as `group_mid:site_s` |
| `is constant in the rows the fit uses` | a dummy has no variation: an unused factor level, or a level only in rows dropped for missing values | [`droplevels()`](https://rdrr.io/r/base/droplevels.html) the column, or check the missing values |
| `must be numeric: group` | a categorical column is an outcome or a mediator (only a covariate on a right side is expanded), or a column is a date or another type | recode it as a numeric column |

### An unresolved MBCO result

[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
does not stop when a refit fails. It returns the result with the failure
recorded, so a table of several tests is not lost to one bad refit:

``` r
res <- mbco_sem(fit, "a", "b")   # a warning explains the failure
res$unresolved                   # TRUE
res$tests                        # converged = FALSE for the failed refit, reason in `note`
res$statistic                    # NA: the MBCO test was not carried out
```

Check `res$unresolved` (or `all(res$tests$converged)`) before reading
`p.value`. A model or data error, such as a missing column or a label
constraint in a model with a product, still stops with its own message.
[`compare_lr()`](https://data-wise.github.io/medfit/reference/compare_lr.md)
follows the same rule: when medfit has no accepted reference, its
verdict is `"unresolved"` and `reference$lr` is `NA`.

### Errors that carry evidence

A native fit that cannot be trusted stops with a classed error, never
with a fit. Several of these errors carry the outcome ledger as
`$ledger` (what a ledger is: [the native
guide](https://data-wise.github.io/medfit/articles/native-guide.html#the-outcome-ledger));
read it before you rerun anything. An unresolved branch means unknown,
not infeasible: only a literal contradiction is a proof of emptiness.

| You see | Cause | What to do and where to look |
|----|----|----|
| `zero-product branches did not converge` (class `medfit_error_no_convergence`) | a branch of an `a*b == 0` model failed while another succeeded, so the best survivor need not be the constrained optimum | fit without the product constraint, or raise `n_starts`; look at `err$ledger` (one node per branch), `err$best_survivor` (`id` and `f`, for diagnosis only, never a p-value) |
| `no branch of the zero-product constraints converged` (class `medfit_error_no_convergence`; also `medfit_sem_empty_union` when every branch is certified empty) | no branch converged, or every branch holds a literal contradiction such as `a == 0` with `a == 1` | remove or correct the contradicting equalities; if no branch is certified empty, check the data scale; look at `err$ledger$children`: each child has `feasibility` (`certified_empty` is a proof) and `outcome` |
| `literal zero/nonzero contradiction` (class `medfit_sem_infeasible`) | the model’s own equalities contradict exactly (`a == 0` with `a == 1e-9` too); no tolerance | remove or correct one equality; look at `err$ledger$feasibility` |
| `branches to fit; at most 64 are supported` (a plain error) | the zero-product equalities give more than 64 raw branches, duplicates included, counted before anything is fitted; a count above 2^53 prints as `approximately` and an overflow as `overflow (Inf)` | state fewer zero-product equalities, or fit the branches you need one at a time; look at `err$ledger$enumeration`: `state` is `not_enumerated` and `required` is the raw count; `err$ledger$branch_map` has `raw_count` and an unknown unique count |
| the error message of the failing stage, with class `medfit_sem_covariance_error` | the optimizer accepted the fit and the covariance stage then failed; the likelihood is evidence, but the result is not a fit | fix the stage the message names, or simplify the model; look at `err$ledger` (`covariance` is `"failed"`, `post_fit` holds the original condition), `err$partial` (the accepted fit without `vcov`) |
| `likelihood retained, covariance unavailable` (a warning from [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)) | a refit null passed the optimizer and failed only in the covariance stage; the MBCO statistic and p-value use its likelihood and are unchanged | read the warning for the failure; no standard error was invented; look at `res$ledger$children`: the node of that null has `covariance = "failed"` |
| `missing, malformed or unresolved SEM outcome ledger` (class `medfit_error_ledger`) | [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) was given a fit whose ledger is absent, altered, forged or from an earlier release, so its evidence cannot be trusted | refit with the current medfit and call [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) on the new fit; look at `err$ledger$rejected_evidence` holds the refused ledger, when the fit had one |

`medfit_error_ledger` is a class of its own:
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
and
[`compare_lr()`](https://data-wise.github.io/medfit/reference/compare_lr.md)
report an optimizer failure as an unresolved result, but they refuse bad
evidence outright. The covariance error is a sibling of
`medfit_error_no_convergence`, so handlers written for an unresolved
refit do not catch it. How the ledger is built is in [Computation and
algorithms](https://data-wise.github.io/medfit/articles/computation-algorithms.html#a-zero-product-is-a-union-of-simpler-models).

``` r
err <- tryCatch(fit_sem(model, data), error = identity)
class(err)                       # the typed class says which case
err$ledger$children              # per-branch outcome and feasibility
err$best_survivor                # only for `medfit_error_no_convergence` with a survivor
```

## Messages that are not errors

| You see | Meaning |
|----|----|
| `Model-based standard errors are not valid under inverse-probability weighting` | you gave `weights` with `se_type = "model"`. Shown once per session. Add `se_type = "sandwich"` |
| `` fit_sem(): the `fixed_x` default leaves `` | with `fixed_x` unset, the named variables carry a `~~` or `~1` statement, so they stay free and the other exogenous variables are fixed. Shown on each fit. Pass `fixed_x` explicitly to choose |
| the estimates use fewer rows than your data has | the model fits drop rows with missing values on their variables. Since 0.8.0 [`nobs()`](https://rdrr.io/r/stats/nobs.html) and `n_obs` report the rows used; 0.7.0 and earlier reported every row of `data`, so there, count them with [`complete.cases()`](https://rdrr.io/r/stats/complete.cases.html) |

## Still stuck?

Run the failing call on `mediation_demo` with the same arguments. If
that works, the difference is in your data. If it fails the same way,
open an [issue](https://github.com/Data-Wise/medfit/issues) with the
call and the full message.
