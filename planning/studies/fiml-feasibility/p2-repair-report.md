# FIML P2 repairs: implementation and local verification

2026-10-29. Reviewed baseline: `c7430172`; original numerical implementation:
`b4a50f36`. Scope remains the isolated three-variable Gaussian random-X study,
separate from 0.16. No production code, public API, push, or expensive CI.

**Verdict: PASS for both bounded repairs and corrected local acceptance.**
This closes the two P2 findings; production integration remains a separate,
unauthorized milestone.

## Repair contract and implementation

| Finding | Required behavior | Implemented correction |
| --- | --- | --- |
| Post-solver ledger loss | Preserve every completed solver/start record on later errors | One condition handler around all post-solver checks attaches the complete table and rethrows the original condition |
| Fixture SD mismatch | Match the frozen generating residual SD 0.03 | Shared fixture helper multiplies base SD-0.9 innovations by `0.03 / 0.9` |

The ledger includes SLSQP and nlminb starts 1,2,3, their statuses, objective,
stationarity, acceptance and reasons. Spread, geometry, observed-information
and nested numerical errors retain all six records. Existing condition classes
and messages are preserved; pre-solver input rejection has no completed table.
The no-overlap edge both asserts the full solver/start set and exports
[diagnostic_attempts.csv](prototype-results/diagnostic_attempts.csv).

`prototype-fixtures.R` holds the shared near-singular constructor used by the
acceptance runner and regression tests. The correction changes only the two
near-singular data cells; seeds, masks and all numerical acceptance thresholds
remain unchanged. Both models are independently reconstructed with the same
seed and direct `rnorm(sd = 0.03)` draws, including exact missingness masks.

## Regression evidence

The initial tests reproduced nine failures: five missing-ledger checks and four
numerical fixture comparisons. The final suite adds an ordinary numerical-error
case and passes **4 tests / 61 assertions**, with no failures or errors:

| Test | Assertions |
| --- | ---: |
| Actual rank-deficient fits, both models | 18 |
| Forced post-solver likelihood-spread rejection | 10 |
| Information rejection, typed perturbation and ordinary Hessian errors | 27 |
| Independent SD-0.03 fixture reconstruction, both models | 6 |

Test-only failure injection occurs in isolated function environments; production
namespace bindings are never replaced. The pre-fix run demonstrates that the
assertions reject the original defects. See the [failing historical log](p2-review-baseline/regression-before.log)
and [passing current log](prototype-results/regression-tests.log).

## Corrected local acceptance

| Check | Result |
| --- | --- |
| Regular fits | 42/42 PASS |
| Edge/metamorphic/planted-defect checks | 13/13 PASS |
| Gradient/Hessian points | 126/126 PASS |
| Stable likelihood identities | 126/126 PASS |
| Independent optimizer/information gates | 42/42 PASS |
| Original reference study | 30/30 fits; 10/10 edges PASS |
| No-overlap diagnostic attempt records | 6/6 retained and exported |
| Other numerical fixtures | All 40 acceptance rows and parameter/SE coordinates exactly unchanged |
| R parsing and namespace lint | 6/6 study scripts PASS |

The final complete acceptance run exited 0 in 38.60 seconds. Likelihood,
estimates, SEs and full covariance are compared against the independently
parameterized likelihood and lavaan with the existing fixed limits. The
largest scaled stationarity is 6.563e-6 (limit 1e-5); the largest Hessian
discrepancy is 1.285e-6 (limit 1e-4). No limit was widened. The original four
planted defects remain detected.

[Validation receipt](p2-repair-validation.json) records counts, changed cells and
worst errors. [Current acceptance report](prototype-report.md) contains the full
error table. Evidence hashes are in [the manifest](evidence-manifest.json).

## History and interpretation

The [P2 baseline](p2-review-baseline/README.md) preserves the original review,
pre-fix test failures, acceptance rows and key gates. Complete prior code/data
remain at `c7430172`. Earlier near-singular results genuinely used SD 0.027;
they are historical evidence, not results of the corrected SD 0.03 fixture.
The older optimizer-repair receipt and documentation-only validation receipt
remain historical records of their own runs.

These repairs do not establish coverage under arbitrary MAR, global
identification/optimization, fixed-X FIML, robust/expected-information SEs,
weights, general model support, cross-platform validation or production API
compatibility. After these bounded repairs, a separately authorized integration
design can address an actual adopter, explicit FIML/random-X opt-in, preserved
defaults, and downstream support/rejection rules. This work does not expand or
block 0.16.

## Reproduce locally

From the study worktree root, with the existing research dependencies:

```sh
Rscript -e 'testthat::test_file("planning/studies/fiml-feasibility/test-prototype-regressions.R", stop_on_failure = TRUE)'
Rscript planning/studies/fiml-feasibility/prototype-acceptance.R
```

The acceptance command rewrites `prototype-results/`; preserve its existing
receipt before another run. No production package suite, hosted CI, release or
external submission is implied by these research checks.
