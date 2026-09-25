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
  σ̂_ij = 0 exactly. That holds for a serial chain whose covariate sets nest (G4 makes them
  identical), and for the outcome equation against every mediator equation.
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
  8 (renumbered 1–6, 8 and 9 after G1–G4 added a test group). The SE oracle calls `.effect_se()`
  directly.
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

### G7: adverse-review triage (2026-09-23)

**Source:** an independent review via the OpenCode MCP, model `opencode/nemotron-3-ultra-free`
(OpenCode Zen), read-only `plan` agent, session `ses_f2e774a90ffeIkbFFtgxdOXnKn`. It came back with
11 findings and the verdict REVISE. The paid `opencode/gpt-6-sol` run failed with HTTP 402
(insufficient account funds). Each finding was checked against the code or a direct R run before
triage.

| # | Finding | Triage |
|---|---|---|
| 1, 7 | "σ̂_ij = 0 exactly is false in finite samples" (BLOCKER) | **Rejected, empirically.** OLS residuals are orthogonal to their own column space, and e1 lies in equation 2's. An R run (n = 500) gave serial and outcome cross-products of about 1e-14 against 176 for the parallel pair. **A new caveat surfaced:** with `weights`, the zero holds only for the weighted cross-product, so weighted and intercept-free models error in module 1 |
| 2 | Oracle 1 circular | **Accepted.** The truth now comes from simulating nested counterfactuals from the data-generating process, not from the formulas |
| 3 | Covariate means | **Partly accepted.** The value at `c̄` equals the sample-average effect exactly (linearity), so that part of the claim was wrong. But the delta-method SE is conditional on the observed covariates, and the docs now say so |
| 4 | `m_star` validator vs a scalar default | **Accepted (clarity).** The extractor expands a scalar into a named vector before construction |
| 5 | `I(X*M)` bypasses the guard | **Confirmed on `dev`.** `I(X * M2)` returns `SerialMediationData` silently. Detection moves to `all.vars()` per term. Precomputed columns are documented as undetectable. **The existing D8(a) guard has this bug today**, a candidate for a separate fix PR |
| 6 | Identical covariates stricter than the paper | **Accepted (wording).** Documented as a medfit limitation; nested sets are future work |
| 8 | 3% tolerance unjustified | **Accepted.** 3% is about 3 Monte Carlo SEs at B = 5,000, and the fixture uses n ≥ 5,000 |
| 9 | The class may not generalize to later modules | **Deferred** to those modules' specs |
| 10 | `a` vs `a*` in the NIE | **Accepted.** Footnote added |
| 11 | G1 is a breaking change | **Rejected.** Those fits error today, so nothing that currently works changes |

### G8: second adverse review (2026-09-23)

**Source:** OpenCode MCP, model `opencode/muse-spark-1.3-contributor-free` (OpenCode Zen, $0),
read-only `plan` agent. It came back with 11 findings and the verdict REVISE. All 11 were new.
Every code claim was checked. Two of them also exposed **live bugs on `dev`**, outside this spec
(below).

