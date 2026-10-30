# Historical FIML prototype acceptance report

Snapshot from `c92b6fec`, superseded by [the repaired report](prototype-report.md).
Prior failing rows and optimizer gates are in `optimizer-repair-baseline/`;
complete original artifacts remain in that local commit. Links below to
`prototype-results/` now resolve to the repaired run.

Executed 2026-10-29 on `codex/fiml-feasibility`, separately from 0.16.
**NO-GO for accepting the prototype or authorizing production integration.**
The bounded experiment is complete; four regular cells and one related
metamorphic check remain failures. No production code, package tests, API,
release configuration, remote branch or hosted CI was changed.

## Scope and provenance

The [frozen protocol](prototype-protocol.md) was committed as `4055b430`
before prototype execution, following scope commits `ce9b0566` and `3da8874`.
Baseline medfit dev is `edcf23d8705165cd2497deda0d4e8410b9754811`.
The study loads this worktree's package with `pkgload`, reads native RAM
moments/derivatives and the scaled SLSQP wrapper, and defines only research
functions in [prototype.R](prototype.R). It neither replaces namespace bindings
nor returns a production `SEMFit`.

The scope is three observed Gaussian variables, random X, free intercepts,
independent disturbances, unweighted rows, and a free or zero direct path.
Fixed X, latent variables, nonlinear constraints and downstream inference
remain excluded. The existing complete-data SEM gate evaluates another
likelihood and is deliberately not presented as a FIML acceptance gate.

The independent oracle parameterizes marginal means and log residual variances,
with separate likelihood/optimization and covariance transport. Lavaan uses
observed-Hessian covariance. The original 30-cell/10-edge reference study was
rerun unchanged; its two fixed-X edges are reference-only. Installed lavaan
0.7-3 source provenance remains in [source-manifest.json](source-manifest.json).

## Final local evidence

| Check | Result |
| --- | --- |
| Original reference fits and edges | 30/30 and 10/10 PASS |
| Prototype regular acceptance cells | 38/42 PASS |
| Prototype edge/metamorphic/mutant checks | 12/13 PASS |
| Independent gradient/Hessian checks | 120/120 evaluated points PASS |
| Stable likelihood-difference identities | 120/120 evaluated points PASS |
| Independent reference optimizer/information gates | 38/40 PASS |
| Optimizer attempt ledger | All 252 solver/start attempts retained |
| Required planted defects | All four detected |
| R parsing and namespace lint | Both research scripts PASS |

Forty prototype fits are available, each checked at its fit and two fixed
perturbations. Six derivative points belonging to the two rejected shifted
fits were not evaluated; **120/120 is not 126/126**. All 42 acceptance cells
remain in [rows.csv](prototype-results/rows.csv), including failures.
The harness exits with status 1, correctly signaling NO-GO.

Across the 40 available fits, worst likelihood difference per retained row is
4.42e-13; standardized estimate discrepancy 3.58e-7; relative SE discrepancy
4.17e-5; and full SE-product-normalized covariance discrepancy 8.34e-5.
The fixed limits are respectively 1e-8, 1e-5, 1e-3 and 1e-3.
Worst second-resolution SE discrepancy is 3.39e-8 (limit 1e-4).
These comparisons include both the independent likelihood and lavaan.

Worst independent gradient discrepancy is 2.79e-10 (limit 1e-6), observed
Hessian discrepancy 8.82e-7 (limit 1e-4), and casewise/grouped likelihood
difference per row 1.07e-12 (limit 1e-8). Full named covariance/Hessian entries,
gradient vectors, original row IDs and all optimizer attempts are retained.
The minimum Jacobi-scaled observed-Hessian eigenvalue over available fits is
0.2705, with maximum scaled condition number 7.54. The corresponding moment
geometry bounds are 0.2524 and 8.18. Both exceed the existing native 1e-4
minimum-eigenvalue diagnostic threshold. These are fixture diagnostics, not
proof of global identification.

