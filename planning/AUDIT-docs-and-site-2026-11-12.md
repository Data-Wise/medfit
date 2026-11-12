# Audit: documentation surfaces and the website after 0.17.0 (2026-11-12)

Status: read-only audit of `origin/dev` at `433a6396` (DESCRIPTION 0.17.0, date 2026-11-11; `main` holds the merge `6b9a943c`;
no tag, the GitHub release is pending in another session). Nothing here changes a file except this report. Scope guard:
the native-to-sem rename belongs to PR #431 and `PLAN-0.18.0-engine-vocabulary-2026-11-12.md`; findings that touch that
vocabulary are listed as "defer to #431", not fixed here.

Method: `rg`/`grep` over every surface, `pkgdown::check_pkgdown()` (clean), and a static anchor check of every
`page.html#anchor` link in `vignettes/articles/*.qmd` and `README.md` (script reasoning below). Evidence is `file:line`.

## 1. Inventory

| Surface | Format | Size | Owner today | Currency (0.17.0 tree) |
|---|---|---|---|---|
| `README.md` | Markdown, home page of the site | 380 lines, 17 H2/H3 | hand-edited | **stale in four places** (F1) |
| `NEWS.md` | Markdown, pkgdown news page | 1,978 lines, one `# medfit x.y.z` per release | hand-edited | **two stale phrases, two missing issues** (F2) |
| `_pkgdown.yml` | YAML, 378 lines | navbar 10 items, Models menu 15 links, Guides menu | hand-edited | clean: `check_pkgdown()` reports no problems |
| `vignettes/articles/*.qmd` | Quarto, 44 pages | 67 to 1,264 lines; 7 pages over 400 lines | hand-edited, evaluated at site build | stale version words in 4 pages (F3) |
| roxygen and `man/` | roxygen2, generated Rd | n/a | code authors | `document()` no diff (per `.STATUS`); not re-run here |
| `inst/CITATION` | R, 75 lines | uses `meta$Version` (`inst/CITATION:13`) | derived | **current by construction**; no gate needed |
| `DESCRIPTION` | DCF | `Version: 0.17.0`, `Date: 2026-11-11` (`DESCRIPTION:4-5`) | release prep | current |
| `.STATUS` | text, 526 lines, newest entry first | | session end | top entries are 0.17.0 prep; no "released" entry (correct: not released) |
| `CLAUDE.md` | Markdown, 723 lines | | maintainers and agents | status lines stale (F5) |
| `cran-comments.md` | Markdown, 42 lines | about 0.3.2 | CRAN submission | historical; CRAN on hold (#83), see F7 |
| GitHub release notes | web, per tag | | release engineer | none for 0.17.0 yet; no template in the repo (F8) |
| `planning/` | Markdown, plans, grills, ADRs | ADRs in `planning/specs/ADR-*.md` | authors | two ADRs carry the `decisions:` front matter checked by `test-adr-front-matter.R` |
| `CONTRIBUTING.md`, `AGENTS.md` | Markdown | | | not audited in depth |

pkgdown shape: navbar `home, reference, models, guides, cookbook, articles, qc, ecosystem, status, news` (`_pkgdown.yml:46-49`);
Models menu has 3 group labels and 15 links; the articles index has 6 sections, and the "Guides" section lists 15 pages
(`_pkgdown.yml:332-349`), mixing user guides (`guide-*`), the native-engine track (`native-*`), comparisons and an example.

## 2. Findings

Severity: **S1** states something false about 0.17.0; **S2** stale or misleading wording; **S3** design or maintainability.

### F1. README is stale in four places (S1)

| Where | Text | Why stale |
|---|---|---|
| `README.md:21` | heading "Bounded FIML in 0.16.0" | the section now describes 0.16.0 and 0.17.0; the heading hides the 0.17.0 scope |
| `README.md:38` | "Website publication remains a separate step." | the site publishes from `main`/release by workflow; the sentence is a leftover from the 0.16.0 release |
| `README.md:278` | `TwoLevelMediationData` row ends "(development version)" | the class ships in 0.17.0 (experimental); the label is wrong and the experimental label is missing from this row |
| `README.md:44-46` vs `21-37` | the What's new row for 0.17.0 and the FIML section say the same thing twice | duplication (F4) |

Also `README.md:332`: "2,200+ `test_that()` blocks" is a hand-counted number with no gate; `.STATUS` records 2,361 tests for the
last full run (units differ, so the claim is untestable as written).

### F2. NEWS 0.17.0 (S1/S2)

* `NEWS.md:60`: "Behavior change for the development version only (the adapter is unreleased)." The adapter ships in 0.17.0.
* `NEWS.md:101`: "Hardening of the two-level adapter (all within the development version, ...)". Same.
* `NEWS.md:372` ("removed in the development version") sits under `# medfit 0.15.0` (starts `NEWS.md:352`): historical and
  correct for that entry; leave it. `NEWS.md:1232` likewise.
* Known issues (`NEWS.md:12-14`) list only #320. The checklist's own notes (`planning/PLAN-0.17.0-release-checklist-2026-11-11.md`
  P3) triage #369 (bounded remainder) and #394 (S4/S5 two-level fitting, narrowed). Neither appears in the release summary;
  `NEWS.md:99` and `:317` mention #394 only as "deferred".
