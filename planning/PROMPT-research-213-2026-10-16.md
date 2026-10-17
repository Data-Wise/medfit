# Research prompt: nonlinear-constrained ML fits that land on wrong points (medfit #213)

Paste everything below the line into an AI chat with web search / deep research on. It is self-contained.

---

You are a research team with five hats: (1) nonlinear constrained optimization (SQP, active-set, interior point, global/multistart methods), (2) structural equation modeling and likelihood inference (constrained ML, likelihood-ratio and profile-likelihood intervals, boundary/Heywood cases, mediation analysis), (3) numerical analysis (conditioning, parameter scaling, reparameterization), (4) statistical software engineering (R, nloptr, lavaan, OpenMx), and (5) verification and testing of numerical code. Produce a recommendation I can implement and defend. Cite papers, documentation and source code you actually found, with links; mark anything you could not verify. Do not guess at citations.

## 1. The problem

I maintain an R package, medfit, with a native maximum-likelihood SEM engine (normal-theory discrepancy F_ML, parameters theta, gradients analytic). A model can carry nonlinear equality constraints on named parameters, for example in a mediation model

    M ~ a*X
    Y ~ cp*X + b*M
    M ~~ Vm*M          (residual variance of M)
    Y ~~ Vy*Y          (residual variance of Y)
    a*b/sqrt(2*(b^2*Vm + Vy)) == q     (a standardized-effect-type constraint)

The solver is nloptr `NLOPT_LD_SLSQP` (SLSQP, Kraft 1988) with analytic objective gradients and finite-difference constraint Jacobians. Variances are unbounded (no box constraint). Parameters are preconditioned to unit scale. Several starts are tried (default start from moments, plus perturbed starts x0 + N(0, (0.5*max(|x0|,u))^2)); with a nonlinear row every start is tried and the best accepted one is kept. A solution is accepted by a gate: nloptr status in {success, ftol, xtol}, constraint residual small, and a Newton decrement on the active null space below a tolerance (a stationarity test).

When q equals the value of the constraint function at the unconstrained MLE (so the constrained optimum IS the unconstrained MLE and the likelihood-ratio statistic must be 0), the constrained fit fails in two ways:

- Seed 1 (n = 250, X ~ Bernoulli(0.5), M = 1.5X + e, Y = 0.3X + 1.0M + e): every start fails with "expression did not evaluate to one finite real number (got NaN)" at a point with Vy = -1.985 (SLSQP stepped to a negative variance, where sqrt of a negative number gives NaN).
- Seed 101 (a = 2.5, b = 1.5, sigma_Y^2 = 2): the fit is ACCEPTED with LR = 1458.9 against the unconstrained fit (should be 0), status 3 (xtol), Newton decrement 9e-11, 7 retries, and NaN standard errors. The unconstrained MLE is a = 2.68, cp = 0.25, b = 1.56, Vm = 0.93, Vy = 1.78. The wrong solution is a = -9.74, cp = 7.16, b = -1.02, Vm = 16.6, Vy = 5.5. All variances there are POSITIVE, so this is not a negative-variance wander: it is a genuine stationary point of the constrained problem (a spurious local optimum on the constraint surface) that passes my stationarity gate.

Starting the constrained solve at the unconstrained MLE gives LR = 0, so the optimizer is fine when started well.

## 2. What I measured (R, 36 and 72 constructed cases)

Cases: (a, b) in {(0,0), (0.05,0.05), (0,1), (1,0), (1.5,1), (2.5,1.5)} x sigma_Y^2 in {1,2} x seeds, constraint at the MLE (36 cases) and shifted by -0.1, +0.05, +0.2 (72 cases, compared with the best objective found by any variant with 40 starts).

| Variant | Constraint at the MLE: errors / far-off | Shifted q: errors / worse than best-known by > 1e-4 |
|---|---|---|
| Baseline (current) | 6 errors, 1 far (LR >= 1e-3) of 36 | 10 errors, 2 worse of 72 |
| A: lower bound on residual variances, 1e-4 absolute | 0 / 0 | 0 / 0 |
| A: lower bound 1e-3 x the start value (relative) | 0 / 0 | 0 / 0 |
| A: lower bound 0 | 0 / 0 | not run |
| B: also run from the unconstrained MLE and keep the best | 0 / 0 | 0 / 0 |

So A and B both fix every constructed case; they do not discriminate. I have NOT tested: inequality constraints (a*b > k), models with latent variables or several mediators, constraints where a variance is truly at zero (Heywood case) at the constrained optimum, weighted fits, or data with variances at very different scales. I have also not established WHY seed 101's spurious point exists (nonconvex constraint surface? sign symmetry in (a, b)? the constraint function is invariant to flipping the signs of a and b together).

