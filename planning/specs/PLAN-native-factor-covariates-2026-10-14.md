# PLAN: factor covariates in the native engine (0.11.0 headline)

| | |
|---|---|
| **Date** | 2026-10-14 |
| **Status** | T1-T8, T4b, T5b done on `feature/factor-covariates` (T8 `b2ab509`, 2026-10-15; Codex T6 review: approve); T9 (unit-level planted defects) and T10 (docs, NEWS, gate registration) pending; no PR until the final whole-branch Codex review |
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
| T4b | Fit-statistic parity for `fixed_x` (Codex review of T4): the lavaan test and the gate also compare parameter count and chi-square; see "T4b" | `tests/testthat/test-sem-factor-fixedx.R`, `tests/sim/sem-factor-gate.R` | npar, df and chi-square equal lavaan `fixed.x = TRUE` (1e-5) and, for the free fit, lavaan `fixed.x = FALSE`; all finite | test file; gate (`chisq` column) |
| T5 | Missing data (F7, D2): dummies from the full column before deletion; one new check, `.sem_check_dummy_support()`; see "T5 detail" and "T5 implementation and harness" | `R/sem-factor.R`, `R/sem-fit.R` (only if a test finds a gap), tests, gate | Row count equals `complete.cases` on the twin; an all-zero dummy is reported by name | `test-sem-factor-missing.R`; gate cells `miss` |
| T6 | Products (F5, D3, D4), the largest slice; see "T6 detail" | `R/sem-factor.R`, `R/sem-fit.R`, `R/extract-sem.R`, tests, gate | `g:m` fits and equals the hand-coded product twin and lavaan; refusals and the four-way message as specified | `test-sem-factor-product.R`; gate product cells |
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

### T5 implementation and harness (revised 2026-10-14, after probing the current behavior)

**Probe (2026-10-14, 150 rows, `m ~ x + g; y ~ m + g`):** works already: NA in the factor (10 rows dropped once, message correct), NA in the outcome, sampling weights. **Fails with an unnamed error** (`sample covariance matrix is singular (n = 109, p = 5)`): a level present only in dropped rows, a declared level no row has, a dummy that is 1 in every kept row, a constant logical. So T5's `R/` change is one check, not a rewrite.

**Design:** `.sem_check_dummy_support(map, data, x)` in `R/sem-factor.R`, called from `.sem_fit_syntax()` right after listwise deletion and before `.sem_sample()`. For every generated dummy in `ram$obs`: zero variance in the kept rows is an error naming the dummy, its level and factor, and the cause, read from the full-column dummy (pre-deletion `data`): the sum is 0 ("no row has this level"), positive and the kept column is all 0 ("the level occurs only in rows dropped for missing values"), or the kept column is all 1 ("every row the fit uses has this level"). Hand-coded dummies are not generated, so they keep today's message.

**Tests (`test-sem-factor-missing.R`, red first; written 2026-10-14, 6 of 11 red as expected):** NA in the factor, NA in the outcome, NAs on different rows (counted once), weights, level only in dropped rows, unused level, all-1 dummy, constant logical, an `mbco_sem()` refit after deletion, and the planted defect `afterdelete` (a character column, the pre-pass run on the complete rows only: the level disappears silently, so the test expecting the named error would fail). Test-design fix recorded: `logLik()` is undefined for a weighted fit, so the weighted case compares estimates, SEs and counts only.

**Harness (`sem-factor-gate.R`, new `lost` cell family):** per cell a character column whose last level occurs only where the outcome is NA, and a factor with a declared unused level; n in {100, 400} x K in {3, 5} x SEEDS. Rule: the fit errors and the message names the dummy (`g_<level>`) and contains the cause text; a run that fits is a failure. New mutant `afterdelete` (the pre-pass on the complete rows only) must exit 1 on the character-column cells; unit-level `nolevelcheck` (the support check returns nothing) must exit 1 on all `lost` cells.

**Agent skills:** `test-driven-development` (red first, one behavior per test, a planted defect), `incremental-implementation` (one check, one commit), `test-engineer` agent on the finished test file and gate cells, `code-reviewer` agent on the diff, a Codex adversarial review at the slice boundary.

**T5 as built (2026-10-14), after the test-engineer and code-reviewer agents:** the check also runs once before the zero-product branch grid (the grid swallows errors into "no branch converged") and honors weights (a level whose rows all have zero weight is named: "occurs only in rows with zero weight"); a zero-row result skips the check so the existing error stands. Scope limit, stated: **only generated dummies are checked**; a hand-coded constant 0/1 column keeps today's unnamed "sample covariance matrix is singular". Gate: 400 runs (360 main + 40 `lost` cells), seven mutants exit 1 (`afterdelete` fails exactly the character-column cells, `nolevelcheck` all `lost` cells).

