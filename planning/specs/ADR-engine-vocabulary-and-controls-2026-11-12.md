---
decisions:
  - {id: V-1, title: "The in-package ML fitter is the sem engine: engine = 'sem', prose 'the sem engine'", status: decided, date: 2026-11-12}
  - {id: V-2, title: "engine = 'native' stays as a silent alias; soft deprecation one minor later; no removal without a [BREAKING] issue", status: decided, date: 2026-11-12}
  - {id: V-3, title: "compare_lr(engine = ) keeps its name in 0.18.0 (reference = deferred until #320 and the result-field collision are resolved)", status: deferred, date: 2026-11-12}
  - {id: V-4, title: "Listwise ML and bounded FIML are one engine; missing = stays the switch", status: decided, date: 2026-11-12}
  - {id: V-5, title: "Tuning: the existing control accepts a plain list (legacy nloptr options) or sem_control(); optimizer = 'auto' for the listwise search, resolved protocol recorded", status: decided, date: 2026-11-12}
  - {id: V-6, title: "Argument design rules: meaning-changing options are arguments, search options are control, strings not logicals, options() only for tuning", status: decided, date: 2026-11-12}
  - {id: V-7, title: "TwoLevelMediationData: optional source_version and a fallback reader; source and source_package validators unchanged; source and lavaan_version kept", status: decided, date: 2026-11-13}
  - {id: V-8, title: "Prose and titles change first; the 'native' article URLs are renamed to sem-* only after a pkgdown redirect spike confirms anchors survive", status: conditional, date: 2026-11-12}
  - {id: V-9, title: "One decision record and one user guide: this ADR and the Guides article 'Which engine should I use?'", status: decided, date: 2026-11-12}
---

# ADR: engine vocabulary, tuning controls and provenance

**Date:** 2026-11-12. **Status:** nine decisions answered by the author in the 2026-11-12 grill; **revised the same day after
the Codex adversarial review** (section 7: V-3, V-5, V-7 and V-8 changed, V-6 rule 3 corrected); **V-7 revised again on 2026-11-13** after a second Codex review and a `/code-review` (section 7); **none implemented**.
The implementation is `planning/PLAN-0.18.0-engine-vocabulary-2026-11-12.md`. Evidence and the full grill ledger:
`planning/AUDIT-engine-and-optimizer-2026-11-12.md` (read-only audit of `origin/main` at `6b9a943c`).
The solver evidence and the SLSQP and `nlminb` decisions stay in `ADR-native-solver-and-engines-2026-10-23.md`; this ADR
changes names and API shape, not the solver.

## 1. Context

"Native" named where the code lives, not what it does. It had five senses (an argument value, the in-package ML fitter,
a set of defaults, a fitter that does not exist yet, and 12 page names), the word "engine" meant two different things
(`fit_mediation(engine = )` selects a fitter, `compare_lr(engine = )` selects an external oracle), and the optimizer had
no public name at all. The audit also found that FIML runs both SLSQP and `nlminb` and requires agreement
(`R/sem-fiml.R:393`, `:494`), while the listwise path runs SLSQP only.

## 2. Vocabulary (the four layers)

The swap test: if you swap it, does the meaning of the result change?

| Layer | Question | Examples | Swap changes the meaning? |
|---|---|---|---|
| Engine | which fitter, hence which models and effects exist | `glm`, `regmedint`, `lmer`, `sem` | yes |
| Estimator | what is minimized | OLS, REML, listwise ML, bounded FIML | yes |
| Optimizer | which algorithm finds the minimizer | SLSQP, `nlminb`, AUGLAG | no: same objective; a failure is an error or an unresolved result |
| Inference | how uncertainty is computed | delta, sandwich, bootstrap, MBCO | the interval, not the estimate |

An engine is named for the model family it fits (`glm`, `lmer`) or the package that fits it (`regmedint`), never for who
wrote it.

## 3. Decisions