## 3. Constraints on the solution

- Existing policy in the package: an improper solution (negative variance) is REPORTED, never silently bounded. A variance floor contradicts this unless it is opt-in, applied only when a nonlinear row exists, and reported when it is active at the solution.
- Unconstrained fits and linear-constrained fits must not change at all (bit-identical output is the target); only fits with nonlinear constraint rows may change behavior.
- Standard errors come from the information matrix projected on the null space of the active constraints, so they need an interior, nonsingular solution.
- The result must be defensible to a statistician who uses it for likelihood-ratio / profile-likelihood intervals (MBCO tests, constraint-based CIs for mediation effects), including near-boundary cases (a or b near 0).
- Cost matters modestly: a fit is milliseconds to a second; doubling the start count is acceptable, 100x is not.
- Language: R, with nloptr; no new hard dependencies.

## 4. Questions to research (answer each, with sources)

1. What is the known failure theory? Search for: SLSQP and negative-variance steps / infeasible iterates; nonconvex equality constraints and spurious KKT points; constrained ML in SEM with nonlinear parameter constraints (lavaan `:=` with `==`, OpenMx `mxConstraint`, Mplus MODEL CONSTRAINT); Heywood cases and variance bounds as standard practice. What do lavaan and OpenMx do by default (do they bound residual variances for you; how do they start; do they use multistart)? Report their actual defaults from documentation or source.
2. Which of these fixes is best, and why: (A) lower bounds on variances (absolute or relative to data scale), (B) warm start from the unconstrained estimate (projected onto the constraint), (C) reject steps that make a variance non-positive (in-solver), (D) reparameterize variances as exp(.) or squares, (E) a different algorithm for the nonlinear rows (augmented Lagrangian, interior point/IPOPT, trust-region SQP such as `NLOPT_LD_AUGLAG` or `ipoptr`), (F) a stationarity-gate upgrade that tests second-order conditions or objective gap, (G) something else you find. For each: what it fixes, what it breaks, effect on SEs and LR statistics, and effect on boundary solutions.
3. Is a warm start from the unconstrained MLE a recognized technique for LR and profile-likelihood computation under constraints (e.g., profile likelihood by continuation / path-following from the MLE)? Is there a principled continuation method for profile intervals on a constrained function of parameters (delta-method-free CIs, Wald vs LR vs Lagrange multiplier), and does it solve the "spurious local optimum accepted" problem?
4. How should a solver decide that an accepted stationary point is "far above the optimum"? The unconstrained objective is a lower bound on the constrained objective; is there a literature rule (a bound check, second-order sufficient conditions, a multistart agreement criterion, a global-optimality certificate for this structure) that avoids a made-up threshold?
5. Statistical validity: if a floor or warm start is used, what happens to the asymptotic distribution of the LR statistic when the true value sits on the boundary (variance 0, or a = b = 0 in mediation where the constraint gradient vanishes and regularity fails)? Which corrections are standard (Self & Liang 1987, chi-bar-square mixtures, Stoel et al. for SEM) and does the solver choice interact with them?
6. Verification design: propose an independent oracle for constrained ML that does not use the same solver (e.g., profile likelihood by a 1-D root find in a reparameterized model, brute-force grid or global optimization via `nloptr` with different algorithm, closed-form where available for this mediation model), a set of about 30 hard cases (double null, near-null, b = 0, a = 0, near-boundary, large and tiny variance scales), acceptance thresholds, and planted-defect (mutation) tests that make the gate fail when the fix is removed.
7. Prior art in R: how do `lavaan`, `OpenMx`, `semTools`, `RMediation`, `bmlm`, `medflex`, `CMAverse` handle constrained or profile-likelihood CIs for products of coefficients, and what failure reports exist? Any known issues similar to this one?

## 5. Output format

1. One-paragraph diagnosis of the seed-101 failure (be explicit about what is established and what is a hypothesis).
2. A ranked comparison table of fixes A-G with columns: mechanism, fixes seed 1, fixes seed 101, risk to unconstrained fits, effect on SEs/LR, boundary behavior, implementation size, evidence/source.
3. Your single recommendation, the rejected alternatives and why, and the conditions under which you would change your mind.
4. A verification plan (oracle, 30 cases, thresholds, mutation tests) I can code in R.
5. A list of things you could not verify, and the 5 most important sources with links.

Be adversarial about your own recommendation: say how it could pass my 36 and 72 cases and still be wrong.
