# Engine Adapter Architecture (regmedint) — Orchestration Plan

> **Branch:** `feature/engine-adapter-architecture`
> **Base:** `dev`
> **Worktree:** `~/.git-worktrees/medfit/feature-engine-adapter-architecture`
> **Spec:** `planning/specs/SPEC-engine-adapter-architecture-2026-08-22.md`
> **Grill:** `planning/specs/GRILL-engine-adapter-architecture-2026-08-22.md` (9 decisions locked — read before touching design; do not re-litigate resolved branches)

## Objective

Add a second `fit_mediation()` engine (`"regmedint"`, CRAN-published, closed-form) that returns
`MediationData` or `InteractionMediationData` depending on whether the fitted formula has an
`X:M` interaction term — extending the existing `switch`-based dispatch minimally, with zero
behavior change to the existing `"glm"` path. CMAverse is explicitly out of scope (deferred,
blocked — see spec §7).

## Phase Overview

| Phase | Increment | Priority | Effort | Status |
|---|---|---|---|---|
| 1 | Dispatch extension (§2) | High | Low | **Done** (2026-08-22) |
| 2 | regmedint adapter core (§3–§5) | High | Med | **Done** (2026-08-22) |
| 3 | Tests + acceptance criteria (§6) | High | Med | 3.1–3.4 done with Phase 2; 3.5–3.6 pending |
| 4 | Vignette + pkgdown + NEWS | Med | Low | Not started |

**Total estimate:** ~1 week (per `EXTENSIONS-PLAN-2026-06-03.md`'s Ext C effort row).

## Phase 1: Dispatch extension

**Scope:** Widen `fit_mediation()`'s dispatch (`R/fit-glm.R:131,175-189`) with zero behavior
change to the existing `"glm"` path (spec §2).

- [x] 1.1 Widen `checkmate::assert_choice(engine, choices = c("glm"))` → `c("glm", "regmedint")`
- [x] 1.2 Add `engine_args = list()` as a new optional `fit_mediation()` parameter (default empty)
- [x] 1.3 Add the `regmedint = .adapter_regmedint(...)` arm to the existing `switch()`
- [x] 1.4 **Backward-compat regression check:** run the full existing test suite for
      `engine = "glm"` and confirm byte-identical output before/after (spec §2 acceptance
      criterion — this is the gate for the rest of the phases, not a nice-to-have)
      → **Passed:** 7 glm configs (basic/cov/binom/interaction/weights/sandwich/dots)
      serialized before/after — `identical(serialize(before), serialize(after))` TRUE;
      full suite 0 fail before, 813 pass / 0 fail / 2 skip after (+7 new expectations).

**Phase 1 notes:** 2.1's `Suggests: regmedint` was pulled forward (the `.adapter_regmedint()`
stub's `requireNamespace()` guard otherwise triggers a check WARNING). `R/fit-regmedint.R`
holds a stub that errors "not yet implemented" so the `switch()` arm is check-clean; Phase 2
replaces the stub body. `.Rbuildignore` gained `.token-optimizer`, `AGENTS.md` (added on dev in
`ef66b5b`), and `ORCHESTRATE-*.md` — all three were `R CMD check` NOTEs.

**Key files:** `R/fit-glm.R` (update), `R/aab-generics.R` (update `fit_mediation` generic docs —
new `engine_args` param)

## Phase 2: regmedint adapter core

**Scope:** `.adapter_regmedint()` — the translation layer (spec §3–§5). Depends on Phase 1's
`engine_args` param existing.

- [x] 2.1 `Suggests: regmedint` in `DESCRIPTION`; `requireNamespace()` guard + install-hint error (done in Phase 1)
- [x] 2.2 `.formula_has_interaction()` reuse — confirm the existing helper `extract_mediation
      (decomposition = "auto")` uses is exported/accessible internally, or factor it out to
      `R/utils.R` if it's currently private to the lm/lavaan extraction path (check before
      assuming — this is exactly the kind of implementation-time detail the grill ledger flagged
      as deferred, not a re-litigated design decision)
- [x] 2.3 Argument bridging per spec §5 table: auto-derive `cvar`/`mreg`/`yreg`/`a0`/`a1`/
      `m_cde`/`c_cond` from `formula_y`/`formula_m`/`family_y`/`family_m`/`data`; explicit error
      (not a silent default) for non-binary treatment without an `engine_args` override
- [x] 2.4 `.regmedint_to_mediation_data()` — simple (no-interaction) case
- [x] 2.5 `.regmedint_to_interaction_mediation_data()` — four-way mapping per spec §3:
      `cde=cde`, `int_ref=pnde-cde`, `int_med=tnie-pnie`, `pie=pnie`, plus delta-method SE
      propagation through regmedint's own `vcov()` (analytical — no bootstrap)
- [x] 2.6 Class-selection dispatch: `has_interaction` auto-detected from `formula_y`, with
      `engine_args$interaction` as the explicit override (spec §4)

**Key files:** `R/fit-regmedint.R` (NEW), `DESCRIPTION` (update `Suggests`)