**V-1. The sem engine.** The in-package maximum-likelihood fitter for lavaan-style syntax is "the sem engine" in prose
and `engine = "sem"` in code. It matches `fit_sem()`, `SEMFit` and `mbco_sem()`, and covers listwise ML, bounded FIML
and a future two-level fitter without another rename. Rejected: `path` (sounds observed-only), `system` (suggests
simultaneity), `ml` (an estimator, and FIML is also this engine), `joint` (clashes with `JointMediationData`),
`builtin` and `native` (provenance, not model family; the `glm` engine is in-package too), keeping `native`.

**V-2. Alias policy.** `engine = "sem"` is added in the next minor release (0.18.0). `"native"` is accepted silently
and documented as the legacy spelling. One minor later it gets a `lifecycle` soft deprecation. It is not removed without a
`[BREAKING]` issue and two months' notice. Checked 2026-11-12 in **local checkouts only** (`~/projects/r-packages`,
`~/projects/research`): no dependent package calls `engine = "native"`; only the private `medfit-book` repo and a stale note
do, so the alias protects the book. External users and saved objects are not checked.

**V-3. `compare_lr()` (deferred).** The grill chose `reference = c("lavaan", "openmx")`. The Codex review found two
verified collisions: `engine` is the pinned third positional argument (`test-api-freeze.R`, `pin_compare_lr_args`), and
the returned object already has a `$reference` field meaning **medfit's** LR, so the new argument would give "reference"
two meanings in one call. #320 (LR above the reference on about 30% of gate runs) also makes this a poor moment to change
diagnostic vocabulary. Decision: keep `engine` in 0.18.0 and document it as "the external comparison program (lavaan or
OpenMx), not a fitter of the mediation model". Revisit after #320 with the argument, positional and result-field contracts
specified together (candidate names: `against`, `program`).

**V-4. One engine, two estimators.** Bounded FIML stays inside the sem engine and `missing = "listwise" | "fiml"` stays
the switch (lavaan's own spelling). "Estimator" is documentation vocabulary; no new argument. FIML stays labeled bounded
and not statistically admitted.

**V-5. Controls (revised after review).** `control` **already exists**: `fit_sem(control = list())` and
`mbco_sem(control = )` take raw `nloptr` options (pinned by the freeze), and `fit_mediation()` already forwards `control`
through `engine_args` (`fit_args` in `R/fit-sem.R`). So no new slot is added and the route does not change.
- `control` accepts **either** a plain list (today's meaning, unchanged results, FIML still requires an empty list) **or**
  a `sem_control()` object. A plain list is read as `sem_control(nloptr = <list>)`, so every released call keeps working.
- `sem_control(optimizer = "auto", n_starts = NULL, nloptr = list())` is validated by its constructor (a typo errors).
  `optimizer` describes the **listwise search** only: `"auto"` and `"slsqp"` today. FIML's protocol (SLSQP and `nlminb`
  both run, both must be accepted: `R/sem-fiml.R:393`, `:494`) is **not selectable**; for a FIML fit only `"auto"` is
  legal and anything else is an error, so no name misdescribes what ran.
- `control` is normalized **once, at entry** (`fit_sem()` and `mbco_sem()`) into a plain `nloptr` options list plus a
  resolved protocol; everything downstream, including `fit@internals$control`, MBCO refits and the FIML guard
  (`R/sem-fiml-interface.R:465`, applied to the resolved values), keeps receiving a plain list. FIML keeps `n_starts` 3
  and an empty `nloptr` list; a default `sem_control()` resolves to that and passes.
- The resolved **search protocol** (estimator, optimizer(s), `n_starts`, start rule, version) is stored in
  `fit@diagnostics$protocol` (not `control`, which is already `fit@internals$control`, the raw `nloptr` options). `"nlminb"` and `"auglag"` are added later as additions, `"nlminb"` flagged experimental until
  the D-4 gate (solver ADR) has measured it.
- Top-level `n_starts` stays valid (freeze); a different value in both places is an error. No `solver` word in the
  public API; the `fit_mediation()` route stays `engine_args = list(control = ...)`, with no new top-level argument.

**V-6. Argument design rules.**
1. Meaning-changing options are top-level arguments (`engine`, `missing`, `fixed_x`, `meanstructure`, `information`,
   `se_type`); options that change only how the answer is found go in `control`.
2. Strings, never logicals, for anything that can gain a third level.
3. `"auto"` is the default of every algorithmic choice and the resolved protocol is recorded, so a default can move
   **without an API change**. It is not free of consequences: with several starts and constrained fits a different
   protocol can select a different accepted local optimum (`R/fit-sem.R`, the spread warning), so a default move that can
   change reported estimates is **result-affecting**: it needs a protocol version bump, a NEWS note and the gate evidence
   (the D-4 pattern), and the recorded protocol lets a user rerun the old one.
4. A control object is validated by its own constructor: a typo errors, a new knob is additive. Adding a value to an
   enumeration is non-breaking under the freeze; removing or retyping one is not.
5. `options(medfit.*)` only for session-wide tuning defaults, never for anything that changes a result's meaning (the
   removed `medfit.native_defaults` is the lesson). **Grandfathered:** `medfit.covariate_mean_variance` (population-average
   four-way standard errors) and `medfit.twolevel_equal_diff` / `medfit.twolevel_equal_var` (which paths count as equated)
   already change what is reported; they predate this rule, stay as they are, and are candidates to move into an argument
   or control entry in a later minor. New options follow the rule.
