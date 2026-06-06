# Extract Mediation Structure from lavaan Model

Internal function for extracting mediation structure from lavaan models.
This function is registered as an S7 method in `.onLoad()` when lavaan
is available.

## Usage

``` r
extract_mediation_lavaan(
  object,
  treatment,
  mediator,
  outcome = NULL,
  a_label = "a",
  b_label = "b",
  cp_label = "cp",
  standardized = FALSE,
  structure = c("auto", "serial", "parallel"),
  decomposition = c("auto", "four_way", "two_way"),
  interaction = NULL,
  m_star = 0,
  ...
)
```

## Arguments

- object:

  Fitted lavaan model object

- treatment:

  Character: name of the treatment variable

- mediator:

  Character: name of the mediator variable for simple mediation (X -\> M
  -\> Y), OR an ordered character vector of length \>= 2 for serial
  mediation (X -\> M1 -\> M2 -\> ... -\> Y). When a vector is supplied
  the function returns a
  [SerialMediationData](https://data-wise.github.io/medfit/reference/SerialMediationData.md)
  object instead of
  [MediationData](https://data-wise.github.io/medfit/reference/MediationData.md).

- outcome:

  Character: name of the outcome variable (optional, auto-detected)

- a_label:

  Character: label for the a path in lavaan model (default: "a")

- b_label:

  Character: label for the b path in lavaan model (default: "b")

- cp_label:

  Character: label for the c' path in lavaan model (default: "cp")

- standardized:

  Logical: extract standardized coefficients? (default: FALSE)

- structure:

  Character: one of `"auto"` (default), `"serial"`, or `"parallel"`.
  Selects the multi-mediator structure when `mediator` has length \>= 2.
  `"auto"` infers it from the SEM's regression rows: a mediator
  regressed on another mediator implies `"serial"`, otherwise
  `"parallel"`. The explicit values are authoritative and skip
  detection.

- ...:

  Additional arguments (ignored)

## Value

A
[MediationData](https://data-wise.github.io/medfit/reference/MediationData.md)
object; a
[SerialMediationData](https://data-wise.github.io/medfit/reference/SerialMediationData.md)
object when `mediator` is a length \>= 2 vector resolving to a serial
chain; or a `ParallelMediationData` object when it resolves to parallel
mediation.

## Details

This method extracts mediation structure from a fitted lavaan SEM model.
The lavaan model should specify labeled paths for the mediation
structure.

### Typical lavaan Model Specification

    model <- "
      # Mediator model
      M ~ a*X

      # Outcome model
      Y ~ b*M + cp*X

      # Indirect and total effects (optional)
      indirect := a*b
      total := cp + a*b
    "

### Path Labels

By default, the function looks for paths labeled:

- `a`: Treatment -\> Mediator path

- `b`: Mediator -\> Outcome path

- `cp`: Treatment -\> Outcome (direct effect) path

You can customize these labels using the `a_label`, `b_label`, and
`cp_label` arguments.

### Alternative: Unlabeled Paths

If paths are not labeled, the function will attempt to identify them by
variable names. This requires specifying `treatment`, `mediator`, and
`outcome` arguments.

## Examples

``` r
if (FALSE) { # \dontrun{
library(lavaan)

# Define mediation model
model <- "
  M ~ a*X
  Y ~ b*M + cp*X
"

# Fit model
fit <- sem(model, data = mydata)

# Extract mediation structure
med_data <- extract_mediation(
  fit,
  treatment = "X",
  mediator = "M",
  outcome = "Y"
)
} # }
```
