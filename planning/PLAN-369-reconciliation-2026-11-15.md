# Plan: close out issue #369 (reconcile #249 and #357 with merged work)

Status: EXECUTED 2026-11-15. T1-T3 in `bd2d9c7b` (on `origin/dev`); T4: #369 closed as completed; optional items:
#276 "Sync the plan (D18)" ticked, mbco-lrt log D18/D20 marked decided in mbco-lrt `9daa6dd` (local, not pushed).
Revised before execution after an independent adversarial review. Docs and issue administration only;
no `R/` or test change. Every GitHub write (issue comment, issue edit, close), every push and every edit in
Data-Wise/mbco-lrt needs the owner's yes in chat. All evidence below is read on `origin/dev` (`0226c74c`).

## What is already true (verified 2026-11-15, read-only)

| Item | State | Evidence |
|---|---|---|
| #249, #357, #360 | CLOSED 2026-11-11 | `gh issue view` |
| #369 | OPEN; body carries the 2026-10-31 clause-level table | `gh issue view 369` |
| Clause reconciliation doc | on dev | `planning/ISSUE-369-reconciliation-2026-10-31.md` (via #377, `da0d9edc`) |
| Imported plan banner | on dev | `planning/specs/PLAN-constrained-lr-solver-2026-10-19.md:5-10` |
| Solver ADR | on dev | `planning/specs/ADR-native-solver-and-engines-2026-10-23.md`: Part A (SLSQP default, labeled "D19" in the 2026-10-09 numbering) accepted and implemented; Part B (tiered path, AUGLAG fallback) decided as the target, not implemented; `"slsqp"` as a permanent option replaces Part B's `slsqp_legacy` and its deprecation window (ADR ~line 175) |
| Default solver | SLSQP | `R/sem-control.R:6` (`.sem_nloptr_algorithm <- "NLOPT_LD_SLSQP"`), `R/sem-optim.R:383` |
| **D18** | **decided in medfit** | #276 (closed 2026-10-22): "SLSQP is kept as a permanent, user-selectable backup and is never the default. The plan's `slsqp_legacy` two-release removal is dropped." Agrees: ADR ~175, `planning/releases/0.16.0/issue-disposition.md:7` |
| **D20** | **decided for Tier 1** | ADR D-6 (decided 2026-10-23): structure and Tier 1 method are standardized warm-start charts (0/600 invariance failures). Tier 1 is not implemented |
| Stale D18/D20 copies | outside medfit's decision record | mbco-lrt `docs/decisions/decisions-log.md:24,26` (still "open"; read-only), `GRILL-276:19`, #276's unchecked "[ ] Sync the plan (D18)" |
| `cc3fd88` | superseded | 8 files: 6 identical to origin/dev; `.STATUS` and the roadmap differ only because dev moved on |
| Live #369 mentions | 3 lines | `.STATUS:256` (`next:` open-issues list), `planning/medfit-roadmap.md:1893,1897` |
| History mentions (keep) | 2 lines | `.STATUS:23`, `NEWS.md:91` (released 0.17.0 section) |

Remaining scope is administrative: record that D18 and D20 are already decided, drop #369 from the live lists, post a
closing comment, close. No owner decision is open: D18 is decided (#276) and the owner confirmed D20 is Tier 1 only (D-6).

## Key reading

- **D18 is decided, not deferred.** The author ruled on 2026-10-21 (#276); the ADR already carries the effect. The
  upstream log is stale, not medfit's record.
- **D20 is decided for Tier 1 (D-6).** #276 phrases it "standardization always on". If that means more than Tier 1
  (for example every constrained fit today), it would be a new decision; the owner confirmed Tier 1 only (2026-11-15).
- **Implementing Part B and Tier 1 is unscheduled roadmap work.** It is not a #369 deliverable and needs no new issue.
- **Label clash.** The ADR's "D19" (SLSQP default) is the 2026-10-09 numbering; upstream D19 is now an RMediation item.

## Tasks

### T1: cross-reference D18 and D20 in the solver ADR

**Description.** Add one `decisions:` row, D-14 "D18: SLSQP stays a permanent user-selectable option, never the
default", `status: decided`, `date: 2026-10-21` (the author's date, source #276). Add two sentences to Part B: D18 is
D-14; upstream D20 is covered for Tier 1 by D-6; the ADR "D19" label is the old numbering.

**Acceptance criteria.**
- [ ] One new row, unique id, format `{id, title, status, date}`.
- [ ] No sentence claims SLSQP was removed, that Part B or Tier 1 is implemented, or that standardization is on today.

**Verification.** `Rscript -e 'testthat::test_file("tests/testthat/test-adr-front-matter.R")'` passes; `grep -n
"removed\|always on" <ADR>` shows no new claim.

**Dependencies.** None. **Files.** the ADR. **Scope.** XS.

### T2: point the imported plan banner at #276 and D-6

**Description.** Add one sentence to the banner in `planning/specs/PLAN-constrained-lr-solver-2026-10-19.md:5-10`: D18
is decided in #276 (ADR D-14) and D20 for Tier 1 in ADR D-6. Leave the body (the stale `slsqp_legacy` clauses) alone;
the banner already marks the file historical and upstream-owned.

**Acceptance criteria.** [ ] banner names #276, D-14, D-6; [ ] body unchanged.

**Verification.** `git diff` touches banner lines only. **Dependencies.** T1. **Scope.** XS.

### T3: closure section and the live open-issue lists

**Description.**
- Add a dated "2026-11-15 closure" section to `planning/ISSUE-369-reconciliation-2026-10-31.md`: #249, #357, #360
  closed 2026-11-11; D18 decided (#276, D-14); D20 decided for Tier 1 (D-6); Part B and Tier 1 unscheduled;
  `cc3fd88` superseded (one line); #320 stays open; the mbco-lrt log sync is a separate, owner-authorized edit there.
- Drop #369 from `.STATUS:256` open-issues list and from `planning/medfit-roadmap.md:1893` (and reword `:1897`, which
  says #369 "tracks administrative follow-through", to past tense with the closure date).
- Do not touch `.STATUS:23` or `NEWS.md:91` (history). No NEWS or release-notes edit: 0.18.0 is released and its notes
  are published.

**Acceptance criteria.**
- [ ] Every #369 checklist item has a disposition and an evidence link in the closure section.
- [ ] After the edit, `git grep -n '#369'` shows only `.STATUS:23`, `NEWS.md:91`, the reconciliation doc, the ADR,
  the banner and the roadmap past-tense line.

**Verification.** `git grep -n '#369'` before and after (diff the two lists);
`Rscript -e 'testthat::test_file("tests/testthat/test-docs-release.R")'` passes (RD-7 reads the `.STATUS` head).

**Dependencies.** T1. **Files.** reconciliation doc, `.STATUS`, roadmap. **Scope.** S.

### Checkpoint A (after T1-T3)

- [ ] ADR front-matter and docs-release tests pass locally.
- [ ] Owner reviews the diff. Docs on dev are allowed; commit and push need a yes.

### T4: close #369 (owner action)

**Description.** Post one comment (drafted in chat first), then close as completed. Draft:

> Closing. #249, #357 and #360 closed 2026-11-11. D18 is decided in #276 (SLSQP stays a permanent, user-selectable
> option, never the default), recorded as ADR D-14. D20 is decided for Tier 1 by ADR D-6 (standardized warm-start
> charts). Implementing Part B and Tier 1 is unscheduled roadmap work and needs no new issue. #320 stays open as the
> known external-engine limitation. Syncing the upstream mbco-lrt decisions log is a separate change there. Record:
> `planning/ISSUE-369-reconciliation-2026-10-31.md` (2026-11-15 closure), commit `<sha>`.

**Acceptance criteria.** [ ] comment links the dev commit, D-14, D-6 and #320; [ ] issue closed.

**Verification.** `gh issue view 369 --json state` = CLOSED. **Dependencies.** Checkpoint A pushed. **Scope.** none.

### Optional, separate authorization

- Tick #276's "[ ] Sync the plan (D18)" box (issue edit in medfit).
- Update mbco-lrt `decisions-log.md:24,26` to "decided" (cross-repo write).

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| D-14 dated 2026-10-21 looks backdated | Low | the row's title cites #276; the commit message says it records an earlier decision |
| Upstream log stays stale and misleads a later reader | Low | the closure section and the banner name it as stale and point at #276 |

## Owner answer (2026-11-15)

1. D20 "standardization always on" means Tier 1 only, covered by ADR D-6. No D-15 row.
