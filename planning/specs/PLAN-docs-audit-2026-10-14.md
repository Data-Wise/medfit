# PLAN: documentation and website audit (medfit 0.10.0)

**Date:** 2026-10-14 | **Audited:** `origin/main` = released 0.10.0 (tag `v0.10.0`, `157a1db`) and the live site
https://data-wise.github.io/medfit/ | **Status:** plan only; nothing was fixed. The only file created is this one.

`planning/` is Rbuildignored (`^planning$`), so this file does not ship in the tarball.

---

## 1. Summary and method

The site is healthy: every page is served, no internal link is dead, no rendered math is broken, and the examples
and the doc-drift tests pass. The problems are **stale claims** (a handful that mislead), **one dead anchor repeated
on four pages**, and **0.8.0-0.10.0 changes that never reached the guides for CRAN 0.3.2 upgraders** or the
native-engine limits.

Top findings, by user impact:

1. `guide-changes` (the CRAN 0.3.2 upgrade page) omits the 0.9.0 rename of every `tidy()`/`glance()` column and the
   `conf.int` argument (`std.error` to `std_error`, and so on), which breaks 0.3.2 code. Confirmed against the `v0.3.2` tag.
2. Four pages link to `https://data-wise.github.io/medfit/#installation`; the home page anchor is `#install`. The
   link lands on the home page top, not on the install section.
3. README says the two CRAN bugs were fixed in 0.7.0; NEWS and `guide-changes` say 0.5.0.
4. `guide-troubleshooting` says `nobs()` reports used rows "in the development version" and cites 0.7.0; the fix shipped in 0.8.0.
5. `models.qmd` capability table lists no native route for the treatment-by-mediator row (0.10.0 added it).
6. `AIC()`/`BIC()` rank a product fit against a no-product fit without warning, and no page says the likelihoods are not comparable.
   Reproduced: 3934.7 against 2994.1 on `mediation_demo` for the same outcome.
7. `guide-troubleshooting` has no 0.10.0 product-term messages, no "not nested", boundary, "starts disagree" or "no start converged" rows.
8. The native book (5 chapters) is linked from the menu and index only; no guide, tutorial, quickstart or model page links to it, and no chapter covers products.
9. README "3,300+ tests" is stale (full suite now 5,663 expectations); the README roadmap link goes to `planning/medfit-roadmap.md`, last updated 2026-10-10 (0.7.0).
10. Glossary has no entries for mean structure, `fixed_x`, product term, `anova()`, conditional log likelihood; its MBCO row says "minimum of two" (now k paths).

**Method.** Source: read README, NEWS (0.5.0-0.10.0), CLAUDE.md, DESCRIPTION, `_pkgdown.yml`, all 35 `vignettes/articles/*.qmd`
(targeted greps for versions, "planned", "not yet", "refused", counts; full reads of home/README, Getting Started,
Models, Reference Card, Cookbook headings and recipes 7 and 17-18, Introduction, Extraction (native section),
`model-native`, `model-interaction`, `native-guide`, `native-quickstart`, `native-tutorial`, `lavaan-comparison`,
`guide-changes`, `guide-troubleshooting` native section), roxygen for `fit_sem`, `extract_mediation`, `SEMFit-methods`, `sem-syntax-help`.
Live: fetched all 69 sitemap URLs with `curl`, parsed every internal `href` and fragment, checked all 221 external
links, and loaded 10 pages in a browser to count MathJax containers and errors. Ran the repo's own checks (section 7).

**Verified live vs source-only**

| Area | Live | Source only |
|---|---|---|
| All 69 sitemap pages return 200 | yes | |
| Internal links (69 distinct targets) and fragments | yes | |
| External links (221) | yes (403/503 from bot blocking only, none 404) | |
| Version strings: nav badge `0.10.0`, home What's New, Getting Started, cookbook prerequisites, NEWS top entry | yes | |
| Cookbook has 18 sections, Reference index matches `_pkgdown.yml` (25 topics) | yes | |
| Math rendering: `te`, `methods`, `native-book-1` to `5`, `guide-glossary`, `refcard` (0 errors, 1,081 math spans site-wide in static HTML) | yes (browser) | |
| Rendered chunk output (numbers in tables, `#>` blocks) | spot checks only | CI renders every page at build; tests pin many numbers |
| Search box, r-universe badge, dev-version docs, mobile layout | no | no |
| Prose of the 14 model pages, 5 book chapters, `methods.qmd` beyond native sections | | grep for stale phrases only, not read in full |

