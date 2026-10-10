# GRILL: medfit 0.7.0 release plan (S24)

| | |
|---|---|
| **Date** | 2026-10-10 |
| **Target** | The S24 release plan drafted by an Opus subagent on 2026-10-10 (read from the subagent report, not a file); sources: `planning/specs/PLAN-native-sem-implementation-2026-10-09.md` (S24, section 8), `.STATUS`, `CLAUDE.md` |
| **State at grilling** | `dev` @ `579963c`, CI green (R-CMD-check, test-coverage); `main` is an ancestor of `dev` (45 commits ahead); #105 and #106 open |
| **Channel** | GitHub and r-universe only (ledger D9, plan section 8); not CRAN |


## Decision Ledger

| # | Branch | Decision |
|---|---|---|
| R1 | Riskiest assumption: is the probmed path (#105, #106) a release gate? | Yes. Run the S17b probmed gate and probmed's own suite against the bumped build before the release PR; release only if they pass, so #105 and #106 can close with evidence and the notes can claim probmed compatibility. Rejected: ship stating it unverified; ship claiming nothing. Cost accepted: about an extra hour and a possible blocker. |
| R2 | Benefit honesty: which gates are rerun on the release candidate after #120, #122, #123? | Rerun the constrained gate (`tests/sim/sem-constrained-gate.R`, about 120 fits vs OpenMx) and the parity gate (`tests/sim/sem-parity-gate.R`) only. The unconstrained SE gate and the reliability study are untouched code, so the NEWS claim 'agree to 1.6e-4 in the worst of 240 simulated datasets' stands on its 2026-10-09 run. Rejected: all four gates (hours of compute for unchanged code); none (stale evidence in the PR body). |
| R3 | Dependents: how are the suites of probmed, missingmed, mediationverse and RMediation judged? | Baseline plus candidate: clone each dependent's dev into scratch, run its suite against medfit 0.6.0 and against the 0.7.0 candidate, and count only per-package differences as regressions. A dependent that is already red on 0.6.0 is not blamed on medfit. medrobust stays out. Rejected: candidate only (a pre-existing failure costs a baseline run on the spot and risks a wrong call); candidate vs each dependent's released version (tests code users run, misses a break in unreleased dependent changes). Cost accepted: double the runtime. |
| R4 | Scope: is S1 / PR 11 part of 0.7.0? | Out. Ship 0.7.0 with PRs 1-10 and the review fixes (#118-#124); NEWS lists S1/PR 11 as planned. `.STATUS` says S1 gates PR 11, not 0.7.0, and plan section 4.4 scopes it out. Rejected: include S1 first (unsoaked feature, every gate reruns); include only if under a day (sizing step, scope-creep risk). |
| R5 | Extras: which optional dispatches and cross-repo items accompany the release? | In, all after the tag and each on its own explicit go: (a) `[BREAKING]` issue in medfit for the `model =` argument; (b) RMediation `mbco()` X0 report, drafted as text in a planning file first, filed in RMediation only on explicit request (cross-repo write); (c) ecosystem row E1 in `~/projects/r-packages/mediation-planning` (cross-repo write, explicit request). Out: r-hub and full revdepcheck (GitHub/r-universe channel only; dependents covered by R3). Rejected: bundling the cross-repo writes into the release session without per-action approval. |
