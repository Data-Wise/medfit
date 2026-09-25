# GRILL: effect standard errors in `tidy()`

**Date:** 2026-09-23 · **Status:** resolved (D1–D7) · **Branch:** `dev` (decision record only)
**Origin:** open question from PR #68 (`tidy()`/`glance()` for Parallel + Interaction, `f1ad7b2`):
path SEs come from the `vcov` diagonal, effect/component rows are `NA`, matching `MediationData`.

## Pre-answers (codebase sweep)

| Fact | Evidence |
|---|---|
| `confint(parm = "effects")` already has delta-method SEs for Simple, Parallel, Interaction | `R/methods-base.R` confint methods for `MediationData`, `ParallelMediationData`, `InteractionMediationData` |
| `tidy()` reports `NA` for the same rows, so `tidy(conf.int = TRUE)` disagrees with `confint()` | `R/methods-tidy.R` (`MediationData` "all" branch; Parallel/Interaction `path_se` + `NA`) |
| Simple `confint()` TE SE is wrong: assumes Var(TE) = Var(NIE) + Var(c'), dropping Cov(ab, c') = a Cov(b, c') | `mediation_demo` simple fit: current 0.1273, full gradient 0.1194, parametric bootstrap (20,000 draws) SD 0.1193 |
| Simple `confint()` hard-codes Cov(a, b) = 0 | harmless for separate lm fits and for this saturated lavaan fit (Cov(a,b) ~ 6e-19), not true in general |
| `confint()` warns (Simple, Parallel) or messages (Interaction) on every call | same methods |
| No SE anywhere for `pm`; `SerialMediationData` has no effects `confint()` | grep |

## Decisions

### D1 — Scope: `tidy()` reports delta-method effect SEs via one shared helper

**Decision:** `tidy()` and `confint()` both call a single gradient-over-`vcov` helper, so
`tidy(conf.int = TRUE)` and `confint()` cannot disagree. `NA` effect rows in Simple, Parallel and
Interaction become numbers.
**Rejected:** copying `confint()`'s formulas into `tidy()` (two paths drift; would copy the TE bug);
keeping `NA` (leaves the inconsistency); a bootstrap-only `tidy(boot = ...)` path (new API, still
inconsistent for the plain case).

### D2 — Fix the Simple `confint()` TE SE in the same change

**Decision:** route `confint(<MediationData>, parm = "effects")` through the D1 helper, which uses
the full `vcov` (including Cov(b, c') and Cov(a, b)). TE intervals get narrower and correct. NEWS
"Bug fixes" entry: the old formula assumed NIE and c' independent. No deprecation cycle; this is a
correctness fix, not an API change.
**Rejected:** a deprecation cycle (preserves a known-wrong answer); a separate PR first (two PRs
touching the same functions back to back); leaving it (contradicts D1).

### D3 — `tidy()` is silent; the approximation is documented

**Decision:** `tidy()` emits no warning or message for effect SEs. Its `@details` states that effect
SEs are delta-method normal approximations and points to `bootstrap_mediation()`. `confint()` keeps
its current warning/message, since that is where users choose an inference method.
**Rejected:** warn once per session (adds session state to `tidy()`); warn every call (breaks quiet
`map()` + `tidy()` pipelines and downstream `expect_silent()`); silencing `confint()` too (drops an
existing nudge toward bootstrap).

### D4 — No SE for the proportion mediated

**Decision:** PM = NIE / TE gets no delta-method SE anywhere. It is a ratio whose delta SE is
unstable and whose sampling distribution is badly skewed as TE nears 0. `pm` appears only in
`glance()` (no SE columns) and `tidy()` has no `pm` row, so existing output is unchanged; the docs
say to bootstrap PM.
**Rejected:** a delta-method SE (unstable near TE = 0, CIs can leave [0, 1]); an SE only when TE
is clearly nonzero (arbitrary cutoff); dropping `pm` from output (breaking).

### D5 — Serial is in scope

**Decision:** `SerialMediationData` joins the helper in the same change: `tidy()` gains path SEs
and delta-method NIE/NDE/TE SEs (gradient of a * d1 * ... * b, plus c'), `tidy(conf.int = TRUE)`
stops returning `NA` with a warning, and a new `confint(<SerialMediationData>, parm = "paths" |
"effects")` method is added. All four classes then behave the same.
**Rejected:** Serial `tidy()` only (reopens the D1 gap for Serial); a separate PR (Serial keeps NA +
warning meanwhile); bootstrap-only for Serial permanently.

### D6 — Verify against two independent oracles

**Decision:** for each class, compare the helper's effect SEs with (a) lavaan's `:=`
defined-parameter SEs from a jointly fitted model (delta method on the same `vcov`; tolerance
~1e-6; `skip_if_not_installed("lavaan")`) and (b) the SD of a fixed-seed parametric bootstrap from
`bootstrap_mediation()` (~3% tolerance). Add a `tidy()` == `confint()` consistency test and a D2
regression pin (Simple TE SE 0.1194 on `mediation_demo`, not the old 0.1273). Positive control: a
planted sign error in any gradient must fail both oracles.
**Rejected:** a numerical-gradient check (shares any `vcov`-handling mistake; adds `numDeriv`);
consistency tests alone (cannot fail on a wrong formula); hand-computed pins alone (share the
code's reasoning).

### D7 — Announce through NEWS only

**Decision:** a "New features" entry (effect SEs in `tidy()` for all four classes; new
`confint(<SerialMediationData>)`) and a "Bug fixes" entry (Simple TE SE). No ecosystem issue: a
read-only scan of probmed, RMediation, medrobust, medsim, mediationverse and missingmed (`R/` and
`tests/`) found 0 uses of `tidy()`/`glance()`/`confint()` on medfit objects. `NA` becoming a number
is additive and the TE change is a bug fix, so the breaking-change process does not apply.
**Rejected:** a courtesy ecosystem issue (noise with no affected package); treating it as breaking
(2-month delay for output no dependent consumes).

## Implementation sketch (for the plan, not binding)

- One internal helper, e.g. `.effect_se(x, terms)`, returning named SEs from `sqrt(g' V g)` with
  gradients built on the alias rows already in `@vcov` (`a`, `b`, `c_prime`; `d1..`; `a1, b1, ..`).
- Simple: NIE = a b, NDE = c', TE = a b + c'. Serial: NIE = a prod(d) b, TE = NIE + c'.
  Parallel: NIE = sum(a_j b_j). Interaction: reuse the existing component gradients in
  `confint(<InteractionMediationData>)`; the regmedint engine already stores its own delta-method
  `vcov` for components and keeps using it.
- `confint(parm = "effects")` for all four classes and `tidy()` call the helper; `tidy()` does not
  warn (D3).
- Feature branch + worktree; tests per D6; NEWS per D7.

## Open Questions

- The lm serial chain's `vcov` is block-diagonal across equations (documented in the Model
  Extraction article). The helper will inherit that; say so in `?tidy` next to the D3 note, or is
  the article enough?
- Should `tidy()` gain a `conf.method` argument later (normal vs bootstrap via a `BootstrapResult`)?
  Out of scope here; revisit only if asked.

