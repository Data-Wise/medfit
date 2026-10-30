# Bounded FIML study and prototype

**Current state:** the isolated prototype passes locally. The separately authorized
bounded production integration is implemented at `625e7280`; corrected QA and
pre-docs gates pass at test head `0f40b73f`. Documentation and final local gates
remain pending. See the [active plan](../../PLAN-FIML-bounded-integration-2026-10-29.md)
and [argument analysis](argument-design-analysis.md).
Initial numerical implementation: `b4a50f36`; pre-repair reviewed baseline: `c7430172`.
See the [P2 repair report](p2-repair-report.md) for current evidence and history.
Separate from 0.16. No push, release or hosted CI was performed. The worktree branch is `codex/fiml-feasibility`; baseline dev is
`edcf23d8705165cd2497deda0d4e8410b9754811`.

## Read in this order

1. [Technical record](technical-record.md): complete plan history, model,
   likelihood, derivatives, covariance, numerical decisions and fixes.
2. [Final acceptance report](prototype-report.md): current result, exact scope,
   failed alternatives, numerical discrepancies and reproducible command.
3. [Frozen prototype protocol](prototype-protocol.md): fixtures and acceptance
   limits established before execution.
4. [Implementation-options memo](numerical-implementation-memo.md): primary
   source research, design options and deferred integration requirements.

## Plans, execution and decisions

| Stage | Authoritative record | State |
| --- | --- | --- |
| Standalone feasibility and adversarial corrections | [Protocol](protocol.md) | Complete |
| Independent likelihood versus lavaan | [Study report](report.md) | 30/30 fits, 10/10 edges |
| Numerical implementation research | [Memo](numerical-implementation-memo.md) | Complete |
| Algebra and curvature probes | [Results](numerical-probes.csv) | Six probes |
| Source identity checks | [Functions](source-functions.csv) | 12 matches |
| Scope and fixed-X distinction | [Memo](numerical-implementation-memo.md) | Prototype bounded |
| Frozen execution design | [Prototype protocol](prototype-protocol.md) | Complete |
| Initial acceptance | [Historical report](prototype-before-optimizer-repair.md) | NO-GO at `c92b6fec` |
| Optimizer and reference repairs | [Technical record](technical-record.md) | Complete at `b4a50f36` |
| P2 review repairs | [Repair report](p2-repair-report.md) | Both findings resolved; 61 assertions PASS |
| Current local acceptance | [Report](prototype-report.md) | 42/42 fits, 13/13 edges |
| Bounded integration design | [Design](integration-design.md), [review](integration-design-review.md) | Accessor P2 resolved; static review PASS, design only |
| Production/API implementation | [Active plan](../../PLAN-FIML-bounded-integration-2026-10-29.md) | Authorized and locally implemented; QA/pre-docs PASS; docs/final gates pending |

Early references to pending prototype authorization describe historical stages.
The user subsequently authorized the isolated prototype and its optimizer
repairs. A later, separate authorization activated bounded production implementation;
neither authorization assigns it to 0.16. A technical GO also does not establish external adopter commitment. The new
[design](integration-design.md) names medfit's own simple-mediation workflow as the
first engineering adopter; it does not claim an external package has committed.

## Code and evidence

| Artifact | Purpose |
| --- | --- |
| [study.R](study.R) | Independent likelihood, original feasibility harness |
| [numerical-probes.R](numerical-probes.R) | Derivative/information/source probes |
| [prototype.R](prototype.R) | Study-only native RAM FIML implementation |
| [prototype-fixtures.R](prototype-fixtures.R) | Correct SD-0.03 near-singular fixture |
| [test-prototype-regressions.R](test-prototype-regressions.R) | Four tests / 61 assertions for P2 repairs |
| [P2 validation receipt](p2-repair-validation.json) | Current local acceptance and repair checks |
| [Diagnostic attempts](prototype-results/diagnostic_attempts.csv) | Six no-overlap solver/start records |
| [prototype-acceptance.R](prototype-acceptance.R) | Complete local acceptance runner |
| [rows.csv](prototype-results/rows.csv) | All 42 regular cells |
| [edges.csv](prototype-results/edges.csv) | All 13 edge and mutant checks |
| [derivatives.csv](prototype-results/derivatives.csv) | All 126 checked points |
| [matrices.csv](prototype-results/matrices.csv) | Full named covariance/Hessian entries |
| [gradients.csv](prototype-results/gradients.csv) | Full gradient coordinates |
| [attempts.csv](prototype-results/attempts.csv) | 252 prototype solver/start groups |
| [independent_attempts.csv](prototype-results/independent_attempts.csv) | 126 independent starts |
| [ledgers.csv](prototype-results/ledgers.csv) | 12,600 original row IDs |
| [conditioning.csv](prototype-results/conditioning.csv) | Local information/rank diagnostics |
| [Validation receipt](optimizer-repair-validation.json) | Counts and four repaired regressions |
| [Source manifest](source-manifest.json) | Inspected lavaan archive/file hashes |
| [Evidence manifest](evidence-manifest.json) | Recursive artifact hashes |

`prototype-initial-results/`, `prototype-repair1-results/` and
`prototype-repair2-results/` preserve earlier failed runs.
`optimizer-repair-baseline/` preserves the four optimizer failures;
`optimizer-repair-probes/` preserves rejected solver/reference trials.
Complete pre-repair evidence is also retained in local commit `c92b6fec`.

## Reproduce

From the study worktree root, with the already installed research dependencies:

```sh
Rscript planning/studies/fiml-feasibility/prototype-acceptance.R
```

The current acceptance run exits 0; see the [repair report](p2-repair-report.md) for timing and validation.
The previous numerical run took approximately 37 seconds. It includes the
original raw-data 30-fit/10-edge reference study. It rewrites the study output
files, so preserve the current receipt before a future rerun. See the
[technical record](technical-record.md#reproduction-and-evidence-integrity) for
commands, dependencies, checks and the distinction from deferred hosted gates.

The [historical P2 baseline](p2-review-baseline/README.md) preserves the review,
failing regression evidence and earlier acceptance rows. Its near-singular data
actually used SD 0.027; current data implement the frozen SD 0.03 specification.
