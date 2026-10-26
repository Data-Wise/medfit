# D1 outcome ledger: implementation and review scope

Author authorized D1 only on 2026-10-22 following approval of the bounded dependency
design in missingmed's `docs/specs/PROPOSAL-T5-medfit-evidence-contract-2026-10-22.md`.
Base: local `origin/dev` 505e8ed, medfit 0.12.0, isolated branch
`codex/medfit-d1-outcome-ledger`. Existing medfit checkout is untouched.
T5 remains UNACCEPTED. No installs, simulations, saved-result changes or merge.

## Approved D1 contract (review all clauses)

Versioned public full/null/nested records must retain stable IDs/parents, exact
constraints, estimation sample/model/likelihood-domain context, optimizer and
acceptance state, finite likelihood availability, feasibility, covariance,
improper/identification notices and original condition class/message. Enumeration
completeness is separate from within-branch optimality; no globality certificate.

Any unresolved required branch prevents ordinary successful inference. Typed
errors retain the ledger and any best-survivor diagnostic, never a survivor
p-value. Attempt every bounded required null even after another fails. Preserve
clean starts, solver, all-row acceptance and original constraints.

Required D1 controls: both partial-failure orderings, counterfactual LR 1 versus
survivor 9, all-success minimum, all-failure, missing/malformed ledger refusal,
public full-fit and nested input/refit failure propagation, intended-assertion
survivor-success/status-drop/label-swap mutants and unchanged stored known answers.

## Approved migration spec coverage and exclusions

Owning approved spec is missingmed
`docs/specs/SPEC-lavaan-mbco-on-mbco-sem-2026-10-16.md`, SHA256
`b933e60601f4c95dcd763af0c98e0491c20ccac8cef5007451a6a441034469bc`.
Its section 3c requires per-branch full/refit/provider/public propagation;
distinguishes infeasibility, unresolved optimization, post-fit diagnostic failure
and accepted likelihood; forbids completeness inferred from convergence;
requires both failure orderings and hidden potentially better LR 1 versus 9.
Section 4.8 requires public/nested propagation and survivor-success defects.
Section 3d/4.10 requires labeled diagnostic checks because symmetric statistic
checks can miss swapped labels. C5/3 requires retained branch warning evidence.

D1 implements only the dependency ledger/public seams of these clauses, NOT full
T5 acceptance. D2 proof-producing exclusions, D3 preallocation count/dedup evidence,
D4 escaping covariance-stage payload/recovery and D5 missingmed integration remain
separately gated. Basic over-cap error records `not_enumerated`; the existing
post-allocation cap is NOT fixed here. Errors before returned optimizer evidence
remain unknown, not falsely classified as covariance-only or infeasible.
NA covariance warnings retain the existing return behavior, not a new permission.
The real pre-existing stored improper-null fixture and final cross-package frozen
review remain open. No LR tolerance, df, ARIV, model syntax or dependency-floor change.

## Deterministic verification protocol

Use existing libraries with `R_LIBS=/private/tmp/claude-501/medfit-lib2` and load
this worktree with pkgload; never install it. `test-sem-outcomes.R` uses the
pre-existing memory_exp fixture, single-start fits and injected failures. The
initial red run demonstrated missing public ledgers and survivor/early-abort gaps.
Existing random/sample-generating files are not run wholesale. A bounded runner
will select only explicitly inspected stored-data existing test bodies and pure
expression controls; perturbed starts are forbidden in that runner.

Review request: inspect this entire D1 diff against each contract above; trace
all error/public/nested paths and tests, especially malformed evidence, lost
notices, wrong branch attribution and false completeness. Report findings and
explicit omitted clauses; do not modify files or run random suites. Do not
interpret D2-D5/T5 omissions as D1 completion. Standard bounded Claude review,
no automatic retry/resume. Verification counts and review disposition follow.

## Verification results and remaining limits

- 111 focused D1 assertions (11 bodies), 44 selected existing stored-input
  branch/MBCO assertions (10 bodies), 104 pure expression assertions (12 bodies):
  **259 passed, zero failures/errors/skips**. All fitting used single starts;
  `.sem_perturbed_starts` was replaced by an error to forbid random retries.
