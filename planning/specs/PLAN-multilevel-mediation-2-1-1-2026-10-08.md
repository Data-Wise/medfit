# Plan: multilevel mediation, module 1, cluster-level treatment (2-1-1)

**Date:** 2026-10-08 · **Status:** **APPROVED** 2026-10-08 after two Codex adversarial reviews (round 1: P4, P5; round 2: P6); the P6 edit was not re-reviewed
**Spec:** [SPEC-multilevel-mediation-2-1-1-2026-09-25.md](SPEC-multilevel-mediation-2-1-1-2026-09-25.md) (approved 2026-09-25, revision 2) ·
**Decisions:** [GRILL-multilevel-mediation-ext-d-2026-09-25.md](GRILL-multilevel-mediation-ext-d-2026-09-25.md) D1–D16 ·
**Background:** [REVIEW-multilevel-mediation-2026-09-25.md](REVIEW-multilevel-mediation-2026-09-25.md)
**Where:** this plan is written on `feature/ext-d-module1-plan` (from `origin/dev`). The code lands in three
PRs, each on its own branch from `dev`, created only on an explicit "make the branch" (or worktree):
`feature/cluster-extract` (PR A), `feature/cluster-fit` (PR B, after A merges),
`feature/cluster-boot` (PR C, after A merges; B and C are independent).

## Approach

Same discipline as the joint-mediator work (`PLAN-joint-mediator-interactions-2026-09-23.md`): build the
verification harness first and prove it on cases with known answers before any estimator code exists, settle
point estimates before standard errors, and run the simulation gates before the first PR merges, because the
spec says a failed SE-ratio or D4-correlation gate sends D4 back to the grill.

```
T0 preflight ─→ T1 harness (self-validated) ─→ T2 class ─→ T3 routing/guards ─→ T4 term detection, R1, products
                                                                                          │
              T8 methods + print ←─ T7 gradients/SE/generics ←─ T6 point oracles ←─ T5 vcov assembly
                     │
                     └─→ T9 simulation gates (checkpoint) ─→ T10 PR A gates + PR ══ merge ══┬─→ T11 fit engine ─→ T12 KR + warnings ─→ T13 PR B
                                                                                          └─→ T14 cluster bootstrap ─→ T15 TE oracle, docs, PR C
```

T2–T8 touch the same files, so they run in sequence. After PR A merges, PR B and PR C can run in either order.

## Coordination with the native SEM engine

Ext D goes first (native-engine ledger K6). Shared hot spots, to avoid conflicts: `R/fit-glm.R` (engine dispatch and
checks, PR B here, N4 there), `DESCRIPTION` (Suggests here, Imports `nloptr` there), `NEWS.md`, `_pkgdown.yml`,
`R/zzz.R`. The native engine's N4 waits for PR B to merge. Which release carries which is not assigned yet (both
may claim 0.6.0).

## Decisions this plan makes where the spec is silent

