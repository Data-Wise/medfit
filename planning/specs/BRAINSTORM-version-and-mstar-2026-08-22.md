# BRAINSTORM: The `0.4.0` claim, and `m_star` as a first-class argument

**Date:** 2026-08-22 · **Branch:** `feature/engine-adapter-architecture` (Ext C complete, `11480ce`)
**Scope:** two items raised after Phase 4 landed.
**Companion:** `BRAINSTORM-ext-c-phase4-decisions-2026-08-22.md` — decisions 1–3, already applied.
**Not in scope:** re-opening any of the 9 locked grill decisions.

---

## TL;DR

| # | Item | Answer | Effort |
|---|---|---|---|
| 1 | Is `0.4.0` a claim we should walk back? | **No — keep it.** A version string on a feature branch is not a release. | 0 min |
| 2 | Promote `m_star` to a `fit_mediation()` argument? | **Yes, but as its own spec + PR.** Four sub-decisions below. | ~1.5 hr |

These are not coequal in urgency. #1 decides before this branch lands. #2 is a future session.

---

## First: the check that could have changed the answer

`confint(InteractionMediationData)` is the **only** edit on this branch that touches an
already-released code path. The new branch prefers an engine-supplied component covariance block
when `all(c("cde","int_ref","int_med","pie","nde","nie","total_effect") %in% rownames(@vcov))`.
The argument that it cannot fire for existing objects was *structural* (it sits ahead of the
gradient path). Structural arguments are not evidence, so it was tested directly:

```
lm  extract, no cov        m_*, y_*, a, b, c_prime, theta3, b0            ALL7 = FALSE
lm  extract, +cov          m_*, y_*, a, b, c_prime, theta3, b0            ALL7 = FALSE
glm fit_mediation          m_*, y_*, a, b, c_prime, theta3, b0            ALL7 = FALSE
glm fit_mediation +cov     m_*, y_*, a, b, c_prime, theta3, b0            ALL7 = FALSE
lavaan extract             M~X, Y~X, Y~M, Y~XM, M~~M, Y~~Y, a, b, c_prime ALL7 = FALSE
regmedint engine           ... + cde, int_ref, int_med, pie, nde, nie, total_effect   ALL7 = TRUE
```

**The new branch fires for regmedint-built objects only.** No existing user's confidence interval
moves. This matters more than the version number would have: had it come back TRUE, the branch
would be changing shipped behavior, not adding to it.

---

## Item 1 — `0.4.0`

### The reframe

A `Version:` string in `DESCRIPTION` on a feature branch **is not a release claim.** The public
claim is the git tag plus the GitHub release, and `git tag --list` ends at `v0.3.2` — there is no
`v0.4.0`. `CLAUDE.md`'s own release pipeline puts the bump at *step 1*, before the PR, with the
tag several steps later. The number stays revisable right up to the `dev → main` PR title.

So the question "is this a claim I have to stand behind" has the answer: not yet, and not until
you tag it.

### What it would cost if the number were wrong

Nothing downstream. Every dependent pins medfit as a **floor**, never an equality or a maximum:

| Package | Constraint |
|---|---|
| mediationverse | `medfit (>= 0.2.0)` |
| medsim | `medfit (>= 0.2.0)` |
| rmediation | `medfit (>= 0.2.0)` |
| probmed | `medfit (>= 0.3.0)` |
| missingmed | `medfit (>= 0.3.1)` + unpinned `Remotes: data-wise/medfit` |

A floor cannot be violated by going *up*. The one thing to note: missingmed's `Remotes` entry is
unpinned, so it tracks medfit's default branch — it will see `0.4.0` when this reaches `main`, not
when it reaches `dev`. Still a floor, still satisfied.

### Reverting is available but costs more than it saves

Two lines back to `0.3.2`, but: the strict-flavor WARNING returns on every check run, and `NEWS.md`
loses its heading (the file has **never** carried an `[Unreleased]`/development-version section —
`git log -S"Unreleased" -- NEWS.md` has zero hits). You would be trading a clean 0/0/0 for a
recurring "is that the known one?" on each strict run.

**Non-blocker, separate axis:** 0.3.2 published 2026-07-23; today is 2026-08-22, ~30 days. That
affects *when* to submit to CRAN, not what to call it.

---

## Item 2 — `m_star` as a `fit_mediation()` argument

### Lead evidence

```r
fit_mediation(Y ~ X * M, M ~ X, data = d, treatment = "X", mediator = "M", m_star = 1)
#> ERROR: unused argument (m_star = 1)
```

A **hard error**, raised by `glm.control()` after `...` routes the argument into `stats::glm()`.
There is no silent behavior to preserve, so the change is purely additive — the strongest possible
starting position for a signature change on an exported function.

The gap is real: `.fit_mediation_glm()` calls `extract_mediation()` without `m_star`, so it always
takes the default `0`. A user fitting `Y ~ X * M` through `fit_mediation()` **cannot reach the
reference level at all**, on any engine except regmedint (via `engine_args$m_cde`).

### The four sub-decisions the spec must make

**1. Precedence against `engine_args$m_cde` — recommend: collapse to one knob.**
They are one concept with two spellings. `m_cde` was only ever regmedint's local name for it. Ship
both and you invite an object whose `@m_star` disagrees with the value the engine actually used.
Recommendation: `m_star` becomes the argument; `m_cde` leaves the `known` set in
`.adapter_regmedint()` with a pointed error message. (Alternatives: accept both with documented
precedence; error when both supplied. Both are worse — they preserve the ambiguity.)

**2. State the mechanism asymmetry in the docs.**
For glm, `m_star` is **extraction-time**: the four-way is computed, then evaluated at `m*`.
For regmedint, it is **fitting-time**: `m_cde` goes into regmedint's own closed-form `cde`
estimator. Same observable effect, different path. Writing this down is what makes a single
argument routing to both coherent rather than a leaky abstraction — and it is the first thing a
reviewer will ask about.

**3. Behavior on the two-way path.** `fit_mediation(Y ~ X + M, ..., m_star = 1)` has nothing to
apply to. Pick silent-ignore, warn, or error — and pick it in the spec, or it surfaces in review.

**4. Signature hygiene.** Append after `engine_args`, before `...`. Never insert ahead of an
existing named argument: positional callers reaching through `se_type` must keep working.

---

## Boundary: grill #9 stays closed

Decision #9 rejected a `decomposition=` argument, and this is **not** a re-open. #9 rejected a
*mode* argument — one that changes which class comes back. `m_star` is a *value* argument that
changes a number inside a class already being returned. `decomposition` remains unexposed; the
follow-up spec must not drift into it.

---

## Consolidated action list

### Do now (< 5 min)

1. **Keep `0.4.0`.** No edit. The tag, not the string, is the claim — and every downstream pin is
   a floor.

### Later (own session, ~1.5 hr) — **DONE 2026-08-22**

2. ~~**`SPEC-m-star-argument-<date>.md`**~~ — written and implemented the same session; see
   `SPEC-m-star-argument-2026-08-22.md`. All four sub-decisions landed as recommended.
   Original scope:

   **`SPEC-m-star-argument-<date>.md`** — the four sub-decisions above, then implement: signature,
   thread through `.fit_mediation_glm()` → `extract_mediation()`, retire `engine_args$m_cde`, docs,
   tests for both engines + the two-way path.

### Not doing

3. `decomposition=` — locked closed by grill #9.

---

## Recommended Next Step

→ **Nothing on item 1 — it is already correct.** The only open thread is item 2, and it belongs to
a future session with its own spec. The `confint` verification above is what actually needed doing
before this branch lands, and it passed.
