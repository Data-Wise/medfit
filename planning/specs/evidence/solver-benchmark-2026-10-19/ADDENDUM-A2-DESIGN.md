# Solver benchmark, addendum A2: is Tier 1 robust, or did it depend on its start? (precommitted)

**Committed before `bench_a2.R` runs.** Any change after the first run goes in a "Deviations"
section of `RESULTS-A2.md`.

## Question

Addendum A1 found that the precommitted Tier 1 (T) fails when its full `nlminb` fit starts the
nuisance parameters at the unconstrained MLE ("cold"), and that starting from the grid's inner
optimum ("warm", TW) fixes it.

The author's concern (2026-10-19): if T's correctness depends on a start choice, it may not be safe
to use. A2 asks two things:
- whether the correct answers are **robust** to start and grid choices, or fragile;
- whether a variant exists whose correctness does not depend on a start at all.

It also folds in D20 (internal standardization).

## Methods (all on the two-path model, ab = q ≠ 0)

| Label | What it is | Depends on a start? |
|---|---|---|
| T | Precommitted Tier 1: 41-point φ grid, inner fits at each point, full fits from the best 3 points with **cold** nuisance | yes |
| TW | As T, full fits **warm** from each point's inner optimum | the polish step only |
| TW11, TW21 | TW with 11- and 21-point grids, best **1** point | yes (coarse) |
| TWr | TW, but each inner fit starts at a random nuisance value (MLE + N(0, 1) per coordinate) | stress test |
| NP | **Numerical profile.** Per sign, g(φ) = min over the nuisance by `nlminb`, warm-started along the grid from its neighbour. Then `optimize()` on g within every bracketed local minimum of the grid values (and at the grid ends), keeping the best. No full joint fit. | φ: no; nuisance: only through the inner fits |
| PC | **Closed-form profile** (observed models only). c′ and the variances are concentrated out exactly. The 201-point φ grid plus `optimize()` on each bracketed minimum is the oracle's procedure on a coarser grid. | no |
| TWs | TW on internally standardized data (x, m, y divided by their SDs; q scaled by s_x/s_y) (D20) | as TW |
| AUG8 | nloptr AUGLAG + LBFGS from 8 starts: the 4 sign flips plus 4 random starts (a ~ N(â, 3 SE(â)), b = q/a, nuisance at the MLE). Same acceptance as `bench.R`. | yes |

## Data

- Cells G1–G7 and E1–E7 of A1: identical generators and seeds (base 20261101), 11,500 datasets.
- Invariance cells I1–I3 of A1, for TW, TWs, NP and PC.

## Scoring (as in A1)

- **Reference:** the A1 oracle (the exact 1-D profile). Where any method lands below it by more than
  1e-6·max(1, LR), the minimum feasible value becomes the reference (oracle miss).
- **Outcomes:** success, accepted-wrong and unresolved, per method and cell.
- **Invariance:** relative discrepancy as in A1.

## Fixed criteria

A method is **robust** if, over all 11,500 datasets, it has
- zero accepted-wrong answers;
- zero unresolved fits;
- invariance within 1e-6 relative in I1–I3.

A family is **fragile** if its error count changes materially across the start and grid variants.
Here "materially" means any variant has more than 0 wrong where another has 0.

## How the recommendation follows

1. **If NP (or TWs) is robust and the TW variants are fragile:** recommend NP-style numerical
   profiling for Tier 1. It generalizes to latent models, because the inner fits are smooth
   unconstrained problems. Drop the joint polish, or keep it only when it improves on NP.
2. **If the only robust method is PC:** Tier 1 is safe only where closed-form profiling exists
   (observed models). Latent models stay on Tier 2 multistart, reported as `local`.
3. **If no chart method is robust:** do not make Tier 1 the default. AUGLAG multistart becomes the
   default, reported as `local`.
