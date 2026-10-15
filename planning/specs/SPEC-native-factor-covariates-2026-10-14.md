# SPEC: factor covariates in the native engine (`fit_sem()`, `fit_mediation(engine = "native")`)

| | |
|---|---|
| **Date** | 2026-10-14 |
| **Status** | DRAFT, grill in progress (D1-D5 decided 2026-10-14); nothing implemented |
| **Origin** | [PROPOSAL-0.10.1-2026-10-14.md](../PROPOSAL-0.10.1-2026-10-14.md) (advice: its own spec, not a patch); the `fit_sem()` error "model variables must be numeric: g" (`R/sem-fit.R:54`) |
| **Evidence labels** | **[V]** verified in this repo; **[A]** assumption, correct me |

## Assumptions

1. **[V]** A factor, character or logical column in `data` that the model names stops the fit at `R/sem-fit.R:54`; users dummy-code by hand (cookbook recipe 20 note; edge test in #209).
2. **[V]** The fit pipeline is: parse, `.sem_complete()`, product materialization (`.sem_materialize_products()`, `R/sem-fit.R:257`), `.sem_assign_fixed_x()`, `.sem_to_ram()`, numeric check, listwise deletion, `.sem_sample()`. Dummies are observed exogenous numeric columns, so every downstream stage already handles them.
3. **[A]** Only a factor on the **right side of a regression** (a covariate or a product factor) is expanded. A factor as an outcome, an indicator, a treatment or a mediator named to `extract_mediation()` keeps the numeric error, because the effects need a single column.
4. **[A]** Dummies are exogenous and not Gaussian, as a binary treatment already is; the model-test policy for a product (chi-square `NA` when a product factor is a regression target) is unchanged and applies per dummy.

## 1. Objective

Let a factor covariate appear in a native model by name, e.g. `outcome ~ x + m + g`, and fit it exactly as the hand-coded dummies would be fit. Why: today's error sends users to a manual step that is easy to get wrong (reference level, naming, a product with the factor). Users: applied researchers with categorical covariates (site, group, sex).

**What does not change:** every fit whose model names only numeric columns (the frozen fixture, bit for bit), the syntax grammar, and `extract_mediation()`'s treatment and mediator rules.

## 2. Rules (proposed)

| Rule | Statement |
|---|---|
| F1 expansion | A name on a regression's right side that is a factor, character or logical column of `data` is replaced, in the completed table, by one numeric dummy per non-reference level, each with the original row's other properties. Logical gives one 0/1 column, no reference. |
| F2 reference and order | The reference level is `levels(x)[1]`; a character column is converted with levels sorted in the C locale (the rule `.sem_product_name()` uses), so results do not depend on the session locale. An ordered factor is an error (polynomial contrasts are not dummies). A factor with one level is an error. |
| F3 names | A dummy is named `<factor>_<level>`. A collision with an existing column or another dummy is an error naming both. A level that makes an invalid name is an error (the user renames it). |
| F4 labels and fixed values | A label (`b*g`) or a fixed value on a factor term is an error: it cannot name several coefficients. A label on one dummy (`b*g_b`) is allowed. |
| F5 products | `g:m` expands to `g_b:m`, `g_c:m` (each through the canonical product name and the existing rules 8 and 9). A factor on both sides of a product is an error (as `x:x` is). |
| F6 `fixed_x` | `fixed_x = TRUE` includes the dummies; `fixed_x = "g"` selects all of the factor's dummies; a dummy name selects one. |
| F7 data | Dummies are built from the full column **before** listwise deletion, so the dummy set does not depend on which rows survive; a level present only in dropped rows gives an all-zero column, which the existing singularity checks report. A missing value in the factor gives NA in every dummy (the row is dropped once, by listwise deletion). Weights are unaffected. |
| F8 output | `tidy()`, `summary()` and the table show the dummy rows by their names; `@data` keeps the original columns and the dummies. |
| F9 extraction | In `extract_mediation()` a factor in the mediator equation enters the covariate means through its dummies (the `m_<dummy>` rows, as the lm/glm route already handles factor dummies). |

## 3. Commands

```bash
Rscript -e 'devtools::test(filter = "sem-factor")'     # new tests
Rscript -e 'devtools::test(filter = "sem-frozen")'     # frozen fixture, bit-identical
NOT_CRAN=true Rscript -e 'devtools::test(reporter = "summary")'
```

## 4. Project structure

```
R/sem-fit.R          .sem_expand_factors(tab, data) before .sem_materialize_products(); dummy columns added to `data`
R/sem-model.R        .sem_assign_fixed_x(): factor selection by name; F4 label errors
R/extract-sem.R      F9 covariate means over dummy columns
tests/testthat/test-sem-factor-*.R   rules F1-F9, the frozen no-op, planted defects
vignettes/articles/  model-native.qmd limits, cookbook recipe 20 note, ?"medfit-syntax"; NEWS
```

## 5. Testing strategy

| Level | What | Oracle |
|---|---|---|
| Parity | `outcome ~ x + m + g` equals the same fit with hand-coded dummies, estimates, SEs, logLik | the hand-coded fit; `lm()` per equation for a recursive model; lavaan with the same dummies |
| Rules | F2 ordered/one-level/character-locale; F3 collision and bad names; F4 labels; F5 factor products; F6 `fixed_x` | error messages, exact values |
| Missing | NA in a factor drops the row once; a level only in dropped rows | listwise count |
| Extraction | four-way with a factor covariate in the mediator equation equals the glm route with the same factor | `fit_mediation(engine = "glm")` four-way |
| Frozen | numeric-only models bit-identical | the T1 fixture |
| Planted defects | wrong reference level; dummies built after listwise deletion; label on a factor accepted | each fails the right test |

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

## 8. Open questions for the author

1. ~~Name scheme~~ decided, D5.
2. **Character columns**: accept with C-locale levels (recommended) or error and ask for a factor?
3. **Ordered factors**: error (recommended) or treat as unordered with a warning?
4. **Release**: 0.11.0 headline (recommended, since latent means are deferred) or batch into the next release with the covariate-mean option?
5. **Treatment or mediator as a two-level factor**: keep the numeric error (recommended) or expand with a 0/1 rule?
