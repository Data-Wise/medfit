---
title: "Proposal: docs and website audit, currency fixes, ADHD-friendly layout"
status: proposal (not authorized, nothing implemented)
date: 2026-11-22
base: dev at ce39a655 (0.19.0.9000, unreleased)
source: read-only audit; all file:line cites verified by reading at ce39a655. Nothing was rendered, so build-time and table-of-contents points are inferred.
---

# Docs and website: audit, fixes, layout

## TL;DR

- The site is structurally sound. Getting Started and the model pages already follow a good template.
- The real problems are **stale claims** (README says "no user-visible changes", "on CRAN"), **menu sprawl** (about 74 links, duplicates), and **walls of text** (model-twolevel 6,203 words, troubleshooting 4,836, README 383 lines).
- **No R code changes.** Seven small docs PRs, each mergeable alone. Start with A (currency).
- **Release trap for 0.20.0:** five pages say "development version" or "unreleased" and will fail `test-docs-release.R:17` once the `.9000` suffix is dropped (PR G).

## 1. What is wrong now (verified)

| # | Finding | Where |
|---|---|---|
| 1 | README What's new says "no user-visible changes yet since 0.19.0"; NEWS top lists native two-level, `mbco_sem` on two-level fits, `twolevel_equal_indirect()`, h1 ICC (#513) | `README.md:149-151` |
| 2 | "medfit is on CRAN" (CRAN has 0.3.2); lifecycle badge "stable"; test count and citation version stale | `README.md:4, 332, 338, 366` |
| 3 | "Examples on this site use medfit 0.13.0" | `guide-troubleshooting.qmd:21` |
| 4 | Cookbook menu stops at recipe 23; recipe 24 exists | `_pkgdown.yml` (cookbook items), `cookbook.qmd:777` |
| 5 | Native two-level route and "experimental" label missing; no development row | `models.qmd` (~54), `refcard.qmd:46,78`, `guide-twolevel-tutorial.qmd`, `lavaan-comparison.qmd`, `guide-changes.qmd:119` |
| 6 | "native engine" wording where the name is now "sem engine" | `cookbook.qmd:278,323,389,585,646` (headings, anchors depend on them), `model-interaction.qmd:91`, `sem-defaults-0-15.qmd:216,263`, `whats-new-0-11.qmd:23,113`, `extraction.qmd:921`. `guide-changes.qmd` rows are history: leave |
| 7 | Duplicate menu entries: `quality-control` (Articles and Project), `sem-defaults-0-15` (Guides and Articles), Getting Started, Reference Card and Cookbook (Articles and their own menus) | `_pkgdown.yml` |
| 8 | Orphans (only the navbar links to them): `guide-architecture`, `whats-new-0-11` | inbound-link grep |
| 9 | Navbar is at the cap of 8 left items; any new top-level item means dropping one | `test-docs-release.R:99-102` |

Checked and fine: all 45 articles are in the navbar, no broken internal links or anchors found (heuristic heading ids), h1 ICC rule documented correctly (`model-twolevel.qmd:229-250`, `guide-troubleshooting.qmd:87-91`, `guide-glossary.qmd:102`).

## 2. ADHD-friendly layout (what to change)

Principle: one clear next action per screen, answer-first, short scannable chunks, no dead ends.

