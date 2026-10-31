# Models

Every model medfit can run, in one place. Find yours in the first table,
then open its page. For a one-page lookup of every function see the
[Reference
Card](https://data-wise.github.io/medfit/articles/refcard.md); for short
task recipes see the
[Cookbook](https://data-wise.github.io/medfit/articles/cookbook.md).

## Find your model

| I have | Page |
|----|----|
| One mediator, a continuous outcome | [Simple mediation](https://data-wise.github.io/medfit/articles/model-simple.md) |
| A binary or count outcome, or a binary mediator | [Binary and non-normal variables](https://data-wise.github.io/medfit/articles/model-glm-families.md) |
| An effect of the mediator that depends on the treatment | [Treatment-by-mediator interaction](https://data-wise.github.io/medfit/articles/model-interaction.md) |
| Inverse-probability weights or case weights | [Weights and robust SEs](https://data-wise.github.io/medfit/articles/model-weights.md) |
| The closed-form regression engine | [The regmedint engine](https://data-wise.github.io/medfit/articles/model-regmedint.md) |
| Mediators in a chain (M1 drives M2) | [Serial mediation](https://data-wise.github.io/medfit/articles/model-serial.md) |
| Mediators side by side | [Parallel mediation](https://data-wise.github.io/medfit/articles/model-parallel.md) |
| Several mediators and treatment-by-mediator products | [Joint mediation](https://data-wise.github.io/medfit/articles/model-joint.md) |
| Treatment assigned to whole clusters | [Cluster-randomized trials](https://data-wise.github.io/medfit/articles/model-cluster.md) |
| A lavaan fit | [lavaan fits](https://data-wise.github.io/medfit/articles/model-lavaan.md) |
| A model written as syntax, with defined parameters | [Native: paths and defined parameters](https://data-wise.github.io/medfit/articles/model-native.md) |
| A latent mediator | [Native: a latent mediator](https://data-wise.github.io/medfit/articles/model-native-latent.md) |
| Constraints, or a test of the indirect effect | [Native: constraints and MBCO](https://data-wise.github.io/medfit/articles/model-native-constraints.md) |
| Serial or parallel mediators, or weights, in syntax | [Native: several mediators and weights](https://data-wise.github.io/medfit/articles/model-native-multi.md) |
| A factor, character or logical covariate in syntax | [Native: categorical covariates](https://data-wise.github.io/medfit/articles/model-native-factors.md) |

## Capabilities at a glance

| Model | Class | Engines and routes | Standard errors | Page |
|----|----|----|----|----|
| Simple | `MediationData` | `glm`, `regmedint`, [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) (`lm`/`glm`, lavaan), native | model, sandwich | [simple](https://data-wise.github.io/medfit/articles/model-simple.md) |
| Binary or count variables | `MediationData` | `glm` families | model, sandwich | [glm families](https://data-wise.github.io/medfit/articles/model-glm-families.md) |
| Treatment-by-mediator | `InteractionMediationData` | `glm`, `regmedint`, lavaan, native ([`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md) with `x:m`) | model; closed form (`regmedint`) | [interaction](https://data-wise.github.io/medfit/articles/model-interaction.md) |
| Weighted | `MediationData` | `glm`; native `weights` | sandwich (HC3; native HC0-type) | [weights](https://data-wise.github.io/medfit/articles/model-weights.md) |
| Serial | `SerialMediationData` | `lm`/`glm` with `mediator_models`, lavaan, native via [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md) | model | [serial](https://data-wise.github.io/medfit/articles/model-serial.md) |
| Parallel | `ParallelMediationData` | `lm`/`glm`, lavaan, native via [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md) | model | [parallel](https://data-wise.github.io/medfit/articles/model-parallel.md) |
| Joint, with products | `JointMediationData` | `lm` fits | delta method, bootstrap | [joint](https://data-wise.github.io/medfit/articles/model-joint.md) |
| Cluster-level treatment (2-1-1) | `ClusterMediationData` | `lmer` fits or `engine = "lmer"` | model, Kenward-Roger (`"kr"`) | [cluster](https://data-wise.github.io/medfit/articles/model-cluster.md) |
| Latent mediator, constraints | `SEMFit`, then extracted | [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md), `engine = "native"` | model, sandwich | [native](https://data-wise.github.io/medfit/articles/model-native.md), [latent](https://data-wise.github.io/medfit/articles/model-native-latent.md) |
| Categorical covariates (0.11.0) | `SEMFit`, then extracted | [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md) with a factor, character or logical column | model, sandwich | [categorical covariates](https://data-wise.github.io/medfit/articles/model-native-factors.md) |

Inference works on every row: delta-method intervals from
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
[`confint()`](https://rdrr.io/r/stats/confint.html), and the parametric,
nonparametric and plugin bootstrap (see [Bootstrap
Inference](https://data-wise.github.io/medfit/articles/bootstrap.md)).

> **The native engine takes one mediator in
> [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)**
>
> `fit_mediation(engine = "native", model = )` accepts a single
> mediator. For several mediators, fit the syntax with
> [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
> (see [Native: several mediators and
> weights](https://data-wise.github.io/medfit/articles/model-native-multi.md))
> and then call `extract_mediation(fit, mediator = c(...), outcome = )`,
> with `structure = "parallel"` for side-by-side mediators.

## The `fit_mediation()` engines compared

The four engines answer different questions and do not return
interchangeable numbers. Read the row for your engine before you swap
one for another.

|  | `glm` (default) | `regmedint` | `lmer` | `native` |
|----|----|----|----|----|
| Estimation | [`stats::glm()`](https://rdrr.io/r/stats/glm.html) for the mediator and outcome models | closed-form natural effects from the regmedint package | REML mixed models, a random cluster intercept in both | maximum-likelihood SEM from syntax (`model =`) |
| Outcome and mediator families | any `glm` family | a linear mediator model; the outcome may be logistic | Gaussian only | Gaussian only |
| Indirect effect | product of path coefficients, on the link scale when the link is not the identity | regmedint’s natural indirect effect; equals the path product only for a linear mediator model and a unit treatment contrast (the adapter errors otherwise) | `a * b_between` (own and spillover parts in [`decompose()`](https://data-wise.github.io/medfit/reference/decompose.md)) | the path product from the fitted syntax |
| Case `weights` | yes | no | no | yes (weighted maximum likelihood) |
| `se_type = "sandwich"` | yes, HC3 | no (`"model"` only) | no (`"model"` or `"kr"`) | yes, HC0-type, a little smaller than HC3 in finite samples |
| Rows with missing values | dropped once, both models share the sample | dropped by the engine | dropped once | listwise by default; the separate bounded FIML opt-in drops only all-empty model rows |
| Returns | `MediationData` or `InteractionMediationData` | the same two classes | `ClusterMediationData` | `SEMFit`, then [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) |

The native column describes the default listwise path. The separate
[bounded FIML
workflow](https://data-wise.github.io/medfit/articles/native-guide.html#bounded-fiml)
is limited to three numeric continuous observed variables, explicit
random X and observed/model SEs; weights, bootstrap and fit tests are
deferred for those objects. Bounded FIML is available from 0.16.0 and is
unavailable in released 0.15.0.

A weight or an SE type that an engine does not take is an error, not an
ignored argument, so a silent change of estimand is not possible through
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md).
The estimand still differs where the table says so: a logistic outcome
through `glm` gives a path product on the log-odds scale, while
`regmedint` gives a natural effect.

## What medfit does not run

- Treatment varying within clusters (1-1-1), and non-Gaussian outcomes
  or mediators in the cluster design.
- Four-way or joint decompositions with non-Gaussian models.
- Latent means (a free latent mean or intercept) on the native engine,
  and products with a latent variable. Observed intercepts and means
  (`y ~ 1`, `meanstructure =`) and the observed product `x:m` with its
  four-way decomposition are supported.
- Bayesian fits through `brms` (planned).

See [Methods and
Formulas](https://data-wise.github.io/medfit/articles/methods.md) for
the assumptions behind each model.
