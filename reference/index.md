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
- [`BootstrapResult()`](https://data-wise.github.io/medfit/reference/BootstrapResult.md)
  : BootstrapResult S7 Class

## Model Fitting

Functions for fitting and extracting mediation models

- [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
  : Extract Mediation Structure from Fitted Models
- [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  : Fit Mediation Models
- [`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
  : Perform Bootstrap Inference for Mediation Statistics

## Methods

Print and summary methods for medfit classes

- [`tidy(`*`<S7_object>`*`)`](https://data-wise.github.io/medfit/reference/tidy.S7_object.md)
  [`glance(`*`<S7_object>`*`)`](https://data-wise.github.io/medfit/reference/tidy.S7_object.md)
  : Tidy, Glance, and Inference Methods for medfit Objects
- [`print(`*`<mediation_effect>`*`)`](https://data-wise.github.io/medfit/reference/print.mediation_effect.md)
  : Print Method for mediation_effect
- [`print(`*`<summary.BootstrapResult>`*`)`](https://data-wise.github.io/medfit/reference/print.summary.BootstrapResult.md)
  : Print Summary for BootstrapResult
- [`print(`*`<summary.JointMediationData>`*`)`](https://data-wise.github.io/medfit/reference/print.summary.JointMediationData.md)
  : Print Summary for JointMediationData
- [`print(`*`<summary.MediationData>`*`)`](https://data-wise.github.io/medfit/reference/print.summary.MediationData.md)
  : Print Summary for MediationData
- [`print(`*`<summary.SerialMediationData>`*`)`](https://data-wise.github.io/medfit/reference/print.summary.SerialMediationData.md)
  : Print Summary for SerialMediationData
