# FI-B0: short implementation checklist

Date: 2026-10-31 MDT. Status: **condensed proposal; implementation not authorized**.
Replaces the longer decision packet from commit `270584ec`. No experiments or push.

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

- [ ] Add exactly matched, named-only `source_fit = NULL` and `effect = NULL`
  after `...` in `bootstrap_mediation()`, preserving existing positional slots,
  defaults and callback contracts. Source-route calls omit `statistic_fn`;
  validate that route before forcing the existing required callback argument.
- [ ] Require a validated accepted FIML `SEMFit`, explicit `method` and exact
  `effect` (`nie`, `nde`, `te`). `nonparametric` means row bootstrap;
  `parametric` means Gaussian parameter draws, not generative parametric bootstrap.
- [ ] Reject conflicts with supplied `statistic_fn`, non-NULL `data`,
  `mediation_data`, `cluster`, nonempty `...`, and source-route `plugin`.
  Reject `effect` without a source fit. Validate before RNG/workers/refits.
- [ ] Reuse `BootstrapResult` with backward-compatible optional inference
  metadata. Preserve legacy constructors and tidy/glance columns. Record target,
  source provenance, method label, requested/successful/failed counts, seed,
  sampling frame, and the complete replicate ledger. Never mutate the source.

Design examples only; not currently supported calls:

```r
bootstrap_mediation(method = "nonparametric", source_fit = fit,
                    effect = "nie", n_boot = 999L, seed = 101L)
bootstrap_mediation(method = "parametric", source_fit = fit,
                    effect = "te", n_boot = 20000L, seed = 102L)
```

## 2. Sampling, failure policy and intervals

- [ ] **Rows:** resample entire retained nonempty records at fixed retained N,
  preserving missingness masks and multiplicity. Rebuild scales/means/patterns
  per replicate; use the identical source model and existing accepted refit
  protocol. No relaxed Hessian gates, survivor replacement or listwise fallback.
- [ ] **Failure:** any required unresolved/invalid/nonfinite replicate withholds
  the interval. Keep all requested IDs and reasons; `n_boot` remains requested B,
  with length-B estimates containing NA failures. No survivor interval from
  printing, `tidy()` or `confint()` at any confidence level. Interrupted runs
  are incomplete, never successful intervals.
- [ ] **Draws:** jointly draw canonical free parameters using the full matched
  observed/model covariance; keep fixed zeros and avoid duplicate aliases.
  No optimizer/refits or negative nuisance-variance truncation. Refuse invalid
  covariance; specify a deterministic PSD factor and roundoff-only tolerance
  before coding. Record any roundoff correction; no material covariance repair.
- [ ] Use the original fitted effect as point estimate and explicit
  `stats::quantile(type = 7)` for both methods. Preserve seeded sequential/parallel
  agreement. Nonfinite draw/functionals also withhold the interval.
- [ ] Document IID Gaussian/ignorable-MAR and parameter-distinctness assumptions.
  The sampling target conditions on nonempty retention and excludes empty-count
  uncertainty. Include an all-empty MCAR fixture; do not generalize to MNAR.
  Joint-null/local-to-null NIE behavior remains a stated calibration limitation.

## 3. Independent tests and local completion gates

- [ ] Use six bounded source fixtures: free/zero direct path crossed with
  complete, MCAR and observed-X MAR; compare the same supplied incomplete
  resamples against lavaan. Require exact parameter-name sets and classifications.
  Keep the paired plan's numerical tolerances and existing stricter native gates;
  predeclare optimum-comparison tolerance separately before running tests.
- [ ] Check an independent rowwise observed-component Gaussian likelihood,
  score/Hessian, and covariance. Hand-check effects `a*b`, `cp`, `cp+a*b`;
  never use medfit's central functional as its own oracle.
- [ ] Reproduce joint draws with independently constructed factors and supplied
  normals; check cross-covariance, fixed zeros, aliases and zero extra refits.
  Check manual type-7 interpolation for both methods and alternate levels.
- [ ] Regression tests must detect mask/scale leakage, duplicate-row loss,
  survivor filtering, failed covariance/nonfinite effects, diagonal-only draws,
  source mutation, RNG-before-validation and withheld-CI accessor bypasses.
- [ ] Run relevant legacy/API, sequential/parallel, native numerical and local
  package/docs gates. Update help, support matrix and the existing FIML minibook
  example for the verified scope; record evidence once in the roadmap/status.
  Main-only hosted coverage and release-only expensive CI remain unchanged.

## 4. Budget and deferred work

**Now:** planning and static document checks only. No runtime or simulation budget
is authorized. Future implementation authorization should name the bounded local
fixture count, worker/time cap and stop rule; seek agreement before exceeding it.
The earlier six-source/12-paired-resample design costs 156 medfit/lavaan fit
invocations, excluding internal solver starts. It is a proposed local oracle
budget, not permission to run it now. Smaller failure fixtures remain explicit.

**Deferred:** the candidate 40-million-fit simulation grid, its timing pilot,
exact statistical manifest and full resource allocation. Preserve Q10 rejection
floors and Q12-Q13 power/staged-admission decisions in the paired plan. No new
sample size or reduced calibration standard is substituted here. Numerical tests
establish implementation correctness within fixtures, not statistical coverage.
Deferring that study does not satisfy or remove the roadmap's statistical
admission requirement: wider calibration claims and release admission need a
separately agreed evidence plan. Do not start a study to finish this roadmap.

**Next decision:** focused review of this API/failure/test checklist, then separate
implementation authorization. FI-B0 is not implementation approval. Keep the
implementation plan inactive and retain all 11 future model variants unchanged.

Source anchors: [API](../R/bootstrap.R), [result class](../R/classes.R),
[base accessors](../R/methods-base.R), [tidy/glance](../R/methods-tidy.R),
[FIML source validation](../R/sem-fiml-interface.R),
[central effects](../R/effect-se.R).