| # | Question | Plan decision | Why |
|---|---|---|---|
| P1 | Behavior 10 puts `se_type = "kr"` in extraction, but Delivery puts KR in PR B | PR A's `lmer` method accepts `se_type = "model"` only and errors "kr arrives with the fit engine" for `"kr"`; PR B adds KR to both routes | Follows the spec's Delivery section, which is the more specific statement; the PR A SE gates then cover model-based SEs only, as Delivery says |
| P2 | The planted defects mock helpers that do not exist yet (`.raw_to_within`, the relabel helper) | Create them as separately named internal functions (`.raw_to_within()` in T4, `.relabel_clusters()` in T14) so `local_mocked_bindings()` can reach them | The spec's group 8 injects defects through those names |
| P4 | The spec says the A2 warnings fire "once per call" and names `.notify_once()`, but that helper is **session-wide** (`R/zzz.R:23`: keyed state, `message()`, at most once per session), so a second qualifying fit in the same session would stay silent and the spec's own test (warn at J = 20 and J = 8) would pass only for the first fit | Emit each A2 warning with base `warning(call. = FALSE)` (the house style, as in `R/generics-effects.R:350`), once per `extract_mediation()` call, with no keyed state; test two qualifying calls in one session, each warning exactly once | The spec's behavior (once per call) wins over its parenthetical naming the wrong helper; `.notify_once()` stays for advisory nudges in refit loops |
| P5 | The spec assigns the TE oracle to PR A (Outcomes table) and to PR C (Delivery) | The TE oracle runs in **PR A** (T9); PR C only repeats it through `bootstrap_mediation(cluster = )` | `te_oracle()` takes its SE from the harness's own cluster bootstrap, so it does not depend on PR C; running it before PR A merges means a failed check cannot force rework after integration |
| P6 | Behavior 6 detects the mean term by values (constant within clusters, exact affine function of the cluster mean), but when every cluster has the same mean of M the intercept meets that rule and the between effect is not identifiable; the spec has no guard (found by the second adversarial review) | `.find_cluster_mean_term()` never considers `(Intercept)`, requires `sd(cluster means) > 1e-8 * max(1, sd(M))` on the model rows and a matched column that is present and non-aliased in `fixef()` (lme4 drops rank-deficient columns), and otherwise errors "no between-cluster variation in the mediator, so the between-cluster effect is not identifiable" | A misleading NIE is worse than an error; the guard costs one variance check and one membership check |
| P7 | The spec's harness table lists `effects_from()` as new, but `tests/testthat/helper-joint.R` already defines it, and it is generic (an object, or a planted-defect `effect_fn`); testthat sources helpers alphabetically, so a second definition would silently be replaced by the joint one | `helper-cluster.R` reuses the joint `effects_from()` and does not redefine it | One shared name is what the spec's group 8 assumes; the call happens at test time, so load order does not matter |
| P8 | The spec gives `true_cluster_effects(dgp, seed)`, but its "same noise in every world" wording needs the noise of the simulated units | `sim_cluster211()` stores every noise draw in the object it returns and `true_cluster_effects(dgp, defect)` recomputes counterfactuals on those units; `seed` is dropped, and the `defect` hook plants a wrong truth for the self-tests | The truth is then exact (no Monte Carlo error), so the self-tests use 1e-10, a stronger check than the spec's tolerance |
| P9 | The plan puts `lme4` in `DESCRIPTION` Suggests in T10, but T3's `R/extract-lmer.R` calls `lme4::` and `requireNamespace("lme4")`, and `R CMD check` reports "'::' or ':::' import not declared from: 'lme4'" (a WARNING) the moment that file exists | `lme4` moves to Suggests in T3; `pbkrtest` stays in T10, where KR first needs it | The check scans `R/`, not only `tests/` (T1's tests-only use passed); every push from T3 on would otherwise fail the r-lib check |
| P10 | Behavior 8 says level-1 covariates "with no cluster-mean companion" are accepted but does not define a companion when the covariate is already cluster-mean centered | `covariates_centered` is TRUE when every level-1 column has zero cluster means or has a column constant within clusters that is an exact affine function of its cluster mean; FALSE otherwise | Matches the printed claim ("upper-level robustness holds only if level-1 covariates are cluster-mean centered"); centered-without-companion is the harness's `cov = "centered"` case |
| P11 | The spec's `.find_cluster_mean_term()` skips zero-variance columns, so with equal cluster means it would report a misleading "missing mean term" rather than the identifiability problem | `.lmer_terms()` checks between-cluster variance first (P6) and then detects; the planted-defect test shows a detector without the intercept exclusion and the zero-variance skip returns `(Intercept)` | The error names the real cause |
| P12 | Spec group 9's second run says "uncentered covariates correlated with u_j"; the harness's `cov = "confounded"` instead gives the level-1 covariate a between-cluster part that drives both M and Y | The uncentered run uses `cov = "confounded"` with the covariate entered raw (`cov_terms = "C"`), and the centered control enters `C_w` and `C_bar`; the claim tested is the one Behavior 8 prints (own is robust to upper-level confounding only with cluster-mean centering) | The mechanism is the printed claim, and the harness can make it fail: own bias z = -5.5 uncentered vs -0.8 centered |
| P13 | T10 adds `pbkrtest` to Suggests, but PR A has no Kenward-Roger code (it is refused until PR B, P1) | `pbkrtest` is added to `DESCRIPTION` in T12, where KR first calls it | A Suggests entry with no use in `R/`, `tests/` or `vignettes/` is dead weight in the PR that introduces it |
| P3 | `tests/sim/` does not exist | T9 creates it with `^tests/sim$` in `.Rbuildignore` and `tests/sim/results/` for the CSVs | Spec project structure; heavy runs stay out of testthat and out of the tarball |

## Spec inconsistencies found while planning

The spec is approved, so it is not edited here. Each item is resolved in the plan (P1, P4, P5, P6); an errata note on the spec is optional and the author's call.

| Spec text | Conflict | Resolution |
|---|---|---|
| Behavior 10 (KR in extraction) vs Delivery (KR in PR B) | placement | P1 |
| Behavior 6: value-based detection, no identifiability guard | gap, not a conflict: the intercept can match the mean-term rule | P6 |
| Behavior 11 and test group 7: "once per call (`.notify_once`)" | `.notify_once()` is once per session | P4 |
| Outcomes table (TE oracle in PR A) vs Delivery (TE oracle in PR C) | placement | P5 |

