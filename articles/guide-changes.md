# What changed since CRAN 0.3.2

CRAN has medfit 0.3.2; this site documents 0.13.0 (GitHub and
r-universe). This page lists what a 0.3.2 user needs to know before
upgrading: numbers that change, calls that now stop with an error, and
what is new. The full record is
[NEWS](https://data-wise.github.io/medfit/news/index.html).

> **The short version**
>
> - **Two results were wrong in 0.3.2 and are fixed:** serial
>   [`te()`](https://data-wise.github.io/medfit/reference/te.md)/[`pm()`](https://data-wise.github.io/medfit/reference/pm.md),
>   and `confint(parm = "paths")` on lavaan-extracted objects. See issue
>   [\#83](https://github.com/Data-Wise/medfit/issues/83).
> - **Several silent mistakes now stop with an error.** If code that ran
>   before fails now, check the second table.
> - **Install** from r-universe or GitHub; see the [home
>   page](https://data-wise.github.io/medfit/#install).

## Numbers that change

| Version | What | Before | Now |
|----|----|----|----|
| 0.5.0 | serial [`te()`](https://data-wise.github.io/medfit/reference/te.md) and [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) | summed only the chain and the direct effect (`a * d * b + c'`), leaving out paths that skip a mediator | sum every path from treatment to outcome; [`te()`](https://data-wise.github.io/medfit/reference/te.md) equals the treatment coefficient of `lm(Y ~ X + covariates)` when the models are linear with the same covariates |
| 0.5.0 | `confint(parm = "paths")` | looked for lm-style row names only; on lavaan-extracted objects the `b` and `c'` standard errors were swapped | finds each path by name, and stops with an error naming the missing rows |
| 0.5.0 | `confint(parm = "effects")` for a simple fit | the total-effect interval was too wide (it dropped the covariance of the indirect effect and `c'`) | full delta-method gradient; on the `mediation_demo` fit the total-effect SE is 0.119, not 0.127 |
| 0.5.0 | four-way decomposition with factor or transformed covariates | the covariate means skipped them, so NDE, INTref and the total were wrong | means come from the mediator model’s design matrix; with weights, they are weighted |
| 0.8.0 | [`nobs()`](https://rdrr.io/r/stats/nobs.html), `@n_obs` and [`med()`](https://data-wise.github.io/medfit/reference/med.md) when the data have missing values on a model variable | counted `nrow(data)` although [`glm()`](https://rdrr.io/r/stats/glm.html) had dropped the incomplete rows: 5 missing treatment values in 400 rows gave 400 | count the rows the models used (395 in that example); [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md) drops rows that are incomplete on any variable in either formula before fitting, so both models share one sample |
| 0.9.0 | standard errors of INTref, NDE and the total effect from [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) of a lavaan four-way fit when the mediator equation has a covariate | left out the covariate-mean term, so they were too small: INTref SE 0.022 against 0.069 from lavaan’s own `:=` (measured on 0.8.0; 0.3.2 has no [`tidy()`](https://generics.r-lib.org/reference/tidy.html) for these objects) | equal lavaan’s `:=` (0.069) |
| 0.9.0 | INTref from a lavaan four-way fit with sampling weights | used unweighted covariate means, so it differed from the lm/glm route: 0.726 against 0.841 on the check data | uses the weighted means and equals the lm/glm route (0.841) |
| 0.8.0 | the names in [`coef()`](https://rdrr.io/r/stats/coef.html), [`vcov()`](https://rdrr.io/r/stats/vcov.html) and [`tidy()`](https://generics.r-lib.org/reference/tidy.html) of a `SEMFit` | an unlabeled parameter was `"M ~ X"` or `"X ~~ X"` (with spaces) and a loading `"m2 ~ eta"` | `"M~X"`, `"X~~X"` and `"eta=~m2"`, the names `lavaan::coef()` uses; labeled parameters are unchanged |
| 0.9.0 | a fixed intercept, `y ~ 0*1`, in the native engine | the row was dropped and the covariance-only fit returned | a restriction (“the mean of `y` is 0”): one degree of freedom, a changed discrepancy, comparable with [`anova()`](https://rdrr.io/r/stats/anova.html); any `y ~ 1` row turns the mean structure on |
| 0.9.0 | [`logLik()`](https://rdrr.io/r/stats/logLik.html), [`AIC()`](https://rdrr.io/r/stats/AIC.html), [`BIC()`](https://rdrr.io/r/stats/AIC.html) of a native fit with `fixed_x` | (new argument) | conditional on the fixed variables; [`anova()`](https://rdrr.io/r/stats/anova.html), [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) and multi-fit [`AIC()`](https://rdrr.io/r/stats/AIC.html)/[`BIC()`](https://rdrr.io/r/stats/AIC.html) stop when fixed sets or data differ; [`glance()`](https://generics.r-lib.org/reference/glance.html) gains a `fixed_x` column |
| 0.10.0 | `extract_mediation(<SEMFit>, decomposition = "four_way")` | refused by name until the `:` operator existed | returns the four-way decomposition when the outcome equation carries the treatment-by-mediator product; refused with a message that says to add `x:m` when it does not |
| 0.14.0 | [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md) and `fit_mediation(engine = "native")` with `fixed_x` or `meanstructure` left unset | (no warning) | same results, plus a once-per-session warning of class `medfit_warning_default_change`: in 0.15.0 the defaults become the exogenous observed variables and `TRUE`, which moves `npar`, [`logLik()`](https://rdrr.io/r/stats/logLik.html), AIC and BIC; pass both arguments to keep today’s results, or set `options(medfit.native_defaults = "0.15")` to use the new defaults now |
| 0.5.0 | `se_type = "sandwich"` with a treatment-by-mediator term | returned the model-based covariance, with no warning | applies the sandwich estimator |
| 0.5.0 | lavaan fits with custom path labels | the alias rows of `@vcov` were all zero, so a parametric bootstrap had a zero-width interval | the alias rows are filled from the labeled parameters |

What did **not** change:
[`nie()`](https://data-wise.github.io/medfit/reference/nie.md) for
serial objects still returns the chain effect by default. The new
`nie(x, type = "total")` returns the total indirect effect.

If you stored serial
[`te()`](https://data-wise.github.io/medfit/reference/te.md) or
[`pm()`](https://data-wise.github.io/medfit/reference/pm.md) values from
0.4.0 or earlier, rerun them.

## Names that changed

Code that reads a result by column name, or passes an argument by name,
breaks silently when the name changes. These two renames are the ones to
search your scripts for.

| Version | What | Before | Now |
|----|----|----|----|
| 0.9.0 | [`tidy()`](https://generics.r-lib.org/reference/tidy.html) columns | `std.error`, `conf.low`, `conf.high` (and `p.value` for a `SEMFit`, which exists from 0.7.0) | `std_error`, `conf_low`, `conf_high`, `p_value`; [`glance()`](https://generics.r-lib.org/reference/glance.html) of a `SEMFit` has `p_value` too; [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) keeps `p.value` because it returns a base-R `htest` |
| 0.9.0 | [`tidy()`](https://generics.r-lib.org/reference/tidy.html) arguments | `conf.int = TRUE`, `conf.level = 0.9` | `conf_int = TRUE`, `conf_level = 0.9`; the dotted names still work and warn (`is deprecated as of medfit 0.9.0`) |
| 0.9.0 | class of a [`summary()`](https://rdrr.io/r/base/summary.html) result | `summary.MediationData` | `summary_MediationData` (likewise `summary_SEMFit` and the other classes) |
| 0.8.0 | `fit_sem(sampling_weights = )`, only for code written against 0.7.0 | the argument name in 0.7.0 | `fit_sem(weights = )`, the name [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md) uses; the old name still works and warns once per session |

## Calls that now stop with an error

Each of these was accepted before and gave a wrong or ignored result.

| Version | Call | Message to look for | What to do |
|----|----|----|----|
| 0.5.0 | `m_star` supplied with no treatment-by-mediator term | `applies only when the outcome model has a treatment-by-mediator` | drop `m_star`, or add the product term |
| 0.5.0 | a product written inside a function, such as `I(X * M)` | `Found function-wrapped treatment-by-mediator product term(s)` | write it as `X * M` or `X:M` |
| 0.5.0 | a product among mediators in a multi-mediator model | `Multi-mediator (serial or parallel) extraction supports only treatment-by-mediator product terms` | refit without it; a treatment-by-mediator product in the outcome model is supported (see [Joint mediation](https://data-wise.github.io/medfit/articles/model-joint.md)) |
| 0.5.0 | four-way decomposition with a non-identity link | `Four-way decomposition requires the identity link` | refit with `gaussian(link = "identity")` |
| 0.7.0 | a [`glm()`](https://rdrr.io/r/stats/glm.html) argument passed through `...` that partly matches `model`, such as `mod = FALSE` | `is only used with engine = "native"` | drop the argument; [`glm()`](https://rdrr.io/r/stats/glm.html)’s own `model` cannot be passed through [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md) |
| 0.9.0 | a lavaan four-way fit that has a product of the treatment with a covariate in the mediator or the outcome equation (`m ~ x + xc`) | `does not support a treatment product` | it changed the effects without changing a coefficient the decomposition reads, and 0.8.0 returned a decomposition without a message; remove the product, or fit without the four-way decomposition |
| 0.11.0 | [`AIC()`](https://rdrr.io/r/stats/AIC.html) or [`BIC()`](https://rdrr.io/r/stats/AIC.html) of several `SEMFit`s over different observed variables, such as a fit with a product term and one without | `different observed variables` | the likelihoods describe different data, so they are not comparable; compare fits over the same variables ([`anova()`](https://rdrr.io/r/stats/anova.html) and [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) refuse the same pair) |
| 0.11.1 | [`anova()`](https://rdrr.io/r/stats/anova.html) of two `SEMFit`s where a nonzero fixed parameter (for example `M1 ~~ 0.5*M2`) is in one fit and absent from the other | `nonzero fixed parameters differ` | fit the restricted model by fixing or constraining parameters of the larger one, so both fits carry the same fixed values |
| 0.13.0 | [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md) of a model with a zero-product constraint (`a*b == 0`) where one branch cannot be fitted while another succeeds | `zero-product branches did not converge` | 0.12.0 returned the best surviving branch with a warning, and that fit could be used as if it were certified; fit the model without the product constraint, or raise `n_starts` |

Two more stop in situations 0.3.2 could not reach: two `lmer` fits that
kept different individuals within the same clusters (0.6.0), and a
lavaan label that reuses one of medfit’s alias names for a different
path (0.5.0).

## Objects that gained something

| Version | What | Effect on your code |
|----|----|----|
| 0.5.0 | serial objects gain a `nie_total` row in [`tidy()`](https://generics.r-lib.org/reference/tidy.html), a `nie_total` column in [`glance()`](https://generics.r-lib.org/reference/glance.html), and `indirect_total` in `coef(type = "effects")` | appended after the existing entries, so positions are unchanged |
| 0.7.0 | a lavaan fit of a simple single-mediator model appends the rows `m_<treatment>`, `y_<mediator>` and `y_<treatment>` to `@estimates` and `@vcov` | code that indexes these by position past the `a`, `b`, `c_prime` rows sees three more rows; code that looks rows up by name is fine |

## What is new

| Version | New |
|----|----|
| 0.4.0 | the `regmedint` engine, `engine_args`, and `m_star` in [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md); see [The regmedint engine](https://data-wise.github.io/medfit/articles/model-regmedint.md) |
| 0.5.0 | joint mediation ([page](https://data-wise.github.io/medfit/articles/model-joint.md)); the bundled `mediation_demo` data; delta-method standard errors in [`tidy()`](https://generics.r-lib.org/reference/tidy.html); [`confint()`](https://rdrr.io/r/stats/confint.html) and [`coef()`](https://rdrr.io/r/stats/coef.html) for bootstrap results |
| 0.6.0 | cluster-randomized designs ([page](https://data-wise.github.io/medfit/articles/model-cluster.md)); the [Reference Card](https://data-wise.github.io/medfit/articles/refcard.md) and [Cookbook](https://data-wise.github.io/medfit/articles/cookbook.md) |
| 0.7.0 | the native maximum-likelihood engine ([page](https://data-wise.github.io/medfit/articles/model-native.md)), [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md), and sampling weights with robust standard errors for it |
| 0.8.0 | nonlinear constraints in the native engine ([page](https://data-wise.github.io/medfit/articles/model-native-constraints.md)), `mbco_sem(paths = )` for a product of k paths, [`anova()`](https://rdrr.io/r/stats/anova.html), [`tidy()`](https://generics.r-lib.org/reference/tidy.html)/[`glance()`](https://generics.r-lib.org/reference/glance.html)/[`confint()`](https://rdrr.io/r/stats/confint.html) for `SEMFit`, [lavaan and the native engine](https://data-wise.github.io/medfit/articles/lavaan-comparison.md), and cookbook recipes 12 and 13 |
| 0.9.0 | observed intercepts and means in the native engine (`y ~ 1`, `meanstructure =`), `fixed_x` ([page](https://data-wise.github.io/medfit/articles/model-native.md)), cookbook recipe 18 and step 9 of the [native tutorial](https://data-wise.github.io/medfit/articles/native-tutorial.md) |
| 0.10.0 | the product term `x:m` in native syntax and the four-way decomposition from a native fit ([`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) on a [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md) fit), a supported-class table, and a worked example in the [interaction page](https://data-wise.github.io/medfit/articles/model-interaction.md) |
| 0.11.0 | categorical covariates in native syntax ([page](https://data-wise.github.io/medfit/articles/model-native-factors.md), [recipe 21](https://data-wise.github.io/medfit/articles/cookbook.html#a-categorical-covariate-in-a-native-fit)); `options(medfit.covariate_mean_variance = TRUE)` for population-average four-way standard errors (default unchanged); [`AIC()`](https://rdrr.io/r/stats/AIC.html)/[`BIC()`](https://rdrr.io/r/stats/AIC.html) refuse fits over different observed variables; nonlinear-constrained fits no longer wander to negative variances (#213); the native engine is no longer marked experimental (its signatures, `SEMFit` properties and syntax change only through a deprecation) |
| 0.11.1 | nonparametric and cluster bootstrap resamples are reproducible across `ncores` with a fixed seed; [`anova()`](https://rdrr.io/r/stats/anova.html) records row-wise `p_valid` and refuses mismatched nonzero fixed parameters; native fits record the best-of-starts verdict in `@diagnostics$optimum` |
| 0.12.0 | [`compare_lr()`](https://data-wise.github.io/medfit/reference/compare_lr.md) ([article](https://data-wise.github.io/medfit/articles/lavaan-comparison.html#checking-a-constrained-lr-against-lavaan-or-openmx)): the product-null LR in lavaan or OpenMx against [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md), with warnings only on observed evidence |
| 0.13.0 | a roundoff-limited restoration’s objective rise is capped (a worse point can no longer stand and inflate an LR); a refit the optimizer cannot fit is an unresolved result in [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) and [`compare_lr()`](https://data-wise.github.io/medfit/reference/compare_lr.md) instead of an error or a silent answer, and a zero-product branch that cannot be fitted stops [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md) with an error instead of returning a partial fit |

## Dependencies

0.7.0 adds `lifecycle` and `nloptr (>= 1.0.4)` to `Imports`, and
`OpenMx` to `Suggests` (the tests use it as an independent check). 0.8.0
adds `withr` to `Suggests` (tests only).

## Related

[Troubleshooting](https://data-wise.github.io/medfit/articles/guide-troubleshooting.md)
\| [Models](https://data-wise.github.io/medfit/articles/models.md) \|
[Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md)
