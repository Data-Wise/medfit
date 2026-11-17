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

   ```r
   grep("nlevels", deparse(body(lavaan:::lav_pt_add_bounds)), value = TRUE)[1]
   #> "    if (lav_pt_nlevels(partable) > 1L) {"
   pv <- lavaan::sem(fc_model(floor = FALSE), d, cluster = "id", fixed.x = FALSE, bounds = "pos.var")
   names(lavaan::parTable(pv))   # no "lower"
   #> "id" "lhs" "op" "rhs" "user" "block" "level" "free" "ustart" "exo" "label" "plabel" "start" "est" "se"
   #> warning: lavaan->lav_object_post_check(): some estimated ov variances are negative
   lavaan::lavInspect(pv, "post.check")   #> FALSE
   fc_l2_var(pv)                          #> X 0.6330654  M 0.3194527  Y -0.3093251
   ```
2. **The syntax floor binds.** P1 labels each level-2 variance (`Y ~~ vy_b*Y`) and adds `vy_b > eps`.
   Y ends at eps exactly (|v - eps| < 1e-8), the fit converges, post.check is TRUE and lavaan raises no warning.
   The SE of `vy_b` is 0: lavaan treats the active inequality as an equality in the covariance.
   Level-2 block emitted by `fc_model(floor = TRUE, eps = 1e-3)`:

   ```
   level: 2
     X ~~ vx_b*X
     M ~~ vm_b*M
     Y ~~ vy_b*Y
     M ~ a_b*X
     Y ~ b_b*M + cp_b*X
   vx_b > 0.001
   vm_b > 0.001
   vy_b > 0.001
   ```
3. **The adapter accepts the floored fit.** `extract_mediation()` on the P1 fit raises only the
   `medfit_few_clusters` warning and reports `admissible = TRUE`; `twolevel_statistic(ff, "nie_between")`
   returns -0.001117 with no warning.
4. **Bootstrap refits are not lost to the negative-variance warning.** The cluster bootstrap
   (`R/bootstrap.R`, `.bootstrap_nonparametric_cluster`) counts any warning other than `medfit_few_clusters`,
   or a message containing "singular", as a failed replicate. `twolevel_statistic()` refits with
   `check.post = FALSE` (`R/twolevel-statistic.R:229`), so the P0 warning above is not raised in refits.
   Ten cluster replicates, `set.seed(42)`:

   ```r
   fit <- fc_fit(d, arm, 1e-3)$fit   # arm "p1" or "p0"
   stat <- twolevel_statistic(fit, "nie_between", treatment = "X", mediator = "M", outcome = "Y")
   set.seed(42)
   b <- bootstrap_mediation(statistic_fn = stat, method = "nonparametric", data = d, cluster = "id", n_boot = 10)
   ```

   ```
   p1: kept 10 of 10, estimate -0.001117, ci [-0.0072, 0.0084]
   p0: kept 10 of 10, estimate -0.107492, ci [-0.1934, -0.0497]
   ```

   No warning was raised in either run. P0 refits keep inadmissible solutions silently (documented behavior).
   A probe statistic that refits the P1 model with the same refit options and records the smallest level-2
   variance (same seed, 10 replicates plus the original-data call) gave `min level-2 variance over refits 0.001 n 11`.

## Stop rules

- **S5 (neither floor binds): not triggered.** The syntax floor binds; only `pos.var` does not.
- **S4 (adapter defect): none found.**

## Note for the plan (documentation, not a defect)

The adapter's `nie_contrast` is within minus between (NIE_W - NIE_B), so its truth is .02 (or .20 when
NIE_B = 0). The plan's "Delta = -.02" follows the P2X sign (between minus within). The harness scores the
adapter's sign; the plan text should say which sign the study reports.
