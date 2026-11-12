# How medfit is organized

medfit separates what a mediation model is (an S7 class per structure)
from how it was obtained (an engine or an
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
method) and from what you ask of it (generics such as
[`nie()`](https://data-wise.github.io/medfit/reference/nie.md) and
[`tidy()`](https://generics.r-lib.org/reference/tidy.html)). This page
maps those three layers. The [Reference
Card](https://data-wise.github.io/medfit/articles/refcard.md) lists
every function; this page shows how they connect.

## From a model to an object

``` default
flowchart LR
  subgraph Sources
    LM["lm / glm fits"]
    LAV["lavaan fits"]
    LMER["lmer fits"]
    TWO["two-level lavaan fit"]
  end
  subgraph Engines["fit_mediation() and fit_sem()"]
    GLM["glm"]
    REG["regmedint"]
    LME["lmer"]
    NAT["native (ML SEM, FIML)"]
  end
  EX["extract_mediation()"]
  Sources --> EX
  Engines --> EX
  EX --> OBJ["a mediation object"]
```

``` mermaid
flowchart LR
  subgraph Sources
    LM["lm / glm fits"]
    LAV["lavaan fits"]
    LMER["lmer fits"]
    TWO["two-level lavaan fit"]
  end
  subgraph Engines["fit_mediation() and fit_sem()"]
    GLM["glm"]
    REG["regmedint"]
    LME["lmer"]
    NAT["native (ML SEM, FIML)"]
  end
  EX["extract_mediation()"]
  Sources --> EX
  Engines --> EX
  EX --> OBJ["a mediation object"]
```

[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
fits and then extracts;
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
alone reads a model you already fitted and never refits. Native fits
return a `SEMFit` first, which
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
then converts.

## The classes

| Class | Structure | Typical source |
|----|----|----|
| `MediationData` | X to M to Y | `lm`, `glm`, `lavaan`, [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md) |
| `InteractionMediationData` | X to M to Y with an X by M product (four-way decomposition) | `lm`, `glm`, native with the `:` term |
| `SerialMediationData` | X to M1 to … to Mk to Y | `lm`, `glm`, `lavaan`, native |
| `ParallelMediationData` | X to several mediators to Y | `lm`, `glm`, `lavaan`, native |
| `JointMediationData` | several mediators with X by M products | `lm` |
| `ClusterMediationData` | cluster-level treatment (2-1-1) | `lmer`, `fit_mediation(engine = "lmer")` |
| `TwoLevelMediationData` | X, M and Y on level-1 units (1-1-1), within and between effects | two-level `lavaan` fit |
| `FIMLMediationData`, `FIMLParallelMediationData`, `FIMLSerialMediationData` | bounded full-information ML for missing data | native engine with `missing = "fiml"` |
| `SEMFit` | a native structural equation fit (the input to extraction) | [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md) |
| `BootstrapResult` | an interval and its draws | [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md) |

Each structure has its own class so that its effects, covariance and
checks stay separate; the
[Models](https://data-wise.github.io/medfit/articles/models.md) pages
describe one structure each.

## What you ask of an object

``` default
flowchart TB
  OBJ["a mediation object"]
  OBJ --> EFF["nie() nde() te() pm() paths() decompose()"]
  OBJ --> TID["tidy() glance() summary() confint()"]
  OBJ --> BOOT["bootstrap_mediation()"]
  BOOT --> BR["BootstrapResult"]
```

``` mermaid
flowchart TB
  OBJ["a mediation object"]
  OBJ --> EFF["nie() nde() te() pm() paths() decompose()"]
  OBJ --> TID["tidy() glance() summary() confint()"]
  OBJ --> BOOT["bootstrap_mediation()"]
  BOOT --> BR["BootstrapResult"]
```

The effect generics read the stored paths and covariance and compute
delta-method standard errors; classes with a level or a decomposition
take extra arguments (`level =` for two-level objects).
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
takes a statistic function (for two-level objects,
[`twolevel_statistic()`](https://data-wise.github.io/medfit/reference/twolevel_statistic.md))
and returns a `BootstrapResult`.

## Where this lives in the code

| Concern | Files |
|----|----|
| Classes | `R/classes.R`, `R/classes-twolevel.R` |
| Generics and their methods | `R/aab-generics.R`, `R/generics-effects.R`, `R/methods-*.R` |
| Fitting engines | `R/fit-*.R`, `R/sem-*.R` |
| Extraction | `R/extract-*.R` |
| Effect standard errors | `R/effect-se.R` |
| Bootstrap | `R/bootstrap.R`, `R/twolevel-statistic.R` |

S7 generics load before their methods (the `aab-` file prefix), and the
classes are registered with S4 in `.onLoad()` so that they dispatch in
installed packages.
