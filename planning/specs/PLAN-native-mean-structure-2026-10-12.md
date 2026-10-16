# PLAN: Native mean structure, 0.9.0 (observed intercepts)

**Date:** 2026-10-12 (revised the same day after an Opus adversarial review; its findings are numbered H1-H2, M1-M8, L below). **Revised 2026-10-13** after a second Opus review (H-A to H-C, M-A to M-D, low items) and a Codex review; decisions G8-G12 in the GRILL, amendments marked **(R2)** below | **Branch:** `feature/native-mean-structure` (not created; branching waits for your request)
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
5. **(R2) `meanstructure` is tri-state (G10).** `NULL` (default): on when any `~1` row is written; `TRUE`: on; `FALSE`: off, and a free `~1` errors naming the term. What `FALSE` does with a fixed `~0*1` is: it errors too (a fixed intercept is a mean-structure statement). `fit_sem()` gains the argument, as does `fit_mediation()`.
6. **(R2) A fixed `~0*1` changes meaning versus 0.8.0 (G10).** 0.8.0 drops it (df 0); 0.9.0 makes it a restriction (df 1). NEWS behavior-change entry; the T1 frozen gate cannot see this (it covers only models without `~1`), so add a frozen intended-change fixture.
7. **(R2) Prerequisite: the `anova()` nesting fix (G8)** is merged to `dev` before T5; it rewrites `.sem_anova_nested` once, and T5 only adds the implicit-mean normalization.

## Tasks

### T1: Flag and fixture freeze (S) (M2)
- [x] Add `has_mean` to the RAM spec and sample list, default `FALSE`; no behavior change.
- [x] **Create the frozen values; they do not exist yet.** `tests/testthat/fixtures/` holds only `memory_exp.rds` and `lavaan-simple-before-aliases.rds`; the pinned estimates in `test-sem-parity.R:128-145` are at 1e-6, and OpenMx is a live oracle that skips when absent. Generate from the **v0.8.0 tag** (not after the `has_mean` edit) and store: F, gradient and expected information at a stored theta to **1e-12**; observed-information SEs to about **1e-9**; fitted estimates to **1e-6** (a 2-ulp change in theta moves observed-information SEs by 1.8e-11, reversing row order moves theta by 1.1e-7, and `test-sem-ipw.R:70-71` already records about 1e-8 drift on the CI matrix). Include a **weighted sandwich case and a constrained case**, so the gate actually exercises `.sem_scores`/`.sem_sample` and the constraint path.
- [x] Test: with `has_mean = FALSE` every frozen value is reproduced (G3 gate), written first and **red against a deliberately perturbed `.sem_eval`**.
- [ ] **(R2) Tolerance and platform.** State whether 1e-12 is relative (expected-information entries scale with n); generate the fixture on macOS and confirm on the ubuntu CI BLAS before Checkpoint A. Generating from `dev` before T1 is equivalent to the v0.8.0 tag (`git diff v0.8.0..dev` is empty for `R/sem-*`).
- [ ] **(R2) Seed.** `.sem_seed()` must not add the `m` vector to its hash text when the flag is off (it would change perturbed starts); add a frozen case where a retry happens so the gate pins this.
- Files: `R/sem-ml.R`, `tests/testthat/test-sem-*.R`, `helper-sem.R`, new fixtures.

