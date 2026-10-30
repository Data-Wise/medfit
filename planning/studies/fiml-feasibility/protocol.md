# Bounded FIML feasibility protocol and adversarial review

Date: 2026-10-29. Separate from 0.16; local research only. No production
implementation, API change, external submission or expensive CI is authorized.
Baseline: dev edcf23d8705165cd2497deda0d4e8410b9754811.

## Adversarial findings resolved before execution

1. **Consumer evidence is incomplete.** The concrete workflow is observed
   continuous native mediation with partially observed X/M/Y, where current
   listwise handling discards otherwise usable observations. No downstream
   maintainer has committed to adoption. A technical PASS cannot satisfy that
   product decision; implementation remains conditional on a named adopter.
2. **Random-X success is insufficient for current default semantics.** Main
   cells use random X. Add a bounded fixed-X comparison with complete X and a
   separate missing-X row-retention probe. Do not silently enable random-X
   modeling for a user who requested fixed X.
3. **A saturated model alone is weak evidence.** Include a direct-path-zero,
   overidentified model as well as the unrestricted model. Test a deliberately
   unidentified missingness pattern; optimizer success alone cannot accept it.
4. **SE agreement can fail for coordinate or scaling reasons.** The standalone
   optimizer uses marginal means/log variances; transform its inverse TOTAL
   negative-log-likelihood Hessian into lavaan's structural intercept/variance
   coordinates. Explicitly request observed Hessian information from lavaan.
   Never invert an average-likelihood Hessian without the sample-size factor.
5. **One shared evaluator can reproduce a shared bug.** Cross-check case-wise
   Cholesky likelihood against pattern-wise solve/determinant likelihood, and
   complete-data likelihood against structural conditional normal densities.
   Compare total log likelihood including constants, named parameter sets,
   original-coordinate estimates, stationarity and all SEs. Multiple starts and
   a second optimizer support finite-fixture agreement, not global convergence.
6. **A feasibility GO is not medfit validation.** No native FIML implementation
   exists in this study. A GO means proceed to a separately authorized design;
   it says nothing about native derivatives, constraints, weights, downstream
   compatibility, MAR validity in real data or release readiness.

## Fixed study boundary

- R/lavaan already installed; no dependency installation. n=300, three fixed
  seeds, two observed Gaussian mediation models, five masks: complete,
  monotone MCAR, nonmonotone MCAR, MAR depending on fully observed X, and MCAR
  including missing X. Thirty primary fit comparisons.
- Primary settings: free mean structure, random X, normal ML, standard SEs from
  observed Hessian information. No latent variables, categorical variables,
  sampling weights, nonlinear restrictions, robust SEs, bootstrap or native API.
- Independent mean/covariance from structural equations. No medfit functions or
  lavaan model/derivative builders construct the reference likelihood. Independent
  BFGS starts plus nlminb polish; every returned coordinate is compared by name.
- Proposed thresholds fixed before the first fit: total log-likelihood
  difference/retained row <=1e-8, estimate differences in standardized data
  coordinates <=1e-5, relative model-SE differences <=1e-3. Include raw-unit
  differences in the evidence. Numerical Hessian precision and positive
  definiteness must also be checked; never widen tolerances to conceal a miss.
- Edge checks: all-missing rows, all-missing variable, missingness-induced
  nonidentification, row order, shift/rescale likelihood identity, complete-data
  reduction and fixed-X row selection. Explicitly count retained/empty rows.
- Plant listwise-deletion, omitted-mean, and wrong Hessian sample-size scaling
  defects. Each must fail its associated criterion on informative fixtures.

## Decision rule

Technical GO only if every primary cell passes the predeclared likelihood,
estimate, stationarity and SE checks, independent formulations agree, edge
behavior is explained, and defects are caught. Any unexplained miss is
NO-GO/pending diagnosis; report the failing cell without changing thresholds.

A technical GO supports a small design proposal, not implementation approval.
Adopter, fixed-X missing-covariate policy, treatment of unsupported settings,
native derivative/inference integration and public API all need a later scope
decision. Nothing here blocks or expands 0.16.

## Execution amendments (criteria unchanged)

The initial 25/30 primary and 8/10 edge results are retained as `initial-*`.
Diagnosed harness repairs: lavaan stopping `rel.tol` changed from 1e-12 to
1e-10; fixed-X syntax omits explicit free X moments; reference optimization
uses dimensionless coordinates for rescaled data. No likelihood, parameter or
SE acceptance threshold changed. Final evidence and limitations are in
[report.md](report.md); deeper numerical research remains a separate task.
