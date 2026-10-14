# Package index

## Quick Start

ADHD-friendly entry points for rapid analysis

- [`med()`](https://data-wise.github.io/medfit/reference/med.md) :
  Simple Mediation Analysis
- [`quick()`](https://data-wise.github.io/medfit/reference/quick.md) :
  Quick Summary of Mediation Results

## Data

Simulated example data

- [`mediation_demo`](https://data-wise.github.io/medfit/reference/mediation_demo.md)
  : Simulated Mediation Data for Examples

## Effect Extractors

Extract mediation effects from fitted models

- [`nie()`](https://data-wise.github.io/medfit/reference/nie.md) :
  Extract Natural Indirect Effect (NIE)
- [`nde()`](https://data-wise.github.io/medfit/reference/nde.md) :
  Extract Natural Direct Effect (NDE)
- [`te()`](https://data-wise.github.io/medfit/reference/te.md) : Extract
  Total Effect (TE)
- [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) : Extract
  Proportion Mediated (PM)
- [`paths()`](https://data-wise.github.io/medfit/reference/paths.md) :
  Extract All Path Coefficients
- [`decompose()`](https://data-wise.github.io/medfit/reference/decompose.md)
  : Decomposition of a Mediation Effect
- [`joint_effects()`](https://data-wise.github.io/medfit/reference/joint_effects.md)
  : Joint Effects at a Given Parameter Vector

## S7 Classes

Core S7 class definitions for mediation data structures

- [`MediationData()`](https://data-wise.github.io/medfit/reference/MediationData.md)
  : MediationData S7 Class
- [`SerialMediationData()`](https://data-wise.github.io/medfit/reference/SerialMediationData.md)
  : SerialMediationData S7 Class
- [`ParallelMediationData()`](https://data-wise.github.io/medfit/reference/ParallelMediationData.md)
  : ParallelMediationData: Parallel (Multiple-Mediator) Mediation
  Structure
- [`InteractionMediationData()`](https://data-wise.github.io/medfit/reference/InteractionMediationData.md)
  : InteractionMediationData: Mediation with Treatment-Mediator
  Interaction
- [`JointMediationData()`](https://data-wise.github.io/medfit/reference/JointMediationData.md)
  : JointMediationData: Joint Natural Effects of Multiple Mediators
- [`ClusterMediationData()`](https://data-wise.github.io/medfit/reference/ClusterMediationData.md)
  : ClusterMediationData: Cluster-Level Treatment Mediation (2-1-1)
- [`BootstrapResult()`](https://data-wise.github.io/medfit/reference/BootstrapResult.md)
  : BootstrapResult S7 Class
- [`SEMFit()`](https://data-wise.github.io/medfit/reference/SEMFit.md)
  **\[experimental\]** : SEMFit S7 Class

## Model Fitting

Functions for fitting and extracting mediation models

- [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  : Extract Mediation Structure from Fitted Models
- [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  : Fit Mediation Models
- [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
  **\[experimental\]** : Fit a Structural Equation Model by Maximum
  Likelihood
- [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
  **\[experimental\]** : Minimum-of-k Likelihood-Ratio Test for an
  Indirect Effect (MBCO)
- [`medfit-syntax`](https://data-wise.github.io/medfit/reference/medfit-syntax.md)
  [`medfit_syntax`](https://data-wise.github.io/medfit/reference/medfit-syntax.md)
  **\[experimental\]** : medfit Model Syntax
- [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
  : Perform Bootstrap Inference for Mediation Statistics

## Methods

Print and summary methods for medfit classes

- [`tidy_s7_object()`](https://data-wise.github.io/medfit/reference/tidy_s7_object.md)
  [`glance_s7_object()`](https://data-wise.github.io/medfit/reference/tidy_s7_object.md)
  : Tidy, Glance, and Inference Methods for medfit Objects
- [`SEMFit-methods`](https://data-wise.github.io/medfit/reference/SEMFit-methods.md)
  **\[experimental\]** : Methods for SEMFit objects
