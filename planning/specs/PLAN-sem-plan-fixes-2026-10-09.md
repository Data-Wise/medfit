# PLAN: apply the three reviews to the native SEM plan, and fix the lavaan-route names bug

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Status** | **IN PROGRESS** (2026-10-09). T0, T1-T7 and T14 done; T8 (sweep and review) is next; workstream B (T9-T13) is running in its own worktree. |
| **Spec** | [SPEC-sem-plan-fixes-2026-10-09.md](SPEC-sem-plan-fixes-2026-10-09.md), APPROVED 2026-10-09 (fix ids F1-F22, modules `plan-fixes`, `lavaan-probmed-names`, `spec-errata`) |
| **Edits** | [PLAN-native-sem-implementation-2026-10-09.md](PLAN-native-sem-implementation-2026-10-09.md) and [GRILL-native-sem-implementation-2026-10-09.md](GRILL-native-sem-implementation-2026-10-09.md) |
| **Task list location** | This file. The skill's default `tasks/todo.md` is not used: `.Rbuildignore` ignores `^planning$` but not `tasks/`, so a new top-level `tasks/` would ship in the tarball. Repo convention is `planning/specs/PLAN-*.md` with embedded checkboxes. |

## Overview

Two independent workstreams, run in two worktrees in parallel.

- **A. `plan-fixes` (docs, one PR into `dev`):** apply fixes F1-F22 to the SEM implementation plan and ledger, record decisions D9-D16, and review the result.
- **B. `lavaan-probmed-names` (code, one PR into `dev`):** make lavaan-derived `MediationData` carry the `m_<X>`, `y_<M>`, `y_<X>` names so `probmed::pmed(method = "parametric_bootstrap")` works. This fixes a bug that exists today and gives plan task S17b its prerequisite.

`spec-errata` is only drafted here (inside T7). The frozen grammar spec is not edited.

## Architecture decisions

- **One plan file, many edits, so sequence the plan edits (T1 to T7).** They all touch the same two documents; parallel edits would conflict. The only parallelism is workstream A against workstream B.
- **Verify first, then edit.** Every reviewer claim already has a Verify column in the spec; each task closes by running its greps or tests.
- **Tests before code in B (T9 red, T10 green).** The probmed failure reproduces today, so the red test is real.
- **No SEM engine code anywhere in this plan.**

## Dependency graph

```text
T0 worktree + land spec/plan ──┬─> T1 -> T2 -> T3 -> T4 -> T5 -> T6 -> T7 -> T8 ──> CHECKPOINT A (docs PR) -> T15
                               │
T14 file medfit issue ─────────┴─> T9 -> T10 -> T11 -> T12 -> T13 ──> CHECKPOINT B (code PR) ──┐
                                                                                               v
                                                                         T16 close-out (.STATUS, worktrees)
```

T4 (S17b) refers to workstream B by name only; it does not wait for B to merge.

## Task list

### Phase 0: set up and track

- [x] **T0: Worktree and landing (XS).** *(done 2026-10-09: `~/.git-worktrees/medfit/feature-sem-plan-fixes`, branch `feature/sem-plan-fixes` off `dev` at `23724a0`; both files moved in, main checkout clean, markdownlint 0 hits on MD056/MD038/MD040/MD032.)* Create `feature/sem-plan-fixes` off `dev` (explicit go-ahead given in the approval of this plan; create nothing else). Move the spec and this plan into it.
  - Acceptance: both files tracked on the branch; main checkout clean.
  - Verify: `git -C <worktree> status --short` shows only the two files; `markdownlint` has no MD056, MD038, MD040 hits.
  - Files: `SPEC-sem-plan-fixes-2026-10-09.md`, `PLAN-sem-plan-fixes-2026-10-09.md`. Depends on: none.
