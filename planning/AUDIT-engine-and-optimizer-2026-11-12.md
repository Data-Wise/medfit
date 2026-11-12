# AUDIT: the fit engine, the optimizer, and the word "native" (2026-11-12)

Read-only audit of `origin/main` at `6b9a943c` (the 0.17.0 merge). Nothing in `R/`, `tests/` or the docs was changed.
Numbers are from `git grep` on that tree unless a source is named. Status: input to a grill; no decision recorded.

## 1. Bottom line

"Native" names **where the code lives** ("medfit fits this itself, no other SEM package"), not **what it does**. It is
used in five senses, one of them for something that does not exist yet. A reader of the site cannot tell what it
means, and the claim it implies is loose (the fitter depends on nloptr and `stats::nlminb`). The user-facing
object is a maximum-likelihood SEM fitter, so a name that says so (`sem`) already matches `fit_sem()`, `SEMFit`
and `mbco_sem()`.

## 2. The five senses of "native" (user-facing and internal)

| # | Sense | Where | Count / evidence |
|---|---|---|---|
| 1 | A string value of an argument | `fit_mediation(engine = "native")` (`R/fit-glm.R:263`); frozen by `tests/testthat/test-api-freeze.R` since 0.11.0 | the only API surface |
| 2 | The in-package ML fitter for lavaan-style syntax | prose "native engine" 106x, "native fit" 40x, "native SEM" 21x, "native maximum-likelihood" 9x | `R/sem-*.R`, `fit-sem.R`, `extract-sem.R`, `methods-sem.R`, `compare-lr*.R`, FIML files: about 9,300 lines in 23 files |
| 3 | A set of defaults | "native defaults" (0.15.0 flip of `fixed_x`, `meanstructure`), `R/native-defaults.R`, `native-defaults-0-15.qmd` | a property of the fitter's defaults, not a kind of engine |
| 4 | A future fitter | `TwoLevelMediationData@source %in% c("lavaan", "native")` (`R/classes-twolevel.R:178`); "native two-level fitter" (S4/S5, #394) | **does not exist**; the validator accepts a value no code produces |
| 5 | Page and file names | `native-guide`, `native-quickstart`, `native-tutorial`, `model-native*` (5 pages), `native-defaults-0-15` | 12 article files; `_pkgdown.yml` 41 mentions |

Totals of the word (case-insensitive): `R/` 70, `tests/` 531, `vignettes/` 268, `man/` 19, `README.md` 19, `NEWS.md` 75,
`planning/` 862. The ADR of 2026-10-23 already proposed the prose name "built-in SEM engine" (and kept the argument
string frozen). The docs use "built-in" once and "native" about 250 times: the proposal was never adopted.

## 3. What the engine is (the architecture that the name hides)

Five layers, each with its own vocabulary. Users meet only the first and last.

1. **Model.** Syntax (`R/sem-parse.R`, `sem-expr.R`) to a RAM model (`sem-model.R`, `sem-factor.R`): observed and latent
   variables, labels, `:=`, constraints, the `x:m` product term, categorical covariates.
2. **Objective (the estimator).** Two separate implementations:
   - **Listwise ML** (`sem-ml.R`): general, any model the parser accepts.
   - **Bounded FIML** (`sem-fiml.R`, `sem-fiml-interface.R`, about 1,500 lines): **not general**. Closed-form pattern tables
     for named structures only (simple, parallel j = 1 or 2, serial with 0 to 2 covariates), each verified against
     lavaan, none statistically admitted. This is a second estimator inside the same engine.
3. **Solver and its safeguards** (`sem-optim.R`, `sem-constraints.R`, `sem-nonzero.R`, `sem-outcomes.R`).
   - Default: **SLSQP** from the NLopt C library, called through the **nloptr** package (`Imports`). medfit wrote no
     optimizer; it wrote the layers around SLSQP: natural-unit scaling, best-of-starts (5 by default), an acceptance
     gate (feasibility, stationarity as a Newton decrement, curvature, multiplier signs), a Newton polish for active
     nonlinear rows, a capped status -4 restoration, redundant-constraint handling, and an exact split of `a*b == 0`
     into one fit per factor (Tier 0).
   - `stats::nlminb` is **also in the code**: `R/sem-fiml.R:393` loops over both `c("slsqp", "nlminb")` on every start
     (`nlminb` with a same-optimizer refinement against an anchored objective), and `:494` requires both to be accepted
     before the fit is certified. So FIML has a built-in two-optimizer agreement check that the listwise path lacks, and
     no public argument or page names an optimizer choice (`git grep solver` in `man/`, `vignettes/`, `README.md`: none).
     The ADR sentence "there is no `solver` argument" is true of the public API.
4. **Inference** (`sem-se.R`, `sem-sandwich.R`, `sem-mbco.R`, `sem-anova.R`, `compare-lr.R`): observed or expected
   information, HC sandwich, delta-method effects, `mbco_sem()`, `anova()`, `compare_lr()` against lavaan or OpenMx.
5. **Evidence** (`sem-outcomes.R`, 679 lines): the versioned outcome ledger (`fit@diagnostics$ledger`), typed errors,
   the D2 literal certificates. This is what turns "the optimizer failed" into a reportable result.

## 4. The word "engine" is overloaded too

| Use | Values | Meaning |
|---|---|---|
| `fit_mediation(engine = )` | `glm`, `regmedint`, `lmer`, `native` ("brms", "gformula", "ipw", "tmle" planned) | which **fitting backend** estimates the mediation model |
| `compare_lr(engine = )` | `lavaan`, `openmx` | which **external program** supplies the comparison likelihood (an oracle, not a fitter) |
| `bootstrap_mediation(method = )` | `parametric`, `nonparametric`, `plugin` | inference, not an engine |
| prose "the engines" (ADR Part C, Models page) | the four above | same as row 1 |
| ADR Part D "solver" | `slsqp`, `nlminb`, AUGLAG (proposed) | the optimizer inside one engine |

Two arguments named `engine` mean different things, and lavaan is a fitting engine nowhere in `fit_mediation()` yet is an
`engine` in `compare_lr()`. "Solver" is the correct word for the third axis and is unused in the public API.

## 5. The optimizer, consolidated from the ADRs and gates

| Topic | State | Source |
|---|---|---|
| SLSQP default for every fit | accepted 2026-10-09, implemented. One benchmark (3 shapes, 90 cells): SLSQP 98.5% from random starts, 100% from default starts; nlminb 100% and about 2.4x faster but takes no constraints; L-BFGS worst (93.3%) | ADR Part A |
| Tiered path for constrained fits | **Tier 0 only implemented** (zero-product split, 0.8.0; unresolved handling 0.13.0). Tier 1 (substitution charts) and the AUGLAG fallback are **not implemented** | ADR Part B, D-6 |
| Silent wrong answer, general nonlinear null | in the mbco-lrt benchmark SLSQP accepted a wrong answer on 12% of 15,000 datasets (read from that repo, not re-run). The guards lower but do not remove this | ADR Part B |
| `nlminb` on zero-product branch fits (stage 1) | decided (D-2, D-3); status in code unverified here | ADR Part D |
| `nlminb` as unconstrained default (stage 2, D-4) | **deferred** 2026-11-11, gate not run | ADR, #424 |
| partial branch result | an error, not a flagged fit (D-11, #303) | ADR |
| third oracle | semopy monthly (D-13) | ADR |
| quality control | seven-item admission checklist, `tests/sim` gates, `qc-monthly`, OpenBLAS runner | CLAUDE.md, `quality-control.qmd` |

Open findings that touch the optimizer: #320 (`compare_lr()` LR above medfit's reference on about 30% of gate runs,
flagged correctly), #369 (task-list reconciliation), #394 (native two-level fitter, S4 and S5).

## 6. Where the material lives (to consolidate)

| Kind | Files | Problem |
|---|---|---|
| Decisions | 14 GRILL files (2026-08-22 to 2026-10-26), 6 PLAN, 4 SPEC, `ADR-native-solver-and-engines`, `ADR-native-defaults` | the ADR is the only single view and is dated 2026-10-23; it still says "native engine (proposed prose name: built-in SEM engine)" |
| Research and QC | `RESEARCH-redundant-constraints`, `BRAINSTORM-optimizer-quality-control`, `BRAINSTORM-native-mean-structure` | evidence only reachable from the ADR's source list |
| User docs | `native-guide`, `native-quickstart`, `native-tutorial`, `model-native` x5, `native-defaults-0-15`, `methods`, `computation-algorithms`, `quality-control`, `syntax-crosswalk`, `lavaan-comparison`, `models` | the solver is named only in `methods` and `computation-algorithms` (ADR section 5, dated 2026-10-23); no page says which engine to choose, in one place |
| Code comments | file headers of `sem-*.R` | thresholds and calibrations live here and in `tests/sim` |
| Tests | 531 "native" mentions; `test-api-freeze.R`, `test-gate-coverage.R` | a rename touches test names, snapshots and the freeze table |

Stale or contradictory items found:

- `model-native.qmd`: "the separate **unreleased** bounded FIML opt-in" (released in 0.16.0).
- ADR sections 3 and 5: "no `solver` argument" while `R/sem-fiml.R` switches solvers internally.
- ADR Part C table: `"native"` is described as "(built-in SEM engine; also `fit_sem()`)", two names in one cell.
- `TwoLevelMediationData` accepts `source = "native"` although no native two-level fitter exists.
- CLAUDE.md engine table lists `"brms"`, `"gformula"`, `"ipw"`, `"tmle"` as planned; none is in `assert_choice`.

## 7. Candidate names

| Option | Prose | Argument | Cost | Verdict |
|---|---|---|---|---|
| A | native engine (status quo) | `"native"` | none | keeps the ambiguity |
| B | built-in SEM engine | `"native"` (frozen) | docs only, about 250 edits | cheap, but prose and argument disagree forever |
| C | the `sem` engine | `"sem"` new, `"native"` kept as alias | docs plus one code path plus a deprecation | prose and argument agree; matches `fit_sem()`, `SEMFit`, `mbco_sem()` |
| D | ML engine | `"ml"` | same as C | wrong: bounded FIML is also this engine, and ML is an estimator, not an engine |

Constraint: the 0.11.0 API freeze promises that exported signatures change only through a deprecation, and CLAUDE.md
asks for a `[BREAKING]` issue and two months of notice for a break. Adding `"sem"` while keeping `"native"` is not a
break; removing `"native"` is.

## 8. Questions for the grill (answered one at a time; none decided)

1. Prose name for the thing: "sem engine", "built-in SEM engine", or keep "native"?
2. Argument value: add `engine = "sem"` with `"native"` as a silent alias now, warn later, remove when?
3. `compare_lr(engine = )`: rename to `reference =` (it names an oracle, not a fitter)?
4. One engine or two: is listwise ML plus bounded FIML one engine with two estimators, and does `missing =` stay the
   switch?
5. Public `solver` option: expose now (FIML already has an internal switch), or hold until D-4 is measured?
6. Where the single "Engines and solver" page lives, and does the ADR get a Part E that supersedes the stale lines?
7. `TwoLevelMediationData@source = "native"`: drop the unused value now, before anything depends on it?
8. Page and file renames (`native-*`, `model-native*`): rename with redirects, or keep URLs and change titles only?

## 9. Vocabulary brainstorm (added 2026-11-12, after the author asked to separate engine from optimizer)

Four axes that "native" blurs into one word. Swap test: if you swap it, does the **meaning** of the result change?

| Axis | Question it answers | Examples | Swap changes the meaning? |
|---|---|---|---|
| Engine | which fitter, hence which models and estimands exist | `glm`, `regmedint`, `lmer`, `sem` (now "native") | **yes**: different model class, assumptions, SEs |
| Estimator (objective) | what quantity is minimized | OLS, REML, ML on listwise rows, bounded FIML | **yes**: different likelihood and missing-data assumption |
| Optimizer | which algorithm finds the minimizer | SLSQP, `nlminb`, AUGLAG (proposed) | **no**: same objective, same answer to about 1e-6 when it works; when it fails the result is an error or "unresolved" |
| Inference | how uncertainty is computed | delta, sandwich, bootstrap, MBCO, `compare_lr()` | changes the interval, not the estimate |

## 10. Grill ledger (author's answers, 2026-11-12; recorded, not yet implemented)

| # | Question | Answer |
|---|---|---|
| 1 | Engine name | **`sem`** (prose "the sem engine"; argument `engine = "sem"`) |
| 2 | Argument value policy | `"sem"` added in the next minor; `"native"` a **silent alias**; soft deprecation a minor later; no removal without a `[BREAKING]` issue and two months' notice. No dependent package uses `engine = "native"` (checked: only the private `medfit-book` repo and a stale note) |
| 3 | `compare_lr(engine = )` | rename to **`reference =`**; `engine` kept as a soft-deprecated alias |
| 4 | Bounded FIML scope | **one engine**; `missing =` stays the switch; "estimator" is docs vocabulary only |
| 5 | Optimizer exposure | **`control = sem_control()`** with `optimizer = "auto"` added in 0.18.0 beside `engine = "sem"`. Legal values now `"auto"` and `"slsqp"`; `"nlminb"` and `"auglag"` are added later without breaking, `"nlminb"` flagged experimental until the D-4 gate measures it. Resolved control stored in `fit@diagnostics`. Rules in section 11 |
| 6 | Where the material lives | new **`ADR-engine-vocabulary-and-controls`** (records 1 to 8, supersedes the stale lines; the solver ADR keeps the evidence and gets a pointer) plus a Guides article **"Which engine should I use?"** linked from the landing and Models pages |
| 7 | `TwoLevelMediationData` provenance | **drop `source`**; `source_package` becomes the single provenance slot, validated only as a non-empty string (in-package fits use `"medfit"`, as the other classes do); **`lavaan_version` becomes `source_version`**. Allowed without deprecation because the class is experimental. Found: `source` duplicated `source_package` and was read only by `print()` and the provenance output, never for dispatch |
| 8 | "native" pages and URLs | rename the 12 article files to `sem-*` / `model-sem*` with pkgdown `redirects:` from every old URL; `native-defaults-0-15` is redirected and retitled but its body stays historical |

**Revised after the Codex adversarial review (same day; see ADR section 7).** Rows 3, 5, 7 and 8 above are superseded:
3 is deferred (the pinned third argument and the result's `$reference` field collide), 5 builds on the **existing** pinned
`control` (a list or `sem_control()`), 7 is additive (`source` and `lavaan_version` are pinned in the dependents
contract), 8 is conditional on a pkgdown redirect spike. The author accepted all revisions.

## 11. Future-proof argument design (author's requirement, 2026-11-12)

Rule from the swap test in section 9: if swapping it changes the **meaning** of the result, it is a top-level
argument (`engine`, `missing`, `fixed_x`, `meanstructure`, `information`, `se_type`); if it changes only **how the
answer is found**, it belongs in one control object (`optimizer`, `n_starts`, tolerances, retries).

1. Strings, never logicals, for anything that can gain a third level (`meanstructure` and `fixed_x` already outgrew
   TRUE/FALSE).
2. `"auto"` as the default of every algorithmic choice; the docs promise "a reliable choice", the **resolved** value is
   recorded in the fit. The default can then move (D-4) without an API change. The 0.15.0 flip needed a `[BREAKING]`
   issue because defaults were literal.
3. One `control = sem_control(...)` object (precedent: `glm.control`, `lme4::lmerControl`), validated by its own
   constructor so a typo errors and a new knob is additive. Adding a value to an enumeration is non-breaking under
   the 0.11.0 freeze; removing or retyping one is not.
4. `options(medfit.*)` only for session-wide **tuning** defaults, never for anything that changes a result's meaning
   (lesson: `medfit.native_defaults` had to be removed).
5. Record the resolved control in `fit@diagnostics` so a rerun is reproducible after a default moves.
6. Experimental values are accepted, documented with a stage, and announce themselves once per session
   (`lifecycle`, already in `Imports`).

Naming rule that the existing engine values already follow: an engine is named for the **model family it fits**
(`glm`, `lmer`) or the package that fits it (`regmedint`), never for who wrote it. `native` is the one value that
names provenance. By that rule the value is `sem`.
