# FIML implementation and results

> Bounded research prototype · medfit · 2026-10-29
> Sources: [technical record](technical-record.md), [acceptance report](prototype-report.md), [frozen protocol](prototype-protocol.md), and [local correctness review](p2-review-baseline/local-correctness-review.md).

**Status:** Local numerical PASS; both P2 review findings resolved, with regression tests passing.

Separate from 0.16. No production integration, push, release, or expensive CI.
Initial implementation: `b4a50f36`; reviewed baseline: `c7430172`. Current corrections and validation: [P2 repair report](p2-repair-report.md).

## tl;dr

| Metric | Value |
| --- | --- |
| Regular fits passing | 42 / 42 |
| Edge and defect checks passing | 13 / 13 |
| Gradient/Hessian points passing | 126 / 126 |
| P2 regression assertions passing | 61 / 61 |
| Open P2 review findings | 0 |

Counts describe the corrected local acceptance run. Both findings are closed by targeted regression evidence, not merely by the fit counts. Sources: [acceptance evidence](prototype-report.md#final-local-evidence), [P2 repair evidence](p2-repair-report.md).

## 1. What is implemented

### The bounded model

- Three observed Gaussian variables: X, mediator M, and outcome Y.
- Equations: `X = ix + eX`; `M = im + a*X + eM`; `Y = iy + b*M + cp*X + eY`.
- Random X, free intercepts, independent disturbances, positive residual variances, one group, and unweighted rows.
- Two model variants: direct path `cp` free, or fixed exactly to zero.
- Study-only output; no public fit class or production API routing.

Source: [model and input boundary](technical-record.md#exact-model-and-input-boundary).

### How the numerical engine works

- Group rows by which variables are observed; retain their means, covariances, counts, and original IDs.
- Evaluate each observed-variable block with a Cholesky Gaussian likelihood; include mean structures and normalizing constants.
- Center and scale using available marginal observations; initialization requires no complete rows.
- Reuse native RAM moment derivatives; differentiate the full likelihood score for observed information.
- Invert the Hessian of total negative log likelihood, then transport the full covariance back to original coordinates.
- Require optimizer status, stationarity, information/rank diagnostics, and accepted-likelihood agreement.

Sources: [implementation map](technical-record.md#implementation-map-and-output-record), [likelihood](technical-record.md#missingness-patterns-and-the-full-likelihood), [covariance transport](technical-record.md#affine-coordinates-and-full-covariance-transport).

## 2. What passed and what was repaired

### Evidence at a glance

| Check | Result | Interpretation |
| --- | --- | --- |
| Prototype fits and edges | 42/42; 13/13 | Bounded local numerical acceptance passes |
| Derivatives and likelihood-difference identities | 126/126 each | Fit plus two fixed perturbations per cell |
| Original reference study | 30/30 fits; 10/10 edges | Independent likelihood agrees with lavaan |
| Independent optimizer/information gates | 42/42 | Independent convergence and curvature checks pass |
| Actual covariance-scaling mutation during review | 42/42 fits rejected | Primary SE/covariance comparisons catch the injected defect |
| Archived evidence integrity | 110/110 hashes match | Saved artifacts remained unchanged during review |

Sources: [acceptance evidence](prototype-report.md#final-local-evidence), [fresh review](p2-review-baseline/local-correctness-review.md#verification). The mutation's 13 edge checks still passed; the primary fit comparisons supplied the decisive rejection.

### Optimizer and reference repairs

| Finding | Problem | Fix |
| --- | --- | --- |
| Shifted prototype fits | nlminb stopped before original-coordinate stationarity passed | Supply the full score-derived Hessian to its own stable-objective refinement |
| Near-singular independent fits | Independent oracle polish reported nonconvergence | Supply its own numerical gradient/Hessian and revise solver stopping controls |
| Shifted lavaan reference | Raw-coordinate intercept error exceeded the fixed limit | Fit standardized data and independently transport every estimate and covariance entry |

The initial prototype passed 38/42 fits. The repaired run passes 42/42. The first two repair categories cover the four failed model/fixture cells; the lavaan conditioning repair resolved a further reference discrepancy. Acceptance limits and required statuses were not relaxed.

Tighter stopping alone, excessively tight stopping with curvature, and a trial lavaan BFGS fit were rejected when they failed accuracy or convergence requirements. Historical failures and intermediate 41/42 results remain preserved.

Source: [repairs and rejected approaches](prototype-report.md#repairs-and-rejected-approaches).

### Largest reported errors

| Quantity | Worst error | Fixed limit |
| --- | ---: | ---: |
| Likelihood per retained row | 2.04e-13 | 1e-8 |
| Standardized estimate | 1.99e-6 | 1e-5 |
| Relative SE | 3.21e-5 | 1e-3 |
| Full normalized covariance | 6.42e-5 | 1e-3 |
| Scaled stationarity | 6.57e-6 | 1e-5 |
| Independent observed Hessian | 1.29e-6 | 1e-4 |

These values come from the corrected local acceptance run and updated acceptance report. Covariance errors use independent-reference SE products as their normalizer. Source: [final local evidence](prototype-report.md#final-local-evidence).

## 3. Design — Decisions

### Full observed curvature

**Concept:** Standard SEs come from the inverse Hessian of total negative log likelihood.

**Issue:** Dropping nonlinear moment-mapping curvature or inverting an averaged Hessian changes the covariance.

**Solution:** Differentiate the complete analytic score, check two resolutions, and compare full named matrices with independent references.

**Impact:** The prototype covariance and acceptance harness retain off-diagonal covariance and test omitted-curvature and N-scaling defects.

Source: [observed Hessian and N scaling](technical-record.md#score-observed-hessian-and-n-scaling).

### Separate solvers and independent references

**Concept:** Native SLSQP and nlminb each fit three deterministic starts.

**Issue:** Optimizer success alone does not establish stationarity or reference agreement.

**Solution:** Require an accepted candidate from each solver; refine nlminb's own candidate; compare against a separately parameterized likelihood and lavaan.

**Impact:** `prototype_fit` gates accepted solutions; the acceptance harness compares likelihood, estimates, SEs, and full covariance without using prototype estimates to initialize the references.

Sources: [solver refinement](technical-record.md#stable-likelihood-differences-and-solver-refinement), [independent references](technical-record.md#independent-references-and-identification-diagnostics).

### Keep research and integration separate

**Concept:** This is an isolated, bounded numerical prototype.

**Issue:** Finite fixture agreement does not establish a production missing-data API, general identification, global optimization, or inference coverage.

**Solution:** Keep unsupported models and public downstream routing outside this prototype; require a separate integration decision.

**Impact:** Production resampling, profiles, MBCO, fit indices, and extraction compatibility remain deferred; 0.16 is neither expanded nor blocked by this study.

Source: [deferred work](technical-record.md#decisions-consequences-and-deferred-work).

## 4. What remains open

### Both P2 review findings resolved

| Finding | Problem | Fix implemented and tested |
| --- | --- | --- |
| Failed-fit evidence | Post-solver spread, rank, and information errors discard the completed attempt table | Attach the complete ledger to every post-solver error; four failure-path scenarios and both model variants are tested; no-overlap exports six records |
| Near-singular fixture provenance | A 0.9-SD residual multiplied by 0.03 generates SD 0.027, while the frozen protocol specifies 0.03 | Use `(.03 / .9) * noise`; independently reconstruct both fixtures at SD 0.03; preserve earlier evidence and rerun all 42 acceptance cells |

Sources: [historical review findings](p2-review-baseline/local-correctness-review.md#findings), [repair evidence](p2-repair-report.md), [post-solver diagnostic](prototype.R), and [fixture helper](prototype-fixtures.R). The two evidence/fixture gaps are resolved; no production implementation is implied.

### Outside the demonstrated scope

- Fixed-X FIML, weights, latent/categorical models, nonlinear constraints, robust or expected-information SEs, and bootstrap.
- Repeated-sampling coverage, general MAR robustness, global optimization/identification guarantees, performance benchmarks, and cross-platform validation.
- Production APIs, defaults, downstream compatibility, releases, and inclusion in 0.16.

Sources: [acceptance interpretation](prototype-report.md#reproduce-and-interpret), [deferred integration requirements](numerical-implementation-memo.md#integration-acceptance-deferred-to-a-separate-authorization).

## Next steps

1. Consider a separately authorized integration design with an identified adopter/use case, explicit FIML/random-X opt-in, preserved defaults, and downstream support/rejection rules.
2. Keep FIML separate from 0.16; broader model support, inference coverage and production gates remain deferred.

Source: [review findings and next milestone](p2-review-baseline/local-correctness-review.md#evidence-and-next-milestone). This report restructures existing sources; it authorizes no implementation or integration.

## Source map

- [Technical record](technical-record.md): equations, implementation, decisions, and fix history.
- [Acceptance report](prototype-report.md): numerical results and rejected approaches.
- [Frozen protocol](prototype-protocol.md): predeclared scope, fixtures, and gates.
- [Implementation-options memo](numerical-implementation-memo.md): source research and deferred integration requirements.
- [Local correctness review](p2-review-baseline/local-correctness-review.md): historical reproduction and the two findings, now resolved by the repair report.
- [P2 repair report](p2-repair-report.md): corrections, regression tests and current validation.
- [Saved fit evidence](prototype-results/rows.csv), [edge evidence](prototype-results/edges.csv), and [derivative evidence](prototype-results/derivatives.csv).
