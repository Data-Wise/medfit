# What changed since CRAN 0.3.2

CRAN has medfit 0.3.2; this site documents 0.7.0 (GitHub and
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
>   page](https://data-wise.github.io/medfit/#installation).

## Numbers that change

| Version | What | Before | Now |
|----|----|----|----|
| 0.5.0 | serial [`te()`](https://data-wise.github.io/medfit/reference/te.md) and [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) | summed only the chain and the direct effect (`a * d * b + c'`), leaving out paths that skip a mediator | sum every path from treatment to outcome; [`te()`](https://data-wise.github.io/medfit/reference/te.md) equals the treatment coefficient of `lm(Y ~ X + covariates)` when the models are linear with the same covariates |
| 0.5.0 | `confint(parm = "paths")` | looked for lm-style row names only; on lavaan-extracted objects the `b` and `c'` standard errors were swapped | finds each path by name, and stops with an error naming the missing rows |
| 0.5.0 | `confint(parm = "effects")` for a simple fit | the total-effect interval was too wide (it dropped the covariance of the indirect effect and `c'`) | full delta-method gradient; on the `mediation_demo` fit the total-effect SE is 0.119, not 0.127 |
| 0.5.0 | four-way decomposition with factor or transformed covariates | the covariate means skipped them, so NDE, INTref and the total were wrong | means come from the mediator model’s design matrix; with weights, they are weighted |
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

## Calls that now stop with an error

Each of these was accepted before and gave a wrong or ignored result.

| Version | Call | Message to look for | What to do |
|----|----|----|----|
| 0.5.0 | `m_star` supplied with no treatment-by-mediator term | `applies only when the outcome model has a treatment-by-mediator` | drop `m_star`, or add the product term |
| 0.5.0 | a product written inside a function, such as `I(X * M)` | `Found function-wrapped treatment-by-mediator product term(s)` | write it as `X * M` or `X:M` |
| 0.5.0 | a product among mediators in a multi-mediator model | `Multi-mediator (serial or parallel) extraction supports only treatment-by-mediator product terms` | refit without it; a treatment-by-mediator product in the outcome model is supported (see [Joint mediation](https://data-wise.github.io/medfit/articles/model-joint.md)) |
| 0.5.0 | four-way decomposition with a non-identity link | `Four-way decomposition requires the identity link` | refit with `gaussian(link = "identity")` |
| 0.7.0 | a [`glm()`](https://rdrr.io/r/stats/glm.html) argument passed through `...` that partly matches `model`, such as `mod = FALSE` | `is only used with engine = "native"` | drop the argument; [`glm()`](https://rdrr.io/r/stats/glm.html)’s own `model` cannot be passed through [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md) |

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

## Dependencies

0.7.0 adds `lifecycle` and `nloptr (>= 1.0.4)` to `Imports`, and
`OpenMx` to `Suggests` (the tests use it as an independent check).

## Related

[Troubleshooting](https://data-wise.github.io/medfit/articles/guide-troubleshooting.md)
\| [Models](https://data-wise.github.io/medfit/articles/models.md) \|
[Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md)
