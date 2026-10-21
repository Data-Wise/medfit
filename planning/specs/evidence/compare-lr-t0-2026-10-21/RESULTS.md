# T0 spike results (2026-10-21), plan `PLAN-compare-lr-249-2026-10-21.md`

Versions installed: OpenMx 2.22.11, lavaan 0.7.3 (macOS, R release). Cell: X, M independent N(0,1), Y = 0.3 X + N(0,1), n = 100 (the joint null a = b = 0),
model `M ~ a*X; Y ~ b*M + cp*X` (saturated), null `a*b == 0`. Reference: `mbco_sem(fit, "a", "b")`, minimum `diff_ll`. Tolerance 1e-4 * max(1, LR).
Scripts here run from the package root (`Rscript <script>`); they need OpenMx and lavaan and the dev package (`load_all`).

| Engine / start | Result | Reproduces? |
|---|---|---|
| OpenMx, zero start (60 seeds) | LR about 0 in 59 of 60 while medfit LR > tolerance; returned a*b violates the constraint (residual up to 0.027) | **Yes** (OpenMx#433: the constraint is dropped) |
| OpenMx, medfit default start (60 seeds) | no dropped constraint; 1 of 60 returned an LR above medfit's (0.308 vs 0.106, a worse local optimum, seed 2) | Partly: a local optimum, not a drop |
| lavaan, default start (300 seeds) | converged 300/300; statistic above medfit's beyond tolerance in **20 of 300 (6.7%)**; never below | **Yes** (issue reports 11%) |
| lavaan, zero start | **could not be applied**: a start of 0 set in the parameter table, or passed as `start = <table>`, is replaced (start values stayed -0.047, -0.035) | Not tested |

## Decisions and consequences

- **P1: GO.** Both known failures reproduce on the installed versions, so `compare_lr()` is exported.
- The evidence rules work on this data: OpenMx's failure shows as a violated constraint (residual above tolerance), not just LR = 0; lavaan's as a statistic above the accepted medfit minimum.
- `medfit_warning_engine_statistic_above_max` must cover **both** engines (OpenMx's default start also returned a statistic above the restricted maximum once).
- **T2 risk:** P4 needs a zero start for lavaan, and lavaan's parameter-table start was ignored. T2 must find a working mechanism (for example `start` modifiers in the model syntax, or a perturbation inside the optimizer control) or document lavaan as running from its default start only; the plan's open question 2 now also covers this.
- **T3 correction:** `sem_openmx()` in `tests/testthat/helper-sem.R` is not drop-in. It takes a test model with data frames `mod$a`, `mod$s` (`row`, `col`, `label`, `value`) plus `smp`, not a `SEMFit`. The spike built them by hand (`sem_rows(...)` and `.sem_ram()`); T3 needs a small translation from the fit's table for observed-variable models.
