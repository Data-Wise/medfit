# SPEC: factor covariates in the native engine (`fit_sem()`, `fit_mediation(engine = "native")`)

| | |
|---|---|
| **Date** | 2026-10-14 |
| **Status** | APPROVED by the author 2026-10-14 (D1-D9); revised 2026-10-14 per the Codex adversarial review (D10-D12: expansion before completion, stored-data contract); nothing implemented |
| **Origin** | [PROPOSAL-0.10.1-2026-10-14.md](../PROPOSAL-0.10.1-2026-10-14.md) (advice: its own spec, not a patch); the `fit_sem()` error "model variables must be numeric: g" (`R/sem-fit.R:54`) |
| **Evidence labels** | **[V]** verified in this repo; **[A]** assumption, correct me |

## Assumptions

1. **[V]** A factor, character or logical column in `data` that the model names stops the fit at `R/sem-fit.R:54`; users dummy-code by hand (cookbook recipe 20 note; edge test in #209).
2. **[V]** The fit pipeline is: parse, `.sem_complete()`, product materialization (`.sem_materialize_products()`, `R/sem-fit.R:257`), `.sem_assign_fixed_x()`, `.sem_to_ram()`, numeric check, listwise deletion, `.sem_sample()`. Dummies are observed exogenous numeric columns, so every downstream stage already handles them **provided they exist before `.sem_complete()`**: completion is data-free and adds variance, covariance and mean rows for every exogenous name it sees, and resolves `fixed_x` names, so a factor left in the table would reach the numeric check as an observed variable (Codex finding 1). `.sem_fit_syntax()` is re-entered by `mbco_sem()` (`R/sem-mbco.R:156`, from `fit@data`) and by the zero-product branch fits, so the expansion must also be safe on a re-entry (Codex finding 2).
3. **[A]** Only a factor on the **right side of a regression** (a covariate or a product factor) is expanded. A factor as an outcome, an indicator, a treatment or a mediator named to `extract_mediation()` keeps the numeric error, because the effects need a single column.
4. **[A]** Dummies are exogenous and not Gaussian, as a binary treatment already is; the model-test policy for a product (chi-square `NA` when a product factor is a regression target) is unchanged and applies per dummy.

## 1. Objective

Let a factor covariate appear in a native model by name, e.g. `outcome ~ x + m + g`, and fit it exactly as the hand-coded dummies would be fit. Why: today's error sends users to a manual step that is easy to get wrong (reference level, naming, a product with the factor). Users: applied researchers with categorical covariates (site, group, sex).

**What does not change:** every fit whose model names only numeric columns (the frozen fixture, bit for bit), the syntax grammar, and `extract_mediation()`'s treatment and mediator rules.

## 2. Rules (proposed)

| Rule | Statement |
|---|---|
| F1 expansion | A name on a regression's right side that is a factor, character or logical column of `data` is replaced by one numeric dummy per non-reference level, each with the original row's other properties. Logical gives one 0/1 column, no reference. **Timing (D10):** this is a data-aware pre-pass `.sem_expand_factors(parsed$parameters, data, fixed_x)` that runs on the parsed table **before** `.sem_complete()`, so completion, role classification, scale and product checks, `fixed_x` resolution and RAM construction see only numeric names. It returns the rewritten table, the data with the dummy columns, `fixed_x` with factor names replaced by their dummy names, and the factor map (F10). |
| F2 reference and order | The reference level is `levels(x)[1]`; a character column is converted with levels sorted in the C locale (the rule `.sem_product_name()` uses), so results do not depend on the session locale. An ordered factor is an error (polynomial contrasts are not dummies). A factor with one level is an error. |
| F3 names | A dummy is named `<factor>_<level>`. A collision with an existing column or another dummy is an error naming both. A level that makes an invalid name is an error (the user renames it). |
| F3a dummy references (D13) | `<column>_<level>` absent from `data`, matching a non-reference level of a categorical column, builds that one dummy; the map keeps only the dummies in use. |
| F3b explicit dummy plus bare factor (D14) | In one equation, a dummy named explicitly is not generated again from the bare factor; the explicit row (with its label) stays. |
| F4 labels and fixed values | A label (`b*g`) or a fixed value on a factor term is an error: it cannot name several coefficients. A label on one dummy (`b*g_b`) is allowed. |
| F5 products | `g:m` expands to `g_b:m`, `g_c:m` (each through the canonical product name and the existing rules 8 and 9). A factor on both sides of a product is an error (as `x:x` is). |
| F6 `fixed_x` | `fixed_x = TRUE` includes the dummies; `fixed_x = "g"` selects all of the factor's dummies; a dummy name selects one. Resolved inside the F1 pre-pass (the names are rewritten before completion sees them), so `.sem_assign_fixed_x()` is unchanged. |
| F7 data | Dummies are built from the full column **before** listwise deletion, so the dummy set does not depend on which rows survive; a level present only in dropped rows gives an all-zero column, which the existing singularity checks report. A missing value in the factor gives NA in every dummy (the row is dropped once, by listwise deletion). Weights are unaffected. |
| F8 output | `tidy()`, `summary()` and the table show the dummy rows by their names. `@data` holds the **modeled** columns only (numeric columns and the dummies), never the original factor: keeping both would make F3's collision rule fail on a refit (Codex finding 2). |
| F10 refit contract (D11) | The fit stores the factor map (factor, levels, reference, dummy names). A refit from `@data` (`mbco_sem()`, the zero-product branch fits) finds the factor name absent from `data` and its dummies present, so the pre-pass **rewrites the model text/table through the stored map instead of re-expanding**; with no map it errors as today. A column that is already a dummy of the same factor and identical to what the expansion would build is not a collision. `mbco_sem()` constraint text that names the factor is rewritten through the same map (a label on one dummy needs no rewrite). |
| F9 extraction | In `extract_mediation()` a factor in the mediator equation enters the covariate means through its dummies (the `m_<dummy>` rows, as the lm/glm route already handles factor dummies). |

## 3. Commands

```bash
Rscript -e 'devtools::test(filter = "sem-factor")'     # new tests
Rscript -e 'devtools::test(filter = "sem-frozen")'     # frozen fixture, bit-identical
NOT_CRAN=true Rscript -e 'devtools::test(reporter = "summary")'
```

## 4. Project structure

```
R/sem-fit.R          .sem_expand_factors(tab, data, fixed_x) BEFORE .sem_complete(); returns table, data, fixed_x, factor map
R/sem-model.R        F4 label errors (factor term with a label or fixed value)
R/fit-sem.R          stores the factor map on the SEMFit
R/sem-mbco.R         refit rewrites factor names through the stored map (F10)
R/extract-sem.R      F9 covariate means over dummy columns
tests/testthat/test-sem-factor-*.R   rules F1-F9, the frozen no-op, planted defects
vignettes/articles/  model-native.qmd limits, cookbook recipe 20 note, ?"medfit-syntax"; NEWS
```

## 5. Testing strategy

| Level | What | Oracle |
|---|---|---|
| Parity | `outcome ~ x + m + g` equals the same fit with hand-coded dummies, estimates, SEs, logLik | the hand-coded fit; `lm()` per equation for a recursive model; lavaan with the same dummies |
| Rules | F2 ordered/one-level/character-locale; F3 collision and bad names; F4 labels; F5 factor products; F6 `fixed_x` | error messages, exact values |
| Order | the completed table and `ram$obs` contain the dummies and not the factor; `fixed_x = "g"` and `fixed_x = TRUE` give the same rows as the hand-coded twin | table and RAM equality with the hand-coded fit |
| Refit | `mbco_sem()` on a factor-covariate fit (with and without `fixed_x`, with a `g_b:m` product) equals `mbco_sem()` on the hand-coded twin; a branch-split refit works | the hand-coded twin |
| Missing | NA in a factor drops the row once; a level only in dropped rows | listwise count |
| Extraction | four-way with a factor covariate in the mediator equation equals the glm route with the same factor | `fit_mediation(engine = "glm")` four-way |
| Frozen | numeric-only models bit-identical | the T1 fixture |
| Planted defects | wrong reference level; dummies built after listwise deletion; label on a factor accepted; expansion moved after completion; refit without the map | each fails the right test |

## 6. Boundaries

- **Always:** frozen fixture after any edit to `.sem_fit_syntax`; oracle-based tests; US English; lint at 120 columns.
- **Ask first:** changing the dummy naming scheme after release; accepting an ordered factor; expanding a factor treatment or mediator.
- **Never:** change any numeric-only result; guess a reference level from the data's order of appearance; silently drop a level.

## 7. Success criteria

1. A factor covariate fits and equals the hand-coded fit to 1e-8 (estimates) and 1e-6 (SEs); lavaan parity on the hand-coded twin.
2. The frozen fixture is bit-identical; the full suite has 0 failures; strict `R CMD check` 0/0/0.
3. Each F-rule has a passing test and each planted defect a failing one.
4. Docs: `?"medfit-syntax"`, `model-native.qmd`, recipe 20, NEWS; the error "must be numeric" is rewritten to name the factor and point to the rule.

## 7b. Grill decisions (2026-10-14, author)

| # | Question | Decision |
|---|---|---|
| D1 | F4: `b*g` on a factor term | **Error**; label a single dummy (`b*g_b`). A label names one coefficient, and sharing it would add a hidden equality constraint (df + k - 2). |
| D2 | F7: when dummies are built | **From the full column, before listwise deletion.** A level only in dropped rows gives an all-zero dummy that the singularity checks report by name; the coefficient set never depends on the missingness pattern. |
| D3 | F5: factor in a product | **Expand to one product per dummy** (`g_b:m`, `g_c:m`), each through the canonical name and rules 8 and 9, as `lm()` does; messages name the dummy product. |
| D4 | Four-way with a `g:m` product | **Keep refusing**, with a message that says the effects differ by `g` and averaging over `g` is not supported. A group-averaged decomposition is a new estimand (its SE would carry the sampling variance of the group proportions) and needs its own spec. |
| D5 | F3: dummy names | **`<factor>_<level>`** (`site_B`). A clash with an existing column is an error naming both; a level that is not a valid name (space, symbol) is an error asking the user to rename the level, never a silent rewrite. The name is fixed once released: it appears in users' labels and `:=` formulas. |
| D6 | Character columns | **Accepted**; converted to a factor with levels sorted in the C locale (locale-independent, as `.sem_product_name()`). |
| D7 | Ordered factors | **Error** (polynomial contrasts are not dummies); the message tells the user to use `factor(x, ordered = FALSE)`. |
| D8 | Release | **0.11.0 headline** (latent means deferred to 1.0 unless a consumer appears). |
| D9 | Two-level factor as treatment or mediator | **Keep the numeric error**; effects need one column named in `extract_mediation()`. |

## 7c. Codex adversarial review (2026-10-14) and revisions

Verdict: do not ship as written. Both high findings confirmed against the code and applied above.

| # | Finding | Verification | Decision |
|---|---|---|---|
| D10 | Expansion after `.sem_complete()` is too late: completion is data-free (`R/sem-fit.R:29`), adds rows for the factor and resolves `fixed_x` before dummies exist, so the numeric check (`R/sem-fit.R:54`) still fires | Confirmed | **Pre-pass before completion** (F1, F6); product and rule 8/9 checks need no change |
| D11 | `mbco_sem()` refits from `fit@data` (`R/sem-mbco.R:156`); F8 kept the factor and the dummies, so F3 would collide | Confirmed, with a correction: the stored data holds only the modeled columns, so the actual failure is a refit text that still names `g`; keeping both columns is what would create the collision | **`@data` holds modeled columns; the fit stores a factor map; refits rewrite through it** (F8, F10) |
| D13 | D1 says "label one dummy (`b*g_b`)", but with a factor column `g` in `data` no column `g_b` exists to name (found at T3) | Confirmed | **A model name `<column>_<level>` that is not a column of `data` and names a non-reference level of a categorical column refers to that one dummy** (F3a); naming only some dummies builds only those; the reference level's name is an error; two columns that could own the name are an error |
| D14 | `y ~ g + b*g_b` named the dummy twice (Codex review of T3) | Confirmed | **An explicit dummy row in the same equation keeps its row and modifier; the bare factor generates only the other dummies** (F3b) |
| D12 | The zero-product branch fits (`.sem_fit_branches()`) re-enter `.sem_fit_syntax()` too | Same contract | The pre-pass is a no-op on an already-expanded table and data; tested |

## 8. Open questions for the author

None: D1-D12 settled 2026-10-14. Next: an implementation plan (`tasks/plan.md`) and a feature branch on request.
