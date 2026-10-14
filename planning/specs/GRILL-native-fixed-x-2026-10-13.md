# GRILL: native `fixed_x` (medfit)

| | |
|---|---|
| **Date** | 2026-10-13 |
| **Target** | [PLAN-native-fixed-x-2026-10-13.md](PLAN-native-fixed-x-2026-10-13.md) |
| **Status** | in progress; decisions supersede the plan where they differ |

## Decision Ledger

| # | Branch | Decision |
|---|---|---|
| F-G1 (2026-10-13) | Release shape | **Bundle `fixed_x` into 0.9.0** (author's choice over the recommended 0.9.0-then-0.9.1). 0.9.0 is merged to dev (#174 `8681083`) but untagged (DESCRIPTION 0.8.0); the 0.9.0 tag waits for checkpoints F-A and F-B. The plan's "0.9.1" label is stale. Cost accepted: any `fixed_x` regression blocks the mean-structure release, and the frozen-value gate must be rerun after every df/logLik edit. |
| F-G2 (2026-10-13) | Product columns and per-variable selection | **`TRUE` selects every exogenous observed variable, product columns included; names select any subset, including a product column (`fixed_x = c("x", "xm")`).** A precomputed product is an ordinary exogenous variable in 0.9.0, so nothing extra is needed now. Theory: the likelihood factorizes `f(X, XM) f(M \| X, XM) f(Y \| M, X, XM)` with the exogenous block free and unrelated to theta, so fixing any subset at sample moments leaves estimates and model-based and sandwich SEs unchanged (information block diagonal; the sandwich's structural block depends only on the structural scores). Caveats: fixing a variable fixes its covariance with every other exogenous variable; with a product column the likelihood is a pseudo-likelihood (`XM` depends on endogenous `M`, accepted in the 0.10.0 spec), so the conditional logLik stays refused across models. The exogenous set is computed from the completed model, not the raw syntax; 0.10.0 also accepts the `:` term (`"x:m"`) as a name. |
| F-G3 (2026-10-13) | Visibility of fixed rows | **Visible in `@table`, `tidy()` and `summary()` (flag column `fixed_x`, est = the sample moment, se NA); absent from `theta`, `vcov`, `coef()` and npar/df** (recommended; lavaan's `coef` under `fixed.x = TRUE` excludes them too). |
| F-G4 (2026-10-13) | Guard on the conditional logLik | **Visible, and (F-G7) refused across fixed sets:** `glance()$fixed_x` lists the fixed names (empty when none); `print()`/`summary()` say "logLik is conditional on: ..."; `AIC()`/`BIC()` on several fits (F-G7: error, not warning) when their fixed sets or data differ; `anova()`/`mbco_sem()` refuse (plan F5). Adds a small task to F4. Nothing changes when `fixed_x = FALSE`. |
| F-G5 (2026-10-13) | The "49x" speed claim | **Measure on the real build; quote only the measured ratio in NEWS; no timing gate.** RMediation's 49x (561 to 66 free parameters) came from numeric-fixed emulation on installed 0.7.0, a different code path. F7 records a timing table (30 covariates, n, hardware, free parameters before and after); acceptance stays on correctness gates. |

## Pre-answered from the code (not asked; override on request)

- **Scale interplay (new risk).** `.sem_shift_ok()` requires every observed intercept free, so a fixed exogenous mean (fixed at the sample mean, the lavaan default case) would push every `fixed_x = TRUE` fit onto the plain-coordinate route and lose the 0.9.0 scale protection. Rule: a fixed-x intercept row maps to 0 on mean-centered data, so the shifted route stays allowed for fixed-x rows (they carry no path entry); F7 adds the location sweep (mean/sd 0 to 1e5) with `fixed_x = TRUE` and a subset.
- **Pairing rule (T-2) is in `.sem_complete()`** (`R/sem-model.R`, `paired`): it skips any exogenous variable with an explicit `~~` row; completion adds the free pairs among unselected variables itself, as the plan says.
- **Native `standardized = TRUE` is unsupported** (`R/extract-sem.R`), so the standardized-SE change under `fixed.x` (0.0342 vs 0.0360) does not reach any medfit output.
- **Sandwich:** `(A^-1 B A^-1)_cc = A_cc^-1 B_cc A_cc^-1` for a block-diagonal A, so structural robust SEs do not depend on the exogenous score block; F7 still verifies it, weighted.
- **Explicit statements** on a selected variable (`x ~~ v*x`, `x ~ 1`, a shared label, a constraint or `:=` on its moment) error naming the term (plan rule 3, unchanged).
| F-G6 (2026-10-13) | Default at each entry point | **`FALSE` everywhere** (`fit_sem()` and `fit_mediation(engine = "native")`; opt in with `fixed_x`, through `engine_args` for the mediation route). A different `fit_mediation` default would change the returned `MediationData@vcov` rows (the exogenous variance and mean rows leave), a visible change for no estimate or SE difference. Revisit at 1.0. |
| F-G7 (2026-10-13) | AIC/BIC across fixed sets (Codex adversarial review, high) | **Refuse, not warn.** Multi-fit `AIC()`/`BIC()` on `SEMFit` errors when the fixed sets or the estimation data differ, naming the difference; same-set fits compare. Supersedes the warning in F-G4; the `glance()$fixed_x` column and the print note stay as the second line of defense. Dispatch limit documented: base `AIC(a, b)` dispatches on the first argument only, so `AIC(lm_fit, semfit)` and `rbind(glance(a), glance(b))` cannot be guarded. |

## Open Questions

- **Ordering inside the fit (design detail, not a decision).** The fixed values need the data's moments, which need the listwise-complete rows, which need the observed-variable set from the completed table. F2 therefore creates the fixed-x rows in `.sem_complete()` with the `fixed_x` flag and assigns their values after `.sem_sample()` (or computes the observed set first); pick whichever keeps the T1 frozen gate bit-identical.
- **Explicit-statement policy under lavaan-copied models (answered by R0, 2026-10-13).** lavaan 0.7.2 with `fixed.x = TRUE` neither errors nor overrides: an explicit `x ~~ x`, `x ~~ v*x`, `x ~~ c1` or `x ~ 1` makes that parameter FREE again (`free > 0`), the parameter count rises by one, and df moves (0 to 1 for `x ~~ x`), so the fit silently becomes a different model. Evidence: `evidence/native-fixed-x-2026-10-13/lavaan-explicit-exo-variance.R` and `.out` (one dataset, n = 300, lavaan 0.7.2). medfit keeps S5 (error naming the term), which is stricter and avoids the df shift; record the difference in `?"medfit-syntax"` (V10).
- Missing-row and weight edge cases are covered by F7 (extends the RMediation checks, which were complete-data, one dataset, n = 500).