- [x] **T14: File the medfit issue for the existing bug (XS).** *(done 2026-10-09: [#106](https://github.com/Data-Wise/medfit/issues/106).)* Title: "lavaan-derived MediationData breaks probmed's parametric bootstrap (missing m_/y_ names)". Body: the verified table (glm names versus lavaan names), the `subscriptOutOfBoundsError`, scope (observed single mediator, plugin and nonparametric run), the proposed fix, and a link to the spec. Decision D16.
  - Acceptance: issue open on `Data-Wise/medfit`, links this plan, no labels invented.
  - Verify: `gh issue view <n>` shows the body; record the number in T9's test header and T13's PR body (it is #106).
  - Files: none. Depends on: none.

### Phase 1: workstream A, `plan-fixes` (sequential, one worker)

- [x] **T1: Scale-free acceptance gate (M). Fixes F1, F7.** *(done 2026-10-09: Q14, R12, S5/S6/S14/G2 edits; Q14 cited 10 times, unit-invariance in Q14, S5, S6, S14, G2, R12.)*
  - Acceptance:
    - New decision Q14 in section 3: stationarity measured by a scale-free quantity (Newton decrement on the reduced Hessian), model kept in original units, threshold calibrated in S6 and not frozen before.
    - Q9 amended: a near-singular Hessian at an accepted point triggers the retry.
    - S5 gains the unit-invariance test (data x0.01 and x1000 give identical accept or reject decisions and estimates equal in SE units) with its planted defect, plus the conditioning pre-scale experiment (kept only if S5's data say so).
    - S6 calibrates the threshold across the K10 structures and the scale cells; S14 and section 6.1 G2 and G3 cite Q14.
  - Verify: `grep -n "Q14" PLAN` finds the decision and at least four citations; `grep -n "unit-invariance" PLAN` finds S5, S6 and S14; the old `max(1, max` wording survives only in a quoted citation of the spec.
  - Files: PLAN, GRILL. Depends on: T0.
- [x] **T2: Constraint-gate hygiene (S). Fixes F2, F3, F4, F6, F9, F10.** *(done 2026-10-09: Q10 bound-row signs, S14 sign check on bounds, rank-deficient skip, scaled windows, D14 tolerance, S5 clamp; evidence labels corrected so only checked items are marked [V].)*
  - Acceptance:
    - Q10 states the signs: a lower bound is column `-e_i` (`c = l_i - x_i`), an upper bound `+e_i` (`c = x_i - u_i`).
    - S14's warn-only check also covers active bound rows; it is skipped, with a message, on a rank-deficient active set.
    - S14's feasibility and active-set windows scale with the constraint gradient norm.
    - S14's warn tolerance is defined in the Q14 units and cites D14, starting value `-1e-3`, fixture margin at least 200x.
    - S5 clamps perturbed starts into `[lb, ub]` with a planted defect (an unclamped start must fail a test).
  - Verify: `grep -n -E "clamp|rank-deficient|-e_i|\+e_i" PLAN` finds each; no remaining "multiplier sign unchecked" text.
  - Files: PLAN. Depends on: T1.
- [x] **T3: Numeric hygiene (XS). Fixes F5, F8.** *(done 2026-10-09: S3 gradient sentinel, S25 NNLS scaling and step guard.)*
  - Acceptance: S3 gives the analytic gradient the same non-positive-definite sentinel path as the objective (planted defect: an indefinite start through the gradient must not error); S25 scales the NNLS columns and `b` first and guards the step length (planted defect from the S1 review: a dependent column).
  - Verify: grep S3 and S25 for "sentinel" and "scale".
  - Files: PLAN. Depends on: T2.
- [x] **T4: Downstream contract and the probmed gate (M). Fixes F11, F15, F17, F18.** *(done 2026-10-09: S17 contract paragraph, new S17b, equal-label collapse; sigma divisor corrected to n-2 (mediator) and n-3 (outcome) against the saved output.)*
  - Acceptance:
    - New task S17b in the task table, PR 6 list, DAG and E2E row: a `skip_if_not_installed("probmed")` test with a `pmed()` plugin known answer (own `set.seed()`, divisor-n sigma note) and a `parametric_bootstrap` case; latent mediators documented as plugin-only; it depends on workstream B.
    - S17 gets a contract paragraph: the fields probmed reads, the `m_<X>`, `y_<M>`, `y_<X>` names, the intercept default of 0, name-not-position indexing (Q3 covariate rows move positions), and `source_package = "medfit"` with missingmed noted.
    - Equal labels collapse to one parameter in section 2.4, S11 and S17 (free-parameter numbering matches `lavaanify()` after collapsing).
  - Verify: `grep -n "S17b" PLAN` appears in the task table, section 4.3 and the DAG; the phrase "a shared label appears once" no longer contradicts S11.
  - Files: PLAN. Depends on: T3.
- [x] **T5: API surface and ecosystem record (S). Fixes F13, F16, F19, F20, F21.** *(done 2026-10-09: Q2 and R9 model-argument capture, S16/S21 weights routing, six-package table, reserved seam columns, experimental label (now the lifecycle badge, D17).)*
  - Acceptance:
    - Q2 and R9: the `model` argument captures glm's `model =` and partial-matches `mod =`; it is a behavior change in NEWS; `model` joins missingmed's reserved arguments (a note for its owner, not a write); R9 no longer says "additive only" and lists all six packages with the impact table.
    - S16 and S21: `fit_mediation(engine = "native", weights =, se_type = "sandwich")` routes to N6, one argument name on both front ends.
    - Section 2.4 reserves `level`, `block`, `group` columns (NA in 0.7.0) and states `cluster =` semantics for a later native two-level fit.
    - R5 and S18: an experimental label on `SEMFit` and `fit_sem()`, a NEWS line, and the rename cost. **Found while editing:** `lifecycle` is not a dependency of medfit (absent from `DESCRIPTION`, `NAMESPACE`, `R/`). The author approved adding it ("add lifecycle", 2026-10-09, D17); it is added in PR 6 (S18), not in this docs PR.
  - Verify: grep `additive only` returns nothing; grep `lifecycle` finds R5 and S18.
  - Files: PLAN. Depends on: T4.
- [x] **T6: Seam coverage and the release gate (S). Fixes F12, F14.** *(done 2026-10-09: S10 covers all 31 lavaan:: calls with a mechanical grep test, S24 and section 8 run the dependents' suites.)*
  - Acceptance: S10 routes every `lavaan::` call in `R/extract-lavaan.R` through the seam, moves the `requireNamespace("lavaan")` guard behind it, and adds a noSuggests job step that extracts a native fit with lavaan absent; S24 and section 8 replace "full `revdepcheck`" with installing the dev build into a scratch library and running the test suites of probmed, missingmed, mediationverse and RMediation (counts quoted), keeping `revdep_check()` as the CRAN-facing check.
  - Verify: grep S10 for the five helper names; grep S24 for the four package names.
  - Files: PLAN. Depends on: T5.
- [x] **T7: Ledger rows and errata (S). Fix F22; spec-errata draft.** *(done 2026-10-09: ledger rows D9-D17 (17 total), errata block, plan section 10 cross-reference; the frozen spec is byte-identical.)*
  - Acceptance: GRILL rows D9-D16 for the eight resolutions in the spec; an "Errata for spec 4.5c" section with the three text items from the spec (bound rows, scale-free measure, scaled windows), marked draft and not applied; the plan's section 10 cross-references D9-D16.
  - Verify: `grep -c "^| D" GRILL` is 17; the frozen spec file is byte-identical (`git diff --stat SPEC-sem-grammar-2026-10-08.md` empty).
  - Files: GRILL, PLAN. Depends on: T6.
- [ ] **T8: Consistency sweep and independent review (M).**
  - Acceptance: a cross-reference pass (every `S`, `Q`, `R`, `OD`, `D` id cited is defined exactly once; the PR table, DAG and task table agree); `markdownlint` shows no MD056, MD038, MD040; a fresh-context code review of the two edited documents returns no high finding, and every finding is verified before fixing; the docs PR is open with the F1-F22 table in its body.
  - Verify: the sweep script's output is quoted in the PR body; CI on the PR is green.
  - Files: PLAN, GRILL. Depends on: T7.

### Checkpoint A: after T8

- [ ] Docs PR green, no high review finding, spec file untouched.
- [ ] The author says "merge" (ask-before-merge rule). Then T15.

### Phase 2: workstream B, `lavaan-probmed-names` (code, parallel with Phase 1, own worktree)

- [ ] **T9: Red tests (S).** `tests/testthat/test-probmed-names.R`: (a) names test: for a lavaan simple single-mediator fit, `names(@estimates)` and `rownames(@vcov)` contain `m_<X>`, `y_<M>`, `y_<X>` and the pre-existing rows; (b) integration test, `skip_if_not_installed("probmed")`: `pmed(method = "parametric_bootstrap")` on the lavaan object runs and agrees with the glm route within Monte Carlo error at a fixed seed.
  - Acceptance: both tests fail on current `dev` with the errors recorded (the names test on missing rows; the integration test on `subscriptOutOfBoundsError`).
  - Verify: `NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-probmed-names.R")'` shows the failures; transcript saved for the PR body.
  - Files: `tests/testthat/test-probmed-names.R`, `tests/testthat/helper-test-data.R` if a fixture is needed. Depends on: T14.
- [ ] **T10: Implement the alias rows (M).** In the lavaan simple-path worker, add `m_<treatment>`, `y_<mediator>`, `y_<treatment>` rows to `@estimates` and `@vcov` through `.expand_vcov_with_aliases()`, sourced from the `M~X`, `Y~M`, `Y~X` rows via `.lavaan_alias_source_idx()`; leave every existing row and its order unchanged.
  - Acceptance: T9's tests pass; the pre-existing block of `@estimates` and `@vcov` is `identical()` to the pre-change output; the full existing lavaan suite is unchanged.
  - Verify: `NOT_CRAN=true Rscript -e 'devtools::test()'` with counts quoted; an `identical()` regression test on a frozen copy of the old output.
  - Files: `R/extract-lavaan.R`, `R/utils.R` (only if the helper needs an argument), `tests/testthat/test-extract-lavaan.R`. Depends on: T9.
- [ ] **T11: Edge cases and planted defects (S).**
  - Acceptance: labeled parameters (`a`, `b`, `cp`), `meanstructure = TRUE`, `fixed.x = FALSE` and covariates each get the three rows or a named error; a latent mediator gets none and is documented plugin-only; serial, parallel and four-way objects are unchanged; planted defects: dropping one alias row fails the names test, swapping `y_<M>` and `y_<X>` fails the bootstrap agreement test.
  - Verify: the new tests pass; each planted defect, applied with `local_mocked_bindings()` or a temporary edit, turns its test red and leaves `git diff` clean after revert.
  - Files: `tests/testthat/test-probmed-names.R`, `tests/testthat/test-extract-lavaan.R`. Depends on: T10.
- [ ] **T12: Docs (S).** NEWS "behavior change" entry (rows added to `@estimates` and `@vcov` of lavaan-derived `MediationData`; name-based consumers such as probmed now resolve them); a sentence in `?extract_mediation` and `extraction.qmd` on the names; `inst/WORDLIST`.
  - Acceptance: `devtools::document()` leaves only the intended Rd diff; spelling and `pkgdown::check_pkgdown()` clean.
  - Verify: both commands, output quoted.
  - Files: `NEWS.md`, `R/aab-generics.R`, `vignettes/articles/extraction.qmd`, `inst/WORDLIST`, `man/extract_mediation.Rd`. Depends on: T11.
- [ ] **T13: Gates, E2E and PR (S).**
  - Acceptance: full suite, lint on an installed scratch library, spelling, `check_pkgdown()`, and the strict `devtools::check(cran = TRUE, args = "--run-donttest", ...)` all clean, counts quoted; an E2E transcript from a fresh `Rscript` (lavaan fit, `extract_mediation()`, `probmed::pmed(parametric_bootstrap)`) that errors on pre-change `dev` and succeeds on the branch; the PR body links the T14 issue and quotes both transcripts.
  - Verify: the PR's CI is green.
  - Files: none new. Depends on: T12.

### Checkpoint B: after T13

- [ ] Code PR green; E2E fails before and passes after.
- [ ] The author says "merge". Then close the T14 issue by reference.

### Phase 3: close-out

- [ ] **T15: Comment on issue 105 (XS).** After checkpoint A merges: findings in four bullets, the S17b plan, the contract paragraph, and a link to the merged plan. Ask first if the wording changes the scope the issue requests.
  - Acceptance: comment posted; the issue stays open (the gate itself is PR 6's S17b).
  - Verify: `gh issue view 105 --comments`. Depends on: Checkpoint A.
- [ ] **T16: Close-out (XS).** Update `.STATUS` (merged PRs, next = PR 1 of the SEM plan), remove both worktrees after the usual gate (local tip equals PR head, merge commit in `dev`), and remind the author to run `git branch -D` for the leftover local branches.
  - Acceptance: clean tree on `dev`; `git worktree list` shows only the main checkout.
  - Verify: the three commands. Depends on: Checkpoints A and B.

## Out of scope (waiting on the author)

- Amending the frozen grammar spec (the errata PR, D12).
- Any write to probmed, missingmed, RMediation or mediationverse: a probmed issue, missingmed's reserved-arguments list, the RMediation `mbco()` example report. Each needs an explicit request.
- Starting PR 1 of the SEM plan; it needs the author's "make the branch".

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| T10 changes the position or names of existing rows and breaks a downstream index | High | Existing block asserted `identical()` against a frozen copy; alias rows are appended; RMediation's alias lookups (`a`, `b`, `d<i>`) are re-run in T13 against a scratch install |
| Reviewer claims not yet re-run (bound signs, degenerate sets, NNLS bug) are edited into the plan as facts | Med | The plan keeps them labeled **[reviewer, unverified]** in its evidence tags; S1's reimplementations are cited, not trusted |
| Sequential edits to one file drift out of sync | Med | T8's cross-reference pass and the independent review |
| probmed missing in CI, so T9(b) and T13's E2E skip silently | Med | The names test (a) runs without probmed; the PR body carries the manual E2E transcript; T13 records whether the probmed job ran |
| Scope creep into SEM engine code | Med | Boundaries in the spec; PR 1 needs a separate go |

## Open questions

None. The eight questions in the spec are resolved (D9-D16).