---

## 2. Currently accurate (do not re-edit)

- **Versions and install:** DESCRIPTION 0.10.0 / Date 2026-10-14; README install block; home What's New table (0.4.0-0.10.0);
  nav badge; Getting Started, Reference Card, Cookbook, Troubleshooting prerequisite notes; CRAN 0.3.2 statements.
- **NEWS.md** 0.10.0 to 0.2.0 render live; the 0.9.0 "planned for 0.10.0" sentence is a historical entry (correct as history).
- **`_pkgdown.yml`:** `check_pkgdown()` clean; reference index lists all 22 exports plus `medfit-syntax`, `SEMFit-methods`, `tidy_s7_object`;
  Models (14 pages), Guides (13 entries), Cookbook (18 anchors, all resolve live), Articles menus match the articles index.
  All 35 articles are in the live articles index.
- **Cookbook** count (18) in `cookbook.qmd:15`, `getting-started.qmd:192`, README:283, menu and `test-cookbook-consistency.R`: consistent.
- **Native pages:** `model-native` (intercepts, product table, limits), `native-guide`, `native-quickstart`, `native-tutorial` (step 9),
  `lavaan-comparison` (product and `fixed_x` rows), `model-interaction` native section, `extraction` native section,
  `methods` native sections (mean structure, fixed-x, products): consistent with 0.10.0 behavior and the code messages quoted
  (`test-model-pages-messages.R`, `test-guide-*.R`, #195 pins the product tables).
- **Rd/roxygen:** `man/` is byte-identical to a fresh `roxygen2::roxygenise()` (no drift); examples run (`devtools::run_examples(run_donttest = TRUE)` ok);
  `?fit_sem`, `?extract_mediation` (SEMFit method and four-way), `?SEMFit-methods`, `?"medfit-syntax"` match the code.
- **CLAUDE.md** engines table, "Native product term and four-way" and status paragraph are current (0.10.0). AGENTS.md has no version claims.
- Spelling, URLs, pkgdown check: clean (section 7). `inst/WORDLIST`: no change needed.

---

## 3. STALE

| # | Page, line or anchor | Says | True now | Evidence |
|---|---|---|---|---|
| S1 | `vignettes/articles/getting-started.qmd:18`, `guide-changes.qmd:28`, `cookbook.qmd:21`, `refcard.qmd:17` | link to `.../medfit/#installation` | home anchor is `#install` (`<h2 id="install">`); `#installation` does not exist | live `index.html` ids; link crawler: `MISSING-ANCHOR .../medfit/#installation` from 4 pages |
| S2 | `README.md:49-50` | "serial `te()`/`pm()` and `confint()` path rows ... are fixed in 0.7.0" | fixed in 0.5.0 | NEWS 0.5.0; `guide-changes.qmd:27`; `models` table row 0.5.0 in README:30 |
| S3 | `guide-troubleshooting.qmd:96` | "`nobs()` reports the rows used in the development version; 0.7.0 reported every row" | `nobs()`/`n_obs` count used rows since 0.8.0 (NEWS 0.8.0 "Bug fixes", #138); there is no "development version" on the live site | NEWS.md:264-268; live page says "development version" |
| S4 | `models.qmd:45` (capabilities table, "Treatment-by-mediator" row) | engines: `glm`, `regmedint`, lavaan | also native `fit_sem()` with `x:m` (0.10.0) | NEWS 0.10.0; `model-interaction.qmd:23`; `refcard.qmd` row 6 already says so |
| S5 | `README.md:302` | "3,300+ tests" | 1,230 `test_that` blocks, 5,663 expectations, 0 failed | full suite run (section 7) |
| S6 | `README.md:305,339`, `planning/medfit-roadmap.md:4-6,27` | "see the roadmap for the detailed development plan"; roadmap says "current 0.7.0", Last Updated 2026-10-10 | 0.10.0; 0.8.0-0.10.0 and the mean-structure/product work absent | roadmap header; README links to it on GitHub |
| S7 | `guide-glossary.qmd:104` | MBCO = "the minimum of two likelihood-ratio tests" | `mbco_sem(paths = )` takes k paths (0.8.0) | NEWS 0.8.0; `native-guide.qmd:5` |
| S8 | `extraction.qmd:913-918` ("Design for Extensibility") | lists "Moderated mediation" and "Multiple treatments" as future, "extend" `fit_sem()` for latent variables | `fit_sem()` latent variables already ship (0.7.0); the X-by-M four-way shipped in 0.4.0, so reread the "Moderated mediation" wording | NEWS 0.4.0, 0.7.0 |
| S9 | `extraction.qmd:638` | "Non-Gaussian outcomes are not yet supported and raise an informative error" | the real rule is identity link and Gaussian; message is `Four-way decomposition requires the identity link` | `guide-changes.qmd:61`; `guide-troubleshooting.qmd:57` |
| S10 | `bootstrap.qmd:610-624` | "Bootstrap infrastructure is **complete**" with a "future" BCa line and a status checklist | fine as a roadmap list but reads as internal status on a user page; no cluster/`cluster =` bullet (0.6.0) | `refcard.qmd` bootstrap table lists cluster resampling |
| S11 | `_pkgdown.yml:214` ("ADHD-friendly entry points"), `introduction.qmd:18` ("ADHD-friendly API") | internal workflow jargon on the public site | author's call (see section 6) | |
| S12 | `_pkgdown.yml:258` | "Print and summary methods for medfit classes" | the section lists `tidy_s7_object` and `SEMFit-methods` (tidy/glance, anova, confint, logLik) | live Reference index |
| S13 | `tasks/plan.md:3`, `tasks/todo.md:3` | "unreleased, DESCRIPTION still 0.8.0" | 0.9.0 and 0.10.0 released; CLAUDE.md points to these as "the closed fixed_x plan" | `DESCRIPTION`; CLAUDE.md:588 |
| S14 | `.STATUS` first line `version:` | "0.9.0 ... `dev` carries the 0.10.0 product term, unreleased (DESCRIPTION still 0.9.0)" | 0.10.0 released (tag `v0.10.0`) | `git tag --points-at origin/main` |
| S15 | `CLAUDE.md:44` (About) | "Fitting: ... with the `glm` and `regmedint` engines" | also `engine = "lmer"` (0.6.0) | CLAUDE.md engines table, line 536 |
| S16 | `R/fit-sem.R:59` roxygen (`[anova()]` link) | links `[anova()]` | roxygen warns: topic "anova" is in `stats` and `lavaan`; Rd link may resolve to the wrong help page | `roxygenise()` log: `fit-sem.R:59: @param Topic "anova" is available in multiple packages` |

Stale items already handled by CLAUDE.md or NEWS history (the "until 0.10.0" sentence in NEWS 0.9.0, the "latent means are planned for a later release" error text) are **not** stale: the latter is the current message, quoted by tests.

---

## 4. GAPS

| # | Feature or page | Where it should live | Evidence |
|---|---|---|---|
| G1 | 0.9.0 rename `std.error`/`p.value`/`conf.low`/`conf.high` to snake_case and `conf.int`/`conf.level` to `conf_int`/`conf_level` (old args warn) | `guide-changes` "Numbers that change" or a new "Names that changed" table | CRAN 0.3.2 `tidy()` used `std.error`, `conf.int` (`git show v0.3.2:R/methods-tidy.R`); `guide-changes` has no such row; NEWS 0.9.0 "Names without dots" |
| G2 | 0.8.0 `nobs()`/`n_obs`/`med()` count used rows; `fit_mediation()` drops incomplete rows | `guide-changes` row (and troubleshooting S3) | NEWS.md:264-278 |
| G3 | 0.9.0 lavaan four-way fixes (SE of INTref/NDE/TE too small with a mediator covariate, 0.037 against 0.095; wrong decomposition for a treatment product in the mediator equation; unweighted covariate means with weights) | `guide-changes` "Numbers that change" + "Calls that now stop with an error" | NEWS 0.9.0 "Behavior changes"; `guide-changes` has only the 0.5.0 covariate-means row |
| G4 | Native product-term errors, warnings and the NA model test | `guide-troubleshooting` "Native engine" table | the table has 7 rows, none for `x:m`; messages are in `model-native.qmd:149-170` and `?"medfit-syntax"`; `fit_sem()` warns once for NA test and once without `se_type = "sandwich"` |
| G5 | `anova()` "not nested", boundary-null warning, `n_starts` "starts reached different optima" warning, "no start converged", `latent means are planned` | `guide-troubleshooting` "Native engine" | NEWS 0.8.0, 0.9.0; none of these strings appears in `guide-troubleshooting.qmd` |
| G6 | **`AIC()`/`BIC()` across fits with and without a product are not comparable** (the product column enters the joint likelihood); multi-fit `AIC()` does not refuse, unlike `anova()` | Limits in `model-native.qmd`, `native-guide.qmd`, `model-interaction.qmd:138-140`; roxygen `?SEMFit-methods` (R/methods-sem.R:46-49) and `?"medfit-syntax"` (R/sem-syntax-help.R:112) | probe: `AIC(f1, f0)` gives df 13 / AIC 3934.7 against df 9 / AIC 2994.1 for the same outcome; docs say only "`logLik()`, AIC and BIC stay defined"; .STATUS lists "AIC()/BIC() still rank fits that anova()/mbco_sem() refuse" as open |
| G7 | Known limit: an intercept sharing a label with a path | `model-native.qmd` Limits (after confirming) | .STATUS (#183 follow-ups) says it errors in `.sem_center_map()`. **Not reproduced as a plain error** on `origin/main`: two shared-label models (`a*1` on `mediator1` with the path `a`; `a*1` on `outcome` with the path `a`) crossed with 10 paths (linear `<` and `==` constraints, `cp == a*b`, `a*b > k`, `weights` with sandwich, sandwich, `fixed_x`, `anova()`, `mbco_sem()`) all fit, which covers the fit, gate and polish call sites of `.sem_center_map()`. The one failure: the outcome-intercept variant on data shifted by +500 (mean/sd about 500) stops with "no start converged (5 tried) ... Hessian is nearly singular", while the same data without a shared label is within the documented scale limits; the chapter 2 "refused shift" table (`native-book-2-scale.qmd:485-519`) may be this limit Plan G12 (GRILL) says "allowed". Documented only inside `native-book-2-scale.qmd:239,485-519` |
| G8 | Native mean structure has no cookbook recipe (observed intercepts, `y ~ 1`, `meanstructure =`) | cookbook recipe 19, Reference Card row | recipes 11-18 cover latent, constraints, `anova()`, `fixed_x`; intercepts are only in `model-native#intercepts` and book 1 |
| G9 | Reference Card: no row for `y ~ 1`/`meanstructure`, `AIC()`/`BIC()`/`logLik()` on `SEMFit`, or native warnings | `refcard.qmd` "I have, run" and "Warnings" tables | `test-refcard-coverage.R` only checks that export names appear as substrings, so it cannot catch missing rows |
| G10 | Native book: not linked from any guide or model page; no chapter on products/four-way (0.10.0) | `native-guide`, `native-tutorial`, `native-quickstart`, `model-native` "Related"; optional chapter 6 | `grep -l native-book vignettes/articles/*.qmd` returns only the four chapters; `methods.qmd#products-and-observed-information` is the only derivation |
| G11 | Glossary: mean structure, intercept, `fixed_x`, product term (`x:m`), nested comparison (`anova()`), conditional log likelihood, canonical name `m:x` | `guide-glossary.qmd` "The native engine" table | table lists `SEMFit`, label, `:=`, `=~`, constraint only |
| G12 | Getting Started "Where next" omits cluster, lavaan and native rows; Introduction native bullet omits means, `fixed_x`, products | `getting-started.qmd:160-175`, `introduction.qmd:22,292-310` | the engine table lists them, the "I have" table does not |
| G13 | `guide-changes` "What is new" lacks a dependency line for 0.9.0/0.10.0 and the `x:m` supported-class limits are only in model-native | `guide-changes` | NEWS 0.10.0 "Supported class for a product (limits)" |
| G14 | The native model docs state no sample-size or runtime guidance for `fixed_x` beyond NEWS timing | optional, `native-tutorial` step 9 | NEWS 0.9.0 (561 to 65 parameters, 5 s to 0.2 s) |
| G15 | Absolute-URL links are not covered by the link tests; `test-native-book.R` and `test-guide-pages.R` regexes match only relative `](x.html#...)` links and never check fragments | extend the guards (task 1.3) | the `#installation` break (S1) passed all tests |

---

## 5. Tasks (batches ordered by user impact)

Conventions: sizes XS (under 15 min), S (under 1 hour), M (1-3 hours). "Verify" commands run from the repo root; set
`NOT_CRAN=true` for `devtools::test()`. Content PRs branch from `dev`. The site is GitHub Pages (`pkgdown.yaml`
deploys on merge to `main`); no Netlify credits are involved.

### Batch 1: stale claims that mislead (recommended first) | PR size S

| ID | Task | Files | Acceptance | Verify | Size | Depends |
|---|---|---|---|---|---|---|
| 1.1 | Fix `#installation` to `#install` in four pages | `vignettes/articles/getting-started.qmd`, `guide-changes.qmd`, `cookbook.qmd`, `refcard.qmd` | no `#installation` left; link target exists | `grep -rn '#installation' vignettes README.md` returns nothing | XS | none |
| 1.2 | README: CRAN-bug fix version 0.7.0 to 0.5.0; test count to a measured figure; replace "see the roadmap" with NEWS or refresh the roadmap header (see task 6.1 and Q3) | `README.md` | statements agree with NEWS and the full suite | `grep -n '0.7.0\|3,300' README.md` shows only the What's New row; `NOT_CRAN=true Rscript -e 'r <- as.data.frame(devtools::test(reporter = "silent")); c(sum(r$nb), sum(r$failed))'` (quote the count) | XS | none |
| 1.3 | Strengthen link guards: assert every `https://data-wise.github.io/medfit/...#frag` in articles and README resolves to an existing page and heading id, and that no `#installation` anchor appears | `tests/testthat/test-guide-pages.R` (add a test) | the guard runs offline: map each absolute site URL to its source (`README.md` or `vignettes/articles/<name>.qmd`), derive the pandoc heading ids from the source headings (and explicit `{#id}`s), assert the fragment is among them, and `skip_on_cran()`; a planted `#installation` fails the test (positive control); the suite passes after 1.1 | `NOT_CRAN=true Rscript -e 'devtools::test(filter = "guide")'` | S | 1.1 |
| 1.4 | `guide-troubleshooting.qmd:96`: replace "development version" and 0.7.0 wording with "since 0.8.0" | `vignettes/articles/guide-troubleshooting.qmd` | no "development version" on the page; claim matches NEWS 0.8.0 | `grep -n 'development version' vignettes/articles/guide-troubleshooting.qmd` empty; `devtools::test(filter = "guide-troubleshooting")` | XS | none |
| 1.5 | `models.qmd`: add native route to the "Treatment-by-mediator" row; check "Find your model" row | `vignettes/articles/models.qmd` | row lists native `fit_sem()` with `x:m` | `grep -n 'Treatment-by-mediator' vignettes/articles/models.qmd`; `devtools::test(filter = "model-pages")` | XS | none |
| 1.6 | Glossary MBCO row: "minimum over the paths' likelihood-ratio tests (two or k paths)" | `vignettes/articles/guide-glossary.qmd` | matches `mbco_sem(paths = )` | `devtools::test(filter = "guide")` | XS | none |

### Batch 2: upgrade guide and troubleshooting for CRAN 0.3.2 users | PR size M

| ID | Task | Files | Acceptance | Verify | Size | Depends |
|---|---|---|---|---|---|---|
| 2.1 | Add rows to `guide-changes`: snake_case rename (0.9.0, old args warn), `nobs()` used rows (0.8.0), lavaan four-way fixes (0.9.0), `fit_sem(weights =)` rename note (0.8.0, only for 0.7.0 users: say so or omit) | `vignettes/articles/guide-changes.qmd` | each row states Before and Now, with the version; claims backed by the tests in 2.2 | see 2.2 | S | none |
| 2.2 | Add known-answer tests for each new row (column names, `conf.int` deprecation warning, `nobs()` with missing values, lavaan four-way SE against `:=`) | `tests/testthat/test-guide-changes.R` | each new statement has a test that fails if the behavior reverts (plant a defect for one) | `NOT_CRAN=true Rscript -e 'devtools::test(filter = "guide-changes")'` | S | 2.1 |
| 2.3 | Add native rows to Troubleshooting: product errors (`needs a variable name on each side`, `rule 8`, `rule 9`, `names the coefficient label`), the NA model-test note, product without `se_type = "sandwich"` warning, `anova()` "not nested", boundary-null warning, "starts reached different optima", "no start converged", `latent means are planned` | `vignettes/articles/guide-troubleshooting.qmd` | every quoted fragment appears in the code and is triggered by a test | `devtools::test(filter = "guide-troubleshooting")` | M | none |
| 2.4 | Extend `test-guide-troubleshooting.R` to trigger each new message (the existing pattern) | `tests/testthat/test-guide-troubleshooting.R` | a reworded message fails the test | same as 2.3 | S | 2.3 |

### Batch 3: native-engine known limits | PR size S-M

| ID | Task | Files | Acceptance | Verify | Size | Depends |
|---|---|---|---|---|---|---|
| 3.1 | Document that `AIC()`/`BIC()` of a fit with a product are not comparable with a fit without it (and that multi-fit `AIC()` does not check); decide doc-only vs a code warning (Q1) | `vignettes/articles/model-native.qmd` Limits, `native-guide.qmd` Limits, `model-interaction.qmd:138`, roxygen in `R/methods-sem.R:46-49` and `R/sem-syntax-help.R:112`, then `devtools::document()` | the sentence appears in all five places; `man/SEMFit-methods.Rd`, `man/medfit-syntax.Rd` regenerated; a test pins the probe (AIC differs by more than the parameter penalty) | `Rscript -e 'devtools::document()'` then `git diff --stat man`; `devtools::test(filter = "sem-product")` | S | decision Q1 |
| 3.2 | Settle the intercept-shares-a-path-label limit: reproduce or retire the .STATUS claim, then document the real behavior in `model-native` Limits | `vignettes/articles/model-native.qmd`; `.STATUS` | either a documented limit with its message, or the .STATUS note removed; a test quoting the message | author supplies the failing model (Q2); `Rscript -e 'devtools::load_all(); fit_sem(<model>, mediation_demo)'` | S | decision Q2 |
| 3.3 | Fix the ambiguous roxygen link `[anova()]` to `[stats::anova()]` | `R/fit-sem.R:59`, regenerate `man/fit_sem.Rd` | `roxygenise()` prints no "available in multiple packages" | `Rscript -e 'roxygen2::roxygenise()' \| grep -c 'multiple packages'` returns 0 | XS | none |
| 3.4 | Glossary entries: mean structure, intercept, `fixed_x`, product term, canonical name `m:x`, nested comparison, conditional log likelihood | `vignettes/articles/guide-glossary.qmd` | each term links to its page | `devtools::test(filter = "guide")` | S | none |

### Batch 4: Reference Card and Cookbook gaps | PR size M

| ID | Task | Files | Acceptance | Verify | Size | Depends |
|---|---|---|---|---|---|---|
| 4.1 | Cookbook recipe 19: observed intercepts and means (`y ~ 1`, `meanstructure =`, `~0*1` restriction compared with `anova()`); update counts (eighteen to nineteen) in cookbook intro, Getting Started, README, menu, test | `vignettes/articles/cookbook.qmd`, `_pkgdown.yml` (menu), `getting-started.qmd:192`, `README.md:283`, `tests/testthat/test-cookbook-consistency.R` | recipe runs after the setup chunk alone; count and anchors agree everywhere | `grep -rn 'eighteen\|Eighteen' vignettes README.md tests` empty; `devtools::test(filter = "cookbook")`; `pkgdown::check_pkgdown()` | M | none |
| 4.2 | Reference Card: rows for `y ~ 1`/`meanstructure`, `AIC()`/`BIC()`/`logLik()` on `SEMFit`, and native warnings (NA model test, starts disagree, not nested) | `vignettes/articles/refcard.qmd` | rows present; version note still 0.10.0 | `devtools::test(filter = "refcard")` | S | 3.1 |
| 4.3 | Make `test-refcard-coverage.R` word-boundary aware (a bare substring `nie` or `te` matches anywhere) | `tests/testthat/test-refcard-coverage.R` | planted removal of `joint_effects` row fails | `devtools::test(filter = "refcard")` | S | none |

### Batch 5: navigation and cross-links | PR size S

| ID | Task | Files | Acceptance | Verify | Size | Depends |
|---|---|---|---|---|---|---|
| 5.1 | Link the native book from `native-guide`, `native-tutorial`, `native-quickstart` ("Where next") and `model-native` "Related" | the four `.qmd` files | each links to the chapter list or the relevant chapter | `grep -l native-book vignettes/articles/*.qmd`; `devtools::test(filter = "native-book")` | XS | none |
| 5.2 | Getting Started "Where next": add cluster, lavaan and native rows; Introduction native bullet: add means, `fixed_x`, products | `vignettes/articles/getting-started.qmd`, `introduction.qmd` | rows present, links resolve | `devtools::test(filter = "model-pages\|guide")` | S | none |
| 5.3 | `extraction.qmd:638` reword to the identity-link rule; `extraction.qmd:913-918` update the extensibility list; `bootstrap.qmd:610-624` reword the status list or drop emoji status and add cluster resampling | `extraction.qmd`, `bootstrap.qmd` | no "future" item that already shipped | `grep -n 'not yet supported' vignettes/articles/extraction.qmd` empty | S | none |
| 5.4 | `_pkgdown.yml` Methods section description; (optional) drop "ADHD-friendly" wording on public pages (Q4) | `_pkgdown.yml:214,258`, `introduction.qmd:18` | description matches contents | `Rscript -e 'pkgdown::check_pkgdown()'` | XS | decision Q4 |

### Batch 6: housekeeping and optional content | PR size S (docs) + optional M

| ID | Task | Files | Acceptance | Verify | Size | Depends |
|---|---|---|---|---|---|---|
| 6.1 | Refresh `planning/medfit-roadmap.md` header (current 0.10.0, last updated), or retire the README links to it (S6) | `planning/medfit-roadmap.md`, `README.md:305,339` | no 0.7.0 "current" claim | `grep -n 'current 0\.' planning/medfit-roadmap.md` | S | 1.2 |
| 6.2 | Stamp `tasks/plan.md` and `tasks/todo.md` headers as released (0.9.0), `.STATUS` first `version:` line to 0.10.0 released, CLAUDE.md:44 add the `lmer` engine | `tasks/plan.md`, `tasks/todo.md`, `.STATUS`, `CLAUDE.md` | no "DESCRIPTION still 0.8.0" text | `grep -n 'still 0.8.0\|still 0.9.0' tasks/*.md .STATUS` empty | XS | none |
| 6.3 | (Optional) native book chapter 6: the product term and the four-way decomposition (derivation and checks, as chapters 1-5) | `vignettes/articles/native-book-6-product.qmd`, `_pkgdown.yml` (menu and index), `tests/testthat/test-native-book.R` (count 5 to 6) | follows the chapter pattern; test updated | `devtools::test(filter = "native-book")`; `pkgdown::check_pkgdown()` | M | 5.1 |

**Recommended first batch: Batch 1.** It fixes every statement that sends a reader to the wrong place or states a wrong fact
(dead anchor on four pages, wrong fix version, a nonexistent "development version"), costs under two hours, needs no
author decision, and 1.3 stops the dead-anchor class from recurring. Batch 2 is the next highest user impact (it protects
CRAN 0.3.2 upgraders from silent breakage) and should follow immediately.

Order: 1 then 2, then 3 (blocked on decisions Q1 and Q2), 4, 5, 6. Batches 4 and 5 touch overlapping files
(`getting-started.qmd`, `cookbook.qmd`); land 4 before 5 or merge them to avoid conflicts.

---

## 6. Risks and open questions for the author

Q1. **AIC/BIC across product and no-product fits (G6).** Doc-only, or also a code guard (an error or warning in multi-fit `AIC()`/`BIC()` as for `fixed_x` sets)? A code change is out of scope for a docs batch; the docs sentence is correct either way. Recommended: docs now, code warning as a 0.10.1 item.
Q2. **Intercept sharing a label with a path.** `.STATUS` says it errors in `.sem_center_map()`. My probes on `origin/main` (G7: two shared-label models, ten constraint, weight and test paths) raised no error except "no start converged" on a +500 shifted outcome, and the GRILL ledger (G12) says "allowed". Is that shifted-data stop the failure you meant, or is there another model? Without it, 3.2 cannot write an accurate limit, and the `.STATUS` note may be stale or may describe an error in a path I did not exercise.
Q3. **Roadmap and `planning/` links.** README links to `planning/medfit-roadmap.md` on GitHub from the public site. Refresh it (task 6.1) or remove the link and point to NEWS?
Q4. **Tone on public pages.** "ADHD-friendly" appears in the reference index and the Introduction. Keep (house style) or replace with plain wording (S11)? Also `bootstrap.qmd` ends with an emoji checklist that reads as internal status.
Q5. **Guide-changes scope.** It says "what a 0.3.2 user needs." Items from 0.7.0-0.8.0 that only 0.7.0 users saw (`fit_sem(sampling_weights =)`) are not relevant to a 0.3.2 reader; the plan omits them unless you want a second "from 0.7.0" table.
Q6. **`pkgdown::check_pkgdown()` prints 24 pandoc warnings** ("Deprecated: --mathjax. Use --math-method=mathjax[:URL]"). Harmless today; a future pandoc may drop `--mathjax` and break math site-wide. Track; no task proposed.
Q7. **Doc-drift tests are partial.** The refcard test matches substrings (4.3), link tests skip absolute URLs and fragments (1.3), and the `.STATUS` note says docs error-message tables were not fully covered (#195 pinned the product table only). Each new quoted message in Batch 2 needs its own trigger test.
Q8. **Native book length.** Chapter 6 (6.3) is optional; the book is 5 chapters on main, and its chapters are 27-35 KB each. Confirm demand before writing.
Q9. **Not audited live:** search, r-universe badge, mobile layout, dev-version docs, full prose of model pages and book chapters (greps only). 3 test skips in the full suite and 42 warnings were not triaged.

---

## 7. Check outputs (run on `origin/main` worktree, 2026-10-14)

```text
pkgdown::check_pkgdown()
  [WARNING] Deprecated: --mathjax. Use --math-method=mathjax[:URL] instead.   (x24, pandoc)
  ✔ No problems found.

spelling::spell_check_package()
  No spelling errors found.

urlchecker::url_check()
  ✔ All URLs are correct!                      (47 URLs)

NOT_CRAN=true devtools::test(filter = "cookbook|model-pages|guide|refcard|lavaan-comparison|native-book")
  [ FAIL 0 | WARN 0 | SKIP 0 | PASS 281 ]

NOT_CRAN=true devtools::test()   (full suite)
  files: 104  tests: 1230  expectations: 5663  failed: 0  skipped: 3  warnings: 42

devtools::run_examples(run_donttest = TRUE)  ->  ok (all examples run)
roxygen2::roxygenise() on a copy -> no diff in man/ or NAMESPACE; one warning:
  fit-sem.R:59: @param Topic "anova" is available in multiple packages: stats and lavaan.

Live crawl (curl):  69 sitemap URLs, 0 non-200;  69 distinct internal link targets, 0 non-200;
  1 missing fragment: https://data-wise.github.io/medfit/#installation  (from getting-started, guide-changes, cookbook, refcard)
  221 external links: no 404; 403 (doi.org, bot block) and 503 (rdrr.io, rate limit) only
Browser (MathJax): te, methods (338 spans), native-book-1..5, guide-glossary, refcard: 0 mjx-merror
```
