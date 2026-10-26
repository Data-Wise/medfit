# Result: Checkpoint 2, missingmed consumer rerun (2026-10-25)

Plan: `PLAN-checkpoint2-missingmed-consumer-rerun-2026-10-25.md`. Read-only on missingmed.

## Setup
- medfit: `origin/dev` `9599608` (P1 to P4 merged), Version 0.14.0, loaded from a clean `git archive` with `pkgload::load_all`; `.sem_retain_covariance` present. Nothing installed.
- missingmed: two scratch copies from `git archive`, no writes in the repo: `c2af811` (the closure matrix's caller source) and `4a84e66` (tip of `feature/lavaan-mbco-medfit`; `c2af811` is on that branch).
- missingmed loaded with `pkgload::load_all`, each file run with `testthat::test_file`, silent reporter.

## Counts (identical on both revisions)

| File | Tests | Expectations | Failed | Errors | Skipped |
|---|---|---|---|---|---|
| `test-mbco-encoding.R` | 9 | 95 | 0 | 0 | 0 |
| `test-mbco-provider.R` | 5 | 17 | 0 | 0 | 0 |
| `test-mbco-sem-acceptance.R` | 20 | 595 | 0 | 0 | 0 |
| Total | 34 | 707 | 0 | 0 | 0 |

## Mapping
No failures, so no row of the naming table (`$ledger`, over-cap error, `medfit_sem_covariance_error`, message text) was
exercised by these three files. Zero unmapped failures.

## Discrepancies with the receipts (not failures)
- The closure matrix states 816 (95 + 126 + 595). Encoding and acceptance match exactly; the provider file yields 17 at both
  revisions (14 `expect_` calls in the source), so 109 of the 816 are not reproduced. The 126 may count differently or
  come from another revision or runner; not resolved.
- The matrix's fixture blob `13b372d9fcf182dbbeae5b426621cedc2a9dd276` is not in either tree; the only fixture,
  `mbco-d4-medsim-0.5.1.rds`, hashes to `e9956e7ea9127f4b7138b3073c7880b88508e583` at both revisions (unchanged between them).

## What this does and does not show
- Shows: missingmed's consumer files that call `medfit::mbco_sem`/`fit_sem` pass unchanged against `dev`.
- Does not show: the naming-table adapter changes are needed or not, since these files do not assert on `diagnostics$outcome`,
  `medfit_sem_unresolved` or the covariance error class. Those live in the dependency runner (768 assertions) and in D5's
  new tests, not run here.

## Verdict
Checkpoint 2 missingmed line: no unmapped failures, with the two receipt discrepancies above open for the author.
