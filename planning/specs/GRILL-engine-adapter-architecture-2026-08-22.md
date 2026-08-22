# GRILL: Engine Adapter Architecture (Extension C)

**Date:** 2026-08-22 · **Target:** `SPEC-engine-adapter-architecture-2026-08-22.md`
**Preceded by:** an independent adversarial-review agent pass (findings folded in as attack-angle
input, not restated here — see the SPEC's revision below for the resolved outcomes) and
`BRAINSTORM-medfit-mediationverse-next-features-2026-08-22.md` (this Extension was already the
committed next item there, not itself a brainstorm output).

> Interrogated by grill — see [GRILL-engine-adapter-architecture-2026-08-22.md](GRILL-engine-adapter-architecture-2026-08-22.md)

## Decision Ledger

| # | Branch | Decision |
|---|---|---|
| 1 | Effect representation for non-closed-form engines (§2's "no new class" premise was falsified: `nie()`/`nde()` are computed live as `a_path*b_path`, verified at `R/methods-base.R:62` — a g-formula/IPW estimate has no correct slot to occupy) | Restrict Ext C v1 to closed-form (regression-based) methods only. Simulation-based effects (g-formula, IPW) deferred to a follow-up spec (see #7) rather than solved with new slots or a new class this pass. |
| 2 | Registry vs. minimal dispatch extension (verified actual `fit_mediation()` dispatch is a hardcoded `checkmate::assert_choice(engine, c("glm"))` + `switch`, at `R/fit-glm.R:131,175-189` — not the `.engine_registry` §4 originally described, and no `engine_args` param exists today) | Minimal: widen `assert_choice`'s choices vector, add one `switch` arm, add one new optional `engine_args = list()` param. No `.engine_registry`/`.register_engine()`/`.dispatch_engine()` abstraction this pass — YAGNI until a 3rd external engine actually needs it. |
| 3 | CMAverse CRAN availability (verified live: `"CMAverse" %in% rownames(available.packages(...))` → `FALSE`) | Switch the first external adapter target from CMAverse to **regmedint** (verified on CRAN, v1.0.2) — already used as medfit's own Ext B validation target, so this removes a CRAN-incoming-check risk entirely rather than managing it via `skip_on_cran()`. |
| 4 | Does regmedint's `pnde/tnde/tnie/pnie` output actually map onto `InteractionMediationData`'s `cde/int_ref/int_med/pie` slots? | Verified numerically against a fitted example: `cde + (pnde-cde) + (tnie-pnie) + pnie = te` exactly (`0.9722823` both sides). Mapping is `cde=cde`, `int_ref=pnde-cde`, `int_med=tnie-pnie`, `pie=pnie`. SEs need delta-method propagation through regmedint's own reported 7×7 `vcov` (analytical, not bootstrap — regmedint exposes `coef()`/`vcov()`/`confint()` methods directly). |
| 5 | MediationData vs. InteractionMediationData class selection | Mirror `extract_mediation(decomposition="auto")`'s existing convention: adapter auto-detects an `X:M` term in `formula_y` and sets regmedint's own `interaction=` argument accordingly — `TRUE` → `InteractionMediationData` via the #4 mapping; `FALSE` → regmedint's plain natural-effects output → `MediationData`. |
| 6 | Backward-compat guarantee for the existing `"glm"` path | Explicit acceptance criterion added: all existing `fit_mediation(engine="glm", ...)` test-suite output must be byte-identical before/after this PR, despite the low apparent risk of the 2-line diff. |
| 7 | CMAverse's deferred fate | Named follow-up spec placeholder (`SPEC-cmaverse-adapter.md`, not yet written) recorded in `EXTENSIONS-PLAN-2026-06-03.md` as **Ext C.1**, explicitly blocked on two named open problems: CRAN-availability strategy (`Additional_repositories`/r-universe) AND the engine-native-effects representation problem from #1, still unresolved for non-closed-form engines. |
| 8 | Interface bridging: regmedint needs `a0/a1` (treatment levels), `m_cde/c_cond` (evaluation points), `mreg/yreg` (model-type strings), `cvar` — none of which `fit_mediation()`'s formula-based signature currently derives | Auto-derive what's derivable (`cvar` from formula covariates; `mreg`/`yreg` from `family_y`/`family_m` — Gaussian→"linear", binomial→"logistic"; `a0=0`/`a1=1` default for binary treatment, explicit error for continuous/multi-level treatment; `m_cde`/`c_cond` default to sample means, matching `InteractionMediationData`'s existing `m_star` convention). One new `engine_args=list()` param as the override escape hatch — consistent with the original roadmap's `engine_args` philosophy (§7c.5), scoped down to what's actually needed. |
| 9 | API consistency: should `fit_mediation(engine="regmedint")` get its own `decomposition=` override argument, mirroring `extract_mediation()`'s? | No — auto-only. `engine_args=list(interaction=FALSE/TRUE)` (from #8's escape hatch) already gives an explicit override path; a second, differently-named override argument on a brand-new engine with zero users yet is redundant surface area. Revisit only if real usage shows the auto-detection guesses wrong often. |

## Open Questions (deferred to implementation time, not re-litigated here)

- PR split mechanics (likely 2 PRs: adapter core + class-selection logic, then vignette/pkgdown/NEWS — down from the original 3-PR CMAverse plan now that there's no separate registry PR).
- Exact wording of the `engine_args` documentation and the continuous/multi-level-treatment error message from decision #8.
- Whether `EXTENSIONS-PLAN-2026-06-03.md`'s Ext C row needs updating now to say "regmedint" rather than "CMAverse" (mechanical doc-sync, not a design decision).

## Handoff

`/craft:plan planning/specs/SPEC-engine-adapter-architecture-2026-08-22.md` (or the revised version,
once updated) → task breakdown → feature worktree off `dev`.
