## Summary

Bounded Gaussian FIML (random X, `missing = "fiml"`, `fixed_x = FALSE`) grows from the three-variable X -> M -> Y model to:

- **FI-G0**: a dimension-generic kernel. The RAM-table parameter layout, variance indices, bounds, starts and solver
  units are derived from a table, not hard-coded for three variables. Spec:
  `planning/specs/SPEC-fiml-generic-kernel-2026-11-08.md`.
- **FI-G1**: one or two observed covariates (`M ~ X + Z...`, `Y ~ M + X + Z...`, free exogenous covariances).
- **FI-G2 slices 1-2**: two parallel mediators, with independent disturbances (`M1 ~~ 0*M2`) or a free M1-M2 residual
  covariance (`M1 ~~ M2`). Extraction returns `FIMLParallelMediationData`; the NIE sum carries the cross-path blocks.

Everything else stays refused with the classed `medfit_sem_fiml_error` (three or more covariates, serial, covariate on
M only, omitted Y path, tied/fixed/labeled paths, constraints, products, weights, sandwich, expected information).
Source-fit bootstrap stays behind the stage-0 guard and is refused for covariate and parallel fits. No statistical
admission, coverage or global-optimality claim is made; these are validated protocols only. No push, release or CRAN
step is part of this change.

Not run: any check on the OpenBLAS gates runner, the platform matrix, statistical coverage of the new fits, and the
vignette build in `R CMD check` (quarto toolchain not used locally).

## Evidence (pre-PR testing, tree = branch tip)

Local machine: macOS aarch64, R 4.6.2. Tree: worktree `feature/fiml-g1-covariates`; suite run at `20555358`.

| Check | Command | Result |
|---|---|---|
| Full suite | `NOT_CRAN=true Rscript -e 'r <- as.data.frame(devtools::test(reporter="silent", stop_on_failure=FALSE))'` | 187 files, 1967 test blocks, 12388 expectations, 0 failed, 0 errors, 2 skipped, 4 warnings (re-run at the final tip eaee39e5, after the exact-origin fix) |
| Skips | same run | `test-extract-lavaan.R` (needs lavaan absent) and `test-restore-docs.R` (help-page check): each skips 1 test; both also skip 1 on `origin/dev` `ba50f998` |
| Lint | install source into an isolated library, then `R_LIBS=<lib> Rscript -e 'lintr::lint_package()'` (verified `find.package("medfit")` is the isolated lib) | 0 findings. `origin/dev` measured the same way: 0 findings |
| R CMD check | `R CMD build --no-manual --no-build-vignettes` then `_R_CHECK_FORCE_SUGGESTS_=false NOT_CRAN=false R CMD check --no-manual --ignore-vignettes --no-tests --as-cran` (the `scripts/check-local.sh` options, plus `--as-cran`) | Status: 1 NOTE (CRAN incoming feasibility: "Version jumps in minor (submitted: 0.16.0, existing: 0.3.2)"); 0 WARNING, 0 ERROR. The version is unchanged from `dev` (0.16.0), so the NOTE is not from this branch. Built at `18bb05a9`; later commits touch only `tests/sim` and `planning/` |
| Gate coverage | `test-gate-coverage.R`, `test-experimental-criteria.R`, `test-sim-pinned.R` | pass (a first full-suite run failed these 3 expectations because the new gate was not yet named in the exit criteria and its `fit_sem()` calls did not state `meanstructure`; both fixed in `20555358`, then the full suite above was re-run) |
| New gate | `Rscript tests/sim/sem-fiml-ext-gate.R`, then `Rscript tests/sim/run-gates.R --only fiml,fiml-ext` | 65 rows, 65 pass; driver verdict PASS (10 of 10 checks); `run-gates.R --mutants --only fiml-ext`: every mutation rejected, control passes |
| Planted defects in the gate | `MUTANT=<name> Rscript tests/sim/sem-fiml-ext-gate.R` | each of 5 defects fails the gate (see item 3) |

Largest recorded gate discrepancy against lavaan: estimates 7.4e-8 (limit 1e-5), covariance 2.6e-7 (1e-3), logLik 9.1e-13
(1e-6), NIE estimate 3.7e-8 (1e-5), NIE delta SE relative 2.8e-8 (2e-3).

### R2 parity proof (FI-G0 changes no stage-0 number)

`_agents_workspace/parity-g0.md`. The feature tip (`bb0f4584`, 23 commits above the pinned source) was compared with the
pinned stage-0 source `ba50f998`, each installed into its own library. Scope: X -> M -> Y, no covariates, bounded
Gaussian random-X FIML, stage-0 cell shapes.

- 72 datasets (30 n=200 shapes x 2 seeds, plus n=500 cells), stage-0 generator and seeds. Fit object (theta, vcov,
  logLik, diagnostics including ledger, attempts, spread), `coef`, `vcov`, `tidy`, `glance`, `extract_mediation`, and
  every bootstrap result (432 results, B=40 nonparametric, 2000 parametric draws): `identical()` TRUE for 72 of 72; max
  absolute difference 0 over 1,587,456 numeric values (timing fields excluded).
- 21 edge fits (small n, 60% missing, scales 1e-4 and 1e4, all-M-missing, constant X, empty rows, complete data,
  a = b = 0): identical; a 1e-13 plant is detected. 7 refusal paths: same classes. Injected refit failures (B=60):
  identical statuses and counts.
- Only observed difference: a model with an extra variable on the Y equation only now fails with "unsupported FIML
  topology or correlated disturbances" instead of "FIML requires exactly three observed variables". Both refuse.
