# REPORT: medfit #213 investigation (2026-10-16)

**Issue:** `fit_sem()` with a nonlinear equality constraint fails or lands on a wrong point (LR 1459 where 0 is right).
**Status:** diagnosed, fix designed, not built. T2 red tests built. T3 is next.
**Branch:** `feature/issue-213-variance` (local, unpushed). Plan: `planning/PLAN-0.11.0-scope-2026-10-16.md` (T2, T3a, T3).
**Sources:** my prototypes, a ChatGPT deep-research answer (`RESPONSE-chatgpt-213-2026-10-16.md`), and an Opus review that
ran R against it (`REVIEW-chatgpt-213-2026-10-16.md`, 274 lines). Numbers marked (review) are the Opus agent's and were not
rerun by me; numbers marked (mine) I ran.

## 1. Bottom line

- The issue's explanation (steps to a negative variance) is **half right**. It explains seed 1 only.
- Seed 101 is a **real strict local minimum on the wrong sign branch** of the constraint. No stationarity or
  second-order gate can reject it, so only a better candidate can.
- **No single fix works at the default `n_starts = 5`.** The design that does: a data-relative variance floor, the
  unconstrained fit as first start and incumbent, sign-flipped copies of that start, and a dominance check. All of it
  applies only when nonlinear rows exist.
- Recommendation: build that design in T3, behind an independent oracle gate and a planted-defect set.

## 2. What is wrong

Model: `M ~ a*X`, `Y ~ cp*X + b*M`, free `Vm`, `Vy`; constraint `a*b/sqrt(2*(b^2*Vm+Vy)) == q`, with q set so the
unconstrained MLE already satisfies it (LR must be 0).

| Case | What happens | Why |
|---|---|---|
| Seed 1 | Every start errors, NaN at `Vy = -1.985` | SLSQP steps to a negative variance; the constraint is evaluated there (review: 8 of 8 errors, none from the Jacobian or objective) |
| Seed 101 | Accepted fit, LR 1458.9, NaN SEs, `converged = TRUE` | Fit sits on the (-,-) branch (a = -9.74, b = -1.02) while the MLE is (+,+). Positive variances. Strict local minimum (review: reduced Lagrangian Hessian eigenvalues 150, 20.5, 6.1, 0.48) |

Why branches: on the feasible set `a*b = q*sqrt(2D)` with `D = b^2 Vm + Vy > 0`, so neither a nor b can change sign without
leaving the set. For `q != 0` the set splits into (+,+) and (-,-) pieces, and the likelihood prefers one.

## 3. What was tried and what it showed

| Fix | At q = MLE value (36 cases, mine) | Elsewhere | Verdict |
|---|---|---|---|
| Baseline | 6 errors, 1 far off | 72 shifted cases: 10 errors, 2 worse than best-known (mine) | broken |
| Variance floor only | 0 / 0 | 5 starts, 480 cases: 4 silent wrong-branch fits, two should be LR 0 but gave 2.82 and 2.55 (review) | not enough alone |
| Warm start from the unconstrained MLE only | 0 / 0 | 384 cases with q mirrored or ±0.5: 28 fail (15 errors, 13 off by 6 to 338 LR) (review) | not enough alone |
| Floor + reference + sign flips | n/a | **672 of 672 oracle matches, 0 errors, worst gap 3.8e-6** (review, emulated by wrapping `.sem_optimize`) | adopt |

The floor is the domain guard (keeps starts alive); the reference start is the branch guard. They are not rivals.
An **absolute** 1e-4 floor fails on rescaled data (LR 1917 at 1e-3 scaling); the floor must be relative to the data scale.

## 4. Verified facts worth keeping

- nloptr status 3 = `FTOL_REACHED`, 4 = `XTOL_REACHED`. My prompt had this backwards. Status 3 is also medfit's routine stop
  (14 of 20 good fits), so "flag a status-3 stop" cannot work. It is replaced by the dominance check.
- The independent oracle (from the ChatGPT answer, corrected and run by the review) matches medfit's logLik-based LR at
  the achieved q to 1.7e-8, and to at most 2.70e-6 at the nominal q (110 cases). That gap is medfit's constraint
  residual (-8.8e-9) times dLR/dq (about 308), so the plan's 2.5e-7 target cannot be met at the nominal q. Compare at
  the achieved q.
- Closed form at q = 0: `LR(0) = min(n log(K/C), n log(E/(E - D^2/C)))` matches medfit's `a*b == 0` and the better of
  `a == 0`, `b == 0` to 1e-9 on seven datasets.
