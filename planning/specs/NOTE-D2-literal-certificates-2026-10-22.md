# D2 literal zero/nonzero certificates — 2026-10-22

Authorized slice only, from pinned D1 8d7d6c14e038b8f41d9e1bbe37a4e74bf54b404f.
Branch codex/medfit-d2-literal-certificates in the existing isolated worktree.
T5 remains UNACCEPTED. No D3-D5 implementation, installs, simulations, saved
result changes, push or merge. Existing libraries unchanged; tests source-load
this worktree, not the stale check-folder installation.

## Contract and implementation

Approved dependency design: missingmed/docs/specs/
PROPOSAL-T5-medfit-evidence-contract-2026-10-22.md, D2 (lines 84-106).
This authorization narrows initial proof scope to explicit literal zero/nonzero
contradictions only, not bounds or general affine solving. An explicit zero
equality on a parsed parameter label must conflict with a finite nonzero literal
equality in the identical domain. Fixed parameter-table values are not proof premises: public syntax cannot combine a fixed modifier and label. No expression
evaluation, tolerance, optimizer text, numerical rank or solver status is proof.
Underflowed nonzero literals are unknown, never treated as zero proof premises.

Certificates store method, label, source rows and values; the ledger retains
constraints and parsed parameters. They are reconstructed during validation.
A certified-empty child is retained, not optimized, with excluded outcome and
unavailable likelihood. Same sample/domain/settings and parameter provenance
are checked against its parent. A union returns a minimum only if at least one
branch resolves and every other branch resolves or has a valid certificate.
All-empty unions raise medfit_sem_empty_union. Direct infeasible models raise
medfit_sem_infeasible. Both inherit medfit_sem_unresolved. Top-level MBCO null
failure remains explicit, with no finite substitute LR or survivor-only p-value.

## Deterministic evidence

New test-sem-literal-certificates.R: 60 assertions, stored memory_exp.rds and
injected failures only. Exact/signed/reversed literals, underflow, refusal of forged fixed-parameter
premises, feasible/unknown/bounds cases, both branch orders, skipped empty child,
matched direct sibling objective, all-empty typed failure, ordinary null failure,
nested public MBCO propagation and tampered certificate/domain evidence.
Proof-removal control refuses; unknown-as-empty validator mutant fails its
intended assertion. D1's survivor-success mutation updated for the new guard.

Runner /private/tmp/medfit-d1.3jrA2K/run-deterministic.R allows only the inspected
stored-data branch/MBCO bodies, expression tests, D1 outcomes and new D2 file.
n_starts=1, random retries forbidden. 45 stored branch/MBCO +104 expression
+160 D1 +60 D2 =369 assertions pass, zero unexpected warnings/errors/failures.
Missingmed's run-consumer-assertions.R source-loading this worktree passes
95 encoding +126 provider +595 acceptance =816 assertions. Combined 1185.
Six modified R/test files lint clean under source-loaded namespace; generated
fit_sem/mbco_sem Rd parse clean. No full R CMD check or vignette render: those
can install or execute prohibited stochastic examples.
Stored fixture Git hash equals pinned D1: 13b372d9fcf182dbbeae5b426621cedc2a9dd276.

## Failed approaches and repairs

Initial tests failed on absent detector and D1 survivor refusal, as intended.
First integration attempt lost parsed parameter evidence at the public wrapper
and left excluded-node settings unnormalized; preserve parsed premises and bind
certificate context to the successful sibling's actual comparison context.
Malformed legacy evidence initially reached literal parsing and emitted warnings;
non-data-frame evidence now returns unknown immediately. Existing D1 mutation
target was updated to the new guard expression, not bypassed or disabled.

## Claude review and dispositions

One authorized Claude Sonnet review, job ca1aef5c-d3f2-467b-8ee4-2aefc0605741,
returned needs-attention (11 turns, no budget exhaustion). Raw result:
D2-claude-review-2026-10-22.json. Four concerns were addressed locally:

1. Consistent parent/child parameter-table forgery could supply a fixed-value premise.
2. That premise is unreachable through public syntax. Removed it rather than expanding syntax;
   only explicit literal equalities now supply values. Added consistent-forgery refusal.
3. Replaced the vacuous null p-value assertion with error/non-htest, no-test-result,
   and certified-empty nested-null evidence assertions.
4. Guarded the empty resolved-child set before min(); malformed all-excluded/resolved
   parents now refuse without warnings, tested explicitly.

Claude did not open the cross-root approved proposal/spec, modified D1 mutation body,
generated docs or runner; this is not full-spec independent sign-off. Codex traced
the approved D2 PASS paragraph: exact exclusion plus matched sibling, feasible/unknown
cases, all-empty union, domain provenance, nested/public failure and mutation refusal
are covered in test-sem-literal-certificates.R. Bounds/affine certificates are explicitly
deferred under the approved permission to narrow initial scope. Post-review repairs
are deterministically retested, not independently re-reviewed; no automatic retry.
Real-case improper-null evidence remains absent; literal examples do not close P3/T5.

## Explicit null attribution follow-up — 2026-10-22

Tests only; fitter and certificate implementation unchanged from d9ace70.
The failed public null is now identified as mbco/null:1 with parent mbco,
exact model syntax including a1 == 0, unresolved outcome, unavailable likelihood,
and complete enumeration of two children. Each excluded child has a validated
certificate for a1 and the exact rebased id/parent. Successful a2/cp nulls also
validate their nested certificate and rebased identities.