* `NEWS.md` is one 1,978-line page with no release-time rule: nothing checks that every release has a heading, or that "unreleased"
  wording disappears when a version ships (F9 gate).

### F3. Article version words (S2)

* `vignettes/articles/guide-changes.qmd:117` (0.17.0 row) repeats 0.16.0 content ("corrected observed and sandwich covariance
  under active nonlinear constraints ..." is already in the row at `:116`), and the same row says "in the previous development
  version", which a reader of a released 0.17.0 cannot place. `:15` says "documents 0.17.0 and the development version".
* `vignettes/articles/model-native.qmd:38` and `native-tutorial.qmd:31`: "the separate unreleased bounded FIML opt-in". Bounded
  FIML shipped in 0.16.0 (simple model) and 0.17.0 (the rest).
* `vignettes/articles/model-fiml.qmd:24`: "covariates, parallel and serial forms in the development version" (now 0.17.0).
* `vignettes/articles/native-guide.qmd:229, 322, 349, 390`: "After 0.16.0 the development version ...", "Development version
  only; not in 0.16.0." Each should read "from 0.17.0".
* `vignettes/articles/getting-started.qmd:16`, `refcard.qmd:15`, `guide-changes.qmd:15`: "documents 0.17.0 and the development
  version". Defensible while `dev` runs ahead of a release; after the release, say "0.17.0". `cookbook.qmd:19` is correct.

### F4. Duplicated content (S3)

* The 0.17.0 FIML scope is stated in `README.md:21-38`, `README.md:44`, `NEWS.md:4-8`, `guide-changes.qmd:117`,
  `native-guide.qmd:223-390`, `model-fiml.qmd`, `models.qmd:87-92`. Seven copies, three different phrasings of the limits
  ("numerically verified, not statistically admitted" appears in NEWS and README:44 but README:27 says "not calibrated for
  coverage"). One copy is the source (`model-fiml.qmd`); the rest should be a sentence and a link.
* The README "What's new" table (`README.md:42-60`) copies NEWS rows; the 0.15.0 and 0.16.0 rows are paragraph length.
* `guide-changes.qmd` is a second changelog with its own table (rows 0.3.2 to 0.17.0), so every release is documented in
  NEWS, the README table and this page.

### F5. CLAUDE.md and `.STATUS` status lines (S2)

* `CLAUDE.md:669` "Current status: 2026-10-31 UTC: 0.16.0 released ... (`dev` is ahead)" and `CLAUDE.md:666` "Last Updated:
  2026-10-26" are older than the 0.17.0 prep lines at `:651`. `CLAUDE.md:651` says "`DESCRIPTION` is 0.17.0 on the prep branch
  only until its PR merges"; the PR merged (`DESCRIPTION` on `dev` is 0.17.0). Not edited here because the 0.17.0 release record
  belongs to the release session and PR #431 edits adjacent vocabulary text; flagged for stage 3 with the coordination note below.
* `.STATUS:5-8` still says "Branch feature/release-prep-0.17.0 ... R2 full local gates pending", while `433a6396` and `6b9a943c`
  are on `dev` and `main`.

### F6. Links and anchors (S3, no breakage found)

* `pkgdown::check_pkgdown()`: no problems (reference index covers every topic; articles index covers every article).
* Static anchor check over 44 articles plus the README: every `page.html#anchor` link with a plain heading resolves. The 24
  links into `cookbook.html#...` resolve through pandoc's rule that strips the leading "5. " from "## 5. Two mediators in a chain";
  `test-model-pages.R` already asserts them. The check my script flagged is a limit of the script, not of the pages.
* **Anchor fragility:** the cookbook headings are numbered ("## 1. One-line mediation", `cookbook.qmd:30`); a renumber or a
  title tweak breaks 24 inbound links with no build error. External deep links (README uses absolute
  `https://data-wise.github.io/medfit/articles/...#` URLs, `README.md:44-46, 285-325`) are not checked by anything but a manual
  URL pass. Any rename in stage 3 needs an anchor check first.

### F7. `cran-comments.md` (S3)

It describes the 0.3.2 submission (`cran-comments.md:24-36`). CRAN is on hold (#83) and the file is not shipped (`.Rbuildignore`
not re-checked here). Leave as the 0.3.2 record; add one line at the top saying it is historical, so no one syncs it to 0.17.0.

### F8. GitHub release notes (S3)

No template or generator in the repo; the 0.16.0 checklist says "reviewed notes", and the 0.17.0 checklist R9 repeats it. The
release notes can be derived from the NEWS release summary (`NEWS.md:3-18`) so they cannot disagree with it.

### F9. What no existing gate catches

Existing docs tests: `test-model-pages*`, `test-guide-*`, `test-refcard-coverage`, `test-cookbook-consistency`,
`test-condition-docs`, `test-twolevel-docs`, `test-adr-front-matter`, `test-docs-warning-ready`. None checks:
README/NEWS/articles version words against `DESCRIPTION`; that a released version has a NEWS heading; "development version" or
"unreleased" in prose once the version has shipped; that `.STATUS` or `CLAUDE.md` status lines name the current version; that
every export is in the pkgdown reference (covered by `check_pkgdown()` locally, but not as a test).

### F10. Design (S3), for stage 2

* Home page is a 380-line README: 17 headings, a 60-second tour with 3 code blocks, a two-example "More examples" section, a
  10-row ecosystem table, and the development-status section. The first screen is the FIML paragraph (`README.md:21-38`), a
  specialist topic, ahead of install and the first example.
* Seven article pages exceed 400 lines (`methods` 1,264, `extraction` 998, `cookbook` 783, `bootstrap` 630, `example-gpa` 488,
  `native-guide` 488, `model-twolevel` 435). Only `cookbook` is a lookup page; the others are read-through.
* Navigation: 10 top-level items, 15 links in the Models menu, and 15 pages in one articles "Guides" section; the navbar
  Guides menu and the articles index group the same pages differently.
* Model pages share a template (one-line lead, a 4-row facts table `Structure/Class/Indirect effect/Routes`:
  `model-simple.qmd:19-24`), which is a good base. `model-twolevel.qmd:28` adds `Availability`; `model-fiml.qmd:24` too; others do not.

## 3. Coordination with PR #431 (not touched)

The native-to-sem rename will rewrite `native-*`/`model-native*` page names, menu labels and `engine = "native"` mentions. This
audit and the later stages therefore (a) change no file name, URL or menu label containing "native", (b) fix version words only
inside sentences that #431 does not own, and (c) put the new gates on version words and structure, not on the vocabulary.

## 4. Verified and not verified

Verified: version strings, headings, grep hits above at `433a6396`; `check_pkgdown()` clean; anchor check run.
Not verified: a rendered site build (not run here), external URL liveness (`urlchecker`), roxygen `document()` diff, the
`.Rbuildignore` status of `cran-comments.md`, `CONTRIBUTING.md` and `AGENTS.md` content, spelling.

## 5. Proposed stage 3 fix list (for the maintainer's confirmation)

1. README: heading to "Bounded FIML (0.16.0 and 0.17.0)"; delete "Website publication ..."; drop "(development version)" and add
   "(experimental)" at `:278`; shorten the What's new rows to one line each with the NEWS link.
2. NEWS 0.17.0: replace "development version"/"unreleased" at `:60`, `:101`; add #369 and #394 to the known issues.
3. Articles: version words in `guide-changes.qmd:117`, `model-native.qmd:38`, `native-tutorial.qmd:31`, `model-fiml.qmd:24`,
   `native-guide.qmd:229,322,349,390`; make `model-fiml.qmd` the single FIML source.
4. `.STATUS`, `CLAUDE.md` status lines, `cran-comments.md` header line: after the release session reports, to avoid colliding
   with its edits.

## 6. Addendum (2026-11-12, after v0.17.0 was released and #433 back-merged main into dev)

* **Release state.** v0.17.0 is released (tag at `6b9a943c`, GitHub release 2026-11-12, tagged install verified, site shows 0.17.0).
  F5 now reads: `CLAUDE.md:651` ("not released, release not authorized"), `CLAUDE.md:666`/`:669` and `.STATUS:5-8` need the
  released state; the stage 3 wait on the release session (section 5, item 4) is no longer needed. F8: the GitHub release notes
  exist; deriving them from the NEWS release summary stays the rule the stage 4 gate checks.
* **Line fix.** The README "2,200+ `test_that()` blocks" claim is at `README.md:335` (F1 cited `:332`, the heading).
* **NEWS F2 additions.** The 0.17.0 entry also omits the #426 packaging items (RMediation added to Suggests, a names-only
  `@usage` block for `TwoLevelMediationData`, both merged in `e608ac7c`), and the known-issues list needs #369 and #394 (both open)
  next to #320.
* **Merge order.** Stage 3 edits `native-guide.qmd`, `model-native.qmd` and `native-tutorial.qmd`, which PR #431 (S5a prose slice)
  also edits later: stage 3 lands first and is limited to version words and structure, with no rename of any file, URL or menu
  label containing "native".
* **Rendered pass** on the live site: see section 9 of `planning/PROPOSAL-docs-adhd-design-2026-11-12.md` (new findings F11 to F16).
