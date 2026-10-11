# Research: redundant constraints in the native SEM engine (audit F1, plan T6)

**Date:** 2026-10-11 (revised the same day after an adversarial review, section 5) | **Status:** research and design note; code change is task T6 in `tasks/plan.md`
**Question:** an inequality row that coincides with the equality rows (`a == b` with `a - b < 0`) stops 0.7.0 fits. Why, is there
precedent for the failure and its remedy, and what should medfit do?
**Evidence:** `planning/specs/evidence/native-sem-2026-10-11/03-redundant-inequality-sets.R` (seeded; `./run-all.sh` reruns it).

## 1. What fails, measured

Three-variable mediation model, 12 seeded datasets (n = 200), `fit_sem()` internals on the 0.7.0 code:

| Constraint set | Fits (of 12) | What kind of set it is |
|---|---|---|
| `a == b` ; `a - b < 0` | 5 | inequality coincides with the equality, consistent |
| `a == b` ; `a - b > 0` | 5 | same, other direction |
| `a + b == 0.8` ; `a + b > 0.8` | 7 | same |
| `a + b == 0.8` ; `a + b < 0.8` | 7 | same |
| `a + b == 0.2` ; `a + b > 0.2` | 5 | same |
| `a + b == 0.8` ; `a + b < 0.9` | 12 | inequality inactive on the equality set (control) |
| `a + b < 0.2` ; `a + b < 0.2` | 12 | inequality-only duplicate (control) |
| `a + b < 0.2` ; `2*a + 2*b < 0.4` | 12 | inequality-only parallel rows (control) |
| `a + b == 0.8` ; `a + b < 0.5` | 0 | inconsistent (control: must error) |

Every failure is a `no start converged (5 tried)` error with one of three solver outcomes: nloptr status 3 with a stationarity
decrement of 0.04 to 0.6 (the solver reports success at a point that is not stationary, so the acceptance gate is what saves
the user from a wrong answer), status 5 (evaluation budget), or status -1. When a fit does succeed it equals the equivalent
independent set to 1e-6 (max gap 1.4e-8), so the failure is the solver's path, not a different optimum.

**Why the coincident case and not the others.** On the equality set an inequality row whose gradient lies in the span of the
equality gradients has a *constant* value, here exactly 0. It is therefore active at every feasible point, and SLSQP's
quadratic subproblem receives an active Jacobian with a dependent row. A strictly inactive row (`< 0.9`) never enters the active
set, and inequality-only duplicates are tolerated in these runs. This is the condition #122 fixed for duplicated *equality*
rows (`R/sem-constraints.R`, `.sem_independent_rows()`: SLSQP "stops with status -4 although the constraints are consistent");
the remedy there was to hand the solver an independent subset and keep checking every row in the acceptance gate.

**Prototype.** Dropping an inequality row that lies in the span of the independent equality rows *and* holds on the equality set
(the constant satisfies it) gives 12 of 12 fits in every consistent set, identical to the independent set (gap 0, because the
solved problem is then literally the same). The inconsistent set still fails and names `constraint 'a + b < 0.5' is violated by ...`,
because the row is kept when its constant violates it.

## 2. Precedent

Verified means the source was read in this session; the rest is recorded as background and should be checked before it is cited
in the article.