## Remaining failures

1. **Shifted data, both models.** All three SLSQP attempts pass, but no nlminb
   attempt meets the frozen original-coordinate scaled stationarity limit
   1e-5. The best nlminb values are approximately 1.38e-5 (free direct path)
   and 1.96e-5 (zero direct path), despite convergence status 0 and very close
   likelihoods. Original structural intercepts couple with slopes under large
   mean shifts; standardization alone does not ensure this gate passes.
   The related full affine-shift check fails because the required accepted
   transformed fit is unavailable. This is not recorded as an invariance PASS.
2. **Near-singular regular data, both models.** Prototype candidates and all
   numerical comparisons pass, but the independent oracle's nlminb polish
   returns status 1. Its BFGS stage returns 0, gradients are below 6.35e-7,
   and Hessians are positive. The frozen rule requires both optimizer stages
   to converge, so these cells fail. Close agreement does not override status.

See [attempts.csv](prototype-results/attempts.csv) and
[independent_gates.csv](prototype-results/independent_gates.csv).
Follow-up should target these four cells and their solver stopping behavior;
acceptance limits must not be widened merely to obtain PASS.

## Corrections made during the bounded experiment

Failed evidence is preserved in `prototype-initial-smoke.csv`,
`prototype-initial-results/`, `prototype-repair1-results/` and
`prototype-repair2-results/`. Acceptance limits and fixture definitions did not
change. Final evidence is in `prototype-results/`.

- The first covariance comparison used `stats::vcov` on a namespace-only lavaan
  object. This dispatch failed; `lavaan::vcov` is the working S4 generic.
- Raw total-NLL subtraction loses useful digits near a solution. A stable
  pattern likelihood difference uses a log1p determinant ratio and an exact
  inverse-difference identity. A same-nlminb restart uses this objective plus
  a constant 1, preserving its target and derivatives. Both initial/final
  statuses are retained. All evaluated identities agree with the independent
  likelihood within 7.48e-12 per row. There is no cross-solver polishing.
- A numerical observed Hessian alone returned misleading tiny positive
  curvature in the deliberately nonidentified no-overlap fixture. The study
  now additionally checks the rank of the observed-pattern mean/covariance
  Jacobian geometry. This Gram matrix is a local observability diagnostic,
  **not** an expected-information SE estimator under MAR. The fixture now
  raises a typed diagnostic instead of an ordinary finite-SE success.
- Default zero-centered numerical-Hessian steps were dominated by subtraction
  noise. Larger independent Richardson steps fix regular-data checks; relative
  variance perturbations keep near-singular probes in the positive domain.
  Two Richardson resolutions are still compared against the complete analytic
  score derivative. No derivative tolerance was relaxed.

The four planted defects are listwise fitting, omitted means, inverse-average
Hessian N scaling, and omitted moment-mapping curvature. Each is rejected by
its intended independent likelihood or covariance/Hessian check. Empty rows,
row permutations, all seven nonempty patterns, singleton patterns, identifiable
no-complete-row data, rescaling, all-missing variables, unsupported settings,
nonidentification and invalid implied PD have explicit evidence.

## Reproduce and interpret

From the isolated study worktree:

```sh
Rscript planning/studies/fiml-feasibility/prototype-acceptance.R
```

Final local runtime was approximately 26 seconds. The command intentionally
returns nonzero while required acceptance cells fail. Session information,
warnings and an execution log are retained; recursive file hashes are in
[evidence-manifest.json](evidence-manifest.json).

This experiment supports the pattern likelihood, native RAM score and full
observed-Hessian covariance construction on the evaluated fixtures. It does
not establish inferential coverage, MAR robustness beyond the stated model,
global optimality, production compatibility or readiness to add FIML to 0.16.
No full package suite, production constraint gates, coverage collection or
expensive CI was run for this study-only change.
