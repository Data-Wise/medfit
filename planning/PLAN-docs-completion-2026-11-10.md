# Plan: complete the book, website articles, vignettes and cookbook (DRAFT, 2026-11-10)

Status (2026-11-10, later): D1 (#398), D3 (#399) and D5 (#401) merged into `dev`; D4 (PR4) in progress; D2, D2b, D7 and D6 pending. Original status: planning only; nothing started. Written from a surface inventory of `origin/dev` (file list, `_pkgdown.yml`,
`NEWS.md`, `book/index.qmd`, `model-fiml.qmd`, the earlier gap audits). Items marked **verify** are suspected, not
confirmed; each work unit starts by confirming its own gaps (rule `doc-update-currency-check.md`: inventory and
currency first, then edit only the delta).

## What exists

| Surface | State on `dev` |
|---|---|
| Website articles | 38 `.qmd` under `vignettes/articles/`: 14 model pages (`model-*.qmd`), guides (changes, troubleshooting, intervals, glossary, native defaults), cookbook, refcard, methods, lavaan-comparison, quality-control, native quickstart/tutorial/guide |
| Technical book | `book/`: native-engine minibook, preface plus 8 chapters (mean structure, scale, constraints, fixed_x, inference, product term, four-way, FIML). Repository-only, not on the site. Scope widened 2026-11-10 (see D2b) |
| Earlier audits | `GAP-docs-vignettes-2026-09-24` (all rows fixed), `docs-site-audit-2026-10-13`, `AUDIT-minibook-coverage-2026-10-20` (10 gaps filled), `PROPOSAL-docs-2026-10-24` (native-defaults article done; two quick wins to **verify**) |
| Doc gates | `test-refcard-coverage`, `test-cookbook-consistency`, `test-model-pages*`, `test-guide-*`, `test-native-book`, `test-lavaan-comparison`; `pkgdown::check_pkgdown()` |

## Gaps (ranked by chance of misleading a reader)

1. **Two-level mediation has no docs yet** (issue #394; the class and extraction are on `dev`, effects and bootstrap are
   in flight). Needs a model page, cookbook recipe, refcard rows, a `methods.qmd` section, glossary symbols,
   troubleshooting rows for the classed conditions, a `guide-changes` row and NEWS. Planned as S2 PR4; it must carry
   the literature caveats: fixed-slope estimand (`sigma_ab = 0`), latent versus manifest cluster means, the contrast is
   descriptive, not a test. Do not state a 3-4% `fixed.x` SE gap (measured about 1% for `a_between`, about 0% for the
   others).
2. **Book and preface lag the code (verify).** `book/index.qmd` still describes bounded FIML as the 0.16.0 simple
   X -> M -> Y route; `dev` now fits parallel and serial forms with 0-2 covariates (14 variants, still not
   statistically admitted). Chapter 8 was touched 2026-11-09, so check what it already says before editing. The
   preface also says "documents medfit 0.16.0".
