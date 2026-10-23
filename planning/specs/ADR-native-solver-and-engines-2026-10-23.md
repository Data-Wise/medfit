# ADR: the solver behind the built-in SEM engine, and which engine to use when

**Date:** 2026-10-23. **Status by part:**

| Part | Status |
|---|---|
| A. SLSQP as default solver (2026-10-09, D19) | **Accepted, implemented** |
| B. Replace SLSQP for constrained fits, tiered path (2026-10-19, D16) | **Approved plan, not implemented**; evidence revised 2026-10-20 |
| C. The engines and when to use each | Description of current behavior |
| D. A `solver` option; `nlminb` first on branch fits, then unconstrained fits (2026-10-23) | D-1 to D-3, D-6 (structure), D-7 to D-10 **decided**; D-6 Tier 1 chart method **open**; D-4 **proposed**, unmeasured, staged after D-2; D-5 conditional |

**Author's call needed** on the open questions in section 6. Superseded drafts are in Appendix A.

This ADR corrects a common recollection, "we decided not to use SLSQP because it performed worst". The record
says something narrower. It is written from the files cited in each section; the numbers are quoted, not re-run.

## 1. Context

medfit's native engine (proposed prose name: "built-in SEM engine"; the argument string `engine = "native"` is
frozen by `tests/testthat/test-api-freeze.R`) fits lavaan-style models by maximum likelihood. The optimizer is
**SLSQP** (sequential least-squares quadratic programming, Kraft 1988/1994) as implemented in the **NLopt** C
library (identifier `NLOPT_LD_SLSQP`) and called through the R package **nloptr** (`DESCRIPTION` Imports,
`R/sem-optim.R`). medfit did not write an optimizer; it wrote the layers around SLSQP (starts, scaling, the
acceptance gate, the Newton polish, the capped restoration).

The recollection mixes decisions about different classes of model, so this ADR keeps them apart:

- **Unconstrained fits** (bounds allowed): SLSQP today (Part A); `nlminb` proposed (Part D, D-4).
- **Plain linear constraints:** SLSQP today and decided to stay (D-7).
- **The zero product `a*b == 0`:** an exact branch split, implemented (Part B Tier 0); `nlminb` proposed for the branch fits (D-2, D-3).
- **Other nonlinear constraints:** SLSQP today; the tiered path with AUGLAG as the fallback decided as the target (Part B, D-6), not implemented.

## 2. Part A: SLSQP is the default solver (accepted 2026-10-09, D19; implemented)

**Decision.** SLSQP for all fits, unconstrained and constrained alike (OD3, closed at checkpoint A on 2026-10-09). Parts B and D change this for some classes; this part records what was decided then and what is implemented now.

**Evidence** (`planning/specs/GRILL-native-sem-engine-medfit-2026-10-08.md`, `PLAN-native-sem-implementation-2026-10-09.md`
rows OD3 and G5; one benchmark, 3 model shapes, n of 50, 200 and 1000, 30 datasets per cell, 90 cells, match
means the implied covariance is within 1e-5 of lavaan):

| Solver | Default (moment-based) starts | Random starts | Speed per fit (latent fixture) | Constraints |
|---|---|---|---|---|
| nlminb | every cell | 100% | 1.1 ms | no |
| nloptr SLSQP | every cell | 98.5% | 2.6 ms | **yes** |
| ucminf | every cell | 98.2% | not reported | no |
| optim BFGS | every cell | 97.0% | not reported | no |
| nloptr L-BFGS | every cell | **93.3%** (worst cell 86.7%) | 1.6 ms | no |

On the later S6 study (100 datasets per cell): SLSQP 100% from the default start, 99.1% from random starts, 99.8%
with the retry; L-BFGS 93.8% and 95.9%.

**Reading.** The worst performer in this benchmark was **L-BFGS**, which the original plan (J6) had chosen for
unconstrained fits; it was dropped in favor of SLSQP. SLSQP cost about 2x the time of nlminb and was the only
candidate that handles constraints, so one solver covers every fit. nlminb was the most reliable and the fastest and
was kept out because it cannot take constraints. Rsolnp and lbfgsb3c failed to link on the benchmark machine; optimx,
ROI, RTMB and others were not tried.