6. Experimental values are accepted, documented with a stage, and announce themselves once per session through
   `lifecycle`. The repo has no badge mechanism; "experimental" is prose plus that message.

**V-7. Provenance of `TwoLevelMediationData` (revised 2026-11-13).** `source` is the fitting route (`"lavaan"`,
`"native"`) and `source_package` the package (the cross-class provenance slot: `"stats"`, `"lavaan"`, `"medfit"`). They are
independent fields, not duplicates: `source = "native"` with `source_package = "lavaan"` is valid in 0.17.0
(`test-twolevel-class.R:87`). Both `source` and `lavaan_version` are **pinned** in `test-dependents-contract.R`, documented
in the class and present in `summary(x)$provenance`, so deleting either would break released objects and readers. NEWS
calls the class experimental, so a change is permitted, but the cheapest safe path is additive:
- Add one optional property, `source_version` (`character(0)` or one non-empty string), the version of whichever package
  fitted the model. `lavaan_version` may also be empty, so a fit lavaan did not make needs no placeholder. Both are
  checked outside the validator's length-1 scalar loop; S7 reruns the validator on `@<-`, so the rules cover assignment.
- **No custom constructor, no stored fill, no new error a 0.17.0 call can reach.** Readers use one helper that returns
  `source_version` when the property exists and is non-empty, else `lavaan_version` for a lavaan fit; it checks
  `S7::prop_exists()` first because an object saved by 0.17.0 keeps its old class after `readRDS()`.
- **Validators of `source` and `source_package` unchanged in 0.18.0.** Opening them, and a `"sem"` route value, wait for the
  native two-level fitter (#394), their first caller. The stored `"native"` is data on an experimental class, not an
  argument, so V-2's alias policy does not apply to it.
- **Keep `source` and `lavaan_version`.** The contract table gains `source_version` and removes nothing. This reverses the
  grill answer "drop `source`": it is not a duplicate. Whether `lavaan_version` is deprecated is decided with #394.

**V-8. Renames (conditional, revised after review).** Two steps, in order. (1) In 0.18.0, article **titles and prose** say
"sem engine"; the URLs stay. (2) The 12 files named `native-*` and `model-native*` become `sem-*` and `model-sem*` with a
pkgdown `redirects:` entry per old URL **only after a spike shows** that the installed pkgdown supports `redirects:` for
`articles/` paths and that fragments survive (the released README links to `native-guide.html#bounded-fiml`, and
`test-native-defaults-article.R` asserts the defaults article path). If anchors do not survive, keep the URLs and
rename nothing. `native-defaults-0-15` stays historical in body. Historical NEWS entries are not rewritten.

**V-9. Where this lives.** This ADR is the decision record. The user-facing guide is a Guides article "Which engine should
I use?" next to "Which interval should I use?", answering three short questions in order (engine, estimator, optimizer
when it matters), linked from the landing page and the Models page. The solver ADR gets a one-line pointer to this one.