- Four new intended-assertion mutant executions: survivor-success in both
  orderings, public outcome drop, and a/b label swap. Survivor-success is a
  composite mutation that also bypasses the independent consumer validator;
  otherwise that validator correctly stops the deliberately forged completion.
- Clean starts, equality/contradictory all-row checks and a nonlinear equality
  were exercised on stored data. This is not the full randomized native gate
  suite or a coverage percentage claim; prohibited suites remain unrun.
- Existing numerical answers 221.045546, 0.083100 and 0.060332 retain their
  original absolute 1e-6 comparison. No tolerance was changed. The stored
  memory_exp fixture SHA256 is unchanged versus base:
  `ec778dc6503cb6ad0351b0dd8ce47b03c3e16ad0f67212512b263aa1f2acdccd`.
- Roxygen generated four changed help files; six touched R/test files have no
  lints, four changed Rd topics pass `tools::checkRd`, and diff whitespace passes.
  The computation article was updated but not rendered (no example execution).
- Restricted package check: 0 errors, 1 warning, 0 notes, with tests/examples/
  vignettes/manual disabled. Warning is undeclared `rlang::` usage in the
  pre-existing `R/compare-lr.R`, not changed here; DESCRIPTION already omitted it
  at base. Do not call this a clean check. No dependency fix was made.

### No-install scope deviation

Codex launched that restricted package check, overlooking that R CMD check
installs the project into its temporary check library. It created medfit only
under `/private/tmp/medfit-d1.3jrA2K/check/medfit.Rcheck`; no dependency installation
or existing R library was changed. This was disclosed to the author and must not
be repeated under the current no-installs instruction. Use pkgload/static checks
instead. Existing installed 0.11.1 `.rdb`/`.rdx` hashes remain identical to the
approved inventory. Check artifacts remain isolated in this task's temp folder.

### Claude review and disposition

One read-only standard review, job `8159dadc-32c8-44a3-8d84-ccb6caa426e1`,
session `56e38358-be0d-4a15-8d10-f6ebee367289`, requested `sonnet`, effective
`claude-sonnet-5-5`, medium effort. Fingerprint
`6a9c508f563dae76c8fda0251c658bca30ae65da40db7d3075105fa051b82983`.
Completed in 27,924 ms (API 27,207), 7 turns, 177,276 total tokens (3,498 output),
$0.1481998; no cost/turn exhaustion, no evidence lease, no reported context drift.
No retry, resume, fallback or follow-up review was run.

Verdict `approve`, explicitly **partial**, medium uncertainty: examined
sem-fit, sem-mbco, fit-sem, sem-outcomes and sem-optim. Skipped the new tests,
NEWS, classes/syntax help, generated Rd, computation article and this contract
receipt. Therefore it did NOT complete clause-by-clause spec/test coverage and
is NOT a final D1 or T5 acceptance verdict.

One low finding (confidence 0.4): failing fits retain warnings/messages only in
the ledger, so a plain error can hide useful notices. Confirmed and fixed after
the review: typed error messages now summarize retained notices, with original
records preserved; both branch orderings test the summary. These edits were not
Claude-reviewed. Post-review hardening also validates domain/settings/sample and
reconstructs required child restriction sets to reject forged/drop-child ledgers;
factor maps propagate into branches. Tests cover attributed sample data, fixed-x,
factor unions, altered domains and missing children. All 259 assertions and lint
checks were rerun afterward. These hardening edits are likewise unreviewed.

At that checkpoint, next was author authorization for a focused Claude test/spec/post-review-diff pass,
with explicit omitted-clause disposition. D1 is implemented and deterministically
verified locally, but independent review coverage remains incomplete. D2-D5 and
the real stored improper-null gate remain open; **T5 UNACCEPTED**.

## Authorized focused review and follow-up — 2026-10-22

