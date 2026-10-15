# PLAN: factor covariates in the native engine (0.11.0 headline)

| | |
|---|---|
| **Date** | 2026-10-14 |
| **Status** | T1-T3 and T7 done on `feature/factor-covariates` (`d6ca3c2`); T4 and T5 revised 2026-10-14 (harness, checks, agent skills); T6, T8-T10 pending |
| **Spec** | [SPEC-native-factor-covariates-2026-10-14.md](SPEC-native-factor-covariates-2026-10-14.md) (D1-D12, F1-F10) |
| **Branch** | `feature/factor-covariates` (worktree `~/.git-worktrees/medfit/feature-factor-covariates`); one PR to `dev` (squash) |

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
| T4 | `fixed_x` at fit level (F6): `TRUE`, `"g"`, `c("x", "g")`, a dummy name; see "T4 detail" | `R/sem-factor.R` (only if a test finds a gap), tests, gate | Fixed rows, df, logLik and `glance()$fixed_x` equal the hand-coded twin | `test-sem-factor-fixedx.R`; gate cells `fx` |
| T5 | Missing data (F7, D2): dummies from the full column before deletion; see "T5 detail" | `R/sem-factor.R`, `R/sem-fit.R` (only if a test finds a gap), tests, gate | Row count equals `complete.cases` on the twin; an all-zero dummy is reported by name | `test-sem-factor-missing.R`; gate cells `miss` |
| T6 | Products (F5, D3, D4): `g:m` becomes `g_b:m`, `g_c:m` through the canonical product name and rules 8 and 9; `g` on both sides errors; four-way keeps refusing a `g:m` product with the new message | `R/sem-fit.R`, `R/extract-sem.R`, tests | Fit equals the hand-coded product twin; refusal message says the effects differ by `g` | `test-sem-factor-product.R` |
| T7 | Stored contract (F8, F10, D11, D12): factor map in `fit@internals`; `mbco_sem()` and branch refits; `@data` has no original factor | `R/fit-sem.R`, `R/sem-mbco.R`, `R/sem-fit.R`, tests | `mbco_sem()` on a factor fit (with and without `fixed_x`, with `g_b:m`, and a zero-product branch fit) equals the twin | `test-sem-factor-refit.R` |
| T8 | Extraction (F9, D9): four-way with a factor covariate in the mediator equation equals the glm route; a factor treatment or mediator keeps a numeric error whose text names the factor and the rule | `R/extract-sem.R`, tests | Agreement to 1e-8 | `test-sem-factor-extract.R` |
| T9 | Planted defects: wrong reference level, dummies after deletion, label accepted, expansion after completion, refit without the map (`sem_mutate()` with `fx_skip_covr()`) | `tests/testthat/test-sem-factor-defects.R` | Each fails the intended test | defect file |
| T10 | Docs: rewrite the "must be numeric" error text; `?"medfit-syntax"`, `model-native.qmd` limits table, cookbook recipe 20 note, refcard row, NEWS under development; keep the spec-quoted messages in the guide guards (`test-guide-native-limits.R`) | `R/sem-fit.R`, `R/sem-syntax-help.R`, `vignettes/articles/*.qmd`, `NEWS.md` | Guard tests pass; docs audit clean | `devtools::document()`, spelling, lint |

## T4 and T5 detail (revised 2026-10-14)

**Already covered, so not re-tested:** `.sem_expand_fixed_x()` name rewriting (T1 unit tests); `mbco_sem()` refit with `fixed_x` as `"g"`, `"g_b"`, `c("x","g")`, `TRUE` (T7, `test-sem-factor-refit.R`); the factor map in `internals`. T4 and T5 add the **fit-level** behavior and the **gate**; they are expected to need little or no `R/` change, and a gap a test finds is fixed in the slice.

### T4 tests (`test-sem-factor-fixedx.R`, red first)

| Case | Oracle | Pass rule |
|---|---|---|
| `fixed_x = "g"` equals the twin with `c("g_b","g_c")` | hand-coded twin | table `est`, `se`, `fixed_x` flags, `df`, `logLik`, parameter count equal (1e-8 / 1e-6) |
| `fixed_x = TRUE` includes every dummy | twin with `fixed_x = TRUE` | same, and `glance()$fixed_x` lists `g_b, g_c` |
| `fixed_x = "g_b"` fixes one dummy, leaves `g_c` free | twin with `"g_b"` | same |
| `fixed_x = c("x","g")` | twin | same |
| fixed moments are those of the rows used | a factor with 10% NA (listwise deletion) vs the twin built on `complete.cases` rows | fixed rows equal the twin's, not the full-data moments |
| lavaan | `lavaan::sem(twin, fixed.x = TRUE)` | `npar`, `df`, chi-square 1e-5, estimates 1e-4 |
| refusal | `fixed_x = "zzz"`, and `"g"` when `g` is not on a regression's right side | the existing messages (name the variable) |

### T5 tests (`test-sem-factor-missing.R`, red first)

