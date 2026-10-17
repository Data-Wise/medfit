# ChatGPT response to the #213 research prompt (2026-10-16), saved verbatim

Source: `planning/PROMPT-research-213-2026-10-16.md` pasted into ChatGPT (deep research). Status: UNREVIEWED claim set.
Nothing below is verified by medfit's authors; the review is in `planning/REVIEW-chatgpt-213-2026-10-16.md`.

---

Recommendation: make the unconstrained fit a retained candidate and a mandatory start for nonlinear-constrained fits; keep multistart; isolate domain failures by start; and add objective-dominance checks. Do not introduce a default variance floor. A floor changes the admissible model and does not exclude seed 101's positive-variance solution.

The strongest improvement over "warm start" alone is this: when the unconstrained estimate satisfies the constraints, retain its objective and parameters before calling SLSQP. The optimizer must never replace that feasible candidate with a worse result.

## 1. Diagnosis of seed 101

Your results establish that the acceptance gate can admit a feasible, apparently stationary solution whose objective is dramatically worse than an available feasible solution. They do not yet establish that the accepted point is a local minimum: that requires checking the reduced Hessian of the Lagrangian, and independently verifying the constraint Jacobian and stationarity calculation. Nevertheless, the sign-branch explanation has a firm mathematical basis. Write D = b^2 V_m + V_y > 0. For q != 0, the constraint requires sign(ab) = sign(q); a continuous feasible path cannot change the sign of either coefficient without passing through ab = 0, which violates the constraint. Thus the positive-q surface has disconnected (a,b) = (+,+) and (-,-) portions. Seed 101 lies on the opposite-sign branch from the MLE. The transformation (a,b) -> (-a,-b) preserves the constraint, not the likelihood for the observed data. A poor branch minimum is therefore plausible; positive variances do not protect against it. Separately, your status description needs correction: NLopt status 3 is FTOL_REACHED; 4 is XTOL_REACHED. Neither certifies global optimality.

I also checked the branch explanation computationally using the independent reduction below. On a separate Python-generated dataset with your second parameter configuration, it recovered the MLE with objective error 3.4e-13, while an opposite-sign branch solution had LR approximately 1300.06. This is corroborating evidence, not a reproduction of your R seed 101.

## 2. Ranked comparison of fixes A-G

"Fixes" below distinguishes your observed results from guarantees.

| Rank / fix | Mechanism | Seed 1: invalid-domain evaluations | Seed 101: wrong stationary point | Risk to unconstrained fits | SEs / LR | Boundary behavior | Size / evidence |
|---|---|---|---|---|---|---|---|
| 1. B: retained unconstrained candidate + warm start | Supplies a statistically informed start; preserves a feasible incumbent | Fixes your cases empirically; does not prevent later invalid trial points | Decisive at q = g(theta_hat) if the MLE candidate is retained; otherwise heuristic | None if dispatched only for nonlinear rows | Does not change the optimization problem; recompute constrained SEs | Preserves zero and improper solutions allowed by existing policy | Small-medium; profile-path literature supports MLE/neighbor initialization |
| 2. G: continuation + branch-aware starts + failure isolation | Follows nearby solutions; explores distinct branches; one failed start cannot abort all starts | Limits damage; continuation often avoids large excursions | Helps substantially; no general global guarantee | None with isolated dispatch | Preserves target likelihood; branch switching must be allowed | Singular points require branch handling, not smooth continuation alone | Medium; Boiger et al.; derivation below |
| 3. F: stronger verification | Feasibility, KKT residuals, rank, reduced curvature, incumbent dominance | Detects failures rather than preventing trial points | Dominance rejects this result; second-order checks reject saddles but not bad local minima | None | Separates optimization validity from SE availability | Ordinary null-space calculations fail at singular constraints; inequalities require critical-cone logic | Medium |
| 4. A: opt-in variance bounds | NLopt respects explicit box bounds during evaluations | Protects this denominator with positive floors on both variances; zero bounds alone can still allow D = 0 | Only empirical: the reported wrong point satisfies the bounds | None if opt-in and nonlinear-only | Active floors change the fitted model and LR comparison | Positive floors exclude zero; zero bounds change improper-solution policy | Small; NLopt bound guarantee |
| 5. E: alternative local algorithm | Different globalization and constraint treatment | Not automatically domain-safe | May reach another basin; no automatic global certificate | None if nonlinear-only | Same inference only when solving the same parameter space accurately | Depends on parameterization and bounds | Medium-large; AUGLAG available through NLopt |
| 6. D: exponential / square parameterization | Enforces positive / nonnegative variances | Helps variance-domain problems; not arbitrary expression domains | Does not remove sign branches | None if isolated | Interior likelihood invariant; SEs require transformation | exp excludes exact zero; squares have zero derivative at zero and duplicate signs | Medium |
| 7. C: reject nonpositive-variance steps | Feasible-step or domain-aware line search | Potentially, with an actual solver-level implementation | Does not remove the wrong branch | None if isolated | Changes parameter space if negative variances were allowed | Rejecting V <= 0 excludes zero | Large through an R wrapper; not equivalent to throwing a callback error |