One read-only standard adversarial plugin review of committed `06b2ca9`, base
`505e8edcaf83c2260fbf9dabbcc15e9785620de7`, job
`6b6a1736-0258-4d21-8f85-6cd23b8644cd`, session
`88919597-6853-4db6-99f9-f5d9bda98657`. Fingerprint
`fd392677cfc46ae647393ff95cf1f87f2ed91b52e5953abcdd8d7c984561b498`.
Requested/effective sonnet / claude-sonnet-5-5, medium; 224,145 total tokens
(8,982 output), 8 turns, 72,481 ms (API 71,829), $0.2615716.
No Evidence Lease, lease/cost/turn exhaustion, reported drift, retry, resume,
fallback or automatic second review.

Verdict **approve, no D1 blocker**, static only, medium uncertainty. Read the
entire receipt, all 11 focused test bodies, sem-outcomes in full, and diffs of
sem-fit/sem-mbco/fit-sem, including the prior post-review fixes. Read owning
spec around section 3c (reported lines 108–177). Its summary says 3d was not
directly read although the coverage list says 3c/3d; conservatively do not credit
direct 3d coverage. It explicitly skipped PROPOSAL-T5 and direct C5/3, 4.8/4.10
source reading, using this receipt instead. Also skipped unchanged optimizer,
zero-product/boundary helpers, classes/syntax help, NEWS/status, generated help
and article. It executed nothing and did not independently verify test counts,
fixture hashes or numeric receipts. **Complete independent spec coverage remains
OPEN despite the approval label.** Codex read the owning spec and proposal in
this follow-up; that does not substitute for omitted independent review.

| Approved requirement | Focused review evidence and remaining boundary |
|---|---|
| 3c full/null/nested propagation, both partial orderings, all-failure | Traced fit wrappers, branch loop, public converter and MBCO; tests named `neither partial-failure ordering...`, `MBCO attempts every null...`, `all-failure...`. |
| 3c successful minimum and hidden 1 versus survivor 9 | `public fits and MBCO...` and `survivor-success...`; 9 is injected and 1 is a counterfactual mock message, not a fitted hidden optimum. |
| 3c missing/malformed evidence, enumeration versus optimum | Strict validator and tests `missing, malformed...`, `public consumers reject...`, `sample attributes...`; count reconstructed rather than copied; no globality certificate. |
| 4.8 survivor mutation, public/nested route | Actual test bodies inspected; composite survivor mutation bypasses the independent validator explicitly. Direct owning 4.8 source inspection omitted. |
| 3d/4.10 labels | Syntax-swap refusal and labeled-output mutant inspected; direct source coverage incomplete. No D4/df changes or full 3d closure claim. |
| C5/3 notices | Attributed child notice retention traced; findings/dispositions below. Direct owning source inspection omitted. |
| Broader 3c covariance/exclusion/cap controls | Returned NA-covariance warning control inspected; escaping-stage distinction D4, proved exclusion D2, preallocation/duplicates D3 remain open. |
| Provider/MI public integration and genuine improper null | D5 and P3 remain open; this dependency review cannot accept T5. |

Three low findings, independently dispositioned:

1. **Root union notices empty** (confidence 0.5). Not loss of branch evidence:
   children retain each branch's original notices; only the winner is replayed.
   Retain attributed child records rather than duplicate/flatten them at root.
   Documented that traversal contract in fit_sem help; new union warning control
   pins empty root and retained notices on both children. Root-only consumers
   must not interpret an empty list as absence of descendant warnings.
2. **MBCO typed-error summary untested** (0.45). Confirmed coverage gap. Added
   warning-before-error injections for a-only, b-only and both failures; assert
   message summaries and exact attributed warning records. Existing behavior
   passes. Generic nested summary wording remains; typed recursive IDs and exact
   constraints retain provenance, and the top-level message identifies its null.
3. **Sample duplication risk / unchecked child objective** (0.4). No memory or
   serialization measurement supports a quantified cost; R sharing means source
   references do not prove eager independent copies. Defer sample-storage redesign
   (would alter the approved exact-context schema). The independent child-objective
   consistency issue was confirmed: finite child values below the parent, or all
   above it, passed public inference. Two regression assertions failed with zero
   execution errors before the fix. Validator now requires exact parent f equals
   minimum resolved child f (copied values, no new numerical tolerance).

