# SPEC: bundled example data for medfit

**Date:** 2026-09-23 · **Status:** proposed · **Branch:** `dev` (this spec is doc-only; implementation
needs a `feature/*` worktree per this repo's own branch-guard rules)
**Origin:** requested directly ("create a plan to include data in the medfit package; check
mediationverse packages and identify gaps for the bppk" — confirmed "bppk" = medfit itself).
**Depends on:** nothing blocking; independent of the open 0.4.0 CRAN-submission decision in `.STATUS`.

---

## 1. Problem

medfit is the only package at the base of the mediationverse dependency graph that ships **zero**
bundled data. A full read-only survey of all seven packages (2026-09-23) found:

| Package | `data/` | `data-raw/` | `LazyData` | Real dataset(s) |
|---|---|---|---|---|
| **medfit** | no | no | **not set** | **none** |
| mediationverse | no | no | not set | none (meta-package, expected) |
| medrobust | yes (3 `.rda`) | no (uses `inst/scripts/`) | true | `gesthtn`, `heals_data`, `nhanes_pa` |
| medsim | no | no | not set | none (simulation engine, expected) |
| missingmed | no | no (only a logo script) | true (**inert** — no data) | none |
| probmed | yes (1 `.rda`) | yes | true | `multilevel_designs` |
| rmediation | yes (1 `.rda`) | yes | true | `memory_exp` |

Every package that ships a substantive fitting/analysis feature (medrobust, probmed, rmediation)
bundles at least one real, cited dataset, documented via `data-raw/<name>.R` →
`data/<name>.rda` → `man/<name>.Rd` (`\docType{data}`, `\keyword{datasets}`, `\source` naming real
or honestly-labeled-synthetic provenance). medfit alone has no example data, no `LazyData` field,
and — checked in full — **no prior planning trace anywhere** (`.STATUS`, `CLAUDE.md`, `NEWS.md`,
`planning/`) that this gap was ever noted.

The visible cost: all four of medfit's own vignettes (`getting-started`, `introduction`,
`extraction`, `bootstrap`) and its README build data inline with `set.seed()` + `rnorm()` at
render time, every time. That's fine for a one-off demo but means:

- No single canonical example a user can `data(...)` and follow along with outside a vignette.
- Every vignette re-derives its own toy scenario, so the four read as four unrelated demos rather
  than one running example shown from four angles.
- `R CMD check --as-cran` reproducibility rests entirely on `set.seed()` calls staying correct as
  vignettes are edited — a bundled, version-controlled `.rda` removes that fragility for at least
  the primary example.

## 2. Non-goals

- **Not a real-world dataset with external provenance.** medfit's own stated principle is
  "infrastructure, not effect sizes" (`CLAUDE.md:47`) — it makes no substantive claim about any
  domain, so there is no reason to search for or license a real study's data. The dataset is
  **synthetic by design**, generated with a documented `set.seed()`, and its `\source` field says
  so plainly. (medrobust's `heals_data` is the ecosystem's existing precedent for this — "synthetic
  ... generated using methods described in the package vignette" — not a novel choice here.)
- **Not a reuse of `rmediation::memory_exp`.** medfit sits *below* RMediation in the dependency
  graph (RMediation `Suggests: medfit`), so medfit cannot depend on RMediation for its own example
  data without an awkward, unnecessary reverse dependency. Each package's data stays with its own
  layer.
- **Not a fix for missingmed's inert `LazyData: true` or medrobust's broken `arsenic_synthetic`
  README reference.** Both are real findings from this same survey (§6) but belong to their own
  packages' own planning, not this spec.
- **Not a CRAN-submission decision.** Independent of whether/when 0.4.0 goes to CRAN (open item in
  `.STATUS`); this can land in whichever release follows.

## 3. Decisions

**One dataset, not several — designed to serve all four existing vignette themes.** A single
`.rda` covering serial, parallel, and interaction structures at once lets the vignettes share one
running example instead of four disconnected toy scenarios, mirroring how medrobust's `gesthtn`
serves three of its vignettes.

**Shape** (synthetic; n = 250, one row per unit):

| Column | Role | Type | Used by |
|---|---|---|---|
| `treatment` | X | binary (0/1) | all four vignettes |
| `mediator1` | M1 | continuous | getting-started, introduction, extraction (serial: `treatment -> mediator1`) |
| `mediator2` | M2 | continuous | extraction (serial: `mediator1 -> mediator2`; parallel: `treatment -> mediator2` independently of M1) |
| `moderator` | W | binary | extraction, interaction demos (`treatment * mediator1` term) |
| `covariate1`, `covariate2` | C | continuous, binary | all four (covariate-adjusted fitting, the realistic case) |
| `outcome` | Y | continuous | all four |

Column names spelled out (`treatment`, not `X`) rather than single letters, matching this
ecosystem's existing convention (`gesthtn`'s and `memory_exp`'s documented columns are named, not
lettered) and making `formula_y = outcome ~ treatment + mediator1` self-explanatory in a vignette
without a lookup table.

**A plausible, clearly-fictional cover story**, generated once and reused: a workplace-training
scenario (training assignment -> skill confidence -> job performance, with supervisor support as a
second, parallel mediator, and tenure as a moderator of the confidence path). Chosen only for
concreteness in prose and `\examples`; the `\source` field states outright that it is simulated for
package demonstration and describes no real study, study population, or claim.

**Naming:** `mediation_demo` — descriptive, and distinct from every existing name in the ecosystem
(`gesthtn`, `heals_data`, `nhanes_pa`, `multilevel_designs`, `memory_exp`) so a user working across
packages never confuses which package a dataset came from.

## 4. Implementation surface

Follows the ecosystem's own established convention exactly (medrobust/probmed/rmediation all use
this shape; medrobust's `inst/scripts/` variant is not used here since medfit has no reason to
depart from the more common `data-raw/` placement probmed and rmediation already use):

