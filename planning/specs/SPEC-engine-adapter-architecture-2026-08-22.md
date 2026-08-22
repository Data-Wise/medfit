# SPEC: Engine Adapter Architecture (Extension C) — regmedint adapter

**Status:** Draft, grilled · **Created:** 2026-08-22 · **Author:** Davood Tofighi (with Claude Code)
**Plan:** `planning/EXTENSIONS-PLAN-2026-06-03.md` → **Extension C** (gate: Extension B merged ✓ — #38/#39/#40)
**Design source:** `planning/medfit-roadmap.md §7b–7c` (original design, pre-Ext-A/B — substantially
revised below after an adversarial-review pass + a 9-branch grill session; see
`GRILL-engine-adapter-architecture-2026-08-22.md` for the full decision ledger and rationale)
**Reuses (do NOT reimplement):** the one-class-per-structure pattern
(`MediationData`/`InteractionMediationData`); the `@vcov` naming-alias contract
(`.expand_vcov_with_aliases()`, `R/utils.R`); `InteractionMediationData`'s existing `m_star`
convention (reused for regmedint's `m_cde`/`c_cond` evaluation-point defaults — see the §5
correction note: the actual convention is `m_star = 0`, not the sample mean).

---

## 0. What changed from the original draft (§7b/7c) and why

This spec was rewritten after two review passes found the original design (CMAverse-first,
generic `Decomposition` class, full engine registry) didn't fit what actually shipped in Ext A/B,
and rested on an unverified external-package assumption. Verified, load-bearing changes:

1. **Adapter target: regmedint, not CMAverse.** CMAverse is confirmed **not on CRAN**
   (`"CMAverse" %in% rownames(available.packages(...))` → `FALSE`, checked live 2026-08-22). A
   CRAN-published package (medfit 0.3.2) taking on a non-CRAN `Suggests` dependency is a real
   check-farm risk. **regmedint** (CRAN, v1.0.2) is already medfit's own validation target for Ext
   B's four-way decomposition (`SPEC-interaction-fourway-2026-06-03.md` references it), is
   closed-form/regression-based, and its `pnde/tnde/tnie/pnie/cde/te` output maps exactly onto
   `InteractionMediationData`'s slots (verified numerically, §3). CMAverse (comprehensive g-formula/
   IPW/TMLE, per the original §7c.4 rationale) is deferred to a named follow-up spec (§7).
2. **No generic `Decomposition` class, no engine registry.** Both were designed pre-Ext-A/B and
   never needed: `ParallelMediationData`/`InteractionMediationData` shipped as concrete classes, and
   `fit_mediation()`'s actual dispatch today is a hardcoded `checkmate::assert_choice()` + `switch`
   (`R/fit-glm.R:131,175-189`), not the registry §7c.6 sketched. This spec extends the *existing*
   mechanism minimally rather than introducing either abstraction — revisit only when a 3rd external
   engine actually needs it.
3. **Scope narrowed to closed-form methods.** `nie()`/`nde()` on `MediationData` are **computed
   live** as `a_path * b_path` (`R/methods-base.R:62`), not stored — a simulation-based estimate
   (g-formula/IPW) has no correct slot to occupy without new class surface. Closed-form regression
   methods (regmedint, and CMAverse's own `"rb"` mode) don't have this problem because their
   reported effects are *identical in form* to what `MediationData`/`InteractionMediationData`
   already compute. Simulation-based effects are explicitly out of scope here (§7).

## 1. Scope (MVP) and non-goals

**In scope (MVP):**
- One external adapter: **regmedint**, `Suggests`-gated (`requireNamespace()`).
- `fit_mediation(..., engine = "regmedint")` — the *existing* formula-based entry point, extended
  with one new optional `engine_args = list()` parameter for regmedint-specific overrides.
- Auto-detection of simple vs. interaction mediation from `formula_y`'s `X:M` term, exactly
  mirroring `extract_mediation(decomposition = "auto")`'s existing convention — returns
  `MediationData` or `InteractionMediationData` accordingly (§4).
- Auto-derivation of regmedint's required arguments (`cvar`, `mreg`/`yreg`, `a0`/`a1`,
  `m_cde`/`c_cond`) from what `fit_mediation()` already knows, with `engine_args` as the override
  escape hatch (§5).
- Delta-method SE propagation for the `InteractionMediationData` mapping, using regmedint's own
  analytical `vcov()` (§3) — no bootstrap dependency.

**Out of scope (deferred, named follow-up):**
- **CMAverse adapter (`SPEC-cmaverse-adapter.md`, not yet written) — Ext C.1.** Blocked on two
  unresolved problems, both surfaced by this grill: (a) CRAN-availability strategy for a non-CRAN
  `Suggests` dependency, (b) how a simulation-based engine's native effect estimates should be
  represented given `nie()`/`nde()`'s live-computation contract (§0.3). Do not start this until both
  are resolved in their own spec.
