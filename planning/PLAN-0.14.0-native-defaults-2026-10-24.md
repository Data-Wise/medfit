# PLAN: medfit 0.14.0, native defaults (warn release)

**Date:** 2026-10-24. **Status:** revision 2, awaiting approval (revision 1 failed a Codex adversarial review: four
findings, all addressed below; see "Revision log").
**Spec:** `planning/specs/SPEC-native-defaults-2026-10-24.md` (approved; R-1 to R-12).
**ADR:** `planning/specs/ADR-native-defaults-2026-10-24.md` (E-1 to E-15, all decided).
**Evidence:** `planning/specs/evidence/native-defaults-2026-10-24/` (`arm.R` reruns the dependents' per-test comparison).

0.14.0 changes no default. It fixes what the flip would expose (R-1, R-4, R-6), preserves the baselines that depend on
the old defaults (R-8), adds the versioned resolver, the warning and the opt-in (R-2, R-3, R-5, R-11a, R-11b), builds
and runs the oracle matrix under the opt-in (R-12, E-15), and announces the change (R-9 announce half, R-10). 0.15.0
keeps only the flip (R-7), the flip decision on the matrix results, and the reliability blocker (E-12).

## Architecture decisions carried from the ADR

- Unset is `missing()` captured at entry, before any reassignment (E-10); `fit_mediation(engine = "native")`
  forwards `fixed_x`/`meanstructure` only when the caller put them in `engine_args`.
- 0.14.x: unset takes the old value unless `options(medfit.native_defaults = "0.15")`; an explicit value is never
  overwritten (E-14).
- An implicit `fixed_x = TRUE` resolves inside `fit_sem()` to an explicit character subset (observed exogenous
  columns, products and factors included, minus those with a `~~` or `~1` statement); empty means `FALSE` (E-13,
  E-11). E-5's lenience is that subtraction, with a note; explicit `fixed_x = TRUE` still errors.
- Internal refits call `.sem_fit_syntax()` with explicit settings, never through the resolver (R-6).
- Warning class `medfit_warning_default_change`, once per session per argument. The warning, the test helper that
  keeps medfit's own suite quiet, and the doc settings land in one PR (Codex finding 4).

## Dependency graph

```
T1 pinned SE (R-1) ──────────────────────────────────────────────┐
T2 refit settings explicit (R-6) ────────────────────────────────┤
T3 baseline preservation in tests/gates (R-8) ───────────────────┤
T4a compare_lr spike: subset translation ─> T4b lavaan ─> T4c OpenMx
                                                                 │
T5a warning-ready docs and examples (no behavior change) ────────┼─> T5 resolver + warning + opt-in + test helper (atomic)
                                                                 │        │
                                                                 │        ├─> T6 fixed_x subset + lenience
                                                                 │        ├─> T7 fit_mediation forward-if-given
                                                                 │        └─> T8a oracle matrix: harness + core cells
                                                                 │                 └─> T8b product, factor, subset cells (needs T6)
                                                                 └─> T9 docs/NEWS announce ─> T10 ecosystem
```

T1 and T4a are the highest-risk items and go first. T3 preserves baselines; it is not what keeps the warning out of
the suite (Codex finding 4): that is T5's test helper and T5a's doc settings, which land with or before the warning.

## Task list

### Phase 1: fixes the flip would expose

- [ ] **T1. Pinned-parameter SE under a mean structure (R-1, E-8).** Size M.
  - Root cause (confirmed 2026-10-24: the `b` row of `act$z_theta` is exactly 0, `act$free[b]` is TRUE,
    `V[b, b]` = 3.19e-35): `.sem_vcov()` (`R/sem-se.R:46-52`) maps the active-set basis into centered coordinates,
    re-orthonormalizes it (`qr.Q(qr(solve(tmat, z)))`) and maps it back (`z <- tmat %*% zc`). A row of `z` that was
    exactly zero comes back as roundoff, so the SE is 5.6e-18 and `tidy()`'s exact test `se > 0`
    (`R/methods-sem.R:298`) computes a z-statistic.
  - Fix at the source, not in `tidy()`: after the map back, set to exactly zero the rows of `z` that are exactly zero
    in the theta-unit basis from `.sem_active_set()` (a structural zero, not a small number: no tolerance). No
    tolerance is added to `tidy()`, which would hide a real tiny SE.
  - Why it is general: `.sem_vcov()` is shared by linear equalities, active inequalities, active bounds, fixed
    coordinates, nonlinear rows and the sandwich. The rule touches only rows that the theta-unit basis already has
    at exactly zero, so it can only remove roundoff the centering round trip introduced; the acceptance cells below
    prove that for each consumer instead of asserting it (Codex finding 3).
  - Acceptance, one cell per consumer, each against a stated oracle, with and without `meanstructure = TRUE`:
    | Cell | Pinned row expectation | Oracle for the other rows |
    |---|---|---|
    | linear equality `b == 0` | SE exactly 0, `statistic` NA | the same model with `b` fixed by syntax (`0*mediator1`), to 1e-8 |
    | fixed syntax coordinate `0*mediator1` | not a parameter: no row; unchanged | lavaan `sem(..., meanstructure = TRUE, fixed.x = FALSE)`, to 1e-6 |
    | active lower bound (`lower(0)` on a path that hits 0) | SE exactly 0 | the same model with the path fixed at 0, to 1e-8 |
    | active nonlinear row `cp == a*b` | no row is structurally zero: every SE unchanged and positive | `meanstructure = NULL` fit (no centering), to 1e-8 on the covariance-part rows |
    | `se_type = "sandwich"` with `b == 0` | SE exactly 0 | the sandwich SEs of the `0*mediator1` model, to 1e-8 |
    | near-zero tangent: equality `a == 1e-9 * b`-style row (a direction with a tiny but nonzero component on a coordinate) | that coordinate's SE stays positive and matches the uncentered fit to 1e-8 | `meanstructure = NULL` fit |
  - Planted defect: restoring zeros by a tolerance (e.g. `abs(z) < 1e-12`) instead of exact zeros must fail the
    near-zero tangent cell; removing the restore must fail the `b == 0` cells.
  - Metamorphic: shifting every observed mean by a constant leaves all SEs unchanged and the pinned rows exactly 0.
  - Verify: `devtools::test(filter = "sem-methods|sem-se|sem-mean")`; the 15 "real" failures of the `ms` arm in
    `evidence/.../failures.csv` that trace to this bug pass under an explicit `meanstructure = TRUE`.
  - Files: `R/sem-se.R`, `tests/testthat/test-sem-se-pinned.R` (new), `NEWS.md`.
  - Risk tier: `R/sem-se.R` is in `tests/sim/risk-files.txt` ⇒ the PR carries the seven-item checklist (oracle,
    planted defects and metamorphic cell above; reliability cell and platform run from the gates).

- [ ] **T2. Refits pass their settings explicitly (R-6).** Size S.
  - `mbco_sem()` passes `meanstructure = isTRUE(fit@internals$ram$has_mean)` (FALSE, not NULL) and the parent's
    resolved `fixed_x` (`R/sem-mbco.R:165`). Inventory every internal refit first (grep `.sem_fit_syntax(` and
    `fit_sem(` under `R/`: `mbco_sem()`, `compare_lr()`, `anova()` helpers, bootstrap refits, `.sem_fit_branches()`)
    and record the list in the PR body; each passes both settings explicitly.
  - Acceptance: for each refit site, a test checks the refit's `has_mean` and fixed set equal the parent's (no-mean
    parent, mean parent, named-subset parent); existing MBCO tests unchanged.
  - Verify: `devtools::test(filter = "sem-mbco|compare-lr|bootstrap|sem-anova")`.
  - Files: `R/sem-mbco.R` and the refit sites found, `tests/testthat/test-sem-refit-settings.R` (new).
  - Note for later (no change here): missingmed has the same pattern at `missingmed/R/mbco_sem.R:236` (other repo;
    T10 asks first).

- [ ] **T3. Baseline preservation (R-8, E-7).** Size M.
  - Scope is baselines, not warnings: pass `fixed_x = FALSE` and the current `meanstructure` explicitly in every
    `fit_sem()` call in `tests/sim/` (27 calls, the gates), the frozen-fixture tests (0.8.0, 0.9.0 values), and the
    tests that assert logLik, npar, AIC, BIC or a parameter count. Tests that check only structural results stay
    unpinned (they exercise the new defaults in 0.15.0).
  - Add `R/fit-sem.R` to `tests/sim/risk-files.txt` (spec CI section).
  - Acceptance: suite and gates identical before and after (pinning to the current default changes nothing);
    `test-sim-pinned.R` (new, fast) fails if a `fit_sem()` call in `tests/sim/` omits either setting.
  - Verify: `devtools::test()` counts unchanged (6938 expectations, 0 fail at base); dispatch the gates on the PR.
  - Files: `tests/sim/*.R` (mechanical), the frozen-fixture test files, `tests/sim/risk-files.txt`,
    `tests/testthat/test-sim-pinned.R`. One PR: the diff is uniform and the gates must see it whole.

- [x] **T4a. Spike: how `compare_lr()` represents a fixed set (R-4, E-4).** Size S, output is a decision note.
  - Problem (Codex finding 1, confirmed): removing the `fixed_x` refusal (`R/compare-lr.R:156`) is not enough.
    `.lr_unsupported()` then refuses any table with a non-free row (`R/compare-lr.R:169`), which fixed exogenous
    moments create, and lavaan's `fixed.x` is a logical over all exogenous variables, not a subset.
  - Prototype in a scratch script (no package change):
    1. lavaan with `fixed.x = FALSE` and the fit's fixed moments written as fixed rows at the sample values (N
       denominator) in the parameter table; check its LR equals lavaan `fixed.x = TRUE` when the subset is all
       exogenous variables, to 1e-8.
    2. The same translation for a named subset (`fixed_x = "covariate1"`) and for a lenient subset (a variable left
       free because the model writes `x ~~ x`), against `fit_sem()`'s own constrained-minus-unconstrained deviance.
    3. Conditional-likelihood check: when both models share a saturated exogenous block, the LR under the fixed
       set equals the LR under `fixed_x = FALSE` (the fixed moments are the MLEs); a mismatch is a finding.
    4. The same three cells in OpenMx (`free = FALSE` paths at the sample moments; a means path for a mean
       structure).
  - Exit: a note in `planning/specs/` naming the translation, the refined line-169 rule (allow non-free rows that are
    fixed exogenous moments or intercepts at their sample values, refuse every other non-free row), and the sizes of
    T4b and T4c. If the subset cannot be represented in one engine, that engine keeps refusing subsets with a
    stated reason, and the spec's R-4 gets an amendment for the author to approve.
  - Files: scratch script under `tests/sim/scratch/` (not committed) and the note.

