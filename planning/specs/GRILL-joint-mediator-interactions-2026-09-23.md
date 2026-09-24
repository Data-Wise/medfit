# Grill: D8(b) joint-mediator interaction spec

**Date:** 2026-09-23
**Target:** [SPEC-joint-mediator-interactions-2026-09-23.md](SPEC-joint-mediator-interactions-2026-09-23.md) (draft)
**Pre-sweep facts:**
- `nie(<SerialMediationData>)` is `a * prod(d) * b`, the path through the whole chain only
  (`R/generics-effects.R:276`).
- `nie(<ParallelMediationData>)` is `sum(a_paths * b_paths)` (`:344`).
- medfit uses a unit 0 → 1 treatment contrast (`R/fit-regmedint.R:27`).
- The four-way path evaluates the mediator reference level at the covariate sample means
  (`R/extract-lm.R:611-615`).

## Decisions

### G1: product terms change what `nie()` means for serial fits

**Finding:**
- Without a product, `nie()` on a serial fit is chain-only (`a*d*b`).
- With a product, the joint NIE counts every mediated path.
- So adding `X:M2` makes the NIE jump for reasons unrelated to the interaction.

**Decision:** label, document and pin it.
- `print()` and the docs say "joint NIE (all paths through M1..MK)".
- A test pins the difference: with θ3 = 0 in the data-generating process, the joint NIE equals the
  sum over all mediated paths, not `a*d*b`.

**Rejected:**
- an opt-in `estimand = "joint"` for no-product fits now (a small follow-up, not module 1);
- documenting it silently in `@details` only.

### G2: standard errors for parallel mediators

**Finding:**
- The spec kept a vcov that is block-diagonal across equations.
- For parallel mediators with correlated residuals, that ignores Cov(β̂i, β̂j), so the joint NIE's
  delta-method SE is wrong.

**Decision:** for `JointMediationData` only, fill the cross-equation blocks with the stacked-OLS
covariance σ̂_ij (Xi'Xi)⁻¹ Xi'Xj (Xj'Xj)⁻¹, where σ̂_ij is the mean residual cross-product.
- The same rule covers both structures. When a residual lies in another equation's column space,
  σ̂_ij = 0 exactly. That holds for a serial chain whose covariate sets nest, and for the outcome
  equation against every mediator equation.
- So serial and outcome blocks stay zero, and only parallel mediator–mediator blocks become
  nonzero.
- All models must share the same rows; error if they differ.
- This is a medfit-side step, checked by the bootstrap oracle (within 3% for **both** structures).
- Existing classes are untouched.

**Rejected:**
- keeping block-diagonal and documenting it (knowingly wrong parallel SEs);
- NA SEs with the bootstrap required (breaks the #70 `tidy()` contract).

### G3: shape of `m_star`

**Finding:**
- The CDE uses m(i) only for mediators that carry an X×M product.
- A length-K vector would silently ignore the other entries, the same silent no-op the existing
  `m_star` rule forbids.

**Decision:** `m_star` is a scalar (applied to every interacting mediator) or a named vector keyed
by the interacting mediators only. Unknown or non-interacting names error. The validator checks the
names against `@interactions`.

**Rejected:**
- a positional length-K vector (entries silently ignored);
- a scalar only (can't set different reference levels).

### G4: covariate sets across models

**Finding:** differing covariate sets across models (say `M1 ~ X + C1`, `M2 ~ X + M1 + C2`) quietly
break two exactness claims: the propagation identity (spec test 4) and G2's zero blocks. They also
sit badly with the paper's assumption that confounders are controlled for every mediator.

**Decision:** every model (all mediator models and the outcome) must carry the same covariate set,
after removing the treatment and the mediators. Otherwise error, naming the differing terms. With
identical sets, serial regressors nest, so the identities and zero blocks are exact. Parallel
mediator models share their regressors, so their cross-block is σ̂_ij (X'X)⁻¹.

**Rejected:**
- allowing differing sets with a warning (exact tests cover only the nested case, and a warning is
  easy to miss);
- allowing them silently.

### G5: PR slicing

**Decision:** two PRs.
- **PR A:** class, extractor, guard narrowing, cross-equation vcov (G2), `.effect_gradients()` and
  the effect generics (`nie`/`nde`/`te`/`pm`/`decompose`/`paths`). It carries oracle tests 1–6 and
  8. The SE oracle calls `.effect_se()` directly.
- **PR B:** methods contract (`print`/`summary`/`confint`/`tidy`/`glance`, bootstrap aliases), NEWS,
  pkgdown and the Model Extraction section.
- Between the merges, `dev` briefly has a class without `tidy()`/`confint()`. No CRAN release is
  planned, so that's harmless.

**Rejected:**
- one PR (large, hard-to-review diff);
- three PRs with the vcov split out (the vcov is useless without the effects).

### G6: closed on recommended answers at the checkpoint

- **Class name:** `JointMediationData` (it names the estimand).
- **Gradients:** analytic, matching `.effect_gradients()`. The serial NIE is differentiated through
  the propagated mediator means by the chain rule.
- **Pre-answered by existing conventions:**
  - Unit treatment contrast 0 → 1 (as in `R/fit-regmedint.R`).
  - The NDE is evaluated at the covariate sample means (as in the four-way path). The joint effects
    are linear in `c`, so the value at the means equals the population-average effect. The means are
    treated as fixed in the delta method, as in the four-way path.
- **Four-way split for K ≥ 2:** stays out unless a verified source is found.

## Outcome

G1–G6 are folded into the spec (same date).

## Open questions

None blocking. Later modules (`joint-mm`, `joint-lavaan`, `joint-nongaussian`) and an opt-in
`estimand = "joint"` for no-product fits (from G1) each need their own spec.