Final follow-up: **273 deterministic assertions pass**: 124 focused (11 bodies),
45 selected stored-input branch/MBCO (10 bodies), 104 pure expression (12 bodies).
Focused file: zero failures/errors/unexpected warnings/skips. The older larger-
branch mutant initially escaped as a typed error under the new guard; its test
now asserts that refusal, then explicitly bypasses the guard only for the
original wrong-number assertions. Final selected run has zero failures/errors.
An initial test-edit ordering error was corrected before the two intended red
assertions were established; it is not counted as defect evidence.
Four touched R/test files lint clean; fit_sem Rd regenerated and checked;
whitespace passes. No R CMD check/install, simulation, saved-result change,
push or merge in this follow-up. Full randomized suites remain unrun.
These follow-up edits were **not Claude-reviewed**; no automatic review rerun.
T5 remains UNACCEPTED, with D2–D5, P3 and final independent review open.

## Findings verification and authorized rerun

Verified the three earlier findings: child-attributed union notices are retained;
MBCO-boundary notices can repeat winner-child records and are now documented;
sample duplication is a measured design cost, not a reason to silently alter the
approved exact-sample schema. Serializing existing stored data in memory used
12,237 bytes for one copy, 24,382 for two, and 777,372 for 64; these are raw
serialization measurements, not compressed full-fit size estimates.

Fixed a confirmed outer-pipeline notice loss on typed nested failures. A test
failed its two intended message assertions before the fix (and then errored on
the missing notice record). The survivor-success mutant now also verifies the
wrong returned LR equals 9 in both branch orderings.

Claude rerun job `324c1829-6ba6-4a7a-9938-283361fa7523`, session
`6fd6ffa6-363e-437b-a367-d00c6ce88628`, standard/medium, sonnet effective
claude-sonnet-5-5: needs-attention, medium uncertainty. 290,095 total tokens,
4,888 output, 12 turns, 37,989 ms, $0.2093331; no reported exhaustion.
Raw result: `/private/tmp/medfit-d1.3jrA2K/D1-review-followup-2026-10-22.json`.
It read the entire approved spec, closing direct C5/4.8/4.10 source omissions,
but only selected test bodies and sem-mbco lines 150–240; it skipped the dependency
proposal and full label/encoding test tracing. Independent clause-to-test coverage
therefore remains OPEN. Broader exclusion/cap controls belong to D2/D3; all-success
minimum controls already exist. The hidden LR=1 remains counterfactual injection,
not real-case evidence.

Post-review: corrected duplicated documentation prose and verified the reported
repeated `Retained notices:` summary (one intended red assertion: length 2 versus
1). Typed conditions now preserve base_message and rebuild one summary while
retaining inner and outer notices. These latest edits are NOT Claude-reviewed;
no automatic second review was run.

Final deterministic run: **281 assertions pass** (132 focused/12 bodies,
45 stored-input branch/MBCO/10 bodies, 104 expression/12 bodies), zero failures
or errors. Focused run has zero unexpected warnings; touched R/test lint and
mbco_sem Rd validation pass. No installs, simulations, saved-result edits, push
or merge. Full random suites unrun. T5 UNACCEPTED; P3 and review tracing open.

## Notice-path repair and clause tracing

Confirmed the typed MBCO-refit path dropped boundary-captured notices when an
error already supplied a matching ledger. Three intended assertions failed
(warning record, message record, public error text), then passed after appending
captured notices to the typed node. Existing inner records survive. The success
path was correct: a new union-input control pins replayed warnings at null roots
and retained children. Both actual union partial-failure orderings now assert
zero root warnings and exactly one attributed child warning. These tests use
stored input and injected conditions; no real improper-null claim.

Final: **295 deterministic assertions pass**: 146 focused/13 bodies,
45 selected stored branch/MBCO/10 bodies, 104 pure expression/12 bodies.
Zero failures/errors; focused zero unexpected warnings. Changed-file lint,
mbco_sem Rd and whitespace checks pass. Stored input and existing medfit library
hashes match the earlier recorded values. Full RNG suites and R CMD check unrun
under the current no-simulation/no-install limits. No installs, simulations,
saved-result edits, push or merge.