**Safeguards that make a single SLSQP run trustworthy** (`R/sem-optim.R`, `R/sem-constraints.R`): natural-unit
scaling, best-of-starts, the acceptance gate (feasibility, stationarity, curvature, multiplier signs), a reference
(unconstrained) incumbent, the Newton polish, and the capped status -4 restoration (PR #300).

## 3. Part B: replacing SLSQP for constrained fits (approved as a plan 2026-10-19; not implemented)

**Problem.** For the nonlinear null `a*b == 0` a local solver can stop at the wrong branch and return a feasible
point with a larger discrepancy. The LR statistic is then too large, and the answer looks fine. The issue is a
silent wrong answer, not slowness.

**Decision of record** (`planning/specs/GRILL-constrained-lr-solver-2026-10-19.md`, copied from
Data-Wise/mbco-lrt `docs/specs/GRILL-medfit-solver-v2-2026-10-19.md`; plan `docs/planning/PLAN-medfit-solver-2026-10-19.md` §7,
recorded as D16): a tiered path becomes the default for constrained fits.
- Tier 0: a product of labels set to zero is split into one fit per factor, and a failed branch makes the result
  unresolved (not the minimum of the others).
- Tier 1: exact substitution charts for parsed multilinear constraints (polynomial whitelist, cap on strata).
- Fallback: augmented Lagrangian (AUGLAG), with a Rsolnp backup when installed.
- `solver = "slsqp_legacy"` would reproduce today's results with a deprecation warning for one or two releases
  (Part D proposes a permanent, non-deprecated `"slsqp"` option instead).
- Implement in medfit after milestone M3 (D13).

**What is implemented in medfit today** (checked 2026-10-23): Tier 0 only, since 0.8.0 (`.sem_fit_branches()`), with
the unresolved handling added in 0.13.0 (#300). There is **no `solver` argument, no AUGLAG and no Tier 1** in
`R/`; every constrained fit still goes through SLSQP.

**Evidence** (mbco-lrt, `docs/strategy/ideation-checks/solver-benchmark/RESULTS.md`, inspected 2026-10-20; product
null, 15 cells x 1,000 datasets, observed-variable models only, cell design in that repository's DESIGN.md; read from that repository, not
re-run here):

| Method | Datasets | Right answer | Accepted a wrong answer | Unresolved | Median time |
|---|---|---|---|---|---|
| SLSQP | 15,000 | 13,195 (88%) | **1,805 (12%)** | 0 | 7.3 ms |
| CSOLNP (Rsolnp) | 15,000 | 6,635 (44%) | **5,109 (34%)** | 3,256 | 18.4 ms |
| AUGLAG (AUG) | 15,000 | 8,150 (54%) | 21 | 6,829 (46%) | 22.7 ms |
| Tiered chart method (T) | 15,000 | 15,000 (100%) | 0 | 0 | 10.7 ms |

**Reading.** SLSQP was not the worst: CSOLNP returned wrong answers most often and AUGLAG resolved the fewest
datasets. SLSQP was the fastest and its cost is the 12% silent wrong answers, with no unresolved flag. The tiered
method was right on all of them in this benchmark. That asymmetry (silent wrong versus honest unresolved) is the
reason for Part B.

**The evidence moved after the decision.** RESULTS.md (2026-10-20) says the original rule passes, but broader tests
show one accepted-wrong result and 16 of 200 invariance failures for the cold-start chart method (T), and
recommends the standardized warm-start chart method (TWs) and closed-form profiling (PC) as candidates, "for an
author decision". It states there is no latent-model validation and that it "does not approve a new package
default". So the approved plan's chart method and the currently recommended candidate differ, and the plan's
AUGLAG fallback resolved only 54% in the benchmark (my reading, not stated in the files).

## 4. Part C: the engines and when to use each

| Engine (`fit_mediation(engine = )`) | Fits | Use it for | Not for |
|---|---|---|---|
| `"glm"` (default) | two regressions, closed-form effects, delta SEs | one mediator, any glm family, weights, sandwich SEs | latent variables, constraints |
| `"regmedint"` | VanderWeele closed form (Suggests: regmedint) | the published formulas for binary and count outcomes | weights, sandwich |
| `"lmer"` | mixed models for cluster-level treatment (Suggests: lme4, pbkrtest) | 2-1-1 cluster designs, Kenward-Roger | weights, sandwich, families |
| `"native"` (built-in SEM engine; also `fit_sem()`) | all equations jointly by ML with SLSQP | latent mediators, several mediators, constraints, `:=`, the `x:m` product and four-way effects, categorical covariates, MBCO | latent means and latent products; a nonlinear null that must be certified |

`mbco_sem()`, `anova()` and `compare_lr()` work on native fits. A failed refit is an unresolved result, never the
minimum of the refits that worked (0.13.0).

## 4a. Part D: a `solver` option and class-based defaults (proposed 2026-10-23)

One current ledger. "Decided" means the author answered it in the 2026-10-23 grill; "Proposed" means it is the
author's stated direction but not accepted into the plan of record; nothing here has been measured.

| # | Item | Status | Content |
|---|---|---|---|
| D-1 | Motivation for `nlminb` | Decided (with a correction) | Reliability, not speed. The polish and restoration code acts only when a **nonlinear** constraint row is active (`.sem_polish` returns NULL otherwise, checked 2026-10-23), so unconstrained fits and purely linear ones never use it. An `nlminb` rung for unconstrained fits would not remove those failure modes; its benefit on the common path is unproven. |
| D-2 | Where `nlminb` starts (stage 1) | Decided | At the zero-product branch fits (Part B's Tier 0), not at ordinary unconstrained fits. Stage 1 has its own gate row (see the evidence table: branch fits compared with SLSQP and with the lavaan/OpenMx reference). D-4 is stage 2 and depends on stage 1 passing. |
| D-3 | How a branch reaches `nlminb` | Decided | Pin the coordinates: the rows that only fix parameters to constants (`a == 0`) are removed from the solve. A label shared by several paths pins every coordinate it names, and `:=` parameters are recomputed from the pinned values. Pinned coordinates stay in the parameter table as fixed, count as active constraints in the covariance projection, and stationarity in the gate is evaluated on the free coordinates; the gate itself is unchanged. Other linear constraints stay on the constrained solver (D-7). |
| D-4 | Unconstrained default and an option (stage 2) | **Proposed** (measurement gate below; starts only after stage 1 passes) | `nlminb` for unconstrained fits (bounds allowed), **including the reference (unconstrained) incumbent fit that constrained fits run** (`.sem_reference_fit`), so the gate must cover that use too. SLSQP stays selectable as `solver = "slsqp"`, not deprecated. SLSQP post-processing by class: see the table after the ledger. Which solver ran is recorded in `@internals`. |
| D-5 | `nlminb` as a cross-check on branch fits | Conditional | Chosen earlier in the grill while nloptr was the default. Superseded by D-2/D-3 (branches run on `nlminb` in stage 1) and D-4; it matters only if stage 1 is rejected, in which case a cross-check against SLSQP stays the way `nlminb` enters. Consistent with Appendix A. |
| D-6 | Constrained default | **Decided** for the structure; **Tier 1 chart method open** | Decided (author, 2026-10-23): the order of the tiered path is Tier 0 (exact branch split, shipped) first, Tier 1 charts second, AUGLAG only as the fallback. AUGLAG is not the class-wide default. Open: which chart method Tier 1 uses. The 2026-10-20 benchmark report names the standardized warm-start chart method (TWs) and closed-form profiling (PC) as candidates and does not approve a default; the cold-start method of the 2026-10-19 plan had one accepted-wrong result and invariance failures. Tier 1 is not implemented, so leaving it open costs nothing, and the product null is already handled by Tier 0. |
| D-7 | Plain linear constraints | **Decided** (author, 2026-10-23) | SLSQP, until AUGLAG is measured on linear constraints and matches (the only measured option: 10 of 10 starts, 11 ms; a linear feasible set has no wrong-branch problem). So SLSQP remains the solver for linear constraints, and is the default there, not only an option. |
| D-8 | D-4 reliability gate | **Decided** (author, 2026-10-23, after the review) | A paired non-inferiority test on the same datasets, whole-fit outcome: a dataset is a success when `fit_sem()` (with its gate and retry) returns an accepted fit that matches the lavaan or OpenMx reference, and a failure when it is unresolved or an error. **delta is fixed independently of the pilot at 0.01** (one point of success: a failed start is caught by the gate and retried, and the harm that matters, a silent wrong answer, has its own zero-tolerance rule). Per decision cell, the one-sided 95% lower bound of (`nlminb` minus SLSQP) success, from a paired **score interval (Tango's) or an exact conditional test** pre-specified in the design file (both handle zero or few discordant pairs), must be at least -0.01, with **1,000 datasets per cell**; the pilot sets the sample size only. At n = 1,000 the bound passes two equal solvers while discordant pairs stay under about 37 (3.7%); delta = 0.005 would need about 3,200 datasets per cell, so 0.01 is the practical value. Also required: zero silent wrong answers for `nlminb`, median time no worse than SLSQP's, estimates within the existing parity tolerances. Default-start cells (100% for both solvers in every earlier study) cannot fail a comparison, so they are a check that both stay at 100%, not a gate. Replaces "not below SLSQP in any cell" and the first -0.005 proposal. |
| D-9 | When the gate design is fixed | **Decided** (author, 2026-10-23) | Before the first run: a `tests/sim/gates.csv` row and a short design file (cells, datasets per cell, thresholds, the comparison and the mutants) are committed first, and `run-gates.R` re-derives the verdict from the saved results, as for every other gate. This closes the provenance gap the mbco-lrt report flags (untracked scripts, unresolvable pre-commit hashes): thresholds cannot move after the data. |
| D-10 | Latent structures in the D-4 gate | **Decided** (author, 2026-10-23) | The existing `sem_models()$latent` plus two new stress structures: a **boundary (Heywood) case**, where a residual variance's optimum sits at its lower bound (exercises the #213 variance floor and the different bound handling of `nlminb`), and a **weak-loading case**, where a flat likelihood makes convergence tests disagree. D-8 applies per structure and per data scale; OpenMx is the reference where lavaan stalls (the harness records that it does at large data units). Not included: several factors, cross-loadings, latent constraints. |

**Conflicts to resolve, not paper over:**

1. **Part B versus D-4: resolved by D-6.** The constrained default is Part B's tiered path with AUGLAG as the fallback;
   D-4 now covers only unconstrained fits and the SLSQP option. Linear constraints stay on SLSQP (D-7).
2. **Evidence against AUGLAG as a class-wide default.** On the product null (mbco-lrt, 15,000 datasets) AUGLAG left
   6,829 (46%) unresolved, was the slowest of four methods, and gave 21 wrong answers; it was never measured on
   linear constraints in the evidence read here, nor on latent models. The best constrained method in the record is
   the tiered chart method (100% right, 0 wrong), which the benchmark report still lists as needing broader
   validation (RESULTS.md, 2026-10-20). `nlminb` as the unconstrained default is supported (100% from random starts,
   1.1 ms in the 2026-10-08 benchmark) but measured before the acceptance gate and natural-unit scaling existed.
3. **Costs of leaving SLSQP as default:** every constrained fit changes at 1e-6 or more, the frozen fixtures and
   gates were calibrated on SLSQP, and the k = 4 restoration cap was calibrated on SLSQP stalls. `"slsqp"` as an
   option replaces Part B's `solver = "slsqp_legacy"` and its deprecation window.

**SLSQP post-processing by class** (code as of 2026-10-23; replaces the earlier "whenever SLSQP is the solver"):

| Fit class | Gate and retries | Polish (`.sem_polish`) | Status -4 restoration and the k = 4 cap |
|---|---|---|---|
| unconstrained | yes | no | no |
| linear constraints only | yes | no (returns NULL without an active nonlinear row) | no |
| nonlinear constraint, a row active | yes | yes | yes (the cap is part of the restoration) |

Under D-4 these stay tied to the constrained SLSQP path; none of them applies on `nlminb`.

**Evidence required before D-4 is accepted** (thresholds below are proposals for the author to set):

| Model class | Methods to compare | Must show |
|---|---|---|
| unconstrained, observed | `nlminb`, SLSQP | parity with lavaan and OpenMx within the existing tolerances; reliability by the D-8 rule (paired bound, delta 0.01) from default and random starts at the four data scales; gate verdicts unchanged |
| unconstrained, latent | `nlminb`, SLSQP | the D-8 rule on latent fixtures (D-10). The harness already has one latent structure (`sem_models()$latent`, a one-factor
mediator `eta =~ m1 + m2 + m3`, with lavaan as the reference at four data scales) beside the observed, parallel and
serial structures; it has no boundary (Heywood) or weakly identified latent case |
| zero-product branch fits (stage 1) | `nlminb` with pinned coordinate, SLSQP with the `a == 0` row | same discrepancy and estimates within parity tolerance on every branch; a failed branch is unresolved, never the minimum of the rest; the D-8 rule on the branch fits |
| constrained fits, reference (incumbent) step | `nlminb`, SLSQP | the final constrained fit and its gate verdict are unchanged on the constrained gate fixtures when the unconstrained reference step uses `nlminb` |
| linear constraints | AUGLAG, SLSQP | parity with the constrained gate; unresolved rate at most SLSQP's (0 on the fixtures); runtime reported |
| nonlinear constraints | AUGLAG, SLSQP, tiered path | accepted-wrong count 0; unresolved reported, not hidden |
| product null | tiered path (Tier 0) | unchanged: branch fits, unresolved when any branch fails |

The existing harness `tests/sim/sem-reliability.R` compares only SLSQP and L-BFGS and needs `nlminb` and AUGLAG
columns; the seam for a second backend is `.sem_nlopt` / `.sem_solve_one`, with an explicit mapping on each side.
NLopt returns integer statuses (the gate accepts 1, 3, 4 and -4). `nlminb` returns `$convergence` (0 or 1) and a
`$message` string, so its mapping is defined on the message (verify the strings against the installed R): accept
'relative convergence (4)', 'X-convergence (3)', 'both X-convergence and relative convergence (5)' and 'absolute
function convergence (6)' only if the gate also accepts the point; treat 'false convergence (8)', the roundoff-limited
analog of status -4, as a stall that the gate alone may accept, with a retry otherwise; refuse 'singular convergence
(7)' and the evaluation and iteration limit messages (9, 10) and retry. The stationarity and curvature checks are
solver independent.

## 5. Consequences

- Users of constrained native fits get SLSQP's speed and, rarely, a wrong-branch statistic; the guards (gate,
  incumbent, branch split, unresolved results) lower that risk but do not remove it for general nonlinear nulls.
- Product nulls `a*b == 0` already avoid the nonlinear solve (Tier 0), so the documented MBCO path is the safe one.
- The docs currently name SLSQP only in `methods.qmd` and `computation-algorithms.qmd`. A reader of the landing and
  guide pages is not told which solver runs, what it is trusted for, or that Part B is planned and not shipped.

## 6. Open questions for the author

1. **Prose name:** keep "native engine" with a definition, or "built-in SEM engine" (recommended, `engine = "native"`
   stays).
2. **State the solver up front** on the native guide and the glossary: "SLSQP (NLopt, through nloptr)", the Part A
   numbers in one line, and a plain note that constrained nonlinear nulls can in rare cases stop at a wrong branch.
3. **Part B:** the order (Tier 0, Tier 1, AUGLAG fallback) is decided (D-6). Open: which chart method Tier 1 uses
   (TWs or PC, per RESULTS.md), and the validation it needs (latent models are untested).
4. **Linear constraints:** decided, D-7 (SLSQP until AUGLAG is measured on them). Remaining: who runs that AUGLAG
   linear benchmark and what result lets AUGLAG replace SLSQP there.
5. **Evidence gate for D-4:** the reliability rule is decided (D-8: delta 0.01, paired score interval, 1,000 datasets per cell),
   so are the latent structures (D-10) and the commit-first rule (D-9). Open: the two new latent fixtures still to be
   written, and the thresholds of the linear and nonlinear rows of the evidence table.
6. **`solver` argument:** name and values (`"nlminb"`, `"auglag"`, `"slsqp"`, an automatic default), which functions
   take it (`fit_sem()`, `fit_mediation()`, `mbco_sem()`), and the NEWS entry. No deprecation window if SLSQP stays
   an option.
7. **Evidence provenance:** RESULTS.md says A1 and A2 scripts are untracked and their pre-commit hashes do not
   resolve; archive them before any package decision rests on them.

## 7. What would change this decision

- Part A: a model class where SLSQP's random-start reliability drops well below nlminb's, or constraint support
  becoming available in a more reliable solver at similar cost.
- Part B: a latent-model benchmark in which the tiered or chart method is wrong or unresolved more often than SLSQP,
  or a certified global method for the general product null.

## Appendix A. Superseded drafts of Part D

Kept for the record; none of this is current. The cross-check decision (D-5) and the first ladder draft were
superseded by the ledger in Part D.

### First draft: a ladder by constraint type, conditional on nlminb passing a gate


**Proposal** (author's comment on the first draft): use the cheapest reliable solver for the class of model, and
reserve the heavier machinery for the models that need it.

| Rung | Model class | Solver | Status |
|---|---|---|---|
| 0 | no user constraints (bounds allowed) | `stats::nlminb` with the analytic gradient, in natural units | **proposed**; today SLSQP |
| 1 | linear `==`, `<`, `>` constraints | SLSQP (nloptr) | today's behavior |
| 2 | product of labels set to zero (`a*b == 0`) | Tier 0: one fit per factor, each a rung 0 or rung 1 fit; a failed branch makes the result unresolved | implemented since 0.8.0 (branches currently run on SLSQP) |
| 3 | other nonlinear constraints | Tier 1 charts, then a constrained solver, as in Part B | planned, not implemented |

The ladder is consistent with Part B: the Tier 0 branch fits in the 2026-10-19 plan are already specified as
unconstrained `nlminb` fits, and rungs 2 and 3 are Part B's tiers.

**Condition: "nlminb performance is acceptable".** The 2026-10-08 benchmark favors nlminb (100% from random starts,
1.1 ms against SLSQP's 98.5% and 2.6 ms), but it predates the acceptance gate, natural-unit scaling and the bound
handling now in `R/sem-optim.R`, and the current harness `tests/sim/sem-reliability.R` compares only SLSQP and
L-BFGS. So the claim is not yet measured on today's code. Define "acceptable" before switching, and measure it with
that harness extended by an nlminb column:

1. Same answers: estimates within the existing parity tolerances against lavaan and OpenMx, and against SLSQP on the
   frozen fixtures, with identical gate verdicts.
2. Reliability: from default and random starts, at the four data scales, not below SLSQP's in any cell, and 100%
   from the default start.
3. Speed: not slower than SLSQP (it was about 2x faster in 2026-10-08).
4. Failure behavior: a stalled or non-converged nlminb run is caught by the gate and retried, never accepted
   (nlminb's PORT status codes need a mapping to the gate's accepted set 1, 3, 4, -4; the stationarity and curvature
   checks are solver independent, so they carry over).
5. The existing `.sem_nlopt` seam (a thin wrapper tests can stub) and `.sem_solve_one` are the place to add a second
   backend; no change to the gate is needed if the status mapping is explicit.

**Risks.** Two solvers mean two sets of platform quirks (the status -4 restoration was an SLSQP phenomenon and would
not apply on rung 0), and an `nlminb` fit that differs from today's SLSQP fit in the last digits would move frozen
fixtures at the 1e-9 level (pin optimizer outputs at 1e-6). Which solver ran should be recorded on the `SEMFit`
(`@internals`), as Part B already requires.

## Sources

`planning/specs/GRILL-native-sem-engine-medfit-2026-10-08.md`; `PLAN-native-sem-implementation-2026-10-09.md`;
`PLAN-native-sem-review-fixes-2026-10-08.md`; `GRILL-constrained-lr-solver-2026-10-19.md`;
`EXPLAIN-native-optimizer-and-outer-check-2026-10-20.md`; `RESEARCH-redundant-constraints-2026-10-11.md`;
`R/sem-optim.R`; `R/sem-constraints.R`; `DESCRIPTION`. Outside this repository, read only:
`~/projects/research/mbco-lrt/docs/planning/PLAN-medfit-solver-2026-10-19.md` and
`docs/strategy/ideation-checks/solver-benchmark/RESULTS.md`, `DESIGN.md`, `ADDENDUM-A2-DESIGN.md`.