| Source | What it shows | Status |
|---|---|---|
| Kraft (1988), DFVLR-FB 88-28; Kraft (1994), ACM TOMS 20(3):262-281, Algorithm 733 | The SLSQP algorithm (BFGS Hessian, linearized constraints, a least-squares subproblem solved each iteration); it is the code behind nloptr's `NLOPT_LD_SLSQP` and SciPy's SLSQP | verified (search result) |
| SciPy `fmin_slsqp` exit modes | Mode 6, "Singular matrix C in LSQ subproblem", and mode 2, "More equality constraints than independent variables": the same solver family reports dependent or excess constraints as failures, not as a degenerate success | verified (docstring) |
| Linear independence constraint qualification (LICQ); Mangasarian-Fromovitz (MFCQ) | LICQ requires the active constraint gradients to be independent; a redundant active constraint breaks it, so multipliers are non-unique. MFCQ is weaker and can survive redundancy among inequalities; textbook treatment in Nocedal and Wright, *Numerical Optimization*, ch. 12 | LICQ statement verified in SAS NLP documentation; chapter number from memory |
| Andreani, da Rosa and Secchin, preprint on constraint qualifications and "reductions" (Optimization Online, January 2025) | Eliminating redundant constraints can restore MFCQ; the existence of such a reduction is itself treated as a constraint qualification | verified only through a search summary; the PDF could not be read, so check the title and statements before citing |
| Solver presolve (Knitro via AIMMS: "Remove Duplicate Constraints" default, "Remove Linearly Dependent Constraints" optional; Xpress, CPLEX, Gurobi presolve) | Detecting and removing redundant rows before the solve is standard practice, in two strengths: exact duplicates, and linear dependence. Cheap row-by-row checks miss parallel rows | verified (documentation pages) |
| lavaan, `lav_optim_nlminb_constr.R` | lavaan does **not** check for dependent rows: it stacks `rbind(ceq_jac(x), cin_jac(x))` into an augmented-Lagrangian loop around `nlminb`, with no rank test and no message about dependence. A row is treated as active only under a strict-complementarity test. Its only failure signal is the non-convergence code | verified (source read) |
| Monfort, Holly and Gourieroux (1982, *Econometrica*); Holly, Gourieroux and Monfort (1982, *J. Econometrics*) | Kuhn-Tucker multiplier, Wald and likelihood-ratio tests under inequality constraints share a chi-bar-squared (mixture) null distribution; relevant to what a redundant active row does to the *test*, not to the fit | verified (abstracts) |
| Lawson and Hanson (1974/1995), non-negative least squares | The multiplier-sign check (T7) is an NNLS problem whose columns are the active constraint gradients; dependent columns are the case fixture 02 reproduces | background |

Reading of the precedent:

1. **Redundancy that coincides with equalities is a known degeneracy**, not a medfit-specific bug: it is a LICQ failure, solvers
   report it as a singular subproblem or a stall, and mature solvers remove the rows in a presolve step.
2. **The standard remedy is row reduction before the solve, with the dropped rows still checked afterward.** That is what #122
   already does for equalities, and what the T6 change extends.
3. **lavaan is not a model to copy here.** It has no dependence handling at all; "lavaan accepts it" cannot be the parity
   target for this case. The parity target is the equivalent independent set fitted by medfit itself.
4. **No SEM-specific source on redundant inequality rows was found.** The search did not surface Dijkstra or Andrews on this
   point; the SEM literature on inequality constraints concerns the null distribution (chi-bar-squared), not solver degeneracy.
   Treat this as an absence of evidence from one search, not a claim that none exists.

## 3. Design for T6 (revised after the adversarial review, section 5)

An **inequality row is implied by the equalities** when its gradient lies in the span of the independent equality gradients: the
residual after projection onto that span is below `implied_tol = 1e-12` (rows are unit length). On the equality set its value is a
constant `c`, computed at any point of that set (a least-squares solution of the equalities).

| Case | Action |
|---|---|
| implied and `c <= 1e-8` (satisfied, on or inside the boundary) | drop from the solver's rows; keep in the acceptance gate, which already uses every row |
| implied and `c > 1e-8` (violated everywhere on the equality set) | **keep** the row; the solve proceeds and the acceptance gate reports the violation, as it does today |
| not implied (including near-dependent rows, residual above `1e-12`) | unchanged |

Where: the filter belongs next to `.sem_independent_rows()` in the constructor of the solver's rows (`.sem_nlopt_constraints()`),
so the unit-length rows, the "dropped rows are still gated" argument and the gate's constraint tolerance are shared with #122. The
gate's sign check already reports `skipped: the active constraints are linearly dependent` in these fits; that stays correct (a
dropped row has no meaningful multiplier), and the docs say so.

