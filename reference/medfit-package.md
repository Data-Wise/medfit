# medfit: Infrastructure for Mediation Model Fitting and Extraction

Provides S7-based infrastructure for fitting mediation models,
extracting path coefficients, and performing bootstrap inference.
Designed as a foundation package for probmed, RMediation, and medrobust.

## Details

Key functions:

- [`med`](https://data-wise.github.io/medfit/reference/med.md),
  [`quick`](https://data-wise.github.io/medfit/reference/quick.md): Fit
  and extract in one step

- [`fit_mediation`](https://data-wise.github.io/medfit/reference/fit_mediation.md):
  Fit mediation models

- [`fit_sem`](https://data-wise.github.io/medfit/reference/fit_sem.md),
  [`sem_control`](https://data-wise.github.io/medfit/reference/sem_control.md):
  Fit model syntax with the sem engine and set its optimizer

- [`extract_mediation`](https://data-wise.github.io/medfit/reference/extract_mediation.md):
  Extract from fitted models

- [`bootstrap_mediation`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md):
  Bootstrap inference

- [`nie`](https://data-wise.github.io/medfit/reference/nie.md),
  [`nde`](https://data-wise.github.io/medfit/reference/nde.md),
  [`te`](https://data-wise.github.io/medfit/reference/te.md),
  [`pm`](https://data-wise.github.io/medfit/reference/pm.md),
  [`decompose`](https://data-wise.github.io/medfit/reference/decompose.md):
  Effects

- [`joint_effects`](https://data-wise.github.io/medfit/reference/joint_effects.md):
  Joint effects at a parameter vector

- [`paths`](https://data-wise.github.io/medfit/reference/paths.md): Path
  coefficients

- [`mbco_sem`](https://data-wise.github.io/medfit/reference/mbco_sem.md),
  [`compare_lr`](https://data-wise.github.io/medfit/reference/compare_lr.md):
  The MBCO likelihood-ratio test of an indirect effect; the product-null
  LR compared with lavaan or OpenMx

- [`twolevel_statistic`](https://data-wise.github.io/medfit/reference/twolevel_statistic.md):
  Bootstrap callback for two-level fits (experimental)

Key classes:

- [`MediationData`](https://data-wise.github.io/medfit/reference/MediationData.md):
  Simple mediation

- [`InteractionMediationData`](https://data-wise.github.io/medfit/reference/InteractionMediationData.md):
  Simple mediation with a treatment-by-mediator interaction (four-way
  decomposition)

- [`SerialMediationData`](https://data-wise.github.io/medfit/reference/SerialMediationData.md):
  Serial chain of mediators

- [`ParallelMediationData`](https://data-wise.github.io/medfit/reference/ParallelMediationData.md):
  Parallel mediators

- [`JointMediationData`](https://data-wise.github.io/medfit/reference/JointMediationData.md):
  Joint natural effects of several mediators with treatment-by-mediator
  products

- [`ClusterMediationData`](https://data-wise.github.io/medfit/reference/ClusterMediationData.md):
  Treatment assigned to clusters (2-1-1)

- [`TwoLevelMediationData`](https://data-wise.github.io/medfit/reference/TwoLevelMediationData.md),
  [`TwoLevelParallelMediationData`](https://data-wise.github.io/medfit/reference/TwoLevelParallelMediationData.md):
  Two-level `lavaan` fits (1-1-1), one or several parallel mediators
  (experimental)

- [`SEMFit`](https://data-wise.github.io/medfit/reference/SEMFit.md): A
  sem engine fit

- [`BootstrapResult`](https://data-wise.github.io/medfit/reference/BootstrapResult.md):
  Bootstrap results

## See also

Useful links:

- <https://data-wise.github.io/medfit/>

- <https://github.com/data-wise/medfit>

- Report bugs at <https://github.com/data-wise/medfit/issues>

## Author

**Maintainer**: Davood Tofighi <dtofighi@gmail.com>
([ORCID](https://orcid.org/0000-0001-8523-7776)) \[copyright holder\]

Authors:

- Davood Tofighi <dtofighi@gmail.com>
  ([ORCID](https://orcid.org/0000-0001-8523-7776)) \[copyright holder\]