### T2: Parser, table, and the flag everywhere (S) (H1, M7, M8, L)
- [ ] `.sem_to_ram()` and `.sem_complete()`: implement semantics 1-3 above. Free and fixed observed `~1` rows are kept; saturation of unwritten observed intercepts when the flag is on; latent `~1` rule; `meanstructure = FALSE` with a free `~1` errors naming the term.
- [ ] **Thread the flag through every re-fit (M7).** Store `meanstructure` in `SEMFit@internals`; `mbco_sem()` re-parses `fit@model` (`R/sem-mbco.R:155`), `.sem_fit_branches` recurses (`R/sem-fit.R:121`) and `fit_mediation`'s `fit_args` (`R/fit-sem.R:142`) lacks it: all must pass it, and `fit_mediation(engine = "native")` gains `meanstructure =`. Read it with `isTRUE()` so SEMFit objects saved before 0.9.0 (no flag) still work.
- [ ] Coefficient names `y~1` (summary rows render `"y ~1 "` with a trailing space at `R/methods-sem.R:126`; fix). Intercepts take labels and constraints like any parameter. (0.10.0 rule 9 will forbid fixed, shared, or constrained `~1` rows in product models; do not make the table shape depend on it.)
- [ ] **(R2, G12) Shared label between an intercept and a path: allowed.** `gmap` gains mean columns; the step floor's "first entry wins" rule gets a test with a mixed-scale shared parameter (sd ratio against sd) instead of an error. Labels shared among intercepts are allowed as before.
- [ ] Update `R/fit-sem.R:21` roxygen.
- [ ] **(R2, G10) Tests and text that encode the old `~0*1` behavior:** `tests/testthat/test-sem-fit.R:108-111`, `test-sem-model.R:234-235`, `test-sem-parse.R:58` (a latent model with `m1 ~ 0*1`), and `R/sem-syntax-help.R:35` ("`y ~ 0*1` is accepted"). Update each in this task, with the NEWS behavior-change entry.
- [ ] **(R2, M-D) Plumbing and messages.** `fit_sem()` gets `meanstructure`; `.sem_fit_branches` calls `.sem_fit_syntax` with positional arguments (`R/sem-fit.R:121`), so pass the flag by name. Update the "mean structure is not supported" messages with the behavior change: `test-sem-fit.R:83`, `test-model-pages-messages.R:15`, `guide-troubleshooting.qmd:84`, and the df-error moment count (`R/sem-fit.R:63-64`, `p(p+1)/2`) here, not in T9. `print()`/`summary()` say whether mean structure is on.
- [ ] **(R2, G11) Parser: accept `y ~ 1 + x`** (lavaan's combined form), after the SPEC amendment is approved. Until then the lavaan-comparison probe at `test-lavaan-comparison.R:44` stays "Unsupported".
- [ ] **(R2, M-B) Numeric acceptance tests move to T3.** `y ~ 0*1` df 1 and the chi-square and logLik equal to lavaan's need T3's F and `.sem_df`; T2 keeps parse, table, flag and message tests only, so the suite is green at each checkpoint.
- Tests: error messages by name; **`y ~ 0*1` is a restriction (df 1, chi-square and logLik equal lavaan's on the review's model)**; `y ~ 1` alone frees the other observed intercepts (npar and logLik equal lavaan's); `meanstructure = TRUE` plus a user-fixed `y ~ 0*1` keeps the fixed 0; flag survives `mbco_sem()` and `.sem_fit_branches`; old SEMFit without the flag loads; shared intercept/path label errors; latent `M ~ 1` errors, `M ~ 0*1` accepted.

### T3: Likelihood core and counts (M) — Checkpoint A (H2, M1, M5)
- [ ] `m` vector in RAM; `mu = F (I - A)^-1 m`; `.sem_sample()` keeps raw data and (weighted) `xbar`; scores use uncentered data.
- [ ] `F` adds `(xbar - mu)' Sigma^-1 (xbar - mu)`; gradient uses `W = Sigma^-1 - Sigma^-1 (S + d d') Sigma^-1` plus the `dmu` block (`dmu/dm_j = F B e_j`, `dmu/dA_ij = F B E_ij B m`). **Reviewer verified these formulas to 1.4e-9 against central differences on a latent RAM.**
- [ ] Expected and observed information gain the additive mean term (G1); the mean term carries a factor `n`, the covariance term `n/2`.
- [ ] **`.sem_df()` moves here from T5** (M5): moments `p(p+1)/2 + p` with mean structure on. Checkpoint A's df and chi-square equality needs it.
- [ ] **(R2, G9) Scale handling for intercepts (H2), decided: centered gate plus scaled starts.** Run the information, its inversion (`.sem_invert_info`, which fails near mean/sd 4500) and the identification check in implied-mean coordinates phi = (paths, variances, mu), mapping back with `V = J V_phi J'`; apply the same centering in `.sem_gate_projected` and `.sem_active_set`; define phi for fixed or constrained intercepts (the map covers only the free `m`). Sd floor and sample-mean starts (latents: `m_free = xbar_v - (A0 mu0)_v`, mu0 = 0) handle scale, not the gate: measured, they leave the Jacobi-scaled eigenvalue unchanged. Recalibrating `.sem_singular_tol` is ruled out (would need < 4.5e-7; S6's degenerate points sit at 1.7e-5).
- Tests and gates (rewritten, M1):
  - Information is compared to a **finite-difference Hessian of F only at exact-fit moments (S = Sigma, xbar = mu)**, where expected information equals n/2 times the Hessian (7.2e-10 in the review); observed information vs a finite difference is tautological and is not used as a gate.
  - **Intercept SEs against an oracle at T3** (lavaan with `meanstructure = TRUE, fixed.x = FALSE, information = "observed"`), not only at T8: dropping `dmu/dA` from the mean term leaves path and variance SEs identical to the covariance-only fit and is wrong only on intercept SEs (about -52%), so the saturated regression gate cannot see it.
  - Saturated free intercepts reproduce the covariance-only estimates, SEs, df, and chi-square to 1e-6.
  - **(R2, M-C) Always-on oracle.** For observed recursive models the ML intercept SE equals the OLS SE times sqrt((n-k)/n) (matched to 1e-11 across mean/sd 0 to 1000); make it the T3 gate so it runs in the noSuggests job. Keep lavaan for the latent form and T8a.
  - **(R2) Sweep** extends to mean/sd 1e5 and asserts vcov non-NA and equal to the OLS values, not only that the fit is accepted; the gradient finite-difference test runs at `d = xbar - mu != 0` (at a saturated optimum a gradient missing `dmu/dA` is invisible).
  - **(R2) Numeric T2 acceptance tests** (moved here): `y ~ 0*1` df 1, chi-square and logLik equal to lavaan's on the review's model.
  - Planted defects: gradient without `dmu`; information without the mean term; **information with `dmu/dA` dropped** (fails the intercept-SE oracle); each named.
- **Checkpoint A:** frozen-value gate (T1), regression gate, intercept-SE oracle, and the mean/sd sweep pass. Go/no-go on T4-T8.

### T4: Scores, weights, sandwich (M) (M1, M6)
- [ ] `.sem_scores()` adds `w_i * (dmu_k)' Sigma^-1 (x_i - mu(theta))`; the centering at the sample mean is removed for the mean-structure path. Weighted `xbar` and `S` follow the existing convention (weights rescaled to sum to n, divisor n; reviewer confirmed).
- [ ] Update the `R/sem-sandwich.R` header comment (the block-diagonal sentence is no longer true).
- [ ] **(R2, M-C) Dependency-free check:** the saturated weighted sandwich equals the covariance-only sandwich (the sandwich transforms with the reparameterization); lavaan `sampling.weights` stays as the second oracle.
- Tests (rewritten): "scores sum to the gradient" is **vacuous at a saturated optimum** (both sums about 4e-5, SE difference 4.3e-8 when scores are centered at the sample mean). Use **a restricted-intercept model and an off-optimum theta**, where the defect shows (sum error 151.6 off the optimum; SE difference 0.88% with a restricted intercept). Sandwich SEs vs lavaan with `sampling.weights`: **pass `meanstructure = TRUE, fixed.x = FALSE` explicitly** (lavaan reports `meanstructure` FALSE under `sampling.weights` unless asked; default `fixed.x = TRUE` gives logLik -846.33 vs -1269.52 and a fixed `x~1`).

### T5: logLik, anova, counts-dependent methods (S) (M3, L)
- [ ] **logLik double count (M3).** `R/methods-sem.R:116` has `df = .sem_n_free(object) + smp$p`; once the means are in theta, `n_free` already counts them, so AIC is off by 2p and BIC by p log n, and a saturated-mean fit would differ from the covariance-only fit. Add `p` only when the flag is off. The logLik value needs no change (F already contains the mean term).
- [ ] **(R2, H-B, Codex) `anova()` across mean-structure status: allowed, with normalization.** A covariance-only fit already is the saturated-mean fit (F, logLik and lavaan's logLik are identical), so `y ~ 0*1` against it is a valid nested test with df 1. But `.sem_anova_nested` compares free `lhs op rhs` rows, and `y ~ 0*1` frees `x ~1` and `m ~1` that the covariance-only table lacks, so the planned call stops with "not nested". Add: a fit with the flag off gets implicit free `v ~1` keys for every observed variable before the nesting check (building on the G8 fix). Test both argument orders, free, fixed and constrained intercept comparisons, and that a mean-structure fit against a covariance-only fit with equal df still gives the "same df" error.
- Tests: df and AIC/BIC cases (saturated, one fixed intercept, one equality) including AIC equal for the saturated-mean and covariance-only fits; `anova()` of covariance-only vs `y ~ 0*1` gives df 1 and the lavaan chi-square difference; no-`~1` fits keep the 0.8.0 logLik.
- **(R2, M-D)** `glance()`'s `npar` differs between a saturated-mean fit (q + p) and a covariance-only fit (q) while their AIC is equal; document it.

### T6: Constraints and MBCO (M) — with T8a, Checkpoint B (M7)
- [ ] Intercept rows work in linear and nonlinear `==`, `<`, `>`, `:=` and in the redundancy rule (`.sem_independent_rows()`); check natural-unit scaling `x = theta/u` with the T3 intercept floor.
- [ ] `mbco_sem()` clean-start null refits carry intercepts **and the flag**: with `meanstructure = TRUE` and `y ~ 0*1` the refit must keep the restriction, otherwise `diff_ll` is understated or negative.
- [ ] Intercept variants of `tests/sim/sem-nonlinear-gate.R` (with `MUTANT=` switches), including one that drops the flag on refit.
- **Checkpoint B:** nonlinear gate and **T8a lavaan parity on simple, serial, parallel, and latent-mediator models** pass, then author go/no-go on T7-T9.

### T7: Methods and extraction (S) (M4)

- [ ] `coef`, `vcov`, `tidy`, `glance`, `confint` include intercept rows; `SEMFit` carries the flag.
- [ ] `extract_mediation(<SEMFit>)` returns the same effects as the covariance-only fit; intercept rows never enter `.path_se()` or two-way effect SEs. **Exception (0.10.0 plan F7):** the four-way INTref gradient needs `b0` (`R/effect-se.R:268`, guarded by `if ("b0" %in% rownames(vc))`), so the `m~1` row and its covariances with the path rows stay in `vcov`.
- [ ] **Refuse four-way on a SEMFit in 0.9.0, by name (M4).** A 0.9.0 native fit with `m ~ 1` and a data product column, called with `interaction =` and the default `decomposition = "auto"`, would reach `.extract_interaction_mediation_lavaan` (`R/extract-lavaan.R:1087-1091`), a four-way decomposition scoped to 0.10.0 through the worker with the known bugs; the translated error at `R/extract-sem.R:91-97` would be unreachable for such fits. Error text names engine and release.
- [ ] **(R2, M-D)** The refusal also covers an explicit `decomposition = "four_way"`, not only `"auto"`.
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
- [ ] **(R2, M-A, G11)** Lavaan-comparison probe `fit_sem("outcome ~ 1 + treatment", d)` (`test-lavaan-comparison.R:44`) flips to Supported once `y ~ 1 + x` is accepted; if the amendment slips, rewrite the probe as two statements and state the syntax gap in the row.
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
3. **(R2, G12) Shared label between an intercept and a path: allowed** (reverses the earlier refusal; the engine's `gmap` gains mean columns and the step floor gets a mixed-scale test).
4. **(R2, G9) H2 scale handling: decided**, not left to the T3 sweep: centered gate plus sd-floor and sample-mean starts; the sweep (to mean/sd 1e5) verifies it.
5. **(R2, G10) Fixed `~0*1` is a restriction**, announced as a correctness change (see Semantics 5-6).
6. **(R2, G11) `y ~ 1 + x` is accepted**, which needs a grammar amendment approved before T2's parser work.
7. **(R2, G8) The `anova()` nesting fix lands first** as its own PR (`fix/anova-nesting`).

## Not in this plan

Explicit latent means (0.11.0, G7 identification rules), the `:` operator and four-way (0.10.0).