## 4. Consequences

- One word, `sem`, replaces "native" in prose and the argument; "engine" still means two things until V-3 is resolved
  (documented as "fitter" vs "external comparison program"); "optimizer" is the listwise search algorithm and has one
  home (`control`).
- Adding AUGLAG, `nlminb` or new tolerances never changes a signature.
- The guide defines "the sem engine" as **medfit's own SEM fitter** (`fit_sem()`, `engine = "sem"`) and keeps the lavaan
  extraction route (`extract_mediation()` on a lavaan fit) visibly distinct, since users may read "sem" as lavaan's `sem()`.
- Cost: prose edits inventoried by type (not a blanket replace), one new exported function (`sem_control()`), an additive
  provenance change, test names and snapshots that mention "native" (531 hits), and, if the spike passes, 12 renames.
- The private `medfit-book` repo still says `engine = "native"`; the alias keeps it working and its maintainer updates it.

## 5. What would change this

- The D-4 gate shows `nlminb` is not non-inferior: `"nlminb"` is never added, and the `optimizer` enumeration stays at
  `"auto"` and `"slsqp"`.
- A second in-package fitter family (for example a Bayesian one) would need its own engine value; V-1's rule (name the
  model family) decides the name.
- Dependents start passing `engine = "native"`: the soft deprecation is postponed, not the alias removed.

## 6. Open items to verify before implementation

1. ~~Whether listwise attempts record which optimizer ran~~ **Resolved 2026-11-13: no.** Listwise attempts are gate
   lists without a solver field; the algorithm defaults to `NLOPT_LD_SLSQP` but `control$algorithm` overrides it
   (`R/sem-optim.R:383-384`), visible only in `fit@internals$control`. V-5 therefore stores the effective algorithm in
   `diagnostics$protocol` and treats `optimizer = "slsqp"` with a different `nloptr$algorithm` as a conflict.
2. ~~How the sem route of `fit_mediation()` receives `control`~~ **Resolved by review:** `fit_args` in `R/fit-sem.R`
   already forwards `control` through `engine_args`; no top-level argument.
3. ~~Whether `test-api-freeze.R` pins the argument lists~~ **Resolved:** `pin_fit_sem_args` and `pin_mbco_sem_args` pin
   `control`; `pin_compare_lr_args` pins `engine` as the third argument; new arguments only at the end.
4. ~~That the installed pkgdown supports `redirects:` and keeps `#fragments`~~ **Resolved 2026-11-13:** pkgdown 2.2.1
   supports `redirects:`; its default meta-refresh page loses the fragment (checked in Chromium), and a local
   `pkgdown/templates/layout-redirect.html` that appends `location.hash` keeps it. V-8 step 2 may proceed with that
   template.
5. ~~The dependents-contract table~~ **Resolved:** it pins `source` and `lavaan_version`; V-7 is additive.
6. ~~Saved-object compatibility and external users~~ **Resolved 2026-11-13:** objects saved by an installed v0.17.0
   read, print and give the same `nie()`/`coef()` under dev; none stores `"native"` in a character property. An S7 test
   confirmed that an added property errors on an old object and `S7::prop_exists()` guards it (V-7). Public GitHub code
   search found no `engine = "native"` callers outside `Data-Wise`.

## 7. Codex adversarial review (2026-11-12) and dispositions

Read-only review of this ADR, the plan and the audit against `origin/main` at `6b9a943c` (agent `codex:codex-rescue`).
Verdict: revise before S1. The author accepted all dispositions below. I re-checked findings 1 to 4 and 6 in code; 5 and 7
to 9 are the reviewer's, taken as required checks.