NLopt explicitly distinguishes box constraints, which evaluations respect, from nonlinear constraints, which intermediate iterates may violate. Therefore adding D > 0 as an ordinary nonlinear constraint does not itself make sqrt(D) safe. Your finite-difference code must also respect domains: NLopt's bound guarantee does not cover perturbations generated inside your own Jacobian callback.

Two algorithm corrections matter:

- AUGLAG is an augmented-Lagrangian framework, not trust-region SQP. With a local inner solver it remains a local method.
- IPOPT is an interior-point method, not a global optimizer. Switching to it would also conflict with the no-new-hard-dependency requirement unless optional.

NLopt documents SLSQP's SQP implementation, AUGLAG's subsidiary-solver design, and the finite bounds required by its global algorithms. None supplies a cheap, generic global certificate for arbitrary nonlinear SEM constraints.

### What lavaan and OpenMx actually do

These are defaults in the documentation/source retrieved for this review, not an assertion about every historical release.

| Question | lavaan | OpenMx |
|---|---|---|
| Automatically bound residual variances? | Default `bounds = "none"`; nonnegative variance bounds are optional | `mxMatrix()` and `mxPath()` default to unspecified bounds; no universal residual-variance floor |
| Ordinary optimizer | Typically nlminb; nonlinear constrained route uses augmented-Lagrangian constrained optimization | Current retrieved source selects SLSQP unless overridden |
| Starting values | Documented default uses factor-specific loading estimates, observed residual variances initially half the observed variance, and other initialization rules; accepts a fitted lavaan object as starts | Starts are supplied through matrix/path values; low-level matrix values default to zero |
| Default random multistart? | `rstarts = 0`; `optim.attempts = 4` supplies conditional fallback attempts, not four random searches | `mxTryHard()` is an explicit repeated-start facility; ordinary `mxRun()` is not equivalent to it |

Sources: lavaan options source, optimization source, and options documentation; OpenMx optimizer source, matrix documentation, path documentation, and mxTryHard.

A negative residual variance and an undefined likelihood are not interchangeable concepts. In latent-variable SEM, a negative residual variance can coexist with a positive-definite implied observed covariance matrix. Conversely, positive diagonal variances do not ensure positive definiteness when residual covariances are free. Blanket positivity rules therefore do more than protect arithmetic.

## 3. The implementation I recommend

Implement a nonlinear-only candidate-management layer around the existing solver.

1. Preserve the existing dispatch exactly when there are no nonlinear rows. Do not change starts, RNG consumption, bounds, tolerances, or postprocessing on those paths.
2. Fit, or reuse, the reference model with the nonlinear rows removed, retaining existing linear constraints, bounds, data handling, weights, and likelihood conventions.
3. Re-evaluate its objective and every requested constraint independently.
4. If feasible, retain it as an incumbent before any constrained solve.
5. Run SLSQP from that estimate, followed by the existing starts. For profile calculations, also use the nearest successful profile fit.
6. Catch domain failures per start, record them, and continue. Never replace undefined values with a flat constant and zero gradient.
7. Select the lowest-objective eligible result, subject to incumbent-dominance checks.
8. Report optimization validity and inferential validity separately.

The core invariant is: f_returned <= min over feasible theta of f(theta) + eps_f.

A feasible candidate need not be stationary to demonstrate that a higher-objective stationary result is unacceptable. If your best feasible candidate is not stationary and no solve improves it, return an optimization-incomplete diagnostic, not a worse "converged" fit.

