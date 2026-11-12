## Summary

FI-G3 slice S3: serial FIML with ONE observed covariate `Z`, for both public serial variants, on top of the merged S1a
router, S1b saturated variant and S2 pure chain. `fit_sem()` with `missing = "ml"` now fits `M1 ~ X + Z`,
`M2 ~ M1 + X + Z` (saturated) or `M2 ~ M1 + Z` (chain), `Y ~ ... + X + Z`, with the three disturbance zeros written, a
free covariance of `X` and `Z`, and a written `Y` path for every exogenous variable (free, or at most one fixed at
exactly zero, which makes that variable the treatment). The saturated variant has q 20 (19 with the direct path fixed)
and the chain q 18 (17); two or more covariates, and k = 2 syntax, stay refused with a classed `medfit_sem_fiml_error`
until S4.

- Extraction through `extract_mediation()` and `fit_sem()` (`R/fit-sem.R`, `R/sem-fiml-interface.R`,
  `R/aab-generics.R`): the paths are the treatment's coefficients (`a`, `a2`, `d1`, `b1`, `b`, `c_prime`; `a`, `d1`, `b`,
  `c_prime` for the chain) with the full covariance from the fitted information; the covariate's coefficients are never
  paths and the covariate is recorded in `fit_context`. Effects, per-effect origin rules and consumer refusals are those
  of the no-covariate forms.
- Covariate as treatment (Q6a): allowed for the saturated variant with a free direct path; refused for the chain at
  extraction with `medfit_error_fiml_extract_unsupported` (its free Z to M2 and Z to Y paths would be the one-shortcut
  graph that is not admitted).
- Deviation F6 (reviewer note): `M2 ~ M1 + X` with `Z` omitted from the `M2` equation is accepted at fit as a chain
  whose structural treatment is `Z` (the S1a router already admits the identical structure under other variable names);
  Q6a is enforced at extraction, where naming `X` the treatment is refused.
- Fixtures: new `tests/testthat/fixtures/fiml-refusals-after-g3s3.rds` and `fiml-tables-after-g3s3.rds` (built by
  `make-fiml-after-g3s3.R`); every earlier frozen fixture is untouched.
- Gate `fiml-ext`: 12 structures (new `ser_sat1` and `ser_chain1`) x 2 seeds x 8 checks + 1 = 193 rows, 30 refusal
  probes; four new covariate planted defects (`ser_cov_alias`, `ser_cov_drop_y`, `ser_cov_wrong_offset`,
  `ser_chain_cov_treatment`).
- Docs: NEWS (the S2 sentence that said serial models with covariates stay refused is corrected), roxygen (`fit_sem`,
  `extract_mediation`, man pages regenerated), native guide, models, methods, README and book scope sentences.

No statistical admission, coverage or global-optimality claim is made. No push, release or CRAN step is part of this
change.

Not run: any check on the OpenBLAS gates runner, the platform matrix, statistical coverage, a Hopper run, the vignette
build in `R CMD check`, a lavaan 0.6.x recheck (Q15), a refresh of the other gates (see Evidence).

## Evidence (pre-PR testing, tree = branch tip)

Local machine: macOS aarch64, R 4.6.2. Tree: worktree `feature/fiml-serial-s3`, tip `403f41bb`, 7 commits above
`origin/dev` `15d946b1`. Lint, check and gates were run on `git archive HEAD` copies with isolated libraries
(`find.package("medfit")` verified to point at the isolated library for lint).

