# Gap analysis: model pages and a cookbook menu for the medfit site

**Status:** analysis only, nothing built. Date 2026-10-10. Requested as: gap analysis for the docs, an item menu on the website for the cookbook, and one page for every model type that can be run, in subgroups, to show what the package can do.

## What can be run (verified by running each on 0.7.0 unless noted)

| Model type | Routes that run it | Verified |
|---|---|---|
| Simple mediation | `med()`, `fit_mediation()` (glm), `extract_mediation()` on `lm`/`glm`, lavaan, native | yes |
| Binary or other glm outcome | glm outcome model | yes (cookbook 3) |
| Binary or other glm mediator | `family_m = binomial()` | yes, `MediationData` returned |
| Treatment-by-mediator (four-way) | `lm`/`glm`, lavaan (`meanstructure = TRUE`), `engine = "regmedint"` | by tests |
| IPW / case weights, robust SEs | `fit_mediation(weights, se_type = "sandwich")`; native `sampling_weights` | yes (native) |
| Serial chain | `lm`/`glm` + `mediator_models`, lavaan | yes (lavaan) |
| Parallel | `lm`/`glm`, lavaan, `structure = "parallel"` | by tests |
| Joint (several mediators, products) | `lm` | by tests |
| Cluster 2-1-1 | `engine = "lmer"`, `extract_mediation()` on `lmer` pair; `se_type = "kr"`; cluster bootstrap | by cookbook 9 |
| Latent mediator, constraints, `:=` | `fit_sem()`, `engine = "native"`; `mbco_sem()` | yes |
| Native serial and parallel | `fit_sem()` then `extract_mediation(structure = )`. **Not** `fit_mediation(engine = "native")`: it takes one mediator and errors "Must have length 1". | yes |

## Where each is covered now

| Model type | Cookbook | Article | Dedicated page |
|---|---|---|---|
| Simple | 1, 2 | Getting Started, Extraction | no |
| Binary outcome | 3 | Extraction | no |
| Binary mediator | none | none | no |
| Weights and robust SEs | 4 | Getting Started, Methods | no |
| Serial | 5 | Extraction (lm and lavaan) | no |
| Parallel | 6 | Extraction | no |
| Interaction (four-way) | 7 | Extraction | no |
| Joint | 8 | Extraction, Methods | no |
| Cluster 2-1-1 | 9 | Extraction, Methods, Bootstrap | no |
| lavaan | 10 (simple only) | Extraction | no |
| regmedint engine | **none** | Getting Started prose, Extraction | no |
| Native latent mediator | 11 | Methods | no |
| Native constraints, `mbco_sem()` | 11 (snippet) | Methods, `?"medfit-syntax"` | no |
| Native serial or parallel | **none, in no article** | none | no |
| Native weights and sandwich | none | Methods only | no |
| Bootstrap kinds (parametric, nonparametric, plugin) | 8, 9 only | Bootstrap | no |

## Gaps

| # | Gap | Evidence |
|---|---|---|
| **M1** | No navigation by model. The cookbook is one 11-recipe page and the navbar has no entry for any recipe; the Articles menu lists 7 pages. | `_pkgdown.yml` navbar; `cookbook.qmd` has 11 H2 sections and no menu entry |
| **M2** | No page per model type. Every type shares an article section, so a reader cannot land on "serial mediation" or "latent mediator" directly. | the table above, column 4 |
| **M3** | Three model types have no worked example anywhere: the `regmedint` engine, a binary mediator, and native serial or parallel. | grep: `regmedint` 0 hits in the cookbook, `family_m` 0 hits in any article, no native serial or parallel text in any article |
| **M4** | A real limitation is undocumented: `fit_mediation(engine = "native")` takes one mediator, while `fit_sem()` plus `extract_mediation()` takes several. | the error above; `?fit_mediation` does not say so |
| **M5** | No capability matrix. Nothing shows structure by engine by standard-error type on one page, which is the showcase you want. | none exists |
| **M6** | `pkgdown` has no `articles:` index, so the site cannot group articles. Grouping needs one. | `_pkgdown.yml` has no `articles:` section |

