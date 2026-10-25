# [BREAKING] fit_sem() defaults change in 0.15.0: fixed_x = TRUE and meanstructure = TRUE

Draft for T10 of `planning/PLAN-0.14.0-native-defaults-2026-10-24.md`. Not filed; the author files it.

---

## What changes

In medfit **0.15.0**, the native engine's defaults change together:

| Argument | Today (0.14.x) | 0.15.0 |
|---|---|---|
| `fixed_x` | `FALSE` | `TRUE`: the observed exogenous variables (product and factor columns included) are fixed at their sample moments, except any the model writes a `~~` or `~1` statement on, which stay free |
| `meanstructure` | `NULL` (means only if the model writes `~1` or a product) | `TRUE` |

This applies to `fit_sem()` and to `fit_mediation(engine = "native")`.

## When

- **0.14.0** (the release that opens this issue) warns once per session per argument when either is left unset
  and the default matters. Results do not change in 0.14.0.
- **0.15.0** flips both defaults, **no earlier than two months after 0.14.0** is released. The clock starts at
  the 0.14.0 release date.

## What moves, and what does not

- **Moves:** `logLik()`, the number of parameters, AIC and BIC, and the parameter list (fixed exogenous moments
  leave it; intercepts join it).
- **Does not move on the measured cases:** structural estimates and their standard errors. The native-defaults
  oracle matrix (`tests/sim/native-defaults-oracle.R`, 557 rows against lavaan) finds no disagreement; its `limit`
  rows are declared conventions, such as `glance()` returning `NA` fit statistics for weighted fits.

## What to do

- **To keep today's results:** pass `fixed_x = FALSE, meanstructure = NULL` explicitly. That silences the 0.14.0
  warning and keeps results identical after 0.15.0.
- **To try the 0.15.0 defaults now:** `options(medfit.native_defaults = "0.15")`. Variables the default leaves free
  are named in a message of class `medfit_message_fixed_x_lenient`.
- **To silence the warning by class** (for example in a package's tests): muffle
  `medfit_warning_default_change`.

## Known dependents

- **RMediation:** tests and the `mbco()` example pass both settings explicitly (Data-Wise/rmediation#85).
- **missingmed:** `R/mbco_sem.R` on its open PR #102 calls `fit_sem()` without `meanstructure`; the fix is posted
  there (Data-Wise/missingmed#102 comment). Its users would see the warning until that lands.
- probmed, mediationverse, medsim, medrobust: no `fit_sem()` call affected (Checkpoint B, three builds, 0 changed
  results).

## References

- Spec: `planning/specs/SPEC-native-defaults-2026-10-24.md`; ADR for the defaults.
- PRs: #315-#328 (0.14.0 work).
