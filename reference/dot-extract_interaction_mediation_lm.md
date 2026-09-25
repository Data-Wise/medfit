# Extract Treatment-Mediator Interaction Structure from lm/glm Models

Internal worker for the four-way (VanderWeele 2014) branch of the lm/glm
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
method. Invoked by
[`.extract_mediation_lm_impl()`](https://data-wise.github.io/medfit/reference/dot-extract_mediation_lm_impl.md)
when a single mediator's outcome model carries an `X:M` term. Builds an
`InteractionMediationData` object for continuous `Y` and `M` with binary
treatment (0 -\> 1) and reference mediator level `m_star`.

## Usage

``` r
.extract_interaction_mediation_lm(
  model_m,
  model_y,
  treatment,
  mediator,
  int_term,
  outcome = NULL,
  data = NULL,
  m_star = 0,
  vcov_fun = stats::vcov
)
```

## Arguments

- model_y:

  Fitted lm/glm for the outcome. `Mk`'s coefficient is read as `b`; the
  model should include `X` and every earlier mediator
  (`Y ~ X + M1 + ... + Mk + ...`), whose coefficients are stored as the
  skip-path aliases `b1..b{k-1}`. Omitting an earlier mediator that also
  affects `Y` biases `b`. `a * d * b` is the effect through the full
  chain only;
  [`te()`](https://data-wise.github.io/medfit/reference/te.md) sums
  every path.

- treatment:

  Character scalar: treatment variable name.

- int_term:

  Character: the interaction coefficient name in `model_y` (from
  [`.find_interaction_term()`](https://data-wise.github.io/medfit/reference/dot-find_interaction_term.md)).

- outcome:

  Character scalar, or `NULL` to auto-detect from `model_y`.

- data:

  Data frame, or `NULL` to take the `object` model frame.

- m_star:

  Numeric scalar reference mediator level.

- vcov_fun:

  Function returning a model's coefficient covariance (default
  [`stats::vcov()`](https://rdrr.io/r/stats/vcov.html)), e.g. a sandwich
  estimator.

## Value

An `InteractionMediationData` object.

## Details

With mediator model \\M = \beta_0 + \beta_1 X + \beta_2^\top C\\ and
outcome model \\Y = \theta_0 + \theta_1 X + \theta_2 M + \theta_3 XM +
\dots\\ the components are CDE = \\\theta_1 + \theta_3 m^\*\\, INTref =
\\\theta_3 (E\[M\mid X=0\] - m^\*)\\, INTmed = \\\theta_3 \beta_1\\, PIE
= \\\theta_2 \beta_1\\, where \\E\[M\mid X=0\]\\ evaluates covariates at
their sample means. The combined `vcov` is block-diagonal across the two
separately-fitted equations and named with the aliases `a`, `b`,
`c_prime`, `theta3`, `b0`.
