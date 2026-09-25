# Validate a multi-mediator fit for the joint-effects branch

Enforces every precondition of the closed-form joint effects and returns
the structure implied by the mediator models. Each failure names its
cause.

## Usage

``` r
.check_joint_fit(
  med_models,
  model_y,
  treatment,
  mediators,
  structure,
  decomposition,
  vcov_fun
)
```

## Arguments

- med_models:

  List of the K mediator models, in `mediators` order.

- model_y:

  Outcome model.

- treatment, mediators:

  Variable names.

- structure:

  `"auto"`, `"serial"` or `"parallel"` as supplied.

- decomposition:

  As supplied to
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md).

- vcov_fun:

  As supplied to
  [`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md).

## Value

`"serial"` or `"parallel"`.
