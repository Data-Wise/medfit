<!-- Copied from Data-Wise/mbco-lrt:docs/planning/PLAN-medfit-solver-2026-10-19.md at 85fedb5 (2026-10-19). The authoritative copy is there; edit there first. -->

# Plan: constrained LR fits in medfit's native SEM engine (#213), v2 (2026-10-19)

> Historical imported design snapshot, not a statement of released solver behavior.
> The upstream source remains authoritative; this reconciliation does not edit or
> claim synchronization with it. See
> [#369 clause dispositions](../ISSUE-369-reconciliation-2026-10-31.md): comparison
> engines and the reduced #357 milestone shipped, while D18/D20/source-sync
> clauses remain unresolved. Do not infer that SLSQP was removed from released
> medfit or that broad chart/global-certification machinery was implemented.

**Status:** approved 2026-10-19 (see §7); revised after the adversarial review (`codex-review-solver-2026-10-19/review.md`; Claude's
check in `claude-verification.md`). v1 is in git history (33eb4f7). It needs the author's approval
before it is recorded in D16.

**Benchmark outcome (2026-10-19; `docs/strategy/ideation-checks/solver-benchmark/RESULTS.md`, `RESULTS-A1.md`):**
1. **Tier 1 is the default for q ≠ 0.** The precommitted rule held in decision cells 5–11: 7,000/7,000
   correct, 0 wrong.
2. **The Tier 1 fit must warm-start.** Start the full `nlminb` fit from the inner optimum at its grid
   point. A cold start, with the nuisance parameters at the unconstrained MLE, jumped to a second
   local minimum on the same sign at q = 25 and lost scale invariance. With the warm start: 0 wrong
   in 18,500 datasets.
3. **Standardize the data internally** (recommended; the residual scale sensitivity is up to 6e-6
   relative, 2 of 200 datasets).
4. **Drop SLSQP and csolnp as solvers** (author, 2026-10-19).
   - SLSQP returned wrong answers with a success status in up to 46% of datasets.
   - csolnp, at default settings, failed in nearly every q ≠ 0 dataset.
   - AUGLAG stays as the Tier 2 fallback, reported as `local`. The `solver = "auto"` csolnp
     fallback is withdrawn.
   - **Open:** whether `slsqp_legacy` stays, only to reproduce old results.

**Addendum A2 outcome (2026-10-19, `RESULTS-A2.md`; supersedes item 2 above):**
- **Not start-dependent:** random inner starts gave 0 wrong answers in 10,900.
- **Grid-dependent:** with one grid point kept, 11 points gave 69 wrong and 21 points gave 23.
- **Observed models:** use the closed-form profile (PC). It needs no numerical start: 0 wrong, and
  invariant to 3e-13.
- **Latent and general models:** standardize the data, use a 41-point φ grid, keep the best 3, then
  polish warm. Add an 81-point grid-refinement check that downgrades the label to `local` when the two
  disagree. The check is not yet tested.
- **Never:** a cold polish, an unstandardized numerical profile, or a single best grid point.

**Changes from v1:**
- three claims withdrawn (C1 exact feasibility, C3 global φ search, C4 two-chart coverage);
- singular strata are added;
- substitution is conditional (structural detection, regularity and conditioning checks);
- the existing `sem-optim.R` safeguards are kept;
- the reporting and validation gate are expanded.

All derivations are Claude's unless cited.

## 1. Problem (unchanged)

The constrained fits use `nloptr` `NLOPT_LD_SLSQP` (`medfit/R/sem-optim.R:367`). Since #213 they are
guarded by:
- best-of starts, a reference (unconstrained) incumbent and sign-flipped starts (lines 367–426);
- preconditioning (58–70);
- valid perturbed starts (108–122);
- an acceptance gate with a projected version for constraints (174 ff.);
- a Jacobi-scaled reduced-Hessian check (234 ff.);
- improper-solution detection (265–281).

The OpenMx reruns and the audit show wrong-branch stops for every solver. SLSQP also returns
infeasible points. The goal is a design whose answer does not depend on which local minimum a solver
happens to find, wherever that can be achieved, and that says plainly where it cannot.

## 2. Design

### Tier 0: exact decompositions (always first when they apply)

**Product null ∏ θ_j = 0.**
- Fit the k branches with θ_j fixed at exactly 0. Each is an unconstrained fit on `stats::nlminb`
  with analytic gradients, plus the existing start, gate and improper-solution machinery.
- The restricted MLE is the best branch whose fit is accepted (Berger 1997, eq. 15.3).
- **If any branch is unresolved,** the statistic is reported as unresolved, not as the minimum of
  the others: a failed branch fit is not a large statistic.
- Observed recursive models: closed forms serve as the oracle.

### Tier 1: substitution charts, used only when all four conditions hold

1. **The constraint is structurally multilinear in the pivot parameter θ_j.**
   - Decided from the parsed expression, never from probe evaluations.
   - The expression must be a polynomial in the free parameters in which θ_j has degree ≤ 1.
   - `stats::deriv` / `stats::D` on the expression, checked symbolically: the second derivative in
     θ_j simplifies to 0.
   - Otherwise the constraint is "unknown" and goes to Tier 2.
2. **The chart is regular on the region searched.** The pivot's coefficient c(θ_{-j}) is bounded
   away from 0 relative to its scale. φ bounds are derived from the user's parameter bounds, and
   non-finite maps are rejected.
3. **Singular strata are enumerated.**
   - Every point where all candidate pivots' coefficients vanish gets its own branch, with those
     parameters fixed at 0. For b1 b2 = b3 b4: charts b4 = b1 b2/b3 and b2 = b3 b4/b1, plus the
     stratum b1 = b3 = 0, fitted over (b2, b4) and the rest.
   - For k-factor multilinear constraints, stratify recursively over the zero sets of the
     coefficients.
   - If enumeration is not structurally available, go to Tier 2.
4. **Conditioning is acceptable.** The scaled reduced Hessian of the chart objective is checked; if
   it is ill-conditioned, as near a small divisor, the fit goes to Tier 2 even though the constraint
   is eliminable.

**ab = q ≠ 0** in sign branch s:
- a = s·exp(φ), b = q/a, φ bounded by the parameter bounds;
- outer **multistart profile search** over φ, which is *not* certified global:
  - adaptive resolution scaled by the profile's curvature and by SE(a)/|a|;
  - inner fits started from both neighbouring solutions;
  - both sign components always kept.
- The report gives the search domain and any unresolved tail.
- "Certified" is claimed only where D6 earns it: observed-variable models, through the quartic
  (van Giersbergen 2014) or the closed-form branches.
- q → 0 is handled separately: at q = 0 the two components meet the zero-product set, and the Tier 0
  branches apply.

### Tier 2: constrained solver (unknown, non-multilinear or ill-conditioned constraints)

- `nloptr` `NLOPT_LD_AUGLAG` (L-BFGS inner), wrapped in the existing best-of / reference incumbent /
  sign-flip machinery of `sem-optim.R`. SLSQP is removed as the default local algorithm.
- `Rsolnp::csolnp_ms()` (≥ 2.0.1, Suggests): automatic backup when AUGLAG fails, and the user option
  `solver = "csolnp"`, with the same gates.

### Reporting for every constrained fit

- Raw and scaled constraint residual. Scaled by SE(ab) when estimable, with a stable fallback when
  SE(ab) is near 0.
- Status and termination reason.
- Rank of the constraint Jacobian (LICQ).
- At regular points: the projected-gradient norm and the smallest eigenvalue of the reduced Hessian.
- At singular points: "KKT unavailable (LICQ fails)", with branch- or stratum-wise comparison instead.
- The number of distinct optima **found** (not "exist").
- Which tier produced the answer.

## 3. Claims, as revised

| | Claim | Status |
|---|---|---|
| C1′ | Tier-0 branches are exactly feasible (θ_j = 0 is exact). Tier-1 charts satisfy the equality up to floating point while finite; the residual is reported. | C1 (v1) withdrawn |
| C2′ | The branch decomposition is exact as a set identity; each branch statistic is usable only if its fit passes the gates. | Revised |
| C3′ | The q ≠ 0 φ search is a multistart profile search, not a global method; certified only in observed models (D6). | C3 (v1) withdrawn |
| C4′ | Charts plus enumerated singular strata cover the feasible set of structurally multilinear constraints; otherwise the constraint goes to Tier 2. | C4 (v1) withdrawn; the b1 = b3 = 0 stratum is added (counterexample verified, `check_counterexamples.py`) |
| C5 | `nlminb` on regular, well-conditioned charts beats constrained solvers | Unproved; **benchmark required** (§5) |
| C6 | Tier 2 is rarely needed | Withdrawn; no evidence |
| C7′ | Gradient tests use randomized directional finite differences over scales, signs, near-zero divisors and boundary-adjacent points, and test the chain rule separately | Revised |

## 4. Code consequences

- Keep and reuse every safeguard listed in §1. Add `.medfit_constrained_fit(method = )` behind the
  existing `.sem_optimize` caller contract.
- Route constraints by structural classification, and never silently change admissible bounds.
- RMediation's `mbco_branch_probe.R` is an advisory wrong-branch diagnostic, not the Tier-1 detector.

## 5. Benchmark before Tier 1 becomes the default for q ≠ 0 (half a day of runs)

**Methods compared** (same fixtures, seeds):
- Tier 0 / Tier 1 `nlminb`;
- nloptr AUGLAG;
- nloptr SLSQP (current);
- Rsolnp `csolnp_ms`.

**Fixtures:**
- observed models with closed forms;
- two-basin data;
- memory RQ1–RQ3;
- near-zero divisors;
- the b1 = b3 = 0 stratum.

**Measures:**
- rate of reaching the oracle;
- infeasible returns;
- runtime.

**If Tier 1 does not beat Tier 2 on regular charts,** Tier 1 is kept only for q = 0 (Tier 0) and
D6's observed-model certification.

## 6. Validation gate (release)

- **Deterministic fixtures, zero tolerance:**
  - observed-model closed forms and the quartic;
  - memory RQ1 72.544, RQ2 0.083, RQ3 25.828;
  - the b1 = b3 = 0 stratum;
  - an affinity false positive (the cubic) routed to Tier 2;
  - chart endpoints (overflow, tiny divisors);
  - k = 3 at q = 0 and q ≠ 0.
- **Latent-variable cases:**
  - a branch that weakens identification;
  - a Heywood case;
  - correlated estimates (latent X).
- **Seeded simulation:**
  - q ≠ 0 on both sides of and near the two-basin threshold;
  - small n.
  - Report results **per stratum**: failure types and the exact-LR discrepancy, with Monte Carlo
    confidence bounds.
  - No averaged allowance of wrong statistics: every unresolved or wrong case is explained or fixed.

## 7. Decisions (grill 2026-10-19; revised the same day after the Codex review of the grill, R1–R8 in `codex-review-solver-grill-2026-10-19/claude-review.md`, all accepted by the author)

### 7.1 Certification status on every result

Every constrained result carries `status`, shown by `print()`:

| Status | Meaning |
|---|---|
| `exact` | Tier 0 branches, or observed-model closed forms or the quartic |
| `charted` | Tier 1 substitution with all singular strata enumerated |
| `local` | Tier 2 multistart; uncertified |
| `unresolved` | No usable statistic |

`require = c("any", "charted", "exact")` lets the user refuse weaker statuses.

### 7.2 The decisions

1. **Failed branch fit (R1).** The status is `unresolved`, with the failed branch, the reason and a
   remedy. The minimum over accepted branches minus F_U is reported as a **conditional** upper bound
   on LR.
   - It is valid only when every accepted candidate is proper, feasible and fitted under the same
     bounds.
   - It is conditional on the unrestricted fit, as every LR statistic is.
   - Check F_U ≤ every restricted candidate; otherwise refit the unrestricted model from that
     candidate.
   - p(LR_bound) is reported as a **lower bound on p**, used only to decide non-rejection.
   - Bootstrap types fail closed on unresolved replicates and report their count.
2. **Scope (R2).** Any user expression **fully resolved**:
   - algebras expanded recursively;
   - every final symbol a free parameter;
   - fixed parameters and named constants substituted as numbers.

   Anything else is not eligible for Tier 1.
3. **Classification (R3).**
   - Exact polynomial expansion with cancellation (`codex-review-solver-grill-2026-10-19/check_polyexpand.R`)
     replaces the token whitelist and `D()`.
   - Tier 1 requires degree ≤ 1 in the pivot, and a pivot whose coefficient is a single monomial, so
     its zero set is a union of coordinate planes.
   - Strata are enumerated only for sums or differences of products, deduplicated, capped (64).
     Product nulls are Tier 0 and need no strata.
   - Over the cap, or with no monomial pivot: Tier 2 with status `local`, never silently.
4. **SLSQP (R4).**
   - New default path: Tier 0, then Tier 1 (q ≠ 0 only after the benchmark passes, item 5), then
     AUGLAG.
   - `solver = "slsqp_legacy"` reproduces the **whole** pre-change path (starts, tolerances, gate,
     RNG), for exactly two minor releases, with a deprecation warning once per session.
   - Pinned regression fixtures for both paths. NEWS says constrained results may change and why.
5. **Benchmark (R5),** an explicit exception to D13, run now in `docs/strategy/ideation-checks/`.
   Precommitted design:
   - fixtures and seed vectors fixed before running;
   - 1,000 datasets per simulated cell;
   - success = accepted, feasible and |LR − oracle| ≤ 1e-6 (relative); unresolved counts as failure;
   - reported: binomial 95% CIs, infeasible returns separately, median and 90th-percentile runtime.

   **Decision rule:** Tier 1 becomes the q ≠ 0 default only if it has zero accepted-wrong answers
   and its success rate is not below AUGLAG's by more than 0.5 percentage points (one-sided 95%).
   Until then, Tier 1 for q ≠ 0 is opt-in. Implementation in medfit follows M3.
6. **Solver selection (R8; reverses grill decision 6).**
   - `solver = "auglag"` is the deterministic default.
   - `"auto"` tries `Rsolnp::csolnp_ms()` after AUGLAG fails, when Rsolnp is installed.
   - `"csolnp"` requires Rsolnp (Suggests, ≥ 2.0.1).
   - The result records the requested solver, the solver that returned the fit, every attempt, and
     package versions.
7. **Reporting (R7).** An S7 `diagnostics` slot with a schema version, one row per fit
   (unrestricted, each branch or stratum):
   - identifiers and the branch definition (fixed parameters);
   - deviance and LR candidate;
   - accepted/rejected and why;
   - raw and scaled residual and its tolerance;
   - proper/improper; active bounds;
   - starts and distinct optima found;
   - solver requested/used, package version, attempts;
   - seed and options;
   - LICQ rank, projected gradient, smallest reduced-Hessian eigenvalue;
   - status; whether a p-value exists; whether the bound's conditions hold.

   `print()` shows one line (status, tier, solver, optima found) and any warning; `summary()` shows
   the table. Unresolved, infeasible or improper results are statuses, never buried rows.
8. **RMediation alignment (R6).** See `PLAN-rmediation-mbco-fix-2026-10-19.md`: the same status labels.
