> **Current checkpoint (2026-11-01):** Local FI-B1/FI-B2 implementation, independent QA, docs and final gates PASS. Renewed suite: 1802 tests, 8983 passing expectations, zero failures/errors; coverage 96.31213% overall and 158/158 changed critical expressions; source supplement 497 tests, one skip; lint clean and package check OK. Statistical admission remains deferred. Implementation is local; integration requires separate authorization. Earlier failure, worker-limit and preregistration deviations are historical and retained below.
> Earlier status statements below are historical where inconsistent with this checkpoint.

# FI-B0: short implementation checklist

Date: 2026-10-31 MDT. Updated 2026-11-01 MST: **reviewed contract merged via #378; bounded implementation and numerical QA complete locally; final gates blocked by test-helper assertions**.
The active [execution plan](PLAN-FIML-bounded-inference-implementation-2026-11-01.md) owns task state.
Replaces the longer decision packet from commit `270584ec`. No statistical experiments or implementation push.

## Scope and roadmap

Existing three-variable continuous Gaussian random-X FIML only: X -> M -> Y,
with direct path free or fixed zero; unstandardized `nie`, `nde`, `te`.
Follow the [roadmap](medfit-roadmap.md): FI-B0 contract -> FI-B1 row intervals ->
FI-B2 parameter draws -> the approved 11 observed-model variants. This checklist
neither expands models nor adds robust SEs, likelihood intervals, p-values,
standardized effects, or a release date. The [paired plan](PLAN-FIML-inference-and-observed-models-2026-10-31.md)
remains the historical detailed specification; the large simulation proposal
is deferred, not a prerequisite for drafting or reviewing this checklist.

## 1. API and compatibility

- [x] Add exactly matched, named-only `source_fit = NULL` and `effect = NULL`
  after `...` in `bootstrap_mediation()`, preserving existing positional slots,
  defaults and callback contracts. Source-route calls omit `statistic_fn`;
  validate that route before forcing the existing required callback argument.
- [x] Require a validated accepted FIML `SEMFit`, explicit `method` and exact
  `effect` (`nie`, `nde`, `te`). `nonparametric` means row bootstrap;
  `parametric` means Gaussian parameter draws, not generative parametric bootstrap.
- [x] Reject conflicts with supplied `statistic_fn`, non-NULL `data`,
  `mediation_data`, `cluster`, nonempty `...`, and source-route `plugin`.
  Reject `effect` without a source fit. Validate before RNG/workers/refits.
- [x] Reuse `BootstrapResult` with backward-compatible optional inference
  metadata. Preserve legacy constructors and tidy/glance columns. Record target,
  source provenance, method label, requested/successful/failed counts, seed,
  sampling frame, and the complete replicate ledger. Never mutate the source.
  Use an optional versioned `inference` list, empty for legacy objects; record
  retained/collected counts, RNG settings, quantile type and refit protocol.
  Retain row indices or normal-draw IDs, acceptance/condition reasons and
  unattempted IDs after interruption. Withheld results have NA distribution SD
  in `tidy()`; all-success SD remains descriptive, not a robust standard error.

Development API examples; these replicate counts are illustrative, not admitted statistical-study settings:

```r
bootstrap_mediation(method = "nonparametric", source_fit = fit,
                    effect = "nie", n_boot = 999L, seed = 101L)
bootstrap_mediation(method = "parametric", source_fit = fit,
                    effect = "te", n_boot = 20000L, seed = 102L)
```

## 2. Sampling, failure policy and intervals

- [x] **Rows:** resample entire retained nonempty records at fixed retained N,
  preserving missingness masks and multiplicity. Rebuild scales/means/patterns
  per replicate; use the identical source model and existing accepted refit
  protocol. No relaxed Hessian gates, survivor replacement or listwise fallback.
- [x] **Failure:** any required unresolved/invalid/nonfinite replicate withholds
  the interval. Keep all requested IDs and reasons; `n_boot` remains requested B,
  with length-B estimates containing NA failures. No survivor interval from
  printing, `tidy()` or `confint()` at any confidence level. Interrupted runs
  are incomplete, never successful intervals.
- [x] **Draws:** jointly draw canonical free parameters using the full matched
  observed/model covariance; keep fixed zeros and avoid duplicate aliases.
  No optimizer/refits or negative nuisance-variance truncation. Refuse invalid
  covariance using the fixed factor/tolerance below. Record any roundoff
  correction; no material covariance repair.
- [x] Use the original fitted effect as point estimate and explicit
  `stats::quantile(type = 7)` for both methods. Preserve seeded sequential/parallel
  agreement. Nonfinite draw/functionals also withhold the interval.
- [x] Document IID Gaussian/ignorable-MAR and parameter-distinctness assumptions.
  The sampling target conditions on nonempty retention and excludes empty-count
  uncertainty. Include an all-empty MCAR fixture; do not generalize to MNAR.
  Joint-null/local-to-null NIE behavior remains a stated calibration limitation.
  Ignoring retention requires a model-parameter-independent normalization. A
  sufficient bounded case is all-empty MCAR selection independent of complete
  records, followed by the declared complete/MCAR/observed-X MAR mechanism
  among retained records. This argument does not cover arbitrary value-dependent
  all-empty deletion. Preserve positivity and identified observed information;
  verify collected/retained counts in the non-negligible all-empty MCAR fixture.

