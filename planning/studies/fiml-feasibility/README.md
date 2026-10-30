# Bounded FIML study and prototype

**Current state:** local numerical PASS, implemented and tested at `b4a50f36`.
Separate from 0.16. No production integration, push, release or hosted CI was
performed. The worktree branch is `codex/fiml-feasibility`; baseline dev is
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
| Current local acceptance | [Report](prototype-report.md) | 42/42 fits, 13/13 edges |
| Production/API integration | [Deferred requirements](numerical-implementation-memo.md#integration-acceptance-deferred-to-a-separate-authorization) | Not authorized |

Early references to pending prototype authorization describe historical stages.
The user subsequently authorized the isolated prototype and its optimizer
repairs. That authorization did not extend to production implementation or
change 0.16. A technical GO also does not establish adopter commitment.

## Code and evidence

| Artifact | Purpose |
| --- | --- |
| [study.R](study.R) | Independent likelihood, original feasibility harness |
| [numerical-probes.R](numerical-probes.R) | Derivative/information/source probes |
| [prototype.R](prototype.R) | Study-only native RAM FIML implementation |
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

The final verified run exited 0 in approximately 37 seconds. It includes the
original raw-data 30-fit/10-edge reference study. It rewrites the study output
files, so preserve the current receipt before a future rerun. See the
[technical record](technical-record.md#reproduction-and-evidence-integrity) for
commands, dependencies, checks and the distinction from deferred hosted gates.