## Risks

| Risk | Mitigation |
|---|---|
| The harness is wrong, so every oracle agrees with a wrong estimator | T1 validates each helper on balanced cases whose answer is a closed form (`a·b_B`, `a·b_W`) before T4 starts, and shows defect injection changes the numbers |
| Value-based term detection (Behavior 6) accepts the intercept when cluster means of M are all equal | P6: intercept excluded, between-cluster variance and non-aliasing required, error otherwise; T4 plants the intercept-accepting detector |
| Value-based term detection (Behavior 6) mislabels a column | T4 tests grand-mean centering, `scale()`, near-miss means and uncentered raw terms, and asserts the rescaled coefficient and vcov (1e-8) |
| The SE ratio or D4 correlation fails with unbalanced clusters or random within-slopes | T9 is a checkpoint before PR A; a failure sends D4 back to the grill (spec Outcomes), so PR A does not merge on a hope |
| Heavy tests are silently skipped on CI | The spec records that r-lib's check action sets `NOT_CRAN = "true"` (settled in the joint work); T0 re-confirms it with a canary test on the first push of `feature/cluster-extract` and reads the SKIP summary |
| lme4 optimizer changes move pinned values | Pinned constants use 1e-6 relative; within-run identities use 1e-8 (spec Testing strategy) |
| noSuggests CI job breaks | Every lme4 test starts with `skip_if_not_installed("lme4")`, KR tests also with pbkrtest; lme4 examples are wrapped in `requireNamespace()` |
| CRAN runtime | Always-on companions avoid simulation loops; T10 measures `test-cluster-211.R` against the 10 s target |
| Scope creep into module 2 or into non-goals | Every non-goal that code can reach errors naming the fix (test group 6); widening scope is an "ask first" item |
| New dependency creep | Only `lme4` and `pbkrtest` in Suggests; `lmerTest` is not added, and subclass dispatch is tested with a local `setClass(contains = "lmerMod")` |

## Tasks

### PR A: class, extraction, effects, methods (`feature/cluster-extract`)

