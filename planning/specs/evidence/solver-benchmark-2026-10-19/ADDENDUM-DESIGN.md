# Solver benchmark, addendum A1: edge and general cases for T vs AUGLAG (precommitted)

**Committed before `bench_edge.R` runs.** Any change after the first run goes in a "Deviations"
section of `RESULTS-A1.md`.

**Status:** an addendum to `DESIGN.md` (0fa69b1), requested 2026-10-19.
- It does **not** reopen the decision recorded in `RESULTS.md`: Tier 1 is the default for q ≠ 0.
- It asks whether that default holds outside the seven decision cells.
- SLSQP and CSOLNP are dropped. Methods are **T** (Tier 1 for q ≠ 0, as in `bench.R`) and **AUG**
  (nloptr `NLOPT_LD_AUGLAG` + LBFGS, same settings and starts as `bench.R`).
- Software: R, `stats::nlminb`, nloptr. Base seed **20261101**; cell c uses 20261101 + c.
- Model and objective: the `bench.R` two-path model, F = −2 log L up to a constant.

## Oracle and outcomes (as in `DESIGN.md`)

The oracle is the exact 1-D profile over a < 0 and a > 0 (`oracle_abq`). Except where a cell states
otherwise, outcomes are scored against it with tolerance 1e-6·max(1, oracle):
- **success:** accepted and within tolerance of the oracle;
- **accepted-wrong:** accepted but outside tolerance;
- **unresolved:** no accepted fit.

**Oracle misses.** T's fits are feasible by construction (b = q/a). So when T lands *below* the
oracle by more than the tolerance, the oracle missed, and that is not a T error. Such cases are
counted separately as `oracle_miss`. For those datasets the reference is T's value, and AUG is scored
against it.

## Pass criteria for T (fixed now)

1. **Every cell:** zero accepted-wrong answers. Unresolved is allowed ("fail loudly") but is reported.
2. **General cells G1–G7:** success ≥ .995. With 1,000 datasets, the 95% Wilson lower bound is then
   at least .988.
3. **Invariance cells I1–I3:** every dataset's T value agrees with the original-scale T value within
   1e-6·max(1, LR).

AUG is reported descriptively under both strict and relaxed acceptance (DEVIATION 2 of `RESULTS.md`).
It has no pass criterion.

## General cells (1,000 datasets each)

In each dataset, (a, b) are drawn uniformly from the stated box and the data are generated with
c′ = 0 and unit error variances.

The constrained value is q = â b̂ + z·SE, where:
- SE = √(b̂²SE(â)² + â²SE(b̂)²);
- z ~ Uniform(−4, 4);
- z is redrawn while |q| < 1e-3.

This spreads the LR from about 0 to about 16, and q takes both signs, including the sign opposite to
â b̂.

| Cell | n | (a, b) box | X | Errors |
|---|---|---|---|---|
| G1 | 100 | [−.6, .6]² | N(0, 1) | N(0, 1) |
| G2 | 500 | [−.6, .6]² | N(0, 1) | N(0, 1) |
| G3 | 30 | [−.6, .6]² | N(0, 1) | N(0, 1) |
| G4 | 100 | [−.6, .6]² | Bernoulli(.5), centered | N(0, 1) |
| G5 | 100 | [−.6, .6]² | N(0, 1) | t₃ / √3 (unit variance) |
| G6 | 100 | [−.6, .6]² | Exp(1), centered | N(0, 1) |
| G7 | 100 | [−3, 3]² | N(0, 1) | N(0, 1) |

## Edge cells (300 datasets each unless noted)

| Cell | Case | Setting |
|---|---|---|
| E1a, E1b, E1c | q near 0 (two basins) | (a, b) = (.3, .3), n = 100; q = 1e-3, 1e-4, −1e-4 |
| E2a, E2b, E2c | â ≈ 0 (x ⟂ m by projection, as fixture D2) | b = .5, n = 200; q = .05, −.05, .5 |
| E3a, E3b | Tiny n | (.3, .3), q = .09; n = 10 and n = 6 |
| E4a, E4b | X and M nearly collinear | a = 3, b = .3, n = 100; q = .9, −.9 |
| E5 | q at the MLE | q = â b̂, so the truth is LR = 0 exactly; scored against 0 |
| E6 | q far away | (.3, .3), n = 100; q = 25 |
| E7 | Near-perfect fit | M = .3X + .001e_M, Y = .3M + .001e_Y, n = 100; q = 2â b̂ |

## Invariance cells (200 datasets each)

Data are G1-type; q is as in G1. T is fitted on the original data and on a transformed copy, and the
two LRs are compared. The LR is invariant under each transformation.

| Cell | Transformation | q on the transformed scale |
|---|---|---|
| I1 | X ← 1000X, M ← .01M, Y ← 100Y | a → a·d/c, b → b·e/d with (c, d, e) = (1000, .01, 100), so q → q·e/c = .1q |
| I2 | X ← −X | q → −q |
| I3 | X ← .001X | q → 1000q |

## Reported

- Per cell and method:
  - success, accepted-wrong, unresolved and oracle_miss, with Wilson 95% intervals;
  - relaxed success for AUG;
  - median and 90th-percentile runtime.
- For the invariance cells: the maximum relative discrepancy.
- Whether each T pass criterion holds.