1. **`data-raw/mediation_demo.R`** — generation script: `set.seed()`, the DGP for all six columns
   (confidence <- f(training, tenure, noise); performance <- f(training, confidence,
   support, covariates, noise); etc.), ending in `usethis::use_data(mediation_demo, overwrite =
   TRUE)`. Comment block at the top states plainly this is synthetic and documents the generating
   equations so the `\source` field and the script agree.
2. **`data/mediation_demo.rda`** — built by running the script above; not hand-edited.
3. **`man/mediation_demo.Rd`** — `\docType{data}`, `\keyword{datasets}`, full `\format` (all six
   columns, types, ranges), `\source` stating "Simulated data for package demonstration; not drawn
   from or representing any real study," and `\examples` showing `data(mediation_demo);
   fit_mediation(outcome ~ treatment + mediator1, mediator1 ~ treatment, data = mediation_demo,
   treatment = "treatment", mediator = "mediator1")`.
4. **`DESCRIPTION`** — add `LazyData: true` (currently absent).
5. **Vignettes** — replace at least `getting-started.qmd`'s inline `rnorm()` block with
   `data(mediation_demo)`; `extraction.qmd` and `bootstrap.qmd` follow once the base example is
   settled (can land in a follow-up commit within the same feature branch rather than blocking on
   rewriting all four at once).
6. **`NEWS.md`** — new entry under the next unreleased version.
7. **README.md** — while touching this file, also fix the two stale items this survey found
   (§6): the ecosystem table listing probmed/medrobust/medsim as "future" packages when all three
   already depend on medfit, and the citation block's stale `version 0.2.1` (actual: 0.4.0 at time
   of writing). Small, unrelated to the data addition, but cheap to fold into the same PR since the
   file is already open.

**Standard package checklist** before PR: `devtools::document()`, `R CMD check --as-cran` (per
`CLAUDE.md`'s CRAN check practice), pkgdown rebuild if the site publishes on push-to-main.

**Branch:** create via `git worktree add ~/.git-worktrees/medfit/feature-bundled-example-data -b
feature/bundled-example-data dev` — this repo's own convention (multi-branch, craft-style:
`main` <- `dev` <- `feature/*`), and per this project's standing rule, feature code never lands
directly on `dev`.

## 5. Acceptance criteria

- `data(mediation_demo, package = "medfit")` loads a 250-row, 6-column data frame matching §3's
  shape, reproducibly (`data-raw/mediation_demo.R` regenerates byte-identical output).
- `man/mediation_demo.Rd` passes `R CMD check --as-cran` with no dataset-documentation NOTE (the
  same `\docType{data}`/`\keyword{datasets}`/`\format`/`\source` shape medrobust and rmediation
  already pass CRAN with).
- At least one existing vignette (`getting-started.qmd`) runs its worked example against
  `mediation_demo` instead of `rnorm()`, and its rendered output changes accordingly (numbers will
  differ from the current ad hoc simulation — expected, not a regression).
- `DESCRIPTION` carries `LazyData: true`.
- README's ecosystem table and citation-version line are corrected (§4 item 7).

## 6. Related findings from this survey (not this spec's scope — flag, don't fix here)

- **missingmed** has `LazyData: true` set in `DESCRIPTION` with no `data/` directory to back it —
  an inert flag, likely leftover scaffolding. Worth a one-line fix in that repo, independently.
- **medrobust**'s `README.md:88` Quick Start example calls `data("arsenic_synthetic")`, a dataset
  that does not exist anywhere in that package (`data/`, `man/`, or R source) — almost certainly a
  stale reference predating `heals_data`'s current name. Breaks the README's own quick-start
  example today, independent of anything in this spec.