- Caveats: reduced B (not the stage-0 study's B), local BLAS (not Hopper), parity measured at `bb0f4584` (slice-2
  residual-covariance work and later commits are outside this sample; the golden fixture tests pin the three-variable
  tables at every later commit).

### R4 refusal evidence

- FI-G1 QA (`qa-g1/REPORT.md` in the session scratchpad): 49 unadmitted topologies and policies, 49 of 49 refused with
  `medfit_sem_fiml_error` (0 accepted); consumer seam with the guard on and mocked open; 10 tampered fits (model string
  replaced and ledger binding recomputed) refused at extract and at both bootstrap methods; extraction refusals.
- FI-G2 QA (`_agents_workspace/qa-g2-parallel.md`): omitted/labeled/fixed/tied/duplicate covariance, covariate, serial,
  three mediators, constraints on the covariance, `fixed_x = TRUE` all refused; source-fit refusal behind and ahead of
  the guard.
- `tests/sim/sem-fiml-ext-gate.R` re-checks seven refusal probes on every gate run (check `unadmitted_accepted`, exact 0).

## Admission checklist

- [x] 1. independent oracle: lavaan raw-data FIML with observed information (the gate and tests: estimates 1e-5, covariance 1e-3, logLik 1e-6, `:=` indirect effects and their SEs), OpenMx raw FIML (FI-G1: 12 cells, max coef gap 1.0e-6; FI-G2: 3 cells, est 2.1e-7, vcov rel 8.3e-5), from-scratch row-wise Gaussian likelihood (9e-13), complete-data OLS (paths 1.1e-8; slice-2 residual covariance 1.7e-9) and an independent EM plus zero-gradient and positive-definite-Hessian check; QA reports `qa-g1/REPORT.md` (90 lavaan cells, max coef gap 4.8e-6, logLik 1.0e-9) and `_agents_workspace/qa-g2-parallel.md` (12 lavaan cells, paths 2.4e-6, logLik 4.7e-9)
- [x] 2. reliability cell: `fiml-ext` gate, 4 structures (one covariate, two covariates, two parallel mediators independent and free covariance) x 2 seeds, MAR missingness plus an all-empty row, 8 checks each plus the refusal count (65 rows, all pass); a small fixed-seed cell, not a coverage or large-replication study
- [x] 3. planted defect: gate defects `wrong_unit`, `no_offset`, `swap_b`, `dropped_cov`, `missing_guard` (each fails the gate; positive control passes on the unmutated tree); test-suite plants for dropped Z -> Y path, dropped X-Z covariance, untransported covariance, dropped M2 -> Y path, wrong wiring, swap, dropped or mis-scaled M1-M2 covariance transport (`test-fiml-g1-*.R`, `test-fiml-g2-*.R`, `test-fiml-generic-kernel-*.R`); QA mutants 4 of 5 (G1) and 9 of 9 (G2) caught, the G1 survivor is behaviorally equivalent (second refusal layer, message changes only)
- [x] 4. metamorphic invariance: affine rescaling shifts FIML values by exactly the log-Jacobian (`test-fiml-generic-kernel-oracle.R`); labels, explicit versus automatic covariances and variable order give the same fit (`test-fiml-g1-covariate.R`); statement order and swapped mediator request give the same fit and sum (`test-fiml-g2-residual-covariance.R`); QA column order, extra column and equation order permutations (coef gap 4e-11, logLik gap 0); the 3-variable model is bit-identical to pinned `ba50f998` (R2 above)
- [x] 5. fault injection: unidentified and sparse missing patterns are refused numerically with the attempt ledger (`test-fiml-g1-covariate.R`); near-boundary residual correlation is fail-closed (a classed error, never a silent boundary solution; QA G2 note B); tampered fits refused (QA G1: 10 of 10); injected refit failures give identical statuses and counts versus pinned `ba50f998` (R2). Not covered: refit-failure injection for covariate and parallel fits (their source-fit bootstrap is refused)
- [x] 6. registration: `tests/sim/gates.csv` row `fiml-ext` (`oracle` = lavaan raw-data FIML, `mutants` = `wrong_unit|no_offset|swap_b|dropped_cov|missing_guard|driver`); `tests/sim/structures.csv` rows "bounded random-X FIML with covariates" and "bounded random-X FIML with parallel mediators"; `run-gates.R` verdict, script map and driver self-test cases; `test-gate-coverage.R` passes; `R/sem-fiml.R` and `R/sem-fiml-interface.R` added to `tests/sim/risk-files.txt`; exit-criteria CSV names `fiml-ext`
- [ ] 7. n/a: the OpenBLAS gates runner runs only on PRs to `main` and this PR targets `dev`, so no OpenBLAS run exists (not run); `fiml` and `fiml-ext` join the `gates (rest)` shard on the release PR, and dev is gated locally (suite, lint, `R CMD check` above)

## Known open edge (fixed in `25dd504c`)

At an exact origin (all a and b paths equal to 0), `tidy()`/`confint(parm = "effects")` previously withheld the NIE
interval for the single-mediator FIML object only; the parallel FIML object reported `std_error = 0` and the degenerate
interval [0, 0], because `.sem_fiml_origin()` tested only `MediationData` (and the parallel `confint()` did not consult
it). The predicate now covers `FIMLParallelMediationData` (all a and b paths exactly 0) and the parallel `confint()`
applies it, so both classes give NA plus the note "NIE inference unavailable: zero delta gradient"; partly zero parallel
objects keep finite SEs (`test-fiml-g2-origin.R`). A real fit never reaches exactly 0, and the public constructors refuse
a forged zero object because the context hash binds the parameters; the test rebuilds that hash to reach the origin.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
