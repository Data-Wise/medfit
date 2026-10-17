# Review of the ChatGPT answer to the #213 research prompt (2026-10-16)

Reviewed: `planning/RESPONSE-chatgpt-213-2026-10-16.md` against `planning/PROMPT-research-213-2026-10-16.md`, on branch
`feature/issue-213-variance` at `ea29c4d`. Every number below came from R runs (medfit loaded with
`devtools::load_all()`, nloptr 2.2.1, lavaan 0.7.3, OpenMx 2.22.11). Scripts are in `/private/tmp/claude-501/`
(`oracle213.R` is the oracle; `r213_*.R` are the experiments). No package code was edited.

## 1. Verdict

**Adopt with changes.** The diagnosis is right, the independent oracle is right, and a reference fit used as an
incumbent and a start is the right core. The rejection of a variance floor is wrong on the data. Neither the reference
start nor the floor works alone at the default `n_starts = 5`:

- the floor alone accepts wrong-branch solutions at q = q_hat;
- the warm start alone dies on domain errors or lands on wrong local minima when q is opposite in sign to q_hat.

T3 should combine four parts, all applied only when there are nonlinear rows:

- a variance floor relative to the data scale;
- the reference fit, used as the first start and as an incumbent;
- sign-flipped copies of the reference start;
- a dominance and lower-bound check.

This combination passed 672 of 672 oracle cases at `n_starts = 5`.

## 2. Claims checked

| # | Claim (response) | Result | Evidence |
|---|---|---|---|
| 1a | For q != 0 the feasible set splits into disconnected sign branches; seed 101's point is on the branch opposite the MLE | CONFIRMED | On any path inside {D > 0, g = q}, ab = q*sqrt(2D) != 0, so neither a nor b changes sign; this holds even with negative variances, as long as D > 0. Seed 101 MLE: (a, b) = (2.684, 1.556). Accepted point: (-9.745, -1.017). The oracle's minimum of the (-,-) branch is LR 1458.91159, which equals medfit's 1458.912 to every printed digit. |
| 1b | Whether the point is a local minimum is not established | CONFIRMED (now settled): strict local minimum | The oracle chart (t, u, z) gives gradient 2.6e-7 and Hessian eigenvalues 11400, 4515, 201. In theta = (a, cp, b, Vm, Vy), with an independent likelihood and finite differences: KKT residual 5.7e-9 against a gradient of size 238, lambda 619, reduced Lagrangian Hessian eigenvalues 150, 20.5, 6.1, 0.48. The objective-only reduced Hessian has eigenvalue -0.78, so the response is right that constraint curvature must be in the second-order test, and medfit's gate already includes it (`.sem_lagrangian_hessian`). No first- or second-order gate can reject this point. |
| 2 | NLopt status 3 is FTOL_REACHED and 4 is XTOL_REACHED | CONFIRMED; the prompt was wrong | nloptr 2.2.1 returns 3 with "NLOPT_FTOL_REACHED" and 4 with "XTOL_REACHED"; the NLopt reference lists the same codes. `.sem_ok_status = c(1, 3, 4)` accepts both, so acceptance is unaffected. Status 3 is medfit's routine stop: 14 of 20 good unconstrained fits end on it. The plan's F3 "flag a status-3 stop" cannot tell good fits from bad ones. |
| 3 | Oracle algebra: A, B, K, C, D, E, Q, unrestricted solution, t/u/z substitution, c(t), determinant, z(u), first-order equation | CONFIRMED, every line | Derived independently (Section 4.1). The verbatim `profile_t` executes and matches my version to 1e-10 at four t values on seed 101. |
| 3a | At q = q_hat the oracle equals the unconstrained optimum | CONFIRMED | Largest abs(LR_oracle) over 110 q_hat and shifted cases: 3.4e-13. |
| 3b | Oracle against a known-good medfit fit (floor lines, `n_starts = 8`) | CONFIRMED, max discrepancy 2.70e-6 | 110 cases (seed 1, seed 101, a 6x2x3 q_hat grid and a 6x2x2x3 shifted grid). The 2.70e-6 case (seed 14, (0,0), shift 0.2) is medfit's constraint residual of -8.8e-9 times dLR/dq of about 308. At the q the fit actually reached, the oracle matches to 1.7e-8. The normalization matches exactly: -2 logLik(h1) = 1907.0434667356 = Q + 3n log 2pi + n log(A/n) + n. |
| 4 | q = 0 closed form LR(0) = min(n log(K/C), n log(E/(E - D^2/C))) | CONFIRMED | Seven datasets, matched to 1e-9 by both `a*b == 0` (zero-product branch split) and the better of `a == 0` and `b == 0`. **New failure:** the standardized row `a*b/sqrt(...) == 0` is not routed to the branch split (its active constraint stays nonlinear). It matches on 6 datasets and errors "no start converged" on seed 101. |
| 5a | Positive floors on both variances protect the denominator; zero bounds alone can allow D = 0 | CONFIRMED | With lb = 0, Vy = 0 together with b = 0 or Vm = 0 gives 0/0. NLopt documents that bounds are never violated at evaluations. |
| 5b | D > 0 as a nonlinear constraint does not make sqrt(D) safe | CONFIRMED | The NLopt reference says nonlinear constraints "may be violated at intermediate steps". Instrumented runs found the NaN in the constraint **value** at the SLSQP iterate itself: 8 of 8 errors on seed 1 and 7 of 7 on seed 101; none came from the Jacobian perturbation or the objective. The objective returns its sentinel there. |
| 5c | FD Jacobian perturbations are not covered by the bound guarantee | TRUE in principle, harmless with the proposed floor | The step is eps^(1/3) * max(abs(theta), u), about 6e-6 u. A floor of 1e-4 u keeps theta - h > 0. A floor below about 1e-5 u would not. |
| 6 | (i) incumbent, (ii) mandatory reference start, (iii) per-start domain isolation | FEASIBLE; (iii) already exists | `.sem_optimize` already wraps each start in `tryCatch`, and `best_of` runs every start for nonlinear rows. Isolation is not enough: in 15 of 28 mirrored-q cases every start died. See Section 4.3. |
| 7 | The floor leaves positive-variance stationary points in place, so its success says nothing about mechanism | CONFIRMED as mechanism, REFUTED as a reason to reject the floor | Seed 101 with the floor: start 5 still lands on the wrong point (accepted, f = 5.8356); starts 1, 2, 6 and 7 reach the MLE; `best_of` keeps the MLE. The floor works by keeping starts alive. It was never active at any solution (smallest variance 0.80). Section 3, finding 2 lists the cases. |
| 8 | Citations | Mixed | Section 2.1. |

