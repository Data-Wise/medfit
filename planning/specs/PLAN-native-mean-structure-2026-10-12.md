# PLAN: Native mean structure, 0.9.0 (observed intercepts)

**Date:** 2026-10-12 (revised same day after an Opus adversarial review; its findings are numbered H1-H2, M1-M8, L below) | **Branch:** `feature/native-mean-structure` (not created; branching waits for your request)
**Inputs:** [SPEC](SPEC-native-mean-structure-2026-10-12.md), [GRILL](GRILL-native-mean-structure-2026-10-12.md) (G1-G7 supersede the SPEC where they differ; **this plan reverses two SPEC behaviors, see "Decisions for the author"**)
**Scope (G2, G6):** observed intercepts and exogenous means; latent variables fit with their default mean rows (latent means fixed at 0, indicator intercepts free, G7 case A). Out of 0.9.0: explicit latent means (0.11.0), the `:` operator and four-way (0.10.0).

Sizes: XS/S/M (no hour estimates, per the 0.7.0 grill D7). Checkpoints drive the schedule: **A** after T3, **B** after T6 + T8a, **C** before release.

## Dependency order

T1 -> T2 -> T3 (A) -> T4 -> T5 -> T6 + T8a (B) -> T7 -> T8b -> T9 (C)

Numbering is kept stable because the 0.10.0 plan and its GRILL cite T2, T3, T5 and T7.

## Semantics fixed by the review (read before T2/T3)