### Fixed covariance factor (bounded default)

Order free coordinates by the validated source `theta` names and require exact
covariance-name alignment. Refuse nonfinite V or nonpositive free-coordinate
marginal variances; fixed structural zeros are outside this free vector.
Let D contain marginal SDs and C = D^(-1) V D^(-1). Set
`tau_sym = 100 * .Machine$double.eps * q * max(1, max(abs(C)))`, with q free
coordinates. Refuse `max(abs(C - t(C))) > tau_sym`; otherwise symmetrize C.
For its symmetric eigendecomposition C = Q diag(lambda) Q', set
`tau_eig = 100 * .Machine$double.eps * q * max(1, max(abs(lambda)))`.
Refuse any lambda < -tau_eig; clip only remaining negative eigenvalues to zero.
Use F = D Q diag(sqrt(pmax(lambda, 0))) Q' and draws theta_hat + F z.
This symmetric correlation-root convention avoids arbitrary eigenvector signs
in supplied-normal comparisons. Log symmetry adjustment, eigenvalues/tolerances
and clipping. Require max(abs(D^(-1) (F F' - V) D^(-1))) <=
10 * max(tau_sym, tau_eig) in the independent factor test. Singular PSD draws
are allowed; substantial indefiniteness is refused.
These numerical defaults passed the frozen fixture checks; that evidence is bounded,
not a general threshold justification or interval-coverage calibration.

## 3. Independent tests and local completion gates

- [x] Use six bounded source fixtures: free/zero direct path crossed with
  complete, MCAR and observed-X MAR; compare the same supplied incomplete
  resamples against lavaan. Require exact parameter-name sets and classifications.
  Keep the paired plan's numerical tolerances and existing stricter native gates;
  use absolute total optimum-NLL difference <=1e-5 for these fixed fixtures.
  This is separate from the paired plan's <1e-7 same-parameter NLL identity;
  retain its coefficient <1e-5 and SD-normalized covariance <1e-3 gates.
  Compare identical rows/models and matched likelihood constants. A tolerance
  failure requires diagnosis; it never authorizes a relaxed threshold.
- [x] Check an independent rowwise observed-component Gaussian likelihood,
  score/Hessian, and covariance. Hand-check effects `a*b`, `cp`, `cp+a*b`;
  never use medfit's central functional as its own oracle.
- [x] Reproduce joint draws with independently constructed factors and supplied
  normals; check cross-covariance, fixed zeros, aliases and zero extra refits.
  Check manual type-7 interpolation for both methods and alternate levels.
- [x] Regression tests must detect mask/scale leakage, duplicate-row loss,
  survivor filtering, failed covariance/nonfinite effects, diagonal-only draws,
  source mutation, RNG-before-validation and withheld-CI accessor bypasses.
- [ ] Run relevant legacy/API, sequential/parallel, native numerical and local
  package/docs gates. Update help, support matrix and the existing FIML minibook
  example for the verified scope; record evidence once in the roadmap/status.
  Main-only hosted coverage and release-only expensive CI remain unchanged.

## 4. Budget and deferred work

**Now:** bounded local implementation and verification explicitly authorized 2026-11-01 MST.
For this authorized implementation milestone, fix the local
verification ceiling at **four elapsed hours, eight aggregate CPU hours, and
at most two concurrent workers**, including oracle checks and required local
package/docs gates. Stop at whichever time cap is reached first; retain partial
results and request a scoped budget amendment. Do not omit failing gates, rerun
until green or widen thresholds to fit the cap. Limits are cumulative across
verification attempts in that milestone; no automatic budget reset on failure.

The focused source/resample matrix is six source cells with 12 paired resamples
per cell: 156 medfit/lavaan fit invocations, excluding internal solver starts.
Give this matrix a sub-cap of **90 elapsed minutes and two aggregate CPU hours**
within the overall cap. Retain the accepted solver's starts/polishes and log
actual work; do not weaken it to meet budget. Predeclare small failure/draw
fixtures separately before execution; existing package tests also remain inside
the overall time/worker cap. Neither matrix nor cap permits a timing pilot or
simulation study. These ceilings are bounded defaults, not a claim that the work
has been timed or will finish within them. Implementation and these local gates are authorized; statistical studies and
external integration still require separate authorization.

**Deferred:** the candidate 40-million-fit simulation grid, its timing pilot,
exact statistical manifest and full resource allocation. Preserve Q10 rejection
floors and Q12-Q13 power/staged-admission decisions in the paired plan. No new
sample size or reduced calibration standard is substituted here. Numerical tests
establish implementation correctness within fixtures, not statistical coverage.
Deferring that study does not satisfy or remove the roadmap's statistical
admission requirement: wider calibration claims and release admission need a
separately agreed evidence plan. Do not start a study to finish this roadmap.

**Current decision:** the maintainer separately authorized bounded implementation/local verification
on 2026-11-01 MST; this contract alone did not authorize it. The execution plan is active,
statistical admission remains deferred, and all eleven future model variants remain unchanged.

Source anchors: [API](../R/bootstrap.R), [result class](../R/classes.R),
[base accessors](../R/methods-base.R), [tidy/glance](../R/methods-tidy.R),
[FIML source validation](../R/sem-fiml-interface.R),
[central effects](../R/effect-se.R).
