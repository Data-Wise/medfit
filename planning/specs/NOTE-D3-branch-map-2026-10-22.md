# D3 — duplicate maps and raw cap

## Optional public/formatting follow-up

On base `08e2dc2`, addressed both low concerns from Claude closure b6e11cec
(approved D3; read original C5/3c/3d/items8-10). Public stored-data controls now
assert exact canonical IDs, counts and duplication on `fit_sem`; full and both
nested MBCO null ledgers retain maps, IDs and successful minima. Every root map
field and a child map are forged on a SEMFit and refused by `mbco_sem`. A forged
nested null map refuses with its rejected evidence and no p-value.

Finite count messages use non-scientific formatting, counts above 2^53 are
conservatively marked approximate, and overflow is named. Numeric metadata and
the 64-RAW policy are unchanged. Independent literal message oracles include
128, 2^40, 2^60 and overflow. Initial tests failed at the unmarked huge count and
overflow wording; the nested injection also needed to ignore internal NULL-model
calls (test harness only). Public success/mapping controls already passed.

570 dependency assertions (=394 existing +176 D3) +816 consumer =1386 pass with
zero failures/errors/warnings. Changed source/test files and consumer tests lint
clean. Generated help inspected; fixture blob remains
`13b372d9fcf182dbbeae5b426621cedc2a9dd276`. No installs, simulations, saved-result
changes, push or merge; no full package check or stochastic vignette execution.
Claude0a653f34 approves this follow-up with no confirmed bugs (Sonnet5.5, medium,
13 turns, 279865 tokens, $0.2147303, 62399ms). Raw review retained in caller
docs/specs/D3-public-format-claude-review-2026-10-22.json. It read changed diffs
and relevant validator/MBCO bodies but omitted approved spec/proposal, the full
new test body beyond the diff, `.sem_as_semfit`, `.sem_rebase_outcome`, and suites.
Thus latest-diff spec conformance is not independently closed; prior b6e11cec
read original clauses for the base D3 commit. No automatic retry.

Three optional observations: exhaustive nested per-field/child tampering and
formatting exactly at/just above 2^53/non-powers are deferred test hardening,
not confirmed failures. The single-start concern does not justify seeding or
mocking away this API test: it already uses the existing known-convergent stored
fixture, n_starts=1 and a random-retry trap; real convergence is required by the
public route. This is bounded local evidence, not cross-platform guarantees.
No implementation changes after review. Earlier counts below are history.
T5 UNACCEPTED; D4/D5 and real-case evidence remain open.

Base: D2 `a11c63b`, carrying pinned D1 `8d7d6c1`. Branch:
`codex/medfit-d3-branch-map`. No dependency installation or consumer integration.

## Approved contract and evidence

The approved missingmed dependency proposal D3 (lines108–130) is authoritative;
the original approved provider spec is unchanged. T5 remains UNACCEPTED.

* `.sem_raw_count`: pure 63/64/65 controls and 2^2000 overflow. Multiplication
  checks overflow before each step. Branch admission uses raw parser factor
  counts, never the number of unique restriction sets.
* `.sem_branch_map`: admitted rows retain length-prefixed structural IDs of
  sorted, distinct parsed constraint rows. No affine solving or subsumption.
  Duplicate/permuted products and repeated-factor parsing are controlled.
* Injected leaf payloads on the unchanged stored memory dataset exercise 32/64
  raw rows, exact full execution order, first tied winner, a separate varying
  objective minimum, and three unique sets despite many duplicate raw rows.
  Injected objectives are control payloads, not scientific results/real cases.
* 128 raw combinations and overflow refuse with zero fit calls and a grid
  allocation trap. Both retain counts, unknown unique count, no children or
  raw mapping, and `not_enumerated` state in typed unresolved conditions.
* Validator reconstructs mappings; forged IDs refuse. Existing D1/D2 public and
  nested ledger regression tests remain in the bounded runner.

Initial new tests failed because helpers were absent (RED). Harness repairs:
corrected reversed-factor raw-row expectation, used the existing `model` SE
mode (not nonexistent `standard`), and replaced shared superassignment with an
explicit environment. These were test setup errors, not fitter defects.

## Verification

484 dependency assertions =45 stored branch/MBCO +104 expression +160 outcome
+85 literal-certificate +90 D3. 816 consumer assertions =95 encoding +126
provider +595 acceptance. All pass with zero failures/errors/warnings.
Four changed code/test files lint clean after source-loading the namespace;
three consumer test files lint clean. Generated `fit_sem.Rd` updated/read;
R/README/man/vignette search found no other stale cap guidance. Diff check clean.
Stored memory fixture Git blob remains `13b372d9fcf182dbbeae5b426621cedc2a9dd276`.
Runs use `n_starts=1` and prohibit randomized retry generation. No full package
check or vignette execution: those exceed the install/stochastic-work boundary.

One read-only Claude review b0735071 (`claude-sonnet-5-5`, medium, 8 turns,
263112 tokens, $0.2535686) returned needs-attention, no ship-blocking code defect.
Raw result with usage/scope: caller docs/specs/D3-claude-review-2026-10-22.json.
Claude read approved D3, full initial D3 tests, actual changed source/docs and
parser helpers. It omitted original spec C5/3c/3d/items8-10, full existing test
bodies, fixture contents, mbco_sem and other callers. No automatic retry.

