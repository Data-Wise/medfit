# PLAN: medfit 0.7.0 release execution (S24)

| | |
|---|---|
| **Date** | 2026-10-10 |
| **Source** | Opus planning pass (read-only) on `dev` @ `579963c`, updated with ledger R6-R10 |
| **Binding decisions** | `GRILL-medfit-0-7-0-release-2026-10-10.md` (R1-R10); the ledger wins over `PLAN-native-sem-implementation-2026-10-09.md` S24 |
| **Channel** | GitHub and r-universe only; not CRAN (CRAN has 0.3.2) |
| **Closed 2026-10-11** | 0.7.0 released 2026-10-10 (`.STATUS` release_0.7.0); post-tag items (c) E1 is done for 0.7.x (mediation-planning#13). Future work opens `tasks/plan.md`, not this file. |

Every step marked **A#** needs an explicit go from the user; approval of one step does not carry to the next.

## State at planning (read-only, 2026-10-10)

- `origin/main` = `1d30d0f` = tag `v0.6.0` (lightweight). `main` is an ancestor of `dev` (45 commits behind).
- `main` protection: PR required, 0 approvals, strict, required check `ubuntu-latest (release)`, no force-push. `dev`: deletion-only ruleset, so "no code on dev" is policy only.
- Open issues: #105, #106 (closed by the release PR), #83 (stays open).

## Findings (gaps between ledger, older plan, and repo)

| # | Finding | Resolution |
|---|---|---|
| F1 | Grill ledger was untracked on `dev` | Done: committed `819365f`, `871d2e3` |
| F2 | PLAN S24 and `.STATUS` still list r-hub and `revdepcheck` | R3/R5 replace both; tick S24 with that wording after the release |
| F3 | PLAN 4.3/4.4 say PR 11 may ship in 0.7.0; NEWS says nonlinear constraints "not yet supported" | R4: out. NEWS lists them as **planned** (blocks bump PR) |
| F4 | NEWS has no `nloptr` entry; Dependencies covers only `lifecycle` | Add `nloptr` (Imports, compiled) and `OpenMx` (Suggests, test oracle) (blocks bump PR) |
| F5 | NEWS lacks a Documentation entry (cookbook recipe 11, `?"medfit-syntax"`, native methods section, refcard rows); l.45 over 80 chars | Add entry, rewrap l.45 |
| F6 | CLAUDE.md:551 stale ("PRs 1-8 of 11"); AGENTS.md:551 differs | R7: edit inside the bump PR, written as already released; keep the two identical |
| F7 | `.STATUS` and PLAN 10 call X0 "unreproduced"; PLAN S0(d) records it reproduced (labels `a2, cp, a1`; diffLL 0.060332 as written) | Correct in post-release `.STATUS` and the R5(b) draft |
| F8 | `dev` reads `Version: 0.6.0`; site library has medfit 0.4.0, RMediation 1.6.1, missingmed 0.5.0 | Build baseline from `git archive v0.6.0`, never from `dev`; verify scratch libraries by loading (`library()`, `packageVersion()`, `find.package()`) |
| F9 | Local dependent checkouts behind `origin/dev` (probmed 1, rmediation 1, mediationverse 6) | R6: clone `dev` from GitHub into scratch; record SHAs |
| F10 | mediationverse Suggests `altdoc` (not installed) | R8: run without it; judge by test name; ask before any CRAN download |
| F11 | `git grep` of dependents for `model =` / `mod =` found no direct caller; missingmed `R/run.R:280-290` forwards `...` and `fit_args` into `fit_mediation()` | Evidence for the R5(a) issue text |
| F12 | Parity gate prints `FAIL` on the estimate rule by design (D22: 2 of 420 runs, latent n = 50, 1.1e-6 and 1.6e-6) | Use the D22 pass rule in G8, not the printed word |
| F13 | Sim scripts write `.csv` only; `.out` came from redirected output | `tee` to `.out`, run in the worktree, commit results in the bump PR |
| F14 | github.com pages time out from this machine (urlchecker); strict check's remote incoming checks need network | A timeout is "deferred to CI", not a fail |
| F15 | Where E1 lives | R9: `mediation-planning/docs/ECOSYSTEM-COORDINATION.md`, drafted in medfit first |
| F16 | DESCRIPTION `Description:` says "generalized linear models, with Bayesian methods planned" | R10: update in the bump PR; no local `aspell`, so G4 plus CI are the evidence; new jargon to `inst/WORDLIST`; state the risk in the PR body |
| F17 | Merge to `main` deploys pkgdown and rebuilds r-universe; `test-sem-mbco` lavaan oracle skips locally (lavaan 0.7-2, needs 0.7-3) and runs on CI | Information only |
| F18 | Codex review (2026-10-10), verified: the migration advice "spell out the `glm()` argument" is wrong. `R/fit-glm.R:223` declares `model` before `...`, so both `model = FALSE` and the partial `mod = FALSE` bind to it, and `R/fit-glm.R:238-239` then errors ``"`model` is only used with engine = \"native\"."`` for every non-NULL value on the glm engine. NEWS.md:66-69 and the roxygen `@param model` (`R/fit-glm.R:49-50`, `man/fit_mediation.Rd`) carry the same wrong advice | Correct NEWS, roxygen and the R5(a) issue text in the bump PR (blocks). Corrected advice: drop the argument; `glm()`'s `model` cannot be forwarded through `fit_mediation()` any more. Open decision D-fwd below |
| F19 | Codex review, accepted: G11 compared failing test names only, so an already-failing test could gain failed assertions or new errors, and new skips or lost execution were invisible; the CSV omitted failure messages | G11 rewritten: assertion-level comparison, block on any worsening |
| F20 | Codex review, accepted: G12 let a nonempty diff be "resolved" by rerunning gates against the old worktree and the old `lib-cand`, and lacked a fetch after the merge | G12 rewritten: record the tested tree, fetch, require tree equality, rebuild `lib-cand` from the release tree on any difference; same check again before the release PR |

**Decided D-fwd (ledger R11, 2026-10-10): text fix only.** No forwarding mechanism in 0.7.0. The NEWS and roxygen correction lands on `fix/model-arg-advice` (`b10789b`), so the bump PR no longer carries it. #125 merged as `fd86211` on 2026-10-10; the two checklist rows are struck below, and the bump branch cuts from `origin/dev` at or after `fd86211`.

## 1. Bump checklist (worktree `~/.git-worktrees/medfit/chore-release-0.7.0`)

| File | Spot | Change |
|---|---|---|
| `DESCRIPTION` | l.4-5 | `Version: 0.7.0`; `Date:` = day of the strict check (reset if the release slips) |
| `DESCRIPTION` | `Description:` | Reword engines text to mention maximum-likelihood SEM (R10) |
| `NEWS.md` | l.1 | `# medfit (development version)` becomes `# medfit 0.7.0`, plus one lead line: experimental native SEM engine; GitHub and r-universe only |
| `NEWS.md` | Dependencies (l.86) | `nloptr (>= 1.0.4)` in Imports (compiled; `pak::pak("data-wise/medfit")` builds it unless lme4 already brought it; r-universe ships binaries); `OpenMx` in Suggests |
| `NEWS.md` | after l.49 | Nonlinear constraints planned for a later release (S1 review, PR 11); until then they error by name |
| `NEWS.md` | new `## Documentation` | Cookbook recipe 11, `?"medfit-syntax"`, native section of the methods article, refcard rows |
| ~~`NEWS.md`~~ | ~~Behavior change, l.66-69~~ | **Done** in #125 (squash `fd86211`, 2026-10-10): corrected to say `model` is an error with the glm engine and to drop it. Do not redo; the bump branch cuts from `origin/dev` after it |
| ~~`R/fit-glm.R`, `man/fit_mediation.Rd`~~ | ~~roxygen `@param model`~~ | **Done** in #125 (`fd86211`), with a test pinning `model = FALSE` and `mod = FALSE`. The suite for that PR: 3320 passed, 0 failed, 3 skipped |
| `NEWS.md` | New features | After R1 passes: one clause that the probmed plugin and parametric bootstrap work on observed single-mediator native fits (#105). Rewrap l.45 |
| `README.md` | l.364 | Citation `0.6.0` becomes `0.7.0` |
| `CLAUDE.md`, `AGENTS.md` | l.548, l.551 | `Last Updated`; status paragraph: 0.7.0 on main, GitHub and r-universe (tag `v0.7.0`, contents #110-#124); 0.6.0 moves to history. Keep the two identical |
| `planning/medfit-roadmap.md` | l.4, 27, 1852-1856, 1907 | Status line adds 0.7.0; "current 0.7.0"; next actions (strike native SEM, add S1/PR 11); "Next Review: After the 0.7.0 release" |
| `inst/WORDLIST` | as needed | Real jargon from the new DESCRIPTION text |
| `tests/sim/results/` | new files | `sem-constrained-gate-<d>.csv/.out`, `sem-constrained-stationarity-<d>.csv`, `sem-parity-gate-<d>.csv/.out` |
| `inst/CITATION`, `cran-comments.md`, `_pkgdown.yml` | none | No change (CITATION uses `meta$Version`; not CRAN; pkgdown auto mode) |

Grep: `git grep -nE '0\.6\.0(\.9000)?' -- ':!planning/specs' ':!tests/sim/results'`. No `0.6.0.9000` exists.

| Hit | Change? |
|---|---|
| DESCRIPTION:4, README.md:364, CLAUDE.md:551, AGENTS.md:551, roadmap:4, 27, 1907 | Change |
| `.STATUS`:6-7 | After the release only |
| NEWS.md:61, 91, 168 (0.6.0 history) | Keep |
| `.STATUS` history rows, roadmap:1854, `planning/specs/*`, `tests/sim/results/*2026-10-09*`, `R/sem-model.R:111` | Keep |

## 2. Gates (worktree; tests need `NOT_CRAN=true`)

`S` = session scratchpad plus `/s24`.

| # | Command | Pass |
|---|---|---|
| G0 | `git fetch origin && git merge-base --is-ancestor origin/main origin/dev && echo ok` | ok; `dev` has not moved since the branch was cut |
| G1 | `Rscript -e 'devtools::document()'; git status --porcelain man NAMESPACE` | no diff |
| G2 | `NOT_CRAN=true Rscript -e 'devtools::test(reporter="summary")'` | FAIL 0, WARN 0; skips only the known ones (lavaan < 0.7-3 MBCO oracle, coverage sim); none in `test-sem-probmed` |
| G3 | `Rscript -e 'devtools::load_all(); lintr::lint_package()'` | 0 lints |
| G4 | `Rscript -e 'spelling::spell_check_package()'` | no words (jargon to `inst/WORDLIST`) |
| G5 | `Rscript -e 'urlchecker::url_check()'` | no 404 or moved URLs; github.com timeouts recorded as deferred to CI |
| G6 | Strict check from CLAUDE.md (`devtools::check(cran=TRUE, args="--run-donttest", env_vars=c(DEPENDS_ONLY, SUGGESTS_ONLY, CRAN_INCOMING, CRAN_INCOMING_REMOTE = "true"))`) | 0 errors, 0 warnings, 0 notes; local aspell absent, so G4 covers the DESCRIPTION spell sub-check |
| G7 | `Rscript tests/sim/sem-constrained-gate.R 2>&1 \| tee tests/sim/results/sem-constrained-gate-$(date +%F).out` (OpenMx 2.22.11; may run in background alongside G6) | "Worst relative SE ... : PASS" (<= 1e-3); 0 failed runs in 120; stationarity "RULE MET" |
| G8 | `Rscript tests/sim/sem-parity-gate.R 2>&1 \| tee tests/sim/results/sem-parity-gate-$(date +%F).out` | D22 rule: SE line PASS (<= 1e-3); 0 failed and 0 improper in 420; any estimate gap over 1e-6 only in `latent.50` with `lav_gap` < 1e-6; `memory_exp` 221.045546 and 0.083100 within 1e-6. Anything else: stop and ask |
| G9 | Scratch libraries (block below) | `lib-base` loads medfit 0.6.0, `lib-cand` loads 0.7.0; all four dependents load in both |
| G10 (R1) | `R_LIBS=$S/lib-cand NOT_CRAN=true Rscript -e 'devtools::test(filter="sem-probmed")'` | 17 expectations, SKIP 0 (a skip means the gate did not run), FAIL 0 |
| G11 (R1, R3) | Each dependent's suite in both arms, saving the full testthat results (not just names) | Compared per package and per test, `cand` vs `base`: no new failing test; for every test failing in `base`, `cand` has no more failed assertions, no new error, and the same failure messages (first line, srcref stripped); no test present in `base` is missing or reduced in `cand` (`nb` not lower); no new skip without a stated reason. Only demonstrably identical baseline failures are exempt. probmed fully clean in `cand` (R1) |
| G12 | After the bump PR is squash-merged: `git fetch origin`, then compare `git rev-parse origin/dev^{tree}` with the tested tree recorded in `$S/logs/tested-tree.txt` (written when the candidate was built, from `git rev-parse HEAD^{tree}` of the worktree) | Equal. If not equal: re-sync the candidate from `git archive origin/dev`, rebuild and reinstall `lib-cand` from that archive (never reuse the old install or worktree), rerun G1-G6 and G10-G11 (plus G7-G8 if anything under `R/` or `tests/sim` changed), re-record the tree. No cleanup, release PR, or tag until equality holds |
| G12b | Immediately before A5, again `git fetch origin` and the same tree comparison | Equal; this also catches any `dev` push after the bump merge |

G9/G11 commands (download of the four dependents from GitHub is granted by R6; `altdoc` is not):

```sh
mkdir -p $S/{src,lib-base,lib-cand,logs}
git -C ~/projects/r-packages/active/medfit archive --prefix=medfit-0.6.0/ v0.6.0 | tar -x -C $S/src
R CMD INSTALL --library=$S/lib-base $S/src/medfit-0.6.0
(cd $S && R CMD build --no-build-vignettes ~/.git-worktrees/medfit/chore-release-0.7.0)
R CMD INSTALL --library=$S/lib-cand $S/medfit_0.7.0.tar.gz
for p in rmediation probmed missingmed mediationverse; do git clone -b dev https://github.com/Data-Wise/$p.git $S/src/$p; done
for L in base cand; do for p in rmediation probmed missingmed mediationverse; do R CMD INSTALL --library=$S/lib-$L $S/src/$p; done; done
git -C ~/.git-worktrees/medfit/chore-release-0.7.0 rev-parse 'HEAD^{tree}' > $S/logs/tested-tree.txt
R_LIBS=$S/lib-$L NOT_CRAN=true Rscript -e 'cat(format(packageVersion("medfit")), find.package("medfit"), "\n"); res <- testthat::test_local("<src/p>", reporter="silent", stop_on_failure=FALSE); saveRDS(res, "<logs/p-L.rds>"); d <- do.call(rbind, lapply(res, function(t) data.frame(file=t$file, test=t$test, nb=t$nb, failed=t$failed, skipped=t$skipped, error=t$error, msgs=paste(vapply(t$results, function(x) sub("\n.*", "", conditionMessage(x)), ""), collapse=" | ")))); write.csv(d, "<logs/p-L.csv>", row.names=FALSE)'
```

The `.rds` keeps every expectation; the CSV adds the first line of each result message so G11 can compare failures, not just names. Record each clone's SHA in the PR body. If R1, G8 or G11 fails, the release is blocked: triage, open a fix PR into `dev` (squash), then rebuild `lib-cand` from the new `dev` tree (G12 procedure) and re-gate; never rerun against the old install.

## 3. PR sequence

1. **A0 (done):** ledger committed and pushed to `dev` (`871d2e3`).
2. **A1, "make the branch":** `git worktree add -b chore/release-0.7.0 ~/.git-worktrees/medfit/chore-release-0.7.0 origin/dev`.
3. Make the bump edits (section 1); run G0-G8.
4. Run G9-G11 (download already granted for the four repos by R6).
5. **A3:** commit bump and sim results (`chore(release): medfit 0.7.0`), push, `gh pr create --base dev`. Body carries the gate table (G2, G6, G7, G8 with the 2-of-420 note, G10, per-package G11, clone SHAs, the aspell exposure from R10).
6. **A4:** user reports the PR's CI result (no polling by me); then `gh pr merge <n> --squash`; run G12 (fetch, tree equality, rebuild on any difference); only after G12 holds, remove the worktree and delete the local branch (the remote branch is auto-deleted on merge; verify).
7. **Freeze `dev`:** no `chore(status)` pushes until the release PR merges (a push changes the PR head and reruns CI).
8. **A5:** run G12b first, then `gh pr create --base main --head dev --title "Release: v0.7.0"`. Body: NEWS 0.7.0 summary, gate evidence, R2 statement (SE gate and reliability evidence stand on the 2026-10-09 run), `Closes #105, Closes #106` with S17b and probmed counts. #83 stays open.
9. **A6:** user confirms `ubuntu-latest (release)` is green; then `gh pr merge <n> --merge`. Never `--squash`, never `--delete-branch` (would delete `dev`), never `--auto`.

## 4. After the merge

1. **A7, tag:** `git fetch origin && git show origin/main:DESCRIPTION | grep '^Version: 0.7.0'`, then `git tag v0.7.0 <main merge sha>` (lightweight, as `v0.6.0`) and `git push origin v0.7.0`. Never push all tags; never force.
2. **A8, draft release:** copy the `# medfit 0.7.0` NEWS section to `$S/notes-0.7.0.md`, prepend "GitHub and r-universe release; not submitted to CRAN (CRAN has 0.3.2)." and a Docs link (0.6.0 format); `gh release create v0.7.0 --verify-tag --draft --title "medfit 0.7.0" --notes-file $S/notes-0.7.0.md`.
3. **A9, publish:** `gh release edit v0.7.0 --draft=false --latest`.
4. **A10, back-merge:** on `dev`, `git merge --ff-only origin/main && git push origin dev`; if `dev` moved, use the no-ff "chore: back-merge main (v0.7.0 release commit) into dev" commit (0.6.0 precedent `ffd63b3`). Check: `git merge-base --is-ancestor origin/main origin/dev`.
5. **r-universe (only when asked; no polling):** `curl -s https://data-wise.r-universe.dev/api/packages | jq '.[] | select(.Package=="medfit") | {Version, RemoteSha}'`; pass = Version 0.7.0 and RemoteSha = main merge SHA. Do not use `/api/packages/medfit` (404s when healthy).
6. **Site:** check once that https://data-wise.github.io/medfit/news/ shows 0.7.0.
7. **A11, `.STATUS` on `dev`** (`chore(status)`, `.STATUS` only): `version:` 0.7.0 with date, tag SHA, release PR number, r-universe state; `next:` drop "revdep check" and S24, list the R5 items, S1/PR 11 and the CRAN trigger; X0 becomes "reproduced (S0 d); report owed" (F7); add a `release_0.7.0` row with gate numbers; tick S24 in PLAN line 310 noting R5 replaced r-hub and revdepcheck. CLAUDE.md and AGENTS.md change only if the bump-PR text turned out wrong.
8. **A12:** if #105 and #106 did not auto-close, close them with an evidence comment.

## 5. Risks and rollback

| Step | Irreversible part | Rollback |
|---|---|---|
| Release merge (A6) | Merge commit on protected `main`, site deploy, r-universe rebuild | No force-push. Revert through a PR (revert the merge commit on a branch, PR to main with the required check) or fix forward with 0.7.1; prefer fix forward |
| Tag push (A7) | Public ref | Before A9 only: delete the remote and local tag, then recreate on the right SHA (delete and recreate, never force; branch-guard and 0.3.2 precedent). After A9: never move it; ship 0.7.1 |
| Release (A8/A9) | Public notes, "Latest" label | Draft step catches errors; `gh release edit --notes-file` fixes text; `--draft=true` unpublishes; deleting the release is the user's action |
| r-universe | Serves `main` HEAD | Cannot be unpublished; fix forward |
| Issue closure | Visible state change | `gh issue reopen` |
| Gate drift | `dev` moves or the bump PR changes after gating | Rerun G12 and the affected gates |
| Gate breakage | Parity count above 2 or outside `latent.50`; a probmed failure in `cand` only | Stop, ask, do not release (R1) |

## 6. Appendix: R5 items (after the tag; each needs its own explicit go)

- **(a) `[BREAKING]` issue in medfit:** title "[BREAKING] fit_mediation() gains a named model argument (0.7.0)". Body: what binds now (`model = FALSE`, or `mod =` passed through `...` to `glm()`, both intercepted and an error with the glm engine); migration (drop the argument; `glm()`'s `model` cannot be forwarded through `fit_mediation()`, unless D-fwd adds a mechanism); grep result (F11: no direct caller; missingmed forwards `...` and `fit_args`); D15 accepted the break with a NEWS note, so this issue serves as the notice.
- **(b) RMediation `mbco()` X0 report:** first draft `planning/specs/REPORT-rmediation-mbco-x0-<date>.md` in medfit (commit on `dev` with a go). Content: the Rd example's `mxPath(from="x", to=endVar, labels=c("a1","a2","cp"))` drops the self-path, so labels shift to `a2, cp, a1`; as written diffLL is 0.060332, correctly labeled 221.045546 for `a1 == 0` and 0.083100 for `b1 == 0`; reproduction `planning/specs/evidence/native-sem-2026-10-08/07-preflight.R`; suggested fix: drop `"x"` from `endVar` in that path. Filing in Data-Wise/rmediation is a cross-repo write, only on explicit request.
- **(c) Ecosystem row E1 (R9):** draft the version-matrix row as text in a medfit planning file; apply to `~/projects/r-packages/mediation-planning/docs/ECOSYSTEM-COORDINATION.md` only on explicit request, on a branch the user picks (that repo is on `docs/missingmed-0.6.0` with an untracked `AGENTS.md`).
- **Out of scope:** r-hub, full revdepcheck, medrobust's suite, S1/PR 11.