**Landing page (README), proposed order**
1. One-line pitch
2. Install (3 lines) plus the CRAN-hold callout
3. "Start here in 60 seconds" (one example, one result)
4. "Pick your model": 6 rows (simple, binary outcome, several mediators, clusters or two-level, lavaan or latent, missing data), link to the full table
5. "When something fails": 3 links
6. Everything else collapsed in `<details>` (What's new, FIML limits, class table, ecosystem); admin footer last

Today: the FIML caveat sits above Install, "Pick your model" appears three times, a 13-row documentation table repeats it. Keep the RD-8 caveat sentence ("not statistically admitted") somewhere in the README.

**Navbar (stays at 8 left items)**
`Home | Start | Models | Cookbook | Guides | Reference | Learn more | News`
- **Start:** Getting Started, 60-second example, Install, Which model?
- **Guides:** led by "When something fails" (Troubleshooting first), then Which engine or interval, Glossary, Upgrading
- **Cookbook:** a link plus 5 task groups, not 24 rows
- **Learn more:** Introduction, Extraction, Bootstrap, Methods, sem engine trio, comparisons, quality control, history
- Each page lives in exactly one menu.

**Page template (every page)**
- **Open:** breadcrumb; three lines "Use this when / You get / Time: N min"; a status label (stable, experimental, development); the existing summary table.
- **Body:** numbered steps, at most 7; after each long chunk a line "You should see ..."; warnings as callouts.
- **Close:** "Common errors" (2 rows linking to troubleshooting), a `{.next-action}` block, Related.
- Today only `model-simple` has the "For / You get" box; non-model pages have no Next block, so readers dead-end.

**Long pages**
- Troubleshooting: add a "Most common 6 errors" table and jump links at the top.
- Cookbook: add a task-to-recipe table at the top (the menu is the only index today).
- `model-twolevel` (6,203 words, 15 h2): open with a decision box; consider moving the sem-engine section into its own page.
- Gloss MBCO, FIML, ICC, sandwich at first use or link the glossary.

## 3. Top 10 fixes (value over effort)

1. Rewrite `README.md:149-151` What's new from NEWS (docs only).
2. Add recipe 24 to the Cookbook menu in `_pkgdown.yml`.
3. Fix `README.md:332` ("CRAN has 0.3.2; this site documents the GitHub build"), the badge, the test count and the citation line.
4. Reword `guide-troubleshooting.qmd:21` without a version number; widen the prose-gate regex to also match "use medfit X" (`test-docs-release.R`, near line 144).
5. Add the native two-level route plus an "experimental" label to `models.qmd`, `refcard.qmd`, `guide-twolevel-tutorial.qmd` and `lavaan-comparison.qmd`; add a development row to `guide-changes.qmd`.
6. Reorder the landing page; delete the duplicate Documentation table.
7. Regroup the navbar (merge duplicates, stay at 8).
8. Add the 3-line opener and the Next block to every non-model page.
9. Troubleshooting top-6 table and jump links; gloss jargon.
10. Cookbook table of contents; rename "native" headings together with the navbar anchors.

## 4. PR sequence (each independently mergeable)

| PR | Content | Tests to run or touch |
|---|---|---|
| A | Currency fixes: 1, 3, 4 (text) | `test-docs-release.R`, `test-model-pages.R` (home links) |
| B | Recipe 24 in the menu; native/experimental labels; development row in `guide-changes` | `test-twolevel-docs.R`, `test-twolevel-native-docs.R`, `test-refcard-coverage.R`, `test-guide-changes.R`, `test-cookbook-consistency.R` |
| C | Landing page reorder (README only) | `test-docs-release.R` (RD-6, RD-8), `test-model-pages.R:78`, `test-guide-pages.R:129` |
| D | Navbar regroup | `test-docs-release.R:199` (at most 8), `test-guide-pages.R:15`, `test-model-pages.R:38` |
| E | Troubleshooting top-6, cookbook table of contents, page openers | docs tests above; extending `page_problems` to guides is an optional test change |
| F | Rename "native" cookbook headings with their anchors (last, riskiest) | `test-cookbook-consistency.R`, `test-model-pages.R:61` |
| G | Release prep for 0.20.0: the five `stale_words` hits, `model-twolevel.qmd:335-336` (wraps a line, so the gate misses it), What's new heading, `guide-changes` row | `test-docs-release.R` |

Release-trap lines for G (once the version has no `.9000`, `stale_words` "development version|unreleased" is checked on the README and every article): `README.md:151`, `getting-started.qmd:16`, `guide-changes.qmd:15`, `refcard.qmd:16`, `model-twolevel.qmd:30`.

## 5. Risks

- Articles evaluate code at build with no caching (cookbook 40 chunks, extraction 31, model-twolevel 25, example-gpa 25); `pkgdown.yaml` runs on PRs to `dev`. Prefer prose and tables over new evaluated chunks.
- Heading renames can silently break navbar anchors if pandoc ids drift (underscores matter).
- Gate gaps: `stale_words` misses phrases wrapped over lines; the prose gate misses "use medfit X".
- The navbar is at its cap; the proposed layout keeps it at 8 by renaming, not adding.

## 6. Decisions

Decided 2026-11-22 (maintainer):

1. PRs A and B: done, merged as #514 (`fceeaab4`). The "use medfit X" gate widening shipped in A.
2. Navbar regroup (D): **accept the proposed 8 items**, each page in exactly one menu.
3. `model-twolevel.qmd`: **keep one page**, add a "Which route do I use?" decision box and a jump list at the top; no anchor moves, no split.
4. Gates in G: **widen** to catch phrases wrapped over a line break (the "use medfit X" part already shipped), with planted defects.
5. Order: **C first** (landing page), then D, E, F, G.
