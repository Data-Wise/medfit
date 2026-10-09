# SPEC: refcard and cookbook for medfit

**Date:** 2026-10-08 · **Status:** APPROVED 2026-10-08 (author; Q1 to Q3 resolved as recommended) · **Branch:** `dev` (this spec is doc-only; implementation needs a `feature/*` worktree)
**Origin:** `/do gap analysis of docs, vignettes, and cookbooks and refcard` (2026-10-08), then "spec this".
**Depends on:** PR #93 (merged 2026-10-08, `8c9e45a`): `ClusterMediationData` is in the extraction, introduction and bootstrap articles, so the cookbook can link to those sections.
**Template:** `~/projects/r-packages/mediation-planning/standards/adhd/REFCARD-TEMPLATE.md` (one page, tables, no explanations, grouped by task, most-used first).

---

## 1. Problem

Gap analysis of `dev` (2026-10-08): medfit has 19 exports, 6 mediation classes, 2 fitting engines, 3 standard-error types and 3 bootstrap methods, documented in five feature-organized articles and 59 Rd pages. There is **no refcard and no cookbook** in this repo or in the other r-packages. The consequences:

- A returning user who knows the package has nowhere to look up "which call gives me X" without reading an article.
- A new user with a task ("I have `lmer` fits and a school-level treatment") must infer the path from feature-organized prose.
- The accessors for the newest class (`paths()`, `pm()`, `glance()`, `decompose()` on `ClusterMediationData`) appear only in `methods.qmd`.

