# Solver benchmark: precommitted design (medfit solver plan v2, §7.2 item 5)

**Committed before any benchmark code runs.** Any change after the first run must be listed in a
"Deviations" section with its reason; results are reported under this design first.

**Purpose.** Decide whether Tier 1 (substitution chart + `nlminb`) becomes medfit's default for
constraints ab = q ≠ 0. Also report, descriptively, how the solvers behave on q = 0 (Tier 0) and on
the other fixtures.

**Software.** R 4.6.1 on the Mac; `stats::nlminb`; `nloptr` (installed version); `Rsolnp` ≥ 2.0.1
in a private library (`rlib/`, gitignored). Base seed **20261024**; cell c uses seed 20261024 + c.

## Model and objective (observed variables, centered data, no intercepts)

- **Two-path model:** M = aX + e_M, Y = c′X + bM + e_Y.
- **Parameters:** θ = (a, b, c′, log ψ_M, log ψ_Y).
- **Objective:** F(θ) = n log ψ_M + RSS_M(a)/ψ_M + n log ψ_Y + RSS_Y(c′, b)/ψ_Y, which is −2 log L
  up to a constant. LR(q) = min over {ab = q} of F − min F.
- **Three-path chain:** X → M1 → M2 → Y, with parameters (b1, b2, b3, three log variances).
- **Parallel model (stratum fixture):** X → M1 → Y (b1, b2), X → M2 → Y (b3, b4), direct path c′;
  constraint b1 b2 = b3 b4.

## Oracles

| Fixture | Oracle |
|---|---|
| q = 0 products | closed form: LR = min_j n log(RSS_j,0 / RSS_j,1) (Berger 1997) |
| ab = q ≠ 0 | exact 1-D profile P(a) = n log RSS_M(a) + n log min_{c′} RSS_Y(c′, q/a), over a < 0 and a > 0: grid per sign: 20,001 points with |a| log-spaced over [1e-6, 1e3]·sd(m)/sd(x), plus 2,001 linear points over â ± 8 SE(â) on that sign, then `optimize()` on every bracketed local minimum; oracle = smallest |
| memory RQ1, RQ2 | closed form (72.5436, 0.0831; `empirical_example_branches.R`) |
| memory RQ3 | best known: 25.8283 (600 BFGS starts, same script); success = within tolerance of it |
| b1 b2 = b3 b4 stratum | best known = min over (chart b4 = b1 b2/b3, 200 starts; chart b2 = b3 b4/b1, 200 starts; stratum b1 = b3 = 0 in closed form) |

## Methods (identical start sets for the constrained solvers)

| Label | What runs |
|---|---|
| **T0** | q = 0: k branch fits with `nlminb` (analytic gradient), each started at the MLE with the branch path set to 0; best accepted branch |
| **T1** | q ≠ 0: chart a = s·exp(φ), b = q/a for s = ±1. Outer grid of 41 φ values centred on log max(\|â\|, SE(â)), spanning ±8 (natural-log units), then `nlminb` on (φ, c′, log ψ's) from the best 3 grid points per sign. Stratum fixture: both charts + the stratum branch. |
| **AUG** | `nloptr` `NLOPT_LD_AUGLAG`, local `NLOPT_LD_LBFGS`, equality g(θ) = ab − q with analytic Jacobian; `xtol_rel` 1e-10, `maxeval` 20,000 |
| **SLSQP** | `nloptr` `NLOPT_LD_SLSQP`, same settings |
| **CSOLNP** | `Rsolnp::csolnp`, same objective, gradient and Jacobian, default control |

**Start set for AUG, SLSQP and CSOLNP:** the MLE plus its sign flips (a, b) → (−a, b), (a, −b),
(−a, −b), with the variances at their MLEs. For q ≠ 0 each start is first projected onto the
constraint by b ← q/a. This mirrors `sem-optim.R`'s best-of / sign-flip logic.

**Acceptance of a fit:**
- finite;
- status success (nlminb convergence 0; nloptr status > 0; csolnp convergence 0);
- |g(θ)| ≤ 1e-8·max(1, |q|).

The method's answer is the lowest F among its accepted fits. **Unresolved** means no accepted fit.

## Outcome per dataset and method

- **Success:** accepted and |LR − oracle| ≤ 1e-6·max(1, oracle).
- **Accepted-wrong:** accepted but not a success.
- **Unresolved:** no accepted fit; counts as a failure.
- **Infeasible returns:** fits with |g| > tolerance, counted separately over all starts.
- **Runtime:** per dataset, all starts.

## Cells (n = 100 unless noted; 1,000 datasets per simulated cell; unit error variances; c′ = 0)

| c | Fixture | Truth | q | Role |
|---|---|---|---|---|
| 1–4 | two-path | (a, b) = (0,0), (0,.39), (.39,0), (.14,0) | 0 | descriptive (T0 vs constrained) |
| 5 | two-path | (.3, .3) | .09 | **decision** (q at the truth) |
| 6 | two-path | (.3, .3) | .02 | **decision** |
| 7 | two-path | (.3, .3) | .005 | **decision** (near the two-basin regime) |
| 8 | two-path | (.3, .3) | −.02 | **decision** (opposite sign) |
| 9 | two-path | (.3, .3) | −.09 | **decision** |
| 10 | two-path | (.1, .5) | .05 | **decision** |
| 11 | two-path | (.1, .5) | −.05 | **decision** |
| 12–14 | three-path chain | (0,0,0), (.39,0,0), (.39,.39,0) | 0 | descriptive |
| 15 | parallel, n = 200 | b1 = b3 = 0, b2 = b4 = .4 | b1 b2 = b3 b4 | descriptive (stratum) |
| D1 | memory RQ1–RQ3 | data | — | deterministic |
| D2 | two-path with â constructed ≈ 1e-6 (x ⟂ m by projection) | q = .05 | — | deterministic (near-zero divisor) |

## Decision rule (fixed now)

Evaluated **separately in every decision cell 5–11**, no pooling. Tier 1 becomes the default for
q ≠ 0 only if **both** hold in every decision cell:
1. T1 has **zero** accepted-wrong answers.
2. The one-sided 95% lower bound of (success_T1 − success_AUG) is ≥ −0.005. This is a paired
   difference on the same datasets, with SE from discordant pairs:
   SE = √(d₁₀ + d₀₁ − (d₁₀ − d₀₁)²/N) / N; lower bound = diff − 1.645·SE.

Otherwise Tier 1 for q ≠ 0 stays opt-in. The deterministic fixtures D1–D2 must succeed for T0/T1;
a failure there is a bug to fix before the rule is applied, not evidence.

**Reported:**
- per cell and method: success, accepted-wrong, unresolved, infeasible returns (Wilson 95% CIs);
- median and 90th-percentile runtime;
- for the decision cells, the paired difference and its bound.
