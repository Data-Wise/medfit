# PLAN: medfit 0.14.0, native defaults (warn release)

**Date:** 2026-10-24. **Status:** draft, awaiting approval.
**Spec:** `planning/specs/SPEC-native-defaults-2026-10-24.md` (approved; R-1 to R-12).
**ADR:** `planning/specs/ADR-native-defaults-2026-10-24.md` (E-1 to E-15, all decided).
**Evidence:** `planning/specs/evidence/native-defaults-2026-10-24/` (`arm.R` reruns the dependents' per-test comparison).

0.14.0 changes no default. It fixes what the flip would expose (R-1, R-4, R-6), pins the old defaults where a
baseline depends on them (R-8), adds the versioned resolver, the warning and the opt-in (R-2, R-3, R-5, R-11a,
R-11b), and announces the change (R-9 announce half, R-10). The flip (R-7), the oracle matrix that gates it (R-12,
E-15) and the reliability blocker (E-12) are 0.15.0 and listed at the end only so nothing is lost.

## Architecture decisions carried from the ADR

- Unset is `missing()` captured at entry, before any reassignment (E-10); `fit_mediation(engine = "native")`
  forwards `fixed_x`/`meanstructure` only when the caller put them in `engine_args`.
- 0.14.x: unset takes the old value unless `options(medfit.native_defaults = "0.15")`; an explicit value is never
  overwritten (E-14).
- An implicit `fixed_x = TRUE` resolves inside `fit_sem()` to an explicit character subset (observed exogenous
  columns, products and factors included, minus those with a `~~` or `~1` statement); empty means `FALSE` (E-13,
  E-11). E-5's lenience is that subtraction, with a note; explicit `fixed_x = TRUE` still errors.
- Internal refits call `.sem_fit_syntax()` with explicit settings, never through the resolver (R-6).
- Warning class `medfit_warning_default_change`, once per session per argument.

## Dependency graph

```
T1 pinned SE (R-1) ─────────────────────────────┐
T2 refit settings explicit (R-6) ───────────────┤
T3 pin old defaults in tests/gates (R-8) ───────┼─> T5 resolver + warning + option (R-2/R-3/R-11a)
                                                │        │
                                                │        ├─> T6 fixed_x subset + lenience (R-5/R-11b/E-13)
                                                │        ├─> T7 fit_mediation forward-if-given (E-10)
                                                │        └─> T8 warning hygiene in medfit's own suite
T4 compare_lr lavaan adapter (R-4) ─> T4b OpenMx adapter (R-4)
                                                         └─> T9 docs/NEWS announce (R-9) ─> T10 ecosystem (R-10)
```

T1, T2, T4 are independent and highest-risk; they go first (fail fast). T3 must land before T5, because T5's
warning would otherwise fire across the suite and the gates.

## Task list

### Phase 1: fixes the flip would expose

- [ ] **T1. Pinned-parameter SE under a mean structure (R-1, E-8).** Size S.
  - Root cause (confirmed 2026-10-24: the `b` row of `act$z_theta` is exactly 0, `act$free[b]` is TRUE, `V[b, b]` = 3.19e-35): `.sem_vcov()` (`R/sem-se.R:46-52`) maps the active-set basis into centered
    coordinates, re-orthonormalizes it (`qr.Q(qr(solve(tmat, z)))`) and maps it back (`z <- tmat %*% zc`). A row of
    `z` that was exactly zero (the coordinate pinned by `b == 0`) comes back as roundoff, so `V[b, b]` is about
    3e-35, the SE 5.6e-18, and `tidy()`'s exact test `se > 0` (`R/methods-sem.R:298`) computes a z-statistic.
  - Fix at the source, not in `tidy()`: after the map back, restore exact zeros in the rows of `z` that were zero
    in the theta-unit basis (the coordinates the active set pins). Do not add a tolerance to `tidy()`, which would
    hide a real tiny SE.
  - Acceptance:
    - `fit_sem("mediator1 ~ treatment + covariate1\noutcome ~ b*mediator1 + treatment + covariate1\nb == 0",
      mediation_demo, meanstructure = TRUE)`: `tidy()` row `b` has `std_error == 0` exactly and `statistic` NA.
    - The same with `meanstructure = NULL` is unchanged (still 0 / NA).
    - Free parameters' SEs unchanged to 1e-10 against the current build, with and without a mean structure, and
      under `se_type = "sandwich"`.
    - Planted defect: removing the restore line makes the new test fail.
  - Verify: `devtools::test(filter = "sem-methods|sem-se|sem-mean")`; the 15 "real" failures of the
    `meanstructure` arm in `evidence/.../failures.csv` that trace to this bug pass under an explicit
    `meanstructure = TRUE`.
  - Files: `R/sem-se.R`, `tests/testthat/test-sem-methods.R` (new case next to line 154), `NEWS.md`.
  - Risk tier: `R/sem-se.R` is in `tests/sim/risk-files.txt` ⇒ the PR carries the seven-item checklist (oracle:
    the unconstrained fit with `b` fixed by syntax `0*mediator1`; planted defect as above; metamorphic: shift a
    variable's mean, the pinned row stays exactly 0).

- [ ] **T2. Refits pass their settings explicitly (R-6).** Size XS.
  - `mbco_sem()` passes `meanstructure = isTRUE(fit@internals$ram$has_mean)` (FALSE, not NULL) and the parent's
    resolved `fixed_x` (`R/sem-mbco.R:165`); audit every other internal refit (`compare_lr()`, `anova()` helpers,
    bootstrap refits) the same way.
  - Acceptance: a test that refits a no-mean and a mean fit through `mbco_sem()` and checks the refit's
    `has_mean` and fixed set equal the parent's; existing MBCO tests unchanged.
  - Verify: `devtools::test(filter = "sem-mbco|compare-lr")`.
  - Files: `R/sem-mbco.R`, any other refit site found, `tests/testthat/test-sem-mbco.R`.
  - Note for later (no change here): missingmed has the same pattern at `missingmed/R/mbco_sem.R:236` (other
    repo; T10 asks first).

- [ ] **T3. Pin the old defaults where a baseline depends on them (R-8, E-7).** Size M.
  - Pass `fixed_x = FALSE` and the current `meanstructure` explicitly in: every `fit_sem()` call in `tests/sim/`
    (27 calls, the gates), the frozen-fixture tests (0.8.0, 0.9.0 values), and tests that assert logLik, npar,
    AIC, BIC or a parameter count. Tests that check only structural results stay unpinned (they cover the new
    defaults later).
  - Add `R/fit-sem.R` to `tests/sim/risk-files.txt` (spec CI section).
  - Acceptance: suite and gates identical before and after (pinning to the current default changes nothing); a
    grep check lists no unpinned `fit_sem()` call in `tests/sim/`.
  - Verify: `devtools::test()` counts unchanged (6938 expectations, 0 fail at base); dispatch the gates on the PR.
  - Files: `tests/sim/*.R` (mechanical), the frozen-fixture test files, `tests/sim/risk-files.txt`. Above five
    files but one mechanical edit; split by directory (sim / testthat) if review prefers.

- [ ] **T4. `compare_lr()` lavaan adapter accepts fixed_x and means (R-4, E-4).** Size M.
  - Remove the two refusals in `.lr_unsupported()` (`R/compare-lr.R` ~150-157) for the lavaan path; pass
    `fixed.x` (with the fit's fixed set) and `meanstructure` to lavaan.
  - Acceptance: product-null LR from `compare_lr()` equals lavaan's own LR difference to 1e-6 on a
    `fixed_x = TRUE` fit, a `meanstructure = TRUE` fit and both; the `compare-lr` gate gets those cells.
    Planted defect: passing `fixed.x = FALSE` regardless must fail the new test.
  - Verify: `devtools::test(filter = "compare-lr")`; `Rscript tests/sim/compare-lr.R` (the gate).
  - Files: `R/compare-lr.R`, `tests/testthat/test-compare-lr.R`, `tests/sim/compare-lr.R`, `tests/sim/gates.csv`.

- [ ] **T4b. `compare_lr()` OpenMx adapter (R-4).** Size M.
  - `R/compare-lr-openmx.R` writes the fixed exogenous variances/covariances at the sample moments
    (`free = FALSE`) and a means path (`mxPath(from = "one", ...)`) when the fit has a mean structure; the data
    switch to raw or cov+means accordingly.
  - Acceptance: OpenMx LR equals lavaan's and medfit's to 1e-5 on the same three cells; OpenMx refusal stays only
    for what OpenMx cannot express (state it in the error).
  - Verify: as T4, with OpenMx installed; skip cleanly when it is not.
  - Files: `R/compare-lr-openmx.R`, `tests/testthat/test-compare-lr.R`.
  - Dependency: T4 (shared test fixtures).

### Checkpoint A (after T1-T4b)

- [ ] Full suite green; counts recorded (`devtools::test()`).
- [ ] Gates dispatched on the PR, both shards green (`gates (rest)`, `gates (reliability)`).
- [ ] Rerun `evidence/.../arm.R` `ms` arm: the 15 real failures are gone; the remaining failures are expected
      value changes in unpinned tests (each named).
- [ ] Author review before Phase 2.

### Phase 2: resolver, warning, opt-in

- [ ] **T5. Versioned resolver, warning and opt-in (R-2, R-3, R-11a, E-9, E-14).** Size M.
  - In `fit_sem()`: capture `fx_unset <- missing(fixed_x)`, `ms_unset <- missing(meanstructure)` first; read
    `getOption("medfit.native_defaults")`; if `"0.15"` resolve unset values to the new defaults (T6 supplies the
    `fixed_x` subset); otherwise keep the old values and call `.warn_native_defaults_once()` when the model has an
    observed exogenous variable (fixed_x) or no `~1` (meanstructure). Any other option value errors.
  - Warning: class `medfit_warning_default_change`, names the argument, says what changes in 0.15.0 (logLik,
    npar, AIC, BIC; estimates and SEs unchanged on the measured cases) and both ways to silence it; once per
    session per argument (package-env flag; a helper to reset it for tests).
  - Signatures unchanged (`test-api-freeze.R` stays green).
  - Acceptance (unit): unset → old value + one warning per argument per session; explicit `FALSE`/`TRUE`/`NULL` →
    no warning, value kept; option `"0.15"` → new values, no warning; bad option value → error.
  - Verify: `devtools::test(filter = "native-defaults|api-freeze")` (new file `test-native-defaults.R`).
  - Files: `R/fit-sem.R`, `R/utils.R` (helpers) or a new `R/native-defaults.R`, `tests/testthat/test-native-defaults.R`.
  - Dependency: T3.

- [ ] **T6. `fixed_x` default resolves to a subset, with lenience (R-5, R-11b, E-5, E-11, E-13).** Size M.
  - `.sem_default_fixed_x(parsed, data)`: observed exogenous columns (product and factor columns included)
    minus those with a `~~` or `~1` statement; returns a character vector, empty ⇒ `FALSE`. One note (classed
    message) naming the variables left free. Explicit `fixed_x = TRUE` keeps today's error.
  - Used only when `fixed_x` is unset and the opt-in is on (0.14.x), so no default fit changes in this release.
  - Acceptance: under the opt-in, a model with `treatment ~~ treatment` fits with `treatment` free and one note;
    the same model with explicit `fixed_x = TRUE` errors with today's message; the fixed set on `@internals`
    equals the returned subset; refits (`mbco_sem()`) see the same subset (T2).
  - Verify: `devtools::test(filter = "native-defaults|fixed-x|sem-product")`.
  - Files: `R/fit-sem.R` or `R/native-defaults.R`, `tests/testthat/test-native-defaults.R`.
  - Dependency: T5, T2.

- [ ] **T7. `fit_mediation(engine = "native")` forwards only supplied settings (E-3, E-10).** Size S.
  - Forward `fixed_x`/`meanstructure` to `fit_sem()` only when present in `engine_args` (the `m_star` pattern), so
    `missing()` in `fit_sem()` sees the caller's intent.
  - Acceptance: `fit_mediation(engine = "native", ...)` with no settings warns once like `fit_sem()`; with
    `engine_args = list(fixed_x = FALSE)` it does not; both entry points give the same fixed set under the opt-in.
  - Verify: `devtools::test(filter = "fit-sem|native-defaults")`.
  - Files: `R/fit-sem.R` (`.fit_mediation_native()`), `tests/testthat/test-fit-sem.R`.
  - Dependency: T5.

- [ ] **T8. Warning hygiene in medfit's own code and suite.** Size S.
  - medfit's suite, examples, vignettes and gates must not raise `medfit_warning_default_change` (spec testing
    strategy). Add a testthat helper that fails a test on that class unless the test expects it; set the opt-in
    or explicit values in examples and articles that would warn.
  - Acceptance: `devtools::test()` and `devtools::check()` show zero occurrences of the warning; article build
    (`pkgdown` workflow on the PR) shows none.
  - Files: `tests/testthat/helper-native-defaults.R`, examples in `R/fit-sem.R`, affected `vignettes/articles/*.qmd`.
  - Dependency: T5, T7.

### Checkpoint B (after T5-T8)

- [ ] Full suite and `scripts/check-local.sh` green; `test-api-freeze.R` unchanged.
- [ ] Opt-in arm: `options(medfit.native_defaults = "0.15")` set in a scratch run of the suite; record failures
      (expected: the unpinned logLik/npar tests only) to size 0.15.0.
- [ ] Dependents (`arm.R`, three builds: base, 0.14.0, 0.14.0 + opt-in): per-test results identical to the
      2026-10-24 evidence; list which dependents' suites now show the warning (expected: RMediation only).
- [ ] Author review before Phase 3.

### Phase 3: announce

- [ ] **T9. Docs and NEWS for the warning release (R-9, announce half).** Size M.
  - NEWS: R-1 fix (behavior change note), R-4, the warning and the opt-in, the 0.15.0 schedule, R-11's retry-seed
    note. `?fit_sem` and `?"medfit-syntax"`: a "Defaults are changing" section. `guide-changes.qmd` row. The
    lavaan comparison and the syntax crosswalk get a one-line forward note (their rewrite is 0.15.0).
  - Acceptance: `/rforge:docs:check` clean on the touched files; `spelling::spell_check_package()` clean;
    the pkgdown workflow on the PR builds.
  - Files: `NEWS.md`, `R/fit-sem.R` (roxygen), `R/sem-syntax-help.R`, `vignettes/articles/guide-changes.qmd`,
    `vignettes/articles/lavaan-comparison.qmd`.

- [ ] **T10. Ecosystem notice (R-10, E-6).** Size S, needs permission per repo.
  - Draft the `[BREAKING]` issue (2-month notice, opens the clock with the 0.14.0 release) in medfit; ask before
    filing. Draft the RMediation change (pass the settings explicitly in `R/00_classes.R` examples and
    `test-mbco-semfit*.R`) and the missingmed line 236 note; both are other repos and need the author's explicit
    go-ahead, one action at a time.
  - Acceptance: issue text in `planning/` reviewed; RMediation PR opened only on approval.

### Checkpoint C: release readiness (0.14.0)

- [ ] Version bump, `.STATUS`, README version row, CLAUDE.md status paragraph.
- [ ] Gates green on the release PR (`dev → main`); `R-CMD-check` green on `main`.
- [ ] Dependents' evidence (`arm.R`) attached to the release PR (spec: each release PR).
- [ ] GitHub release; site redeploys from `main`.

## 0.15.0 (not this plan; recorded so nothing is lost)

R-7 flip and formals (`meanstructure = TRUE`, `fixed_x = TRUE`), obsolete-option note; R-12/E-15 oracle matrix
(four combinations × weights + sandwich, fixed and constrained intercepts, latent mediator, four-way product, factor
covariate, named subset); E-11 VERIFY lavaan's product-column treatment; E-12 reliability non-inferiority blocker;
`test-api-freeze.R` update; R-9 rewrite half (articles re-rendered, printed logLik/AIC diffed); option removal in
0.16.0.

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| T1 restore-zero rule zeroes a row that is not pinned (a tangent with a tiny component) | High: a real SE reported as 0 | restore only rows that are exactly zero in the theta-unit basis from `.sem_active_set()`; metamorphic test with a nearly pinned parameter |
| T3 misses a baseline that depends on the default | Med: silent baseline drift in 0.15.0 | grep check for unpinned `fit_sem()` in `tests/sim/`; opt-in arm at Checkpoint B surfaces the rest |
| Warning floods dependents' CI | Med | once per session; RMediation change in T10; opt-in documented |
| OpenMx adapter for means needs raw data or cov+means | Med: T4b larger than sized | split T4b (fixed paths first, means second) if it exceeds one session |
| Gates job timeouts (ubuntu-26.04 history) | Low after #312 pin | gates stay on ubuntu-24.04 |

## Open questions

1. T3 is mechanical but touches many files: one PR, or split `tests/sim` and `tests/testthat`? (Recommendation: one
   PR; the diff is uniform and the gates must see it whole.)
2. Where the helpers live: `R/fit-sem.R` or a new `R/native-defaults.R`? (Recommendation: new file; it is removed
   wholesale in 0.16.0 with the option.)
