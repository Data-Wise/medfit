# GRILL: medfit 0.11.0 release and S7 1.0 readiness (2026-10-17)

Target: `planning/PLAN-0.11.0-scope-2026-10-16.md` and `planning/PLAN-s7-1.0-readiness-2026-10-17.md`, after Checkpoint 2
passed. One question at a time; the author's answers are the decisions. Recommended answer first on every question.

## Decisions

| # | Branch | Question | Decision | Consequence accepted |
|---|---|---|---|---|
| G1 | Weakest recommendation | CRAN 0.3.2 still ships results earlier releases fixed as wrong (#81, #82) and the hold's triggers are passive | Submit 0.11.0 to CRAN after a one-week soak (recommended) | A CRAN review of a much larger package (native engine, nloptr Imports, OpenMx Suggests) and the strict-check and cran-comments routine; fixes the wrong results on CRAN and unblocks probmed's `medfit (>= 0.3.0)` gate |
| G2 | Riskiest assumption | `run-gates.R` is the single release gate but nothing enforces it; T5b showed a gate sit red unseen | CI job running `run-gates.R --sim` on PRs to `main` (recommended) | About 8 min of runner time per release PR, a workflow that installs lavaan, OpenMx and nloptr, and a decision on making it a required check |
| G3 | Implementation regret | The freeze covers the `?medfit-syntax` grammar, but categorical support (roadmap B1-B3) needs new grammar and naming | Reserve additive extensions in the freeze list and pin the current canonical names with a test (recommended) | About an hour; commits B1-B3 to an additive design (no renaming of dummy columns or `m:x` rows) |
| G4 | Benefit honesty | S5 (rerun on S7 1.0.0) has no mechanism, and a green S7@main result today does not cover later S7 changes | Weekly scheduled workflow: `s7-lifecycle` gate on S7@main plus a CRAN S7 version check that opens an issue (recommended) | About 2 h and weekly runner minutes; a scheduled run may be red and is allowed to fail |
| G5 | Reversibility and scope creep | Sequencing of the four jobs from G1-G4 | **Everything before the 0.11.0 tag** (the author overrode the recommendation: freeze in 0.11.0, CI jobs in the soak week) | About another day before tagging; the Checkpoint 2 evidence must be regenerated on the final commit, which the new CI gate job then provides; the release is gate-enforced and S7-watched from day one |
| G6 | Riskiest assumption (inside G2) | Gate tolerances and baselines were calibrated on macOS; CI Linux differs at about 1e-9 on SLSQP output | Ship the CI gate job non-required, make it a required check after two consecutive green Linux runs (recommended) | Two extra CI runs of about 8 min and a later branch-protection edit; a Linux-only failure is fixed (tolerance, seed or fixture) before it can block a release; if drift appears the tag waits (G5) |

## Open Questions

- Work implied by G1-G5, all before the 0.11.0 tag (none is in the plan's task list yet):
  1. **R1** freeze list: a "reserved additive extensions" paragraph (where: NEWS Lifecycle entry and the native model page)
     plus a test pinning the current canonical names (`m:x` rows, `SEMFit` property names, syntax-help grammar tokens).
  2. **R2** CI job on PRs to `main` (and `workflow_dispatch`) running `Rscript tests/sim/run-gates.R --sim`, installing
     lavaan, OpenMx and nloptr; decide whether it is a required status check on `main` (branch protection today requires
     only `ubuntu-latest (release)`).
  3. **R3** weekly scheduled workflow: `s7-lifecycle` gate on S7@main, plus a CRAN S7 version check that opens an issue on
     a change; allowed to fail.
  4. **R4** Checkpoint 3, the code-focused Codex review (focus text names the code), then the bump; Checkpoint 2 cheap
     items rerun on the release commit (R2 supplies the gate run).
  5. **G1 follow-up** after the tag: one-week soak, then the CRAN routine (strict checks, `cran-comments.md` resync,
     maintainer-manual `submit_cran()`); update `.STATUS` "CRAN submission remains on hold" and the GRILL-0.8.0 R1 triggers.
- Not asked (the grill stopped at five branches): the RMediation message about dropping "experimental" (still unsent, the
  author pastes it); S4 (probmed and RMediation against S7 main); S6 (the `S7 (>= 0.1.0)` floor); whether SEMFit should have
  `nie`/`te` (the absent-pairs table from S3b).