Codex completed the previously omitted converter and test-tail tracing:
R/fit-sem.R:123-169 calls/validates .sem_fit_syntax then requires the ledger
before copying it into public diagnostics. The final outcomes body rejects
changed information, altered child objectives and a dropped child despite a
forged required count; preserves sample attributes, factor and fixed-x contexts.
Strict validation R/sem-outcomes.R:89-149 reconstructs required restrictions and
checks accepted state, exact domain/settings and parent=min(children).

| Owning clause | Actual assertions traced | Boundary |
|---|---|---|
| C5 table line 34 and section 3 lines 60-70 | medfit outcomes bodies: public ledger, both partial orderings, nested null errors, full/all failures, covariance notices, typed boundary retention, outer notice retention. missingmed acceptance 242-255,454-489,498-540 assert full character payload, a/b/both identity, warning exactly once with dataset names, failures/drop counts through direct/infer and both ARIV modes. | D1 tests rerun; existing consumer tests read, not rerun against this D1 source; D5 open. |
| Section 4 item 8, lines 193-195 | Public converter propagation; outcomes first/partial/nested/full-failure/last bodies; survivor mutant LR9 in both orders; status-drop refusal; known-answer stored minimum controls. | LR1 is counterfactual injection, not observed hidden optimum. |
| Section 4 item 10, lines 199-202 | medfit label-swap mutation and null identity. missingmed acceptance142-175 pins loglik=-LR/2, stack(8,12)/K=4, own r4=0, fixed r4=3, D4=4/(1+r4), mixed=true, branch fraction .5, ties choose a, simultaneous swaps flip labels not numeric results, inconsistent k refuses in both modes. | Existing consumer expected-value assertions, not newly rerun guard-removal mutations or D5 integration. |

Consumer implementation read: missingmed R/mbco_sem.R:417-470 (provider,
collected warnings/diagnostic flags and -LR/2), R/mbco_mi.R:287-382
(dataset-named errors, once-only warnings, branch selection, stack/K and k).
Full Codex trace: `/private/tmp/medfit-d1.3jrA2K/D1-clause-trace-2026-10-22.md`.

One authorized plugin review job `60d5389c-6a0f-49f6-b82f-5e63491b4fa5`, session
`fe304d3d-c63c-491b-a386-f5437ac83695`, fingerprint
`adca4a90bd4c02c4d4ed9e3c622f5dbaa146fa495c886fb3af2401f8c808b762`.
Standard/medium, requested sonnet/effective claude-sonnet-5-5, 264131 tokens
(6033 output), 14 turns, 49234 ms (API48465), $0.2214613. No lease or cost/turn
exhaustion, drift, resume, fallback or second review. Initial overlong focus was
rejected by argument validation; shortened before any job started.
Raw result: `/private/tmp/medfit-d1.3jrA2K/D1-notice-review-2026-10-22.json`.

Verdict approve, no blocker, medium uncertainty, static only. Claude traced
the append/no-replay reasoning and public converter; read outcomes1-75,180-239,
sem-outcomes1-150, sem-fit1-40/255-340, consumer provider/pooling. It explicitly
omitted specs/proposal, man/roxygen, consumer acceptance tests, Codex map, and
outcomes75-180/240 onward including final body. Thus Codex clause tracing is
complete for this scope, but independent matrix sign-off remains OPEN.
Its sole low finding (confidence .35) concerns a future mismatched-syntax typed
node being rebuilt without its children. Current wrappers stamp/validate syntax;
not a demonstrated reachable defect, no speculative behavior change made.
Existing nested-failure controls do retain children; the new boundary test is
synthetic and does not certify all nested shapes. No automatic review retry.
D2-D5/P3 remain open; **T5 UNACCEPTED**.

## Matrix findings verified: D1 versus deferred scopes