### 2.1 Citations and external claims

| Claim | Status | Where checked |
|---|---|---|
| NLopt: bounds are never violated, nonlinear constraints can be; codes 1/2/3/4/5 | Verified | nlopt.readthedocs.io, NLopt_Reference |
| NLopt issue #552: SLSQP returns success while violating an equality constraint | Verified | github.com/stevengj/nlopt/issues/552: code 3 with a residual of 3.6e-5 at tolerance 1e-6. Closed as a duplicate of #368, fixed by PR #465. Not checked: whether nloptr 2.2.1 bundles that fix. |
| lavaan: `bounds = "none"`, `rstarts = 0`, `optim.attempts = 4`; nonlinear constraints use nlminb_constr (augmented Lagrangian); default start sets observed residual variances to half the observed variance | Verified | lavOptions() in lavaan 0.7.3; rdrr.io lavOptions page |
| OpenMx default optimizer SLSQP | Verified | `mxOption(NULL, "Default optimizer")` returns "SLSQP" in 2.22.11. Other claims about OpenMx starting values not opened. |
| OpenMx `mxCI(boundAdj = TRUE)`: Wu-Neale correction for a free parameter bounded on one side, not for algebras | Verified | rdrr.io mxCI page |
| RMediation's MBCO example fits both models with `mxTryHard()` | Verified | rdrr.io RMediation mbco page |
| Boiger et al.: profiles of a scalar function of the parameters by integrating the differentiated optimality system | Verified | arXiv 1604.02894 (Boiger, Hasenauer, Hross, Kaltenbacher): Section 3 covers profiles of g(theta); Eq. 4.2 and Prop. 4.2 cover the evolution system. The paper credits the approach to Chen and Jennrich. |
| Drton (2009): singular nulls; the minimum of two chi2_1 at a union of two hyperplanes; non-uniform approximation near singularities | Verified | Ann. Statist. 37(2):979-1012, arXiv math/0703360. Example 1.1 gives the minimum of two independent chi2_1. Section 3 gives a union of hyperplanes whose dependence comes from the angle between their normals in the information metric. Applied to medfit: a and b sit in separate likelihood factors, so the information is block diagonal and min(Z1^2, Z2^2) with independent Z holds. That application is my inference; Drton does not state the mediation case. |
| Self & Liang (1987) | Record verified, full text not read | JASA 82(398):605-610; the cone-projection result was confirmed from secondary summaries only |
| Stoel et al. (2006) | Located, not opened | Psychological Methods 11:439-455, doi 10.1037/1082-989X.11.4.439; authors not confirmed |
| Python corroboration (LR approx. 1300.06 on an opposite branch) | Unverifiable | No code given. The claim is plausible: the oracle finds opposite-branch LRs of 1117 to 1601 in this regime. |
| semTools, bmlm, medflex, CMAverse rows | Not checked | Background only; nothing in T3 depends on them |

