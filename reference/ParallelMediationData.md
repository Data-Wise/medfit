# ParallelMediationData: Parallel (Multiple-Mediator) Mediation Structure

S7 class for **parallel** mediation, where a treatment affects an
outcome through two or more *independent* mediators operating in
parallel (\\X \rightarrow M_j \rightarrow Y\\ for \\j = 1, \dots, k\\).
The total indirect effect is the sum of the per-mediator products,
\\\sum\_{j=1}^{k} a_j b_j\\. This complements
[MediationData](https://data-wise.github.io/medfit/reference/MediationData.md)
(simple) and
[SerialMediationData](https://data-wise.github.io/medfit/reference/SerialMediationData.md)
(serial chains).

## Arguments

- a_paths:

  Numeric vector: treatment -\> mediator effects \\(a_1, \dots, a_k)\\.

- b_paths:

  Numeric vector: mediator -\> outcome effects \\(b_1, \dots, b_k)\\;
  must be the same length as `a_paths`.

- c_prime:

  Numeric scalar: direct effect \\X \rightarrow Y\\.

- estimates:

  Numeric vector of all parameter estimates.

- vcov:

  Square variance-covariance matrix of `estimates`.

- sigma_mediators:

  Optional numeric vector of mediator residual SDs (length k), or NULL.

- sigma_y:

  Optional numeric scalar outcome residual SD, or NULL.

- treatment, outcome:

  Single character strings naming the treatment / outcome.

- mediators:

  Character vector of mediator names (length k, unique).

- mediator_predictors:

  List of predictor-name vectors, one per mediator.

- outcome_predictors:

  Character vector of outcome-model predictor names.

- data:

  Optional data frame, or NULL.

- n_obs:

  Integer number of observations.

- converged:

  Logical convergence flag.

- source_package:

  Character name of the originating package.

## Value

A `ParallelMediationData` S7 object.

## Examples

``` r
pmd <- ParallelMediationData(
  a_paths = c(0.5, 0.4),
  b_paths = c(0.6, 0.3),
  c_prime = 0.2,
  estimates = c(0.5, 0.4, 0.6, 0.3, 0.2),
  vcov = diag(0.01, 5),
  treatment = "X",
  mediators = c("M1", "M2"),
  outcome = "Y",
  mediator_predictors = list("X", "X"),
  outcome_predictors = c("X", "M1", "M2"),
  n_obs = 200L,
  converged = TRUE,
  source_package = "medfit"
)

nie(pmd)   # total indirect effect: sum(a_j * b_j) = 0.42
#> Natural Indirect Effect (NIE): 0.42
paths(pmd) # a1, b1, a2, b2, c_prime
#>      a1      b1      a2      b2 c_prime 
#>     0.5     0.6     0.4     0.3     0.2 
```
