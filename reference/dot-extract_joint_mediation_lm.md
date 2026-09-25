# Extract joint natural effects from lm/glm models (worker)

Called by
[`.extract_mediation_lm_impl()`](https://data-wise.github.io/medfit/reference/dot-extract_mediation_lm_impl.md)
after
[`.check_joint_fit()`](https://data-wise.github.io/medfit/reference/dot-check_joint_fit.md)
has validated the models. Evaluates the unit-contrast (0 -\> 1) effects
at the sample covariate means (VanderWeele and Vansteelandt 2014): NIE =
\\\sum_i (\theta\_{2i} + \theta\_{3i}) \beta^\*\_{1i}\\, NDE =
\\\theta_1 + \sum_i \theta\_{3i} E\[M_i \mid X = 0, \bar c\]\\, CDE =
\\\theta_1 + \sum_i \theta\_{3i} m^\*\_i\\.

## Usage

``` r
.extract_joint_mediation_lm(
  med_models,
  model_y,
  treatment,
  mediators,
  structure,
  interactions,
  m_star,
  outcome = NULL,
  data = NULL
)
```

## Arguments

- med_models:

  List of the K mediator models, in causal order.

- model_y:

  Outcome model.

- treatment, mediators, outcome:

  Variable names (`outcome` auto-detected when NULL).

- structure:

  `"serial"` or `"parallel"`.

- interactions:

  Mediators carrying a treatment product, in order.

- m_star:

  Numeric vector named by `interactions`.

- data:

  Optional data frame; defaults to the outcome model frame.

## Value

A `JointMediationData` object.

## Details

`@estimates` holds every model's coefficients as prefixed source rows
(`m1_`, ..., `mK_`, `y_`) plus path aliases (`a1..aK`, `dij`, `b1..bK`,
`theta3_<mediator>`, `c_prime`); `@vcov` is the stacked-OLS covariance
of the source rows, with alias rows duplicating their source rows. K = 1
is accepted internally (reduction test only).
