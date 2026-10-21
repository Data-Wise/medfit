# Native optimization and an outer check

**Date:** 2026-10-20. **Scope:** explanation of the code in this worktree, followed by a proposal. The small examples below use base R toy objectives; they are **not** calls to `fit_sem()` or evidence that a toy objective is an SEM likelihood. Notation follows the native book: `a` is the treatment-to-mediator path, `b` the mediator-to-outcome path, `theta` the vector of free parameters, `S` the divisor-`n` sample covariance, and `Sigma(theta)` the model-implied covariance. All inequalities below are written `c(theta) <= 0`.

## Part 1. What the current optimizer does

### 1. The quantity it minimizes

Regression chooses coefficients to make predictions fit data. Native SEM instead chooses paths, intercepts, and variances so that the model-implied means and covariance fit the observed ones. Its ML discrepancy is

\[
F(\theta)=\log|\Sigma(\theta)|+
\operatorname{tr}\{S\Sigma(\theta)^{-1}\}
-\log|S|-p+
(\bar x-\mu(\theta))^\top\Sigma(\theta)^{-1}(\bar x-\mu(\theta)),
\]

where the last term appears with a mean structure. The saturated sample model has discrepancy zero; minimizing `F` finds the model parameters closest to the sample moments in the Gaussian likelihood sense. For eligible unweighted fits, a nested likelihood-ratio difference is `n(F_restricted-F_full)`; minimizing matters because a local restricted fit with needlessly large `F` inflates that statistic. The engine computes `F` and its analytic gradient in `R/sem-ml.R:204-253`; `R/sem-anova.R:6,55-86` uses the difference. Positive definiteness of `Sigma` is required; invalid trial points get a sentinel during search and fail the acceptance gate. See also native-book chapters 1 and 5.

*What to remember:* A solver success message is useful only if the returned point really minimizes the ML discrepancy over the requested model.

### 2. Unconstrained fitting and the local gate

`R/sem-optim.R:24-71,347-367` calls nloptr's SLSQP with the analytic objective gradient, even when there are no user constraints. It scales coordinates by each parameter's natural unit, `x_k=theta_k/u_k`, while reporting estimates in the original units. The defaults are `xtol_rel=1e-10`, `ftol_rel=1e-12`, and `maxeval=10000`. With an eligible mean structure it can optimize centered data and map estimates back (`R/sem-fit.R:110-129`); a separate centered Newton polish can improve an otherwise stalled unconstrained fit (`R/sem-optim.R:124-166,410-414`).

After a run, `.sem_gate()` accepts only solver status 1, 3, or 4, a usable implied covariance, correct inward behavior at active bounds, and local stationarity. Let `g` and `H` be the gradient and Hessian on directions free to move. The Newton decrement `sqrt(g' H^{-1} g)` measures remaining improvement on the local quadratic approximation and must be at most `1e-3`. Before that calculation, the gate checks positive curvature and requires the smallest eigenvalue of `D H D`, `D=diag(H)^(-1/2)`, to be at least `1e-4`. Jacobi scaling prevents a huge variance curvature from hiding a weak path direction. Active bounds are handled as fixed coordinates; the gradient must not point toward an improving interior move. These are local numerical checks, not global proofs (`R/sem-optim.R:175-263`).

**Example A: two basins.** Run this in base R:

```r
f <- function(x) (x^2 - 1)^2 + 0.2*x
fits <- lapply(c(-1, 1), function(s)
  optim(s, f, method = "BFGS", control = list(reltol = 1e-12)))
cat("A start minimum F\n")
for (i in 1:2)
  cat(sprintf("%+d % .6f %.6f\n", c(-1, 1)[i], fits[[i]]$par, fits[[i]]$value))
```

Actual `Rscript` output in this worktree:

```text
A start minimum F
-1 -1.024120 -0.202440
+1  0.973994 0.197434
```

Both points are local minima; the left basin has lower `F`. A local stationarity test at the right point cannot discover the left one. Trying both starts and keeping the lower accepted value does.

*What to remember:* Local curvature and stationarity establish a plausible nearby minimum, not the best minimum anywhere.

### 3. Constraint rows, active sets, and polishing