## Post-review dispositions (retested, not independently re-reviewed)

1. Confirmed evidence gap: added single-product factor reversal with explicit
   raw-row bijection, digit-bearing distinct labels, overlapping products,
   unique counts and tampering of every map field. These controls are not a
   mathematical proof against every conceivable encoding collision.
2. Added multi-factor 63/64/65/72 and finite-large 2^40 cases; integer/double/Inf
   refusal metadata and exact messages pinned. 63/65 are pure cardinality tests,
   as approved; parsed execution is 32/64/128, not an expanded execution policy.
3. Added non-first minima tied across duplicate-canonical rows, full forwarded
   argument and rhs assertions. Existing varying minimum remains separate.
4. Confirmed regression: `.sem_outcome` with malformed `a* == 0` threw while
   constructing the map, masking the original error. New test failed before
   repair. A guarded unavailable map now retains its condition while preserving
   the original typed fit error; validator rejects malformed evidence.

Codex reread omitted original clauses: C5 preserved through guarded error and
existing notice tests; 3c duplicate/cap controls above plus existing public/nested
outcome regressions. 3d/items9-10 unchanged; 816 consumer regressions include
independent encoding/df controls. This is owner tracing, NOT Claude closure of
those omissions, D4/D5 integration, full package QA or real-case evidence.
D4/D5 and real-case evidence remain open. No installs, simulations, saved-result
changes, push or merge.

## Reconciliation on dev (P3, 2026-10-25)

Everything above describes D3 as written against 0.12.0, before #300, #303 and the P1/P2 ledger. P3 re-derived it on
0.14.0 `dev` on top of the merged D1 ledger (P1, #336) and D2 certificates (P2, #338) under ADR D-11 and D-12; the
receipts above are history, the table is what shipped.

| missingmed D3 | medfit `dev` (P3) |
|---|---|
| `fit@diagnostics$outcome`, `err$outcome` | field `ledger` (`fit@diagnostics$ledger`, `err$ledger`, `mbco_sem()$ledger`) |
| typed `medfit_sem_unresolved` on the over-cap refusal | unchanged plain error carrying `$ledger`; the over-cap node is not a D-11 convergence failure, nothing was attempted |
| forged map refused as unresolved evidence | refused through `.sem_valid_outcome()`, so `mbco_sem()` stops with `medfit_error_ledger` (own class, never an optimizer failure) |
| `rejected` node `$rejected_evidence` under `mbco/null:i` | the refusal is the error's own `$ledger$rejected_evidence` (P1 `.sem_require_outcome()`) |
| sample on every node (`$sample`) | sample once on the root; the validator reads `[["sample"]]` and `.sem_node_sample()`; the map needs no sample |
| `.sem_outcome()` without a union flag | `branch_map` is built in `.sem_outcome()` for every node (constraints only); P2's `union=` flag is untouched |
| over-cap check ran before D2 | over-cap is checked first and nothing else runs: no literal certificate is tried (decision below) |
| `.sem_fit_branches()` grid allocated first | raw count first, grid second, so overflow never allocates |

Kept from D3 as written: `.sem_raw_count` (integer to `.Machine$integer.max`, then double, `Inf` on overflow),
`.sem_branch_grid`, `.sem_branch_map` (length-prefixed structural IDs, `not_enumerated` over the cap, `unavailable` with
the retained condition when a malformed product row would otherwise mask the original error), the refusal wording
(no scientific notation, `approximately` above 2^53, `overflow (Inf)`), and the controls (63/64/65/72/2^40 counts,
32/64/128 parsed grids with exact execution order and ties, forged map fields, digit-bearing labels, overlapping
products, public fit and nested MBCO propagation). New on `dev`: a map is rebuilt from each node's own constraints
(a map from other constraints and a map on a node without products are refused), a map survives sample compaction, and
the over-cap decision control.

Not taken: D4 text, the keep-branch deletions of 0.14.0 content, and the original NEWS/.STATUS lines (re-written for
`dev`).

Decision for the author (over-cap and D2): an over-cap model (more than 64 raw combinations) does not run the literal
zero/nonzero check. The cap is a property of the raw grid, so a model that D2 could have thinned (`a1 == 1` with many
`a1 * b1 == 0` rows) is still refused: nothing is enumerated, no branch is fitted, no certificate is built, and the
ledger carries the `not_enumerated` map. The alternative (run the check on the raw grid to shrink it) would enumerate
before the cap is applied, which is what the cap prevents, and would let a product count of 2^40 cost time. Pinned by
`test-sem-branch-map.R` ("over-cap refusal is decided by the raw count alone"), including a trap that fails if
`.sem_literal_zero_certificate()` is called.

Evidence on `dev`: `test-sem-branch-map.R` red first (helpers absent, maps `NULL`), then green; mutants: validator
without the map check (21 failures), 2^53 threshold moved to 2^60 (1 failure). Dropping the overflow guard in
`.sem_raw_count` is an equivalent mutant (double multiplication already yields `Inf`). Stored known answers, the P1
and P2 controls, `test-sem-unresolved.R`, `test-sem-edge-grid.R` and `test-sem-branches.R` are unchanged and green.
