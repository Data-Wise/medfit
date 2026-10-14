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
| Latent mediator, constraints | `SEMFit`, then extracted | [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md), `engine = "native"` (experimental) | model, sandwich | [native](https://data-wise.github.io/medfit/articles/model-native.md), [latent](https://data-wise.github.io/medfit/articles/model-native-latent.md) |

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