| # | Severity | Finding | Disposition |
|---|---|---|---|
| 1 | High | `fit_sem(control = list())` already exists and is pinned; a validated `sem_control()` would break `control = list(maxeval = ...)` | **V-5 rewritten:** `control` accepts a list or `sem_control()` |
| 2 | High | `source` and `lavaan_version` are pinned in the dependents contract | **V-7 rewritten:** additive, old names kept one cycle |
| 3 | High | S2 is high risk by path (`R/sem-optim.R`, `R/fit-sem.R` are in `risk-files.txt`) | plan S2: seven-item checklist, justified `n/a` entries |
| 4 | Medium | `fit_mediation()` already forwards `control` through `engine_args` | no top-level argument |
| 5 | Medium | FIML runs both solvers; `"slsqp"` would misdescribe it or change certification; "auto" can move estimates | V-5 scope and V-6 rule 3 corrected |
| 6 | Medium | `engine` is the pinned third argument; `$reference` already means medfit's LR | **V-3 deferred** |
| 7 | Medium | redirects and anchors unverified; README links to `native-guide.html#bounded-fiml` | **V-8 conditional** on a spike |
| 8 | Medium | prose blast radius understated (error text, snapshots, conditions) | plan S5a: inventory by type, split from API PRs |
| 9 | Low | "sem" may read as lavaan's `sem()` | guide defines it; section 4 |

### Second review: `/code-review` of the revised documents (2026-11-12, high effort, 8 findings, all accepted)

| # | Finding | Disposition |
|---|---|---|
| 1 | `mbco_sem()` and `fit@internals$control` re-consume the stored `control`; a `sem_control()` object would break every MBCO refit | V-5: normalize once at entry; plan S2 adds `R/sem-mbco.R` and a test |
| 2 | The FIML guard (`R/sem-fiml-interface.R:465`) rejects any non-empty `control` and `n_starts` other than `NULL`/3 | V-5: guard applied to resolved values; default `sem_control()` passes; plan S2 adds the file |
| 3 | Read-only S7 aliases would break released constructor calls and the contract table | V-7: stored properties and valid constructor arguments (the consistency validator was later removed; see the third review) |
| 4 | `diagnostics$control` collides with `internals$control` | renamed `diagnostics$protocol` |
| 5 | V-6 rule 5 contradicts shipped options | grandfather clause added |
| 6 | S2 dependency on S1 stale | plan table corrected |
| 7 | Risk-gate call described inexactly | plan S2 states `risk_check()` inputs and the `dev` exemption |
| 8 | `n_starts` conflict rule ignores `mbco_sem()` and the defaulted 5 | plan S2: detect "supplied" explicitly; same rule for `mbco_sem()` |

### Third review: second Codex review of S4, then `/code-review` (2026-11-13)

The second Codex review found that an agreement check rejected the valid `source = "native"` with
`source_package = "lavaan"`, and that calls without `source_version` had no legacy path; both were fixed by a stored fill.
The `/code-review` that followed (high effort, 10 findings) found that fix itself unsafe, and V-7 was rewritten:

| # | Finding | Disposition |
|---|---|---|
| 1 | `lavaan_version` has a length-1 check; a fit lavaan did not make cannot omit it | it may be empty (length 0 or 1) |
| 2 | Opening the validators breaks `test-twolevel-class.R:86` and adds an empty-string error | validators unchanged in 0.18.0 |
| 3 | `x@source_version` errors on 0.17.0 objects; fixture script unnamed | `S7::prop_exists()` in the reader; named fixture script |
| 4 | Mismatch check ignores `@<-`; constructor or validator unclear | no mismatch check; all rules in the validator |
| 5 | Disposition 3 still says "consistency validator"; no record of the Codex review | this table; disposition 3 annotated |
| 6 | `source` called both a duplicate and independent | independent; "duplicate" removed; `source` kept |
| 7 | Gates miss the non-lavaan path and assignment; one planted defect | four gates, each with a planted defect |
| 8 | Custom constructor duplicates the reader fallback | constructor dropped; one reader helper |
| 9 | `source = "native"` kept while V-1 retires the word | stored data, not an argument; renaming waits for #394 |
| 10 | REPORT order and status contradict the PLAN | REPORT aligned |