**Phase 2 notes (implementation-time findings — premise corrections, not design re-opens):**

- **2.2:** the existing helper (`.find_interaction_term()`, `R/extract-lm.R`) reads a *fitted
  model's* coefficient names; the adapter needs the decision before fitting, so a formula-level
  sibling `.find_interaction_term_formula()` was added to `R/utils.R` (same both-orderings
  convention). The spec's `.formula_has_interaction()` name was a placeholder.
- **§3 premise correction — `regmedint::vcov()` is diagonal-only** (off-diagonals are `NA`,
  verified in `regmedint:::vcov.regmedint`). `Var(int_ref) = Var(pnde) + Var(cde) − 2Cov` is
  therefore not computable from regmedint's output. The adapter instead reproduces regmedint's
  own delta method (parameter vector `(β, θ, σ²)`, `Σ = bdiag(vcov(mreg), vcov(yreg), 2σ⁴/df)`,
  gradients = regmedint's `Γ_pnde − Γ_cde` etc. specialized to `a0=0, a1=1`) in
  `.regmedint_component_vcov()`, giving the full 7×7 component block plus cross-covariances
  with the coefficients. Its diagonal equals regmedint's reported SEs (tested, Gaussian and
  logistic Y). `confint(InteractionMediationData)` now prefers a stored component block when
  present (backward-compatible: lm/glm objects have none, gradient path untouched).
- **Representability (new guard, §4/§5):** `InteractionMediationData`'s validator pins
  `pie = b·a`, `int_med = θ₃·β₁`, `cde = c' + θ₃·m*`. regmedint's `PNIE = (θ₂β₁ + θ₃β₁a₀)(a₁−a₀)`
  matches only for `a0 = 0, a1 = 1` and a **linear mediator model**; a logistic `mreg` gives
  `PNIE = θ₂[expit(·) − expit(·)]` (Δ = −0.136 on the probe data). The adapter errors with
  guidance for logistic `mreg`, for `a0/a1` outside the unit contrast, and for non-0/1
  treatments (regmedint itself rejects factor/logical `avar`). Net: `engine_args$a0/a1` is
  accepted and forwarded but can only pass the check at `(0, 1)` — recoding is the real fix.
- **yreg mapping:** regmedint pairs `mreg = "linear"` only with `yreg ∈ {linear, logistic}`
  (`ls(asNamespace("regmedint"), "calc_myreg_mreg_linear_")`), so `poisson()` is not
  auto-mapped (error suggests `engine_args$yreg`). Logistic Y **is** supported and tested —
  its rare-outcome closed forms keep `PNIE`/`CDE`/`INTmed` in product form; only `INTref`
  absorbs the `θ₂σ²` / `½θ₃²σ²` terms, and the validator leaves `int_ref` free.
- **`m_cde` default = `mean(M)` per spec §5 text.** ⚠️ The spec's stated rationale ("matching
  `InteractionMediationData`'s existing `m_star` convention") is factually wrong: the lm/glm
  extractor defaults `m_star = 0` (`R/extract-lm.R:119`). So `engine = "glm"` and
  `engine = "regmedint"` report CDE/INTref at different reference levels by default. Followed
  the spec's literal value; **one-line flip if the user prefers cross-engine consistency.**
