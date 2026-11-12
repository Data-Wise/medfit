# PLAN: 0.18.0 engine vocabulary, controls and provenance (2026-11-12)

**Decision record:** `planning/specs/ADR-engine-vocabulary-and-controls-2026-11-12.md` (V-1 to V-9, all decided by the author
on 2026-11-12). **Evidence:** `planning/AUDIT-engine-and-optimizer-2026-11-12.md`. **Status:** plan only; nothing is implemented.
**Starts after:** v0.17.0 is tagged and published (it is still waiting on main CI) and `main` is back-merged into `dev`.

## Principles

- Additive first: add the new spelling, keep the old one working, and change behavior only on the experimental class.
- One PR per slice to `dev`, squash, each independently green; test-first with a planted defect per behavior.
- No result changes: every slice leaves every existing fit's numbers identical (`identical()` or the existing
  tolerance), and says so in its PR body with a transcript (rules `e2e-before-pr`, `pre-pr-testing`).
- Release PRs follow the 0.17.0 lesson: `dev` never runs `R CMD check`, so each slice runs the strict flavors locally
  before the release PR (checklist `planning/PLAN-0.17.0-release-checklist-2026-11-11.md`).

## Slices

| # | Slice | Depends on | Touches | Risk |
|---|---|---|---|---|
| S1 | `engine = "sem"` (V-1, V-2): add the value, `"native"` stays a silent alias | none | `R/fit-glm.R` (`assert_choice`, dispatch, roxygen), `R/fit-sem.R` comments, `man/`, `tests/testthat/test-fit-sem.R`, `test-api-freeze.R` (additive row) | low |
| S2 | `control` accepts a list or `sem_control()` (V-5, V-6) | none on S1 (it no longer touches `fit-glm.R`); do not run beside any other change to `fit-sem.R` or `sem-optim.R`, or beside S5a roxygen edits in the same files | new `R/sem-control.R`, `R/fit-sem.R`, `R/sem-mbco.R`, `R/sem-fiml-interface.R` (the FIML guard), `R/sem-optim.R` (read the resolved optimizer), `NAMESPACE`, `_pkgdown.yml` reference, tests | **high by path** (seven-item checklist) |
| S3 | ~~`compare_lr(reference = )`~~ **deferred (V-3)**: docs-only clarification of what `engine` means | none | `R/compare-lr.R` roxygen, `man/` | low |
| S4 | `TwoLevelMediationData` provenance, additive (V-7) | none | `R/classes-twolevel.R`, `R/extract-lavaan-twolevel.R`, `man/`, `test-twolevel-*.R`, `test-dependents-contract.R` (add `source_version`, remove nothing), NEWS | low |
| S5a | Prose, titles and the Guides article (V-1, V-9) | S1, S2, S4 merged (names final) | `README.md`, `vignettes/articles/*.qmd` text and titles, `R/*.R` roxygen, `man/`, new `guide-engines.qmd`, `_pkgdown.yml`, `CLAUDE.md`, solver ADR pointer | low, wide |
| S5b | Pkgdown redirect spike, then URL renames (V-8, conditional) | S5a | the spike first; only if it passes: 12 article files, `_pkgdown.yml` (`articles:` and `redirects:`), the docs tests, links in NEWS and README | low, wide |
| S6 | `"nlminb"` and `"auglag"` values, `options(medfit.optimizer)` | D-4 gate measured | not scheduled | n/a |

S1 and S2 touch the same function, so they run in order. S3 and S4 are independent of each other and of S1 and S2, so they
can run beside them in separate worktrees. S5a and S5b wait for the names to be final so the prose is edited once.

### S1: `engine = "sem"`

- Accept `"sem"` in the `assert_choice` of `fit_mediation()` and dispatch it exactly as `"native"` is dispatched;
  normalize to one internal value so no other code compares to two strings.
- Roxygen: describe the engine as "the sem engine", list `"native"` as the legacy spelling; no warning.
- Tests: `fit_mediation(engine = "sem")` and `engine = "native"` give `identical()` results on the demo data; an unknown
  engine still errors with the same message shape; the freeze test gains the new value as an addition and still fails
  when a value is removed (planted defect).
- E2E: transcript of both spellings on `mediation_demo`, then `all.equal(coef(a), coef(b), tolerance = 0)`.

### S2: `control` accepts a list or `sem_control()` (the slice that needs care)

- **Compatibility first.** `control` already exists and is pinned: `fit_sem(control = list())` and `mbco_sem(control = )`
  take raw `nloptr` options, and `fit_mediation()` already forwards `control` through `engine_args` (`fit_args`,
  `R/fit-sem.R`). A plain list keeps today's meaning exactly (it is read as `sem_control(nloptr = <list>)`); FIML keeps
  requiring an empty list. No new top-level argument on `fit_mediation()`; the route stays `engine_args = list(control = )`.
