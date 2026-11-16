# T2: floor mechanics in lavaan two-level fits

Plan: `planning/PLAN-few-clusters-design-study-2026-11-16.md`, task T2. Date 2026-11-16.
Environment: R 4.6.2, lavaan 0.7.3, medfit 0.18.0.9000 installed from worktree SHA `67fd1264` into a scratch library.
Harness: `tests/sim/twolevel-few-clusters-lib.R`; the checks below are tests in
`tests/testthat/test-twolevel-few-clusters-harness.R` ("T2: ...").

## Planted dataset

`fc_planted_negative()`: J = 30, n = 5, seed 1 (Mersenne-Twister); Y's cluster means are replaced so that its
between-level residual variance goes negative. Fits use `lavaan::sem(model, d, cluster = "id", fixed.x = FALSE)`.

## Findings

| Arm | Level-2 variances (X, M, Y) | lavaan warnings | post.check |
|---|---|---|---|
| P0 (no floor) | 0.633, 0.319, **-0.309** | `lav_object_post_check(): some estimated ov variances are negative` | FALSE |
| `bounds = "pos.var"` | unchanged, Y **-0.309** | same as P0 | FALSE |
| P1 (syntax floor, eps = .001) | 0.652, 0.333, **0.001** | none | TRUE |

1. **`bounds = "pos.var"` binds nothing in a two-level fit.** The parameter table has no `lower` column.
   lavaan returns early from `lav_pt_add_bounds()` when `lav_pt_nlevels(partable) > 1L`; in a single-level
   fit the same option adds `lower = 0`. This arm is therefore identical to P0 and is not a floor.
2. **The syntax floor binds.** P1 labels each level-2 variance (`Y ~~ vy_b*Y`) and adds `vy_b > eps`.
   Y ends at eps exactly (|v - eps| < 1e-8), the fit converges, post.check is TRUE and lavaan raises no warning.
   The SE of `vy_b` is 0: lavaan treats the active inequality as an equality in the covariance.
3. **The adapter accepts the floored fit.** `extract_mediation()` on the P1 fit raises only the
   `medfit_few_clusters` warning and reports `admissible = TRUE`; `twolevel_statistic(ff, "nie_between")`
   returns -0.001117 with no warning.
4. **Bootstrap refits are not lost to the negative-variance warning.** The cluster bootstrap
   (`R/bootstrap.R`, `.bootstrap_nonparametric_cluster`) counts any warning other than `medfit_few_clusters`,
   or a message containing "singular", as a failed replicate. `twolevel_statistic()` refits with
   `check.post = FALSE` (`R/twolevel-statistic.R:229`), so the P0 warning above is not raised in refits.
   Ten cluster replicates, `set.seed(42)`:

   ```
   p1: kept 10 of 10, estimate -0.001117, ci [-0.0072, 0.0084]
   p0: kept 10 of 10, estimate -0.107492, ci [-0.1934, -0.0497]
   ```

   P0 refits keep inadmissible solutions silently (documented behavior); P1 refits stay at or above eps.

## Stop rules

- **S5 (neither floor binds): not triggered.** The syntax floor binds; only `pos.var` does not.
- **S4 (adapter defect): none found.**

## Note for the plan (documentation, not a defect)

The adapter's `nie_contrast` is within minus between (NIE_W - NIE_B), so its truth is .02 (or .20 when
NIE_B = 0). The plan's "Delta = -.02" follows the P2X sign (between minus within). The harness scores the
adapter's sign; the plan text should say which sign the study reports.
