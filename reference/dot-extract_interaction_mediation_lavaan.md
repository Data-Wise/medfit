# Extract Treatment-Mediator Interaction Structure from a lavaan Model

Internal worker for the four-way (VanderWeele 2014) branch of
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
on lavaan objects. The SEM analogue of
[`.extract_interaction_mediation_lm()`](https://data-wise.github.io/medfit/reference/dot-extract_interaction_mediation_lm.md):
it returns an `InteractionMediationData` object for continuous `Y` and
`M` with binary treatment and reference level `m_star`.

## Usage

``` r
.extract_interaction_mediation_lavaan(
  object,
  treatment,
  mediator,
  int_term,
  outcome = NULL,
  m_star = 0,
  standardized = FALSE
)
```

## Arguments

- object:

  Fitted lavaan model object.

- treatment:

  Character scalar: treatment variable name.

- int_term:

  Character: the interaction (product) coefficient name in the outcome
  equation.

- outcome:

  Character scalar, or `NULL` to auto-detect from the variable predicted
  by the last mediator.

- m_star:

  Numeric scalar reference mediator level.

- standardized:

  Logical: extract standardized coefficients?

## Value

An `InteractionMediationData` object.

## Details

Because lavaan fits one joint system, the expanded `vcov` preserves the
FULL covariance among the paths – including `cov(beta1, theta3)` and
`cov(beta0, theta3)` – unlike the block-diagonal lm/glm engine, so the
delta-method standard errors reflect the joint estimation. The mediator
intercept `beta0` (needed for INTref) is read from the `~1` row, so the
model must be fit with `meanstructure = TRUE`.