At q = g(theta_hat), if theta_hat is the global reference optimum, f(theta_hat) (lower bound) <= f_q* <= f(theta_hat) (feasible upper bound), so equality follows. This is an optimality certificate, not a heuristic LR cutoff.

For general latent models, an optimizer-returned "unconstrained MLE" may itself be only local. Its objective is then not a certified lower bound on the constrained global optimum. It remains a useful feasible incumbent whenever it satisfies the constraints.

Do not merely set LR to zero after detecting matching targets. Preserve the feasible parameters, verify the objective, and recompute constrained inference. An LR of zero does not make constrained SEs equal to unrestricted SEs.

### Projection and continuation

A projection is optional. SLSQP does not require equality-feasible initialization. If using an information-metric predictor, for c(theta) = g(theta) - q,

    Delta theta = - H^{-1} J' (J H^{-1} J')^{-1} c(theta),   J = grad c(theta)'.

Use damping and domain checks. This formula requires suitable nonsingularity; it must not be applied blindly near a = b = 0.

A more principled profile predictor comes from differentiating the KKT equations:

    [ Hess_L   grad g ] [ d theta / dq  ]   [ 0 ]
    [ grad g'    0    ] [ d lambda / dq ] = [ 1 ],     L = f + lambda (g - q).

Follow this with a constrained correction at the new q. Boiger et al. explicitly develop profile calculations for scalar functions of parameters and continuation of their optimality equations.

Continuation follows a stationary branch. It does not establish that this branch remains globally best. Use adaptive step sizes, independent starts at selected profile points, and the lower envelope of competing branches. At q = 0, handle the intersecting branches explicitly.

### Upgrade the gate, but do not oversell it

For regular equality constraints, check r_KKT = grad f + J' lambda, H_R = Z' Hess_L Z, J Z = 0. Use an independently evaluated scaled KKT residual in addition to the Newton decrement.

- Negative reduced curvature rejects a regular local minimum.
- Positive reduced curvature supports a strict local minimum.
- A small decrement cannot distinguish two local minima.
- A pseudoinverse can conceal problematic directions; report rank and conditioning.
- Constraint curvature belongs in the optimization Hessian. Projecting the objective Hessian alone is insufficient for nonlinear second-order conditions.
- For inequalities, verify multiplier signs and complementarity. Weakly active inequalities require critical-cone treatment.

The curvature used for optimization verification and the information used for your SE calculation are related but distinct objects.

There is no universal "LR too large" rejection rule. For shifted q, a large LR may be correct. The defensible rules are dominance by a feasible candidate, agreement with a valid independent oracle, or a genuine lower/upper-bound certificate. Multistart agreement is evidence, not a certificate.

### Why I reject a default floor

A floor can improve trajectories while leaving every bad positive-variance stationary point in place. Its success in your experiments therefore does not establish its mechanism.

If offered as an opt-in feature:

- Define it from a documented data/model scale, not a possibly negative or nearly zero start value.
- Apply compatible parameter-space restrictions to both sides of the intended LR comparison.
- Report its value, activity, and sensitivity to reducing it.
- Treat a positive floor as a restriction of the model, not an invisible numerical detail.

I would reconsider the default only if the package explicitly changed to proper-variance estimation, or if you added a separate, clearly defined proper-model inference mode.

### Statistical validity

Warm starts and continuation do not alter asymptotic inference if they recover the same optimum over the same parameter space. They also do not repair nonregularity.

- Variance zero: under appropriate boundary regularity, LR limits involve tangent-cone geometry and often chi-bar-square distributions. The familiar (1/2)chi2_0 + (1/2)chi2_1 is a special case, not a universal correction. Self-Liang and Stoel et al. are relevant; their conclusions cannot simply be attached to every Heywood model.
- Fixed positive floor: if the true variance is zero, the true parameter is excluded. Standard zero-boundary results do not automatically apply. A shrinking floor requires a rate argument.
- Double-null mediation: with a positive denominator, g = 0 is exactly {a = 0} union {b = 0}. At their intersection, grad g = 0. This is a singular union of models, not an ordinary smooth codimension-one constraint.
- Under orthogonal efficient coordinates at the double null, the LR limit is min(Z1^2, Z2^2), with independent standard normals. With nonorthogonal information, the corresponding distances are dependent. This is different from a generic chi-bar-square correction. Drton provides the relevant singularity/tangent-cone framework and warns that regular approximations need not be uniform near singularities.

Bootstrap calibration must likewise be justified at the singularity; "use a bootstrap" is not a universal solution. Keep numerical correctness tests separate from size/coverage simulations.

### Prior art in the requested R ecosystem

| Package | Relevant machinery | What it contributes here |
|---|---|---|
| lavaan | `:=` defines functions; `==` imposes constraints; defined-parameter inference commonly uses delta/bootstrap methods | Do not confuse computing an indirect effect with constrained profiling. Nonlinear constrained fitting is available. |
| OpenMx | `mxConstraint`; likelihood-based `mxCI` for parameters and algebras | Closest general-purpose comparator. `boundAdj = TRUE` uses Wu-Neale adjustment for eligible singly bounded free parameters, not arbitrary algebras. |
| semTools | `monteCarloCI()` simulates functions from the estimated parameter distribution | Useful inference comparator, not a constrained-ML oracle. |
| RMediation | Distribution-of-product/Monte Carlo intervals; MBCO facilities | Its documented MBCO example fits constrained and full OpenMx models using `mxTryHard()`. |
| bmlm | Bayesian posterior inference for multilevel mediated effects | Credible intervals, not LR profiling. |
| medflex | Natural-effect-model bootstrap or sandwich inference | Different estimating framework; not an oracle for this SEM likelihood. |
| CMAverse | Documented delta and bootstrap inference | No constrained-profile solver established by the documentation checked. |

Mplus documents nonlinear MODEL CONSTRAINT specifications, but LOOP plots and intervals for defined functions should not be mistaken for automatic LR profiling. I did not verify its proprietary optimizer implementation.

A particularly relevant failure report is NLopt issue #552, reporting successful SLSQP termination despite inadequate equality feasibility. It supports independent verification of returned points; it does not establish the mechanism of seed 101.

## 4. Verification plan

### Independent oracle for the observed-variable mediation model

The following is my derivation, rather than a claimed published algorithm. It applies to complete-data, unweighted Gaussian recursive mediation with independent equation errors, free intercepts, and unrestricted direct effect. It does not automatically extend to latent variables, missingness, or survey weights.

Center x, m, y, and define

    A = x'x,  B = x'm,  K = m'm,
    m_r = m - x B / A,   y_r = y - x (x'y) / A,
    C = m_r' m_r,  D = m_r' y_r,  E = y_r' y_r.

After profiling intercepts and c', the negative twice-log-likelihood, up to constants, is

    Q(a,b,v,w) = n log v + (K - 2aB + a^2 A)/v + n log w + (E - 2bD + b^2 C)/w.

The unrestricted solution is

    a_hat = B/A,  b_hat = D/C,  v_hat = C/n,  w_hat = (E - D^2/C)/n.

Use the same likelihood normalization as medfit before comparing LR values.

For q != 0, introduce

    t = b sqrt(v/w) != 0,   u = v^{-1/2} > 0,   z = w^{-1/2} > 0,
    c(t) = q sqrt(2(1+t^2)) / t.

Then a = c(t)/u, b = t u / z, satisfies the constraint exactly. Substitution gives

    Q_t(u,z) = -2n log u - 2n log z + (K + t^2 C) u^2 - 2 c(t) B u + E z^2 - 2 t D u z + c(t)^2 A.

For full-rank data, its quadratic matrix is positive definite:

    det [[K + t^2 C, -tD], [-tD, E]] = K E + t^2 (C E - D^2) > 0.

Together with the logarithmic terms, this makes the inner problem strictly convex.

For a given u,

    z(u) = ( t D u + sqrt((t D u)^2 + 4 E n) ) / (2E).

The remaining first-order equation is

    (K + t^2 C) u - c(t) B - t D z(u) - n/u = 0.

Solve it using `uniroot()`. Search the resulting one-dimensional profile separately on t > 0 and t < 0.

Here is the core R ordinate evaluator:

```r
# Inputs A, B, K, C, D, E are crossproducts defined above.
profile_t <- function(t, q, n, A, B, K, C, D, E) {
  stopifnot(t != 0, q != 0, A > 0, C > 0, E > 0,
            C * E > D^2)
  ct <- q * sqrt(2) * sqrt(1 + t^2) / t
  H <- K + t^2 * C
  z_of_u <- function(u) {
    r <- t * D * u
    h <- sqrt(r^2 + 4 * E * n)
    # Avoid cancellation when r is negative.
    if (r >= 0) (r + h) / (2 * E) else 2 * n / (h - r)
  }
  score <- function(u) {
    H * u - ct * B - t * D * z_of_u(u) - n / u
  }
  lo <- hi <- 1
  for (i in seq_len(1024L)) {
    if (score(lo) < 0) break
    lo <- lo / 2
  }
  for (i in seq_len(1024L)) {
    if (score(hi) > 0) break
    hi <- hi * 2
  }
  stopifnot(is.finite(lo), is.finite(hi), lo > 0,
            score(lo) < 0, score(hi) > 0)
  u <- uniroot(score, c(lo, hi), tol = 1e-11)$root
  z <- z_of_u(u)
  value <- -2 * n * (log(u) + log(z)) +
    H * u^2 - 2 * ct * B * u +
    E * z^2 - 2 * t * D * u * z + ct^2 * A
  list(
    objective = value,
    par = c(a = ct / u, b = t * u / z,
            Vm = 1 / u^2, Vy = 1 / z^2)
  )
}
```

This R transcription has not been executed here; the equivalent Python equations were checked as described above. Standardize data before using this simple implementation to avoid overflow in extreme-scale fixtures.

For the outer search:

- Parameterize t = +/- exp(r).
- Scan both branches, bracket every detected minimum, and refine each.
- Do not call `optimize()` once on a broad interval and assume unimodality.
- Expand the range and refine the grid until objective comparisons stabilize.
- For a formal certificate, add interval bounds or exhaustive stationary-root isolation. Grid stability alone is not a proof.

You can derive finite search bounds from any feasible incumbent. If its LR is Delta, every improving point must satisfy, for example,

    |a - a_hat| <= sqrt( (C/A) { exp(Delta/n) - 1 } ),

with analogous bounds for b. Variance bounds follow from n { log r + 1/r - 1 } <= Delta, where r = v/v_hat or w/w_hat. These restrict the potentially improving region without imposing arbitrary statistical variance floors.

### Exact oracle at q = 0

Fit the two linear-null models separately: a = 0, b = 0. Then

    LR(0) = min [ n log(K/C),  n log( E / (E - D^2/C) ) ].

This is especially valuable because it bypasses both SLSQP and the vanishing gradient of ab.

### Thirty hard fixtures

Use fixed data fixtures or frozen generated datasets. For each applicable fixture, test q = q_hat, q = 0, and several shifted targets.

| Fixtures | Construction | Main defect targeted |
|---|---|---|
| 1-12 | Your six (a,b) pairs x V_y in {1,2}, n = 250, V_m = 1 | Existing behavior, double/near/single nulls |
| 13-18 | (-1.5,-1), (-1.5,1), (1.5,-1), (-2.5,-1.5), (0.001,1), (1,0.001) | Sign branches and asymmetric near-null cases |
| 19-22 | Rescale the same dataset by (s_M, s_Y) = (1e-3,1), (1e3,1), (1,1e-3), (1,1e3) | Scale equivariance; floor/Jacobian defects |
| 23-26 | (V_m, V_y) = (1e-6,1), (1,1e-6), (1e-6,1e-6), (1e6,1e-6) | Conditioning and denominator sensitivity |
| 27-28 | Product inequality ab >= k: one inactive at the MLE, one violated at the MLE | Feasibility, active-set signs, complementarity |
| 29-30 | Three-indicator factor covariance fixtures with one residual variance exactly zero and slightly negative | Proper-boundary versus allowed-improper policy |

For the last two, construct S = lambda lambda' + diag(psi), verify S is positive definite, and impose a nonlinear loading-product constraint at the generating parameter value. This supplies a known zero-discrepancy candidate. Test the zero case under explicit nonnegative bounds and the negative case under the existing improper-solution policy.

Do not generate a literal zero-noise observed mediation equation and treat its singular covariance as an ordinary regular likelihood fixture.

For inequalities, distinguish > from >=: strict inequalities may have an unattained infimum. Document the numerical interpretation rather than silently treating them as identical.

### Acceptance thresholds

These are proposed engineering tolerances, not literature constants:

| Check | Initial target |
|---|---|
| Constraint residual | max-norm of scaled constraint <= 1e-8 |
| Scaled KKT residual | max-norm of r_KKT <= 1e-6, on an explicitly normalized objective |
| q = q_hat identity | abs(LR) <= 1e-7 |
| Independent-oracle agreement | abs(LR - LR_oracle) <= 1e-6 for well-conditioned fixtures |
| Incumbent dominance | No accepted result worse by more than 1e-7 LR units |
| SE eligibility | Finite positive-definite reduced information, acceptable conditioning, regular constraint rank |
| Compatibility | `identical()` for legacy numerical outputs and unchanged RNG state on non-nonlinear paths |

For badly conditioned cases, establish the oracle's numerical error first. Return "numerically inconclusive" if it cannot support the tolerance; do not silently enlarge tolerances until a test passes.

For profile endpoints, control LR error and the root bracket. A fixed parameter tolerance alone is misleading when the profile is flat.

### Mutation tests

1. Remove the MLE start and retained candidate: the frozen failure fixture must fail.
2. Keep the start but discard its incumbent: inject a worse "successful" optimizer return; selection must reject it.
3. Reverse best-candidate ordering: dominance/oracle tests must fail.
4. Abort all retries after one domain error: a fixture with an invalid first start and valid later start must fail.
5. Remove one sign branch from the oracle: sign-reversed fixtures must fail.
6. Replace the q = 0 branch union with one null model: choose fixtures where the omitted branch wins.
7. Corrupt one Jacobian column or scaling factor: independent derivative/KKT checks must fail.
8. Add an unconditional variance floor: the improper latent fixture or scale tests must fail.
9. Drop constraint-Hessian terms: a separate known curved-constraint saddle fixture must fail.
10. Map status 3 to xtol, or alter the F_ML-to-LR multiplier: explicit status and likelihood-normalization tests must fail.

The original 36/72 datasets remain regression tests. They should not be the sole validation evidence.

## 5. Limits, adversarial assessment, and key sources

The recommendation could pass every current case and still be wrong because:

- The unrestricted reference fit is itself local.
- Warm starts and continuation stay on a branch that later becomes suboptimal.
- Every shifted-target start encounters an undefined expression.
- Finite-difference Jacobians are wrong near a domain boundary.
- The constraints lose rank near the double null.
- A profile has disconnected confidence-set components that an endpoint-only search misses.
- Weighted, latent, or missing-data likelihoods do not match the oracle.
- Optimization is correct but the LR reference distribution is wrong.

### What I could not verify

- Your exact seed-101 point's reduced Lagrangian curvature, or the cause of its NaN SEs.
- The implementation of medfit #213, its precise status translation, objective multiplier, and RNG behavior; this review uses your supplied description.
- A global certificate for arbitrary medfit nonlinear constraints.
- A universally safe callback-level replacement for domain-aware globalization in the current SLSQP wrapper.
- Full-text theorem details for Stoel et al.; its bibliographic record and scope were located.
- Proprietary Mplus optimization defaults.
- An exact matching failure report in every requested package. Related OpenMx CI reports were located, but their full discussions were not successfully retrieved.
- The R oracle's execution and the proposed 30-fixture suite; neither was run against medfit here.

### The five most important sources

1. NLopt reference: bound versus nonlinear feasibility and termination-code semantics.
2. Boiger et al., "Integration based profile likelihood calculation...": continuation for profiles of scalar parameter functions; inspected arXiv v1.
3. Self & Liang (1987): boundary likelihood asymptotics.
4. Drton, "Likelihood ratio tests and singularities": singular null geometry, including minima of chi-square quantities.
5. OpenMx `mxCI` documentation: directly relevant implemented likelihood intervals and the limited scope of boundary adjustment.

For the issue's release criterion, I would require retained-candidate dominance, the exact q = 0 oracle, both-sign oracle comparisons, and unchanged legacy paths before interpreting the 36/72 successes as sufficient evidence to ship.

---

Transcription note: equations were converted from the original LaTeX to plain text when saving; the R code block is verbatim. Source links in the original were rendered as footnote markers and were not retained, so every citation is unverified until looked up.