- **No-interaction path** reuses `extract_mediation(fit$mreg_fit, model_y = fit$yreg_fit)` on
  regmedint's own lm/glm fits (`source_package = "regmedint"`), with an internal assertion that
  regmedint's `pnde`/`pnie` equal `c'` / `a·b`. Numerically identical to the glm engine (tested).
- `fit_mediation()` refuses `weights` / `se_type = "sandwich"` for this engine (regmedint has
  neither) instead of silently ignoring them. Rows with `NA` on used variables are dropped
  (glm-engine parity; regmedint errors on `NA` by default).

## Phase 3: Tests + acceptance criteria

**Scope:** Validate every item in spec §6 with `skip_if_not_installed("regmedint")`.

- [x] 3.1 No-interaction case: `nde()`/`nie()` match regmedint's own output
- [x] 3.2 Interaction case: `cde/int_ref/int_med/pie` match the §3 mapping within tolerance;
      `InteractionMediationData`'s existing validator invariants pass (they hold by
      construction — a failure here is a mapping bug, not a tolerance issue, per the grill's
      verified-numerically finding)
- [x] 3.3 Component SEs match delta-method propagation through regmedint's `vcov()`
- [x] 3.4 Continuous/multi-level treatment without an explicit `a0`/`a1` override → clear error,
      not silent wrong default
- [ ] 3.5 `R CMD check --as-cran` clean with regmedint **absent** and **present** (plain `devtools::check()` 0/0/0 after Phase 2; strict flavors pending)
- [ ] 3.6 Phase 1.4's backward-compat regression check re-confirmed at the end (full suite green)

**Key files:** `tests/testthat/test-fit-regmedint.R` (NEW)

## Phase 4: Vignette + docs

**Scope:** Per the grill's Open Questions (mechanical, decided at implementation time, not
re-litigated here).

- [ ] 4.1 Vignette section: "Using the regmedint engine" (where the existing fitting/extraction
      vignette lives — check `vignettes/` for the right file to extend vs. a new one)
- [ ] 4.2 `_pkgdown.yml` reference entry for any newly exported symbols (if `.adapter_regmedint`
      stays internal/`@keywords internal`, likely no new reference entries needed — confirm)
- [ ] 4.3 `NEWS.md` entry
- [ ] 4.4 Roxygen docs on `fit_mediation()`'s updated signature (`engine_args` param, `"regmedint"`
      choice) — `devtools::document()`, verify `RoxygenNote` pin unchanged (`git diff dev --
      DESCRIPTION` empty per the Ext A/B gotcha)

**Key files:** `vignettes/*.qmd` (update or new), `_pkgdown.yml` (update if needed), `NEWS.md`
(update), `man/fit_mediation.Rd` (regenerated)

## Friction Prevention

- Context first: re-read the GRILL file before Phase 2 — 9 decisions are already locked, do not
  re-open them (e.g. don't reconsider CMAverse, don't add a registry, don't add a `decomposition=`
  override argument).
- Verify CWD/branch before any git operation: `pwd && git branch --show-current` should show this
  worktree and `feature/engine-adapter-architecture`.
- No autonomous multi-phase runs — verify each phase (tests green) before starting the next.
- Phase 1.4's backward-compat check gates everything after it — do not proceed to Phase 2 if it
  fails.

## Acceptance Criteria

(mirrors spec §6, repeated here for a single checklist at merge time)

- [ ] `fit_mediation(engine = "glm", ...)` test-suite output byte-identical before/after
- [ ] No-interaction `fit_mediation(..., engine = "regmedint")` → `MediationData`, matches
      regmedint's own `nde`/`nie`
- [ ] Interaction case → `InteractionMediationData`, matches the §3 mapping + validator invariants
- [ ] Component SEs match delta-method propagation through regmedint's `vcov()`
- [ ] Non-binary treatment without override → clear error
- [ ] `R CMD check --as-cran` clean, regmedint absent and present

## Commit Strategy

Conventional commits per phase (`feat(fit): ...`, `test(fit): ...`, `docs(vignette): ...`). Two
PRs suggested (per the grill's Open Questions, not a re-litigated decision — adjust if a single
PR reads cleaner once the diff exists):

- **PR 1:** Phases 1–3 (dispatch + adapter core + tests) — the correctness-bearing change.
- **PR 2:** Phase 4 (vignette/pkgdown/NEWS) — docs-only follow-up.

## Verification

```r
devtools::document()
devtools::test()
devtools::check(cran = TRUE, args = "--run-donttest",
                env_vars = c("_R_CHECK_DEPENDS_ONLY_" = "true",
                             "_R_CHECK_SUGGESTS_ONLY_" = "true",
                             "_R_CHECK_CRAN_INCOMING_" = "true",
                             "_R_CHECK_CRAN_INCOMING_REMOTE_" = "true"))
```

Run both with regmedint installed and with it removed (`_R_CHECK_SUGGESTS_ONLY_` covers the
absent case) — spec §6's last acceptance criterion needs both.

## Session Instructions

```
cd ~/.git-worktrees/medfit/feature-engine-adapter-architecture && claude
```
> "Read ORCHESTRATE-engine-adapter-architecture.md and start Phase 1."

(Desktop app, no persistent shell: `EnterWorktree({ path: "~/.git-worktrees/medfit/feature-engine-adapter-architecture" })` switches the session's cwd directly instead of opening a new terminal.)

## Test-Plan Scaffolding (default-on)

| Tier | Applies? | Reason |
|---|---|---|
| `unit` | ✅ | New adapter function, argument-bridging logic, mapping formulas |
| `integration` | ✅ | Adapter output must interoperate with existing `nde()`/`nie()`/`confint()` generics unchanged |
| `dependency` | ✅ | `regmedint` new `Suggests` — both present/absent paths must check clean |
| `e2e` / `dogfood` | ✅ | Full `fit_mediation(engine="regmedint")` → generic-method round-trip |
| `count-cascade` | N/A | No new command/skill/agent — package code only |

Phase 1 shipped the contract-bearing tests in `tests/testthat/test-fit-glm.R` (section
"Dispatch extension"): `engine_args` default/ignored-by-glm output identity, `engine_args`
validation, and `engine = "regmedint"` reaching its adapter. The byte-identical snapshot
comparison was run out-of-tree (scratchpad script, not committed).

## Documentation

- [x] **Guide/vignette** — new engine choice + fitting workflow change, needed (Phase 4.1).
- [x] **Refcard/README/NEWS** — new exported choice on `fit_mediation()`, needed (Phase 4.3).
- [ ] **Demo** — N/A, no CLI/interactive demo surface in this package.
- [ ] **Mermaid diagram** — N/A this pass (single new adapter, not an architecture change worth
      diagramming); reconsider once/if Ext C.1 (CMAverse) makes the adapter layer non-trivial.

CHANGELOG `[Unreleased]` mirror only — no version/count-line changes.
