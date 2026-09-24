# Plan: joint natural effects with exposure × mediator products (D8(b), module `joint-xm-lm`)

**Date:** 2026-09-23 · **Status:** **approved** 2026-09-23
**Spec:** [SPEC-joint-mediator-interactions-2026-09-23.md](SPEC-joint-mediator-interactions-2026-09-23.md) (approved) ·
**Decisions:** [GRILL-joint-mediator-interactions-2026-09-23.md](GRILL-joint-mediator-interactions-2026-09-23.md) G1–G9
**Where:** two worktrees, created only on an explicit "make the worktree":
- `~/.git-worktrees/medfit/feature-joint-core`, branch `feature/joint-core` from `dev`, for **PR A**;
- `~/.git-worktrees/medfit/feature-joint-methods`, branch `feature/joint-methods` from `dev` after
  PR A merges, for **PR B**.

## Approach

Build the verification harness first and prove it on cases with known answers, before any
estimator code exists. The estimator is then written against oracles that were already shown to
work, and the planted defects show the oracles can catch a real mistake. Point estimates are
settled (T4–T5) before standard errors (T6), because an SE oracle is meaningless on a wrong
estimate.

```
T0 preflight ──→ T1 harness (self-validated) ──→ T2 class ──→ T3 routing/guards
                                                                   │
                         T6 gradients + SE ←── T5 oracles ←── T4 extractor worker
                                  │
                                  └──→ T7 PR A gates + PR ══ merge ══→ T8 print/summary
                                                                          │
                                              T10 docs + PR B ←── T9 confint/tidy/glance
```

All tasks are sequential. T2–T6 touch the same files, so parallel work would only create merge
conflicts.

## Risks