This fixture's null is an all-empty union, not a certified-empty leaf: product
enumeration precedes the ordinary certificate check. The prior broad predicate
was not vacuous (the resolved full-fit sibling prevents all-excluded status),
but explicit indexing makes attribution unambiguous. Wrong-node, missing-proof
and dropped-child in-memory ledger mutations fail the intended assertions.
They are assertion-discrimination controls, not additional source-level guard
mutations; existing producer/validator mutation controls retain their scope.
No stored input or saved scientific result was mutated.

Deterministic suite: 85 D2 +160 D1 +104 expressions +45 stored branch/MBCO
=394 dependency assertions; consumer 95 encoding +126 provider +595 acceptance
=816; total 1210, zero failures/errors/warnings. Changed test and three consumer
test files lint clean. Stored memory_exp.rds hash still equals pinned D1.
Source-loaded existing library only, n_starts=1 and random retries forbidden.
No full R CMD check, vignette execution, installs, simulations or saved-result changes.

Claude job 424e4da7-27eb-444d-9f01-2aac17ce4d87 approves with no findings.
It read the full D2 test, relevant source, changed D1 mutation, generated D2 help,
approved D2 proposal and C5/3c/3d/test items 8-10. It independently agrees the old
predicate was not vacuous and the new explicit null checks close attribution.
It skipped prior raw review/disposition, prior NOTE, roxygen/vignette, full D1
tests and D4 consumer code. Medium uncertainty; no full consumer or D4/df
sign-off. Optional source-level null-certificate-drop mutation not pursued.
Its phrase "mutate saved data" refers to local in-memory ledger copies, not files.

Raw review and complete usage/coverage/session metadata are preserved in
missingmed/docs/specs/D2-null-attribution-claude-review-2026-10-22.json.
Requested sonnet/effective claude-sonnet-5-5, 11 turns, 283870 tokens, 7774 output,
54957 ms, $0.2492667. Evidence Lease null/not exhausted; cost and turn limits
not exhausted. No automatic resume or follow-up review. T5 UNACCEPTED;
D3-D5 and qualifying real-case evidence remain open. No push or merge.

## Reconciliation on dev (P2, 2026-10-25)

Everything above describes D2 as written against 0.12.0, before #300, #303 and the P1 ledger. P2 re-derived it on 0.14.0
`dev` on top of the merged D1 ledger (P1, #336) under ADR D-11 and D-12; the receipts above are history, the
differences below are the contract on `dev`. The certificate itself (`.sem_literal_zero_certificate()`) is unchanged
in meaning: an explicit `label == 0` and an explicit finite nonzero literal equality on the same parsed label, nothing
else (no tolerance, solver status, bounds, rank or fixed-table value).

| D2 as received (0.12.0) | On dev |
|---|---|
| Typed errors inherit `medfit_sem_unresolved` | `medfit_sem_infeasible` and `medfit_sem_empty_union` are refinements of `medfit_error_no_convergence` (class vector `c(<typed>, "medfit_error_no_convergence", "error", "condition")`), so `mbco_sem()` and `compare_lr()` still catch them as unresolved (D-11) |
| Evidence at `err$outcome`, `fit@diagnostics$outcome` | `err$ledger`, `fit@diagnostics$ledger` (P1's field name) |
| Top-level MBCO null that is an all-empty union: an error, no p-value | #300's unresolved result: NA statistic and p-value, `unresolved` TRUE, one warning, the complete ledger on `$ledger`; no finite substitute LR and no survivor-only p-value |
| Excluded node's context was bound to the winner's context by overwriting `outcome$context` | An excluded child takes the winner's context in `.sem_fit_branches()`; on compaction it carries `context$sample_hash` like any child on the same rows and resolves only through `.sem_node_sample()` (tests use `[["sample"]]`, never `$sample`) |
| Wrapper kept the parsed table by copying it from `err$outcome` / `out$outcome` | `.sem_fit_syntax()` and `.sem_reraise_outcome()` keep `context$model$parameters` of a ledger made below, since the entry's context (called with syntax) has none; certificates are checked against it |
| Message gained a `Retained notices:` suffix | Messages unchanged (`no branch of the zero-product constraints converged`, the `N of M ... did not converge` text; a certified branch is listed as `literal zero/nonzero contradiction`); notices live in the ledger only |
| Typed class chosen in `.sem_abort_outcome()` from the node | Same rule, passed to `.sem_no_convergence(subclass = )`; `.sem_reraise_outcome()` re-raises the original condition for every class, so the subclass survives the wrapper |
| `.sem_valid_outcome()` minimum over all children | Minimum over resolved children only, and at least one must exist; a parent whose children are all excluded is refused without a warning |

Not ported here (P3, P4): D3 (branch map and raw cap) and D4 (covariance-stage evidence, `medfit_sem_covariance_error`).

A skipped branch that is not certified still ends in the D-11 error (a failure is unknown, never an exclusion), and the
survivor-success mutant of `test-sem-outcomes.R` (removing the `if (length(skipped))` guard) is unchanged. The
`.sem_valid_outcome()` check that parent and child share `context$model$parameters` now applies to every child.
Mutants in `test-sem-literal-certificates.R`: unknown-as-empty validator, proof removal, a tolerance for exact zero,
and a solver failure substituted for the proof; each fails its intended control.
