## Summary

FI-G3 slice S4: serial FIML with TWO observed covariates (`Z1`, `Z2`), for both public serial variants, on top of the
merged S1a router, S1b saturated variant, S2 pure chain and S3 one-covariate forms. `fit_sem()` with `missing = "ml"`
now fits `M1 ~ X + Z1 + Z2`, `M2 ~ M1 + X + Z1 + Z2` (saturated) or `M2 ~ M1 + Z1 + Z2` (chain), `Y ~ ... + X + Z1 + Z2`,
with the three disturbance zeros written, the free covariance set of the three exogenous variables, and a written `Y`
path for every exogenous variable (free, or at most one fixed at exactly zero, which makes that variable the
treatment). The saturated variant has q 27 (26 with the direct path fixed) and the chain q 25 (24). Three or more
covariates stay refused (the parser limit `.sem_fiml_ser_cov_max()` is 2) with a classed `medfit_sem_fiml_error`.

- Admission and extraction (`R/fit-sem.R`, `R/sem-fiml-interface.R`, `R/aab-generics.R`): `k = 2` joins the admitted and
  extract-supported shapes for both variants; the paths are the treatment's coefficients (`a`, `a2`, `d1`, `b1`, `b`,
  `c_prime`; `a`, `d1`, `b`, `c_prime` for the chain) with the full covariance from the fitted information; the
  covariates' coefficients are never paths. Effects, per-effect origin rules and consumer refusals are those of the
  no-covariate and one-covariate forms.
- Two refusal messages improved: a partial exogenous covariance set at `k = 2` now names the missing pairs (it was the
  generic refusal); a saturated fit with a fixed-zero direct path on the wrong treatment now names the fixed-zero
  variable (it was the generic message).
- Covariate as treatment: allowed for the saturated variant with a free direct path; the pure chain still refuses a
  covariate named the treatment at extraction with `medfit_error_fiml_extract_unsupported` (its free covariate paths to
  `M2` and `Y` would be the one-shortcut graph that is not admitted).
- F6 reading documented: in the chain, a variable left out of the `M2` equation is the structural treatment; exactly one
  variable may be left out, and naming a covariate is refused (roxygen, native guide, models and methods articles).
- Fixtures: new `tests/testthat/fixtures/fiml-refusals-after-g3s4.rds` and `fiml-tables-after-g3s4.rds` (built by
  `make-fiml-after-g3s4.R`). Every earlier frozen fixture is untouched (the diff adds the two new files and no change to
  an earlier one). What changed, only in the new refusal fixture: four of the near-miss entries of the frozen model set
  no longer give the S3 answer: `ser_sat2_zeros`, `ser_chain2_zeros` and `ser_all_exo_cov_sat2` are now accepted fits
  (they were "not yet available"), and `ser_partial_exo_cov_sat2` is still a refusal, now with its own reason (names the
  missing pairs). `test-fiml-g3-baseline.R` lists them as `b4_changed` and excludes them from the earlier-fixture
  comparisons; they are pinned against the new fixture in `test-fiml-g3-serial-two-cov.R`.
- Gate `fiml-ext`: 14 structures (new `ser_sat2`, `ser_chain2`) x 2 seeds x 8 checks + 1 = 225 rows, free-direct policy
  only (the fixed-zero direct path at `k = 2` is covered in the unit tests, not in the gate), 40 refusal probes; four
  new planted defects (`ser_cov2_drop_gy`, `ser_cov2_wrong_offset`, `ser_cov_max_narrow`, `ser_k2_closed`; 21 registered
  before, 25 now).
- Docs: NEWS, roxygen (`fit_sem`, `extract_mediation`, man pages regenerated), native guide, models, methods, README and
  book scope sentences (serial models with three or more covariates stay refused).

No statistical admission, coverage or global-optimality claim is made. No push, release or CRAN step is part of this
change.

Not run: any check on the OpenBLAS gates runner, the platform matrix, statistical coverage, a Hopper run, the vignette
build in `R CMD check`, a lavaan 0.6.x recheck (Q15), a refresh of the other gates (see Evidence).