- A generic `.engine_registry` abstraction (§0.2) — add only when a 3rd external engine arrives.
- `decomposition =` / explicit override argument on `fit_mediation()` — `engine_args =
  list(interaction = TRUE/FALSE)` already covers this; a second override argument is redundant
  surface area for a brand-new engine with no users yet (revisit if auto-detection proves wrong in
  practice).
- Multiple mediators, non-binary treatment beyond the `engine_args` override path, survival/count
  outcomes — matches regmedint's own MVP-relevant capability, not an artificial medfit restriction.

## 2. Dispatch — minimal extension, not a registry

Current code (`R/fit-glm.R:131,175-189`):

```r
checkmate::assert_choice(engine, choices = c("glm"), .var.name = "engine")
...
switch(engine,
  glm = .fit_mediation_glm(...),
  stop(sprintf("Engine '%s' not implemented", engine), call. = FALSE)
)
```

Extended to:

```r
checkmate::assert_choice(engine, choices = c("glm", "regmedint"), .var.name = "engine")
...
switch(engine,
  glm       = .fit_mediation_glm(...),
  regmedint = .adapter_regmedint(formula_y, formula_m, data, treatment, mediator,
                                  family_y, family_m, engine_args, ...),
  stop(sprintf("Engine '%s' not implemented", engine), call. = FALSE)
)
```

New parameter: `engine_args = list()` (default empty — no behavior change for `engine = "glm"`).

**Acceptance criterion:** all existing `fit_mediation(engine = "glm", ...)` test-suite output is
byte-identical before/after this change (explicit regression gate — decision #6 in the grill
ledger, added despite the diff's apparent low risk, matching the precedent Ext A/B both set).

## 3. The regmedint → medfit mapping (verified numerically)

Fitted example (`n=200`, continuous Y/M, binary X, `interaction = TRUE`):

| regmedint | Value | medfit slot | Formula |
|---|---|---|---|
| `cde` | 0.4046578 | `cde` | direct |
| `pnde` | 0.3872047 | — | `cde + int_ref` |
| `tnde` | 0.6245779 | — | `cde + int_ref + int_med` |
| `tnie` | 0.5850776 | — | `int_med + pie` |
| `pnie` | 0.3477044 | `pie` | direct |
| `te` | 0.9722823 | `total_effect` | direct |

Derived: `int_ref = pnde - cde` (= −0.0174531), `int_med = tnie - pnie` (= 0.2373732). **Verified:**
`cde + int_ref + int_med + pie = 0.4046578 + (−0.0174531) + 0.2373732 + 0.3477044 = 0.9722823 = te`
exactly — confirms `InteractionMediationData`'s validator invariant holds by construction, not
approximately.

**SEs:** regmedint exposes `coef()`/`vcov()`/`confint()` directly (7×7 covariance over
`cde/pnde/tnie/tnde/pnie/te/pm`) — analytical, from the delta method regmedint already applies
internally. `Var(int_ref) = Var(pnde) + Var(cde) - 2·Cov(pnde,cde)`; `Var(int_med) = Var(tnie) +
Var(pnie) - 2·Cov(tnie,pnie)` — read directly off regmedint's reported `vcov()`, no re-derivation
of the underlying regression covariance needed.

> **Implementation correction (2026-08-22, Phase 2):** `regmedint::vcov()` (v1.0.2) returns
> **variances only** — every off-diagonal entry is `NA` (`regmedint:::vcov.regmedint` builds
> `diag(se^2)` and blanks the triangles). The covariance route above is therefore unavailable.
> The adapter reproduces regmedint's own delta method instead (same parameter vector
> `(β, θ, σ²)`, same `Σ = bdiag(vcov(mreg), vcov(yreg), 2σ⁴/df)`, same gradients specialized to
> `a0 = 0, a1 = 1`), which yields the full component covariance; its diagonal equals regmedint's
> reported SEs exactly (tested). See `ORCHESTRATE-engine-adapter-architecture.md` Phase 2 notes
> for the other implementation-time findings (representability guard, `m_cde` default caveat).

**Simple-mediation case** (`interaction = FALSE`): regmedint reports plain natural effects
(`nde`/`nie`) directly compatible with `MediationData` — no component mapping needed.

## 4. Class selection — auto-detect, mirroring `extract_mediation()`