- [x] **T0: Preflight.** *(done 2026-10-08: lme4 2.0.6 and pbkrtest 0.5.5 installed, neither in `DESCRIPTION` until T10; the 10 s budget is in the Risks table; canary RESOLVED on draft PR #90 (commit 5b37366): `skip_on_cran()` tests run on CI. ubuntu release/devel `[ FAIL 0 | WARN 0 | SKIP 3 | PASS 1837 ]`, equal to the local `NOT_CRAN=true` pass count; the noSuggests job `[ FAIL 0 | WARN 0 | SKIP 74 | PASS 1324 ]`, so the lme4 tests skip cleanly without lme4)*
  - Acceptance:
    - The always-on runtime budget (10 s) is recorded in this plan.
    - `lme4` and `pbkrtest` are confirmed available locally (lme4 2.0.6, pbkrtest 0.5.5 on this machine) and absent from the noSuggests job.
    - A `skip_on_cran()` canary test (added in T1) shows on the first CI push whether skipped tests run; the SKIP summary is recorded.
  - Verify: the CI line `[ FAIL 0 | WARN 0 | SKIP n | PASS m ]` and its skip reasons.
  - Files: none, or `.github/workflows/R-CMD-check.yaml` only after asking.
- [x] **T1: Verification harness, validated on known answers.** *(checkpoint 1; done 2026-10-08, `test-cluster-harness.R`: 38 pass, 0 fail; a planted mutation of the truth fails 4 expectations. Not yet exercised: `fit_cluster211()` T6, `te_oracle()` and `sim_gate()` T9. `R CMD check` reports "unstated dependencies in tests ... OK" with `lme4::` in the helper, so lme4 stays in T10.)*
  - Acceptance: `tests/testthat/helper-cluster.R` defines `sim_cluster211()`, `true_cluster_effects()`, `fit_cluster211()`, `te_oracle()`, `effects_from()` and `sim_gate()` as in the spec's harness table, following the existing `helper-joint.R` conventions (a default parameter list, a sim function that returns data plus true parameters, `effects_from(obj, effect_fn = NULL)`). Self-tests in `test-cluster-harness.R`:
    - On a balanced class-mean process, `true_cluster_effects()` NIE equals `a·b_B` and the exact own effect equals `a·b_W + a·(b_B − b_W)/n_j` from the true parameters (Monte Carlo tolerance), without calling any package effect function.
    - `effects_from(obj, effect_fn = broken)` returns different numbers from `effects_from(obj)`.
    - `sim_cluster211(process = "peer_mean")` and `slope_sd > 0` and `cov = "confounded"` each change the data in the stated way.
    - A `skip_on_cran()` canary (for T0).
  - Verify: `testthat::test_file("tests/testthat/test-cluster-harness.R")`, all pass.
  - Files: `tests/testthat/helper-cluster.R`, `tests/testthat/test-cluster-harness.R`.
- [x] **T2: `ClusterMediationData` class.** *(done 2026-10-08, `test-cluster-211.R`: 30 pass; full suite 0 failed, 0 errors. `show` is registered with a short `print()`; the `print.summary` registration moves to T8 with the `summary()` method it needs. `data` keeps the empty-data-frame default like the other classes, `kr_df` has an explicit `NULL` default.)*
  - Acceptance:
    - Class and properties as in the spec sketch, with the validator: scalars have length 1; `n_clusters == length(cluster_sizes)`; `sum(cluster_sizes) == n_obs`; alias rows `a`, `c_prime`, `b_within`, `b_between` present in `estimates` and `vcov` and equal to the path properties; `parameterization` and `se_type` in their sets; `kr_df` present iff `se_type == "kr"`.
    - `kr_df` default handled against the `class_numeric | NULL` pitfall (`numeric(0)`).
    - `S7::S4_register()` added in `.onLoad()` before `methods_register()`; `show` and `print.summary` registrations; roxygen with `@export`; `_pkgdown.yml` classes entry.
  - Verify: validator tests (a good object builds; each broken invariant fails with its message).
  - Files: `R/classes.R`, `R/zzz.R`, `_pkgdown.yml`, `tests/testthat/test-cluster-211.R`.
- [x] **T3: Routing and guards (Behavior 1–5).** *(done 2026-10-08, 24 new tests in `test-cluster-211.R`; mutating the within-cluster, glmer and row-identity guards each fails a test. After the guards, `.extract_mediation_lmer()` stops with an internal "not implemented yet" until T4/T5. `lme4` moved into Suggests in this task, P9.)*
  - Acceptance: `R/extract-lmer.R` (new), `.extract_mediation_lmer()`, registered for `merMod` in `.onLoad()` behind `requireNamespace("lme4")`:
    - `glmerMod` gets the D7 error; `lmerMod` and subclasses dispatch.
    - `cluster` defaults to the single shared grouping factor; several or differing factors error asking for `cluster =`.
    - A missing `(1 | cluster)` intercept errors with the corrected formula.
    - Treatment varying within a cluster errors ("1-1-1 designs are not supported yet").
    - Different rows, cluster vectors or treatment vectors across the two models error (D12).
    - `vcov_fun` on the lmer method errors; `se_type` accepts `"model"` only in this PR (P1).
  - Verify: test group 6 rows for these checks, each with a regex naming the term or model; subclass dispatch through a local `setClass(contains = "lmerMod")`.
  - Files: `R/extract-lmer.R`, `R/zzz.R`, `tests/testthat/test-cluster-211.R`.
- [x] **T4: Term detection by values, R1, product and slope guards (Behavior 6–8).** *(done 2026-10-08, 94 pass in `test-cluster-211.R`; mutating the P6 guard, the product guard and the affine tolerance each fails tests. Product detection also covers a product written without its main effect (`M_w:C` without `C`). After the guards `.extract_mediation_lmer()` still stops "not implemented yet" until T5.)*
  - Acceptance:
    - `.find_cluster_mean_term()` as in the spec's code style block (constant within clusters, exact affine function of the cluster mean on the model rows), plus the within and raw term finders; coefficients and vcov rescaled by the affine slope.
    - `.raw_to_within()` as its own function (P2): `b_B = b_W + κ`, vcov `J V J'`.
    - Identifiability guard (P6): `(Intercept)` is excluded from detection; zero between-cluster variation in M (every cluster mean equal to within 1e-8 relative) or a mean term dropped by lme4 as aliased errors "no between-cluster variation in the mediator", never returning the intercept as the between term.
    - A missing mean term errors with the corrected formula; a near-miss (constant within clusters, correlation above 0.99 with the cluster mean, not affine) errors "the cluster mean must be computed on the rows the models use".
    - Product guards run on value-detected names (any mediator term times `X` or a covariate, including `I(X * M)`); random slopes read from `lme4::getME(fit, "cnms")`: within-term slope accepted; slope on raw M, on the mean term or on X errors.
    - Level-1 covariates with no cluster-mean companion are accepted and set `covariates_centered = FALSE` (drives Behavior 8's printed line).
  - Verify: test group 2 (R1 identity 1e-8, affine detection under grand-mean centering and `scale()` 1e-8) and group 6's remaining rows, plus a P6 row: data whose cluster means of M are all equal fit without error in lme4 but `extract_mediation()` errors with the regex "between-cluster variation", and a planted detector that accepts the intercept fails that row.
  - Files: `R/extract-lmer.R`, `tests/testthat/test-cluster-211.R`.
- [x] **T5: vcov assembly and object construction (Behavior 9).** *(done 2026-10-08, 152 pass in `test-cluster-211.R`, full suite 530 tests 0 failed; `@vcov` is T V T' for the linear map T from the stacked fixed effects, then the mediator and outcome blocks are zeroed exactly; mutating the zeros and the `a` alias each fails tests. `extract_mediation()` on an lmer pair now returns a `ClusterMediationData`. `data` keeps the class default; the mediator name is checked against the mediator model's response.)*
  - Acceptance: `@vcov` block-diagonal over the alias rows plus each model's full fixed effects, coerced to base matrices (lme4 returns a `dpoMatrix`); `@estimates` carries prefixed source rows plus the aliases; `n_clusters`, `cluster_sizes`, `parameterization`, `sigma_*`, `tau_*`, `reml`, `converged` filled; the object validates for both parameterizations.
  - Verify: validator passes on fits from both parameterizations; `vcov()` is a base matrix; block zeros between the `a` and outcome blocks are exactly zero.
  - Files: `R/extract-lmer.R`, `tests/testthat/test-cluster-211.R`.
- [x] **T6: Point-estimate oracles.** *(checkpoint 2; done 2026-10-08, 168 pass with `NOT_CRAN=true`, 154 pass + 5 skips without; full suite 536 tests 0 failed. Group 1 at J = 200, n_j = 30, centered covariates: |z| for NIE, NDE, TE = 0.62, 1.55, 1.03 for both parameterizations; O3 own 0.66, spillover 0.26; O4 gap = 11.7 SE of own; O5 peer-mean own 0.1500 vs class-mean D-own 0.1825 (reported); planted defects: NIE as a b_W 7.8 SE, spillover sign 20.7 SE, raw read as within moves b_between by b_within. The effect generics and SEs arrive in T7, so these tests read effects off the paths and take delta SEs from `@vcov`. The always-on companion is a regression pin of a J = 12 fit, not a truth check. Always-on runtime of the file: 1.9 s.)*
  - Acceptance:
    - Group 1: NIE, NDE and TE within 3 SE of `true_cluster_effects()` (J = 200, n_j = 30, centered covariates), both parameterizations; the pinned small-J companion stays always-on.
    - Group 4: O3 (n_j = 50, own within 3 SE of the exact own effect), O4 (dyads: the miss equals `a·(b_B − b_W)/H` to Monte Carlo error, contextual effect large enough that the gap exceeds 6 SE of own), O5 (peer-mean process, unbalanced sizes 2–10: the difference is reported, not gated), and spillover against true NIE minus true own at n_j = 50.
    - Group 8's point-estimate planted defects each fail their oracle at the stated size: NIE as `a·b_W` via `effects_from(effect_fn = )`; spillover sign flipped; raw read as within via `local_mocked_bindings(.raw_to_within = )`.
    - Heavy versions use `skip_on_cran()`; always-on companions pin values to 1e-6 relative.
  - Verify: `devtools::test(filter = "cluster-211")`, all pass, planted defects caught.
  - Files: `tests/testthat/test-cluster-211.R`.
- [x] **T7: Gradients, SEs, effect generics, bootstrap acceptance.** *(done 2026-10-08, 196 pass in `test-cluster-211.R`, full suite 543 tests 0 failed. Each gradient matches a central difference to 1e-6 and the SEs equal T6's hand delta method; a wrong spillover gradient and a removed D11 threshold each fail a test. `decompose()` returns own, spillover and nie with a `label` attribute; the D11 warning fires on dyads and not at n_j = 50. `paths()` returns a, b_within, b_between, c_prime.)*
  - Acceptance:
    - `.effect_gradients()` gains a `ClusterMediationData` branch: NIE `(a: b_B, b_between: a)`, own `(a: b_W, b_within: a)`, spillover `(a: b_B − b_W, b_between: a, b_within: −a)`.
    - `nie()`, `nde()`, `te()`, `pm()`, `paths()` and `decompose()` methods; `decompose()` labels its parts "cluster-average, large-cluster approximation" and warns when `|a·(b_B − b_W)|/H` exceeds half the own effect's SE (D11).
    - `.assert_param_mediation_data()` in `R/bootstrap.R` accepts the class.
  - Verify: analytic gradient against a central-difference gradient computed in the test (1e-6) per effect; the D11 warning fires on the dyad fixture and not on n_j = 50; `bootstrap_mediation(method = "parametric")` from `@estimates`/`@vcov` reproduces the point NIE exactly (group 7).
  - Files: `R/effect-se.R`, `R/generics-effects.R`, `R/bootstrap.R`, `tests/testthat/test-cluster-211.R`.
- [x] **T8: Base and tidy methods, print and summary.** *(done 2026-10-08, 231 pass in `test-cluster-211.R`, full suite 551 tests 0 failed. Snapshots use a hand-built object with fixed numbers so they do not depend on lme4 or the platform; mutating the `covariates_centered` branch fails 4 tests. `tidy()`/`confint()` effects are nie, nde, te, own, spillover; `coef(type = "effects")` is nie, nde, te. `med(cluster = )` already errors ("unused argument", from `glm.control`), which the test pins. The `print.summary` registration deferred from T2 is in `.onLoad`.)*
  - Acceptance: `coef()`, `vcov()`, `nobs()` and `confint(parm = "paths")` through `.path_se()`; `print()` and `summary()` end with the "Estimand and assumptions" block (design, cluster count and size range, one line per row of the assumptions table, adjusted by `covariates_centered`); `summary()` always prints the D-own gap; `tidy()` and `glance()` branches, `glance()` gains `n_clusters`; `quick()` works; `med()` does not take `cluster =`.
  - Verify: snapshot tests of `print()` and `summary()` for a centered and an uncentered fit; `confint()` equals `tidy(conf.int = TRUE)` to 1e-12; `glance()` columns.
  - Files: `R/methods-base.R`, `R/methods-tidy.R`, `R/classes.R`, `tests/testthat/test-cluster-211.R`.
- [x] **T9: Simulation gates and assumption claims.** *(checkpoint 3 PASSED 2026-10-08: `Rscript tests/sim/coverage-2-1-1.R` at R = 1000 per scenario, 33 gated checks, 0 failed, results in `tests/sim/results/coverage-2026-10-08.csv`, about 4 min on 16 cores. SE ratios (nie/own/spillover): balanced 1.013/0.981/1.008, unbalanced 0.967/1.019/0.955, random slope 1.007/0.998/1.002; D4 |r| = 0.027, 0.086, 0.028; path coverage 0.937-0.950 in every cell; TE oracle max |z| 1.64 and 0.56; claims at J = 100, R = 200: own z = 0.93, NIE z = +21.9, NDE z = -20.6, TE z = 1.6, NDE + spillover z = 1.6; uncentered own z = -5.5 vs centered -0.8. The unbalanced D4 r of 0.086 sits near the 0.1 gate, so I replicated it with two fresh seeds (0.062, -0.059): noise around zero, D4 stands. Always-on companion `sim_gate` R = 100 test added.)*
  - Acceptance: `tests/sim/coverage-2-1-1.R` (new, with `^tests/sim$` in `.Rbuildignore`, P3) runs R = 1000 on balanced 60 × 10, unbalanced sizes 3–30 and a random within-slope (the J = 15 KR scenario moves to PR B):
    - SE ratio (mean delta SE over empirical SD) in [0.9, 1.1] for NIE, own and spillover;
    - cross-replication |corr(â, b̂_B)| < 0.1 (D4);
    - Bradley (0.925, 0.975) coverage for path intervals; product coverage reported, not gated.
    - Group 9 (R = 200, J = 100, Corr(v, u) = 0.5): own bias within 2 Monte Carlo SE of zero; NIE and NDE biases more than 4 Monte Carlo SE from zero in Talloen's eqs. 17–18 directions; TE and `c′ + a·κ` unbiased; the uncentered, confounded-covariate run shows own biased.
    - **TE oracle (group 3, P5):** `te()` against the reduced-form `lmer(Y ~ X + C̄ + W + (1 | cluster))` X coefficient via `te_oracle()`, judged against the SE of the difference from the harness's cluster bootstrap, not 3 SE of either estimate.
    - Results in `tests/sim/results/coverage-<date>.csv`; the testthat companion runs R = 100 balanced with the SE-ratio band widened to [0.8, 1.2].
    - **If the SE ratio or D4 correlation fails with unbalanced clusters or random within-slopes, stop: D4 returns to the grill before PR A merges.**
  - Verify: `Rscript tests/sim/coverage-2-1-1.R`; the CSV and the gate table go in the PR body.
  - Files: `tests/sim/coverage-2-1-1.R`, `tests/sim/results/`, `.Rbuildignore`, `tests/testthat/test-cluster-211.R`.
- [x] **T10: PR A gates and PR.** *(gates passed 2026-10-08: full suite 553 tests, 0 failed, 0 errors, 2 skips, 1845 passed with `NOT_CRAN=true`; `lintr::lint_package()` 0 hits; `spelling` clean; `urlchecker` all correct; strict `devtools::check(cran = TRUE, --run-donttest, DEPENDS_ONLY, SUGGESTS_ONLY, CRAN_INCOMING and _REMOTE)` 0 errors, 0 warnings, 0 notes; always-on `test-cluster-211.R` runtime 1.4 s of test time (2.2 s wall) against the 10 s target (53 tests, 9 `skip_on_cran()` skips without `NOT_CRAN`); E2E at 40 clusters, n_j 5-25, level-1 and level-2 covariates: NIE/NDE/TE z = 1.65/0.34/1.79, TE oracle |te - oracle| / se_diff = 0.09, D11 warning fired. The `DESCRIPTION` Description line now says mixed models are extracted, with Bayesian methods planned.)*
  - Acceptance:
    - NEWS "New features" entry stating the estimand and the observed-mean model; `inst/WORDLIST` additions inserted in place; `DESCRIPTION` drops (`lme4` arrived in T3, P9; `pbkrtest` moves to T12, P13) the "future support for mixed models" line; `devtools::document()` with any roxygen churn reverted.
    - The always-on runtime of `test-cluster-211.R` measured against 10 s.
    - E2E transcript (fresh session, 40 clusters, n_j 5–25, a level-1 and a level-2 covariate, extract route): printed object with its assumptions block, `tidy()`, `decompose()` with its warning state, the oracle-1 comparison within 3 SE and the TE oracle result.
    - The T0 CI skip outcome recorded.
  - Verify: full `devtools::test()` (0 failed, 0 errors, counts quoted); CI-style lint (0 hits); `spelling::spell_check_package()` clean; `urlchecker::url_check()`; the strict check from the spec's Commands block (0 errors, 0 warnings, only the Date NOTE); noSuggests job green; PR to `dev` with counts, planted-defect results, the gate table and the transcript. **Ask before merging.**
  - Files: `NEWS.md`, `inst/WORDLIST`, `DESCRIPTION`, `man/*.Rd`.

### PR B: fit engine and Kenward-Roger (`feature/cluster-fit`, after PR A merges)

- [x] **T11: The `lmer` engine.** *(done 2026-10-08 on `feature/cluster-fit`: 272 pass in `test-cluster-211.R`, full suite 562 tests 0 failed, lint clean. Route identity to 1e-8 (also with a random within-slope through `engine_args$random_y = ~M`, 1e-6); oracle 1 through the fit route within 3 SE; mutating the complete-case filter and the slope mapping each fails tests. `med(cluster = )` still errors, now with "`cluster` is only used with engine = \"lmer\"". `se_type = "kr"` and the J < 25 warnings are T12. Level-2 covariates (no within-cluster variation) stay raw; non-numeric covariates are not split.)*
  - Acceptance: `R/fit-lmer.R` (new) and `R/fit-glm.R` dispatch: `fit_mediation(engine = "lmer", cluster = )` drops incomplete rows once (D12); flags level-1 covariates (vary within some cluster); computes `<M>_cm`, `<M>_cwc`, `<C>_cm`, `<C>_cwc` on the remaining rows; rewrites the outcome formula to the within parameterization with centered level-1 covariates plus means; adds `(1 | cluster)` to both models; fits with `REML = TRUE`. `engine_args` accepts only `random_y`, `random_m`, `REML` (`~ M` rewritten to the within term); anything else errors and `...` never reaches `lmer()`. `cluster =` and `se_type = "kr"` error with the glm and regmedint engines; `weights` and `se_type = "sandwich"` error with `lmer`; missing lme4 or pbkrtest errors naming the package. Models go to `extract_mediation()`.
  - Verify: route identity (fit route equals extract route to 1e-8, group 2); the fit-engine error rows of group 6; oracle 1 through the fit route within 3 SE.
  - Files: `R/fit-lmer.R`, `R/fit-glm.R`, `tests/testthat/test-cluster-211.R`.
- [ ] **T12: Kenward-Roger and the few-cluster warnings.**
  - Acceptance: `se_type = "kr"` in both routes (P1): needs REML (errors on ML fits, because `pbkrtest::vcovAdj()` silently returns the REML matrix); stores the KR vcov and the KR df of each path; path intervals are t intervals with the KR df, product intervals stay normal (D10); the A2 warnings are emitted once per call with `warning(call. = FALSE)` (P4: not `.notify_once()`, which is session-wide): J < 25 with model-based SEs points to `"kr"` and the cluster bootstrap; J < 10 warns whatever the SE type.
  - Verify: group 7 (KR df positive and below J for the cluster-level paths; warnings fire at J = 20 model and J = 8 any, silent at J = 30, and **two qualifying calls in the same session each warn exactly once**, so the second call is not silenced (P4)); `kr` on an ML fit errors; the J = 15 KR simulation scenario (SE ratio, D4 correlation, Bradley coverage with t intervals) added to `tests/sim/coverage-2-1-1.R`.
  - Files: `R/extract-lmer.R`, `R/fit-lmer.R`, `R/effect-se.R`, `R/methods-base.R`, `tests/sim/coverage-2-1-1.R`, `tests/testthat/test-cluster-211.R`.
- [ ] **T13: Methods article, PR B gates and PR.**
  - Acceptance: `vignettes/articles/methods.qmd` gains the 2-1-1 section (models, effects, D-own, R1, the D4 argument, the assumptions table; chunk options in the `#|` form, LaTeX per the CLAUDE.md contexts); `?ClusterMediationData` states the estimand, the assumptions and the observed-mean model; NEWS entry; E2E transcript through both routes.
  - Verify: same gates as T10; `pkgdown::build_site()` renders the article section; PR to `dev`. **Ask before merging.**
  - Files: `vignettes/articles/methods.qmd`, `R/classes.R`, `NEWS.md`, `inst/WORDLIST`, `man/*.Rd`.

### PR C: cluster bootstrap (`feature/cluster-boot`, after PR A merges)

- [ ] **T14: Cluster resampling.**
  - Acceptance: `bootstrap_mediation(method = "nonparametric", cluster = "school")` draws J cluster ids with replacement and gives each draw a fresh id through a separately named `.relabel_clusters()` (P2) before `statistic_fn` sees the data; singular fits and convergence warnings from a refit count as failures (D14), caught with `withCallingHandlers()` with per-refit messages suppressed and the count added to the existing warning; `@n_boot` already holds the successes and `BootstrapResult` is unchanged; `cluster = NULL` keeps today's row bootstrap unchanged; `cluster =` with `"parametric"` or `"plugin"` errors.
  - Verify: group 7 (every resample has J distinct ids; a forced singular fit is counted in the warning); group 6's `cluster =` with a parametric bootstrap row; the existing bootstrap tests unchanged and green; group 8's relabel defect (no relabeling, via `local_mocked_bindings` on `.relabel_clusters`, at ICC ≥ 0.3) fails the structural check and drives the SE below 0.9 × delta SE.
  - Files: `R/bootstrap.R`, `tests/testthat/test-cluster-211.R`.
- [ ] **T15: Docs, bootstrap repeat of the TE check, PR C gates and PR.**
  - Acceptance: the TE oracle (run in PR A, P5) is repeated once through `bootstrap_mediation(cluster = )` to show the two bootstraps agree (reported, not gated); NEWS entry; `CLAUDE.md`, `AGENTS.md` and `README.md` list the seventh class, the new files and the `lmer` engine.
  - Verify: same gates as T10; the no-regression row (full suite 0 failed, 0 errors); PR to `dev`. **Ask before merging.**
  - Files: `tests/sim/coverage-2-1-1.R`, `NEWS.md`, `CLAUDE.md`, `AGENTS.md`, `README.md`.

## Checkpoints

1. **After T1:** the harness reproduces closed-form answers on balanced cases and defect injection changes the numbers. No estimator code exists yet.
2. **After T6:** point estimates pass the counterfactual truth and the D-own checks, both parameterizations, and the planted defects are caught. Only then do standard errors start.
3. **After T9, before PR A:** the SE ratio, D4 correlation, path coverage and the TE oracle pass in all PR A scenarios, and the assumption claims hold. A failure reopens D4.
4. **After PR A merges:** `ClusterMediationData` works through `nie()`/`nde()`/`te()`/`decompose()` from user-supplied `lmer` fits, with verified SEs. PR B and PR C start from the merged `dev`, in either order.

## Not in this plan

Module 2 (1-1-1 designs, σ_ab, the individual-average and exact own/spillover split), `glmer`, mediator products, latent cluster means, three-level models, multilevel lavaan: all non-goals in the spec, each erroring by name where code can reach them. The native SEM engine is a separate plan on its own branch.
