# Brainstorm: the medfit 0.19.0 release (2026-11-16)

Status: brainstorm, decided scope. Nothing here authorizes a release, a tag, a `main` merge or a GitHub release; the
maintainer authorizes those in words (precondition P1 of `planning/PLAN-0.19.0-release-checklist-2026-11-16.md`).

## Where things stand

- `main` and the latest tag are **0.18.0** (`v0.18.0` at `6d226fb1`, 2026-11-14, GitHub-only). CRAN holds 0.3.2; #83 keeps
  CRAN on hold.
- `dev` is **0.18.0.9000**, 61 files and +3,680 / -148 lines past `main` (at `7445af62`, 2026-11-16).
- What `dev` adds since 0.18.0 is **IG5: more than one mediator in a two-level model**
  (`planning/PLAN-multilevel-implementation-gaps-2026-11-11.md`):
  - T1 `TwoLevelParallelMediationData` (the class, its validator, the dependents-contract pin)
  - T2 and T3 lavaan extraction of parallel mediators, effects and SEs
  - T4 `twolevel_statistic()` for parallel mediators (#463)
  - T5 docs: model page, cookbook, NEWS (#465)
- Also on `dev`: the few-clusters design-study plan (#464), planning only.
- Not on `dev` yet: the few-clusters harness (T1–T2 in progress, T3 queued). It is internal (`tests/sim/`, a harness test,
  `planning/`), so it can land before or after the release without changing what users get.
- No open PRs (checked 2026-11-16).

## Options considered

| Option | Contents | Cost | Verdict |
|---|---|---|---|
| A. **IG5 only** | ship 0.19.0 with parallel two-level mediators, labeled experimental | one standard release cycle | **chosen** |
| B. IG5 plus the few-clusters study | wait for the harness, run the U4 study, report it | weeks of compute and review; the study answers a research question, not a user need | deferred |
| C. IG5 plus solver work (D-14, D-6) | bundle optimizer changes | turns a low-risk release into a high-risk one (risk-files, seven-item checklist, OpenBLAS runner) | deferred |
| D. Hold until IG6/IG7 | a bigger multilevel release | users wait for a feature that is ready | rejected |

Why A: the IG5 diff touches no `tests/sim/risk-files.txt` entry and no gate file (`gates.csv`, `structures.csv`), so
the release needs no admission checklist. The feature is complete, documented and tested on `dev`. Bundling the study or
solver work would raise the release's risk tier for no user-facing gain.

## Gating: the standard GitHub-only pipeline

The same process as 0.17.0 and 0.18.0: release grill, then the checklist, then the `dev` to `main` PR, then the tag and
the GitHub release. CRAN stays on hold (#83).

## Decisions left for the release grill

1. **Version.** Minor bump to 0.19.0: there is a new exported class, and `extract_mediation()` returns a new class for
   two-level fits with several mediators. Confirm that no existing two-level call changes its return class (single-mediator
   fits must still return `TwoLevelMediationData`).
2. **Experimental label.** Does `TwoLevelParallelMediationData` inherit the two-level experimental exemption (0.17.0
   decision 2: not pinned in `test-api-freeze.R`, "experimental" in NEWS, Rd and the model page)? Recommended: yes, for
   the same reason as the single-mediator adapter.
3. **Book (R6).** Does chapter 9 of `medfit-book` need a parallel-mediator section before the release? Or is R6 a render
   check against the candidate only? Recommended: render-only for 0.19.0. The book follows the release; record that as a
   decision, not as an unmet gate (0.17.0 shipped with R6 unmet and no waiver recorded).
4. **Dependents (R5).** The dependents contract gained a pin. Recommended: run all five dependent suites, as before.
   probmed and RMediation dispatch on classes, so a new class is exactly the kind of change R5 exists for.
5. **The few-clusters harness.** Release before it merges, or after? Recommended: don't wait. If it merges first,
   confirm that its `tests/sim/` files are Rbuildignored and its testthat test is fast or `skip_on_cran()`.
6. **Known limits carried in the notes.** #320 is closed as docs. Restate the two-level limits: no native two-level
   fitting (S4 NO-GO), no latent mediators (S5 NO-GO), no serial two-level mediators, a contrast that is descriptive only,
   and the within-only object when ICC < 0.01.

## Deferred, with where each lives

- The few-clusters design study (U4): `planning/` plan from #464; harness T1–T3 in progress.
- Solver work D-14 and D-6: roadmap item 4.
- IG6 and IG7 (the remaining multilevel gaps): `PLAN-multilevel-implementation-gaps-2026-11-11.md`.
- FIML statistical admission: unchanged, still not admitted.
- CRAN submission: #83.

## Test plan (release-level)

Tier: **release PR (`dev` to `main`)**. That means the full suite plus the release gates, never a subset
(`rules/pre-pr-testing.md`).

| Check | What can fail it | Planted defect / known answer |
|---|---|---|
| Full suite, isolated install, `NOT_CRAN=true` | any regression since 0.18.0 | baseline: the 0.18.0 counts on `main` |
| Strict `R CMD check` (`--run-donttest`, DEPENDS/SUGGESTS_ONLY, CRAN_INCOMING) | a Suggests used unguarded (lavaan in the parallel path) | `_R_CHECK_SUGGESTS_ONLY_` without lavaan must skip, not error |
| Tagged-install smoke (R10) | a broken export or registration of the new class | fit a two-level lavaan model with two mediators from `mediation_demo`-style data; `class()` must be `TwoLevelParallelMediationData`; with one mediator it must be `TwoLevelMediationData` |
| Dependent suites (R5) | dispatch on the new class breaks probmed/RMediation | per-test counts against published 0.18.0 |
| Docs gates (`test-docs-release.R`, model-page tests) | stale version, missing "experimental" | each gate already carries a planted defect |
| Site build (R4) | the new model page errors at build | read the rendered page, not the exit code |
| Both `gates` shards on the release PR | an environment change on the runner | no `--admin` (0.17.0 decision 4) |

## Documentation scaffold

- NEWS: collapse `# medfit 0.18.0.9000` into `# medfit 0.19.0`; every line names a merged PR.
- `.STATUS`, `CLAUDE.md` status line, README version mentions, `inst/CITATION`: bump. Then grep for `0.18.0.9000`.
- The roadmap board (`planning/medfit-roadmap.md`): mark IG5 released after the tag.
