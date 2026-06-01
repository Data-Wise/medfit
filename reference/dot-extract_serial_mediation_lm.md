# Extract Serial Mediation Structure from lm/glm Models

Internal worker for the serial branch of the lm/glm
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
method. Invoked by
[`.extract_mediation_lm_impl()`](https://data-wise.github.io/medfit/reference/dot-extract_mediation_lm_impl.md)
when `mediator` is a character vector of length \>= 2. It assembles a
[SerialMediationData](https://data-wise.github.io/medfit/reference/SerialMediationData.md)
object for the chain `X -> M1 -> M2 -> ... -> Mk -> Y` from `k + 1`
separately fitted regressions.

## Usage

``` r
.extract_serial_mediation_lm(
  object,
  mediator_models,
  model_y,
  treatment,
  mediators,
  outcome = NULL,
  data = NULL
)
```

## Arguments

- object:

  Fitted lm/glm for the first mediator (`M1 ~ X + ...`).

- mediator_models:

  List (length `k - 1`) of fitted lm/glm models for mediators 2..k
  (`M2 ~ M1 + ...`, ..., `Mk ~ M(k-1) + ...`), in chain order.

- model_y:

  Fitted lm/glm for the outcome (`Y ~ Mk + X + ...`).

- treatment:

  Character scalar: treatment variable name.

- mediators:

  Character vector (length \>= 2): mediator names in causal order
  (`M1 -> M2 -> ... -> Mk`).

- outcome:

  Character scalar, or `NULL` to auto-detect from `model_y`.

- data:

  Data frame, or `NULL` to take the `object` model frame.

## Value

A
[SerialMediationData](https://data-wise.github.io/medfit/reference/SerialMediationData.md)
object.

## Details

Path resolution: `a` = coefficient of `treatment` in `object`; `d_i` =
coefficient of `mediators[i]` in `mediator_models[[i]]` (the predecessor
mediator, read regardless of any additional covariates in that
equation); `b` = coefficient of `mediators[k]` in `model_y`; `c'` =
coefficient of `treatment` in `model_y` (0 with a warning if absent).

The combined `vcov` is block-diagonal across the separately-fitted
equations (so `cov(a, d_i) = cov(d_i, b) = 0`) but preserves the
within-`model_y` covariance, so `cov(b, c')` is non-zero. See the
`extract_mediation` lm method docs for the lm-vs-lavaan covariance
divergence this implies.