## Evidence (pre-PR testing, tree = branch tip)

Local machine: macOS aarch64, R 4.6.2. Tree: worktree `feature/fiml-serial-s4`, tip `0362e3c3`, above `origin/dev`
`8bae2e17`. Lint, check and gates were run on `git archive HEAD` copies with isolated libraries (`find.package("medfit")`
verified to point at the isolated library for lint).

| Check | Command | Result |
|---|---|---|
| Full suite, at the final tip | `NOT_CRAN=true Rscript -e 'r <- as.data.frame(devtools::test(reporter="silent", stop_on_failure=FALSE))'` | 199 files, 2196 tests, 18978 expectations, 0 failed, 0 errors, 2 skipped, 4 warnings (tip `0362e3c3`; later commits change only the gate registry, the gate script and docs; the 2 skips and 4 warnings were not examined) |
| Full suite, implementer | the same command | 2196 tests, 18978 expectations, 0 failed, 0 errors, 2 skipped, 4 warnings (implementer-run; the names of the 2 skips and 4 warnings were not recorded in the logs, so they are not examined) |
| Lint | isolated source install of `git archive HEAD`, `R_LIBS=<lib> Rscript -e 'lintr::lint_package()'` with the repo `.lintr` | 0 findings at `0362e3c3` |
| R CMD check | `R CMD build --no-manual --no-build-vignettes`, then `_R_CHECK_FORCE_SUGGESTS_=false NOT_CRAN=false R CMD check --as-cran --no-manual --ignore-vignettes --no-tests` | Status: 1 NOTE (CRAN incoming feasibility: "Version jumps in minor (submitted: 0.16.0, existing: 0.3.2)"); 0 WARNING, 0 ERROR. Same NOTE as `dev`. Rd files, Rd metadata, Rd line widths, Rd cross-references, missing documentation entries, code/documentation mismatches, `\usage`, Rd contents, examples and `--run-donttest` examples all OK; tests skipped by option |
| Gate verdicts | `NOT_CRAN=true Rscript tests/sim/run-gates.R --sim --only fiml,fiml-ext` | `fiml` PASS; `fiml-ext` PASS (225 rows of 225, fourteen structures x two seeds x eight checks plus the refusal count, `unadmitted_accepted` = 0; the re-run CSV agrees with the committed one in every cell and pass flag); OVERALL PASS, 12 of 12 driver checks |
| Gate planted defects | `MUTANT=<name> Rscript tests/sim/sem-fiml-ext-gate.R` for all 24 registered names (after retiring `serial_admitted`, see below) | all 24 stop with a failing gate or a crash (exit 1), measured at `0362e3c3` before the retirement. Failed rows: `wrong_unit` (44: 22 covariance, 22 estimates), `no_offset` (28 estimates), `swap_b` (23: 12 `nie_estimate`, 11 `nie_se`), `dropped_cov` (12 `nie_se`), `missing_guard` (28 guard), `ser_swap_db` (24), `ser_drop_cross` (12 `nie_se`), `ser_total_gradient` (6 `nie_se`), `ser_chain_free_shortcut` (30), `ser_chain_swap_db` (24), `ser_chain_origin` (12 `nie_se`), `ser_chain_te_gradient` (12 `nie_se`), `ser_cov_alias` (16: `nie_estimate`, `nie_se`), `ser_cov_wrong_offset` (20: covariance, estimates), `ser_cov2_wrong_offset` (20: covariance, estimates), `ser_chain_cov_treatment` (`unadmitted_accepted` = 1, limit 0). Caught by a structural crash instead of a numeric gap (fail-closed, 0 numeric rows): `parcov_drop_path` and `parcov_orthogonal` (`subscript out of bounds`), `serial_router_off` (`unsupported FIML topology or correlated disturbances`), `ser_drop_shortcut`, `ser_cov_drop_y` and `ser_cov2_drop_gy` (`length(labels) == conv$ram$q is not TRUE`), `ser_cov_max_narrow` (`unsupported number of FIML covariates`), `ser_k2_closed` (the "not yet available" refusal) |
| Retired equivalent mutant | `MUTANT=serial_admitted Rscript tests/sim/sem-fiml-ext-gate.R` at `0362e3c3` | exit 0, 225 of 225 rows pass. After S4 every serial shape that is valid but not public is refused by another check (the parser limit for three covariates, the partial-covariance and wrong-treatment reasons), so flipping the master switch `.fiml_serial_admitted()` changes no probe: the mutant is equivalent here (it was caught at S3, `unadmitted_accepted` = 2). Retired from `tests/sim/gates.csv` and `tests/sim/sem-fiml-ext-gate.R` in `cfb6c52f`; `test-gate-coverage.R` passes after the change |
| Driver mutants | `NOT_CRAN=true Rscript tests/sim/run-gates.R --mutants --only fiml,fiml-ext` | every mutation rejected, every control passes (exit 0) |
| Parity (V14) | the implementer's parity run against `origin/dev` | 114 of 114 cells identical (implementer-run) |
| Other gates | `Rscript tests/sim/run-gates.R` (all gates) | not refreshed here: the all-gates run reports OVERALL FAIL, 13 of 35 checks, identical on `origin/dev` (stale results of other gates, unrelated to FIML); no waiver is sought for them in this PR |