| Risk | Mitigation |
|---|---|
| CI silently skips the heavy `skip_on_cran()` oracles (no workflow sets `NOT_CRAN`; the latest run's logs have expired, HTTP 404) | T0 reads the testthat skip summary on the first PR A push. If the heavy oracles show as skipped "On CRAN", ask before adding `NOT_CRAN: true` to the workflow (a Boundaries "ask first" item) |
| The harness itself is wrong, so every oracle agrees with a wrong estimator | T1 validates each helper on no-product cases whose answer is a closed form medfit already ships (`ParallelMediationData` NIE, `SerialMediationData` pieces) before T4 starts |
| Raw vs propagated `β1` wiring (G8 finding 1) | T4 computes propagated `β*` in one helper. T5's downstream-product fixture (`X:M2`, `d ≠ 0`) and the raw-wiring planted defect catch a mix-up |
| Gradient terms missed (intercepts, covariate coefficients, `d`) | T6 checks the analytic gradient against a central-difference gradient computed in the **test** (no new dependency) to 1e-6, per effect, before the bootstrap oracle runs |
| Parallel cross-equation vcov wrong | T6's SE oracle uses a correlated-error parallel fixture (`rho = 0.5`), where a block-diagonal vcov would miss by well over 3% |
| CRAN runtime | Always-on companions use n ≤ 500 and no simulation loops. T7 measures the always-on runtime against the 10 s target |
| Scope creep into later modules | Every M×M, lavaan-joint or non-Gaussian request errors. Widening needs asking first |

## Tasks

### PR A: core (`feature/joint-core`)

- [ ] **T0: Preflight (runtime budget and CI coverage).**
  - Acceptance:
    - The always-on runtime budget is set (10 s target) and recorded in this plan.
    - On the first push of `feature/joint-core`, the CI testthat summary for the canary test in
      T1 shows whether `skip_on_cran()` tests run.
    - If they are skipped, the proposed one-line workflow change goes to the user, and nothing
      changes until they answer.
  - Verify: the CI log line `[ FAIL 0 | WARN 0 | SKIP n | PASS m ]` and its skip reasons ("On CRAN").
  - Files: none, or `.github/workflows/R-CMD-check.yaml` after approval.
- [ ] **T1: Verification harness, validated on known answers.**
  - Acceptance: `tests/testthat/helper-joint.R` defines `sim_joint()`, `true_joint_effects()`,
    `gcomp_joint()`, `boot_joint_se()`, `effects_from()` and `fit_joint()`, as in the spec's
    harness table. Self-tests in `test-joint-harness.R`:
    - With no product, `true_joint_effects()` on a parallel data-generating process equals
      `Σ a_i b_i` from the true parameters (Monte Carlo tolerance), and on a serial one equals the
      all-paths sum.
    - `gcomp_joint()` on no-product fits equals the existing `ParallelMediationData` NIE (Monte
      Carlo tolerance).
    - `effects_from(obj, effect_fn = broken)` returns different numbers from
      `effects_from(obj)`, proving the defect-injection path works.
    - A `skip_on_cran()` canary test for T0.
  - Verify: `testthat::test_file("tests/testthat/test-joint-harness.R")`, all pass.
  - Files: `tests/testthat/helper-joint.R`, `tests/testthat/test-joint-harness.R`.
- [ ] **T2: `JointMediationData` class.**
  - Acceptance:
    - Class as in the spec sketch (path slots, effect slots, named `m_star`), with the validator:
      relative tolerance, NIE and CDE path ties, `m_star` names.
    - `S7::S4_register()` added in `.onLoad()` before `methods_register()`.
    - Roxygen with `@export`.
    - `_pkgdown.yml` classes entry.
  - Verify: validator tests (a good object builds; a bad `total_effect`, a broken NIE tie, a broken
    CDE tie and wrong `m_star` names each fail with their message).
  - Files: `R/classes.R`, `R/zzz.R`, `_pkgdown.yml`, `tests/testthat/test-extract-joint.R`.
- [ ] **T3: Routing and guards.**
  - Acceptance: in `.extract_mediation_lm_impl()`'s multi-mediator branch:
    - Hits are partitioned by model. Outcome-model treatment × mediator terms written with `:` or
      `*` are allowed; everything else goes to `.stop_on_unsupported_joint_products()`, naming
      the term and the model.
    - Every G8 check errors with a message naming the cause: all mediators in the outcome,
      numeric 0/1 treatment, identity link, mediator order, identical row names, weights,
      intercept, identical covariate sets (G4), `decomposition = "two_way"` with a product, a
      conflicting `structure`, a non-default `vcov_fun`, and an unused or unknown `m_star` via
      `.stop_on_unused_m_star()` and the G3 names check.
    - Supported fits route to a stub `.extract_joint_mediation_lm()` (filled in T4).
    - No-product fits are unchanged.
  - Verify:
    - test group 6, plus group 8's error rows, each with a regex naming the term or cause;
    - a snapshot test that no-product serial and parallel outputs are byte-identical to `dev`;
    - the existing `test-multimediator-interaction-guard.R` still passes, with any updated
      expectation stated in the commit.
  - Files: `R/extract-lm.R`, `tests/testthat/test-extract-joint.R`.
- [ ] **T4: Extractor worker.**
  - Acceptance: `R/extract-joint.R`, `.extract_joint_mediation_lm()`:
    - A `.propagate_mediator_means()` helper computes `β0*(i)`, `β1*(i)`, `γ*(i)` by recursion
      (serial) or copies them (parallel).
    - Effects are evaluated at `c̄` (unit contrast).
    - `@estimates` carry prefixed source rows (`m1_`, `m2_`, …, `y_`) plus path aliases.
    - `@vcov` is stacked OLS, with cross-blocks `σ̂_ij (Xi'Xi)⁻¹ Xi'Xj (Xj'Xj)⁻¹`.
    - The worker accepts K = 1 internally, for the reduction test only.
  - Verify: test group 4 (propagation identity, 1e-10), zero serial and outcome cross-blocks
    (1e-10), and the K = 1 reduction against `InteractionMediationData` (1e-10).
  - Files: `R/extract-joint.R`, `tests/testthat/test-extract-joint.R`.
- [ ] **T5: Point-estimate oracles.** *(checkpoint)*
  - Acceptance:
    - test group 1 (counterfactual truth within 3 SE) on three fixtures: serial `X:M1`, serial
      `X:M2` with `d ≠ 0`, and parallel `X:M1`;
    - group 2 (g-computation within 4 Monte Carlo SEs);
    - group 3's parallel reduction (1e-8);
    - the G1 pin (group 8);
    - group 9's planted defects (sign-flipped `θ3`, raw `β1`) each **fail** oracles 1–2.
    - Heavy versions use `skip_on_cran()`; always-on companions pin values to 1e-8.
  - Verify: `devtools::test(filter = "extract-joint")`, all pass, planted defects caught.
  - Files: `tests/testthat/test-extract-joint.R`.
- [ ] **T6: Gradients, SEs, effect generics, bootstrap acceptance.**
  - Acceptance:
    - `.effect_gradients()` gains a method for the class, with analytic partials for every term
      the spec lists.
    - `nie()`, `nde()`, `te()`, `pm()` (warns and returns `NA` when TE is near 0), `decompose()`
      and `paths()` methods.
    - `R/bootstrap.R`'s `.assert_param_mediation_data()` accepts the class.
  - Verify:
    - analytic vs central-difference gradient, computed in the test, per effect (1e-6);
    - test group 5 (delta-method SE within 3% of the bootstrap SD, serial and `rho = 0.5`
      parallel);
    - `bootstrap_mediation(method = "plugin")` accepts the object (group 8).
  - Files: `R/effect-se.R`, `R/generics-effects.R`, `R/bootstrap.R`,
    `tests/testthat/test-extract-joint.R`.
- [ ] **T7: PR A gates and PR.** *(checkpoint)*
  - Acceptance:
    - NEWS "New features" entry (class and extraction) that states the estimand and the G1
      difference;
    - `inst/WORDLIST` additions, inserted in place;
    - `devtools::document()` with the roxygen churn reverted;
    - the always-on runtime measured against 10 s;
    - the E2E transcript (D8 case and downstream `X:M2` case, fresh session, oracle 1 within
      3 SE);
    - the T0 CI coverage outcome recorded.
  - Verify: full `devtools::test()` (0 failed, 0 errors); CI-style lint (0); spelling clean;
    `urlchecker::url_check()`; strict check 0/0 plus only the Date note; PR to `dev` with counts,
    the planted-defect results and the transcript. Ask before merging.
  - Files: `NEWS.md`, `inst/WORDLIST`, `man/*.Rd`.

### PR B: methods and docs (`feature/joint-methods`, after PR A merges)

- [ ] **T8: `print()` and `summary()`.**
  - Acceptance: `print()` says "joint NIE (all paths through M1..MK)" (G1), lists the interacting
    mediators and `m_star`, and states the structure. `summary()` follows the
    `InteractionMediationData` layout without the four-way block.
  - Verify: snapshot tests for serial and parallel.
  - Files: `R/classes.R` or `R/methods-base.R`, `tests/testthat/test-extract-joint.R`.
- [ ] **T9: `confint()`, `tidy()`, `glance()`, bootstrap recipe.**
  - Acceptance:
    - `confint(parm = "paths" | "effects")` warns about the normal approximation;
    - `tidy()` types `paths` and `effects`, silent, with numeric SEs from `.effect_se()`;
    - `glance()` gains `structure`, `n_mediators`, `interactions` and `m_star` (`"M2=0"`);
    - a documented `statistic_fn` recipe (full `@estimates`, closes over `c̄`).
  - Verify: test group 7 (tidy silent, `confint()` equals `tidy(conf.int = TRUE)` to 1e-12, the
    recipe reproduces NDE/NIE exactly, `glance()` columns).
  - Files: `R/methods-base.R`, `R/methods-tidy.R`, `tests/testthat/test-extract-joint.R`.
- [ ] **T10: Docs, gates and PR.**
  - Acceptance:
    - The class `@details` covers the estimand (joint, no per-path split), the G1 difference, the
      whole-vector assumptions (with the "outside the mediator vector" wording), identical
      covariate sets as a medfit limitation, the covariate evaluation point with a conditional SE,
      and the precomputed-column warning in plain words.
    - A section in the "Model Extraction" article using `mediation_demo$outcome_int`.
    - NEWS entries for the methods.
  - Verify: same gates as T7; `pkgdown::build_site()` renders the new topic and article section;
    E2E transcript; PR to `dev`. Ask before merging.
  - Files: `R/classes.R`, `vignettes/*.qmd`, `NEWS.md`, `man/*.Rd`.

## Checkpoints

1. **After T1:** the harness reproduces known answers on no-product cases, and defect injection
   changes the numbers. No estimator code exists yet.
2. **After T5:** point estimates pass the counterfactual truth and g-computation on all three
   fixtures, and both planted defects are caught. Only then do standard errors start.
3. **After T7 (PR A merged):** the class is usable through `nie()`/`nde()`/`te()`/`decompose()`
   with verified SEs. The T0 CI outcome is known. PR B starts from the merged `dev`.