| Check | Command | Result |
|---|---|---|
| Full suite, at the final tip | `NOT_CRAN=true Rscript -e 'r <- as.data.frame(devtools::test(reporter="silent", stop_on_failure=FALSE))'` | 197 files, 2161 tests, 18001 expectations, 0 failed, 0 errors, 2 skipped (tip `403f41bb`) |
| Full suite, implementer, before the last two test-only commits | the same command | 2161 tests, 17976 expectations, 0 failed, 1 error (in the implementer's own new test, fixed and the file re-run alone); the last two commits (`e20a142e` exact-origin rules for k = 1 objects, `403f41bb` the serial total-indirect note defined in the covariate test file) are test-only and came after this run |
| Lint | isolated source install of `git archive HEAD`, `R_LIBS=<lib> Rscript -e 'lintr::lint_package()'` with the repo `.lintr` | 0 findings at `403f41bb` (includes the two line-length fixes in `test-fiml-g3-serial-covariate.R` the implementer did not re-lint) |
| R CMD check | `R CMD build --no-manual --no-build-vignettes`, then `_R_CHECK_FORCE_SUGGESTS_=false NOT_CRAN=false R CMD check --as-cran --no-manual --ignore-vignettes --no-tests` | Status: 1 NOTE (CRAN incoming feasibility: "Version jumps in minor (submitted: 0.16.0, existing: 0.3.2)"); 0 WARNING, 0 ERROR. Same NOTE as `dev`. Rd files, Rd metadata, Rd line widths, Rd cross-references, missing documentation entries, code/documentation mismatches, `\usage`, Rd contents, examples and `--run-donttest` examples all OK; tests skipped by option |
| Gate verdicts | `NOT_CRAN=true Rscript tests/sim/run-gates.R --sim --only fiml,fiml-ext` | `fiml` PASS (24 rows of 24); `fiml-ext` PASS (193 rows of 193, twelve structures x two seeds x eight checks plus the refusal count, `unadmitted_accepted` = 0); OVERALL PASS, 12 of 12 driver checks |
| Gate planted defects | `MUTANT=<name> Rscript tests/sim/sem-fiml-ext-gate.R` for all 21 registered names | all 21 stop with a failing gate (exit 1). Failed rows: `wrong_unit` (36: 18 covariance, 18 estimates), `no_offset` (24 estimates), `swap_b` (23: `nie_estimate`, `nie_se`), `dropped_cov` (12 `nie_se`), `missing_guard` (24 guard), `ser_swap_db` (16), `ser_drop_cross` (8 `nie_se`), `ser_total_gradient` (4 `nie_se`), `ser_chain_free_shortcut` (20: covariance, estimates, likelihood, `nie_estimate`, `nie_se`), `ser_chain_swap_db` (16), `ser_chain_origin` (8 `nie_se`), `ser_chain_te_gradient` (8 `nie_se`), `ser_cov_alias` (8: `nie_estimate`, `nie_se`), `ser_cov_wrong_offset` (20: covariance, estimates); `serial_admitted` makes `unadmitted_accepted` = 2 and `ser_chain_cov_treatment` = 1 (limit 0). Caught by a structural crash instead of a numeric gap (fail-closed): `parcov_drop_path` and `parcov_orthogonal` (`subscript out of bounds`), `serial_router_off` (`unsupported FIML topology or correlated disturbances`), `ser_drop_shortcut` and `ser_cov_drop_y` (`length(labels) == conv$ram$q is not TRUE`) |
| Driver mutants | `NOT_CRAN=true Rscript tests/sim/run-gates.R --mutants --only fiml,fiml-ext` | every mutation rejected, every control passes (exit 0) |
| Parity (V14) | the implementer's parity run against `origin/dev` | 128 of 128 cells identical (implementer-run) |
| Other gates | `Rscript tests/sim/run-gates.R` (all gates) | not refreshed here: the all-gates run reports OVERALL FAIL, 13 of 35 checks, identical on `origin/dev` (stale results of other gates, unrelated to FIML); no waiver is sought for them in this PR |

Gate rows are two fixed seeds per structure, not a coverage study. The committed gate CSV
(`tests/sim/results/sem-fiml-ext-gate-2026-11-09.csv`) is the implementer's run (193 rows); the gate pass above re-ran
the gate on the tip copy and passed.

## Admission checklist

- [x] 1. independent oracle: serial FIML with one covariate (both variants, free and fixed direct path) against lavaan
  raw-data FIML (estimates, covariance, logLik, `:=` effects, the relabeled covariate treatment), equation-wise OLS
  (`lm`), the multivariate-normal identity, the restriction LR against the saturated fit, a rowwise Hessian for the
  observed information, and OpenMx on one cell per variant, in `tests/testthat/test-fiml-g3-serial-covariate.R`
  (oracles implementer-run); the gate's `ser_sat1` and `ser_chain1` cells compare the chain NIE, total indirect effect,
  total effect and every extracted path to lavaan `:=` and labeled values. Independent QA: see the Independent QA
  section below.
- [x] 2. reliability cell: `fiml-ext` gate, 12 structures (new `ser_sat1`, `ser_chain1`) x 2 seeds x 8 checks plus the
  refusal count, 193 rows, all pass, re-run on the tip copy above. A small fixed-seed cell, not a coverage or
  large-replication study
- [x] 3. planted defect: four new gate defects `ser_cov_alias` (`a` read from the covariate's `M1` coefficient), `ser_cov_drop_y`
  (covariate dropped from the outcome equation of the tables), `ser_cov_wrong_offset` (covariate centering not carried
  into the intercepts) and
  `ser_chain_cov_treatment` (chain accepting a covariate treatment), plus the seventeen earlier ones, all caught (see the
  evidence table); the test suite plants, each with a positive control first, in
  `tests/testthat/test-fiml-g3-serial-covariate-defects.R`: covariate dropped per equation (M1, M2, Y) and the exogenous
  covariance dropped, covariate aliased as `a`/`a2`/`b1`/`c_prime`, wrong treatment mapping, chain accepting a
  covariate treatment, extraction defects (swapped paths, dropped covariance blocks and predictors), fit-level defects
  (wrong covariance unit, dropped offset, dropped exogenous block), effect defects (`a/a2` and `d1/b` swaps, total
  indirect gradient, `te` without `c_prime`, cross block), a six-alias vector on the chain, and admission predicates
  ignoring the covariate count
- [x] 4. metamorphic invariance: the chain NIE and `te` are invariant to a consistent `d1`/`b` relabeling, so the gate
  also checks every extracted path against lavaan; a covariate named the treatment (saturated) is checked against the
  relabeled lavaan fit; frozen fixtures (`fiml-refusals-after-g3s3.rds`, `fiml-tables-after-g3s3.rds`, built by
  `make-fiml-after-g3s3.R`) pin the unchanged refusals and the k = 1 tables with `identical()` while every earlier
  fixture stays untouched; V14 parity with `origin/dev` on non-serial and no-covariate serial fits (128 of 128
  identical, implementer-run)
- [x] 5. fault injection: k = 2 serial syntax, every other k = 1 serial syntax in the test suite's refusal set (classed
  `medfit_sem_fiml_error`, stage `input`), a labeled (tied) exogenous covariance and a covariate-as-treatment chain are
  refused with classed reasons; the validator rejects forgeries with a
  covariate dropped, on some equations only, or with the wrong treatment, and a six-alias vector on the chain; the
  source-fit and consumer refusals are unchanged for the k = 1 objects; refusal probes in the gate (30, among them the
  serial Q2, shortcut, covariate-rule, not-yet-public, reversed-order, chain covariate-treatment and never-jointly-observed
  probes) must admit 0. Not covered: refit-failure injection (no serial bootstrap exists)
- [x] 6. registration: `tests/sim/gates.csv` row `fiml-ext` (193 rows, `oracle` = lavaan raw-data FIML, `mutants` =
  `wrong_unit|no_offset|swap_b|dropped_cov|missing_guard|parcov_drop_path|parcov_orthogonal|serial_admitted|serial_router_off|ser_swap_db|ser_drop_cross|ser_total_gradient|ser_drop_shortcut|ser_chain_free_shortcut|ser_chain_swap_db|ser_chain_origin|ser_chain_te_gradient|ser_cov_alias|ser_cov_drop_y|ser_cov_wrong_offset|ser_chain_cov_treatment|driver`);
  `tests/sim/structures.csv` rows "bounded random-X FIML with serial mediators and one covariate" and "bounded random-X
  FIML with the pure chain of serial mediators and one covariate" name `fiml-ext` (gate cells `ser_sat1`, `ser_chain1`);
  `R/fit-sem.R` and `R/sem-fiml-interface.R` are in `tests/sim/risk-files.txt`
- [ ] 7. n/a: the OpenBLAS gates runner runs only on PRs to `main` and this PR targets `dev`, so no OpenBLAS run exists
  (not run); `fiml-ext` joins the `gates (rest)` shard on the release PR, and dev is gated locally (suite, lint,
  `R CMD check` above)

## Independent QA

`medfit-oracle-qa`: PASS (independent run, own code, installs of `git archive` of the tip and of dev `15d946b1`). lavaan raw-data FIML and OpenMx: 20 cells (2 variants x free/fixed direct x MCAR, MAR, sparse, covariate-only missing, all-missing mediator pairs), theta <= 2.8e-6, vcov <= 9.7e-8, logLik <= 1.6e-9, delta SEs <= 7.3e-7; complete-data OLS, MVN saturation identity and chain-vs-saturated LR agree (<= 2e-8); hand delta SEs equal `tidy()` to 1.4e-17; origin rule 40 forged-zero cells, 0 mismatches; 15 own planted defects all caught with a clean control (34/34); V14 two-install parity identical in 40 of 40 cells; robustness grid fits match lavaan or fail closed. F6 deviation (`M2 ~ M1 + X` with Z omitted fits as a chain with structural treatment Z, naming X refused): accepted as a documented design limitation, not a defect (agrees with lavaan on relabeled data to 1e-7). Non-blocking findings: (1) the extraction refusal for a wrong treatment with a fixed-zero Y path in the saturated variant uses the generic message; (2) at k = 2 a partial exogenous covariance gets the generic refusal (k = 2 is not admitted here); (3) chain at k = 1 with a never-jointly-observed (X,M1) or (M2,Y) pair is refused ("no accepted candidate") although lavaan finds an identified optimum: fail-closed coverage limit; the saturated variant refuses all never-jointly-observed pairs, correctly (unidentified).

## Known unverified items

- No Hopper run; no OpenBLAS runner run; no platform matrix.
- No lavaan 0.6.x recheck (Q15): all lavaan oracles ran against the one installed lavaan.
- The all-gates run (`run-gates.R` without `--only`) is not clean (OVERALL FAIL, 13 of 35), identically on
  `origin/dev`; this change does not touch those gates.
- Never-jointly-observed variable pairs at k = 1 were not tested by the implementer (independent QA covers them, see
  above).
- The V14 parity run (128 of 128) and the implementer's full-suite run are implementer-run; the full suite at the final
  tip is recorded in the evidence table.
- Two or more covariates, k = 2 and the remaining serial shapes stay refused (S4).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
