# Result: QC record of the 0.14.1 D1-D4 evidence contract (2026-10-25)

Plan: `planning/PLAN-missingmed-evidence-D1-D4-2026-10-24.md`. Decisions: ADR D-11 and D-12
(`planning/specs/ADR-native-solver-and-engines-2026-10-23.md`). Slice notes: `NOTE-D1` to `NOTE-D4`. Related:
`RESULT-checkpoint2-missingmed-rerun-2026-10-25.md`.

Sources: the repository, `git log v0.14.0..HEAD`, and `gh pr view` for #336 to #343. Counts marked "now" were measured on
this branch (`feature/qc-d1-d4-release`, release `ba17d8d` plus two test commits), with `testthat::test_dir()` against an
installed scratch library, reference BLAS (macOS), `NOT_CRAN=true`. Counts marked "PR" are quoted from the PR body. Where the
evidence is a review that left no file in the repository, the entry says so and rests on the PR body or the release brief.

## What the release changed

0.14.1 (release PR #343, merge `ba17d8d`; GitHub-only, CRAN deferred, #83) carries: the outcome ledger on native fits,
branch errors and MBCO (#336); literal zero/nonzero certificates (#338); the branch map and overflow-safe raw cap (#339);
covariance-stage evidence as a typed error, retained in MBCO (#340); the validated MBCO root ledger (#342); docs (#341).
Two test commits follow the release on this branch: `4081e8e` (`compare_lr()` with a retained null) and `6fec51d` (skip the
source-mutating mutants under covr). No `R/` change after the release.

## Per slice

| Slice | PR | New test files (tests, expectations now) | Full suite at merge (PR) |
|---|---|---|---|
| P1 D1 ledger | #336 | `test-sem-outcomes.R` (25, 314; PR 25, 315) | 1624 tests, 7706 expectations, 0 failed, 2 skipped, 1 warning |
| P2 D2 certificates | #338 | `test-sem-literal-certificates.R` (15, 140) | 1639, 7848, 0 failed, 2 skipped, 1 warning |
| P3 D3 branch map | #339 | `test-sem-branch-map.R` (9, 211) | 1648, 8059, 0 failed, 2 skipped, 1 warning |
| P4 D4 covariance | #340 | `test-sem-post-fit.R` (12, 212), `test-sem-post-fit-qa.R` (4, 81) | 1664, 8352, 0 failed, 2 skipped, 1 warning |
| #342 root ledger | #342 | `test-sem-mbco-root.R` (10, 79), `test-sem-mbco-root-qa.R` (8, 41) | 1682, 8470, 0 failed, 0 errors, 2 skipped |
| after release | (branch) | `test-compare-lr-retained-null.R` (3, 25) | not rerun in full |

The one warning in P1 to P4 is the lme4 non-convergence warning in `test-cluster-boot.R` ("any other warning still marks the
refit as failed"), reproduced identically on a clean `origin/dev` archive (PR #336, #338, #339, #340). The two skips are
Suggests skips. Every "now" run above had 0 failed, 0 errors, 0 skipped, 0 warnings.

### Planted mutants (from the PR bodies)

- P1: 12 in-memory mutants (drop node, swap likelihood, forged count, error-class inheritance, survivor `f` and id,
  `which.max`, MBCO downgrade, order, dropped error ledger, hash path), all caught once QA's tests were added. Equivalent
  survivors: the validator's child-digest recheck, and the 64-branch cap inside the validator (the cap is enforced before a
  ledger exists). One mutant, the validator cap 64 to 640, survives for that reason. Mutation tests in `test-sem-outcomes.R`:
  "survivor-success, status-drop and label-swap mutants fail intended assertions", "duplicate and tampered branch IDs cannot
  forge resolved public evidence", "forged, mismatched or missing sample digests are refused...". Gate mutants `noshift`
  and `larger` retargeted and still exit 1.
- P2: 19 in-memory mutants plus 4 survivors, all caught; the `union` flag forced to `TRUE` and to `FALSE` is caught. Tests in
  `test-sem-literal-certificates.R`, for example "consistent parameter forgery cannot supply a contradiction premise" and
  "an underflowed literal is unknown, never a zero premise".
- P3: four mutants survived the implementer's tests (text threshold `>=`, `> 2^54`, `> 2^53 + 2`; cap `> 65L`; validator
  accepting a missing map). Two added tests catch them (the 2^53 text boundary and the 65 cap; "a zero-product ledger without
  its map is refused, by the validator and by `mbco_sem()`"). One mutant is equivalent (removing the overflow guard in
  `.sem_raw_count`: 0 differences in 2000 random vectors and 16362 boundary trials, since IEEE doubles give `Inf`).
- P4: 24 QA mutants plus 3 of the implementer's. Eight of ten compatibility mutants survived the implementer's tests; the 4
  tests of `test-sem-post-fit-qa.R` now catch them. 21 of 24 are caught by named tests, 3 survivors argued equivalent or
  redundant (messages merge already in the inner ledger; the `n_obs` clause behind the data clause; a second guard layer). A
  mutant making the new class a refinement of `medfit_error_no_convergence` is caught: with a refinement the D-11 handler in
  `mbco_sem()` would turn a covariance failure into an unresolved row.
- #342: seven validator mutants (child count `==` to `>=`, root outcome unchecked, null constraint compare dropped, null
  sample check dropped, failed-null id and parent dropped, domain compare dropped, root branch map dropped), each failing a
  named test in `test-sem-mbco-root.R`; 70 forged ledgers, all refused except the residuals listed under "Not decided".

### Independent oracle and numeric neutrality

- P1: `origin/dev` as the oracle: coef, vcov, logLik, tidy, glance, `$tests` and MBCO statistics bit-identical on native,
  zero-product and mean plus `fixed_x` fits and two `mbco_sem()` runs; a +1000 location shift leaves ledger branch counts,
  ids, outcomes and the MBCO statistic identical; the D-11 probe (branch 1, 2, both or none failing) gives the same class and
  message as `dev`; 8 forged-digest variants refused. Known answers 221.045546 and 0.083100 unchanged.
- P2: `identical()` against `origin/dev` on native, zero-product, mean plus `fixed_x` and MBCO fits; a certified branch equals
  the independent sibling fit at 1e-12 (`b1 == 0, a1 == 1`); +1000 shift identical.
- P3: hand product and hand mixed-radix grid with the first-minimum tie-break on 13 models; `dev` export for execution (30 grid
  by f-vector cells) and for the over-cap message, class and `required` on 13 counts (byte-identical); neutrality identical to
  `dev`; 24 forged maps refused.
- P4: numeric neutrality against an `origin/dev` copy (coef, vcov, logLik, tidy, glance, ledger names, MBCO statistic and p
  identical); a +1000 shift moves estimates by at most 5e-15; the SE oracles (`test-effect-se.R`, `test-sem-se-pinned.R`,
  `test-sem-mbco.R`, `test-compare-lr.R`, `test-sem-anova.R`) unchanged; `sem-se-gate.R` (240 runs against OpenMx and lavaan)
  exit 0.
- #342: the same 24 calls and a sandwich fit on a clean `origin/dev` archive, compared with `identical()` on the whole result
  (statistic, p.value, tests, warnings): identical. The one ledger difference is a failed null's recorded
  `context$settings$se_type`, now `"model"` (what the refit used).

## Reviews and what each found

| Review | Found | Fix |
|---|---|---|
| Codex adversarial review (per the release brief; no review file in the repository) | `mbco_sem()` returned a root ledger no validator had checked | #342, `.sem_valid_mbco_outcome()` |
| Oracle QA on #342 (PR #342) | the sandwich false refusal: `fit_sem(se_type = "sandwich")` then `mbco_sem()` was refused because the nulls are refit with `se_type = "model"`; and a failed null checked only for position and `outcome == "unresolved"` | nulls compared with the refits' settings; failed null held to the exact shape |
| Full suite on #342 (PR #342) | `test-sem-literal-certificates.R:327`: an all-empty zero-product null refused as `malformed MBCO outcome ledger` (passed on `origin/dev`) | `78f1a6d` |
| Fresh reviewer (per the release brief; no review file in the repository) | the `failed_se_type` relaxation | recorded in the brief; not independently reconstructed here |
| CI on #342 | a lint `object_usage` finding for an unqualified `test_path` | `5c94cea` "qualify test_path so the lint object-usage check passes" |
| CI `test-coverage` on the release PR #343 (failed there) | `outcome_mutate()` could not find the text it replaces, because covr rewrites function bodies | `6fec51d`: `skip_on_covr()` on the two mutant tests |
| QA on P2 (PR #338) | the MBCO root ledger said "resolved" for an unresolved, direct-infeasible null, because the exclusion counted as resolved for every parent | the `union` flag; regression test red first; re-QA PASS on `b1a0cd0` |
| QA on P3, P4 (PR #339, #340) | surviving mutants (P3: 4, P4: 8 of 10 compatibility mutants); P4: the class-refinement hazard | added tests (see mutants above) |

The recurring class is the false refusal of a genuine result (the sandwich fit, the all-empty union, and the P2 root verdict).
It is the reason the QC article lists every null-node shape `mbco_sem()` can produce.

## Gates and OpenBLAS

- Gates run 40264040502, `workflow_dispatch` on `dev` at `9599608` (P1 to P4): `gates (reliability)` and `gates (rest)` both
  success. #342 changed validation only and was not dispatched on its own; its PR-level gate evidence is the sim scripts run
  locally on the reference BLAS (`sem-factor-gate.R` 0 fail in every cell, `sem-nonlinear-gate.R` RULE MET,
  `compare-lr-gate.R` 150 of 150 rows, `MUTANT=wrongref sem-factor-gate.R` exit 1).
- Release PR #343 checks as listed by `gh pr checks 343`: all pass (including `gates (reliability)` 22 min and
  `gates (rest)` 30 min, lint, risk-tier, macOS, Windows, ubuntu release/devel/oldrel/noSuggests, pkgdown) except
  `test-coverage`, which failed on the covr mutant issue fixed by `6fec51d`.
- Sim gates per slice on the reference BLAS (PR bodies): `sem-fixed-x-gate.R` RULE MET with all six mutants exit 1;
  `sem-nonlinear-gate.R` RULE MET (240 runs) with all five mutants exit 1.
- Full-size `sem-mbco-k-size` (not run for #342 before the release): the log
  `ksize-full.log` in the session scratchpad is finished. 22 cells (21 null, 1 alternative), 2000 replications each, 0 fit
  failures, largest null rejection rate 0.0550 against the limit 0.0646, power 0.838 at the alternative (floor 0.75),
  p-values equal `pchisq(statistic, 1)`, the `chi-square(2)` mutant fails oracle and power; six rules PASS, "RULE MET". The run
  was made on a `git archive` of `origin/main` at `ba17d8d` (Version 0.14.1, which contains #336-#342); the log itself does not
  record the tree.

## Missingmed consumer rerun

`RESULT-checkpoint2-missingmed-rerun-2026-10-25.md`: three consumer files, 34 tests, 707 expectations, 0 failures, identical on
`c2af811` and `4a84e66`, against `dev` at `9599608`. The closure matrix's counts do not reproduce: it states 816 (95 + 126 +
595); the provider file gives 17 at both revisions, so 109 of the 816 are not reproduced, and the fixture hash differs.
Reported, not resolved.

## Decisions for the author (not applied)

1. Whether `R/sem-outcomes.R` and `R/sem-mbco.R` belong in `tests/sim/risk-files.txt`. They decide whether evidence is
   accepted, so a false refusal or acceptance is a result-affecting defect; today the list holds `R/sem-fit.R`, `R/fit-sem.R`
   and the solver files only, so #342 was not high-risk by the checklist's own rule. Recommended: add them.
2. Whether a `gates.csv` row with an `oracle` and `mutants` should register the validator (the genuine-shape grid as the
   oracle, the seven #342 mutants as the planted defects). Adds an OpenBLAS-gated check of the false-refusal class.
3. Whether to tighten the empty-union null to require that the null's `model$syntax` starts with the root's and that the
   information is equal (QA's optional tightening on #342; deliberately not done). It closes the foreign self-consistent
   all-excluded union; the statistic is `NA` either way.
4. The full-size `sem-mbco-k-size` result above, once the tree it ran on is confirmed.
5. The deleted `keep/*` branches are recoverable only from the reflog; nothing in the repository references them.

## Not decided without a refit (residuals, accepted)

A consistent rewrite of the root sample with every `sample_hash`; an altered parameter value inside a null's table; the text,
class and call of a failed null's condition; an empty-union null validated against its own certificates only. Also accepted
by #342: `NULL` `model$parameters` on a failed null (the engine produces it when it stops before parsing).

## Not verified

- The OpenBLAS gates were not run on the final tree: run 40264040502 covers `dev` at `9599608`; #342 and the two later test
  commits were not dispatched.
- The Codex adversarial review and the fresh reviewer's review left no file in the repository; their findings here rest on the
  release brief and the PR bodies.
- The `failed_se_type` relaxation is named in the brief; this record does not reconstruct it.
- The "now" counts are one run on the reference BLAS; no platform other than macOS was run for them.
- The tree of the full-size k-size run.
- Whether the `keep/*` branches still exist in any clone.