**T5b (2026-10-14, from the Codex T5 review):** precheck rows use split product inputs; the harness gets a mutant-signature guard (a replacement function must keep the original's argument names) and a third lost-level kind, `branchprod` (zero-product constraint plus a product input that is NA exactly where the last level lives): gate 420 runs (360 main + 60 lost), all seven mutants exit 1, `nolevelcheck` fails only the 12 lost cells. A test-engineer agent reviewed the harness changes and found four more, all fixed: the precheck counted a latent that shares a name with a data column as an input (false "dropped rows" error; latents are now excluded; test with that model, red before the fix); the `branchprod` cell and test were unanchored, so they would still pass if the precheck were removed (the "no branch converged" wrapper contains the same message; both regexes now start with `^dummy`); the `swap()` guard compared argument names only (now `identical(formals())`, defaults included); the `wrongref` mutant crashed in the gate's moment check instead of failing on its own signature (the check now tests that the names exist). Coverage added: a product input also used in another equation, weights, and `fixed_x` with a zero-product constraint.

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

## Review log (Codex adversarial reviews on the branch)

| Review | Finding | Verdict | Action |
|---|---|---|---|
| T3 code | `mbco_sem()` cannot refit a factor fit (high) | Confirmed; was T7 | Fixed in `d6ca3c2` (factor map in `internals$factors`) |
| T3 code | `y ~ g + b*g_b` duplicates a path (medium) | Confirmed | Fixed in `d6ca3c2` (D14/F3b) |
| T4 results | `g:m` rejected instead of expanded (high) | **Known, scheduled as T6, not a regression**: the pre-pass skips colon terms on purpose, and the user sees `the product 'g:m' needs numeric variables, but g is not numeric` | No PR until T6 lands; T6 detail below. The interim message is accurate but does not point to the rule; T6 replaces it |
| T5 | Zero-product precheck missed product inputs (medium) | **Confirmed by reproduction** (the new test failed with "no branch ... converged" before the fix). The precheck chose complete rows from `lhs`/`rhs` names; `z:w` contributed neither `z` nor `w`, so a level lost to an NA in `z` passed the check, and branch fits carry no factor map | **T5b:** names split at the colon in the precheck; test `the zero-product precheck sees product inputs`; gate cell kind `branchprod` |
| T5 | `nolevelcheck` mutant failed for the wrong reason (medium) | **Confirmed.** The replacement had three arguments, the call four, so every cell died on "unused argument". The mutant proved nothing about the check | **T5b:** the mutant takes `weights = NULL`; `swap()` now refuses a replacement whose argument names differ from the original (harness guard, demonstrated); verified the mutant now fails only the lost cells with the unnamed "singular" error |
| T4b | `g:m` still fails (high), now noted for a model with **no bare `g` term** | **Repeat of the T4 finding, still scheduled as T6.** One new detail the T6 plan did not state: a factor that appears only inside a product (`y ~ m + g:m`) is not found by the pre-pass, which skips colon names when it detects categorical columns | T6 detail gains the product-only case and a test for it; the "no PR until T6" rule stands |
| T4 results | lavaan check omits npar and chi-square (medium) | **Confirmed.** The T4 detail table promised "npar, df, chi-square 1e-5"; the test checks df and regression estimates only, and the gate checks estimates and SEs | T4b (next, before T5) |

## T6 as built (2026-10-14)

`.sem_row_expansion(rhs, map)` (new) is the single place a row's categorical sides become terms: `g` gives its dummies, `g:m` one canonical product per dummy (`.sem_product_name(d, other)`), two categorical sides is an error that suggests the dummy-reference form (`g_b:h_v`). The table expansion, the modifier check and the stored-map rewrite all use it. Detection splits every right-hand name at the colon, so a product-only factor (`g:x`, no bare `g`) is found; such a factor is flagged `product_only` in the map: its dummies are not model variables, so the stored-map check skips them (the product columns are in the stored data), and `fixed_x = "g"` gets a message that says so. `.sem_check_dummy_support()` now reads the dummies from the full column at the kept rows (it takes `keep`, not the model columns), so a product-only dummy made constant by an NA in the other side, or by zero weights, is named. A latent named like a dummy is a collision error. D4: `extract_mediation()` on a factor product refuses with "the effects differ by `g`".

Reviews: test-engineer and code-reviewer agents, both flagged the product-only path (constant check skipped, `mbco_sem()` refit failing with a misleading missing-dummy message, `fixed_x` message), plus loose regexes, a non-independent OLS oracle in the gate, missing dummy-reference, reversed-spelling, logical and stored-map-direct tests: all fixed. Gate: 680 runs (360 main, 80 lost incl. `productonly`, 240 `prod` incl. the product-only form `go`, a `refit` rule and an OLS oracle built from the expected terms); nine mutants exit 1 (`noncanon`, `oneprod` new). Old tests whose behavior changed on purpose were updated (a factor in a product no longer errors; modifier wording).

## T4b (fit-statistic parity)

1. Test: for `fixed_x = TRUE` and for the free fit, compare `length(f@theta)`, `f@df` and `glance(f)$statistic`/chi-square with lavaan (`fitMeasures(l, c("npar","df","chisq"))`, 1e-5 relative); assert each is finite (non-NULL rule).
2. Gate: a `fitstats` column on the lavaan-run cells (free and all modes), same tolerance, in the pass rule; confirm the clean run and that `wrongref`/`dropdummy` still exit 1.
3. Check what the fixed-x gate already proves for lavaan chi-square (`sem-fixed-x-gate.R`, "lavaan" rule) so the new rule does not weaken it.

## T6 detail (factor products)

- **Detection:** categorical columns are also found inside product names (`g:m`, `m:g`, `g_b:m`), so a factor that has no bare term (`y ~ m + g:m`) still expands. Only the two sides of a product are split at the colon; any other colon is a parse error already.
- **Pre-pass:** a product rhs `a:b` where one side is a categorical column (or a `<column>_<level>` reference) expands to one product per dummy, each rewritten through `.sem_product_name()` (`g_b:m`, `g_c:m`); the product-materialization step then builds numeric columns as today. Both sides categorical (`g:h`, `g:g`) is an error naming both (D3).
- **Order:** expansion happens before `.sem_complete()` with the rest of the pre-pass; rules 8 and 9 (`.sem_check_product_parsed()`/`_completed()`) see only numeric product names, and their messages name the dummy product.
- **Stored map:** a product row expanded from a factor is recorded so `mbco_sem()` refits rewrite it (the T7 contract extends to product rows); `fixed_x` naming a factor also fixes the dummies that appear only in products.
- **Four-way (D4):** `extract_mediation(<SEMFit>, decomposition = "four_way")` with a `g:m` product keeps refusing, with a message that says the effects differ by `g`.
- **Tests (red first):** hand-coded product twin (estimates, SEs, logLik); lavaan on the twin; `g:m` in the mediator and in the outcome equation; **`g:m` with no bare `g` term** (and with it); `m:g` spelling equals `g:m`; both-sides-categorical error; `g:h` error; the model test is `NA` for an endogenous product factor exactly as for hand-coded dummies (`glance()`); `mbco_sem()` refuses as for hand-coded; planted defect: product expanded without the canonical name (a duplicate `m:g_b` and `g_b:m`).
- **Gate:** product cells (a `g:m` model against the twin, 2 and 3 levels, one missingness pattern) with a mutant that skips the canonical name.
- **Skills:** the same loop as T4: `agent-skills:test-driven-development`, `test-engineer` review of the tests, `code-reviewer` on the diff, a Codex adversarial review at the slice boundary.

## Checkpoints

- **After T2:** frozen fixture bit-identical, parity with the hand-coded fit. Stop and review if parity fails; every later slice builds on it.
- **After T7 (reached 2026-10-14):** refit contract works.
- **Before any PR:** T6 done (the spec headline needs factor products). T4b is done (2026-10-14). This is the Codex-flagged risk, so review before T8-T10.
- **Close-out (pre-PR, per the e2e rule):** one live exercise that can fail, with transcript in the PR body: factor-covariate fit versus the hand-coded twin and lavaan, plus an `mbco_sem()` refit. Full suite counts, lint at 120 columns, strict `R CMD check` 0/0/0 (run before any release, not for the feature PR alone).

## Risks

| Risk | Mitigation |
|---|---|
| Pre-pass changes a numeric-only result | Returns the input objects unchanged when no factor is found; frozen fixture after every slice |
| A refit with the map and a model edited by the user | The map applies only to names absent from `data` whose dummies are all present; anything else errors as today |
| Hidden dependence on `fit@data` columns elsewhere (`bootstrap_mediation()`, `anova()`) | Grep consumers of `@data` in T7; add a nonparametric-bootstrap refit test |

## Out of scope

Group-averaged four-way (D4), ordered factors (D7), a factor treatment or mediator (D9), latent means (1.0).
