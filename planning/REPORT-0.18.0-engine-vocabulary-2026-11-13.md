# REPORT: 0.18.0 engine vocabulary, controls and provenance (2026-11-13)

**Source:** `planning/PLAN-0.18.0-engine-vocabulary-2026-11-12.md` + `planning/specs/ADR-engine-vocabulary-and-controls-2026-11-12.md`
**Status:** 🟡 Plan only. Nothing implemented, no code written. Precondition met: v0.17.0 tagged 2026-11-12 and `main` back-merged into `dev` (#433).

## tl;dr

| Metric | Value |
|---|---|
| Decisions | 9 (V-1 to V-9): 7 decided, 1 deferred (V-3), 1 conditional (V-8) |
| Slices | 7 (S1, S2, S3, S4, S5a, S5b, S6); S6 not scheduled |
| High-risk slices | 1 (S2, high by path) |
| Review findings accepted | 19 (9 + 2 Codex, 8 `/code-review`) |
| Open items before S1 | 3 |

**One line:** rename "native" to "the sem engine" additively, let `control` take a list or `sem_control()`, add `source_version`, and change no numbers.

## Principles

- **Additive first.** New spelling added, old one keeps working; behavior changes only on the experimental class.
- **One PR per slice** to `dev`, squash, each green; test-first with a planted defect per behavior.
- **No result changes.** Every existing fit stays `identical()` (or within existing tolerance); the PR body says so with a transcript.
- **Strict checks locally.** `dev` never runs `R CMD check`, so run the strict flavors before the release PR.

## The four layers (swap test)

| Layer | Question | Examples | Swap changes the meaning? |
|---|---|---|---|
| Engine | which fitter | `glm`, `regmedint`, `lmer`, `sem` | yes |
| Estimator | what is minimized | OLS, REML, listwise ML, bounded FIML | yes |
| Optimizer | which algorithm finds the minimizer | SLSQP, `nlminb`, AUGLAG | no |
| Inference | how uncertainty is computed | delta, sandwich, bootstrap, MBCO | the interval, not the estimate |

## Slices

| # | Slice | Depends on | Risk |
|---|---|---|---|
| S1 | `engine = "sem"`; `"native"` silent alias | none | low |
| S2 | `control` takes a list or `sem_control()` | none on S1; never beside other `fit-sem.R`/`sem-optim.R` edits | **high by path** |
| S3 | `compare_lr()` docs only (V-3 deferred) | none | low |
| S4 | `TwoLevelMediationData` gains `source_version` | none | low |
| S5a | Prose, titles, new `guide-engines.qmd` | S1, S2, S4 merged | low, wide |
| S5b | pkgdown redirect spike, then 12 renames | S5a; spike must pass | low, wide |
| S6 | `"nlminb"`, `"auglag"`, `options(medfit.optimizer)` | D-4 gate | not scheduled |

**Order:** S1 → S2 (same function). S3 and S4 run beside them in separate worktrees. S5a, S5b wait for final names.

### S2 at a glance (the slice that needs care)

- `.sem_resolve_control(control, n_starts, estimator)` normalizes once, at the top of `fit_sem()` and `mbco_sem()`.
- Everything downstream still receives a **plain list**; `fit@internals$control` stays the raw `nloptr` list.
- FIML guard (`R/sem-fiml-interface.R:465`) checks the **resolved** values; default `sem_control()` passes.
- Resolved protocol stored in `fit@diagnostics$protocol`.
- `n_starts` conflict: both supplied and different → error; "supplied" detected with `missing()`/`is.null()`.
- PR body carries the seven-item checklist: oracle, reliability cell, planted defect, metamorphic, fault injection, registration, platform.

## Decision cards

**V-1. The sem engine**
- **Concept:** name the in-package ML fitter for lavaan-style syntax.
- **Issue:** "native" names who wrote it, not what it fits; the `glm` engine is in-package too.
- **Solution:** "the sem engine", `engine = "sem"`; matches `fit_sem()`, `SEMFit`, `mbco_sem()`.
- **Impact:** covers listwise ML, bounded FIML and a future two-level fitter with no further rename. Rejected: `path`, `system`, `ml`, `joint`, `builtin`, `native`.

**V-2. Alias policy**
- **Concept:** keep old code working.
- **Issue:** `engine = "native"` is in released calls and the private `medfit-book`.
- **Solution:** `"native"` accepted silently in 0.18.0; soft deprecation one minor later; removal only with a `[BREAKING]` issue and two months' notice.
- **Impact:** no dependent breaks (local checkouts checked; external users and saved objects not checked).

**V-3. `compare_lr()` — deferred**
- **Concept:** `engine` there means the external comparison program.
- **Issue:** `engine` is the pinned third positional argument; `$reference` already means medfit's LR; #320 is open.
- **Solution:** keep `engine` in 0.18.0, document it as "the external comparison program (lavaan or OpenMx)".
- **Impact:** revisit after #320 (candidates `against`, `program`).

**V-4. One engine, two estimators**
- **Concept:** listwise ML and bounded FIML.
- **Issue:** should FIML be its own engine?
- **Solution:** no; `missing = "listwise" | "fiml"` stays the switch; "estimator" is doc vocabulary only.
- **Impact:** no new argument; FIML stays labeled bounded, not statistically admitted.

**V-5. Controls**
- **Concept:** one home for optimizer tuning.
- **Issue:** `control` already exists and is pinned as raw `nloptr` options.
- **Solution:** `control` accepts a plain list (read as `sem_control(nloptr = <list>)`) or `sem_control(optimizer = "auto", n_starts = NULL, nloptr = list())`. `optimizer` is `"auto"`/`"slsqp"` for listwise; FIML allows only `"auto"`.
- **Impact:** every released call keeps working; one new export; adding AUGLAG or `nlminb` later never changes a signature.

**V-6. Argument design rules**
- **Concept:** six rules for future arguments.
- **Issue:** meaning-changing options were mixed with tuning knobs and session options.
- **Solution:** (1) meaning-changing → top-level, tuning → `control`; (2) strings, not logicals; (3) `"auto"` default + recorded protocol; a default move that can change estimates is **result-affecting**; (4) constructor validates; (5) `options(medfit.*)` only for tuning, with three options grandfathered; (6) experimental values announce once per session.
- **Impact:** defaults can move without API changes, but not without a protocol version bump, NEWS note and gate evidence.

**V-7. `TwoLevelMediationData` provenance**
- **Concept:** record which package and version fitted the model.
- **Issue:** `source` duplicates `source_package`; `source` and `lavaan_version` are pinned in the dependents contract.
- **Solution:** add `source_version`; open validators to any non-empty string; keep `source`/`lavaan_version` as stored, valid constructor arguments for one cycle; `source` and `source_package` independent (no agreement check); `source_version` optional, filled from `lavaan_version` for lavaan fits.
- **Impact:** additive; contract table gains a row, removes nothing; reverses the grill's "drop `source`".

**V-8. Renames — conditional**
- **Concept:** article URLs say `native-*`.
- **Issue:** redirects and `#fragments` unverified; README links to `native-guide.html#bounded-fiml`.
- **Solution:** 0.18.0 changes titles and prose only; the 12 file renames happen only if a pkgdown spike passes.
- **Impact:** if anchors do not survive, URLs stay and nothing is renamed.

**V-9. Where this lives**
- **Concept:** decision record vs user guide.
- **Issue:** users need a short answer, maintainers need the reasoning.
- **Solution:** the ADR is the record; a Guides article "Which engine should I use?" answers engine, estimator, optimizer.
- **Impact:** linked from the landing and Models pages; solver ADR gets a one-line pointer.

## Review findings (all accepted)

### Second Codex review, S4 (2, 2026-11-13)

| # | Sev | Finding | Fix |
|---|---|---|---|
| 1 | High | `source`/`source_package` agreement check rejects valid `source = "native"` + `source_package = "lavaan"` | fields independent, no check; regression test |
| 2 | Med | no legacy path for calls without `source_version` | optional, filled from `lavaan_version`; old-signature test |

### Codex adversarial review (9)

| # | Sev | Finding | Fix |
|---|---|---|---|
| 1 | High | `control = list()` exists and is pinned | V-5: list or `sem_control()` |
| 2 | High | `source`, `lavaan_version` pinned in dependents contract | V-7: additive |
| 3 | High | S2 high risk by path | seven-item checklist |
| 4 | Med | `fit_mediation()` already forwards `control` | no top-level argument |
| 5 | Med | FIML runs both solvers; "auto" can move estimates | V-5 scope, V-6 rule 3 |
| 6 | Med | `engine` pinned 3rd arg; `$reference` collision | V-3 deferred |
| 7 | Med | redirects/anchors unverified | V-8 conditional |
| 8 | Med | prose blast radius understated | S5a inventory by type |
| 9 | Low | "sem" may read as lavaan's `sem()` | guide defines it |

### `/code-review` of revised docs (8)

| # | Finding | Fix |
|---|---|---|
| 1 | MBCO refits re-consume stored `control` | normalize once at entry |
| 2 | FIML guard rejects non-empty `control` | guard on resolved values |
| 3 | Read-only S7 aliases break constructor calls | stored properties + consistency validator |
| 4 | `diagnostics$control` collides with `internals$control` | renamed `diagnostics$protocol` |
| 5 | V-6 rule 5 contradicts shipped options | grandfather clause |
| 6 | S2 dependency on S1 stale | plan table corrected |
| 7 | Risk-gate call described inexactly | `risk_check()` inputs stated |
| 8 | `n_starts` conflict ignores `mbco_sem()` and defaulted 5 | detect "supplied" explicitly |

## Out of scope

- S6 (waits for the D-4 gate) · native two-level fitter (#394 S4/S5) · editing `medfit-book` · any numerical, solver-path or CRAN change.

## Next steps

1. **Close the 3 open items before S1:** (a) do listwise attempts record which optimizer ran? (b) pkgdown `redirects:` + anchors spike (gates S5b only); (c) `saveRDS()` round trip of a 0.17.0 fit, external users of `"native"`.
2. **S1** `engine = "sem"`, then **S2** `sem_control()`; S3 and S4 in parallel worktrees.
3. **Each slice:** touched tests → full suite in its worktree → lint on an isolated install → `Rscript tests/sim/risk-tier.R`; PR body quotes transcript and counts.
4. **S5a** prose and guide, then **S5b** if the spike passes.
5. **Before release PR:** strict `R CMD check` flavors, `urlchecker`, `spelling`, `probmed`/`RMediation`/`missingmed` suites, site build.
6. **Release 0.18.0** (minor, additive, GitHub-only; CRAN on hold).
7. **After release:** schedule `"native"` soft deprecation (next minor), then the `source`/`lavaan_version` aliases; `compare_lr()` naming after #320.
