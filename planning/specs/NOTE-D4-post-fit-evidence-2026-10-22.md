# D4 local checkpoint

Follow-up: explicit nonwinning-child controls in both product orders/both nulls,
768 dependency +816 consumer =1584 deterministic assertions pass; new test lint
clean. Attribution and dropped-notice mutants fail intended assertions. See
caller `docs/specs/D4-closure-matrix-2026-10-22.md` and raw failure receipt
`D4-closure-claude-review-2026-10-22.json`. Claude5ad08ae8 failed structured-output
finalization: no valid verdict, unread bodies and draft concerns remain. D4 not
independently closed, T5 UNACCEPTED. Author requested wrap-up; no automatic retry.
Descriptions below are the previous checkpoint, not current test counts.

Canonical cross-package receipt:
`/Users/davood/projects/r-packages/active/missingmed/docs/specs/NOTE-D4-post-fit-evidence-2026-10-22.md`.
Raw Claude receipt is alongside it as `D4-claude-review-2026-10-22.json`.

On pinned D3 `cba4c1a`, D4 retains accepted likelihood/context in a typed public
covariance-stage failure and permits checked internal null-only retention.
654 dependency +816 consumer deterministic assertions pass. Full spec review
coverage and nonwinning-child attribution follow-up remain open; T5 UNACCEPTED,
D5/real-case evidence not complete. No installs, simulations, saved-result changes,
push or merge. Public partial payload is not a successful SEMFit.

## Reconciliation on dev (P4)

Written against 0.12.0, before #300, #303 and P1 to P3; re-derived on `dev` (1bd5236), not cherry-picked. The text above
is the missingmed receipt and still stands as D4's contract: an accepted likelihood survives a covariance-stage failure
as evidence in a typed public failure, internal MBCO nulls may retain it after checks, and the public payload is not a
successful `SEMFit`. Both D4 review items that were open are pinned by tests here, and the independent review of D4 is
still owed (this slice is not closed by its own tests).

Changed to fit the merged design: field `ledger` (D4's `outcome`, `diagnostics$outcome` and `err$outcome` are gone; the
error has `$ledger` and `$partial$ledger`, the same node); no `medfit_sem_unresolved` (not on `dev`); the node is built
by the one path a success uses (`.sem_fit_context()` then `.sem_outcome()` then compaction), so `ledger$context` equals
the fit's (rows kept, resolved domain; the fixture with an NA row and an all-NA column catches a raw-data context);
sample stored once with `sample_hash`; `$post_fit` is only added to a node that failed (a NULL element would change
`identical()` of every stored ledger); `.sem_require_outcome(partial = TRUE)` admits the node only for the typed failure,
and a returned fit or a `SEMFit` with `post_fit` is refused with `medfit_error_ledger`; a malformed payload and an
incompatible retained null are refused with `medfit_error_ledger` (not a plain error), so `mbco_sem()` re-signals them
instead of wrapping them as a failed refit; the P3 `branch_map` validator is untouched. The pre-covariance gate is
"optimizer accepted and `f` finite": otherwise the original error stands (with its ledger saying the likelihood is
unavailable). Not taken: the keep-branch deletions of 0.14.0 content, D4's NEWS/.STATUS/AGENTS.md lines.

Decisions for the author:

1. Class: `medfit_sem_covariance_error` is a SIBLING of `medfit_error_no_convergence`, not a refinement. The optimizer
   did converge, so "no convergence" would be false, and a refinement would be caught by the D-11 handlers in
   `mbco_sem()` and `compare_lr()`, which report an unresolved result and so would bypass the checked retention.
2. MBCO: a null whose covariance stage failed is RETAINED (resolved row, same statistic and p-value, one warning, node
   marked `failed` with `post_fit` and notices), not unresolved and not an error. The statistic needs the likelihood
   only. The alternative (unresolved) would discard evidence D4 exists to keep. A full fit with this failure cannot be
   the `object` of `mbco_sem()` (it is an error, not a `SEMFit`).
3. Message: the typed error keeps the original condition's message (D-12: messages unchanged); "covariance-stage failure"
   appears in the retention warning, not the error text. D4 prefixed the error text.
4. Union root: reports the first failing branch's `post_fit` in branch order (D4's conservative rule), even when another
   branch is the minimum; the validator rejects a root that reattributes or drops it. A branch that did not converge
   still raises `medfit_error_no_convergence` first (D-11 outranks D4).

Evidence on `dev`: `test-sem-post-fit.R` written first and run on unmodified `R/` (red: no covariance evidence, the
typed class absent, the raw-data context mismatch), then green (12 tests, 212 expectations). Mutants, each failing named
tests: no branch-notice merge for a retained branch (3 tests: nested covariance failures, nonwinning attribution,
nested null losing-child notice); no `retained` merge in the MBCO null (1 test: singular-information warning kept);
root `post_fit` attributed to the winner (3 tests). The nonwinning-child controls run both product orders
(`a1*b1`, `b1*a1`) and both nulls. Stored known answers, P1 to P3 controls, `test-sem-unresolved.R`,
`test-sem-edge-grid.R` and the SE oracles (`test-effect-se.R`, `test-sem-se-pinned.R`, `test-sem-mbco.R`,
`test-compare-lr.R`, `test-sem-anova.R`) are unchanged and green.