A linear line becomes `c(theta)=a' theta+b`, with `a` normalized to unit length. A `>` line is negated so all inequality rows have `c<=0`. Nonlinear rows such as `a*b>k` are guarded expressions; their Jacobians are central finite differences recomputed at each point. SLSQP sees `theta/u`, so row Jacobians are multiplied by `u`; the acceptance gate checks residuals as distances in natural units (`R/sem-constraints.R:1-123,298-321,323-385`; native-book chapter 3). An *active set* consists of every equality, inequalities near zero, and bounds near a limit. Its null space contains directions that preserve the active constraints to first order.

For an active inequality `c<=0`, a valid local minimum ordinarily has `g+J'lambda=0` with `lambda>=0`; equality multipliers may have either sign. The constrained gate checks every original row within `1e-6` natural units, then applies the decrement and scaled curvature checks on the active-set tangent using the Hessian of `L=F+lambda'c`. It computes a nonnegative-multiplier sign diagnostic, but a wrong-sign **inequality** presently warns rather than rejects; a wrong-side active **bound** can reject. A singular or unavailable multiplier computation can be marked skipped (`R/sem-constraints.R:323-459,559-689`).

Redundancy complicates SLSQP's active Jacobian. The solver receives an independent subset of linear equalities and drops a linear inequality that is satisfied and implied by those equalities; the gate still checks **all** original rows. A violated implied row stays in the solver set so the gate can report it. This is the rule in `R/sem-constraints.R:245-321`, `CLAUDE.md:412-432`, and `planning/specs/RESEARCH-redundant-constraints-2026-10-11.md:1-43,76-94`. After an accepted nonlinear fit, a limited Newton step solves the active KKT equations using Lagrangian curvature; it is kept only when merit improves, feasibility and active-set safeguards hold, and the gate accepts again (`R/sem-constraints.R:461-558`).

**Example B: the equality `a*b=0.3`.** The feasible set has a positive arm and a negative arm. On either arm `b=0.3/a`; the equality is always active and its tangent direction is `(b,-a)`, orthogonal to its Jacobian `(b,a)`. The code explicitly searches both arms:

```r
F <- function(a, b) (a - 0.8)^2 + (b - 0.8)^2
pos <- optimize(function(a) F(a, 0.3/a), c(0.1, 3), tol = 1e-12)
neg <- optimize(function(a) F(a, 0.3/a), c(-3, -0.1), tol = 1e-12)
cat("B branch a b F\n")
for (z in list(pos, neg))
  cat(sprintf("%s %.6f %.6f %.6f\n",
    if (z$minimum > 0) "positive" else "negative",
    z$minimum, 0.3/z$minimum, z$objective))
cat(sprintf("B active equality yes; tangent (b,-a) at positive = (%.6f, %.6f)\n",
  0.3/pos$minimum, -pos$minimum))
```

Actual `Rscript` output:

```text
B branch a b F
positive 0.547723 0.547723 0.127288
negative -0.547723 -0.547723 3.632712
B active equality yes; tangent (b,-a) at positive = (0.547723, -0.547723)
```

The two arm minima have very different discrepancies. For `a*b==0` specifically, medfit uses the exact union `a==0` or `b==0`, fits each linear branch, and keeps the lowest accepted result, up to 64 branch combinations (`R/sem-constraints.R:128-192`; `R/sem-fit.R:215-255`). That exact split does **not** apply to `a*b=0.3`.

*What to remember:* An active set tells us how to check one candidate locally; separate feasible branches still need separate searches.

### 4. Starts, acceptance, and the current optimum label

`n_starts` defaults to five. Perturbed starts are deterministic for a model and checked for a positive-definite implied covariance. For nonlinear constraints, the driver first fits a model without nonlinear rows, uses its estimate and sign-flipped path copies as additional starts, tries **every** start, and keeps the accepted result with smallest `F`. For other fits it stops at the first accepted result; the model default can be a final retry. A feasible relaxed estimate dominates a worse constrained estimate. If none passes the gate the fit errors; failed starts and discrepancies feed warnings (`R/sem-optim.R:74-122,347-455`).

`SEMFit@diagnostics$optimum` is populated through `R/fit-sem.R:141-142`. Its current `status` values (`R/sem-optim.R:460-483`; `man/SEMFit.Rd:40-44`) mean:

