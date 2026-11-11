## Summary

FI-G3 slice S2: the pure chain, the second public serial FIML variant (`a2` and `b1` absent, no covariates, k = 0),
on top of the merged S1a router and S1b saturated variant. `fit_sem()` with `missing = "ml"` now fits
`X -> M1 -> M2 -> Y` with the direct path free or fixed and the three residual covariances fixed at zero (q 12 with the
direct path free and 11 with it fixed; df 2 and 3). The saturated variant and the chain with k >= 1 stay refused with a
classed `medfit_sem_fiml_error` until S3 and S4.

- Chain extraction through `extract_mediation()` and `fit_sem()` (`R/fit-sem.R`, `R/sem-fiml-interface.R`,
  `R/aab-generics.R`) over four aliases: `a`, `d1`, `b`, `c_prime`; `nie` equals `nie_total` (the only path is the
  chain); `te` = `nie` + `c_prime`, with delta-method SEs and the per-effect origin rule.
- Class validator for `FIMLSerialMediationData` (`R/classes.R`): an exact predictor-list check (`setequal` per list)
  for both variants. This closes the S1b QA gap (the S1b validator checked only the shortcut flags, so a forged
  `outcome_predictors` or `mediator_predictors` was accepted).
- Post-S2 refusal fixture `tests/testthat/fixtures/fiml-refusals-after-g3s2.rds` (built by `make-fiml-after-g3s2.R`);
  the earlier frozen fixtures are untouched.
- Gate `fiml-ext`: new structure `ser_chain0`, four chain planted defects (`ser_chain_free_shortcut`,
  `ser_chain_swap_db`, `ser_chain_origin`, `ser_chain_te_gradient`); 10 structures x 2 seeds x 8 checks + 1 = 161 rows.
- Docs: NEWS, roxygen (`fit_sem`, `extract_mediation`, man pages regenerated), native guide, models, methods, README and
  the book chapter scope sentences.

No statistical admission, coverage or global-optimality claim is made. No push, release or CRAN step is part of this
change.

Not run: any check on the OpenBLAS gates runner, the platform matrix, statistical coverage, a Hopper run, the vignette
build in `R CMD check`, a lavaan 0.6.x recheck (Q15), a refresh of the other gates (see Evidence).

## Evidence (pre-PR testing, tree = branch tip)

Local machine: macOS aarch64, R 4.6.2. Tree: worktree `feature/fiml-serial-s2`, tip `fd4a07e6`, 7 commits above
`origin/dev` `c8d90aa5`. Lint, check and gates were run on `git archive HEAD` copies with isolated libraries
(`find.package("medfit")` verified to point at the isolated library for lint).

| Check | Command | Result |
|---|---|---|
| Full suite, at the final tip | `NOT_CRAN=true Rscript -e 'r <- as.data.frame(devtools::test(reporter="silent", stop_on_failure=FALSE))'` | 195 files, 2123 tests, 17113 expectations, 0 failed, 0 errors, 2 skipped, 4 warnings, measured at the final tip `fd4a07e6` (the two skips also skip on `dev`; the 4 warnings are the known cluster-boot, branches and lavaan "empty cases" ones) |
| Full suite, implementer, at the docs commit `fa58edbc` | the same command | 2122 tests, 17090 expectations, 0 failed, 0 errors, 2 skipped, 4 warnings; the last commit `fd4a07e6` (lavaan agreement for every fitted never-jointly-observed chain cell) added one test after this run |
| Lint | isolated source install of `git archive HEAD`, `R_LIBS=<lib> Rscript -e 'lintr::lint_package()'` with the repo `.lintr` | 0 findings at `fd4a07e6` |
| R CMD check | `R CMD build --no-manual --no-build-vignettes`, then `_R_CHECK_FORCE_SUGGESTS_=false NOT_CRAN=false R CMD check --as-cran --no-manual --ignore-vignettes --no-tests` | Status: 1 NOTE (CRAN incoming feasibility: "Version jumps in minor (submitted: 0.16.0, existing: 0.3.2)"); 0 WARNING, 0 ERROR. Same NOTE as `dev`. Rd files, Rd metadata, Rd line widths, Rd cross-references, code/documentation mismatches, `\usage`, Rd contents, examples and `--run-donttest` examples all OK; tests skipped by option |
| Gate verdicts | `NOT_CRAN=true Rscript tests/sim/run-gates.R --sim --only fiml,fiml-ext` | `fiml` PASS (24 rows of 24); `fiml-ext` PASS (161 rows of 161, ten structures x two seeds x eight checks plus the refusal count, `unadmitted_accepted` = 0); OVERALL PASS, 12 of 12 driver checks |
| Gate planted defects | `MUTANT=<name> Rscript tests/sim/sem-fiml-ext-gate.R` for all 16 registered names | all 16 stop with a failing gate (exit 1). Numeric rows fail: `wrong_unit` (28 rows), `no_offset` (20), `swap_b` (23), `dropped_cov` (12), `missing_guard` (20 guard rows), `ser_swap_db` (8: `nie_estimate`, `nie_se`, saturated and chain cells), `ser_drop_cross` (4: `nie_se`), `ser_total_gradient` (2: `nie_se`), `ser_chain_free_shortcut` (10: covariance, estimates, likelihood, `nie_estimate`, `nie_se`), `ser_chain_swap_db` (8: `nie_estimate`, `nie_se`), `ser_chain_origin` (4: `nie_se`), `ser_chain_te_gradient` (4: `nie_se`); `serial_admitted` makes `unadmitted_accepted` = 4 (limit 0). Caught by a structural crash instead of a numeric gap (fail-closed): `parcov_drop_path` and `parcov_orthogonal` (`subscript out of bounds`), `serial_router_off` (`unsupported FIML topology or correlated disturbances`), `ser_drop_shortcut` (`length(labels) == conv$ram$q is not TRUE`) |
| Driver mutants | `NOT_CRAN=true Rscript tests/sim/run-gates.R --mutants --only fiml,fiml-ext` | every mutation rejected, every control passes (exit 0) |
| Parity (V14) | the implementer's parity run against `origin/dev` | 60 of 60 cells identical (implementer-run; the sparse-mask cell is not among them) |
| Other gates | `Rscript tests/sim/run-gates.R` (all gates) | not refreshed here: the all-gates run reports OVERALL FAIL, 13 of 35 checks, identical on `origin/dev` `c8d90aa5` (stale results of other gates, unrelated to FIML); no waiver is sought for them in this PR |