- The standardized row `a*b/sqrt(...) == 0` is **not** routed to the zero-product split and errors on seed 101: a fourth
  red test (the q = 0 test in the file).
- Per-start failure isolation already exists (`tryCatch` per start, `best_of`). It is not enough: in 15 of 28 mirrored-q
  cases every start died.
- Citations the review opened and confirmed: NLopt reference and issue 552, lavaan and OpenMx defaults, Boiger et al.
  (arXiv 1604.02894), Drton (2009). Not opened: Self & Liang (1987) full text, Stoel et al. (2006).

## 5. Design for T3 (nonlinear rows only)

1. **Relative floor** on each variance in a nonlinear row: `lb = max(lb, 1e-4 * unit)`, unit from `.sem_step_floor()`.
   Warn if it is active at the solution; record `floor_active`.
2. **Reference fit:** the model with the nonlinear rows removed (linear rows and user bounds kept, no floor, so its
   objective is a valid lower bound). Failure only disables steps 3-4.
3. **Starts, in order:** the reference estimate; sign-flipped copies (all patterns for k <= 3 path labels, else the joint
   flip); then the existing start and its perturbed starts, unchanged.
4. **Selection:** lowest accepted objective, then a dominance rule (never return an accepted fit worse than a feasible
   reference by more than 1e-10 relative; if the gate rejects the reference, error "optimization incomplete") and a
   lower-bound warning if a fit beats the reference.
5. **Identical legacy paths** (`identical()` on theta, f, vcov, attempts, diagnostics and `.Random.seed`): unconstrained,
   bounds-only, linear, zero-product branches, `mbco_sem()` refits without nonlinear rows, `fixed_x`, factors, weighted
   fits without nonlinear rows.

Size: about 100-130 lines in `R/sem-optim.R`, 5 in `R/sem-constraints.R`, 150 of tests, a 200-line gate script.
Cost: about 2x baseline (672 cases in 2.5 min).

## 6. Verification plan for T3

- **Gate:** `tests/sim/sem-nonlinear-profile-gate.R`, registered in `gates.csv`, using the oracle (preserved at
  `planning/oracle213.R`). 30 fixtures: the review kept most of the answer's list, added the mirrored-q regime and the q = 0
  standardized form, dropped near-duplicates (details in the review, section 4.4).
- **Acceptance:** `abs(LR - LR_oracle(q_achieved)) <= 1e-6 * max(1, LR)` (1e-5 at the nominal q); `abs(LR) <= 1e-7` at q = MLE
  value; constraint residual within `.sem_constraint_tol`; no accepted fit above a feasible incumbent; legacy outputs
  identical.
- **Planted defects, each must turn the gate red:** drop the reference start; drop the sign flips; drop the floor;
  absolute floor; disable dominance; delete one branch from the oracle; route q = 0 to a single null.

## 7. Open questions and risks

- **Improper-solution policy:** the floor turns an improper constrained optimum into a boundary solution. Mitigated by the
  active-floor warning, but it is a behavior change for nonlinear fits. Needs a decision (GRILL) before T3.
- `retries` and `attempts` change meaning for nonlinear fits (extra starts come first).
- Sign flips are generic only for path labels; rows on loadings or covariances default to no flips.
- Unverified: nonlinear inequality rows in medfit, latent and multi-mediator models, weighted fits with nonlinear rows,
  `mbco_sem()` on a model that carries nonlinear rows, whether nloptr 2.2.1 includes NLopt PR 465, and whether a local
  reference fit (latent models) can make the dominance rule reject a better fit.
- The review's emulation wrapped `.sem_optimize`; the real code may behave differently. Rerun the 672 cases against the
  implementation.

## 8. Files

| File | State |
|---|---|
| `tests/testthat/test-sem-nonlinear-variance.R` | 4 red tests (5 failing expectations or errors today) plus 2 frozen fits (pass) |
| `planning/PROMPT-research-213-2026-10-16.md` | the prompt sent to ChatGPT |
| `planning/RESPONSE-chatgpt-213-2026-10-16.md` | its answer, verbatim, unreviewed |
| `planning/REVIEW-chatgpt-213-2026-10-16.md` | Opus review with evidence and full T3 design |
| `planning/oracle213.R` | the corrected, executed oracle |
| `planning/PLAN-0.11.0-scope-2026-10-16.md` | T2, T3a, T3 updated |