Gate rows are two fixed seeds per structure, not a coverage study. The committed gate CSV
(`tests/sim/results/sem-fiml-ext-gate-2026-11-09.csv`) is the implementer's run (225 rows); the gate pass above re-ran
the gate on the tip copy and agrees with it.

## Admission checklist

- [x] 1. independent oracle: serial FIML with two covariates (both variants, free and fixed direct path) against lavaan
  raw-data FIML (estimates, covariance, logLik, `:=` effects, the relabeled covariate treatment), equation-wise OLS
  (`lm`), the multivariate-normal identity, the restriction LR against the saturated fit, a rowwise Hessian for the
  observed information, and OpenMx on one cell per variant, in `tests/testthat/test-fiml-g3-serial-two-cov.R`
  (oracles implementer-run); the gate's `ser_sat2` and `ser_chain2` cells compare the chain NIE, total indirect effect,
  total effect and every extracted path to lavaan `:=` and labeled values. Independent QA: see the Independent QA
  section below.
- [x] 2. reliability cell: `fiml-ext` gate, 14 structures (new `ser_sat2`, `ser_chain2`) x 2 seeds x 8 checks plus the
  refusal count, 225 rows, all pass, re-run on the tip copy above. A small fixed-seed cell, not a coverage or
  large-replication study; free-direct policy only
- [x] 3. planted defect: gate defects `ser_cov2_drop_gy`, `ser_cov2_wrong_offset`, `ser_cov_max_narrow` and
  `ser_k2_closed`, with the earlier ones, all 24 registered names caught (see the evidence table); the equivalent mutant `serial_admitted` was
  retired (`cfb6c52f`); the test suite plants, each with a positive control first, in
  `tests/testthat/test-fiml-g3-serial-two-cov-defects.R` and the updated defect files of the earlier slices
- [x] 4. metamorphic invariance: the chain NIE and `te` are invariant to a consistent `d1`/`b` relabeling, so the gate
  also checks every extracted path against lavaan; a covariate named the treatment (saturated) is checked against the
  relabeled lavaan fit; frozen fixtures (`fiml-refusals-after-g3s4.rds`, `fiml-tables-after-g3s4.rds`, built by
  `make-fiml-after-g3s4.R`) pin the refusals and the k = 2 tables with `identical()` while every earlier fixture stays
  untouched; V14 parity with `origin/dev` (114 of 114 identical, implementer-run)
