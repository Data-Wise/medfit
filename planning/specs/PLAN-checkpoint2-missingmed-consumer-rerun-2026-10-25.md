# Plan: Checkpoint 2 for D1-D4 (missingmed consumer rerun and OpenBLAS gates)

Status: draft, 2026-10-25. Part of `planning/PLAN-missingmed-evidence-D1-D4-2026-10-24.md` (Checkpoint 2). Starts when
P4 (#340) is merged to `dev`. Owner: the medfit session; the missingmed steps need the author's explicit request each time
(`no-cross-repo-work-without-permission`).

## Spec

### Goal
Show that missingmed's consumer code still works, or list exactly what must change in its adapter (missingmed D5), against
`dev` carrying P1 to P4 (#336, #338, #339, #340).

### Why it is not a plain pass or fail
missingmed's consumer tests were written against the 0.12.0 chain on `keep/d4-3a98bf6`. medfit's reconciled design differs
in names, so some consumer assertions are expected to fail for naming reasons, not because the evidence is wrong:

| Consumer expects (keep chain) | medfit `dev` has | Where decided |
|---|---|---|
| `diagnostics$outcome` on an MBCO result | `$ledger` | P1, ADR D-12 |
| typed `medfit_sem_unresolved` for an over-cap model | a plain error carrying `$ledger` | P3 |
| covariance-stage error class from D4 | `medfit_sem_covariance_error` (sibling of `medfit_error_no_convergence`) | P4 |
| error message prefixed "covariance-stage failure" | the original message; the phrase is in the retention warning | P4, D-12 |

A failure that maps to one of these rows is an adapter change in missingmed, not a medfit defect. A failure that does not
map to any row is a finding for medfit (a contract gap) and blocks closing Checkpoint 2.

### Scope
- In: read-only use of missingmed (scratch copy of a committed revision, no writes, no commits, no pushes there), medfit
  `dev` loaded with `devtools::load_all()` in a scratch R process, the consumer runner files, a written mapping table.
- Out: editing missingmed (that is D5, its own request and PR), saving or changing missingmed fixtures or receipts, installs
  into the user library, stochastic suites, `R CMD check` of missingmed.

### Consumer runner (from missingmed's D4 closure matrix, 816 assertions)
`tests/testthat/test-mbco-encoding.R` (95), `test-mbco-provider.R` (126), `test-mbco-sem-acceptance.R` (595). Caller source
in the matrix: missingmed `c2af811`; its current branch is `feature/lavaan-mbco-medfit`. The stored fixture blob must stay
`13b372d9fcf182dbbeae5b426621cedc2a9dd276`.

### Guards
- Never write inside `~/projects/r-packages/active/missingmed`: work from `git archive <rev>` into a new empty scratch
  directory and run everything there.
- Never install medfit into a user library; load it from source in the scratch process and verify by loading, not by
  `installed.packages()`.
- Run R with the scratch copy and the medfit worktree as separate absolute paths; never `setwd` into either repo.
- Record the exact missingmed revision and medfit commit in the result.

### Acceptance
- Every consumer assertion either passes or maps to a row of the naming table, with the failing assertion text quoted.
- Zero unmapped failures. An unmapped failure reopens P1 to P4 as a medfit finding.
- The result file lists, per failing consumer assertion: file, assertion, mapped row, proposed adapter change.
- The stored fixture blob is unchanged in the scratch copy.

## Todo

### A. medfit (no permission needed)
- [ ] A1. Merge #340 (P4) when its checks are green; then `git fetch` and fast-forward `dev`. Blocked by: #340 green.
- [ ] A2. Remove the P4 worktree and delete its local branch (author runs the branch delete). Blocked by: A1.
- [ ] A3. Dispatch the OpenBLAS gates on the combined tree:
  `gh workflow run gates.yaml --ref dev --repo Data-Wise/medfit`. Record the run URL, both shard results and the image
  (ubuntu-24.04 completes in about 25 minutes; ubuntu-26.04 timed out at 75 minutes on 2026-10-24, cause unproven).
  Acceptance: `gates (rest)` and `gates (reliability)` succeed, or a failure is judged against `origin/dev` before the
  four slices. Blocked by: A1.
- [x] A4. Target release for D1-D4: a 0.14.x minor (author, 2026-10-25). Considered: 0.15.0 or a 0.14.x minor. 0.15.0 is the announced native-defaults flip
  (#329), at least two months after 0.14.0. Author's call.

### B. missingmed consumer rerun (needs the author's explicit request; read-only)
- [ ] B0. Author requests the rerun. Blocked by: A1.
- [ ] B1. Pick the missingmed revision: the caller source in the closure matrix (`c2af811`) or the tip of
  `feature/lavaan-mbco-medfit`; state which and why. Open question below.
- [ ] B2. Make the scratch copy: `git -C ~/projects/r-packages/active/missingmed archive <rev>` into a new empty directory
  under the session scratchpad. Check the fixture blob hash there.
- [ ] B3. Find how missingmed obtains medfit in tests (DESCRIPTION has `medfit (>= 0.3.1)`; the closure matrix calls it
  "source-load"), and arrange the scratch process to load medfit `dev` from a clean `git archive` of the merged commit via
  `devtools::load_all()` or `pkgload`, without installing. Verify by loading: print `packageVersion("medfit")` and confirm
  the P4 code is present (for example `exists(".sem_retain_covariance", asNamespace("medfit"))`).
- [ ] B4. Run the three consumer files in the scratch process with a file reporter (the closure matrix notes the harness
  must call start-file and end-file as the existing runner does). Capture counts: expectations, failures, errors, skips.
- [ ] B5. For each failure, fill the mapping table above; quote the assertion; classify as naming (adapter) or unmapped.
- [ ] B6. Write the result to `planning/specs/RESULT-checkpoint2-missingmed-rerun-<date>.md` in medfit (not in missingmed)
  and link it from the P4 PR or the plan. Include the two revisions and the counts.
- [ ] B7. Close or reopen: zero unmapped failures closes Checkpoint 2's missingmed line; any unmapped failure reopens the
  relevant slice.

### C. Hand-off to missingmed D5 (separate request, separate repo)
- [ ] C1. From the result, draft the adapter change list for missingmed (field `ledger`, no `medfit_sem_unresolved`, the
  covariance error class, message handling). Draft only; applying it is missingmed's D5 PR, needs the author's request.
- [ ] C2. missingmed T5 also waits on a stored improper-null input the author has not supplied (missingmed's blocker).

## Open questions
- B1: which missingmed revision to test against. The closure matrix names `c2af811`; the current branch may be ahead. I
  recommend the matrix's revision first (it is the one whose receipts claim 816), then the branch tip as a second run.
- B3: how missingmed's tests currently pick up medfit is not confirmed; the grep for a source-load helper found only prose
  in the NOTE files. Confirm by reading missingmed's test helpers before B4.
- A4: decided 2026-10-25, a 0.14.x minor.