1. **Mean structure on (H1).** Any `~1` row, free **or fixed**, or `meanstructure = TRUE`, turns mean structure on, and then **every observed variable's intercept that the user did not write is free** (lavaan: `y ~ 1` also frees `m~1` and `x~1`; npar 9, df 0, logLik equal to the covariance-only fit). Models with no `~1` and no `meanstructure` fit exactly as in 0.8.0.
2. **A fixed intercept is a restriction (H1).** `y ~ 0*1` is not dropped: lavaan gives df 1, chi-square 19.36, logLik -1279.196 on the review's model. `.sem_to_ram()` currently drops every `~1` row (`R/sem-model.R:146`); under mean structure the fixed row stays as a fixed `m` entry. With `meanstructure = TRUE` the saturation step must run **before** any dropping and must not free a row the user fixed.
3. **Latent variables (M8, G7).** `meanstructure = TRUE` on a model with latent variables is supported in the G7 case-A form: latent means and intercepts fixed at 0, indicator intercepts free (they are observed intercepts). A user-written latent `~1` that is free or fixed nonzero still errors, naming the variable and "planned for a later release"; `M ~ 0*1` equals the default and is accepted.
4. **Exogenous means.** The engine frees them (lavaan's default `fixed.x = TRUE` fixes them at the sample mean); oracles pass `fixed.x = FALSE` (M6).

## Tasks

### T1: Flag and fixture freeze (S) (M2)
- [ ] Add `has_mean` to the RAM spec and sample list, default `FALSE`; no behavior change.
- [ ] **Create the frozen values; they do not exist yet.** `tests/testthat/fixtures/` holds only `memory_exp.rds` and `lavaan-simple-before-aliases.rds`; the pinned estimates in `test-sem-parity.R:128-145` are at 1e-6, and OpenMx is a live oracle that skips when absent. Generate from the **v0.8.0 tag** (not after the `has_mean` edit) and store: F, gradient and expected information at a stored theta to **1e-12**; observed-information SEs to about **1e-9**; fitted estimates to **1e-6** (a 2-ulp change in theta moves observed-information SEs by 1.8e-11, reversing row order moves theta by 1.1e-7, and `test-sem-ipw.R:70-71` already records about 1e-8 drift on the CI matrix). Include a **weighted sandwich case and a constrained case**, so the gate actually exercises `.sem_scores`/`.sem_sample` and the constraint path.
- [ ] Test: with `has_mean = FALSE` every frozen value is reproduced (G3 gate), written first and **red against a deliberately perturbed `.sem_eval`**.
- Files: `R/sem-ml.R`, `tests/testthat/test-sem-*.R`, `helper-sem.R`, new fixtures.

### T2: Parser, table, and the flag everywhere (S) (H1, M7, M8, L)
- [ ] `.sem_to_ram()` and `.sem_complete()`: implement semantics 1-3 above. Free and fixed observed `~1` rows are kept; saturation of unwritten observed intercepts when the flag is on; latent `~1` rule; `meanstructure = FALSE` with a free `~1` errors naming the term.
- [ ] **Thread the flag through every re-fit (M7).** Store `meanstructure` in `SEMFit@internals`; `mbco_sem()` re-parses `fit@model` (`R/sem-mbco.R:155`), `.sem_fit_branches` recurses (`R/sem-fit.R:121`) and `fit_mediation`'s `fit_args` (`R/fit-sem.R:142`) lacks it: all must pass it, and `fit_mediation(engine = "native")` gains `meanstructure =`. Read it with `isTRUE()` so SEMFit objects saved before 0.9.0 (no flag) still work.
- [ ] Coefficient names `y~1` (summary rows render `"y ~1 "` with a trailing space at `R/methods-sem.R:126`; fix). Intercepts take labels and constraints like any parameter. (0.10.0 rule 9 will forbid fixed, shared, or constrained `~1` rows in product models; do not make the table shape depend on it.)
- [ ] **Shared label between an intercept and a path (L): refused in 0.9.0** (decision below): `gmap` has only A and S columns (`R/sem-ml.R:87-89`), and the step floor's "first entry wins" rule would mix units (sd ratio against sd); error names both rows. Labels shared among intercepts are allowed.
- [ ] Update `R/fit-sem.R:21` roxygen.
- Tests: error messages by name; **`y ~ 0*1` is a restriction (df 1, chi-square and logLik equal lavaan's on the review's model)**; `y ~ 1` alone frees the other observed intercepts (npar and logLik equal lavaan's); `meanstructure = TRUE` plus a user-fixed `y ~ 0*1` keeps the fixed 0; flag survives `mbco_sem()` and `.sem_fit_branches`; old SEMFit without the flag loads; shared intercept/path label errors; latent `M ~ 1` errors, `M ~ 0*1` accepted.

### T3: Likelihood core and counts (M) — Checkpoint A (H2, M1, M5)
- [ ] `m` vector in RAM; `mu = F (I - A)^-1 m`; `.sem_sample()` keeps raw data and (weighted) `xbar`; scores use uncentered data.
- [ ] `F` adds `(xbar - mu)' Sigma^-1 (xbar - mu)`; gradient uses `W = Sigma^-1 - Sigma^-1 (S + d d') Sigma^-1` plus the `dmu` block (`dmu/dm_j = F B e_j`, `dmu/dA_ij = F B E_ij B m`). **Reviewer verified these formulas to 1.4e-9 against central differences on a latent RAM.**
- [ ] Expected and observed information gain the additive mean term (G1); the mean term carries a factor `n`, the covariance term `n/2`.
- [ ] **`.sem_df()` moves here from T5** (M5): moments `p(p+1)/2 + p` with mean structure on. Checkpoint A's df and chi-square equality needs it.
- [ ] **Scale handling for intercepts (H2), decided here, recorded in the GRILL.** The acceptance gate's Jacobi-scaled eigenvalue falls with predictor mean/sd (0.29 at 0, 4.4e-3 at 10, 1.7e-4 at 50, 4.3e-5 at 100), against `.sem_singular_tol` = 1e-4 (`R/sem-optim.R:16`, `:182`), so every start is rejected beyond mean/sd of about 70 (a calendar-year predictor). Also `.sem_default_start` (`R/sem-optim.R:314-321`) leaves intercepts at 0 and `.sem_step_floor` defaults to 1 for parameters outside `pos_a`/`pos_s` (`R/sem-ml.R:284`), which feeds the preconditioning, the bound window, perturbed starts, the Hessian step and the constraint scaling. Candidates: floor for an intercept = the variable's sd (the mean observed sd for a latent variable); starts at the sample means (`m = (I - A0) xbar`); judge the gate in a centered parameterization, or recalibrate the threshold with location-shifted S6 cells. **Gate: a sweep of predictor mean/sd from 0 to 1000 must be accepted for a well-identified model while a genuinely unidentified model is still rejected.**
- Tests and gates (rewritten, M1):
  - Information is compared to a **finite-difference Hessian of F only at exact-fit moments (S = Sigma, xbar = mu)**, where expected information equals n/2 times the Hessian (7.2e-10 in the review); observed information vs a finite difference is tautological and is not used as a gate.
  - **Intercept SEs against an oracle at T3** (lavaan with `meanstructure = TRUE, fixed.x = FALSE, information = "observed"`), not only at T8: dropping `dmu/dA` from the mean term leaves path and variance SEs identical to the covariance-only fit and is wrong only on intercept SEs (about -52%), so the saturated regression gate cannot see it.
  - Saturated free intercepts reproduce the covariance-only estimates, SEs, df, and chi-square to 1e-6.
  - Planted defects: gradient without `dmu`; information without the mean term; **information with `dmu/dA` dropped** (fails the intercept-SE oracle); each named.
- **Checkpoint A:** frozen-value gate (T1), regression gate, intercept-SE oracle, and the mean/sd sweep pass. Go/no-go on T4-T8.

### T4: Scores, weights, sandwich (M) (M1, M6)
- [ ] `.sem_scores()` adds `w_i * (dmu_k)' Sigma^-1 (x_i - mu(theta))`; the centering at the sample mean is removed for the mean-structure path. Weighted `xbar` and `S` follow the existing convention (weights rescaled to sum to n, divisor n; reviewer confirmed).
- [ ] Update the `R/sem-sandwich.R` header comment (the block-diagonal sentence is no longer true).
- Tests (rewritten): "scores sum to the gradient" is **vacuous at a saturated optimum** (both sums about 4e-5, SE difference 4.3e-8 when scores are centered at the sample mean). Use **a restricted-intercept model and an off-optimum theta**, where the defect shows (sum error 151.6 off the optimum; SE difference 0.88% with a restricted intercept). Sandwich SEs vs lavaan with `sampling.weights`: **pass `meanstructure = TRUE, fixed.x = FALSE` explicitly** (lavaan reports `meanstructure` FALSE under `sampling.weights` unless asked; default `fixed.x = TRUE` gives logLik -846.33 vs -1269.52 and a fixed `x~1`).

### T5: logLik, anova, counts-dependent methods (S) (M3, L)
- [ ] **logLik double count (M3).** `R/methods-sem.R:116` has `df = .sem_n_free(object) + smp$p`; once the means are in theta, `n_free` already counts them, so AIC is off by 2p and BIC by p log n, and a saturated-mean fit would differ from the covariance-only fit. Add `p` only when the flag is off. The logLik value needs no change (F already contains the mean term).
- [ ] **`anova()` across mean-structure status: allowed, not refused (decision below).** A covariance-only fit already is the saturated-mean fit (F, logLik and lavaan's logLik are identical), so `y ~ 0*1` against the covariance-only fit is a valid nested test with df 1 that a refusal would block. The df count comes from T3's unified rule.
- Tests: df and AIC/BIC cases (saturated, one fixed intercept, one equality) including AIC equal for the saturated-mean and covariance-only fits; `anova()` of covariance-only vs `y ~ 0*1` gives df 1 and the lavaan chi-square difference; no-`~1` fits keep the 0.8.0 logLik.

### T6: Constraints and MBCO (M) — with T8a, Checkpoint B (M7)
- [ ] Intercept rows work in linear and nonlinear `==`, `<`, `>`, `:=` and in the redundancy rule (`.sem_independent_rows()`); check natural-unit scaling `x = theta/u` with the T3 intercept floor.
- [ ] `mbco_sem()` clean-start null refits carry intercepts **and the flag**: with `meanstructure = TRUE` and `y ~ 0*1` the refit must keep the restriction, otherwise `diff_ll` is understated or negative.
- [ ] Intercept variants of `tests/sim/sem-nonlinear-gate.R` (with `MUTANT=` switches), including one that drops the flag on refit.
- **Checkpoint B:** nonlinear gate and **T8a lavaan parity on simple, serial, parallel, and latent-mediator models** pass, then author go/no-go on T7-T9.

### T7: Methods and extraction (S) (M4)
- [ ] `coef`, `vcov`, `tidy`, `glance`, `confint` include intercept rows; `SEMFit` carries the flag.
- [ ] `extract_mediation(<SEMFit>)` returns the same effects as the covariance-only fit; intercept rows never enter `.path_se()` or two-way effect SEs. **Exception (0.10.0 plan F7):** the four-way INTref gradient needs `b0` (`R/effect-se.R:268`, guarded by `if ("b0" %in% rownames(vc))`), so the `m~1` row and its covariances with the path rows stay in `vcov`.
- [ ] **Refuse four-way on a SEMFit in 0.9.0, by name (M4).** A 0.9.0 native fit with `m ~ 1` and a data product column, called with `interaction =` and the default `decomposition = "auto"`, would reach `.extract_interaction_mediation_lavaan` (`R/extract-lavaan.R:1087-1091`), a four-way decomposition scoped to 0.10.0 through the worker with the known bugs; the translated error at `R/extract-sem.R:91-97` would be unreachable for such fits. Error text names engine and release.
- Tests: extraction equality (paths, NIE, SEs) with and without a saturated mean structure; four-way refusal on a mean-structure fit with `interaction =`; `b0` and its covariances are present in `vcov`.

### T8a: lavaan parity (M) — before Checkpoint B (M6, M8)
- [ ] lavaan `meanstructure = TRUE, fixed.x = FALSE`: estimates, SEs, logLik to 1e-4 on **four** forms (simple, serial, parallel, latent mediator in the G7 case-A form); sandwich with `sampling.weights` (explicit `meanstructure = TRUE`).
- [ ] Oracle for intercept SEs and the `y ~ 0*1` restriction (df 1) is lavaan itself, never medfit's own extraction.

### T8b: Independent oracle and worked example (S)
- [ ] OpenMx independent optimum on a constrained-intercept model (`skip_if_not_installed("OpenMx")`).
- [ ] One worked example where an intercept constraint changes a result (G4 honesty requirement); doubles as a docs test.

### T9: Docs and close-out (S) — Checkpoint C (L)
- [ ] NEWS under the existing heading `# medfit (development version)` (not `[Unreleased]`): behavior change (the "not supported" error becomes a feature; **`anova()` across mean-structure status allowed**), the honest benefit statement (saturated-mean fits give identical paths, effects, SEs), and the lavaan-route four-way corrections from the worker fix listed **first** (0.10.0 GRILL H7).
- [ ] Text that says native cannot estimate intercepts: `vignettes/articles/extraction.qmd:796-798`, `model-lavaan.qmd:103`, `model-native.qmd:105`, `native-guide.qmd:181`, `model-native-multi.qmd`, `guide-troubleshooting.qmd`; the error at `R/extract-sem.R:91-96`; header comments at `R/sem-model.R:10`, `R/sem-model.R:134` and the `R/sem-ml.R` header; the moment count in the df error at `R/sem-fit.R:63-64` (`p(p+1)/2`).
- [ ] `?"medfit-syntax"`, `man/fit_sem.Rd`, the lavaan comparison table row (verified live), `methods.qmd` (discrepancy with the mean term), **CLAUDE.md Engines row and file-organization/testing sections**, `.STATUS`.
- [ ] Doc currency check across all tutorial/reference files; `test-refcard-coverage.R`, cookbook, and link tests green.
- [ ] Full suite with counts, `R CMD check --as-cran`, strict-flavor check, `urlchecker`, `spelling`; before any submission `cran-comments.md` resynced (CRAN stays on hold); US English.
- **Checkpoint C:** release decision (version bump to 0.9.0 by release engineering).

## Risks

| Risk | Where it is caught |
|---|---|
| Silent change to existing fits | T1 frozen-value gate (tiered tolerances, from the v0.8.0 tag), rerun after every edit to `.sem_eval`/`.sem_scores`/`.sem_sample` |
| Unwritten intercepts left at 0, or a fixed `~1` dropped | T2 tests against lavaan (npar, df 1, logLik) |
| Information or scores missing the mean term | T3 intercept-SE oracle, T4 restricted-mean off-optimum defects |
| Acceptance gate rejects realistic models with distant means | T3 mean/sd sweep gate |
| `meanstructure` lost on a re-fit (`mbco_sem`, branches, `fit_mediation`) | T2, T6 tests |
| logLik/AIC double count | T5 |
| Four-way reached through a buggy worker in 0.9.0 | T7 refusal |
| SLSQP behavior with intercepts under nonlinear constraints | T6 gate variants |
| Overselling the release | T9 NEWS wording and T8b example |

## Decisions for the author (new; recommended answers apply unless you object)

1. **`anova()` across mean-structure status: allow (recommended), reversing SPEC behavior 5 and G-ledger wording.** Evidence from the review: F and logLik already treat a covariance-only fit as a saturated-mean fit, lavaan's logLik is identical for the two, and the refusal blocks valid tests such as `y ~ 0*1` against the covariance-only fit.
2. **Any `~1` row (free or fixed) turns mean structure on and frees the unwritten observed intercepts (recommended), refining SPEC behavior 2** (which said only that it turns on). Needed for lavaan parity.
3. **Shared label between an intercept and a path: refuse in 0.9.0 (recommended).** lavaan accepts it (df 1); the engine's `gmap` and step-floor units do not support mixing yet, and it can be relaxed later.
4. **H2 scale handling:** pick the candidate (sd floor + sample-mean starts, centered gate, or recalibrated threshold) at T3 and record it; the sweep gate decides, not preference.

## Not in this plan

Explicit latent means (0.11.0, G7 identification rules), the `:` operator and four-way (0.10.0), relaxing the shared-label refusal.