| Case | Oracle | Pass rule |
|---|---|---|
| NA in the factor drops the row once | twin with NA dummies | `n_obs`, `n_dropped`, the message count, estimates equal |
| NA in the outcome drops the row; the factor's dummies of that row go with it | twin | equal |
| a level present only in dropped rows | construct: level `c` appears only where `y` is NA | error names `g_c` and says the dummy is all zero (the existing singularity check, or a new message if it does not name the dummy) |
| an unused factor level (declared, never observed) | `factor(x, levels = c("a","b","c"))` with no `c` | same error, never a silent drop |
| weights | weighted fit vs weighted twin | equal; weights are not affected by the expansion |
| dummies come from the full column, not the kept rows | planted defect (`sem_mutate()` on `.sem_add_dummies`/the call site) | the "only in dropped rows" case changes its result and the test fails |

### Verification harness: `tests/sim/sem-factor-gate.R`

A gate script in the style of `sem-fixed-x-gate.R` (suppressMessages `pkgload::load_all`, `swap()` for namespace mutants, `SEEDS` env, a CSV in `tests/sim/results/`, exit status 1 on any failed run).

- **Cells:** n in {100, 400} x SEEDS (5) x factor levels in {2, 3, 5} x missingness {none, 10% in the factor, 10% in the outcome} x `fixed_x` in {FALSE, `"g"`}.
- **Per-run rule (a failing run fails the gate):** `twin` (estimates 1e-8, SEs 1e-6, logLik 1e-8, `n_obs` equals `complete.cases`), `lavaan` (estimates 1e-5, SEs 1e-3; `fixed.x` matched to the cell), `refit` (`mbco_sem(paths = c("a","b"))` statistic equals the twin's, 1e-6), `names` (dummy names and reference level equal the documented rule).
- **Planted defects (`MUTANT=`, each must exit 1):** `wrongref` (reference is the last level), `nofix` (`.sem_expand_fixed_x` returns its input), `halffix` (a factor in `fixed_x` fixes only its first dummy), `nomap` (`.sem_stored_factors` returns nothing, so refits lose the factor), `dropdummy` (the last dummy omitted from the table).
- **`afterdelete` is a unit test, not a gate mutant** (review finding): a level present only in dropped rows needs a purpose-built data set, so it lives in `test-sem-factor-missing.R` (T5). The gate's `fixed_x` dimension is {FALSE, `"g"`, `TRUE`, `c("x","g")`}; lavaan runs for FALSE and TRUE only (its `fixed.x` is logical), and the gate also checks the fixed `~~` rows against base-R ML moments.
- **Registration:** script-only first (as `sem-fixed-x-gate.R`, which is not in `gates.csv`). Registering in `run-gates.R` needs a verdict function and a `gates.csv` row; decide at close-out (T10), not now.

### Checks run per slice (T4 and T5), in this order

1. New test file red, then green (`devtools::test(filter = "sem-factor")`).
2. Frozen fixture bit-identical (`filter = "sem-frozen"`).
3. Gate: `SEEDS=2 Rscript tests/sim/sem-factor-gate.R` passes; each `MUTANT=` exits 1 (quote the output).
4. Full suite, counts quoted; the single known `tidy()` dotted-names failure is the baseline (it also fails on `dev` when the whole suite runs in one session).
5. `lintr::lint_package()` clean at 120 columns; spelling for new prose.
6. Guide guards: `filter = "guide|model-pages"` (error messages the pages quote must still be triggered).

### Agent skills and agents, per slice

| Step | Skill or agent | Use |
|---|---|---|
| Before writing tests | `agent-skills:test-driven-development` | red-green-refactor, one behavior per test, a planted defect per rule |
| Per slice | `agent-skills:incremental-implementation` | one vertical slice, commit when green |
| Test design review | `agent-skills:test-engineer` (agent) | read the T4/T5 test files and the gate: missing cases, vacuous assertions (the `r$chisq` mistake in T7 compared two NULLs) |
| After each slice | `agent-skills:code-reviewer` (agent) or the `code-review` skill | correctness pass on the diff; fix findings before the next slice |
| Slice boundary | `/codex:adversarial-review` | a challenge review on the slice, as run on T3 (it found the refit and duplicate-path gaps) |
| Docs (T10) | `agent-skills:context-engineering` | load only the spec rows a slice needs |

**Vacuous-assertion rule (new, from T7):** every equality test also asserts the compared value is non-NULL and finite, or compares against a literal that cannot be NULL.

## Checkpoints

- **After T2:** frozen fixture bit-identical, parity with the hand-coded fit. Stop and review if parity fails; every later slice builds on it.
- **After T7 (reached 2026-10-14):** refit contract works. This is the Codex-flagged risk, so review before T8-T10.
- **Close-out (pre-PR, per the e2e rule):** one live exercise that can fail, with transcript in the PR body: factor-covariate fit versus the hand-coded twin and lavaan, plus an `mbco_sem()` refit. Full suite counts, lint at 120 columns, strict `R CMD check` 0/0/0 (run before any release, not for the feature PR alone).

## Risks

| Risk | Mitigation |
|---|---|
| Pre-pass changes a numeric-only result | Returns the input objects unchanged when no factor is found; frozen fixture after every slice |
| A refit with the map and a model edited by the user | The map applies only to names absent from `data` whose dummies are all present; anything else errors as today |
| Hidden dependence on `fit@data` columns elsewhere (`bootstrap_mediation()`, `anova()`) | Grep consumers of `@data` in T7; add a nonparametric-bootstrap refit test |

## Out of scope

Group-averaged four-way (D4), ordered factors (D7), a factor treatment or mediator (D9), latent means (1.0).