## Proposed site structure

**Navbar:** a new **Cookbook** dropdown (the cookbook overview plus its 11 recipes, linked by anchor) and a new **Models** dropdown with the groups below. The old Articles menu stays.

**Models landing page:** the capability matrix (M5), one row per model type, each linking to its page.

| Group | Pages (one each) |
|---|---|
| **Single mediator** | 1 Simple mediation; 2 Binary and non-normal outcomes or mediators; 3 Treatment-by-mediator interaction (four-way); 4 Weights and robust standard errors; 5 The `regmedint` engine |
| **Several mediators** | 6 Serial chain; 7 Parallel; 8 Joint with products |
| **Clustered data** | 9 Cluster-randomized 2-1-1 (`lmer`, Kenward-Roger, cluster bootstrap) |
| **Structural equation models** | 10 lavaan fits; 11 Native: paths and defined parameters; 12 Native: a latent mediator; 13 Native: constraints and `mbco_sem()`; 14 Native: serial, parallel and weights |

Page template: when to use it; data; fit; effects; how to read them; assumptions and limits; related pages.

## Constraints and risks

- Each page is a Quarto article whose code runs at site build (the pkgdown workflow runs on PRs), so 14 pages add build time and 14 new places for the code to break. Keep chunks small and bootstraps at low `n_boot`.
- `lme4`, `pbkrtest`, `regmedint`, `lavaan` and `sandwich` are Suggests, so those pages need `eval:` guards as the cookbook already has.
- The refcard and cookbook consistency tests may need new cases, and the refcard needs rows for the new pages.
- Whether `pkgdown` can group Quarto articles under an `articles:` index is not verified. Verify with a one-page trial first.
- Page 5 (regmedint) and pages 6-8 depend on suggested packages being installed in CI, which they are for the existing articles.

## Decisions (2026-10-10, the author took the recommendations)

1. **Scope: two PRs.** PR 1 is the navbar menus, the Models landing page with the capability matrix, and the first 8 pages (single mediator and several mediators). PR 2 is the cluster and structural equation model pages (pages 9-14). PR 1 starts with a one-page trial of whether `pkgdown` groups Quarto articles under an `articles:` index (M6); if it cannot, group by navbar menu only.
2. **The Models landing page sits beside the cookbook**, not in place of it.
3. **The Cookbook menu lists all 11 recipes**, linked by anchor, plus the cookbook overview.

4. **Added 2026-10-10 (the author): the site home and Getting Started are rewritten in PR 1.** The home page is built from `README.md` (the repo has no `index.md`), so "the index file" is the README. Both become ADHD-friendly (a short "start here" decision table, one recommended path first, short sections, callouts for limits) and add the new features (the Models and Cookbook menus, cluster, native, `SEMFit`). The README edits overlap `docs/readme-outputs` (`7914291`, pushed, no PR yet), so that PR should merge first and this branch rebase onto it.

Rejected: one PR for all 14 pages (14 new places for build-time code to break in a single review) and a cookbook menu with a single entry (no gain over the Articles menu).

## Plan for PR 1

1. Trial: one new article with an `articles:` index entry; confirm the page groups in a local `pkgdown::build_site()` (clean-archive build, candidate library).
2. Navbar: Cookbook dropdown (overview plus 11 anchors) and Models dropdown (groups).
3. Landing page with the capability matrix (M5), including the M4 limit stated plainly.
4. Pages 1-8 from the template, each with chunks that run at build, `eval:` guards for suggested packages, and a low `n_boot`.
5. Rewrite `README.md` (site home) and `vignettes/articles/getting-started.qmd` for scannability and the new features, after `docs/readme-outputs` merges.
6. Refcard rows and consistency-test cases for the new pages; NEWS bullets; spelling and render gates; PR with quoted evidence.