| # | Finding | Triage |
|---|---|---|
| 1 | Raw vs propagated `β1` never disambiguated. A downstream product (`X:M2`, `d ≠ 0`) would drop the `θ3 d β1*(1)` piece | **Accepted.** Propagated `β0*`/`β1*`/`γ*` are defined explicitly. The fixtures require `d ≠ 0` with upstream **and** downstream products, plus a raw-wiring negative control |
| 2 | Aliases alone can't reproduce NDE; gradient terms not listed | **Accepted.** Per-equation source rows plus path aliases, the full list of gradient terms, and a documented `statistic_fn` recipe |
| 3 | Routing ignores which model a product is in; treatment type unchecked | **Accepted.** A product is allowed only as an outcome-model X × mediator; anywhere else it errors, naming the model. Treatment must be numeric 0/1 |
| 4 | `decomposition`/`structure`/`vcov_fun` unspecified on the joint branch | **Accepted.** `two_way` with a product errors, a conflicting `structure` errors, and a non-default `vcov_fun` errors in module 1. Verified: the existing workers hardcode `stats::vcov` (`R/extract-lm.R:691-692`) |
| 5 | Every mediator not required in the outcome model; assumption 4 misstated | **Accepted.** Verified: the serial worker checks only the last mediator. Now every mediator is required, and assumption 4 says "outside the mediator vector" |
| 6 | Heavy oracles unsuitable for CRAN; qualitative oracle | **Accepted.** `skip_on_cran()` on the heavy oracles, always-on pinned companions, and the qualitative check replaced by a 1e-8 parallel reduction. Fixed seeds already make the tests deterministic, so flakiness is moot |
| 7 | Validator tautological and absolute; no path slots | **Accepted.** Relative tolerance, path slots, and validator ties for NIE and CDE |
| 8 | pm/tidy/glance/confint unspecified; `R/bootstrap.R` missing | **Accepted.** Verified: `.assert_param_mediation_data()` hardcodes four classes. The contract is defined and the file added to PR A |
| 9 | Identity link never required | **Accepted.** Verified live on `dev`: the four-way path accepts `gaussian(link = "log")` |
| 10 | Stale #74 premise; G2/G4 wording; G5 test numbering; fixtures; the `m_star` claim | **Accepted.** All corrected. Verified: `extract_mediation()` ignores `m_star` when there is no product |
| 11 | Rows, weights, intercept and order checks sketched but not specified | **Accepted.** Row-name identity, detectors for weights and missing intercepts, mediator order as causal order, and stronger wording on precomputed columns |

**Live bugs on `dev` found while verifying (separate fixes, not D8(b)):**
1. `fit_mediation(Y ~ X * M + C, ..., se_type = "sandwich")` returns a vcov identical to
   `se_type = "model"`, so the four-way path silently ignores `vcov_fun`. Simple fits do get the
   sandwich. Reproduced 2026-09-23.
2. `extract_mediation()` with a `gaussian(link = "log")` outcome and an X × M product returns an
   `InteractionMediationData` using identity-link formulas. The four-way check tests only the
   family name (`R/extract-lm.R:624-631`). Reproduced 2026-09-23.
3. `extract_mediation(..., m_star = <value>)` with no product silently ignores `m_star`. Only
   `fit_mediation()` rejects it.

### G9: consistency pass, harness and outcomes, approval (2026-09-23)

**Request:** "fix all the issues and approve; add harness and outcomes."

**Consistency fixes** (places where later decisions weren't carried through):
1. `m_star` without a product: the note said it was "silently ignored, tracked separately". PR #75
   fixed that, so the joint branch reuses `.stop_on_unused_m_star()`.
2. The bootstrap bullet said every coefficient has an alias row. It now matches G8: aliases for
   paths, prefixed source rows for intercepts and covariate coefficients.
3. Test group 7 said "runs on the alias names" and "wrong-length `m_star`". Both now match G3 and G8
   (the full-`@estimates` recipe reproduces NDE/NIE; `m_star` names; path-tie violations).
4. Resolved question 4 claimed "equals the population-average effect". Corrected to "sample
   average, SE conditional on the observed covariates" (G7).
5. The code-style snippet showed the flat routing G8 replaced. It now names the outcome model and
   documents that allowed terms are removed first.
6. The `vcov_fun` rule now notes #75 (the existing workers honor it; only the joint branch refuses
   it, because the stacked-OLS blocks assume OLS). `fit_mediation()` never reaches the joint branch.
7. PR A adds the class to `R/bootstrap.R` but had no test for it. A plugin-bootstrap acceptance
   check is added to test group 8.
8. The Behavior bullet now says identity link alongside Gaussian.

**Added:**
- **Verification harness:** `helper-joint.R` with independent oracles (counterfactual-simulation
  truth, g-computation from the fitted models, nonparametric bootstrap SE), planted defects injected
  through an `effect_fn` argument without editing production code, `skip_on_cran()` gating with
  pinned always-on companions, a required check that CI actually runs the heavy oracles, and a
  fresh-session E2E transcript per PR.
- **Outcomes:** a table of each check's expected outcome, pass criterion and PR. Two rows are
  labeled targets to measure first: CRAN runtime under 10 s, and heavy oracles executed on CI.

**Decision:** the spec is **approved** by the user. Next step: the task plan
(`PLAN-joint-mediator-interactions-2026-09-23.md`), PR A first.