| Status | Current meaning |
|---|---|
| `unique` | No nonlinear best-of-starts comparison was used; the first accepted fit wins. It does **not** prove a unique or global optimum. |
| `certified` | The fit matches a feasible reference without nonlinear rows within `1e-6` discrepancy. This is a global certificate **only if** that reference really is the global minimum of the relaxed problem; the code's reference is numerically optimized, not formally bounded. |
| `agreed` | At least two accepted best-of starts have discrepancy spread at most `1e-6`. |
| `disagreed` | Accepted starts differ by more than `1e-6`; the lowest is retained and a warning is issued. |
| `single` | Only one best-of start was accepted without the feasible-reference certificate; multiple attempted starts cause a warning. |

The list also records `n_starts`, `n_accepted`, `best_of`, `certified`, and `spread`. Neither `agreed` nor `unique` means global uniqueness. Local optima, weakly curved tangents, boundary solutions, finite-difference Jacobian/Hessian error, and a too-narrow start cloud remain possible failure modes. `R/sem-optim.R:386-390,463-529` also warns when the relaxed fit is worse than a constrained fit or a variance hits the imposed nonlinear-solve floor.

*What to remember:* Read the status as a record of the search and gate evidence, with `certified` conditional on the reference fit's quality.

## Part 2. Proposal: an outer check around the inner solver

The **proposal** is a verification layer that receives the returned `theta`, all original constraints, `F`, and the inner diagnostics. It independently recomputes evidence and reports `verified_local`, `suspect`, or `indeterminate`, plus a separate `global_bound` field. This keeps “is it a valid local constrained minimum?” distinct from “is it the best feasible minimum?”. No code described in this part is implemented.

### 5. Candidate checks and their limits

