# PLAN: Four-way decomposition via the native engine, 0.10.0

**Date:** 2026-10-12 (revised same day after an Opus adversarial review; the review's findings are numbered F1-F11 below) | **Branch:** `feature/native-four-way` (not created; branching waits for your request)
**Status (2026-10-13):** U0 merged (#168 `f4bc0e1`, follow-up #169 `bdeab4b`). The 0.9.0 gates are met: observed mean structure merged as #174 (`8681083`) and `fixed_x` as #175 (`1023520`), both on `dev`, unreleased (DESCRIPTION still 0.8.0). U1-U10 not started; branching waits for the 0.9.0 release decision and your request. Line anchors below were re-pinned against `dev` `8bd9260`; see "Delta since 0.9.0 and `fixed_x`" for what the two merges changed.
**Inputs:** [SPEC amendment (approved)](SPEC-sem-grammar-amendment-product-2026-10-12.md), [GRILL](GRILL-native-mean-structure-2026-10-12.md) G4-G6, [SPEC-interaction-fourway-2026-06-03.md](SPEC-interaction-fourway-2026-06-03.md) (decomposition contract), [PLAN 0.9.0](PLAN-native-mean-structure-2026-10-12.md)
**Depends on:** 0.9.0 tasks T3 (likelihood and counts), T5 (logLik/anova), T7 (methods/extraction and the four-way refusal) merged, **and U0 below merged** (all met, see Status). **U1 and later start only after 0.9.0 T2 merges** (met: #174) (shared files `R/sem-model.R`, `R/fit-sem.R`; [GRILL H8](GRILL-native-four-way-2026-10-12.md)). Only U0 runs in parallel. Grill decisions H1-H8 are applied below.
**Out of scope:** latent means and latent products (0.11.0), three-way products.

Sizes: XS/S/M, no hour estimates (0.7.0 grill D7). Checkpoints: **A** after U4, **B** after U8, **C** before release.

## What the code does (corrected by the review)

- `extract_mediation(<SEMFit>)` (`R/extract-sem.R:97`) calls the shared lavaan worker `.extract_interaction_mediation_lavaan()` (`R/extract-lavaan.R:1089`). The algebra is shared; **the worker's live defects (F1, F3, F5) were fixed by U0** (#168, #169). The earlier claim "no new decomposition math" was wrong: fixing the worker was a prerequisite, and it is now done.
- Native blockers: the mediator-intercept (`m~1`) row exists since 0.9.0, **but mean structure is auto-on only when a `~1` appears** (F2), so a plain `m ~ x; y ~ m + x + x:m` has no intercept and would hit the worker's lavaan-only advice ("refit the lavaan model with meanstructure = TRUE", `R/extract-lavaan.R:1155-1157`) if the native refusal at `R/extract-sem.R:99-105` were simply deleted. That refusal now fires for `decomposition = "four_way"` or any `interaction =` argument, with or without a mean structure.
- Product lookup is not literal: `.find_interaction_term_lavaan` (`R/extract-lavaan.R:978`, candidates at `:991-992`) already tries `interaction`, `x:m`, and `m:x` (F11). The helper work is smaller than first stated, but names written to the table are still canonical.

## Dependency order

U0 (separate, from `dev`) -> [0.9.0 T3/T5/T7] -> U1 -> U2 -> U3 -> U4 (A) -> U5 -> U6 -> U7 -> U8 (B) -> U9 -> U10 (C)

## Tasks

### U0: Fix the live four-way worker defects, on their own branch (M) — prerequisite, not part of 0.10.0
**DONE: merged to `dev` as #168 (`f4bc0e1`) and #169 (`bdeab4b`); the correction ships in the 0.9.0 NEWS (GRILL H7).** Boxes below are ticked from the merge; the text is kept as the record of what was fixed. Lavaan route only; no native code. Tests: `tests/testthat/test-four-way-lavaan-worker.R`.
- [x] **F1, SEs drop the mediator-covariate term.** The filter at `R/effect-se.R:252` keeps `m_<cov>` only when it is in `rownames(vc)`; the worker now adds those alias rows (`R/extract-lavaan.R:1208-1221`), so INTref, NDE and TE keep the `g * cbar` term and `cov(g, b0)`. Reviewer's evidence (before the fix): `m ~ x + c1; y ~ x + m + xm + c1`, n = 2000: medfit INTref SE 0.0366, lavaan's own `:=` 0.095. Follow-up still open: use the estimated exogenous means with their covariance now that 0.9.0 exists (see the delta section).
- [x] **F3, treatment product in the mediator equation is silently wrong.** `m ~ x + w + x:w; y ~ x + m + x:m` returned `a` = 0.500 against a true averaged 1.690. `.stop_on_four_way_products()` (`R/extract-lavaan.R:1016`, called at `:1165`) now rejects a treatment product in the mediator equation and a treatment-by-covariate product in the outcome equation, by name or by equality with a data column, naming the feature; the contrast is documented as 0 to 1 whatever the treatment coding.
- [x] **F5, weighted INTref differs between routes.** The worker used unweighted covariate means, the glm route weighted design means (`R/extract-lm.R:737-741`): INTref 1.1638 vs 1.4556 on the same data and weights. The worker now uses weighted means (`R/extract-lavaan.R:1188`).
- Oracle rule (all three): the reference is **lavaan's own `:=` defined parameters or a hand-written delta method, and OLS `sandwich::vcovHC(, "HC0")`**, never medfit's extraction of a lavaan fit (which shares the code under test). **Every oracle model includes a covariate in the mediator equation.**
- Tests red first: INTref/NDE/TE SEs vs `:=` with a mediator covariate (planted defect: restore the filter); the F3 model errors; weighted parity with glm; a model with no covariate still matches.
- Reviewer scripts for reproduction: scratchpad `fw_cov.R`, `modA.R`, `fw_w.R` (move into `planning/specs/evidence/native-four-way-2026-10-12/` when this task starts).

### U1: `.sem_product_name()` and the product token (S)
- [ ] `.sem_product_name(a, b)`: C-locale sort, `paste0(first, ":", second)`; one helper for parser, materializer, extractor, `tidy()` lookups (amendment rule 7).
- [ ] Tokenizer: `:` after `:=` and `level:`; spaced `x :m` rejected; `a:=b` and `level:1` unchanged. Grammar `term := [modifier "*"] operand`, `operand := name | product`, right side only.
- Tests: identity table; `x:x`, `x:m:w`, product inside an `expr`, product as `lhs`, `eta:x` with `eta =~`: each errors naming the feature; spacing; `a:=b`, `level:1` unaffected.
- Files: `R/sem-parse.R`, `R/sem-model.R`.

### U2: Table rows, duplicates, canonical form (S)
- [ ] Table `rhs` holds the canonical product; duplicate within one equation errors naming both spellings and the canonical name; same product across equations allowed; parameter names `y~m:x` (or the label).
- Tests: `y ~ x:m + m:x`, `y ~ a*x:m + b*m:x` error; `y ~ x:m` and `z ~ m:x` share one column; the table is identical with and without data.

### U3: Materialization (M) (F8)
- [ ] **Placement:** listwise deletion happens inside `.sem_fit_syntax` (`R/sem-fit.R:48-57`), after the absent-column check at `:39-42`; the sample is formed at `:59`. Build each distinct product column there; `fit_sem()` and `fit_mediation(engine = "native", model =)` both go through it. **Since `fixed_x` (#175) the build must come before `.sem_assign_fixed_x(tab, data, weights)` at `R/sem-fit.R:34`** (see the delta section): that helper reads the model's observed columns from `data` and returns early when one is absent, so a product column built only after `:39` would leave every `fixed_x` row of that fit unassigned, not just the product's. Building early is NA-safe (NA propagates through `*`, and the helper does its own `complete.cases`); only the pre-existing-column equality check stays after deletion. Files: `R/sem-fit.R` (omitted from the first draft), `R/fit-sem.R`.
- [ ] Pre-existing `m:x` or `x:m` column: used only if it equals `x*m` exactly (NA-safe comparison: compare after deletion), otherwise an error naming the column and both options.
- **Planted defects that can fail** (the two in the first draft could not: `NA` propagates through `*` so building before or after deletion gives the same rows, and `x*m` equals `m*x` exactly in IEEE 754): (a) run the pre-existing-column equality check **before** deletion on data containing NAs, which breaks (NA in the comparison); (b) name the column in the **wrong order** (`x:m` instead of the canonical `m:x`) and require the table, `coef()` names and the extractor lookup to fail.
- Tests: explicit user-built column equals the materialized fit; mismatched column errors; both planted defects fail. **Plus a `fixed_x = TRUE` case with a `:` term** (the product's fixed row gets its sample moment, and every other fixed row keeps its value), with a planted defect that builds the column after `R/sem-fit.R:39`: it must fail that test.

### U4: Model-validity rules 8 and 9 (M) — Checkpoint A (F6, F7)
- [ ] Rule 8 as in the amendment: directed graph from the whole parsed table (plain regressors, each product factor to the target, latent to indicators); reject a product whose factor is the target or a descendant; no data attached.
- [ ] **Rule 9 runs on the completed table, not only the parsed table (F6).** `.sem_complete` (`R/sem-model.R:33`) adds residual covariances for pure outcomes (`pairs(c(r$pure_lv_y, r$pure_ov_y))`, `R/sem-model.R:91`): in `m ~ x; y ~ m + x + xm; z ~ w` it adds `y ~~ z` (user = 0), which the parsed-table check cannot see, and with correlated outcome errors SEM differs from OLS by up to 3.1e-3. **Decided (GRILL H6):** in a model with a product, completion fixes auto-added pure-outcome residual covariances at 0 (the supported class has no residual covariances) and prints one note saying so; the no-product twin keeps the free covariance. A user who needs the covariance cannot have it with a product in 0.10.0.
- [ ] **Rule 9 gains an intercept clause (F7).** 0.9.0 T2 (#174) lets intercepts be fixed, labeled (including shared with a path) and constrained; any of those on a `~1` row changes the slopes and `b0` away from OLS yet passes the current rule 9. In a product model, `~1` rows must be free, unlabeled-or-uniquely-labeled, and absent from `==`/`<`/`>` constraints.
- Tests: the amendment's rule 8 and 9 rows plus `y ~ x:z; z ~ w:y`, the longer chain, the `y ~~ z` completion case, a fixed intercept, a shared intercept/path label, an intercept in a constraint; each accepted again once the product is removed; planted defects (no descendant search; no residual-covariance check on the completed table; no intercept clause).
- **Checkpoint A:** identity, materialization, and rejection tests green; existing native suite unchanged. **Demand check (GRILL H4):** is there a concrete consumer of native four-way (a probmed or RMediation request, the author's own use, an issue)? If not, U5-U10 stop; the parser and rules stay usable for other products. Decide what counts as a consumer before reaching the checkpoint. Go/no-go on U5-U8.

### U5: Mean structure on for four-way (S) (F2) — new
- [ ] **Decided (GRILL H5): any product term turns saturated mean structure on, in both `fit_sem()` and `fit_mediation()`.** `decomposition` is an extraction argument (`extract_args`, `R/fit-sem.R:166`), so a trigger keyed on it would fail the `fit_sem()` + `extract_mediation()` path; product models are new syntax, so no existing fit changes. The `meanstructure` half is already delivered: `fit_args` at `R/fit-sem.R:165` carries `meanstructure` (and `fixed_x`) since #174 and #175, so U5 only adds the product trigger. Document "product => meanstructure = TRUE" and test it in both call paths.
- [ ] Test the default call that has no `~1`: it yields a four-way decomposition (or the chosen error), never lavaan-only advice.

### U6: Model-test policy and information (M) (F4, F9, F10)
- [ ] Detect "product with an endogenous factor" and "restricted exogenous block" on the completed table (including covariances dropped by the pairing rule, `R/sem-model.R:92-100`; with `fixed_x` the pairing also has to be read together with the flagged rows, see the delta section); when either holds: warn once at fit; `anova()` and `mbco_sem()` refuse naming the product; `glance()`/`summary()` report chi-square, df, p-value and fit indices as `NA` with a note. Warn once when a product is present and `se_type != "sandwich"`.
- [ ] **Expected information (F4).** With an endogenous product factor, expected-information SEs are wrong, sandwich included (`y~xm` SE 0.0308 with expected, 0.0436 with observed = OLS; native sandwich 0.0320 vs HC0-exact 0.0446 with observed). The amendment's "sandwich SEs are safe" therefore holds **only with observed information**: refuse `information = "expected"` (or switch to observed with a message) when a product has an endogenous factor; document it.
- [ ] **Tolerance (F9).** The 2a gate "equal `lm()` to 1e-8" fails today (max |SEM - OLS| 3.5e-8 and 7.1e-8, covariance-only, n = 20000). Derive the tolerance from the optimizer's convergence criterion and state the derivation; start at 1e-6.
- [ ] **Gate mechanics (F10).** The population gate asserts chi-square far above the critical value while `glance()` reports it `NA`: read it from an internal accessor (`.sem_chisq()`), documented as test-only. The null gate (`exo-product-null.R`) uses a precomputed column `p`; add a variant through the `:` path.
- Tests: population gate; null gate (rejection in [0.03, 0.07], mean chi-square within 0.15 of df) both ways; restricted-block cases refused; expected-information refusal; planted defect: removing the endogenous-factor check lets `anova()` run.

### U7: Wire native four-way (S) (F11)
- [ ] `extract_mediation(<SEMFit>, interaction = )` resolves the product with `.sem_product_name(treatment, mediator)` (both argument orders; the worker already tries both orders).
- [ ] Replace the named refusal (`R/extract-sem.R:99-105`; it was an error-rewriting wrapper at `:90-96` before #174) with a **native-worded** error for the remaining no-intercept case (do not delete it blindly, F2).
- [ ] Requirement checks come from U0 (binary treatment, rejected product placements); they are not "kept" from the existing worker because the first draft's claim that they existed was wrong (F3).
- Tests: finds the product for `x:m` and `m:x`; a consumer hard-coding `y~x:m` fails (planted defect); **route comparison canonicalizes names first** (lavaan keeps the written `x:m`, native stores `m:x`, which changes estimate names, `outcome_predictors`, `source_package`).

### U8: Oracles (M) — Checkpoint B (F1, F4, F5, F11)
- [ ] **Reference is independent of the worker under test:** lavaan's own `:=` defined parameters for CDE, INTref, INTmed, PIE, TNIE, TNDE (with `meanstructure = TRUE`, `information = "observed"`), and OLS `sandwich::vcovHC(, "HC0")` per equation. A model compared against `extract_mediation(<lavaan fit>)` is **not** an oracle: both routes share the code.
- [ ] **Every oracle model includes a covariate in the mediator equation** (F1); add one without a covariate to keep the simple case.
- [ ] Weighted component parity with the glm route (INTref etc., not only sandwich SEs) (F5); sandwich SEs under weights.
- [ ] Known-answer simulation from `a, b, c', theta3` with binary X and `m_star`: components **and SEs** (empirical SD over replications), not point estimates only.
- [ ] regmedint / glm four-way comparison. **Tolerance is derived, not guessed (F11):** in the rule-9 class the SEs equal OLS apart from the `n` vs `n - k` scaling, so state the expected ratio and test to it.
- **Checkpoint B:** parity and known-answer gates pass; author go/no-go on U9-U10.

### U9: Cookbook, docs, lavaan comparison (S) (F11)
- [ ] NEWS (U0's correction is listed **first** in the 0.9.0 entry, GRILL H7; this task's entry is for 0.10.0): add under the existing `# medfit (development version)` heading (not `[Unreleased]`): product term, native four-way, the model-test limits, the 0.9.0 and U0 dependencies, the changed worker results from U0 (a behavior change on the lavaan route: SEs, weighted INTref, rejected models).
- [ ] `?"medfit-syntax"`, `man/fit_sem.Rd`, `model-native.qmd`, `native-guide.qmd`, a native four-way worked example (centering matters for the effect at `M = 0`), the lavaan comparison rows (a new row for `:`/four-way, and the existing `fixed_x` row, `vignettes/articles/lavaan-comparison.qmd:94`, to be re-read for the product case), `methods.qmd`, **CLAUDE.md file-organization and testing sections plus the Engines row**, `.STATUS`.
- [ ] One table of the supported class and each limit, so a rejection message is findable; doc currency check over tutorials and references; count and link tests.
- [ ] **Consumer check (F11):** `rforge:impact`/lightweight scratch-library check for probmed and RMediation (Suggests-only revdep per CLAUDE.md), because U0 changes lavaan-route four-way results.

### U10: Close-out (S) — Checkpoint C
- [ ] Full suite with counts; `R CMD check --as-cran`; strict-flavor check; `urlchecker`; `spelling`; CRAN stays on hold (resync `cran-comments.md` before any submission).
- [ ] Apply the amendment to the frozen grammar text in one labeled commit, or record that the amendment remains the authority.

## Delta since 0.9.0 and `fixed_x` (2026-10-13)

What #174 and #175 changed for this plan. Facts live in the linked SPEC and code; this lists only what the units must now account for.

- **Products are fixable (U3, U4, U6).** `fixed_x = TRUE` selects every exogenous observed variable from the completed model (`ram$ov_x`), product columns included, and names select any subset, a product column too ([SPEC-native-fixed-x S1](SPEC-native-fixed-x-2026-10-13.md); the product-by-name case is V3's test). So the `:` term inherits the rule only if the product column exists in `data` when the fixed values are assigned: see the U3 placement note (`R/sem-fit.R:34` against `:39`).
- **`.sem_complete` and the fit path changed (U4, U6).** `.sem_complete(parameters, meanstructure, fixed_x)` (`R/sem-model.R:33`) now flags fixed-x rows (`p$fixed_x`, separate from a user `fixed` restriction) and stores the resolved set as the table's `fixed_x` attribute; `.sem_fit_syntax` (`R/sem-fit.R:9`) assigns the values after completion. Rule 9's intercept clause must treat a `fixed_x`-flagged intercept or covariance row as allowed (it fixes a row at its sample moment, structural estimates are unchanged: SPEC S2) while still rejecting a user-fixed, labeled or constrained intercept; the completed-table check must also read the flag, not only `fixed`.
- **Comparisons refuse across fixed sets (U6, U8).** `logLik()`, `AIC()` and `BIC()` are conditional on the fixed block, and `anova()` and the multi-fit `AIC()`/`BIC()` error across different fixed sets or data via `.sem_check_comparable()` (`R/methods-aic.R:14`; called at `R/sem-anova.R:48` and `R/methods-aic.R:44`). U6's model-test refusals ("`anova()` and `mbco_sem()` refuse naming the product") should reuse that refusal path, and any oracle that compares a four-way native fit across product and no-product twins, or free against `fixed_x` fits, must hold the fixed set and data equal or compare structural parameters only (as the `fixed_x` tests do).
- **Open item beyond this plan.** The `mbco_sem()` refit does not pass `fixed_x` to `.sem_fit_syntax` (`R/sem-mbco.R:155-156`; it passes `meanstructure` only), and `test-sem-fixed-x-plumbing.R:14-25` cannot see this (its mock records `fit_sem()`'s own call first). The statistic is unchanged (the compare test, `test-sem-fixed-x-compare.R:16`), but U6's `mbco_sem()` work touches the same refit.
- **Docs (U9).** The doc list now includes `vignettes/articles/lavaan-comparison.qmd`'s `fixed_x` row (`:94`). `NEWS.md` under the development heading already carries the `fixed_x` and mean-structure entries; the 0.10.0 entry goes beside them.
- **Unchanged:** the product-term grammar, rules 8-9, the `:` canonical name, and the four-way algebra. The 0.9.0 and `fixed_x` work is unreleased, so "after 0.9.0" in this plan still means "merged to `dev`", not "tagged".

## Risks

| Risk | Where it is caught |
|---|---|
| Four-way SEs missing the covariate term (live today) | U0, U8 (oracle independent of the worker) |
| Treatment product in the mediator equation gives a silently wrong `a` | U0 guard, U7 inherits |
| Native default call has no mediator intercept | U5 |
| Rule 9 missed by completion-added covariances or constrained intercepts | U4 completed-table check, intercept clause |
| Expected-information SEs wrong under product misfit | U6 refusal, U8 pins observed |
| A gate that cannot fail (U3 defects, 1e-8 tolerance, hidden chi-square) | U3, U6 rewritten |
| A consumer hard-codes `x:m` | U7 planted defect |
| Moderated parallel mediation unavailable (rule 9) | documented limit; relax later against `product-correlated-residuals.R` |
| U0 changes lavaan-route results for existing users | U9 NEWS and consumer check |

## Decisions (closed by [GRILL-native-four-way-2026-10-12.md](GRILL-native-four-way-2026-10-12.md))

H1 U0 is its own PR (already started as `fix/four-way-worker`); H4 proceed with a demand check at Checkpoint A; H5 any product term turns mean structure on; H6 completion fixes pure-outcome residual covariances at 0 in product models with one note; H7 U0 ships in the 0.9.0 release, correction listed first in NEWS; H8 U1+ wait for 0.9.0 T2.

## Not in this plan

Latent means and products (0.11.0), three-way products, relaxing rule 9, any change to the four-way algebra beyond U0's corrections.
