# PLAN: `fixed_x` for the native SEM engine (0.9.1, after 0.9.0 T5)

**Date:** 2026-10-13 | **Branch:** `feature/native-fixed-x` (not created; branching waits for your request) | **Status:** decided, not started
**Inputs:** RMediation's proposal and grill (read-only, `~/projects/r-packages/active/rmediation/planning/PROPOSAL-medfit-fixed_x-2026-10-13.md`, `GRILL-...`, `RESEARCH-...`); this repo's [GRILL](GRILL-native-mean-structure-2026-10-12.md) G13; [PLAN-native-mean-structure](PLAN-native-mean-structure-2026-10-12.md).
**Decision (author, 2026-10-13, chat "build fixed_x"):** build Option C. Placement is the recommended one: after 0.9.0 T5, as 0.9.1, because it rewrites the same df, logLik and `anova()` code that T3 and T5 rewrite. Default `FALSE`.

## Semantics

`fit_sem(..., fixed_x = FALSE | TRUE | <character vector of exogenous observed variable names>)`, and `fit_mediation(engine = "native", fixed_x = )`.

1. **What is fixed.** For each selected variable: its mean (when mean structure is on), its variance, and every covariance touching it, at the sample moments of the estimation sample (after listwise deletion, ML denominator n, weighted when `weights` are used). `TRUE` selects every exogenous observed variable. Names must be exogenous observed variables of the model; anything else errors naming the variable.
2. **Why per-variable selection is sound.** For a Gaussian path model whose exogenous moments are free and not tied to structural parameters the log-likelihood separates into `l_cond(theta) + l_x(phi)`, so fixing any subset of phi at sample moments leaves the estimates and their model-based and sandwich SEs unchanged (lavaan checks by the RMediation session: 7 subsets, estimates 7e-14, SEs 1e-9; MLR SEs 1e-13; all-fixed vs lavaan `fixed.x = TRUE` 2e-17; one dataset, n = 500, complete data).
3. **Explicit statements error.** A user statement that touches a selected variable (`x ~~ 2*x`, a shared label, `x ~ 1`, a constraint or `:=` involving its moment) is an error naming the term.
4. **logLik is conditional** on the fixed block (as lavaan). `anova()` and AIC/BIC comparisons across different fixed sets, or different data, are refused (builds on the #171 nesting check).
5. **Default stays `FALSE`**, so 0.8.0/0.9.0 values stay frozen; revisit at 1.0.

## Traps to design around (both reproduced by the RMediation session)

- **T-1 Fixed exogenous moments are not restrictions.** Emulating with numeric fixed values moved df 1 -> 4 -> 7; real `fixed.x = TRUE` keeps df 1 and chi-square 9.188694. Fixed-x rows leave both the moment count and the parameter count (flag them separately from a user-fixed value), so df, `anova()` and `mbco_sem()` are unchanged.
- **T-2 The pairing rule.** `.sem_complete()` pairs exogenous covariances only for variables without an explicit `~~` statement (`R/sem-model.R`, the `paired` block); selection silently dropped `c1 ~~ c2` (npar 10 instead of 11, SE off by 3e-4). Completion must add the free pairs among the unselected variables itself, and fix the pairs touching a selected one.

## Tasks (sizes S/M; checkpoints F-A after F3, F-B after F6)

- **F1 (S) Argument, validation, errors.** `fixed_x` normalization (logical or names), errors for non-exogenous names, explicit statements (rule 3), and ties to structural parameters; store the resolved set in `SEMFit@internals`. Tests by error message.
- **F2 (M) Completion with moments.** `.sem_complete()` receives the data's moments (weighted, listwise); fixed-x rows carry the value and a `fixed_x` flag distinct from a user-fixed value (so T-1 and a user's `0*` stay distinguishable); free pairs added explicitly (T-2); with mean structure the means follow rule 1.
- **F3 (M) Counts. Checkpoint F-A.** `.sem_df()`, `n_free`/npar and `nobs`-type counts exclude fixed-x rows from moments and parameters. Gate: lavaan `fixed.x = TRUE` parity on table, npar, df 1 and chi-square 9.188694 on the reference model.
- **F4 (S) logLik conditional.** logLik, AIC, BIC conditional on the fixed block; `glance()` documents it; unchanged when `fixed_x = FALSE` (frozen gate).
- **F5 (S) Comparisons refused.** `anova()` and `mbco_sem()` error across different fixed sets or data; same set allowed.
- **F6 (S) Plumbing. Checkpoint F-B.** `fit_sem`, `fit_mediation`, `.sem_fit_branches` (pass by name), `mbco_sem()` re-parse, `extract_mediation()` unchanged, `print()`/`summary()` say which variables are fixed.
- **F7 (M) Evidence.** Subset-invariance (every subset of {x, c1, c2}: estimates and SEs equal the free fit, model-based and sandwich, weighted); lavaan `fixed.x = TRUE` parity; subset oracle = lavaan with explicit numeric values plus the df/logLik correction; OpenMx; a 30-covariate timing check (RMediation measured 49x, 561 -> 66 free parameters, ab and SE within 2e-9/3e-10 on installed 0.7.0). Planted defects, each named: fixed moments counted as restrictions (df), dropped free covariance (T-2), joint instead of conditional logLik, a non-exogenous or tied variable accepted.
- **F8 (S) Docs.** NEWS; `?fit_sem`; the "native always frees exogenous moments, lavaan defaults to TRUE" text in vignettes and `model-native.qmd`; the lavaan comparison row; CLAUDE.md Engines row. Does not by itself drop "experimental" (target 0.11.0, GRILL G13).

## Dependencies and risks

- Needs 0.9.0 T2-T5 (mean structure, df rule, `anova()` normalization) merged first; #171 (nesting fix) is merged.
- Per-variable fixing has no lavaan oracle of its own (lavaan's `fixed.x` is all or nothing); the explicit-value lavaan route plus OpenMx stands in.
- A selected variable with a constraint tying its moment to a structural parameter breaks the separation; rule 3 errors instead of fitting.
- One simulated dataset, complete data, normal ML so far: F7 extends to missing rows and weights.

## Not in this plan

Making `fixed_x = TRUE` the default (revisit at 1.0), fixed exogenous moments for latent exogenous variables, non-Gaussian likelihoods.