| Candidate outer check | Math, statistics, and what it catches | What it cannot establish; cost | Mapping to current gate and `optimum` |
|---|---|---|---|
| **Second-order KKT certificate with multiplier signs** | Recompute feasibility, independent gradients, `g+J'lambda`, `lambda>=0` for active inequalities, complementarity `lambda_i c_i=0`, and Lagrangian curvature on feasible tangent directions. A negative sign or negative feasible curvature catches a false local minimum that a projected decrement can miss. Under a suitable constraint qualification, **strictly positive** curvature on every nonzero critical-cone direction supports a strict local minimum; merely nonnegative curvature is necessary but inconclusive. Use that cone at a weakly active inequality, not only an equality-like null space. | Local only; rank deficiency, near-zero curvature, and numerical derivatives may make the result indeterminate. Cost: one derivative/Hessian pass plus small linear algebra; critical-cone testing can grow with active rows. | Extends `.sem_gate_projected()` sign warning to an independent outer verdict. `unique/agreed/single` can become `verified_local`, never global solely from KKT; `disagreed` remains evidence of different basins. |
| **Global lower bound or exact split** | Any valid global minimum of a *relaxed* feasible set gives `F_lower<=F_constrained`. If an attained feasible candidate matches the lower bound within numerical tolerance, it is globally optimal. For `a*b==0`, enumerate the `a==0` and `b==0` arms. For general products, a rigorous branch-and-bound needs parameter bounds and valid lower bounds on each box. | A numerically optimized unrestricted or linearly relaxed fit alone is **not** a rigorous lower bound. A general SEM objective is nonconvex even with linear parameter constraints; without global relaxation proof this cannot certify. Exact zero split is finite but each branch fit may itself be local. Branch-and-bound can be expensive. | Can strengthen `certified` only when the lower-bound premise is verified; add a bound gap to `optimum`. A single violated bound makes `suspect`. |
| **Independent likelihood/profile cross-check** | Fit the same model and constraints with lavaan or OpenMx; compare parameters and `nF` after reconciling covariance divisor, means, fixed-x, bounds, and likelihood conventions. A profile of `ab` can expose a missed basin or distorted likelihood-ratio statistic. [Issue #249](https://github.com/Data-Wise/medfit/issues/249) is a proposed comparison target; its live contents were unavailable during this draft, so no issue claim is inferred here. | Two solvers can share a basin or modeling mismatch. Agreement is evidence, not a bound. Cost: one or many extra fits and optional dependencies. | A lower independent feasible `F` overrides `agreed` and `single` with `suspect`; matching fits add corroboration, not global certification. |
| **Randomized restart budget** | With independent starts that each hit a better basin with fixed probability `p`, the chance of missing it in `B` starts is `(1-p)^B`. Stop only after a prespecified lower bound `p>=p_0` gives `(1-p_0)^B<=alpha`; record seed, start distribution, and failures. | Independence and `p_0` are strong, generally unverified assumptions; adaptively clustered or failed starts invalidate the probability statement. Cost roughly `B` optimizations. | Refines `single/agreed/disagreed` with a search-budget report; it should never change `certified` on probability alone. |
| **Bootstrap or perturbation sensitivity** | Refit resampled data or perturb starts/tolerances, and count verdict changes, selected branches, and `n(F_restricted-F_full)`. This detects fragile conclusions near a boundary or flat tangent. | Resampling changes the data and objective, so stable verdicts do not prove the original global optimum. Boundary LR reference distributions need separate statistical treatment. Cost: tens to thousands of refits. | Attach a stability summary to `optimum`; frequent changes mark inference sensitivity, not necessarily a failed single-data KKT check. |

**Recommendation (proposal): implement the independent second-order KKT check first.** It targets the concrete gap that an active inequality's wrong multiplier sign now only warns, has moderate per-fit cost, and can return an honest “indeterminate” when constraint qualification or curvature is weak. Keep the existing feasible-reference comparison as a separate, conditional global-bound claim; do not relabel a local KKT pass as global certification.

**Example C: a two-path mediation constraint `a*b>k`.** Let a toy local discrepancy be `F=(a-0.8)^2+(b-0.8)^2`, with `k=1` and `c=1-ab<=0`. At `(a,b)=(1,1)`, `g=(0.4,0.4)`, `J=(-1,-1)`, so `g+lambda J=0` gives `lambda=0.4>=0`. Along tangent `(1,-1)`, `H_L=[[2,-0.4],[-0.4,2]]` has quadratic curvature `4.8>0`. The strict user spelling `>` is treated numerically as the closed boundary `<=` under feasibility tolerance.

```r
g <- c(2*(1-0.8), 2*(1-0.8))
jac <- c(-1, -1)
lambda <- -sum(g*jac)/sum(jac^2)
cat(sprintf("C a=%.1f b=%.1f c=%.1f lambda=%.1f stationarity=(%.1f, %.1f) tangent_curvature=%.1f\n",
  1, 1, 1-1*1, lambda, (g+lambda*jac)[1], (g+lambda*jac)[2], 4+2*lambda))
```

Actual `Rscript` output:

```text
C a=1.0 b=1.0 c=0.0 lambda=0.4 stationarity=(0.0, 0.0) tangent_curvature=4.8
```

For contrast, if `g=(-0.4,-0.4)` at that same active point, stationarity requires `lambda=-0.4`: the product can increase into the feasible region and lower `F`. A tangent-only decrement would still be zero. This contrast is algebra, not a second run.

*What to remember:* A multiplier's sign tests the direction **into** the feasible region, which tangent stationarity does not test.

### 6. Staged implementation sketch (proposal only)

1. **Independent evidence object.** Add an internal outer verifier near `R/sem-constraints.R` that reevaluates all original rows, analytic objective gradient, separately checked constraint Jacobians, active-set rank, multiplier feasibility, complementarity, and critical-cone curvature. Return raw residuals, tolerances, and `verified_local/suspect/indeterminate`; do not reuse the gate's pass flag or silently turn an unavailable derivative into a pass. Check analytic product Jacobians where available against central differences at multiple step sizes.
2. **Attach without changing the inner search.** Call the verifier after `.sem_optimize()` selects and polishes its winner in `R/sem-optim.R`; expose a versioned outer-check list through `R/fit-sem.R` and `R/classes.R` under `diagnostics$optimum`. Keep current five status labels for compatibility and add separate local and global evidence fields; document them in roxygen/Rd, the native book, and help topics. A `suspect` result should make LR uses in `R/sem-anova.R` and `R/sem-mbco.R` fail clearly after a deliberate API decision.
3. **Targeted planted defects and oracles.** Test a valid positive multiplier, a negative multiplier with zero tangent gradient, a curved constraint where using `H_F` instead of `H_L` gives the wrong verdict, an active bound, dependent equality/implied inequality rows, a finite-difference Jacobian perturbation, a near-flat critical cone, and a deliberately inferior feasible branch. Compare objective and parameterization with an independent lavaan/OpenMx fit where the models truly match. Verify zero-product split and numerical relaxed-reference dominance separately; require an actual lower-bound proof before any global field says certified. Run relevant targeted numerical gates and documentation checks when this proposal is implemented.

*What to remember:* The outer layer should report the strength and limits of its evidence, without changing how the inner solver searches.
