# PLAN: medfit 0.11.0 scope (2026-10-16)

**Status:** APPROVED 2026-10-16, revised 2026-10-16 (harness and test matrix added) and 2026-10-17 (progress, the reliability regression, the label decision, Checkpoint 2 result) by the author (Option B; D2 floor only with nonlinear constraints, D3 reversed 2026-10-17: drop the label when tested enough, D4 no F7, D5 latent means 1.0; D1 closed 2026-10-17: not forced). Produced by a read-only Plan agent (Opus) from
`.STATUS`, the two 0.10.1/0.11.0 proposals, the roadmap, the specs, NEWS, and open issues and PRs. Two claims were
re-checked by hand: PR #214 and issue #213 exist as described. Not verified: that CRAN 0.3.2 fails under development
S7 (inferred from the shared nullable-union pattern), the S7 1.0 CRAN date, whether #214 passes medfit's suite, and
whether probmed adopted `fit_sem()` for P_med MBCO or only evaluated it.

## Progress (2026-10-17)

| Task | State | Where |
|---|---|---|
| T1 S7 compatibility | merged | #219 `d869dc1` |
| T1b S7 lifecycle gate | merged | #220 `c2ad36c` |
| T2, T3 #213 red tests and fix | merged; #213 stays open until the release | #221 `ecc241c` |
| T4 factor gate registration | merged | #222 `b909a7f` |
| T5 exit criteria | merged: criteria file `planning/specs/CRITERIA-native-experimental-exit-2026-10-17.csv`, decisions in `GRILL-native-experimental-exit-2026-10-17.md`, `test-experimental-criteria.R`; three more native gates registered (`nonlinear-parity`, `fixed-x`, `mean-constrained`; 18 gates in `gates.csv`) | #225 `7169d08` |
| T5b reliability regression (unplanned) | merged | #226 `41d97d4` |
| T5c drop the label (D3 reversed) | merged | #227 `0d1a732` |
| T5d CI: R-CMD-check on `main` only, dev gated locally (unplanned) | merged | #224 `d40e171` |
| T5e gate hardening from the Codex adversarial review | merged | #229 `5a1f127` |
| T6a to T6c vacuous Heywood test, product-test warnings, unconditional skip replaced by the `bootstrap-coverage` gate (19 gates in `gates.csv`) | merged | #231 `28fd907` |
| T6e `.STATUS` | merged | #232 `047a90f` |
| Plan updates | merged | #228, #230 |
| T6d, T6g, T6h | open (T6d watch-only; T6g at the release; T6h the author's `git branch -D`) | below |
| Checkpoint 2 | **PASSED 2026-10-17 on `dev` `047a90f`** | below |
| R1 freeze test, R2 gates in CI, R3 S7 weekly watch, R4 Codex review and fixes, single-start warning | merged (#234, #237, #239, #240, #241); issue #238 open (floor fixture on reference BLAS, report-only in CI), not a blocker | step 8c, 8b |
| Version bump to 0.11.0 (DESCRIPTION, NEWS, README, guide-changes, .STATUS, CLAUDE.md) | merged | #242 `10cc3a1` |
| Worked GPA example article (unplanned) | merged | #243 `b2fe4ea` |
| Release PR, tag v0.11.0, GitHub release, #130 closed | **released 2026-10-17** | #244 `35941ee` |
| r-universe check, soak (G7), CRAN | open | step 10 |

**T5b, what happened.** The first full `run-gates.R --sim` on current code was not green: the reliability gate had 4 of
9600 shipped-configuration fits ending `no start converged` (latent, n = 50, replicate 4, random start, the same dataset
at four data scales; 0 at the 2026-10-09 baseline). Bisect: first bad commit 054c702 (T12 renaming), which changed the
parameter order and so the random draw; the 10-09 pass was luck of the draw, not a property of the engine. Cause: the
retries are perturbations of the supplied start, so a start in a bad basin gives five bad attempts (attempt 1 stalled at
f 0.338 against the optimum 0.231 with a non-PD reduced Hessian; the rest hit maxeval). Production `fit_sem()` with the
default start converged on the same data. Fix in #226: with `n_starts >= 3` the last attempt is the model's own default
start; nonlinear-row models keep their starts. Gate 6 of 6, match rate 1.0000. Lesson for the plan: **baselines older
than the code are not evidence**; the 10-09 to 10-11 baselines of parity, constrained, se and reliability had not been
rerun after the mean-structure, product, factor and #213 work until this run. Every gate was rerun on 2026-10-17 on the
rebased branch of #227 (18 of 18 PASS, 105 of 105 checks).

**T5c, the label.** The author reversed D3 on 2026-10-17 ("drop the experimental if it's been tested enough"). The
criteria were checked, not assumed: C2 to C4 hold after #226; C1 is the open-issue list (#213 fixed, #130 a breaking
change notice, #83 the CRAN 0.3.2 issues), because the repo has no `correctness` label to query. #227 carries the
change and the evidence; NEWS states the freeze.

**T5e, Codex adversarial review (2026-10-17, medium; DONE, #229).** `tests/sim/sem-factor-gate.R` passes a run when `lavaan` is not
installed (`(ok(out$lavaan) | !lav_ran)`), and the driver checks only `pass` and `err`, so the 680-run gate can succeed
with every lavaan and fit-statistic parity check skipped. Verified in the source. The 2026-10-17 baseline ran with lavaan
installed, so the evidence stands, but the criterion C3a ("lavaan parity") is not enforced where lavaan is absent.
Done in #229: the factor, fixed-x and mean-constrained scripts stop without lavaan (the three `requireNamespace`
conditionals in `tests/sim/` were the only skip-tolerant spots; parity, constrained, se and nonlinear-parity call
`library(OpenMx)` or `lavaan::` unguarded and already error); the driver requires the lavaan checks to have run and
has a `no_lavaan` mutation for all three (each rejected); each script run with lavaan stubbed out exits 1.

**Second Codex adversarial review (2026-10-17, "the PRs"; no new finding).** It reviewed the local branch
`feature/factor-gate-registration` (`dd42073`, the T4 branch in the main checkout, 295 files against `main`), which
predates #229, and repeated the same finding at `sem-factor-gate.R:299-301`, now rated high. Disposition: already
fixed on `dev`. What it did not do: review the other PRs it was pointed at (#224 to #228, the optimizer fallback in
#226, the label change in #227), because its target was the stale checkout. A review of those needs `--base dev` from a
branch that contains them, or a review run inside the worktree of each PR; not run, and not claimed.

## Recommendation: Option B (middle), about 3-4 working days

Ship everything on `dev`, plus **#214** (S7 compatibility), a **narrow fix for #213**, and a written
**exit-criteria file for the "experimental" label**. Latent means, Ext D module 2 and Ext E stay out.

1. **#214 cannot wait.** An S7 maintainer opened it today: medfit "fails to install or load with development S7".
   S7's main branch heads a 1.0.0 with breaking changes. CRAN 0.3.2 has 18 nullable property unions (dev has 23), so
   CRAN medfit is likely exposed too. That would be a third CRAN trigger outside GRILL-0.8.0-release R1.
2. **#213 is the only item with a named consumer** (probmed, evaluating `fit_sem()` for MBCO intervals). Reproducer and
   workaround (`Vm > 1e-4`) are in the issue.
3. **The `dev` content is done and green:** strict check 0/0/0, 6340 tests pass, docs gaps closed (#216, #217).
4. **"Drop experimental at 0.11.0" is a recorded commitment** (`.STATUS` `fixed_x_and_experimental`, GRILL G13, criteria
   undefined), and RMediation's CRAN hold depends on it. Write the criteria now; drop the label at the first release
   that meets them.

## Candidates

| # | What | Size | Risk | Consumer |
|---|---|---|---|---|
| F1 | Ship `dev` as is (factor covariates, covariate-mean variance, AIC/BIC guard, docs) | S, ~0.5 d | low | users, probmed |
| F2 | S7 compatibility, PR #214 (targets `main`; port to `dev`) | S, 3-5 h | med (`.onLoad`/`.onUnload`) | everyone |
| F3 | #213: variance floor or step rejection only with nonlinear constraints; flag a status-3 stop far above the optimum | M, 1-1.5 d | med (optimizer behavior) | probmed, RMediation |
| F4 | Exit criteria for "experimental" | S, 1-2 h | low | RMediation |
| F5 | Register the factor gate in `run-gates.R`/`gates.csv` | S, 2-3 h | low | release evidence |
| F6 | Triage the 2 skips and 42 warnings; pandoc `--mathjax` deprecation | S, 2 h | none | maintainers |
| F7 | `bootstrap_mediation()` helper for four-way | S-M, 0.5 d | low | users (recipe 20 covers it) |
| F8 | Latent means | L, 5+ d | med-high | none named |
| F9 | Ext D module 2 (1-1-1) / Ext E | L, weeks | high | none named |
| F10 | Hygiene: close #130, refresh roadmap Next Actions | S, 1 h | none | none |
| F11-F13 | Categorical variables: k-level treatment (B1), categorical mediator (B2), native binary and ordinal endogenous variables (B3). Out of 0.11.0; recorded in the roadmap's Next Actions item 6 with sizes and the supported routes (added 2026-10-17) | M-L, M-L, L | med-high | none named |

## Options

| | A Minimal | **B Recommended** | C Ambitious |
|---|---|---|---|
| Includes | F1, F2 | F1-F6, F10 | B plus F7, F8 |
| Effort | ~1 d | ~3-4 d | ~2 wk |
| Slips | nothing | F3 if it changes unconstrained fits | F8 (identification, parity gates) |
| Downside | ships a known probmed bug | slightly later | feature with no consumer |

**Third Codex adversarial review (2026-10-17, empty arguments; no new finding).** Same stale target again: the checkout
is on `feature/factor-gate-registration` (`dd42073`, 295 files against `main`), and with no `--base` the review takes
the checked-out branch. Same finding, `sem-factor-gate.R:299-301`, already fixed by #229. Three runs have now reviewed
one merged T4 branch; none has reviewed #224 to #228, #231 or the 0.11.0 diff as a whole. Fix the cause, not the
repetition: see Checkpoint 3.

## Tasks for B (feature branch from `dev`, squash to `dev`, red tests first, suite green after each)

1. **T1 S7 compatibility:** port #214 onto a `dev` branch (or ask the contributor to retarget it to `dev`; never
   `main`); fold its NEWS bullet into the development section; red test `test-s4-registration.R`; suite on S7 0.2.2 and
   `RConsortium/S7@main`; e2e transcript (install, load, unload, reload).
1b. **T1b S7 lifecycle gate (DONE, #220; added after the Codex review of T1, 2026-10-16; blocks Checkpoint 2):** the review found
   that T1's tests run in the existing test process, so they cannot catch the failure that was reported (it appeared
   only in an installed package). The two-version install, load, unload, reload and `fit_sem()` transcript from #219 was
   run by hand (`/private/tmp/.../e2e-s7.R`), never as a gate, and `tests/sim/gates.csv` has no S7 row. Build
   `tests/sim/s7-compat-gate.R`: `R CMD INSTALL` the working tree into a scratch library, run each step in a fresh
   `Rscript` against S7 0.2.2 and `RConsortium/S7@main` (both in scratch libraries, skip with a message if `main` is
   not installable offline), exit 1 on any step failure; register it in `run-gates.R` and `gates.csv`; `MUTANT=nounion`
   (omit `medfit_numeric`) and `MUTANT=noonload` (skip the `.onLoad()` union call) must exit 1 on dev S7. Built on
   `feature/s7-lifecycle-gate`: a `nohook` mutant (skip the `S7_on_load` branch) was tried and NOT caught on S7@main,
   so that branch is not load-bearing for this flow and no claim is made about it. Fix the false
   "fresh R process" sentence in the header of `test-s4-registration.R` (the gate is the fresh-process check; the
   testthat file checks the registry only). Size: S, 2-3 h; do before T2 so every later checkpoint includes it.
2. **T2 #213 red tests (built, `feature/issue-213-variance`):** `test-sem-nonlinear-variance.R`: seed 1 (errors,
   "no start converged"), seed 101 (a = 2.5, b = 1.5, sigma_Y^2 = 2; LR 1458.9, NaN SEs, `converged` TRUE), the same two
   at the default `n_starts` (both error today), a positivity check, and two frozen fits (unconstrained, linear
   constrained). Adverse review 2026-10-16, run by hand: the repro is deterministic; the issue's workaround turns every
   case green (LR 0, finite SEs), so the tests are satisfiable; the first draft's `expect_no_warning` also forbade the
   legitimate "starts disagree" note and was replaced by a NaN-only check. Known limits: frozen fits use
   `tolerance = 1e-9` (cross-platform), not bit identity, so T3 must also compare `identical()` on the real outputs
   locally; only one constraint form (`a*b/sqrt(2*(b^2*Vm+Vy)) == q`) and no inequality, `mbco_sem()` or zero-product
   branch case is covered yet (added to T3a).
3a. **T3a diagnose (DONE 2026-10-16; report `planning/REPORT-213-investigation-2026-10-16.md`):** prototypes plus a
   ChatGPT answer and an Opus review that ran R. Findings: seed 1 is a negative-variance step (NaN in the constraint
   value at the SLSQP iterate); seed 101 is a strict local minimum on the opposite sign branch (reduced Lagrangian Hessian
   eigenvalues 150, 20.5, 6.1, 0.48), so no gate can reject it. No single fix works at `n_starts = 5`: floor alone 4 of
   480 silent wrong fits, reference start alone 28 of 384 failures (q mirrored or +-0.5). Decision pending the author's
   GRILL on the improper-solution policy; recommended design in T3.
3. **T3 #213 fix (nonlinear rows only):** (1) a floor relative to the data scale (`1e-4 * .sem_step_floor()` unit) on the
   variances in a nonlinear row, with a warning and `floor_active` when it binds; (2) the unconstrained (relaxed) fit as
   first start and as an incumbent; (3) sign-flipped copies of it (all patterns for k <= 3 path labels, else the joint
   flip); (4) a dominance rule (never return an accepted fit worse than a feasible reference) and a lower-bound
   warning. Replaces the "status-3 flag" (status 3 is medfit's routine stop). Oracle: `tests/sim/oracle213.R`
   (independent profile inversion, executed; compare at the achieved q, not the nominal one, because the 2.5e-7 target
   is below the constraint-residual effect of about 2.7e-6). Gate `tests/sim/sem-nonlinear-profile-gate.R` with the 30
   fixtures in the review (section 4.4) and seven planted defects; `identical()` checks on every legacy path; rerun the
   672 emulated cases against the real code; NEWS behavior note; e2e with the reproducer. Cost about 2x for nonlinear
   fits.
4. **Checkpoint 1:** adversarial review of T3; if any unconstrained fit changes, narrow the fix.
5. **T4 factor gate registration:** verdict function, `gates.csv` row, `MUTANT=` defects exit 1.
6. **T5 experimental-exit GRILL (DONE, #225; the label itself is T5c, #227):** criteria (no open correctness issue on the engine, every native gate registered and
   green, lavaan and OpenMx parity green, an API freeze list); record the decision; the author pastes the RMediation
   message.
7. **T6 hygiene (T6a to T6c, T6e DONE in #231 and #232; triaged 2026-10-17 against `dev` at `0d1a732`; full suite 6392 passed, 0 failed, 2 skipped, 42 warnings):**
   - **T6a Vacuous Heywood assertion (a real test defect, found by the warning triage).** In `test-sem-optim.R` ("a Heywood
     case matches lavaan, warns, and names the negative variance") the lavaan names are built with spaces
     (`m2 ~ eta`) but `theta` is named without them (`m2~eta`) since the T12 renaming, so `names(est) %in% names(fit$theta)`
     matches 0 of 11, `max()` of nothing is `-Inf` (the one non-product warning) and `expect_lt(-Inf, 1e-6)` passes. The
     test has compared no estimate with lavaan since 2026-10-11. Fix: build the lavaan names the way the package names
     them, assert the number matched equals `length(fit$theta)`, and plant the defect (shift one estimate) to see it fail.
     Then grep the tests for the same pattern (`%in% names(` followed by `max(abs(`) and require a nonzero match count
     where one is expected. Size S, 1 h; this is the only T6 item that could hide a regression.
   - **T6b 41 of the 42 warnings** are two intended user-facing advisories raised by tests that fit product models for
     another purpose (`test-sem-product-materialize.R` 29, `-mean.R` 8, `-rules.R` 4): the `se_type = "model"` advisory
     for a product, and "the model test is not valid" for an endogenous product factor. Wrap those fits in one helper that
     suppresses exactly these two messages and keep the tests that assert them. Size S, 1 h; no behavior change.
   - **T6c the 2 skips:** `test-bootstrap.R` ("parametric bootstrap achieves nominal CI coverage") is an unconditional
     `skip("Simulation test - run separately for CI coverage validation")` with no gate behind it: register it as a gate
     or delete it (a skipped test is not evidence). `test-extract-lavaan.R` ("errors without lavaan installed") skips
     whenever lavaan is installed, which is by design.
   - **T6d pandoc `--mathjax` deprecation:** raised by the pkgdown build (`math-rendering: mathjax`), rendering succeeds.
     Upstream, not fixable in the package short of switching the renderer; record as watch-only, not a release blocker.
   - **T6e `.STATUS`:** the `next:` field still describes the 0.10.0 release, the RMediation #41 merge (`d29685f`) is not
     recorded, and `release_0_11_0` stops at T4. Rewrite it from this plan's progress table (once, not repeated in
     CLAUDE.md or memory).
   - **T6f roadmap:** Next Actions refreshed in #228; nothing further.
   - **T6g issues at release:** #213 closes with the release PR (its fix is #221); #130 closes (the `[BREAKING]` notice, no
     work left); #214 gets a closing comment (ported to `dev` as #219, the contributor was asked to retarget); #83 stays
     open until the CRAN decision (D1).
   - **T6h local cleanup:** eight worktrees under `~/.git-worktrees/medfit/` and their merged branches; several need the
     author's `git branch -D` because branch-guard blocks the agent. Add the main checkout itself: it sits on the merged
     `feature/factor-gate-registration`, which is what pointed three Codex reviews at a stale branch; moving it to `dev`
     is the author's call.
8. **Checkpoint 2 (release gate):** full suite, `lintr` after `load_all()`, strict check (CLAUDE.md recipe),
   `urlchecker::url_check()`, `spelling::spell_check_package()`, and `Rscript tests/sim/run-gates.R --sim` in full on the
   release commit (after T5e). R-CMD-check no longer runs on `dev` PRs (#224), so the strict check and
   `scripts/check-local.sh` here, plus R-CMD-check on the `dev` to `main` PR, are the only R CMD check evidence.
   **Result (2026-10-17, scratch worktree at `dev` `047a90f`, nothing changed):** suite 6397 passed, 0 failed, 1 skipped
   (lavaan-absence test, by design), 0 warnings; `lintr` 0 lints; spelling 0; `urlchecker` 45 URLs all correct; strict
   check (`--run-donttest` plus the four `_R_CHECK_*` variables) 0 errors, 0 warnings, 0 notes; `run-gates.R --sim` 19 of 19
   PASS, 111 of 111 checks (7 min 25 s); `scripts/check-local.sh` PASS. The release commit differs from `047a90f` by the
   version bump, NEWS and status files, so rerun the cheap items (suite, lintr, `check-local.sh`) on it; the 7-minute gate
   run only if `R/` or `tests/sim/` change.
8b. **Checkpoint 3 (Codex review of the actual scope, before the release PR; first run 2026-10-17, one finding, coverage thin):**
   Run once from the `dev`-based worktree `docs-plan-checkpoint2` against `main` (323 files, 0.11.0 scope plus plan docs).
   Its one finding is accepted: S3 of the S7 plan was marked DONE on a weaker test than the one it names (corrected in
   that plan; S3b is open). It raised no code finding, but its transcript shows only two diff reads (the factor gate
   files and the S7 plan), so absence of findings is not evidence the 0.11.0 code was reviewed. Before the release PR,
   rerun with focus text naming the code (`R/sem-optim.R` start fallback, the gate verdicts in `tests/sim/run-gates.R`,
   the label drop, `.github/workflows/R-CMD-check.yaml`) and treat that second run as the checkpoint. Original spec: from a worktree of `dev` run
   `/codex:adversarial-review --base v0.10.0 --background`, or `--base main` once the bump commit exists, so the target is
   the 0.11.0 diff (the optimizer fallback #226, the label and criteria #225/#227, the gates #229/#231, CI #224) and not
   whatever the main checkout has checked out. Disposition each finding in this plan as for T5e; a finding that reproduces
   on `dev` blocks the release PR. Not run yet; the three earlier reviews do not count toward it.
8c. **Pre-tag work from the 2026-10-17 grill** (ledger `planning/specs/GRILL-0.11.0-release-2026-10-17.md`, G1 to G9; order R1,
   R2, R3, then 8b, then the bump; each its own PR to `dev`, red test or planted defect first where behavior is claimed):
   - **R1 freeze reservation (G3), S, 1 h:** a "reserved additive extensions" paragraph in the NEWS Lifecycle entry and the
     native model page (new syntax may be added; existing names, rows and properties never change meaning), plus a test
     pinning the current canonical names (`m:x` rows, `SEMFit` property names, `?medfit-syntax` grammar tokens). Done when
     renaming a pinned name fails the test (planted defect).
   - **R2 gate in CI (G2, G6), M, 2-3 h:** a workflow running `Rscript tests/sim/run-gates.R --sim` on PRs to `main` and
     `workflow_dispatch`, installing lavaan, OpenMx and nloptr. Non-required first; required status check on `main` only
     after two consecutive green Linux runs (fix Linux-only drift by tolerance, seed or fixture, with evidence, before
     requiring it). Done when it is required and a planted defect (`MUTANT=`) turns the run red.
   - **R3 S7 watch (G4), S-M, 2 h:** a weekly scheduled workflow that runs the `s7-lifecycle` gate on S7@main and compares
     CRAN's S7 version with the last seen one, opening an issue on a change; allowed to fail. Done when a manual dispatch
     passes and a forced version change opens an issue.
   - **R4 Checkpoint 3 (G9):** one focused Codex run after R1-R3 land, from a `dev` worktree; focus text names the start
     fallback (`R/sem-optim.R`), the gate verdicts (`tests/sim/run-gates.R`), the label drop and the two workflows. Pass
     rule: every finding is reproduced on `dev` before it counts; a reproduced finding on the 0.11.0 code blocks the tag.
9. **Release:** bump to 0.11.0; NEWS header; `.STATUS` and CLAUDE.md "Current status"; grep for "0.10.0" leftovers;
   `dev` to `main` merge-commit PR with the evidence summary; CI green on `main`; tag `v0.11.0`; GitHub release;
   r-universe via the packages list (allow about 2 h, no manual dispatch); pkgdown deploys from `main`; back-merge.
10. **Soak, then CRAN (G1, G7, G8):** the soak ends when probmed's suite and RMediation's suite pass against the tag
   (read-only runs), the r-universe build is green and the CI gate is green on `main`; it may end in 2 to 3 days. Then the
   CRAN routine (strict checks, `urlchecker`, spelling, `cran-comments.md` resynced from a fresh run, maintainer-manual
   `submit_cran()`). RMediation does not submit its SEMFit-pair feature until medfit 0.11.0 is accepted; send RMediation
   the "experimental dropped" message now (the author pastes it). Update `.STATUS` ("CRAN submission remains on hold") and
   the R1 triggers of `GRILL-medfit-0-8-0-2026-10-11.md`.

## Harness and test matrix (added 2026-10-16)

Every task ships a red test, a registered harness gate where behavior is numeric or environment-dependent, and a
planted defect (`MUTANT=` in `tests/sim/`, `sem_mutate()` in testthat) that must make the gate exit 1. Gates are
rows in `tests/sim/gates.csv` run by `tests/sim/run-gates.R`; no gate is "run by hand".

| Task | testthat (fast, in the suite) | Harness gate (`tests/sim/`) | Planted defect | Evidence in PR |
|---|---|---|---|---|
| T1 S7 compat (merged #219; gate = T1b) | `test-s4-registration.R`: unions registered, `show()` with `call = NULL`, hooks all-or-none; `.register_s4_unions()` idempotent (guard each `setClassUnion` with `isClassUnion()`, so a second call is safe and covered for codecov) | `s7-compat-gate.R`: install the built tarball into a scratch library, then load, unload, reload and `fit_sem()` once under S7 0.2.2 and under `RConsortium/S7@main`; exit 1 on any load error | drop the `medfit_numeric` line; skip the `.onLoad()` union call | two-version transcript |
| T2 #213 red tests | the issue's two seeds (LR near 0 at the unconstrained estimate) fail first; frozen unconstrained fixture (bit-identical) | none yet (T3 adds it) | n/a (red phase) | red output quoted |
| T3 #213 fix | seeds green; non-convergence flag on a far status-3 stop; unconstrained fixture still bit-identical | `sem-mbco-213-gate.R`: 30-case profile inversion agrees to about 2.5e-7; reuses `sem-nonlinear-gate.R` helpers; also asserts the full existing nonlinear and constrained gates stay green | remove the floor; weaken the status-3 flag | gate transcript, before and after counts |
| T4 factor gate | `test-run-gates.R`-style check that the gate is listed and its verdict function returns FALSE on a mutant | register `sem-factor-gate.R` in `run-gates.R` and `gates.csv` | existing `MUTANT=` set in the gate | `run-gates.R` summary table |
| T5 exit criteria | `test-experimental-criteria.R`: each criterion names a gate id that exists in `gates.csv` and a docs page that exists | the criteria are the gate list: all native gates in `gates.csv` pass | delete a gate row; the test must fail | criteria file and the passing run |
| T6 hygiene | none beyond the triage notes | none | none | `.STATUS` notes |

Cross-cutting:

- **Harness registry:** after T1, T3 and T4, `Rscript tests/sim/run-gates.R` is the single release gate; Checkpoint 2
  runs it in full (not a subset) next to the strict check.
- **Environment matrix:** the S7 job runs on S7 0.2.2 (CRAN) and `RConsortium/S7@main`; the dev-S7 job is allowed to
  fail CI until S7 1.0 is released and is run locally in the meantime (scratch library, as in T1's transcript).
- **Coverage:** load-time code (class unions, `.onLoad` branches) needs a callable, idempotent function to be
  measured; codecov ignores `R/zzz.R`, so logic goes in the covered file and `zzz.R` only calls it.
- **No new test without an oracle:** numeric claims use an independent oracle (profile inversion, lavaan, OpenMx, hand
  calculation); a test with no failure mode does not count.

## Decisions for the author

| # | Decision | Recommended |
|---|---|---|
| D1 | Does S7 1.0 force CRAN action, and how: a 0.3.3 patch from the v0.3.2 tag, or submit 0.11.0? | **CLOSED 2026-10-17: not forced.** S7 1.0.0 is unreleased (CRAN has 0.2.2, 2026-04-22; `NEWS.md` on `main` has a 1.0.0 section, no date); no CRAN mail about S7 or medfit since the 2026-08-12 maintainer check; CRAN checks of 0.3.2 are OK on 13 of 13 flavors. Release 0.11.0 GitHub-only; re-check when CRAN's S7 page shows 1.0.0 or a CRAN mail arrives. Original guidance, kept for that trigger: confirm the S7 date and any CRAN mail first. If forced, submit 0.11.0 (it also fixes the #83 bugs and unblocks probmed's `medfit (>= 0.3.0)` gate); fall back to 0.3.3 only if the deadline is under 2 weeks |
| D2 | #213 scope: floor only with nonlinear constraints, or always | Only with nonlinear constraints (an always-on floor changes every fit) |
| D3 | Drop "experimental" in 0.11.0 | REVERSED 2026-10-17 by the author: drop it when tested enough. The criteria are met after #226 (18 of 18 gates PASS); #227 removes the label |
| D4 | Include F7 | No, recipe 20 covers it |
| D5 | Latent means | 1.0, or later if no consumer appears; record in the roadmap |

## Risks

- S7 1.0 has other breaking items (`convert()`, subclass constructors, `S7_on_build()`); a grep found no `convert()` or
  `parent =` in the class definitions, but there was no full audit.
- The #213 fix may move optimizer paths in existing constrained fits; frozen fixtures and gates are the guard.
- `mediation-planning/PROJECT-HUB.md` is stale (lists medfit 0.2.1); the roadmap's Next Actions is stale (2026-10-10).
- RMediation's own "mature" trigger is undefined (its `.STATUS`, 2026-10-13 hold).
- The label now promises a frozen API (signatures, `SEMFit` properties, the `?medfit-syntax` grammar). Numerical output of
  SEMFit methods, the `medfit.*` options and condition classes are not frozen; a reader may assume they are.
- Gates that depend on Suggests (lavaan, OpenMx) could pass or skip silently in a lean environment: fixed for the three
  skip-tolerant scripts in #229 (they stop, with a driver mutation); a new gate added later can reintroduce it, so a
  gate script must `stop()` on a missing dependency, never skip. The one remaining skip in the suite is by design.
- Review targeting: `/codex:adversarial-review` with no `--base` reviews the checked-out branch. A stale checkout gives a
  review of old code (three times so far); name the base and run it from the worktree under review.
- A random-start gate is sensitive to the draw (T5b): any change to parameter order or naming can move it; rerun the
  reliability gate after such a change.
