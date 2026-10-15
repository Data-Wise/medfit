# PLAN: factor covariates in the native engine (0.11.0 headline)

| | |
|---|---|
| **Date** | 2026-10-14 |
| **Status** | DRAFT for the author's review; nothing implemented, no branch yet |
| **Spec** | [SPEC-native-factor-covariates-2026-10-14.md](SPEC-native-factor-covariates-2026-10-14.md) (D1-D12, F1-F10) |
| **Branch** | `feature/factor-covariates` off `dev`, created only on request; one PR to `dev` (squash) |

## Verified anchors (2026-10-14)

- `.sem_fit_syntax()` (`R/sem-fit.R:9`): parse (`:20`), zero-product branch dispatch (`:21-26`, re-enters with `parsed =`), `.sem_complete()` (`:31`), product materialization (`:38`), numeric check (`:54`), listwise deletion (`:59`). `fit$data` is the model's observed columns after deletion (`R/sem-fit.R:122`), stored as `SEMFit@data` (`R/fit-sem.R:139`).
- `mbco_sem()` refits `paste0(fit@model, "\n", con)` against `fit@data` (`R/sem-mbco.R:158`) and passes the stored `fixed_x` (`:153`). `fit@model` keeps the user's text, so it still names `g`; `fit@internals$fixed_x` will already hold dummy names.
- `SEMFit` has an `internals` list (`R/classes.R:2223`), so the factor map needs no new property.

## Design consequence

Run the pre-pass **right after the parse and before the branch dispatch**, on `parsed$parameters`. Branch refits re-enter with the expanded table and data, so the pre-pass sees no factors there (D12: a no-op). `mbco_sem()` re-parses the original text, so the pre-pass gets the stored map: a name absent from `data` whose dummies are all present expands from the map (F10).

## Tasks (vertical slices, red tests first; each leaves `devtools::test()` green)

| # | Slice | Files | Acceptance | Verify |
|---|---|---|---|---|
| T1 | Pre-pass skeleton: detect factor / character / logical names on a regression's right side; reference level and C-locale order (F1, F2); ordered and one-level errors (D7); dummy names `<factor>_<level>` with collision and invalid-name errors (F3, D5) | `R/sem-fit.R` (`.sem_expand_factors()`), `tests/testthat/test-sem-factor-expand.R` | Table rewritten to dummies; data gains the columns; numeric-only models return the input unchanged (same object) | `filter = "sem-factor"`; `filter = "sem-frozen"` bit-identical |
| T2 | Wire into `.sem_fit_syntax()` before the branch dispatch; fit equals the hand-coded twin (estimates 1e-8, SEs 1e-6, logLik); lavaan parity on the twin | `R/sem-fit.R`, `tests/testthat/test-sem-factor-parity.R` | `outcome ~ x + m + g` fits; completed table and `ram$obs` hold dummies, not `g` (the Order row) | parity file; full suite |
| T3 | Labels and fixed values (F4, D1): `b*g` errors, `b*g_b` works; message names the dummy | `R/sem-model.R` or the pre-pass, tests | Error text exact; label on one dummy fits | `test-sem-factor-rules.R` |
| T4 | `fixed_x` (F6): `TRUE`, `"g"`, a dummy name; names rewritten in the pre-pass | `R/sem-fit.R`, tests | Same rows as the hand-coded `fixed_x` twin | `test-sem-factor-fixedx.R` |
| T5 | Missing data (F7, D2): dummies from the full column before listwise deletion; NA factor gives NA in every dummy; level only in dropped rows gives an all-zero dummy reported by the existing singularity check | `R/sem-fit.R`, tests | Row count equals `complete.cases`; error names the dummy | `test-sem-factor-missing.R` |
| T6 | Products (F5, D3, D4): `g:m` becomes `g_b:m`, `g_c:m` through the canonical product name and rules 8 and 9; `g` on both sides errors; four-way keeps refusing a `g:m` product with the new message | `R/sem-fit.R`, `R/extract-sem.R`, tests | Fit equals the hand-coded product twin; refusal message says the effects differ by `g` | `test-sem-factor-product.R` |
| T7 | Stored contract (F8, F10, D11, D12): factor map in `fit@internals`; `mbco_sem()` and branch refits; `@data` has no original factor | `R/fit-sem.R`, `R/sem-mbco.R`, `R/sem-fit.R`, tests | `mbco_sem()` on a factor fit (with and without `fixed_x`, with `g_b:m`, and a zero-product branch fit) equals the twin | `test-sem-factor-refit.R` |
| T8 | Extraction (F9, D9): four-way with a factor covariate in the mediator equation equals the glm route; a factor treatment or mediator keeps a numeric error whose text names the factor and the rule | `R/extract-sem.R`, tests | Agreement to 1e-8 | `test-sem-factor-extract.R` |
| T9 | Planted defects: wrong reference level, dummies after deletion, label accepted, expansion after completion, refit without the map (`sem_mutate()` with `fx_skip_covr()`) | `tests/testthat/test-sem-factor-defects.R` | Each fails the intended test | defect file |
| T10 | Docs: rewrite the "must be numeric" error text; `?"medfit-syntax"`, `model-native.qmd` limits table, cookbook recipe 20 note, refcard row, NEWS under development; keep the spec-quoted messages in the guide guards (`test-guide-native-limits.R`) | `R/sem-fit.R`, `R/sem-syntax-help.R`, `vignettes/articles/*.qmd`, `NEWS.md` | Guard tests pass; docs audit clean | `devtools::document()`, spelling, lint |

## Checkpoints

- **After T2:** frozen fixture bit-identical, parity with the hand-coded fit. Stop and review if parity fails; every later slice builds on it.
- **After T7:** refit contract works. This is the Codex-flagged risk, so review before T8-T10.
- **Close-out (pre-PR, per the e2e rule):** one live exercise that can fail, with transcript in the PR body: factor-covariate fit versus the hand-coded twin and lavaan, plus an `mbco_sem()` refit. Full suite counts, lint at 120 columns, strict `R CMD check` 0/0/0 (run before any release, not for the feature PR alone).

## Risks

| Risk | Mitigation |
|---|---|
| Pre-pass changes a numeric-only result | Returns the input objects unchanged when no factor is found; frozen fixture after every slice |
| A refit with the map and a model edited by the user | The map applies only to names absent from `data` whose dummies are all present; anything else errors as today |
| Hidden dependence on `fit@data` columns elsewhere (`bootstrap_mediation()`, `anova()`) | Grep consumers of `@data` in T7; add a nonparametric-bootstrap refit test |

## Out of scope

Group-averaged four-way (D4), ordered factors (D7), a factor treatment or mediator (D9), latent means (1.0).