Gate rows are two fixed seeds per structure, not a coverage study. The committed gate CSV
(`tests/sim/results/sem-fiml-ext-gate-2026-11-09.csv`) is the implementer's run; the gates pass above re-ran the gate
on the tip copy and passed.

## Admission checklist

- [x] 1. independent oracle: pure-chain serial k = 0 fit against lavaan (raw-data FIML), equation-wise OLS (`lm`), a
  rowwise Hessian for the observed information, OpenMx on one cell, and the restriction LR against the saturated fit, in
  `tests/testthat/test-fiml-g3-serial-chain.R` (oracles implementer-run, including lavaan agreement for every fitted
  never-jointly-observed chain cell); the gate's `ser_chain0` cell compares the chain NIE, total effect and every
  extracted path to lavaan `:=` and labeled values. Independent QA: see the Independent QA section below.
- [x] 2. reliability cell: `fiml-ext` gate, 10 structures (new `ser_chain0`) x 2 seeds x 8 checks plus the refusal
  count, 161 rows, all pass, re-run on the tip copy above. A small fixed-seed cell, not a coverage or
  large-replication study
- [x] 3. planted defect: four new gate defects `ser_chain_free_shortcut` (freed shortcut), `ser_chain_swap_db` (d1/b
  swap), `ser_chain_origin` (origin rule) and `ser_chain_te_gradient` (te gradient), plus the twelve earlier ones, all
  caught (see the evidence table); the test suite plants, each with a positive control first, in
  `tests/testthat/test-fiml-g3-serial-chain-defects.R`: freed shortcut, variant routing, d1/b swap, cross block, te
  gradient, origin rule, validator forgeries, a six-alias vector
- [x] 4. metamorphic invariance: the chain NIE and `te` are invariant to a consistent d1/b relabeling, so the gate also
  checks every extracted path against lavaan; frozen fixtures (`fiml-refusals-after-g3s2.rds`, built by
  `make-fiml-after-g3s2.R`) pin the unchanged refusals and the earlier fixtures stay untouched; V14 parity with
  `origin/dev` on non-serial fits (60 of 60 identical, implementer-run)
- [x] 5. fault injection: the saturated variant and the chain with k >= 1 are refused at fit; the validator rejects
  forged predictor lists for both variants (exact `setequal`) and a six-alias vector; the per-effect origin rule is
  planted in the test suite; refusal probes in the gate (26, among them the serial Q2, shortcut, not-yet-public,
  reversed-order (saturated and chain) and never-jointly-observed probes) must admit 0. Not covered: refit-failure
  injection (no serial bootstrap exists)
- [x] 6. registration: `tests/sim/gates.csv` row `fiml-ext` (161 rows, `oracle` = lavaan raw-data FIML, `mutants` =
  `wrong_unit|no_offset|swap_b|dropped_cov|missing_guard|parcov_drop_path|parcov_orthogonal|serial_admitted|serial_router_off|ser_swap_db|ser_drop_cross|ser_total_gradient|ser_drop_shortcut|ser_chain_free_shortcut|ser_chain_swap_db|ser_chain_origin|ser_chain_te_gradient|driver`);
  `tests/sim/structures.csv` row "bounded random-X FIML with the pure chain of serial mediators" names `fiml-ext` (the
  gate cell is `ser_chain0`); `R/fit-sem.R` and `R/sem-fiml-interface.R` are in `tests/sim/risk-files.txt`
