# Decisions: 0.17.0 release grill, 2026-11-11

**Status:** decided by the maintainer in a grill session on 2026-11-11. Planning only: no version bump, tag or release
is authorized by this file. The roadmap's current board owns the queue.

| # | Question | Decision | Consequence |
|---|---|---|---|
| 1 | How is bounded FIML with covariates, parallel and serial mediators presented? | Ship, labeled "numerically verified against lavaan, not statistically admitted" | NEWS, the native guide and the README say so; source-fit intervals stay withheld; no admission study is implied |
| 2 | How is the two-level API labeled? | Experimental: `TwoLevelMediationData`, `twolevel_statistic()`, `nie(level = )` | Lifecycle experimental badge in the Rd pages and NEWS; not pinned in `tests/testthat/test-api-freeze.R`; may change without the 2-month deprecation (S4, the native two-level fitter, could change the object) |
| 3 | Why was v0.15.0 tagged before the 2026-12-24 notice floor? | A deliberate waiver by the maintainer | A dated waiver line sits in `PLAN-0.15.0`, `SPEC-0-15-release` and `BRAINSTORM-0-15-release`; the reason was not given and is not recorded |
| 4 | Which gates must pass for the `dev` to `main` release PR? | Both `gates (rest)` and `gates (reliability)` green on the exact release head; no `--admin` merge | `.github/workflows/gates.yaml` already runs on ubuntu-24.04 (both `runs-on` lines), so no workflow change is needed |

## Open, not decided here

- The version bump goes in a release-prep PR (the dev convention); its timing and the NEWS wording are not decided.
- The 0.17.0 release checklist lives on an unpushed branch of another session; fold these four rows into it when it lands.