- [ ] **T4b. `compare_lr()` lavaan adapter for fixed sets and means.** Size from T4a (expected M).
  - Implement T4a's translation and the refined non-free-row rule; pass `meanstructure`.
  - Acceptance cells (each against lavaan's own LR and `fit_sem()`'s deviance difference, to 1e-6): `fixed_x = TRUE`;
    named subset; lenient subset; `meanstructure = TRUE`; both settings; the conditional-likelihood equivalence of
    T4a step 3. Planted defects: translating the subset as `fixed.x = TRUE` must fail the named-subset cell;
    dropping the refined rule must reproduce today's refusal.
  - Verify: `devtools::test(filter = "compare-lr")`; `Rscript tests/sim/compare-lr.R` with the new cells and a
    `gates.csv` row update.
  - Files: `R/compare-lr.R`, `tests/testthat/test-compare-lr.R`, `tests/sim/compare-lr.R`, `tests/sim/gates.csv`.
  - Dependency: T4a.

- [ ] **T4c. `compare_lr()` OpenMx adapter for fixed sets and means.** Size from T4a (expected M; split fixed paths
  and means into two PRs if it exceeds one session).
  - Acceptance: the T4b cells in OpenMx equal lavaan and `fit_sem()` to 1e-5; anything OpenMx cannot express is
    refused with that reason in the error.
  - Verify: as T4b, with OpenMx installed; skips cleanly when it is not.
  - Files: `R/compare-lr-openmx.R`, `tests/testthat/test-compare-lr.R`.
  - Dependency: T4b (shared fixtures and rule).

