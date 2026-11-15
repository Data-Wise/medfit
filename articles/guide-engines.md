# Which engine should I use?

Three choices sit behind every fit: the engine, the estimator and the
optimizer. This page takes them in that order. The engine decides which
models and effects exist. The estimator decides what is minimized. The
optimizer only searches for the minimum. The formulas are in [Methods
and Formulas](https://data-wise.github.io/medfit/articles/methods.md).

## Engine

An engine is the fitter: it decides which models can be written and
which effects come out. medfit names an engine for the model family it
fits or the package that fits it.

| Engine | Fits | Use it for | Page |
|----|----|----|----|
| `"glm"` (default) | [`stats::glm()`](https://rdrr.io/r/stats/glm.html) for the mediator and outcome models | formulas, any `glm` family, case weights | [Simple mediation](https://data-wise.github.io/medfit/articles/model-simple.md) |
| `"regmedint"` | closed-form natural effects from the regmedint package | VanderWeele’s regression closed forms | [The regmedint engine](https://data-wise.github.io/medfit/articles/model-regmedint.md) |
| `"lmer"` | REML mixed models with a random cluster intercept | a treatment assigned to clusters (2-1-1) | [Cluster-level treatment](https://data-wise.github.io/medfit/articles/model-cluster.md) |
| `"sem"` | the sem engine: medfit’s own maximum-likelihood SEM fitter | model syntax, latent mediators, constraints, [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) | [The sem engine](https://data-wise.github.io/medfit/articles/model-sem.md) |

The sem engine is reached in two ways: `fit_sem(model, data)`, which
returns a `SEMFit` for
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md),
and `fit_mediation(engine = "sem", model = )` for one mediator.
`engine = "native"` is the earlier spelling of the same engine and gives
the same fit.

> **The sem engine is not
> [`lavaan::sem()`](https://rdrr.io/pkg/lavaan/man/sem.html)**
>
> “sem” names medfit’s own fitter. A model fitted by
> [`lavaan::sem()`](https://rdrr.io/pkg/lavaan/man/sem.html) reaches
> medfit through
> [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
> on the lavaan fit. That is an extraction route, not an engine: lavaan
> does the fitting and medfit reads the paths. See [lavaan
> fits](https://data-wise.github.io/medfit/articles/model-lavaan.md) and
> [lavaan and the sem
> engine](https://data-wise.github.io/medfit/articles/lavaan-comparison.md).

The engines do not return interchangeable numbers. The [engines
compared](https://data-wise.github.io/medfit/articles/models.md) table
lists what each one estimates, which families it takes and which
standard errors it offers.

The two spellings give the same fit:

``` r
syntax <- "
  mediator1 ~ a * treatment + covariate1 + covariate2
  outcome ~ b * mediator1 + cp * treatment + covariate1 + covariate2
"
by_sem <- fit_mediation(model = syntax, data = mediation_demo,
                        treatment = "treatment", mediator = "mediator1",
                        engine = "sem")
by_native <- fit_mediation(model = syntax, data = mediation_demo,
                           treatment = "treatment", mediator = "mediator1",
                           engine = "native")
all.equal(coef(by_sem), coef(by_native))
```

    [1] TRUE

## Estimator

The estimator is what the engine minimizes. Within the sem engine, the
`missing` argument switches between two estimators:

- `missing = "listwise"` (default): maximum likelihood on the complete
  rows.
- `missing = "fiml"`: bounded full-information maximum likelihood, which
  keeps rows with some values missing. It covers a small set of models,
  is numerically verified and is not statistically admitted. See
  [Missing data: bounded
  FIML](https://data-wise.github.io/medfit/articles/model-fiml.md) for
  its limits.

Both are the same engine; only the objective changes, and so do the
estimates.

## Optimizer

The optimizer is the algorithm that finds the minimum of the estimator’s
objective.
[`sem_control()`](https://data-wise.github.io/medfit/reference/sem_control.md)
sets it for a listwise fit:

``` r
ctl <- sem_control(n_starts = 3, nloptr = list(maxeval = 20000L))
fit <- fit_sem(syntax, mediation_demo, control = ctl)
str(fit@diagnostics$protocol)
```

    List of 5
     $ version   : int 1
     $ estimator : chr "listwise"
     $ optimizer : chr "NLOPT_LD_SLSQP"
     $ n_starts  : int 3
     $ start_rule: chr "model_start_then_perturbed"

`optimizer = "auto"` (default) runs SLSQP for a listwise fit. A plain
list passed as `control` still means `nloptr` options. Bounded FIML runs
a fixed protocol, SLSQP and `nlminb` from three starts each, and the two
must agree; only `optimizer = "auto"` is accepted there. Every fit
records the protocol that ran in `fit@diagnostics$protocol`.

A different optimizer does not change what is estimated. When the search
fails, the fit stops with an error or reports an unresolved result; it
does not return a different answer.

## The four layers

| Layer | Question | Examples | Does swapping it change the meaning of the result? |
|----|----|----|----|
| Engine | which fitter, hence which models and effects exist | `glm`, `regmedint`, `lmer`, `sem` | yes |
| Estimator | what is minimized | OLS, REML, listwise ML, bounded FIML | yes |
| Optimizer | which algorithm finds the minimum | SLSQP, `nlminb` | no: same objective; a failure is an error or an unresolved result |
| Inference | how uncertainty is computed | delta method, sandwich, bootstrap, MBCO | the interval, not the estimate |

Inference is covered in [Which interval should I
use?](https://data-wise.github.io/medfit/articles/guide-intervals.md).

`compare_lr(engine = )` uses the word in another sense: there it names
the outside program, lavaan or OpenMx, that refits the model for the
comparison. It is not a fitter of the mediation model.

## Related

[Models](https://data-wise.github.io/medfit/articles/models.md) \| [The
sem engine
guide](https://data-wise.github.io/medfit/articles/sem-guide.md) \|
[Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md) \|
[Glossary](https://data-wise.github.io/medfit/articles/guide-glossary.md)