**Why drop-only, with no up-front error.** The first draft of this note raised a named error before the solve when an implied row's
constant was positive. The review showed that near-dependence is not implication: for `a == b` with `a - b + 1e-9*cp > 1e-7` the
projection residual is 7.1e-10 (below the 1e-8 rank tolerance) and the constant at the minimum-norm equality point is 7.1e-8, so the
rule would call the set inconsistent, yet `(a, b, cp) = (0.5, 0.5, 200)` satisfies both constraints. Fixture 03's ladder shows the
same for every coefficient from 1e-8 down to 1e-14. A *dropped* row cannot do that harm, because the gate still tests it against
the actual solution; an *error* has no such backstop. Keeping the row when its constant is positive costs one worse error message (the
gate leads with the solver status and then names the row) and buys never rejecting a feasible model.

**Why 1e-12 and not the 1e-8 rank tolerance.** Equality rows use 1e-8 because a wrongly dropped equality row is caught by the gate. A
wrongly dropped *inequality* row is also caught by the gate, but the result is a spurious rejection of a feasible fit, so the implied
test is tightened to the level of floating-point noise: exactly dependent rows such as `2*a + 2*b` leave residuals near 1e-16, and
anything a coefficient of 1e-12 or more away from the span stays with the solver. T6 calibrates this with the ladder of rescaled
equivalents (coefficients 1e-6 to 1e-14, and a rescaled parameter) and fails if any feasible ladder set is rejected.

**Not in scope.** Inequality-only dependence (`a + b < 0.2` with `2*a + 2*b < 0.4`) fit in all 12 seeds and needs no change; a
dependent set of *simultaneously active* inequalities that the equalities do not imply (three rows through one point in two
dimensions) is not covered by the sweep. If T6's tests find it failing, handle it as a separate finding rather than widening T6.

**Decision closed (2026-10-11).** The earlier open question, up-front error versus gate message, is resolved in favor of the gate message
by the review above. The improvement to that message (lead with the violated row, not the solver status) is a separate, optional
change to `.sem_optimize()`'s error text.

## 4. Documentation placed with this note

- `vignettes/articles/methods.qmd`, section "Constraints": the redundancy rules, the 0.7.0 limitation and its workaround.
- `CLAUDE.md` and `AGENTS.md`: the constraint pipeline in one paragraph (rows, independent subset, implied-row rule, gate).
- `tasks/plan.md`, task T6: root cause, the revised design above, and the acceptance tests that follow from section 1 and the ladder.

## 5. Adversarial review of this note (Codex, 2026-10-11) and what changed

Four findings, each reproduced before it was accepted. Only the third concerns this note; the others are recorded because they came
from the same review and are tracked elsewhere.

| # | Finding | Verdict | Change |
|---|---|---|---|
| 3 | Near-dependence does not establish infeasibility (medium) | Accepted. The note's up-front error would reject feasible models; the prototype never did, because it keeps a row whose constant violates it | Section 3 is drop-only; the tolerance is 1e-12; fixture 03 gains the ladder and three assertions (the old rule rejects 5 of 6 feasible ladder sets, the new rule rejects none); T6 and the three docs that stated the error design are corrected |
| 1 | `--sim` can pass on stale CSVs (high) | Accepted, outside this note | Open: `tests/sim/run-gates.R` must require a zero child exit status and a fresh results file, plus a mutant where a child fails beside an old passing CSV |
| 4 | Stationarity check ignores the acceptance threshold (medium) | Accepted, outside this note | Open: save the distance field in the stationarity CSV, check both margins against `.sem_stat_tol`, add a common-rescaling mutant. The committed truncated-run minimum is 1.96e-3, only 2x the threshold, so the check must use runs far from the optimum |
| 2 | GLM complete-case filtering changes `subset` (high) | Accepted, outside this branch: merged in #138 | Open: with `subset = 1:50` and row 1 incomplete, `fit_mediation()` fits rows 2:51 (a = 0.4295, `n_obs` 199) where `glm()` fits rows 2:50 (a = 0.4281). A separate fix |
