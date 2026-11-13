---
decisions:
  - {id: RD-1, title: "Every documentation surface has one owner and one moment it changes", status: proposed, date: 2026-11-12}
  - {id: RD-2, title: "Version words come from DESCRIPTION; prose names a version only where a gate checks it", status: proposed, date: 2026-11-12}
  - {id: RD-3, title: "Release docs gates live in the test suite (docs tier), not in a new workflow", status: proposed, date: 2026-11-12}
  - {id: RD-4, title: "NEWS opens with the release heading and carries no stale wording in a release", status: proposed, date: 2026-11-12}
  - {id: RD-5, title: "README and articles name the DESCRIPTION version and say nothing of a development version in a release", status: proposed, date: 2026-11-12}
  - {id: RD-6, title: "README has a What's new block for the version; CITATION reads the version", status: proposed, date: 2026-11-12}
  - {id: RD-7, title: "CLAUDE.md and .STATUS status lines name the released version", status: proposed, date: 2026-11-12}
  - {id: RD-8, title: "The FIML caveat is a marker on the home page and the FIML page, not a counted phrase", status: proposed, date: 2026-11-12}
  - {id: RD-9, title: "Layout rules that can fail are tests: Next block, hidden setup, short navbar, readable colors, documented exports", status: proposed, date: 2026-11-12}
  - {id: RD-10, title: "What stays manual: release notes review, rendered-site inspection, Lighthouse, external URLs", status: proposed, date: 2026-11-12}
---

# ADR: how medfit documents are created and updated for every release

Status: PROPOSED, 2026-11-12 (stage 4 of the docs pipeline; the maintainer has not accepted it). Inputs:
`planning/AUDIT-docs-and-site-2026-11-12.md` (F1 to F17), `planning/PROPOSAL-docs-adhd-design-2026-11-12.md`. Scope guard: the
native-to-sem vocabulary belongs to `ADR-engine-vocabulary-and-controls-2026-11-12.md`; this ADR names no engine words.

## Context

After 0.17.0 the audit found stale statements in six surfaces (README "Bounded FIML in 0.16.0" and "Website publication",
NEWS "unreleased", "development version" in five articles, status lines in CLAUDE.md and `.STATUS`). Every one was a place a
release step had no owner, and no test noticed. One of the new gates found a further, real gap on its first run: the FIML page
did not carry the "not statistically admitted" caveat the home page and NEWS carry.

## Decisions

**RD-1. Owner and moment per surface.**

| Surface | Format | Created or changed | Owner | Checked by |
|---|---|---|---|---|
| `DESCRIPTION` Version/Date | DCF | release prep (R1), never in a feature PR | release engineer | the gates below read it |
| `NEWS.md` | Markdown | each feature PR adds a bullet under the top heading; R1 collapses the section and sets "# medfit X.Y.Z" | feature author, then release engineer | RD-4 |
| `README.md` | Markdown, home page | layout changes by design PR; "What's new in X.Y.Z" at R1 | release engineer | RD-5, RD-6, RD-8 |
| `vignettes/articles/*.qmd` | Quarto | with the feature; version claims ("documents medfit X") at R1; `guide-changes` row at R1 | feature author; release engineer for version claims | RD-5, `test-guide-changes` |
| roxygen and `man/` | Rd | in the feature PR; `document()` before the PR | feature author | the export gate (RD-9), `check_pkgdown()` |
| `inst/CITATION` | R | derived from `DESCRIPTION`, never edited per release | none | RD-6 |
| `.STATUS`, `CLAUDE.md` status lines | text | R1 and again right after the release (tag, release URL) | release engineer | RD-7 |
| `cran-comments.md` | Markdown | only for a CRAN submission; header says historical until then | CRAN submitter | none (header stays) |
| GitHub release notes | web | R9, derived from the NEWS release summary (first section of the top release) | release engineer | manual (RD-10) |
| `planning/` ADRs and plans | Markdown | when a decision is made | the decider | `test-adr-front-matter` |

**RD-2. One source for versions.** `DESCRIPTION` is the only place a release number is typed. CITATION reads it; the home page
and articles say "0.X.Y" only in sentences a gate checks (`documents/describes medfit X.Y.Z`, `What's new in X.Y.Z`).
Elsewhere write the feature, not the version, or link to NEWS.

**RD-3. Gates are tests.** The cheapest place a failing check is always seen is `devtools::test()` (local and the hosted lint
and risk-tier jobs do not run it; the maintainer's local gate does, and release step R2 runs the full suite). New file:
`tests/testthat/test-docs-release.R`. No new workflow, no new dependency. Each gate is a pure function over text with a planted
defect in the same file that must make it report a problem (the rule used by `test-adr-front-matter.R`).

**RD-4. NEWS.** The first `# ` heading is `# medfit <DESCRIPTION version>`. When the version is a release (three parts), that
section contains neither "unreleased" nor "development version". A development version (`0.17.0.9000`) may keep them.

**RD-5. README and articles.** A sentence that says a page "documents" or "describes" medfit X.Y.Z must name the DESCRIPTION
version. In a release, README and `vignettes/articles` contain neither "development version" nor "unreleased".

**RD-6. Home.** README contains `What's new in <version>` (inside a `<details>`), and `inst/CITATION` takes its version from
`meta$Version` (a hard-coded `R package version 0.x` fails).

**RD-7. Status lines.** The `**Current status:**` line of `CLAUDE.md` names the DESCRIPTION version in its first 160
characters, and `.STATUS` mentions it in its newest 40 lines.

**RD-8. The FIML caveat.** Per the maintainer's note (a), no page count: the phrase "not statistically admitted" must appear
in README and in `model-fiml.qmd`. A single-source include is better but needs a Quarto/pkgdown include that README (plain
Markdown) cannot share; revisit if the caveat grows.

**RD-9. Layout rules that fail.** Every model page except those on `native_pending` has a `{.next-action}` block and a hidden
setup chunk (`#| include: false`); the navbar has at most 8 top-level items; every color in `pkgdown/extra.scss` has at least
4.5:1 contrast against `#d9dadb` (the darkest navbar background measured); every `export()` in `NAMESPACE` has an Rd alias.
`native_pending` lists the five `model-native*` pages until the sem prose slice (PR #431 plan, S5a) lands; deleting that list
is the rollout check. `pkgdown::check_pkgdown()` (the reference index covers every topic) stays as the index gate.

**RD-10. Manual.** Release-notes review (R9), the rendered-site inspection and link check (R4), a Lighthouse pass, keyboard
focus and screen-reader checks, external URL liveness (`urlchecker`) and spelling stay in the release checklist. They need a
browser or the network and do not fail deterministically.

## Consequences

* A release cannot reach `main` with a stale "unreleased", a wrong version claim, a missing What's new block, or a status
  line that skipped the bump: the full suite (checklist R2) fails first.
* `docs-sync` skills and agents are not added: R1 is one checklist row and the gates catch what it misses.
* The gates read the real files, so a harmless edit (a new "documents medfit" sentence with the old version) fails fast.
* Not covered: a feature described in NEWS but not in the docs (needs a feature manifest; deferred), links that resolve to the
  wrong page, and the rendered result.

## Rejected

* A GitHub Actions docs workflow: duplicates the suite and runs only after push.
* A `docs-sync` agent as a gate: an agent is not deterministic; the tests are.
* Counting how many pages say a given phrase (brittle; see RD-8).