### Checkpoint A (after T1-T4c)

- [x] Full suite green; counts recorded (`devtools::test()`). 2026-10-24 on dev 38ba077: 1565 tests, 7104
      expectations, 0 failed, 0 errors, 2 skipped.
- [x] Gates dispatched on the PR, both shards green (`gates (rest)`, `gates (reliability)`). Dispatched on dev
      38ba077 (run 40137907236), both green.
- [x] Rerun `evidence/.../arm.R` `ms` arm: the 15 real failures are gone; the remaining failures are expected value
      changes in unpinned tests (each named). medfit tests only (dependents were unaffected before): 0 errors (was
      18), 8 failed expectations (was 93) in 6 tests: recipe 18 npar 14/8 -> 19/10 (2); lavaan-comparison live
      probes "Estimators other than ML" and "Robust standard errors" change status (2; a probe artifact, not
      a capability change: `test-lavaan-comparison.R:81,102` compare whole `coef()`/SE vectors with lavaan run
      without means, so the native intercepts make the lengths differ; the 0.15.0 flip must pin the probes'
      `meanstructure` or give lavaan `meanstructure = TRUE`, no article note); native book ch. 5 expected information has a mean block (1); product-mean
      through `fit_mediation()` uses raw data (1); MBCO refit test relies on the default for a no-mean fit (2).
