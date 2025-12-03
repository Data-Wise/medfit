# SerialMediationData S7 Class

S7 class for serial mediation models where the effect flows through
multiple mediators in sequence: X -\> M1 -\> M2 -\> ... -\> Mk -\> Y.

This class supports serial mediation chains of any length, from simple
two-mediator models (product-of-three: a \* d \* b) to complex chains
with many mediators (product-of-k).

## Arguments

- a_path:

  Numeric scalar: effect of treatment on first mediator (X -\> M1)

- d_path:

  Numeric vector: sequential mediator-to-mediator effects

  - For 2 mediators (X -\> M1 -\> M2 -\> Y): scalar d21 (M1 -\> M2)

  - For 3 mediators (X -\> M1 -\> M2 -\> M3 -\> Y): c(d21, d32)

  - For k mediators: vector of length (k-1)

- b_path:

  Numeric scalar: effect of last mediator on outcome (Mk -\> Y)

- c_prime:

  Numeric scalar: direct effect of treatment on outcome (X -\> Y)

- estimates:

  Numeric vector: all parameter estimates

- vcov:

  Numeric matrix: variance-covariance matrix of estimates

- sigma_mediators:

  Numeric vector or NULL: residual SDs for mediator models. Length
  should match number of mediators. First element is residual SD for M1
  model, second element for M2 model, etc.

- sigma_y:

  Numeric scalar or NULL: residual SD for outcome model

- treatment:

  Character scalar: name of treatment variable

- mediators:

  Character vector: names of mediators in sequential order. First
  element is M1, second element is M2, etc.

- outcome:

  Character scalar: name of outcome variable

- mediator_predictors:

  List of character vectors: predictor names for each mediator model.
  First list element contains predictors for M1 (typically just "X"),
  second element contains predictors for M2 (typically c("X", "M1")),
  etc.

- outcome_predictors:

  Character vector: predictor names in outcome model

- data:

  Data frame or NULL: original data

- n_obs:

  Integer scalar: number of observations

- converged:

  Logical scalar: whether all models converged

- source_package:

  Character scalar: package/engine used for fitting

## Value

A SerialMediationData S7 object

## Details

### Serial Mediation Structure

Serial mediation models the indirect effect flowing through a sequence
of mediators. The total indirect effect is the product of all path
coefficients:

- **2 mediators (product-of-three)**: Indirect = a \* d \* b

- **3 mediators (product-of-four)**: Indirect = a \* d21 \* d32 \* b

- **k mediators (product-of-k+1)**: Indirect = a \* d21 \* d32 \* ... \*
  d(k,k-1) \* b

### Path Notation

- `a`: Treatment -\> First mediator (X -\> M1)

- `d21`: First -\> Second mediator (M1 -\> M2)

- `d32`: Second -\> Third mediator (M2 -\> M3)

- `dji`: Previous mediator -\> Current mediator

- `b`: Last mediator -\> Outcome (Mk -\> Y)

- `c'`: Direct effect (X -\> Y, controlling for all mediators)

### Extensibility

This class is designed to handle serial chains of any length:

- Minimal case: 2 mediators (length(d_path) = 1)

- No upper limit on chain length

- Validator ensures consistency between mediators and paths

## Examples

``` r
if (FALSE) { # \dontrun{
# Two-mediator serial mediation (X -> M1 -> M2 -> Y)
# Product-of-three: a * d * b
serial_data <- SerialMediationData(
  a_path = 0.5,       # X -> M1
  d_path = 0.4,       # M1 -> M2 (scalar for 2 mediators)
  b_path = 0.3,       # M2 -> Y
  c_prime = 0.1,      # X -> Y (direct)
  estimates = c(0.5, 0.4, 0.3, 0.1),
  vcov = diag(4) * 0.01,
  sigma_mediators = c(1.0, 1.1),  # SD for M1, M2 models
  sigma_y = 1.2,
  treatment = "X",
  mediators = c("M1", "M2"),
  outcome = "Y",
  mediator_predictors = list(
    c("X"),           # M1 ~ X
    c("X", "M1")      # M2 ~ X + M1
  ),
  outcome_predictors = c("X", "M1", "M2"),  # Y ~ X + M1 + M2
  data = NULL,
  n_obs = 100L,
  converged = TRUE,
  source_package = "lavaan"
)

# Three-mediator serial mediation (X -> M1 -> M2 -> M3 -> Y)
# Product-of-four: a * d21 * d32 * b
serial_data_3 <- SerialMediationData(
  a_path = 0.5,           # X -> M1
  d_path = c(0.4, 0.35),  # M1 -> M2, M2 -> M3 (vector for 3 mediators)
  b_path = 0.3,           # M3 -> Y
  c_prime = 0.1,
  estimates = c(0.5, 0.4, 0.35, 0.3, 0.1),
  vcov = diag(5) * 0.01,
  sigma_mediators = c(1.0, 1.1, 1.05),  # SD for M1, M2, M3 models
  sigma_y = 1.2,
  treatment = "X",
  mediators = c("M1", "M2", "M3"),
  outcome = "Y",
  mediator_predictors = list(
    c("X"),              # M1 ~ X
    c("X", "M1"),        # M2 ~ X + M1
    c("X", "M1", "M2")   # M3 ~ X + M1 + M2
  ),
  outcome_predictors = c("X", "M1", "M2", "M3"),
  data = NULL,
  n_obs = 100L,
  converged = TRUE,
  source_package = "lavaan"
)
} # }
```
