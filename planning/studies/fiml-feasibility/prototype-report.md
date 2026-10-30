# Bounded FIML prototype: local acceptance report

Executed 2026-10-29 on `codex/fiml-feasibility`, separately from 0.16.
**PASS for the bounded local numerical prototype.** All four prior optimizer
failures are resolved. This does not authorize production integration, release
or inclusion in 0.16. No production code, public API, push or hosted CI changed.

## Scope and provenance

The [frozen protocol](prototype-protocol.md) was committed as `4055b430`, before
execution. Baseline medfit dev remains `edcf23d8`. The prior NO-GO result is
preserved in local commit `c92b6fec`, the
[historical report](prototype-before-optimizer-repair.md) and
[baseline rows](optimizer-repair-baseline/rows.csv). Acceptance limits,
fixture definitions and required optimizer statuses remain unchanged.

Only study files and `.STATUS` changed. [prototype.R](prototype.R) reads native
RAM moments, derivatives and the SLSQP wrapper without replacing namespace
bindings. The scope remains three observed Gaussian variables, random X,
free intercepts, independent disturbances, unweighted data, and free or zero
direct path. Fixed X, latent variables, constraints and downstream integration
remain excluded. The prototype does not return a production `SEMFit`.

## Repairs and rejected approaches

1. **Shifted prototype fits:** provide nlminb the full score-derived Hessian
   during its existing, accurately anchored, same-solver refinement. Previously
   its approximate curvature stopped before original-coordinate stationarity
   passed. The new refinement retains convergence status 0 and achieves scaled
   stationarity around 1e-11 to 4.2e-9 across the shifted nlminb attempts.
   SLSQP remains independently fitted; there is no cross-solver polishing.
2. **Near-singular independent fits:** the independent marginal-mean/log-variance
   likelihood now optionally supplies numerical gradients and Hessians to its
   nlminb polish. It uses neither RAM derivatives nor prototype estimates.
   The prototype harness enables this option; the original reference study
   retains its previous default. The oracle solver's relative stopping control
   changes from 1e-13 to 1e-10 with these derivatives. This is a solver-control
   change, not a relaxation of the fixed gradient/status/likelihood gates.
   Both near-singular BFGS and polish statuses are now 0, with independently
   checked gradients below 3.11e-8.
3. **Lavaan reference conditioning:** accurate shifted fits exposed a raw-data
   lavaan intercept discrepancy of 1.069e-5 against the unchanged 1e-5 limit.
   The 42-cell prototype harness now fits lavaan in data-derived standardized
   coordinates and independently transports every estimate and full covariance
   entry back using a numerical Jacobian. It does not use prototype transport.
   The likelihood includes the exact affine Jacobian offset and is checked
   against the independent likelihood on original data. The original raw-data
   30-cell reference harness still runs with its previous settings.

Tightening nlminb stopping tolerances alone failed. Supplying curvature while
requiring excessively tight solver stopping also produced nonconvergence
statuses despite tiny gradients; these were rejected. Tightening lavaan's
relative tolerance alone did not improve the shifted intercept. Tightening its
parameter tolerance improved accuracy but reported nonconvergence; a trial
BFGS fit also failed the parameter comparison. Those alternatives were not
accepted. Probe logs and tables are in `optimizer-repair-probes/`, including
the intermediate full run with 41/42 acceptance cells.

## Final local evidence

| Check | Result |
| --- | --- |
| Prototype regular acceptance cells | 42/42 PASS |
| Prototype edge/metamorphic/mutant checks | 13/13 PASS |
| Independent gradient/Hessian checks | 126/126 PASS |
| Stable likelihood-difference identities | 126/126 PASS |
| Independent optimizer/information gates | 42/42 PASS |
| Original raw-data reference fits and edges | 30/30 and 10/10 PASS |
| Required planted defects | All four detected |
| R parsing and namespace lint | All three study scripts PASS |

All 42 fits have checks at their fit and two fixed perturbations. No cell,
parameter, covariance entry or failed start was removed. Ledgers retain 252
prototype solver/start attempts, 126 independent reference starts, 12,600 row
IDs and 1,071 full gradient-coordinate comparisons. Independent attempt
messages, iterations and statuses are in
[independent_attempts.csv](prototype-results/independent_attempts.csv).

| Worst discrepancy across all 42 cells | Observed | Fixed limit |
| --- | ---: | ---: |
| Likelihood per retained row | 2.04e-13 | 1e-8 |
| Standardized estimate | 1.99e-6 | 1e-5 |
| Relative SE | 3.21e-5 | 1e-3 |
| Full SE-product-normalized covariance | 6.42e-5 | 1e-3 |
| Second-resolution SE stability | 3.39e-8 | 1e-4 |
| Scaled stationarity | 4.65e-7 | 1e-5 |
| Independent gradient | 5.13e-9 | 1e-6 |
| Independent observed Hessian | 4.61e-7 | 1e-4 |

Covariance comparisons include both the independent likelihood and lavaan.
Full named matrices, gradients, conditioning diagnostics, warnings and row
ledgers are retained in `prototype-results/`. The four planted defects are
listwise fitting, omitted means, wrong Hessian N scaling and omitted
moment-mapping curvature. Each fails its intended independent criterion.
The shifted and rescaled affine checks both pass. The deliberate no-overlap
nonidentification fixture still raises a typed diagnostic; positive numerical
curvature alone is not accepted as identification evidence.

## Reproduce and interpret

From the isolated study worktree:

```sh
Rscript planning/studies/fiml-feasibility/prototype-acceptance.R
```

The final complete run exits 0 and takes approximately 37 seconds. Session
information and the execution log are retained. Recursive artifact hashes are
in [evidence-manifest.json](evidence-manifest.json).

This is a numerical GO for this bounded research prototype only. It does not
establish inferential coverage, general MAR robustness, global identification
or optimization, or production readiness. No full package suite, production
constraint gates, coverage collection or expensive CI was run. Production/API
integration needs a separate design and authorization; 0.16 remains separate.