Everything else found by the gap analysis is already fixed (the 2026-09-24 audit) or is in flight (#93, and the roadmap and `CLAUDE.md` status text, planned for the 0.6.0 release prep). Those are out of scope here.

## 2. Non-goals

- No new exports, no R code changes, no API changes.
- No printable PDF build and no print stylesheet; "one page" is a content budget (§3, D2), not a layout engine.
- No bundled cluster example dataset. The cookbook simulates inline, as `methods.qmd` does. (Open question Q1.)
- No tutorial-style teaching content (the template separates TUTORIAL from REFCARD).
- No change to what ships in the CRAN tarball: articles stay under `.Rbuildignore`, as the existing ones are.
- The refcard does not explain; it points at the article that does.

## 3. Decisions

| # | Decision | Recommendation and reason |
|---|---|---|
| D1 | Format and location | `vignettes/articles/refcard.qmd` and `vignettes/articles/cookbook.qmd`. Articles evaluate at site build (`eval: true`), so a stale call fails the pkgdown job, the same guard the other articles have. A plain `.md` would drift silently. |
| D2 | Refcard size budget | At most about 120 rendered lines, tables only, descriptions start with a verb and run 2 to 4 words, no articles, no end punctuation (template rules). Grouped by task, most-used first. |
| D3 | Refcard sections | (a) I have X, run Y; (b) fit and extract; (c) effect accessors; (d) standard errors and intervals; (e) bootstrap; (f) class to effect formulas; (g) warnings and errors, and what to do. One live chunk at most (a 6-line quick-start), so the card stays a card. |
| D4 | Cookbook shape | 10 recipes, each: a one-line "when", at most 15 lines of evaluated code, the printed result, and a link to the article that explains. No prose beyond that. |
| D5 | Navbar | New menu group "Quick Reference" with Refcard and Cookbook, above "Detailed Guides" in the Articles menu. |
| D6 | Drift guard | `tests/testthat/test-refcard-coverage.R`: every export and every class name must appear in `refcard.qmd`. It skips when the file is absent (articles are not in the tarball). A planted-defect companion proves it fails when a name is removed. The formulas in the class table are checked against `methods.qmd` by string. |
| D7 | Data for recipes | `mediation_demo` for every recipe except the cluster one, which uses the 40-school simulation from `methods.qmd` (same seed, so its numbers match: NIE 0.2093). |
| D8 | Delivery | Two PRs: PR 1 refcard and guard test, PR 2 cookbook. The refcard is the highest-value gap and is independent of recipe writing. |

### Refcard content (D3), draft

| Section | Rows |
|---|---|
| I have X, run Y | one-line analysis: `med()`, `quick()` · fitted `lm`/`glm`: `extract_mediation()` · formula and data: `fit_mediation()` · `lmer` fits, cluster treatment: `extract_mediation()` or `fit_mediation(engine = "lmer", cluster = )` · `lavaan` fit: `extract_mediation()` |
| Which class | simple, serial, parallel, interaction, joint, cluster: the structure and the call that returns it |
| Effects | `nie()` `nde()` `te()` `pm()` `paths()` `decompose()` `joint_effects()`; `nie(type = "total")` for serial |
| Tables | `tidy(type = "effects")` `tidy(type = "paths")` `glance()` `confint(parm = )` `coef()` `vcov()` `nobs()` |
| Standard errors | `se_type = "model"`, `"sandwich"` (weights), `"kr"` (cluster, REML only) |
| Bootstrap | `method = "parametric"`, `"nonparametric"`, `"plugin"`; `cluster =` for whole clusters |
| Formulas | per class: NIE, NDE, TE, and the cluster own and spillover split (the formulas in `methods.qmd`) |
| Warnings | few clusters (J < 25 model, J < 10 any), own/spillover gap, dropped bootstrap draws, delta-method note |

### Cookbook recipes (D4), draft

| # | Recipe | Code path |
|---|---|---|
| 1 | One-line mediation | `med()`, `quick()` |
| 2 | I have `lm` fits | `extract_mediation()`, `nie()`, `confint(parm = "effects")` |
| 3 | Binary outcome | `glm(family = binomial)`, logit-scale caveat |
| 4 | Weights and robust SEs | `fit_mediation(weights =, se_type = "sandwich")` |
| 5 | Two mediators in a chain | serial: `nie()`, `nie(type = "total")`, `te()` |
| 6 | Two mediators side by side | parallel: `paths()`, summed NIE |
| 7 | Treatment-by-mediator interaction | four-way: `decompose()`, `m_star` |
| 8 | Many mediators with products | joint: `joint_effects()` as a bootstrap statistic |
| 9 | Cluster-randomized trial | `fit_mediation(engine = "lmer")`, `se_type = "kr"`, `decompose()`, cluster bootstrap |
| 10 | I use lavaan | `extract_mediation()` on a lavaan fit, same effects |

## 4. Implementation surface

| File | Change |
|---|---|
| `vignettes/articles/refcard.qmd` | new (PR 1) |
| `vignettes/articles/cookbook.qmd` | new (PR 2) |
| `_pkgdown.yml` | navbar group "Quick Reference" (PR 1 adds Refcard, PR 2 adds Cookbook) |
| `tests/testthat/test-refcard-coverage.R` | new (PR 1) |
| `inst/WORDLIST` | additions as the spell check requires |
| `README.md` | one link line to the refcard and cookbook, **added in the 0.6.0 release prep, not in the PRs**: the page 404s until the site deploys, which fails `urlchecker` |
| `NEWS.md` | none (docs only) |

## 5. Tasks

- [x] **T0: Approve this spec** *(done 2026-10-08: approved; Q1 no bundled dataset, Q2 `med()`/`quick()` stay simple-structure, Q3 one screen of tables. The spec ships inside PR 1.)*
- [x] **T1: Refcard** *(done 2026-10-08 on `feature/refcard`: `refcard.qmd` (about 120 lines), navbar group. README link deferred to release prep (above). The E2E trial found a trap: `fit_mediation(engine = "lmer")` errors with an obscure lme4 message when the formulas contain `(1 | id)`; the card now says plain formulas. Follow-up candidate: a clear error in `fit_mediation()`.)* Write `refcard.qmd`, navbar entry. Gate: renders, one evaluated chunk passes, spell, URL, `check_pkgdown()`.
- [x] **T2: Drift guard** *(done 2026-10-08: 5 expectations pass; mutation (rename `joint_effects` in the card) fails the test; the guard also caught a real gap on first run, `BootstrapResult` missing from the card, now added.)* The coverage test and its planted defect. Gate: passes; fails with a name removed (mutation check, restored after).
- [ ] **T3: PR 1** with T1 and T2. Docs-tier evidence plus the strict CRAN check, as for #93.
- [ ] **T4: Cookbook** (about 90 minutes). Ten recipes, evaluated at site build. Gate: every recipe prints without error or unexplained warning; the cluster recipe matches `methods.qmd` (NIE 0.2093).
- [ ] **T5: PR 2** with T4 plus the navbar entry.

## 6. Acceptance criteria

1. The refcard fits the D2 budget, and a reader can answer "which call gives me the NIE for each class" and "which SE type for weights or few clusters" from it without opening an article.
2. `refcard.qmd` names every export and every class (D6 test), and the test fails when a name is removed.
3. Every cookbook recipe evaluates at site build; a renamed argument fails the pkgdown job.
4. The cluster recipe's numbers equal `methods.qmd`'s (same seed).
5. Strict CRAN check 0/0/0, spelling and URL checks clean, `pkgdown::check_pkgdown()` clean, CI green.
6. **E2E (fresh-context trial, required by `e2e-before-pr.md`):** a clean agent is given only the refcard and the task "treatment assigned to schools, `lmer` fits, give me own and spillover effects with a Kenward-Roger interval". It must reach `fit_mediation(engine = "lmer", se_type = "kr")` and `decompose()` unaided. Transcript quoted in PR 1's body; a failure blocks the PR and sends the refcard back for revision.

## 7. Open questions

| # | Question | Recommendation |
|---|---|---|
| Q1 | Bundle a small cluster dataset (`mediation_cluster_demo`) so cookbook recipe 9 and the articles stop re-simulating? | **No for now.** It is a data-raw script, an Rd page and a `LazyData` change for a docs gap. Revisit if the cluster example appears in a fourth place. |
| Q2 | Should `med()` and `quick()` accept cluster data? (gap analysis item 5) | **Out of scope here.** The refcard states they are for the simple structure. Decide in a separate grill if wanted. |
| Q3 | Refcard length: one screen or one printed page? | **One screen's worth of tables (D2).** There is no print build, so a printed-page budget is unverifiable. |
