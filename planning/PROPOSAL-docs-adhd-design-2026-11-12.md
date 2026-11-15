# Proposal: an ADHD-friendly design for the medfit site (2026-11-12)

Status: PROPOSAL, stage 2 of the docs pipeline. Input: `planning/AUDIT-docs-and-site-2026-11-12.md` (F4 duplication, F10 design).
Nothing here is applied; stage 3 applies the parts the maintainer confirms. No file, URL, anchor or menu label is renamed
(the "native" vocabulary belongs to PR #431), so every example keeps its current links.

## 1. Principles, each tied to a check

| # | Rule | How a page shows it | Checkable? |
|---|---|---|---|
| P1 | **One next action per page.** Every page ends with a single "Next" line, one link. | `**Next:** <link>` as the last line before "Related" | yes: the last non-empty content line of each model page matches `^\*\*Next:\*\*` |
| P2 | **"What this page is for" lead**, at most 2 sentences, in the first 5 lines after the front matter. | Lead states the question the page answers, not the method. | partly: lead length cap by test |
| P3 | **Tables over paragraphs** for choices, settings and limits; a paragraph is at most 5 lines. | Reuse the existing 4-row facts table; add `Use it when / Use something else when`. | no (review) |
| P4 | **Progressive disclosure.** The first screen holds what 80% of readers need; limits, history and math sit under a collapsed `<details>` or a later section. | Home page: install, one example, "pick your model". Everything else below the fold or a link. | partly: README line of the first "Pick your model" heading <= 60 |
| P5 | **At most 7 choices per screen.** Menus group; a group has at most 7 links. | Models menu 15 links in 3 groups: keep, but cap the group sizes at 7 (the native group is 6 today). Guides section: split in two (below). | yes: a test counts links per navbar group |
| P6 | **One home per fact.** A fact (such as the FIML scope) lives on one page; the others link with one sentence. | `model-fiml` is the source; README, guide-changes, native-guide keep one line. | yes: the sentence "numerically verified, not statistically admitted" appears with the same wording everywhere or not at all |
| P7 | **A visible "you are here" cue.** Page title, a one-line breadcrumb (`Models > Single mediator > Simple mediation`), and the navbar group highlighted (pkgdown does this for menu items). | Breadcrumb line under the title, from the pkgdown menu structure. | yes: a test that each model page's breadcrumb equals its menu position |
| P8 | **Readable by default.** Body 16 to 18 px, line height 1.6, line length 60 to 80 characters, contrast at least WCAG AA (4.5:1), no color-only meaning, code blocks not wider than the text. | A small `pkgdown/extra.css` (theme variables), already the pkgdown mechanism. | contrast: yes, computed from the theme colors in a test |
| P9 | **No walls of text.** A section over 30 lines gets a sub-heading or a table; a page over 400 lines gets a "On this page" block of at most 7 links at the top. | Applies to `methods`, `extraction`, `cookbook`, `bootstrap`, `model-twolevel`. | yes: lint on consecutive non-heading, non-code lines |

## 2. Page templates (consistent, three kinds)

**Model page** (15 pages today, `model-*.qmd`):

```
title
> breadcrumb: Models > <group> > <page>
Lead (<= 2 sentences: the question this page answers)
| Structure | Class returned | Indirect effect | Availability | Routes |      <- same 5 rows on every page
## Use it when        (3 bullets) and "Use something else when" (3 bullets with links)
## Run it             (one code block per route; the first is the shortest)
## Read the result    (the table)
## Assumptions and limits   (<= 6 bullets, collapsed if longer)
**Next:** <one link>
```

Only `Availability` is new (two pages have it: `model-twolevel.qmd:28`, `model-fiml.qmd:24`); it takes the version string from
one place, so the version words in F3 stop going stale.

**Guide page** (`guide-*`, `native-*`): lead, "Who this is for", numbered steps or a table, "Next".
**Reference page** (`methods`, `computation-algorithms`, `extraction`): "On this page" block, then sections; no Next line
(readers jump in).

## 3. Navigation

* Navbar: keep the ten items but fold `qc`, `ecosystem` and `status` into one "Project" menu: 8 items instead of 10 (P5).
* Articles index "Guides" (15 pages, `_pkgdown.yml:332-349`) splits into **Guides** (the `guide-*` pages, the defaults article,
  syntax crosswalk: 8) and **Native engine** (`native-quickstart`, `native-tutorial`, `native-guide`, GPA example, comparisons: 7).
  Title text uses the current "native" words; #431 renames them later, by editing two strings.
* "Start here" stays 3 items. Add a fourth row on the Models landing page: "Not sure? Answer three questions" (a table: how many
  mediators, what kind of variables, clustered or not) that ends at one page.

## 4. Before and after: the home page

### Before (README, 380 lines; first screen)

```
# medfit: ... + 6 badges
**medfit** fits mediation models ... (3 lines)
> In one line: ...
## Bounded FIML in 0.16.0      <- 17 lines, specialist, with seven limits
## What's new                  <- 3 paragraph-length table rows
## Install ... CRAN note (4 lines)
## Try it in 60 seconds
...
## Pick your model  (line 154)
```

First screen: the FIML scope. First next action: unclear. "Pick your model" starts at line 154.

### After

```
# medfit: mediation analysis in R
**For:** a treatment, a mediator and an outcome, any of the models listed below.
**You get:** the paths, the indirect effect and its interval, one call.

**Next: run the 60-second example** (below)       <- the single visible action

## Install              (one block, one sentence; CRAN note as a one-line callout)
## Try it in 60 seconds  (the existing code, unchanged)
## Pick your model        (the existing 12-row table, moved up from line 154 to about line 50)
## More                   (a table: Cookbook | Reference card | Troubleshooting | What changed | Methods)
<details><summary>What's new in 0.17.0</summary> 3 bullets + link to NEWS </details>
<details><summary>Bounded FIML (0.16.0 and 0.17.0)</summary> 3 lines + link to model-fiml </details>
## Cite, contribute, license    (short)
```

What changes: the FIML section drops from 17 lines to 3 (P6) and moves below the fold (P4); the What's new table drops from
three paragraph rows to three bullets, each ending in a NEWS link; "Pick your model" moves above the fold. The first screen
holds one action. What stays: every code block, every link target, the badges, the citation; `test-guide-pages.R:129` (absolute
site links resolve) and `test-model-pages.R:78` (home links) keep passing because no target moves.

Pkgdown limits: `<details>` renders in the pkgdown home page (README is rendered through pkgdown's markdown, raw HTML kept); the
README stays valid GitHub Markdown, where `<details>` also renders. Test in stage 3 with a local `build_home()`.

## 5. Before and after: one model page (`model-simple.qmd`, 119 lines)

### Before

```
# title  [front matter]
"One treatment, one mediator, one outcome: the model behind most mediation analyses. This page runs it three ways and reads
the result. Part of the Models collection; for a one-page lookup see the Reference Card."        <- 3 sentences, 2 links
| Structure | Class returned | Indirect effect | Routes |                                         <- 4 rows
## When to use it   (one paragraph, 3 links)
## Route 1 / Route 2 / Route 3   (3 code blocks)
## Reading the result  (table)
## Assumptions and limits  (4 bullets)
## Related   (4 links)                                                                            <- 4 next actions
```

### After

```
# Simple mediation
Models > Single mediator > Simple mediation                                    <- you are here (P7)
**For:** one treatment, one mediator, one outcome. **Gives you:** a, b, c', the indirect effect and its interval.   (P2)
| Structure | Class returned | Indirect effect | Availability | Routes |                           <- 5 rows, shared template
## Use it when / use something else when        <- a 2-column table, each "something else" a link (P3, P1)
| Use this page when | Use another page when |
|---|---|
| one mediator, continuous outcome | the mediator interacts with treatment: interaction; two mediators: serial, parallel |
## Run it  (Route 1 is the shortest; Routes 2 and 3 under "Other routes", same code)
## Read the result  (unchanged table)
## Assumptions and limits  (unchanged four bullets)
**Next:** Add an interval: Bootstrap Inference                                   <- one action (P1)
```

What changes: the lead drops from 3 sentences to 2 lines; "When to use it" becomes a table that routes away; the footer's four
links become one "Next" plus the existing navbar; all code chunks stay executable and identical (`test-model-pages.R` checks
links, anchors and navbar membership, not headings). What stays: file name, title, anchors for existing headings that other
pages link to (`#route-1-one-line` etc. are not linked from elsewhere; `grep 'model-simple.html#'` over `vignettes`, `README.md`, `_pkgdown.yml`, `R` and `tests` finds none).

## 6. Constraints respected

* pkgdown only: Markdown/Quarto, `_pkgdown.yml`, one `pkgdown/extra.css`; no JavaScript, no new dependency.
* Existing docs tests keep passing: `test-model-pages*`, `test-guide-*`, `test-refcard-coverage`, `test-cookbook-consistency`,
  `test-twolevel-docs`. New checks (P1, P5, P6, P7, P8, P9) are added in stage 4 as docs gates, each with a planted defect.
* URLs stable: no page renamed or moved; the Project menu and the articles split change navigation, not addresses.
* Not touched: anything with the "native" vocabulary beyond two section titles (#431), the private book, releases.

## 7. Decisions for the maintainer

1. Apply P1 to all 15 model pages (a `**Next:**` line), or only to the first four? Recommended: all 15; it is one line each.
2. Fold `qc`, `ecosystem`, `status` into a "Project" menu? Recommended: yes (P5).
3. Add `pkgdown/extra.css` (P8), or keep the default Bootstrap 5 theme? Recommended: add, 20 lines, and test contrast.
4. Home page order as in section 4, with the FIML and What's new blocks collapsed? Recommended: yes.

## 8. Rollout

Stage 3 applies the audit's stale fixes first (version words, README, NEWS), then the home page and `model-simple` as the
pilot, then the other 14 model pages by template. Stage 4 adds the gates P1, P5, P6, P7, P8, P9 beside the release-docs gates.
Not verified here: a rendered preview of the proposed pages (this stage changes no page).

## 9. Rendered pass on the live site (2026-11-12, https://data-wise.github.io/medfit/)

Method: built-in browser at 1280 px and 375 px (phone preset), DOM measurements by script, and a Lighthouse audit (mobile for
the home page, desktop for `model-simple`). Evidence, not opinion; "not verified" is listed at the end.

| # | Finding | Evidence | Fix in this proposal |
|---|---|---|---|
| F11 | **The first screen of the home page is the FIML paragraph and the What's new table, not install or an example.** | At 1280x800 the first-screen elements are the H1, three short paragraphs, H2 "Bounded FIML in 0.16.0", an 11-line paragraph, H2 "What's new" and its table. At 375x812 the screen is the badges, the lead and the first 9 lines of the FIML paragraph. | Section 4 (reorder); P4 |
| F12 | **"Pick your model" starts 4,594 px down an 8,639 px page** (53%); Install starts at 2,928 px, the 60-second example at 3,281 px. | `getBoundingClientRect` + `scrollY`, desktop. | Section 4 |
| F13 | **Body text is 14.8 px with a 22.2 px line, and a paragraph is about 776 px wide (about 105 characters).** The longest paragraph is 11 lines. | computed style of the first `main p`; the usual comfortable measure is 60 to 80 characters. | P8: base 16 px, 1.6 line height, `main` max width about 70 ch |
| F14 | **Model page: the first screen is mostly setup noise.** On `model-simple`, after the lead and the facts table, the first screen shows `library(medfit)`, "Attaching package: 'medfit'", the "masked from package:stats: decompose" message, `library(generics)` and its message, before any content. | first-screen elements and screenshot, 1280x800. | Stage 3: `#| include: false` (or `message: false`) on every setup chunk of the 15 model pages; a gate (stage 4) fails a model page whose first code output on screen is a package-attach message |
| F15 | **Contrast fails Lighthouse AA on both pages.** Home (mobile): the version label "0.17.0" in the navbar 2.57:1 (#909294 on #e9e9ea) and the developer role text 4.28:1. Model page (desktop): 10 nodes: the same version label and every navbar item 4.25 to 4.48:1 (#676a6d on #e9e9ea; the active "Models" button 4.25:1). Required 4.5:1. | Lighthouse `color-contrast`, axe 4.12. Scores: home mobile Accessibility 96, `model-simple` desktop 97. | P8: `pkgdown/extra.css` darkens the navbar text and `small.nav-text` to at least 4.5:1; the stage 4 gate computes the ratios from the CSS values |
| F16 | **No breadcrumb, no meta description on the model page, a layout shift on the home page.** Breadcrumb element absent on `model-simple`; Lighthouse `meta-description` fails there (SEO 92); home page CLS 0.114 (budget 0.1). The page does have a skip link ("Skip to contents"), one H1, a main landmark, an "On this page" list, and no horizontal overflow at 375 px (all tables 351 px wide). | DOM checks and Lighthouse. | P7 (breadcrumb); stage 3 adds a one-sentence `description:` to each model page's front matter, the same sentence as the lead; the CLS cause (the badges and logo load without reserved size) is an open item |

Confirmed good, keep: skip link, single H1, landmark, "On this page" list, no overflow on a phone, best-practices score 100.

Not verified here: keyboard focus order and a visible focus ring (a programmatic `focus()` shows no outline, which proves nothing
about `:focus-visible` with the keyboard; needs a manual Tab pass), screen-reader output, hover states of the menus, the dark-mode
theme, and the logo's `alt` (the script counts `alt=""` as missing; the logo is decorative). A Lighthouse run is a sample of one
load per page; the CLS figure varies by run.

### Additions to P-rules from the pass

* P8 gets numbers: base font at least 16 px; text measure at most 80 characters; navbar text and the version label at least 4.5:1;
  checked by a stage 4 gate on `pkgdown/extra.css` values plus a Lighthouse run in the release checklist (not CI).
* P10 (new): **no setup noise.** A model page's first screen shows its lead, facts table and first example, not package-attach
  messages (F14).
* Decision 5 for the maintainer: add `pkgdown/extra.css` with the contrast, font-size and measure rules (recommended: yes; it is
  the same file as decision 3).