## 3. Errors and gaps in the response, by severity

1. **Severe: the recommended design fails in a regime the response never tested.** I emulated its core: the reference
   fit as a start and incumbent, plus the existing starts at `n_starts = 5`, with no floor. On 384 cases with q mirrored
   (-q_hat) or shifted by ±0.5 it gave 15 errors and 13 wrong local minima, worse than the oracle by 6 to 338 LR units.
   Cases: (2.5, 1.5) at q = -q_hat and below; (0.05, 0.05) at q = 0.3 to 0.5. When q is opposite in sign to
   a_hat * b_hat, the MLE sits on neither feasible branch, so a warm start decides nothing. The other starts then die
   on the NaN domain. The response's 30 fixtures never set q opposite in sign to q_hat.
2. **Severe: its case against the floor runs against the data.** At the default `n_starts = 5`, the floor alone failed
   4 of 480 cases, each accepted silently with no "starts disagree" warning:
   - seed 7 (0,0) at q_hat: LR 2.82, oracle 0;
   - seed 56 (0.05,0.05) at q_hat: LR 2.55, oracle 0;
   - two shifted cases, 48.8 and 20.5 LR units off.

   In each case the MLE was on the (-,-) branch with q_hat > 0 and the floor fit took (+,+).

   The floor still rescues what warm starts cannot. On the 28 warm-start failures, floor plus 20 starts fixed all 28.
   Floor plus reference plus sign flips at `n_starts = 5` fixed all 32 hard cases (the 28 plus the floor's 4); the same
   design without the floor failed 27 of 32. The floor is the domain guard and the reference start is the branch
   guard; the response treats them as rivals.

   The floor's real cost is the improper-solution policy. That cost is met by applying the floor only with nonlinear
   rows and warning when it is active, which the plan's D2 already requires. It does not justify a rejection.
3. **Major: the per-start isolation it proposes already exists.** Its point (iii) is in the code (`tryCatch` per start
   plus `best_of`). The missing piece is in-start survival. Bounds give that through NLopt's guarantee; a callback
   cannot reject a step.
4. **Major: its thresholds are unreachable as stated.** "abs(LR - LR_oracle) <= 1e-6" fails on correct fits. medfit
   accepts constraint residuals up to `.sem_constraint_tol = 1e-6` (natural units), and the LR error is
   lambda * residual: 2.7e-6 observed at residual 8.8e-9. The plan's "about 2.5e-7" has the same problem. Compare at
   the achieved q, or tolerate abs(lambda) * residual.
5. **Moderate: it misses the q = 0 standardized form.** It routes q = 0 to the closed form. In medfit,
   `a*b/sqrt(2*(b^2*Vm+Vy)) == 0` reaches the nonlinear solver, not the zero-product split, and seed 101 errors. This
   is a third red case for T2 and a routing question for T3: should a quotient whose numerator is a zero product
   qualify for the split?
6. **Moderate: sentinel plateau.** Its warning about "a flat constant and zero gradient" for undefined values applies
   to medfit's `.sem_objective`. With the floor, 3 of 8 seed-101 starts stopped with status 3 on the sentinel plateau
   at absurd points (a = 2772, Vy at the floor). The gate rejects them, but they waste starts. Secondary; not
   required for T3.
7. **Minor: mutation 10 does not apply.** "Map status 3 to xtol" has nothing to mutate: medfit never maps codes to
   names. Drop it.
8. **Minor: the prompt's error was ours.** The response corrected "status 3 = xtol" correctly.
9. **Credit where due.** Every oracle equation is correct. The search-region bounds are correct:
   - abs(a - a_hat) <= sqrt((C/A)(exp(Delta/n) - 1)), from n log(1 + A(a - a_hat)^2 / C) <= Delta;
   - n(log r + 1/r - 1) <= Delta, from profiling the m-equation at fixed v.

   I checked both algebraically. The q = 0 formula and the Drton framing are right, and so is the warning that a
   floor active at the solution changes the model.

## 4. T3 design

### 4.1 Oracle (corrected, executed)

Derivation, checked line by line:

- -2 log L = const + n log s + x'x/s + [n log v + ||m - a x||^2 / v] + [n log w + ||y - cp x - b m||^2 / w].
- ||m - a x||^2 = K - 2aB + a^2 A = C + A(a - a_hat)^2.
- Profiling cp gives ||y_r - b m_r||^2 = E - 2bD + b^2 C.
- The substitution a = c(t)/u, b = t u/z satisfies the constraint identically.
- In (u, z) the quadratic matrix has determinant KE + t^2(CE - D^2) > 0 by Cauchy-Schwarz, so the inner problem is
  strictly convex.
- z(u) is the positive root of E z^2 - tDu z - n = 0.

The response's equations needed no correction. My additions:

- the outer search: a grid on r = log abs(t) over [-15, 15] in steps of 0.02 on both branches, every grid minimum
  refined by `optimize`, and an edge warning;
- the exact q = 0 union;
- cp recovery;
- the normalization check.

`/private/tmp/claude-501/oracle213.R` runs as is (`Rscript oracle213.R`). It reproduces the 110-case comparison with:

- max abs(LR_floor - LR_oracle) = 2.70e-6, which is the constraint-residual effect;
- 0 errors with the floor;
- baseline: 17 errors and 4 far-off on the same 110 cases.

For the gate, compute LR_oracle at q_ach = g(theta_hat_medfit), not at the nominal q; on the inspected case they agree
to 1.7e-8.

An inequality row `g > q0` needs no new oracle: the likelihood has a single stationary point. LR is 0 when
g(theta_hat) >= q0 and LR_eq(q0) otherwise.

### 4.2 Algorithm (nonlinear rows only; dispatch on `!is.null(cons$nl) || !is.null(cons$nli)`)

1. **Relative floor.** For each free variance parameter (diagonal S entry) whose label appears in a nonlinear row,
   set lb_k <- max(lb_k, 1e-4 * u_k), where u_k is the `.sem_step_floor()` unit (the variable's variance).

   The absolute floor failed the scale test:

   | Data scaling | LR with absolute floor 1e-4 | LR with relative floor |
   |---|---|---|
   | M and Y scaled by 1e-3 | 1917 (binding) | 0 |
   | M alone scaled by 1e-3 | 1129 | 0 |
   | Y alone scaled by 1e-3 | 880 | 0 |

   Under the `shift` path the variances are unchanged, so the same u applies. `.sem_nl_rows()` must expose its rows'
   parameter indices (it builds `row$idx` but does not return them); this is a one-line change.

2. **Reference fit.** Inside `.sem_optimize`, call `.sem_optimize` recursively with the nonlinear rows removed and the
   linear rows and user bounds kept, but without the floor: it is the relaxed model, so f_ref stays a valid lower
   bound. Muffle its warnings and catch its errors. A failed reference only removes steps 3 to 5 and is recorded in
   the diagnostics. It inherits `ram_opt`/`smp_opt` under `shift`, weights through `smp`, `fixed_x` through `ram`, and
   the user's control.

3. **Starts, in order:**
   1. theta_ref, clamped into the floored box.
   2. theta_ref with the signs of the regression-path labels used by the nonlinear rows flipped. Use all 2^k - 1
      patterns for k <= 3; above that, only the joint flip. Keep a start only if `.sem_start_valid()` holds.
   3. The existing `start0` and its `n_starts - 1` perturbed starts, unchanged. `.sem_with_seed` keeps the RNG
      untouched.

   All starts run, since `best_of` already applies.

4. **Selection:** the lowest f among accepted attempts, then two checks with eps_f = 1e-10 * max(1, abs(f_ref)):
   - **Dominance.** If theta_ref satisfies every constraint within `.sem_constraint_tol` and lies inside the floored
     box, an accepted f > f_ref + eps_f is never returned. Re-gate theta_ref. If the gate rejects it, error
     "optimization incomplete: a feasible point with a lower discrepancy exists", never a worse "converged" fit.
   - **Lower bound.** If the best f < f_ref - eps_f, warn that the unconstrained reference is not the global optimum,
     so its LR is not certified.

   No other LR threshold exists. A large LR at a shifted q can be correct.

5. **Floor reporting.** If a floored coordinate is in `active_bounds` at the solution, warn: "variance X is at the
   solver floor (1e-4 x its sample variance); the constrained optimum may be improper or on the boundary; the LR and
   SEs treat it as a bound". Record `floor_active` in the diagnostics. `.sem_improper` stays as it is for every
   variance outside the floored set.

6. **Plan F3.** Drop "flag a status-3 stop far above the optimum" and replace it with steps 4 and 5.

**Paths that must stay identical**, checked with `identical()` on theta, f, vcov, `attempts`, the diagnostics, and
`.Random.seed` before and after:

- unconstrained fits, including the centered polish with a mean structure;
- bounds-only fits;
- linear equalities and inequalities;
- zero-product branch fits whose branch rows are all linear;
- `mbco_sem()` refits (`paths == 0` is linear) of models without nonlinear rows;
- `fixed_x` and factor-expanded fits;
- weighted fits without nonlinear rows.

**Conflicts to resolve in the GRILL:**

- The improper policy: the floor turns an improper constrained optimum into a boundary solution. It is mitigated by
  the step-5 warning, but it is a behavior change for nonlinear fits.
- `retries` and `attempts` change meaning for nonlinear fits: extra starts come first.
- Cost: one relaxed fit plus up to 8 extra constrained solves per fit, multiplied by up to 64 under
  `.sem_fit_branches`. In the emulation, the 672 cases took 2.5 min, about 2x baseline.
- The sign-flip rule is generic only for path labels. A row on loadings or covariances needs its own rule; the default
  is no flips.

**Size:** about 100 to 130 lines in `R/sem-optim.R`, 5 in `R/sem-constraints.R`, about 150 lines of tests and a
200-line gate script.

### 4.3 Evidence for the design (emulated by wrapping `.sem_optimize`; not the final code)

| Variant (`n_starts`) | Cases | Errors | Far (> 1e-4 above oracle) |
|---|---|---|---|
| Baseline (8) | 194 | 14 | 13 |
| Floor only (5) | 480 | 0 | 4 (two at q_hat) |
| Floor only (8) | 194 | 0 | 0 |
| Reference start only (5), mirrored/far q | 384 | 15 | 13 |
| Floor + reference (5) on the 28 hard cases | 28 | 0 | 7 |
| Floor + reference + sign flips (5) on the 32 hard cases | 32 | 0 | 0 |
| **Floor + reference + sign flips (5), full set** | **672** | **0** | **0** (max abs dev 3.8e-6) |

The full set is 12 (a, b) classes (signs mixed, near-null), 2 values of sigma_Y^2, 4 seeds, and q in {q_hat,
q_hat - 0.1, q_hat + 0.05, q_hat + 0.2, -q_hat, q_hat ± 0.5}.

### 4.4 The 30 fixtures

Each fixture is tested at q_hat, at q = 0 (standardized form), at q_hat + {-0.1, 0.05, 0.2}, and at -q_hat.

| # | Fixture | Decision | Why |
|---|---|---|---|
| 1-12 | (a, b) in {(0,0), (0.05,0.05), (0,1), (1,0), (1.5,1), (2.5,1.5)} x sigma_Y^2 in {1, 2}, n = 250 | Keep | Regression set; covers the double null and single nulls |
| 13-18 | (-1.5,-1), (-1.5,1), (1.5,-1), (-2.5,-1.5), (0.001,1), (1,0.001) | Keep | Sign branches. With only the default start, the floor failed every (-,-) case (32 of 32). |
| 19-22 | Scale M and Y by (1e-3,1), (1e3,1), (1,1e-3), (1,1e3) | Keep | Catches an absolute floor (LR 1129 and 880 observed) |
| 23-24 | (Vm, Vy) = (1e-6, 1), (1e6, 1e-6) | Keep 2 of 4 | (1, 1e-6) and (1e-6, 1e-6) duplicate 19-22 |
| 25-26 | Seed 101 data and (0.05,0.05) seed 28, at q = -q_hat - 0.3 and q = 0.5 | Add | The mirrored regime where the warm start alone failed (LR 31 to 338 off) |
| 27-28 | Standardized inequality `> q0`: inactive at the MLE, and violated at it | Keep, change form | The oracle exists in closed form (Section 4.1); a bare `a*b >= k` needs a second reduction |
| 29 | Standardized row `== 0` on seed 101 | Add | Third red case (errors today) |
| 30 | One-factor, three-indicator latent model with a loading-product constraint at its generating value; data from `MASS::mvrnorm(empirical = TRUE)`; one residual variance not in the row set negative | Keep 1 of 2 | Checks that the floor touches only the row's variances and that `.sem_improper` still reports the others. The "exactly zero" variant is dropped: it is the Heywood boundary, already covered by the floor-active warning test. |

**Acceptance rules:**

- abs(LR - LR_oracle(q_ach)) <= 1e-6 * max(1, LR), and <= 1e-5 at the nominal q (observed maximum 3.8e-6);
- q = q_hat: abs(LR) <= 1e-7;
- constraint residual <= `.sem_constraint_tol`;
- no accepted fit above a feasible incumbent;
- identical legacy outputs (Section 4.2).

**Planted defects, each of which must turn the gate red:**

| Defect | Expected failure |
|---|---|
| (a) Drop the reference start | Fixtures 1-12 at q_hat on (0,0) seed 7 fail (LR 2.82) |
| (b) Drop the sign flips | Fixtures 25-26 fail (27 of 32 observed) |
| (c) Drop the floor | Domain errors (15 of 28 observed) |
| (d) Absolute floor in place of the relative one | Fixtures 19-22 fail |
| (e) Disable dominance and inject a worse accepted attempt through a `.sem_nlopt` stub | The worse attempt is returned |
| (f) Delete one branch from the oracle | Fixtures 13-18 fail |
| (g) Route the q = 0 union to a single null | The branch that wins on seed 7 (0,0) is missed |

## 5. Still unverified

- Nonlinear inequality rows in medfit (only the oracle argument is checked), latent-variable and multi-mediator
  models, weighted fits with nonlinear rows, and `mbco_sem()` on a model that itself carries nonlinear rows.
- The generic sign-flip rule beyond this model's two path labels; how flips behave when k > 3.
- Whether nloptr 2.2.1 includes NLopt PR #465 (the #552 fix).
- Full text of Self & Liang (1987) and Stoel et al. (2006).
- OpenMx starting-value claims, and the semTools, bmlm, medflex and CMAverse rows.
- The response's Python corroboration (LR approx. 1300.06).
- Whether a reference fit that is itself local (latent models) ever lets the dominance rule reject a better
  constrained fit. The lower-bound warning in step 4 covers detection, not prevention.
