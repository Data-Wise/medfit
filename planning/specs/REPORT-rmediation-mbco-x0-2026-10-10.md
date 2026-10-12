# Report for RMediation's author: `mbco()` example labels and a nonlinear-constraint optimum

**Status:** FILED 2026-10-10 as Data-Wise/rmediation#35 (title: "mbco() example: path labels shift when endVar includes x; nonlinear ind1 == 0 lands at the a1 = 0 branch"). The issue is the authoritative text; this report is the longer write-up it links to.
**Date:** 2026-10-10 | **Found by:** medfit's native SEM work (PLAN-native-sem-implementation-2026-10-09.md, S0(c) and S0(d); ledger X0)
**Checked against:** RMediation 1.6.1 (installed), OpenMx 2.22.11, nloptr 2.2.1, R 4.x on macOS
**Reproduction:** `planning/specs/evidence/native-sem-2026-10-08/07-preflight.R`, stored output `results/07-preflight.out` (11 of 11 checks pass)

## Summary

Two findings, both in the `mbco()` documentation example or in what it exercises. Neither changes how `mbco()` itself is coded; the first is an example defect, the second is a warning about the nonlinear null model.

1. **The Rd example's labels are shifted** (example defect). `ind1 = a1 * b1` is the direct path times `b1`, so the example tests the wrong product.
2. **On the correctly labeled model, the nonlinear null `ind1 == 0` lands at the `a1 = 0` optimum** (diffLL 221.045546), not at the smaller of the two linear nulls (0.083100). The MBCO statistic from the single nonlinear solve is then far larger than the minimum of the two likelihood-ratio tests.

## Finding 1: labels shift in the `mbco()` example

The example (`mbco.Rd`, inside `\dontrun`) builds the model with:

```r
endVar <- c("x", "repetition", "imagery", "recall")
manifests <- c("x", "repetition", "imagery", "recall")
OpenMx::mxPath(from = "x", to = endVar, arrows = 1, free = TRUE,
               values = .2, labels = c("a1", "a2", "cp"))
```

`endVar` starts with `"x"`, so the path list includes `x -> x`. OpenMx drops that one-headed self-path (it warns that the path "is now overwritten by a two-headed path between 'x' and 'x'" when the variance paths are added) and assigns the three labels to the remaining three targets in order:

| Path | Intended label | Actual label |
|---|---|---|
| x -> repetition | a1 | **a2** |
| x -> imagery | a2 | **cp** |
| x -> recall | cp | **a1** |

Check: `model$A$labels[c("repetition", "imagery", "recall"), "x"]` returns `a2, cp, a1`.

Consequence: `ind1 = a1 * b1` is the x -> recall (direct) path times `b1` (repetition -> recall). The example's reported value, diffLL **0.060332** (seeds 1-3 identical, `mxTryHard()` then `mxCompare()`), tests that product. It equals the separate solve with the shifted `a1` fixed at 0 (0.060332, below the `b1 == 0` solve at 0.083100).

Suggested fix: drop `"x"` from `endVar` in the first `mxPath()` call (use `to = c("repetition", "imagery", "recall")`), keep `endVar` for the means path if wanted, and recompute any value quoted from the example.

## Finding 2: the nonlinear null finds the larger optimum

On the correctly labeled model (x -> repetition `a1`, x -> imagery `a2`, x -> recall `cp`, repetition -> recall `b1`, imagery -> recall `b2`; raw `memory_exp` with means), diffLL against the full model:

| Null model | diffLL |
|---|---|
| `a1 == 0` (linear, fixed) | 221.045546 |
| `b1 == 0` (linear, fixed) | **0.083100** |
| `ind1 == 0` as `mxConstraint(ind1 == 0)`, seeds 1-3 | 221.045546 (a1 = 1e-94, b1 = 0.0215) |

The MBCO statistic for `a1 * b1 == 0` is the minimum of the two linear likelihood-ratio tests, 0.083100. The single nonlinear solve with `mxTryHard()` (checkHess off, 15 extra tries) converged at the `a1 = 0` corner in all three seeds, giving 221.045546. A test built on that value would reject where the minimum-of-two test does not.

This is a solver outcome on one dataset, not a general claim. The three seeds agree with each other and with the `a1 == 0` solve, so more starts did not escape it. Worth a look at whether `mbco()` computes the statistic as the minimum of the two linear solves or from the nonlinear constraint.

## Relation to rmediation#34

Data-Wise/rmediation#34 (opened 2026-10-07, found after this report was drafted) concerns the same `mbco()` example and the same `mxConstraint(ind == 0)` pattern, but runs the other way: OpenMx's default feasibility tolerance (0.05) lets the null fit stop off the null set, so `-2LL(h0)` is too low and the MBCO statistic is understated. Finding 2 above is the null fit sitting exactly on the null set (|ab| about 1e-96) at the worse branch, so the statistic is overstated (221.05 vs the exact 0.0831). They are separate mechanisms. The remedy #34 proposes, fitting the two single-path nulls and taking the smaller `-2LL`, covers both. Finding 1 (shifted labels) is not in #34.

## What this was not

- Not a defect in `mbco()`'s code path: the report concerns the Rd example and the nonlinear null on this model. I did not read `mbco()`'s source.
- Not edited: medfit treats RMediation as read-only; nothing here changes it.

## How medfit uses this

medfit's `mbco_sem()` gates on both values: the as-written 0.060332 (literal reproduction) and the correctly labeled 221.045546 / 0.083100, so the example defect cannot silently pass.

## Reproduce

```r
# from the medfit repo root
Rscript planning/specs/evidence/native-sem-2026-10-08/07-preflight.R
# needs OpenMx and RMediation (for the memory_exp data); checks [d1] [d2] cover finding 1, [a1] [a2] [c1]-[c4] finding 2
```

## Where to file

Filed: Data-Wise/rmediation#35, with links to the script and this report at medfit commit `443fd5e`.