- [x] Author review before Phase 2. Approved 2026-10-24.

### Phase 2: resolver, warning, opt-in, oracle matrix

- [ ] **T5a. Warning-ready examples and articles (no behavior change).** Size M.
  - Lands before T5 and changes no output: 25 articles and 6 R files call `fit_sem()` or the native engine.
  - Articles: one hidden setup chunk per article that has a native fit, which makes the article quiet once T5
    lands. The chunk calls the public API only (a muffled tiny `fit_sem()` call that consumes the once-per-session
    warning), so the printed results stay on the 0.14 defaults and need no rewrite until 0.15.0. Alternative
    rejected: explicit `fixed_x = FALSE, meanstructure = NULL` in about 227 calls, which 0.15.0 would undo.
  - Roxygen examples (6 files: `classes.R`, `compare-lr.R`, `fit-sem.R`, `methods-sem.R`, `sem-mbco.R`,
    `sem-syntax-help.R`; `aab-generics.R` and `fit-glm.R` mention the native engine in prose only, `sem-anova.R` and
    `sem-fit.R` have no examples): explicit settings in the first native call of each example block.
  - Acceptance: rendered articles and examples are byte-identical before and after (no behavior change yet);
    `test-docs-warning-ready.R` (new) fails if an article with a native fit lacks the setup chunk.
  - Files: `vignettes/articles/*.qmd` (25), `R/*.R` roxygen examples (6), `tests/testthat/test-docs-warning-ready.R`.
    Mechanical; over five files by necessity.