1. Version skew: the floor remains >=0.10.0 and D1 ledger consumption is not
integrated. That is the approved D5 gap, not a confirmed current swallowed-union
bypass: .mm_sem_provider calls .mm_sem_complete_syntax BEFORE fitting; product
constraints and defined-product aliases were deterministically refused. Only
affine constraints are admitted. No dependency floor or syntax scope changed.
2. Pooling: an arbitrary invalid provider with full=0,a=1,b=2 reproduces D4=-2,p=1
in both modes. This is a documented internal provider-trust seam, not a public
SEM bypass: .mm_sem_lr validates both summaries before pooling, including losing
branches. No generic pooling/GLM behavior change is part of D1. Two selected
existing consumer tests verify both-branch negative/nonfinite refusal through
pooling and inclusive -1e-7 roundoff policy (23 assertions pass).
3. Duplicate/64 coverage: confirmed test gaps, no fitter defect. Added exactly64
raw public-fit success on stored input (six repeated binary products), distinct
positional IDs, parent=min(children), duplicate/arbitrary ID and duplicated-child
public refusal. Removing only ID validation lets the invalid ledger escape its
intended assertion; the mutant executes successfully before expect_failure.
These do not implement canonical unique-set IDs, deduplicated execution or
overflow-safe pre-grid admission. 63/65 pure counts remain approved D3 scope;
existing128 refusal remains. No production code changes in this follow-up.

**306 medfit assertions pass**: 157 focused/16 bodies,45 stored branch/MBCO/10,
104 expression/12. Plus23 consumer assertions/2 allow-listed existing bodies:
provider validates both branches and raw LR inclusive boundary. Total329, zero
failures/errors; focused zero unexpected warnings. An initial ad-hoc consumer
runner failed reporter file initialization before tests; adding start_file/end_file
fixed the runner. This is not defect evidence. Lint/Rd/whitespace pass. Fixture
and existing library hashes unchanged. No installs, simulations, saved-result
changes, push or merge; full random suite and D5 integration unrun.

One standard/medium read-only review: job21ecbeba-ec93-4623-8473-cab0347c5f77,
session743d7a3c-05dd-4292-939a-d4464d7930e6, basec8194aa, fingerprint
07a12077012225412b33c7088b289302004cfb24df9b4ec18100dbf47a501feb.
Requested sonnet/effective claude-sonnet-5-5,166412 tokens(4582 output),10 turns,
32504ms(API31986),$0.1531338. No Evidence Lease/cost/turn exhaustion, drift,
retry/resume/fallback. Verdict approve, findings[], no material D1 blocker,
medium uncertainty; static only. Read dispositions, validator/branch loop,
zero-product parser, changed tests and consumer admission/provider source.
Skipped consumer pooling code, provider tests, proposal and mutation-helper
internals: those dispositions are Codex-verified, not independently re-verified
by this run. Review optional ID-only control is already present (only child2$id
is changed in each of two public controls; separate duplicated-child control).
Its mention of D3 deduplication must NOT override approved preserve-execution
design; canonical mapping is deferred, deduplicated execution not authorized.
Raw result: /private/tmp/medfit-d1.3jrA2K/D1-scope-review-2026-10-22.json.
Detailed dispositions: /private/tmp/medfit-d1.3jrA2K/D1-finding-dispositions-2026-10-22.md.
D1 coverage strengthened; D2-D5 and genuine improper-null evidence remain open.
**T5 UNACCEPTED.**

## Assertion/tolerance concern verification (2026-10-22)

Confirmed the old header-count test accepted an absent header: gregexpr returns
-1 of length one. Replaced length with positive-match count, and explicit zero,
one and two-header controls; actual error must contain exactly one. No fitter
behavior changed. Consumer fixture has three cases with four expected fields
per mode; added nonempty case and exact expected-field guards to prevent vacuous
loops, and independently derived Chan-Meng nu from m/r4. Stored oracle checks
now demand <1e-8 branch error and null-b magnitude, tenfold margin below unchanged
1e-7 raw-LR policy. Existing T2 note already recorded empirical justification;
this is not a universal optimizer error guarantee or relative tolerance.

Class-only unresolved tests are valid refusal checks, not proof of each reason;
specific branch/dataset controls and existing executed mutants supply separate
coverage. No speculative message rewrite. NULL p.value on an error is not proof
of no inference and was not promoted as such. Suppressed-warning tests cover
ledger retention, not emission; separate notice/attribution controls cover
emission. Threshold bracketing remains intentional arithmetic-resolution testing,
not a claim of exact equality at a floating-point cutoff. D5 real-ledger consumer
propagation and dependency capability pinning remain deferred. No extra NULL
assertion added merely to satisfy the review's contradictory optional suggestion.