- [x] 5. fault injection: three covariates, a partial exogenous covariance set, a fixed-zero direct path on the wrong
  treatment (saturated), a covariate-as-treatment chain, a reversed mediator order and a labeled (tied) exogenous
  covariance are refused with classed reasons; the validator rejects forgeries with a covariate dropped, on some
  equations only, or with the wrong treatment; the source-fit and consumer refusals are unchanged; refusal probes in the
  gate (40, among them the serial Q2, shortcut, covariate-rule, not-yet-public, reversed-order, chain
  covariate-treatment, k = 3, partial exogenous covariance, fixed-zero other-treatment and never-jointly-observed
  probes) must admit 0. Not covered: refit-failure injection (no serial bootstrap exists)
- [x] 6. registration: `tests/sim/gates.csv` row `fiml-ext` (225 rows, `oracle` = lavaan raw-data FIML, 24 registered
  `mutants` plus `driver`, among them the new `ser_cov2_drop_gy`, `ser_cov2_wrong_offset`, `ser_cov_max_narrow` and
  `ser_k2_closed`); `tests/sim/structures.csv` has two new rows (serial saturated and pure chain with two covariates)
  that name `fiml-ext` (gate cells `ser_sat2`, `ser_chain2`); `R/fit-sem.R` and `R/sem-fiml-interface.R` are in
  `tests/sim/risk-files.txt`
- [ ] 7. n/a: the OpenBLAS gates runner runs only on PRs to `main` and this PR targets `dev`, so no OpenBLAS run exists
  (not run); `fiml-ext` joins the `gates (rest)` shard on the release PR, and dev is gated locally (suite, lint,
  `R CMD check` above)

## Independent QA

PASS (independent run, own code, installs of `git archive` of tip `0362e3c3` and dev `8bae2e17`; later commits touch only docs, the PR body, `gates.csv` and the gate script). lavaan raw-data FIML: 16 cells (2 variants x free/fixed direct x MCAR30, MAR, sparse, covariate-only missing; n = 500; large distinct covariate effects): estimates <= 3.2e-7, vcov <= 4e-7, logLik <= 2e-10, effects <= 2.4e-7, delta SEs <= 1.2e-8; OpenMx 4 cells: estimates <= 9e-7, logLik <= 1e-9 (OpenMx numerical-Hessian vcov agrees only to ~1e-4: OpenMx precision). Complete-data OLS, saturation identity and chain-vs-saturated LR agree (theta 4e-8, logLik 1e-11, LR exact vs `lavTestLRT`). Treatment cases (X, Z1, Z2 each as saturated treatment; fixed-zero path on each; chain structural; chain covariate-as-treatment refused for every covariate) match lavaan; a wrong treatment names the fixed-zero variable. Hand delta SEs equal `tidy()` to 2e-16; origin rule on 40 forged-zero patterns exact. 50 validator forgeries rejected. Planted defects (own battery, clean control 25/25): all behavior-changing mutants caught; two equivalent redundant-guard mutants noted. V14 parity vs dev identical in 68 of 68 cells. Robustness: 11 of 12 grid cells match lavaan, the rest fail closed; never-jointly-observed pairs at k = 2: saturated refuses, chain fits except X/M1, matching lavaan where fitted. Low-severity observation: `ctx$covariate` is not hash-covered, so a consistent drop of a covariate from ctx and all predictor lists would pass the validator (detecting it needs the fit).

## Known unverified items

- No Hopper run; no OpenBLAS runner run; no platform matrix.
- No lavaan 0.6.x recheck (Q15): all lavaan oracles ran against the one installed lavaan.
- The all-gates run (`run-gates.R` without `--only`) is not clean (OVERALL FAIL, 13 of 35), identically on
  `origin/dev`; this change does not touch those gates.
- The V14 parity run (114 of 114) and the implementer's full-suite run are implementer-run; the full suite at the final
  tip is recorded in the evidence table. The implementer's 2 skips and 4 warnings were not examined.
- The fixed-zero direct path at `k = 2` is tested in the unit tests only, not in the gate.
- The master-switch mutant `serial_admitted` was retired as equivalent after S4; the mutant runs were measured before the retirement commit (`cfb6c52f` changes only the registry and the gate script).
- Three or more covariates and the remaining serial shapes stay refused.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