- `sem_control(optimizer = "auto", n_starts = NULL, nloptr = list())` validates with `checkmate` and errors on an unknown
  name. `optimizer` is `"auto"` or `"slsqp"` for the listwise search; for a FIML fit only `"auto"` is legal (FIML's
  SLSQP-plus-`nlminb` agreement protocol is not selectable) and anything else is an error.
- **Normalize once, at entry.** A single internal `.sem_resolve_control(control, n_starts, estimator)` runs at the top of
  `fit_sem()` and `mbco_sem()` and returns (i) the plain `nloptr` options list and (ii) the resolved protocol. Everything
  downstream keeps receiving a **plain list**: `fit@internals$control` stays the raw `nloptr` list (written at
  `R/fit-sem.R:421`), `.sem_fit_syntax()`, `.sem_optimize()` (`opts[names(control)] <- control`, `R/sem-optim.R:384`),
  `.sem_reference_fit()` and the FIML `settings` are unchanged. `mbco_sem(control = )` (pinned, `NULL` default) accepts a
  list or `sem_control()` through the same helper, and its `fit@internals$control` fallback (`R/sem-mbco.R:182`) keeps working.
- **FIML.** The guard at `R/sem-fiml-interface.R:465` (`length(control)` non-zero, or `n_starts` not `NULL`/3) is applied to
  the **resolved** values, not to the object: `sem_control()` with all defaults and `optimizer = "auto"` resolves to an
  empty list and passes; any `nloptr` entry, a non-`"auto"` optimizer, or `n_starts` other than `NULL`/3 still errors with
  the existing message. The recorded FIML protocol carries `n_starts = 3`, the listwise one carries the resolved 5.
- Record the resolved **search protocol** in `fit@diagnostics$protocol` (not `control`: `fit@internals$control` already
  holds the raw `nloptr` options, and two slots named `control` with different meanings invite feeding a protocol record
  back in as `control`). It holds the estimator, optimizer(s), `n_starts`, start rule and a protocol version.
- Conflict rule: **supplied** is detected with `missing()`/`is.null()` on the call's own arguments, so an explicit `5` is
  distinguished from the defaulted 5. Top-level `n_starts` and `control$n_starts` both supplied and different is an error;
  supplied once, either works; neither gives the estimator's default (5 listwise, 3 FIML). The same rule applies to
  `mbco_sem(n_starts, control)`, which otherwise falls back to the stored `fit@internals$n_starts`.
- **Risk tier: high by path.** `R/sem-optim.R` and `R/fit-sem.R` are both in `tests/sim/risk-files.txt`, and
  `risk_check()` classifies a feature PR touching either as high risk by path regardless of the edit. The PR therefore
  carries the seven-item admission checklist, each item ticked or `n/a: <reason>` (independent oracle, reliability cell,
  planted defect, metamorphic invariance, fault injection, registration, platform run), and runs `tests/sim/risk-tier.R`.
  `risk_check(changed, risk_files, body, head_ref)` (`tests/sim/risk-lib.R:25`) returns not-high when `head_ref` is `dev` or
  no risk file changed, and otherwise passes only when each of the seven items in the **PR body** is ticked or `n/a` with a
  reason; so run it with the feature branch as `head_ref` and the real PR body, never with `dev`, and read a pass as the
  checklist being complete, not as the edit being safe. Expected `n/a` entries (objective and solver path unchanged) must
  each state why.
- Tests: a released call `control = list(maxeval = 20000L)` gives the identical fit before and after (written first, run
  on `origin/main` to pin the baseline); `mbco_sem()` on a fit made with `control = sem_control()` gives the same result
  as on a fit made with the equivalent plain list; FIML with `control = sem_control()` (all defaults) fits and
  `control = sem_control(n_starts = 5)` errors with the existing guard message; an explicit `n_starts = 5` plus
  `control = sem_control(n_starts = 7)` errors while the defaulted 5 does not; resolved protocol stored in
  `diagnostics$protocol`; `optimizer = "auto"` and `"slsqp"` give `identical()`
  listwise fits; FIML with a non-`"auto"` optimizer errors; typo and conflict errors; the frozen SLSQP fixtures (1e-6)
  unchanged; `test-api-freeze.R` still passes with the argument list unchanged.
- E2E: four fits (listwise `auto`, listwise `slsqp`, listwise with a legacy list, FIML `auto`) with `identical()` and the
  recorded protocol printed.

### S3: `compare_lr()` (deferred, docs only)

- V-3 is deferred: `engine` is the pinned third positional argument and the result's `$reference` already means medfit's
  LR, so no rename now. Roxygen and the lavaan-comparison article say `engine` is "the external comparison program
  (lavaan or OpenMx), not a fitter of the mediation model". Do not change what the function computes (#320 is open).
- Revisit after #320 with the argument, positional and result-field contracts together (candidates `against`, `program`).

### S4: provenance (additive)