1055 deterministic assertions pass: 160 focused outcomes,45 stored branch/MBCO,
104 expressions,126 consumer provider,620 consumer acceptance. Zero failures,
errors or unexpected warnings in completed runs. Initial consumer runner had
duplicate .package forwarding at one acceptance body; corrected runner and reran
acceptance, not a production defect. Changed tests lint clean. No installs,
simulations, saved-result changes, push or merge; fixture/existing-library hashes
unchanged. Full stochastic suite and R CMD check unrun under user constraints.
T5 remains UNACCEPTED pending real-case evidence and D2-D5.

Claude follow-up job78641aac-4a2f-4536-a221-b4bf276b8ca7 approved consumer
changes with two low concerns (platform-sensitive empirical margin; positional
null-case selection). Added explicit null flag and remeasurement trigger after
review; provider retested, not independently re-reviewed. Reviewer skipped this
cross-root D1 diff/receipt and approved-spec/proposal clauses: no independent
closure claimed for those omissions. Standard/medium, requested sonnet/effective
claude-sonnet-5-5,7 turns,117321 tokens(3213 output),26538ms(API25890),$0.113405.
No lease/cost/turn exhaustion, drift, retry/resume/fallback. Session
b3276b8e-d6b3-46ce-8cfb-6699b3a77233. Raw metadata/coverage/findings preserved in
/private/tmp/medfit-d1.3jrA2K/D1-assertion-tolerance-review-2026-10-22.json.

## Reconciliation on dev (P1, 2026-10-25)

Everything above describes D1 as written against 0.12.0 and approved there. P1 re-derived it on 0.14.0 `dev` under ADR
D-11 and D-12 (`planning/specs/ADR-native-solver-and-engines-2026-10-23.md`); the receipts above are history, the
differences below are the contract on `dev`.

| D1 as received (0.12.0) | On dev |
|---|---|
| Unresolved zero-product union: new `medfit_sem_unresolved` error with `$outcome` | Still `medfit_error_no_convergence` (D-11, #303, message unchanged); the ledger is `$ledger`, the survivor `$best_survivor` |
| Field name `outcome` (`diagnostics$outcome`, `err$outcome`, `res$diagnostics$outcome`) | `ledger` everywhere: `fit@diagnostics$ledger`, `err$ledger`, `mbco_sem()$ledger`, `compare_lr()` `$reference$ledger` |
| `mbco_sem()` aborts on any unresolved null | Keeps #300's unresolved result (NA statistic, `unresolved` TRUE, one warning); a structural error in a refit still stops |
| Every pipeline error became the typed unresolved error | The original condition is re-raised with its class and `$ledger` attached (a data or model error is not an optimizer failure) |
| `.sem_require_outcome()` refusal: `medfit_sem_unresolved` | `medfit_error_ledger`, a class of its own, so `mbco_sem()` cannot downgrade a forged or mismatched refit to an unresolved row |
| Every node holds a copy of the sample; failure messages gain a `Retained notices:` suffix | The sample is stored once on the root (descendants on the same rows carry `context$sample_hash`, resolved by `.sem_node_sample()`; 64 branches on 40000 rows serialize to 2.0 MB against 1.8 MB of data, not about 65 copies); messages keep their pre-ledger text and the notices live in the ledger only |
| Refit settings as in 0.12.0 | 0.14.0 kept: refits pass `fixed_x`, `factors` and `meanstructure = isTRUE(has_mean)`; the ledger records them |

Not ported here (P2 to P4): literal certificates, the branch map and raw cap, covariance-stage evidence, and the
`medfit_sem_infeasible` / `medfit_sem_empty_union` / `medfit_sem_covariance_error` classes.

Mutant strings moved with the code: the survivor-success mutant now removes #303's `if (length(skipped))` guard; the
planted-defect tests that rewrote `.sem_fit_syntax()` rewrite `.sem_fit_pipeline()`, which now holds its body.
Two guard bypasses keep a numeric control alive (`test-sem-branches.R`, and the `larger` mutant of
`tests/sim/sem-nonlinear-gate.R`): the ledger guard would otherwise refuse the mutant's fit before the oracle sees it.
