# FEASIBILITY: three additions to the 0.8.0 plan

**Date:** 2026-10-11 | **Basis:** read-only study of medfit `dev` (`d7b3ca1`) and RMediation `dev`; no code changed.
**Companion to:** [BRAINSTORM](BRAINSTORM-medfit-0-8-0-2026-10-11.md), [GRILL ledger](GRILL-medfit-0-8-0-2026-10-11.md) (G1-G9), [RMediation handoff](HANDOFF-rmediation-mbco-on-mbco_sem-2026-10-11.md).
**Tags:** **[V]** verified in code or docs this session; **[R]** my reasoning, not yet checked by a run or a source; **[U]** unverified.
**Decided in the grill:** open questions 1-3 are ledger entries G10 (mbco ownership), G11 (glm recipe in 0.8.0, function in 0.9.0) and G12 (sums of products best-effort); G13 adds the type I error gate for k-path MBCO. The rest of this file is the analysis behind them.

## Summary

| # | Question | Verdict | Size | In 0.8.0? |
|---|---|---|---|---|
| 1 | One function for MBCO | **Feasible**, with one naming constraint | S | Yes (medfit side) |
| 2 | General nonlinear constraint such as `b1*b2*b3` | **Feasible**, an increment on W3; sums of products are the hard case | S to M on top of W3 | Yes, inside W3 |
| 3a | MBCO / joint test for non-normal outcomes (glm) | **Feasible with conditions** | S to M | Yes, if wanted |
| 3b | Natural effects on the outcome scale (odds ratio, risk difference) | **Feasible with conditions**, bigger | L | Later (0.9.0) |
| 3c | Categorical or count outcomes inside the native SEM engine | **Not feasible** in this engine as built | XL | No |

Main risk first: for question 1, medfit and RMediation both exporting a function called `mbco` can mask each other when the mediationverse attaches both **[R]**; the plan avoids it by leaving the generic with RMediation.

## 1. One function for MBCO

**Today [V]:** RMediation exports `mbco(h0, h1, type = "asymp"|"parametric"|"semi")` (two OpenMx models, any nested pair, three test types). medfit exports `mbco_sem(fit, a, b)` (one `SEMFit`, `a*b = 0`, asymptotic min-of-two). `NAMESPACE` has `mbco_sem` only.

**Options**

| Option | What it is | Verdict |
|---|---|---|
| A. `mbco()` stays the one user-facing name, owned by RMediation; medfit supplies engine functions | RMediation's `mbco()` gains a `SEMFit` route that calls `mbco_sem()` (the additive handoff); medfit adds `anova()` for `SEMFit` pairs (G9) | **Recommended.** Matches D9 and the handoff; no second `mbco` name |
| B. medfit defines its own `mbco` generic | One name in medfit, methods per input class | Risky: two exported generics named `mbco`, masking when both attach **[R]**; only workable if RMediation re-exports medfit's generic, which needs medfit on CRAN first (D9) |
| C. Keep two names | `mbco()` (OpenMx) and `mbco_sem()` (SEMFit) | Works today; the user-facing split stays |

**What medfit does under A (S):**
- Generalize `mbco_sem(fit, a, b)` to `mbco_sem(fit, paths)` or keep `a`, `b` and add a `paths` form, so a product of k labeled paths is tested by the minimum of k linear refits (see 2). Keep the current signature working.
- Ship `anova()` / two-model LRT for `SEMFit` (G9) as the general building block.
- Do not export a function named `mbco` from medfit.

## 2. General nonlinear constraint such as `b1*b2*b3`

**What already works [V]:** serial chains are first-class for lm/glm/lavaan: `SerialMediationData`, the chain product `a × d × … × b`, and delta-method SEs through the gradient builder (`R/effect-se.R`), plus `nie(type = "total")` over every path. So a *product of three paths as an estimate* is supported. What is missing is a *constraint* on it in the native engine (`R/sem-constraints.R` rejects every nonlinear row today) and an MBCO for it (`mbco_sem()` documents "only a product of two labeled paths").

**Does the W3 design extend? Yes [R].** W3 turns any nonlinear row into a closure with a central-difference Jacobian, so `b1*b2*b3 == 0`, `== c` and `> k` need no new machinery. Increments:

| Piece | Size | Note |
|---|---|---|
| Zero-product branch split for k factors | S | `b1*b2*b3 == 0` is the union of three linear nulls (`b1 == 0`, `b2 == 0`, `b3 == 0`); solve each as a linear refit, keep the smallest discrepancy. Exact, no nonlinear solve; same idea as today's two-branch split **[R]** |
| MBCO for a product of k paths | S | Minimum of k linear-refit LRTs referred to chi-square(1): an intersection-union test, whose size is at most alpha because the null is the union and rejection needs every component rejected **[R]**. Check against the literature before releasing |
| Parity gate: add one three-product and one sum-of-products problem | S to M | Extends the ~240-run gate (G6) |
| Sum of products (`a1*b1 + a2*b2 == 0`, parallel mediators) | M, **hard** | Not a union of linear nulls, so there is no exact split; falls back to best-of-n multi-start with the spread warning (G2 behavior). Label as best-effort |

**Main risk:** with a product of k >= 3 factors, the constraint's gradient is zero where two or more factors are zero, so the usual constraint qualification fails there and a KKT-based stationarity gate is not meaningful at those points **[R]**. The audit notes the existing code drops a row whose Jacobian vanishes at the start (`R/sem-constraints.R:176` per the audit, **[U]**); the exact branch split avoids depending on this for the equality-zero case. Test explicitly with a fixture where two factors are near zero.

## 3. Indirect effects for non-normal outcomes

"Non-normal" covers two different problems; keep them apart.

**3a. Non-Gaussian families (binary, count, positive):**
- **What exists [V]:** `fit_mediation()` with `family_y`/`family_m` fits any glm family; paths are on the **link scale**, where a*b is not a natural indirect effect on the outcome scale (the docs say so, `R/fit-glm.R:117-120`, `methods.qmd:42-46`). `engine = "regmedint"` gives closed-form effects, but only a linear mediator with a linear or logistic outcome (`R/fit-regmedint.R:293-294`). A treatment-by-mediator term needs Gaussian identity-link models (four-way formulas are linear).
- **Joint test, feasible, S to M [R]:** for a recursive model with no correlated errors the likelihood factors by equation, so the min-of-two LRT reduces to the classic joint significance test (a = 0 from the mediator model, b = 0 from the outcome model, take the weaker). That is valid for any glm family and needs no SEM engine; check the reduction against `mbco_sem()` on Gaussian data before claiming it. It gives a test, not an effect size.
- **Condition:** interpretation stays on the link scale.

**3b. Effects on the outcome scale (odds ratio, risk difference, counts):**
- Needs nonlinear functions of the coefficients (counterfactual predictions, VanderWeele closed forms under a rare-outcome approximation, or g-computation by simulation). Inference by delta method with numerical gradients or by bootstrap; medfit already has both machinery pieces **[V]**.
- Needs definitions decided first: which scale (log OR, OR, RD), which contrast, how covariates are set. Size L; new argument surface and a `scale =` convention; not a 0.8.0 item.
- Cheaper partial step **[R]**: extend the regmedint route's documentation and a `nie()` note for logistic outcomes; no new numerics.

**3c. Categorical or count outcomes in the native SEM engine:** not feasible as built **[V]**: native is Gaussian maximum likelihood on the covariance structure (no thresholds, no WLSMV, no numerical integration). Adding them is a different estimator family (XL). The honest answer for the lavaan comparison article: use lavaan (ordered outcomes, WLSMV) for that case; medfit extracts from lavaan fits already.

**3d. Continuous but non-normal data:** already covered in part **[V]**: nonparametric bootstrap, `se_type = "sandwich"` (HC3 in glm; HC0 in native). Not covered: Satorra-Bentler or other robust chi-square for the SEM test **[U]**. Small item if wanted.

## Recommended placement

| Item | Where |
|---|---|
| 1: k-path `mbco_sem()`, `anova()` for `SEMFit` (G9); no medfit `mbco` generic | W4 (S, the `anova()` part is already there) |
| 2: k-factor products in W3, one extra gate problem, MBCO for k products | W3 (S to M increment) |
| 3a: joint significance / MBCO for glm fits | New small item, W4-adjacent (S to M), if you want it in 0.8.0 |
| 3b: outcome-scale natural effects | 0.9.0 spec first (brainstorm the scale definitions) |
| 3c: categorical in native | Out of scope; document the lavaan route in the comparison article (W5) |

## Open questions for the user

1. Option A for question 1 (RMediation owns the name `mbco`), or does the user want a medfit-owned generic and accept the D9 dependency?
2. Should 3a (joint significance test for glm) go into 0.8.0, or wait for 3b so effect sizes and the test arrive together?
3. For sums of products, is "best-effort with a spread warning" acceptable, or must the parity gate pass for them too (which may not be achievable)?