- Add `source_version` (constructor, `print()`, `summary()`, `provenance`); open the `source_package` and `source`
  validators to any non-empty string; keep `source` and `lavaan_version` as **stored properties that stay valid constructor
  arguments** for one deprecation cycle, filled from `source_package` and `source_version` when omitted, with a validator
  that errors when a supplied value disagrees with them. They are not getter-only (read-only) S7 properties: released calls
  `TwoLevelMediationData(source = , lavaan_version = , ...)` and the contract table pin them as constructor inputs. The
  extractor sets all four.
- Tests: the existing `test-twolevel-*.R` provenance assertions still pass unchanged; new assertions cover
  `source_version`; an object with an unknown fitter string is valid; an empty string is rejected;
  `test-dependents-contract.R` gains `source_version` and **removes nothing**. Check `twolevel_statistic()` and the
  bootstrap callers and any saved-object round trip (`saveRDS()` then `readRDS()` of a 0.17.0 object).
- NEWS: an additive note under the experimental label; the two-level model page's provenance wording.

### S5a: prose, titles and the guide (a docs PR, separate from every API PR)

- **Inventory first, by type**, before any edit: (a) current prose in articles, README, roxygen (change); (b) historical
  NEWS entries (keep); (c) quoted error and warning text (keep while the alias exists: native-route errors name the
  accepted spelling, `R/fit-glm.R`, `R/fit-sem.R`); (d) condition classes (keep); (e) snapshots and test names (change
  only with the code they pin); (f) ADR and GRILL files (keep); (g) the `native-defaults-0-15` body (keep). Preview each
  replacement set with `grep` before and after; no blanket `replace_all`.
- Titles and prose say "sem engine"; URLs do not change in this slice.
- New `vignettes/articles/guide-engines.qmd` "Which engine should I use?": engine, then estimator, then optimizer; the
  four-layer table; it defines "the sem engine" as **medfit's own SEM fitter** (`fit_sem()`, `engine = "sem"`) and keeps
  the lavaan extraction route visibly distinct (readers may read "sem" as lavaan's `sem()`); links from the landing page and
  the Models page; `test-refcard-coverage.R` and the guide tests updated.
- `CLAUDE.md` engine table and prose; one-line pointer at the top of the solver ADR.

### S5b: pkgdown redirect spike, then renames (conditional)

- **Spike first** (a throwaway branch and a local `pkgdown::build_site()`): does the installed pkgdown support
  `redirects:` for `articles/` paths, and does an old `#fragment` (for example `native-guide.html#bounded-fiml`) land on
  the right section after the redirect? Record the result in the plan.
- Only if both hold: `git mv` the 12 files, update the `_pkgdown.yml` menu and `articles:`, add `redirects:` for every old
  URL, update links in README, NEWS (current entries only), `guide-changes`, the cookbook, the model pages and the tests
  that assert them (`test-native-defaults-article.R`, the model-page tests); verify the old URLs on the built site and in the
  deployed site after the release. If anchors do not survive, keep the URLs and stop.

## Verification and release

1. Each slice: touched tests, then the full suite in the slice's own worktree, lint on an isolated install, and
   `Rscript tests/sim/risk-tier.R`; PR body quotes the transcript and counts.
2. Before the 0.18.0 release PR: the strict `R CMD check` flavors, `urlchecker`, `spelling`, the dependent suites
   (`probmed`, `RMediation`, `missingmed`) against the candidate, and a site build.
3. Release as 0.18.0 (minor, additive; GitHub-only, CRAN on hold). NEWS lists the sem engine, `sem_control()` and the
   list-or-object `control`, the additive provenance change on the experimental class, and (only if S5b passes) the
   renamed pages with redirects.
4. After release: soft deprecation of `engine = "native"` is scheduled for the next minor (V-2); the `source` and
   `lavaan_version` aliases follow (V-7); `compare_lr()` naming waits for #320 (V-3).

## Out of scope

- S6 (`"nlminb"`, `"auglag"`, `options(medfit.optimizer)`): waits for the D-4 gate.
- The native two-level fitter (#394 S4 and S5): V-7 only prepares the provenance slot for it.
- Editing the private `medfit-book` repo (its `engine = "native"` calls keep working through the alias).
- Any change to numerical results, the solver path, or CRAN.

## Open items before S1 starts

1. Listwise attempts: do they record which optimizer ran? (ADR section 6, item 1)
2. pkgdown `redirects:` support and anchors (item 4): a spike, gates S5b only.
3. Saved-object compatibility and external users of `engine = "native"` (item 6): a `saveRDS()` round trip of a 0.17.0
   fit; local checkouts were searched, external users were not.

Resolved by the Codex review (ADR section 7): the `control` route (existing `engine_args`), what the freeze pins, and the
dependents-contract rows.

## Revision note

2026-11-12, after the Codex adversarial review (ADR section 7): S2 rewritten around the existing pinned `control` and
re-tiered high by path; S3 deferred; S4 made additive; S5b gated on a spike; S5a split from API work and inventoried by
type. No code has been written.
