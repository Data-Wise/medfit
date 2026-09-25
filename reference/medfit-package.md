# medfit: Infrastructure for Mediation Model Fitting and Extraction

Provides S7-based infrastructure for fitting mediation models,
extracting path coefficients, and performing bootstrap inference.
Designed as a foundation package for probmed, RMediation, and medrobust.

## Details

Key functions:

- [`fit_mediation`](https://data-wise.github.io/medfit/reference/fit_mediation.md):
  Fit mediation models

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