3. **Version-stamped pages.** `whats-new-0-11.qmd` (historical, last edited 2026-10-24), `guide-changes.qmd` ("what
   changed since CRAN 0.3.2"), and the cookbook's recipe count and links need a currency check against NEWS
   (**verify**; fold the check into every unit that touches them).
4. **Project docs.** `planning/TODOS.md` still says "Current Focus: 0.15.0" and lists finished vignette ideas as open;
   `CLAUDE.md`/`.STATUS`/roadmap need the two-level entries (assigned to PR4). The open vignette idea "comparing
   medfit with other packages" exists as `lavaan-comparison`; the probmed and RMediation comparisons are not written.
5. **Quick wins from the 0.14 proposal (verify whether done).** A `withCallingHandlers()` recipe for muffling medfit
   condition classes (section of `guide-troubleshooting.qmd`); a `fixed_x` semantics section in the native guide.
6. **Deferred by decision.** A generated oracle-matrix page from `tests/sim/gates.csv` (R-4, belongs with the QC
   dashboard work); the object-based bootstrap API docs (the API is deferred); a native two-level book chapter
   (needs S4, the native fitter); FIML admission results (needs section 5 of the FIML plan, unauthorized).

## Work units

Docs units edit shared files (`_pkgdown.yml`, `refcard.qmd`, `NEWS.md`, `guide-changes.qmd`), so they merge one at a
time, each from its own worktree off `dev`. Each PR is docs-tier: lint, the doc-consistency tests, a full evaluated
site build with link check, and a quoted transcript for each new example (rule `e2e-before-pr.md`: the example must be
able to fail; every quoted error message gets a `test-guide-*` check).

| # | Unit | Files | Depends on | Starts |
|---|---|---|---|---|
| D1 | Currency sweep and project docs: confirm gaps 2-5, fix `book/index.qmd` and the preface for current FIML scope, update `TODOS.md`, resolve the two quick wins, tick finished items | `book/index.qmd`, `book/chapters/08-fiml.qmd` (only if stale), `guide-troubleshooting.qmd`, `native-guide.qmd`, `planning/TODOS.md` | none | now |
| D2 | Book: reader-facing paragraphs for any code contracts added since the 2026-10-20 audit (rerun the audit method over `R/sem-*.R` changes since then); keep native-only scope | `book/chapters/*.qmd`, `tests/testthat/test-native-book.R` | D1 | after D1 |
| D2b | Widen the book (maintainer decision 2026-11-10): add a part on the model classes beyond the native engine. Chapter 9: the lavaan adapter and `TwoLevelMediationData` (parameter-table keying, the joint-covariance sub-block, the cross-level contrast, the O8 hand-built likelihood as the worked oracle). Chapter 10 (confirmed 2026-11-10): 2-1-1 cluster mediation (`ClusterMediationData`: the mean/within/raw terms found by value, NIE = a x b_between, own and spillover split and the large-cluster approximation, Kenward-Roger t intervals, cluster bootstrap; verified against the existing oracles in `test-cluster-211.R`). Chapter 10 does not depend on S2, so it can be written earlier than chapter 9. Retitle the book and preface; a native two-level chapter waits for S4 | `book/_quarto.yml`, `book/index.qmd`, new `book/chapters/09-*.qmd`, `test-native-book.R` (rename or extend) | D1, S2 PR3 merged | after PR3 |
| D3 | Cookbook and refcard completeness: every exported function and class has a refcard row and at least one cookbook recipe or an explicit "no recipe" reason; recipe numbering and links consistent | `cookbook.qmd`, `refcard.qmd`, the two coverage tests | D1 | after D1 (parallel with D2) |
| D4 | Two-level docs (this is S2 PR4, owned by that slice): `model-twolevel.qmd`, cookbook recipe, refcard, methods, glossary, troubleshooting, guide-changes, NEWS, version 0.17.0 | as listed in the S2 spec | S2 PR2 and PR3 merged | after PR3 |
| D5 | Ecosystem comparison articles for probmed and RMediation (scheduled 2026-11-10): what each package adds on top of medfit, a side-by-side table of the shared objects, one worked example each; each statement checked against the dependent's current release and its test suite (`test-dependents-contract.R`), written like `lavaan-comparison` with a live feature table test | new `vignettes/articles/*-comparison.qmd`, `_pkgdown.yml`, a comparison test | D1 | after D1 (parallel with D2, D3) |
| D7 | Book CI render (maintainer decision 2026-11-10): a workflow that renders `book/` to HTML and PDF and uploads both as artifacts; runs on PRs that touch `book/**` and on release only, not on every PR, to respect the main-only hosted-cost policy; installs the package from the PR tree and needs TinyTeX for the PDF | `.github/workflows/book.yaml` | D2 (so there is content to build) | after D2 |
| D6 | Final gate pass: spelling (`inst/WORDLIST`), `urlchecker`, `pkgdown::check_pkgdown()`, full site build, internal-link check, book render (HTML and PDF), browser inspection of new pages | none (report) | D1-D4 | last |

Concurrency: D1 now (one worker, medium effort); D2, D3 and D5 after it, at most two at a time because of shared files; D2b and D4 after S2 PR3; D7 after D2; D6 last. Together with S2 that stays within the cap of 3 background workers per batch.

## Acceptance

- Each unit's PR carries exact commands and counts (doc tests, lint, site build page and link counts).
- No version or date bump without a real change; the report lists files found already current.
- Statistical claims match `methods.qmd` and the verified oracles; no new numeric claim without an independent
  check (the two-level docs reuse the PR1-PR3 transcripts).
- US spelling; `book/` stays repository-only; its scope is widened to the lavaan adapter and two-level model (D2b).

## Decisions (2026-11-10)

1. Book scope: widened beyond the native engine (D2b), with chapter 9 (lavaan adapter, two-level) and chapter 10 (2-1-1 cluster mediation).
2. Comparison articles for probmed and RMediation: scheduled (D5).
3. Book builds to HTML and PDF in CI (D7), path-filtered to `book/**` and release. Open: confirm the PDF toolchain
   (TinyTeX) is acceptable on the runner.
4. "Other change" was selected without detail; any further adjustment is still to be named.