- [ ] 7. n/a: the OpenBLAS gates runner runs only on PRs to `main` and this PR targets `dev`, so no OpenBLAS run exists
  (not run); `fiml-ext` joins the `gates (rest)` shard on the release PR, and dev is gated locally (suite, lint,
  `R CMD check` above)

## Independent QA

`medfit-oracle-qa`: **PASS on all 10 items, no defect, no planted defect missed** (own code and mutants; scratch only).

- lavaan raw-data FIML, 18 cells (c_prime free/zero/omitted x MCAR 30%, MAR, sparse masks with all-missing mediator pairs and all-NA rows; n = 500; 2 seeds): estimates 4.4e-7, logLik 3.3e-10, vcov 2.7e-9, `ind` and `te` 8e-8, delta SEs 9.7e-9; row counts match. OpenMx, 2 cells: estimates 8.6e-7, logLik 6e-10, vcov 4e-7.
- Complete data equals equation-wise ML-OLS (estimates 9e-9, vcov 3.8e-11), vcov exactly block diagonal (cross-equation terms up to 2.4e-4 under MAR). The chain is overidentified: the LR against the saturated serial fit equals `lavTestLRT` to 1e-10 in 12 cells (df 2 free, 3 fixed), small on a true-chain DGP (0.1 to 5.6, p 0.06 to 0.94) and large with real shortcuts (11.6 to 69.6, p <= 3e-3); `logLik(chain) <= logLik(saturated)` in every cell including sparse masks.
- `a2` and `b1` are truly absent (4x4 vcov over a, d1, b, c_prime; chain predictor lists; four path rows with `c_prime` always listed; effects `nie`, `nie_total`, `nde`, `te`); hand delta SEs (3x3 `nie`, 4x4 `te`, no `a2`/`b1` term) equal `tidy` and `confint` exactly.
- Origin rule (forged exact zeros, hash rebound): `nie` and `nie_total` NA when any two of a, d1, b are 0, finite with one zero; `nde` and `te` finite; the saturated rule is unchanged (9 patterns identical to `dev`).
- Routing: chain vs saturated detected correctly across syntax variants; half shortcuts, and fixed, labeled or tied shortcuts, refused; every k >= 1 serial syntax still "not yet available"; each omitted zero covariance named; extraction refusals classed.
- Class validator: 34 forgeries rejected (predictor lists, variant/context mismatch, hash, alias vectors, a 6x6 vcov on a chain), real chain and saturated objects accepted: this closes the S1b gap.
- Guards: source-fit gives `medfit_error_fiml_inference_unavailable` then (guard mocked open) `medfit_error_fiml_serial_source_fit`; `bootstrap_mediation(mediation_data =)`, `pm()`, `glance()`, `quick()`, `confint(method = "boot")` refuse; the base `SerialMediationData` is `identical()`.
- Planted defects: all caught with a clean 9-check control (freed shortcut, chain parsed as saturated and the reverse, d1/b swap, dropped cross-equation block, wrong `te` gradient, origin rules, six-alias vector, weakened validator); the chain `nie` alone is invariant to a d1/b swap, as predicted.
- V14 parity with `origin/dev` `c8d90aa5`: 12 models x 4 datasets (complete, MCAR, MAR, sparse) = 48 cells, `identical()` on theta, vcov, logLik, tidy, extract, confint, paths, coef.
- Robustness and never-jointly-observed pairs: 12 chain fits (n 50 and 500, 0/30/50% missing, corr(M1, M2) up to 1.00) all match lavaan; most pairs fit and match lavaan (estimates 7e-6, logLik 2.1e-8); two cases where Y is observed only with M2 fail closed with a free direct path (rank deficient, `numerical` stage) and fit with the direct path fixed at 0; no silent wrong fit.

Benign observations (identical on `c8d90aa5`, not S2 regressions): a user label on `c_prime` and an intercept label `M1 ~ i*1` are accepted.

## Known unverified items

- No Hopper run; no OpenBLAS runner run; no platform matrix.
- No lavaan 0.6.x recheck (Q15): all lavaan oracles ran against the one installed lavaan.
- The all-gates run (`run-gates.R` without `--only`) is not clean (OVERALL FAIL, 13 of 35), identically on `origin/dev`
  `c8d90aa5`; this change does not touch those gates.
- The saturated variant and the chain with k >= 1 are refused; no numeric cell exists for the chain with covariates.
- The V14 parity run (60 of 60) has no sparse-mask cell.
- The full suite at the final tip is recorded in the evidence table.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
