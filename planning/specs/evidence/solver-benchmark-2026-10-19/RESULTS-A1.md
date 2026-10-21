# Solver benchmark, addendum A1: results (design precommitted in 3572fcf, `ADDENDUM-DESIGN.md`)

**Run:** 2026-10-19 on the Mac.
- Software: R 4.6.1 and nloptr 2.2.1.
- Base seed 20261101; the decision cells reuse seeds 20261029–20261035.
- Scripts and outputs:
  - `bench_edge.R` → `a1_{P,Q,R}.csv`, analysed in `analysis_a1.out`;
  - `bench_edge_tw.R` → `tw_1..17.csv`, analysed in `analysis_tw.out`.

## As precommitted: T fails two of its three criteria

| Criterion | Result |
|---|---|
| 1. Zero accepted-wrong in every cell | **Fails.** One wrong answer in E6 (q = 25). T reported LR 646.884; the oracle is 646.193. |
| 2. Success ≥ .995 in G1–G7 | Passes. 7,000/7,000. |
| 3. Invariance within 1e-6 relative | **Fails.** 16 of 200 datasets in I3 (X scaled by .001); maximum 5.2e-5. |

**Why.** I reproduced E6 rep 22 in the cloud (R 4.3.3).
- On a > 0 the 1-D profile has two local minima: a = 3.08 (LR 646.193) and a = 8.33 (LR 646.884).
- The best grid point (a = 3.70, inner LR 646.39) lies in the right basin. But the full `nlminb` fit
  restarted the nuisance parameters at the *unconstrained MLE*, not at that grid point's inner
  optimum, and the first steps carried it into the other basin. All three restarts converged there,
  with status 0.
- The I3 failures have the same cause in a badly scaled problem. In the six worst datasets the
  original-scale T value equals the oracle and the scaled-data T value sits above it.

This is a defect in the benchmark's T1 implementation, not in the Tier 1 idea. The precommitted
verdict stands as reported above.

## DEVIATION 1: warm-start T1 ("TW")

TW changes one line. The full fit starts at (φ_k, inner optimum at φ_k) instead of (φ_k, MLE
nuisance). I reran T and TW on every A1 dataset and on decision cells 5–11 (relabelled D5–D11, same
seeds). D7 reproduces `bench_B`'s T values exactly.

| | T (precommitted) | TW (warm start) |
|---|---|---|
| Accepted-wrong, all cells (18,500 datasets each) | 1 | **0** |
| Unresolved | 0 | 0 |
| Success, G1–G7 | 1.000 | 1.000 |
| Success, decision cells D5–D11 | 1.000 | 1.000 |
| Success, E1–E7 (near-zero q, â ≈ 0, n = 6 and 10, collinear, q at the MLE, q = 25, near-perfect fit) | E6 .9967, all others 1.000 | 1.000 everywhere |
| I3 invariance: datasets > 1e-6 (maximum) | 16 (5.2e-5) | 2 (5.9e-6) |
| I1, I2 invariance maximum | 2e-9, 0 | 3e-9, 0 |
| Median time per dataset | .02–.07 s | the same or slightly less |

**TW still fails criterion 3**, narrowly: 2 of 200 datasets when X is rescaled by 1e-3. The likely
cause is the conditioning of c′ on that scale, under `nlminb`'s relative convergence tolerance. It is
not adjudicated here: I did not run the oracle on the scaled data for those two datasets.

## AUG (descriptive, from `analysis_a1.out`)

| Cells | Strict success | Relaxed success | Accepted-wrong |
|---|---|---|---|
| General G1–G7 | .46–.72 | .974–.993 | 0–6 per 1,000 |
| E2 (â ≈ 0) | .000 | .000 | 0–1; the projected starts b = q/a are absurd |
| E6 (q = 25) | .603 | .910 | 65 of 300 |
| E7 (near-perfect fit) | .637 | .697 | 0 |
| E5 (q at the MLE) | 1.000 | 1.000 | 0 |

## Consequences for medfit (#213, plan v2 Tier 1)

1. Warm-start the full chart fit from the inner optimum of its grid point. This is required.
2. Standardize X, M and Y internally before fitting, and transform back afterwards. The LR is
   invariant, so this costs nothing statistically, and it removes the residual scale sensitivity.
   Recommended; not yet tested.
3. A second local minimum *on the same sign branch* occurs at large |q|. Sign-branch elimination
   alone is therefore not a certificate. The grid over φ is what finds both basins, and the fit must
   keep the best one.

## Status

| Claim | Status |
|---|---|
| TW: 0 wrong in 18,500 datasets across general, edge and decision cells | verified numerically |
| T as precommitted: 1 wrong (E6) and 16 invariance failures (I3) | verified numerically; cause reproduced |
| Same-sign second local minimum at q = 25 | verified numerically (1-D profile, cloud R 4.3.3) |
| Internal standardization removes the I3 residual | open (not run) |

**Not examined:**
- models beyond the two-path model (A1 covers ab = q only);
- latent variables;
- n > 500;
- the oracle on the scaled I3 data.