- [ ] **T5. Resolver, warning, opt-in and the suite's test helper, in one PR (R-2, R-3, R-11a, E-9, E-14).** Size M.
  - In `fit_sem()`: capture `fx_unset <- missing(fixed_x)`, `ms_unset <- missing(meanstructure)` first; read
    `getOption("medfit.native_defaults")`; if `"0.15"` resolve unset values to the new defaults (T6 supplies the
    `fixed_x` subset; until T6 lands the opt-in resolves `fixed_x` to `TRUE` only when no statement conflicts, else
    errors with a pointer to T6's behavior); otherwise keep the old values and call `.warn_native_defaults_once()`
    when the model has an observed exogenous variable (fixed_x) or no `~1` (meanstructure). Any other option value
    errors.
  - Warning: class `medfit_warning_default_change`, names the argument, says what changes in 0.15.0 (logLik, npar,
    AIC, BIC; estimates and SEs unchanged on the measured cases) and both ways to silence it; once per session per
    argument (package-env state, internal reset helper).
  - In the same PR (Codex finding 4): `tests/testthat/helper-native-defaults.R` marks both warnings as already shown
    for the whole suite, so the 588 unpinned calls stay quiet; the dedicated tests reset the state and expect the
    warning. A `testthat` reporter check fails the run if the class appears outside a test that expects it.
  - Signatures unchanged (`test-api-freeze.R` stays green). Files in `R/native-defaults.R` (new; removed wholesale
    with the option in 0.16.0) and `R/fit-sem.R`.
  - Acceptance (unit): unset → old value + one warning per argument per session; explicit `FALSE`/`TRUE`/`NULL` → no
    warning, value kept; option `"0.15"` → new values, no warning; bad option value → error. Integration:
    `devtools::test()` and `devtools::check()` show zero occurrences of the class; the pkgdown workflow on the PR
    renders every article without it (T5a).
  - Verify: `devtools::test()`; `scripts/check-local.sh`; pkgdown workflow on the PR.
  - Files: `R/native-defaults.R`, `R/fit-sem.R`, `tests/testthat/test-native-defaults.R`,
    `tests/testthat/helper-native-defaults.R`.
  - Dependency: T3, T5a. The once-per-session flag must be set even when the warning is muffled (set it before
    signaling, not after the handler returns), or T5a's setup chunks consume nothing and every article warns.

- [ ] **T6. `fixed_x` default resolves to a subset, with lenience (R-5, R-11b, E-5, E-11, E-13).** Size M.
  - `.sem_default_fixed_x(parsed, data)`: observed exogenous columns (product and factor columns included) minus
    those with a `~~` or `~1` statement; a character vector, empty ⇒ `FALSE`. One classed note naming the variables
    left free. Explicit `fixed_x = TRUE` keeps today's error.
  - Used only when `fixed_x` is unset and the opt-in is on (0.14.x), so no default fit changes in this release.
  - Acceptance: under the opt-in, a model with `treatment ~~ treatment` fits with `treatment` free and one note; the
    same model with explicit `fixed_x = TRUE` errors with today's message; the fixed set on `@internals` equals the
    returned subset; every refit site from T2 sees the same subset.
  - Verify: `devtools::test(filter = "native-defaults|fixed-x|sem-product|sem-refit")`.
  - Files: `R/native-defaults.R`, `tests/testthat/test-native-defaults.R`.
  - Dependency: T5, T2.

- [ ] **T7. `fit_mediation(engine = "native")` forwards only supplied settings (E-3, E-10).** Size S.
  - Forward `fixed_x`/`meanstructure` to `fit_sem()` only when present in `engine_args` (the `m_star` pattern).
  - Acceptance: with no settings it warns once like `fit_sem()` (state reset in the test); with
    `engine_args = list(fixed_x = FALSE)` it does not; both entry points give the same fixed set under the opt-in.
  - Verify: `devtools::test(filter = "fit-sem|native-defaults")`.
  - Files: `R/fit-sem.R` (`.fit_mediation_native()`), `tests/testthat/test-fit-sem.R`.
  - Dependency: T5.

- [ ] **T8a. Oracle matrix: harness and core cells (R-12, E-15).** Size M. Back in 0.14.0 as the spec assigns it
  (Codex finding 2).
  - `tests/sim/native-defaults-oracle.R`: the four combinations of (`fixed_x`, `meanstructure`) crossed with the
    cells below, comparing structural estimates, their SEs, chi-square, df, logLik, npar, AIC and BIC with lavaan
    (`fixed.x`, `meanstructure`, `sampling.weights`, `se = "robust.huber.white"`) or a stated independent oracle.
    Results to a CSV with one row per cell × combination × quantity; a disagreement is a row marked `block` or
    `limit` with a reason, never a widened tolerance.
  - Core cells here: simple observed model; weights + sandwich SEs; fixed intercept (`y ~ 0*1`); constrained
    intercepts; latent mediator. Each runs with explicit settings and once under the opt-in (to exercise the
    resolver path).
  - Registration: a `gates.csv` row (`oracle` = lavaan, `mutants`), rows in `tests/sim/structures.csv`; planted
    defect: `MUTANT=fixedx_logical` (translate a subset as all-fixed) must flip at least one cell.
  - Verify: `Rscript tests/sim/native-defaults-oracle.R`; the fast subset in `tests/testthat/test-native-defaults-oracle.R`.
  - Files: `tests/sim/native-defaults-oracle.R`, `tests/sim/gates.csv`, `tests/sim/structures.csv`,
    `tests/testthat/test-native-defaults-oracle.R`.
  - Dependency: T5 (opt-in path), T1 (pinned SEs in the constrained cells).

- [ ] **T8b. Oracle matrix: product, factor and subset cells.** Size M.
  - Cells: four-way product (`x:m`; E-11's VERIFY of lavaan's product-column treatment is answered here, not in
    0.15.0), factor covariate (`fixed_x = "g"` and the default subset), named `fixed_x` subset, lenient subset.
  - Acceptance: every cell agrees or is recorded `limit` with a reason; the 0.15.0 flip decision reads this CSV.
  - Files: `tests/sim/native-defaults-oracle.R`, `tests/testthat/test-native-defaults-oracle.R`.
  - Dependency: T8a, T6.

### Checkpoint B (after T5a-T8b)

- [ ] Full suite and `scripts/check-local.sh` green; `test-api-freeze.R` unchanged; zero
      `medfit_warning_default_change` outside expecting tests.
- [ ] Opt-in arm: `options(medfit.native_defaults = "0.15")` set in a scratch run of the suite; record failures
      (expected: the unpinned logLik/npar tests only) to size 0.15.0.
- [ ] Oracle matrix CSV committed with the gate; every `block` row has an owner task for 0.15.0.
- [ ] Dependents (`arm.R`, three builds: base, 0.14.0, 0.14.0 + opt-in): per-test results identical to the
      2026-10-24 evidence; list which dependents' suites now show the warning (expected: RMediation only).
- [ ] Author review before Phase 3.

### Phase 3: announce

- [ ] **T9. Docs and NEWS for the warning release (R-9, announce half).** Size M.
  - NEWS: R-1 fix (behavior change note), R-4, the warning and the opt-in, the 0.15.0 schedule, R-11's retry-seed
    note. `?fit_sem` and `?"medfit-syntax"`: a "Defaults are changing" section. `guide-changes.qmd` row. The lavaan
    comparison and the syntax crosswalk get a one-line forward note (their rewrite is 0.15.0).
  - Acceptance: `/rforge:docs:check` clean on the touched files; `spelling::spell_check_package()` clean; the
    pkgdown workflow on the PR builds.
  - Files: `NEWS.md`, `R/fit-sem.R` (roxygen), `R/sem-syntax-help.R`, `vignettes/articles/guide-changes.qmd`,
    `vignettes/articles/lavaan-comparison.qmd`.

- [ ] **T10. Ecosystem notice (R-10, E-6).** Size S, needs permission per repo.
  - Draft the `[BREAKING]` issue (2-month notice, the clock starts with the 0.14.0 release) in medfit; ask before
    filing. Draft the RMediation change (pass the settings explicitly in `R/00_classes.R` examples and
    `test-mbco-semfit*.R`) and the missingmed line 236 note; both are other repos and need the author's explicit
    go-ahead, one action at a time.
  - Acceptance: issue text in `planning/` reviewed; RMediation PR opened only on approval.

### Checkpoint C: release readiness (0.14.0)

- [ ] Version bump, `.STATUS`, README version row, CLAUDE.md status paragraph.
- [ ] Gates green on the release PR (`dev → main`), including the new oracle-matrix gate; `R-CMD-check` green on `main`.
- [ ] Dependents' evidence (`arm.R`) attached to the release PR (spec: each release PR).
- [ ] GitHub release; site redeploys from `main`.

## 0.15.0 (not this plan; recorded so nothing is lost)

R-7 flip and formals (`meanstructure = TRUE`, `fixed_x = TRUE`), obsolete-option note; the flip decision on the
oracle-matrix CSV from T8a/T8b (every `block` row resolved); E-12 reliability non-inferiority blocker;
`test-api-freeze.R` update; T5a setup chunks removed and the R-9 rewrite half (articles re-rendered, printed
logLik/AIC diffed); option removal in 0.16.0.

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| T1 restore rule zeroes a row that carries real variance | High: a real SE reported as 0 | exact-zero rule only; near-zero tangent cell and the tolerance mutant in T1's acceptance |
| T4a finds a subset cannot be represented in lavaan or OpenMx | High: R-4 not met as written | T4a exits with a spec amendment for the author instead of a silent refusal |
| T3 misses a baseline that depends on the default | Med: silent drift in 0.15.0 | `test-sim-pinned.R`; opt-in arm at Checkpoint B surfaces the rest |
| The T5 test helper hides a warning that should be seen | Med | the reporter check fails on the class outside expecting tests; dedicated tests reset the state |
| T5a setup chunk consumes the warning in an article that should show it (e.g. a page about the change) | Low | that article opts out of the chunk; `test-docs-warning-ready.R` keeps an allow-list |
| Warning floods dependents' CI | Med | once per session; RMediation change in T10; opt-in documented |
| Oracle-matrix gate lengthens the gates job (timeout history) | Med | run the matrix in the `rest` shard with a time budget; gates stay on ubuntu-24.04 (#312) |

## Open questions

1. Where the helpers live: resolved as a new `R/native-defaults.R` (removed wholesale with the option in 0.16.0).
2. T3 as one PR or split: resolved as one PR (uniform diff; the gates must see it whole).
3. Open: the T5a setup chunk relies on the once-per-session state. If the author prefers no hidden mechanism in
   articles, the alternative is explicit settings in about 227 calls (rejected above as churn 0.15.0 would undo).

## Revision log

| Rev | Date | Change |
|---|---|---|
| 1 | 2026-10-24 | first plan (commit `1b79eea`) |
| 2 | 2026-10-24 | Codex adversarial review, four findings, all applied: (1) T4 split into a spike T4a (subset translation, line-169 rule, conditional-likelihood check) and T4b/T4c with named and lenient subset cells; (2) R-12 oracle matrix back in 0.14.0 as T8a/T8b, the spec's assignment, with E-11's lavaan product check moved forward into T8b; (3) T1 acceptance widened to one oracle cell per consumer of `.sem_vcov()` (fixed coordinate, active bound, nonlinear row, sandwich) plus a near-zero tangent cell and a tolerance mutant; (4) T3 rescoped to baseline preservation, the warning made atomic with its suite helper (T5) and preceded by warning-ready docs (T5a); former T8 folded into T5 and T5a |