```r
.adapter_regmedint <- function(formula_y, formula_m, data, treatment, mediator,
                                family_y, family_m, engine_args = list(), ...) {
  if (!requireNamespace("regmedint", quietly = TRUE)) {
    stop("regmedint package required for engine = 'regmedint'.\n",
         "Install with: install.packages('regmedint')", call. = FALSE)
  }
  has_interaction <- isTRUE(engine_args$interaction) ||
    (!"interaction" %in% names(engine_args) && .formula_has_interaction(formula_y))
  # ... build regmedint() args (§5), call regmedint::regmedint(), dispatch on has_interaction:
  #   TRUE  -> .regmedint_to_interaction_mediation_data() (§3 mapping)
  #   FALSE -> .regmedint_to_mediation_data()
}
```

`.formula_has_interaction()` reuses the same detection helper `extract_mediation(decomposition =
"auto")` already uses — same convention, same helper, not a reimplementation.

## 5. Argument bridging — auto-derive, `engine_args` as override

regmedint requires `yvar, avar, mvar, cvar, a0, a1, m_cde, c_cond, mreg, yreg` — none of which
`fit_mediation()`'s formula-based signature (`formula_y, formula_m, data, treatment, mediator,
family_y, family_m, ...`) currently exposes directly.

| regmedint arg | Auto-derivation | Override via `engine_args` |
|---|---|---|
| `yvar`/`avar`/`mvar` | From `treatment`/`mediator` + `formula_y` LHS | n/a |
| `cvar` | Remaining RHS terms of `formula_y` minus treatment/mediator/interaction | `engine_args$cvar` |
| `mreg`/`yreg` | `family_m`/`family_y`: `gaussian()`→`"linear"`, `binomial()`→`"logistic"` | `engine_args$mreg`/`$yreg` |
| `a0`/`a1` | `0`/`1` if `treatment` is binary in `data`; **error** with an explicit message otherwise (no silent guess for continuous/multi-level treatment) | `engine_args$a0`/`$a1` |
| `m_cde`/`c_cond` | `m_cde = 0`; `c_cond` = covariate sample means — see the correction note below | `engine_args$m_cde`/`$c_cond` |
| `interaction` | Auto-detected per §4 | `engine_args$interaction` |

> **Implementation correction (2026-08-22, Phase 4):** this row originally specified `m_cde` =
> *sample mean of the mediator*, justified as "the same convention as `InteractionMediationData`'s
> existing `m_star` default." That justification was wrong on both counts: the lm/glm extractor
> defaults `m_star = 0` (`R/extract-lm.R:119,153`) and so does the lavaan extractor (asserted in
> `test-extract-interaction-lavaan.R:38`), while regmedint itself has *no* `m_cde` default — it is
> a required argument. Shipping the sample mean would have made the new engine the only one of
> three reporting the CDE/INTref split at a different reference level. **`m_cde` therefore
> defaults to `0`.** `c_cond` keeps the covariate sample means, which does match the lm
> extractor's own `E[M | X = 0]` convention. `nde`/`nie`/`te`/`pm` are invariant to `m*` either
> way; only the CDE/INTref split moves.

## 6. Acceptance criteria

- [ ] `fit_mediation(engine = "glm", ...)` test-suite output byte-identical before/after (§2).
- [ ] `fit_mediation(..., engine = "regmedint")` on a no-interaction formula returns `MediationData`
      with `nde`/`nie` matching regmedint's own `nde`/`nie` output (`skip_if_not_installed("regmedint")`).
- [ ] `fit_mediation(..., engine = "regmedint")` on an `X:M`-interaction formula returns
      `InteractionMediationData` whose `cde/int_ref/int_med/pie` match the §3 mapping within
      numerical tolerance, and whose validator invariants pass (they hold by construction — a
      failure here indicates a mapping bug, not a tolerance issue).
- [ ] Component SEs match delta-method propagation through regmedint's own `vcov()` (§3).
- [ ] Continuous/multi-level treatment without an explicit `engine_args$a0`/`$a1` override produces
      a clear error, not a silent wrong default.
- [ ] `R CMD check --as-cran` clean with regmedint absent (Suggests-gated) **and** present.

## 7. Deferred: CMAverse adapter (Ext C.1 — not yet spec'd)

`SPEC-cmaverse-adapter.md` — blocked on:
1. CRAN-availability strategy (`Additional_repositories`, r-universe, or accepting the CRAN-incoming
   NOTE with full `skip_on_cran()` gating).
2. The engine-native-effects representation problem (§0.3) for simulation-based methods
   (g-formula/IPW), which this spec deliberately does not solve.

Do not begin implementation on Ext C.1 until both are resolved in their own grilled spec.

## References
- `medfit-roadmap.md §7b–7c` (original design source, substantially revised above).
- Regmedint documentation (CRAN, v1.0.2) — `coef()`/`vcov()`/`confint()`/`summary()` methods.
- Internal: `SPEC-interaction-fourway-2026-06-03.md` (regmedint as validation target, `m_star`
  convention reused here); `GRILL-engine-adapter-architecture-2026-08-22.md` (full decision ledger).
