# PLAN: Four-way decomposition via the native engine, 0.10.0

**Date:** 2026-10-12 (revised same day after an Opus adversarial review; the review's findings are numbered F1-F11 below) | **Branch:** `feature/native-four-way` (not created; branching waits for your request)
**Inputs:** [SPEC amendment (approved)](SPEC-sem-grammar-amendment-product-2026-10-12.md), [GRILL](GRILL-native-mean-structure-2026-10-12.md) G4-G6, [SPEC-interaction-fourway-2026-06-03.md](SPEC-interaction-fourway-2026-06-03.md) (decomposition contract), [PLAN 0.9.0](PLAN-native-mean-structure-2026-10-12.md)
**Depends on:** 0.9.0 tasks T3 (likelihood), T5 (counts), T7 (methods/extraction) merged, **and U0 below merged**. **U1 and later start only after 0.9.0 T2 merges** (shared files `R/sem-model.R`, `R/fit-sem.R`; [GRILL H8](GRILL-native-four-way-2026-10-12.md)). Only U0 runs in parallel. Grill decisions H1-H8 are applied below.
**Out of scope:** latent means and latent products (0.11.0), three-way products.

Sizes: XS/S/M, no hour estimates (0.7.0 grill D7). Checkpoints: **A** after U4, **B** after U8, **C** before release.

## What the code does (corrected by the review)

- `extract_mediation(<SEMFit>)` (`R/extract-sem.R:88`) calls the shared lavaan worker `.extract_interaction_mediation_lavaan()` (`R/extract-lavaan.R:1005`). The algebra is shared, **but the worker has live defects on the lavaan route today** (F1, F3, F5, U0). The earlier claim "no new decomposition math" was wrong: fixing the worker is a prerequisite, not a given.
- Native blockers: no mediator-intercept (`m~1`) row until 0.9.0, **and mean structure is auto-on only when a `~1` appears** (F2), so a plain `m ~ x; y ~ m + x + x:m` has no intercept and would hit the worker's lavaan-only advice ("refit the lavaan model with meanstructure = TRUE", `R/extract-lavaan.R:1088-1090`) if the native wrapper at `R/extract-sem.R:90-96` were simply deleted.
- Product lookup is not literal: `.find_interaction_term_lavaan` (`R/extract-lavaan.R:991-993`) already tries `interaction`, `x:m`, and `m:x` (F11). The helper work is smaller than first stated, but names written to the table are still canonical.

## Dependency order

U0 (separate, from `dev`) -> [0.9.0 T3/T5/T7] -> U1 -> U2 -> U3 -> U4 (A) -> U5 -> U6 -> U7 -> U8 (B) -> U9 -> U10 (C)

## Tasks

### U0: Fix the live four-way worker defects, on their own branch (M) — prerequisite, not part of 0.10.0
Branch `fix/four-way-worker` from `dev`; own PR; merged before U6. Lavaan route only; no native code.
- [ ] **F1, SEs drop the mediator-covariate term.** `R/effect-se.R:251-252` filters `m_<cov>` against `rownames(vc)`, but the worker's alias list (`R/extract-lavaan.R:1121-1127`) never adds `m_<cov>` rows, so INTref, NDE and TE lose the `g * cbar` term and `cov(g, b0)`. Reviewer's evidence: `m ~ x + c1; y ~ x + m + xm + c1`, n = 2000: medfit INTref SE 0.0366, lavaan's own `:=` 0.095. Fix: add `m_<cov>` alias rows (or use the estimated exogenous means with their covariance once 0.9.0 exists, as a follow-up).
- [ ] **F3, treatment product in the mediator equation is silently wrong.** `m ~ x + w + x:w; y ~ x + m + x:m` returns `a` = 0.500 against a true averaged 1.690 (`R/extract-lavaan.R:1066`, `:1096-1109`). Reject, when four-way is selected, any product involving the treatment in the mediator equation and any treatment-by-covariate product in the outcome equation; add a binary-treatment check (or document the 0-to-1 contrast); name the feature in the error.
- [ ] **F5, weighted INTref differs between routes.** Worker uses unweighted covariate means (`R/extract-lavaan.R:1107`), the glm route uses weighted design means (`R/extract-lm.R:738-741`): INTref 1.1638 vs 1.4556 on the same data and weights. Use weighted means.
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
- [ ] **Placement:** listwise deletion happens inside `.sem_fit_syntax` (`R/sem-fit.R:42-50`), after the absent-column check at `:32-35`. Build each distinct product column there, after deletion and before the sample is formed; `fit_sem()` and `fit_mediation(engine = "native", model =)` both go through it. Files: `R/sem-fit.R` (omitted from the first draft), `R/fit-sem.R`.
- [ ] Pre-existing `m:x` or `x:m` column: used only if it equals `x*m` exactly (NA-safe comparison: compare after deletion), otherwise an error naming the column and both options.
- **Planted defects that can fail** (the two in the first draft could not: `NA` propagates through `*` so building before or after deletion gives the same rows, and `x*m` equals `m*x` exactly in IEEE 754): (a) run the pre-existing-column equality check **before** deletion on data containing NAs, which breaks (NA in the comparison); (b) name the column in the **wrong order** (`x:m` instead of the canonical `m:x`) and require the table, `coef()` names and the extractor lookup to fail.
- Tests: explicit user-built column equals the materialized fit; mismatched column errors; both planted defects fail.

### U4: Model-validity rules 8 and 9 (M) — Checkpoint A (F6, F7)
- [ ] Rule 8 as in the amendment: directed graph from the whole parsed table (plain regressors, each product factor to the target, latent to indicators); reject a product whose factor is the target or a descendant; no data attached.
- [ ] **Rule 9 runs on the completed table, not only the parsed table (F6).** `.sem_complete` adds residual covariances for pure outcomes (`pairs(c(r$pure_lv_y, r$pure_ov_y))`, `R/sem-model.R:82`): in `m ~ x; y ~ m + x + xm; z ~ w` it adds `y ~~ z` (user = 0), which the parsed-table check cannot see, and with correlated outcome errors SEM differs from OLS by up to 3.1e-3. **Decided (GRILL H6):** in a model with a product, completion fixes auto-added pure-outcome residual covariances at 0 (the supported class has no residual covariances) and prints one note saying so; the no-product twin keeps the free covariance. A user who needs the covariance cannot have it with a product in 0.10.0.
- [ ] **Rule 9 gains an intercept clause (F7).** 0.9.0 T2 lets intercepts be fixed, labeled (including shared with a path) and constrained; any of those on a `~1` row changes the slopes and `b0` away from OLS yet passes the current rule 9. In a product model, `~1` rows must be free, unlabeled-or-uniquely-labeled, and absent from `==`/`<`/`>` constraints.
- Tests: the amendment's rule 8 and 9 rows plus `y ~ x:z; z ~ w:y`, the longer chain, the `y ~~ z` completion case, a fixed intercept, a shared intercept/path label, an intercept in a constraint; each accepted again once the product is removed; planted defects (no descendant search; no residual-covariance check on the completed table; no intercept clause).
- **Checkpoint A:** identity, materialization, and rejection tests green; existing native suite unchanged. **Demand check (GRILL H4):** is there a concrete consumer of native four-way (a probmed or RMediation request, the author's own use, an issue)? If not, U5-U10 stop; the parser and rules stay usable for other products. Decide what counts as a consumer before reaching the checkpoint. Go/no-go on U5-U8.

### U5: Mean structure on for four-way (S) (F2) — new
- [ ] **Decided (GRILL H5): any product term turns saturated mean structure on, in both `fit_sem()` and `fit_mediation()`.** `decomposition` is an extraction argument (`R/fit-sem.R:143`), so a trigger keyed on it would fail the `fit_sem()` + `extract_mediation()` path; product models are new syntax, so no existing fit changes. `fit_mediation(engine = "native")` also gains `meanstructure` in `fit_args` (resolves the 0.9.0 GRILL open question). Document "product => meanstructure = TRUE" and test it in both call paths.
- [ ] Test the default call that has no `~1`: it yields a four-way decomposition (or the chosen error), never lavaan-only advice.

### U6: Model-test policy and information (M) (F4, F9, F10)
- [ ] Detect "product with an endogenous factor" and "restricted exogenous block" on the completed table (including covariances dropped by the pairing rule, `R/sem-model.R:80-88`); when either holds: warn once at fit; `anova()` and `mbco_sem()` refuse naming the product; `glance()`/`summary()` report chi-square, df, p-value and fit indices as `NA` with a note. Warn once when a product is present and `se_type != "sandwich"`.
- [ ] **Expected information (F4).** With an endogenous product factor, expected-information SEs are wrong, sandwich included (`y~xm` SE 0.0308 with expected, 0.0436 with observed = OLS; native sandwich 0.0320 vs HC0-exact 0.0446 with observed). The amendment's "sandwich SEs are safe" therefore holds **only with observed information**: refuse `information = "expected"` (or switch to observed with a message) when a product has an endogenous factor; document it.
- [ ] **Tolerance (F9).** The 2a gate "equal `lm()` to 1e-8" fails today (max |SEM - OLS| 3.5e-8 and 7.1e-8, covariance-only, n = 20000). Derive the tolerance from the optimizer's convergence criterion and state the derivation; start at 1e-6.
- [ ] **Gate mechanics (F10).** The population gate asserts chi-square far above the critical value while `glance()` reports it `NA`: read it from an internal accessor (`.sem_chisq()`), documented as test-only. The null gate (`exo-product-null.R`) uses a precomputed column `p`; add a variant through the `:` path.
- Tests: population gate; null gate (rejection in [0.03, 0.07], mean chi-square within 0.15 of df) both ways; restricted-block cases refused; expected-information refusal; planted defect: removing the endogenous-factor check lets `anova()` run.

### U7: Wire native four-way (S) (F11)
- [ ] `extract_mediation(<SEMFit>, interaction = )` resolves the product with `.sem_product_name(treatment, mediator)` (both argument orders; the worker already tries both orders).
- [ ] Replace the error-rewriting wrapper (`R/extract-sem.R:90-96`) with a **native-worded** error for the remaining no-intercept case (do not delete it blindly, F2).
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
- [ ] `?"medfit-syntax"`, `man/fit_sem.Rd`, `model-native.qmd`, `native-guide.qmd`, a native four-way worked example (centering matters for the effect at `M = 0`), the lavaan comparison row, `methods.qmd`, **CLAUDE.md file-organization and testing sections plus the Engines row**, `.STATUS`.
- [ ] One table of the supported class and each limit, so a rejection message is findable; doc currency check over tutorials and references; count and link tests.
- [ ] **Consumer check (F11):** `rforge:impact`/lightweight scratch-library check for probmed and RMediation (Suggests-only revdep per CLAUDE.md), because U0 changes lavaan-route four-way results.

### U10: Close-out (S) — Checkpoint C
- [ ] Full suite with counts; `R CMD check --as-cran`; strict-flavor check; `urlchecker`; `spelling`; CRAN stays on hold (resync `cran-comments.md` before any submission).
- [ ] Apply the amendment to the frozen grammar text in one labeled commit, or record that the amendment remains the authority.

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
