## Summary

Bounded Gaussian FIML (random X, `missing = "fiml"`, `fixed_x = FALSE`) grows to two parallel mediators with one or two
observed covariates (FI-G2 slices 3 and 4, on top of the merged FI-G0 to FI-G2 slice 2 work in #383):

- Models: `M1 ~ X + Z...`, `M2 ~ X + Z...`, `Y ~ M1 + M2 + X + Z...`, free exogenous covariance, both residual forms
  (`M1 ~~ 0*M2` written, or the free, label-less `M1 ~~ M2`), each with the direct path free or fixed exactly at zero.
  Four new variants (one or two covariates x two residual forms), eight policy cells with the direct-path choice.
- Extraction returns `FIMLParallelMediationData` with the full covariance of `a1`, `a2`, `b1`, `b2` and `c_prime`;
  covariate coefficients stay in the fitted covariance, not among the paths. No class change.
- `tests/sim/sem-fiml-ext-gate.R` grows to 8 structures (129 rows) and two new planted defects (`parcov_drop_path`,
  `parcov_orthogonal`).

Decisions:

- Covariates enter every equation (both mediator equations and the outcome equation).
- An omitted `Y ~ X` (any exogenous variable without a written `Y` path) is refused when covariates are present.
- Treatment rule: with no `Y` path fixed at zero, `extract_mediation()` may name any exogenous variable as the treatment;
  a `Y` path fixed at zero makes that variable the treatment.
- No class change: the existing parallel FIML class carries the covariate fits.

Everything else stays refused with the classed `medfit_sem_fiml_error` (three or more covariates, three or more
mediators, serial with covariates, covariate on the mediators only, omitted `Y` path, partial exogenous covariance set,
tied/fixed/labeled paths, constraints, products, weights, sandwich, expected information). Source-fit bootstrap stays
behind the stage-0 guard and is refused for covariate parallel fits (`medfit_error_fiml_covariate_source_fit` once the
guard is open). No statistical admission, coverage or global-optimality claim is made; these are validated protocols
only. No push, release or CRAN step is part of this change.

Not run: any check on the OpenBLAS gates runner, the platform matrix, statistical coverage of the new fits, a Hopper
run, and the vignette build in `R CMD check` (quarto toolchain not used locally).

## Evidence (pre-PR testing, tree = branch tip)

Local machine: macOS aarch64, R 4.6.2. Tree: worktree `feature/fiml-g2-covariates`, tip `5623420d`, 6 commits above
`origin/dev` `64c17b2e`.

| Check | Command | Result |
|---|---|---|
| Full suite | `NOT_CRAN=true Rscript -e 'r <- as.data.frame(devtools::test(reporter="silent", stop_on_failure=FALSE))'` | 188 files, 1986 tests, 13037 expectations, 0 failed, 0 errors, 2 skipped, warnings: see run (run on the rebased tip) |
| Lint | install `git archive HEAD` into an isolated library, then `R_LIBS=<lib> Rscript -e 'lintr::lint_package()'` (verified `find.package("medfit")` is the isolated lib) | PLACEHOLDER: 5 findings at `5623420d` (3 `line_length_linter`: `tests/sim/run-gates.R:478`, `tests/sim/sem-fiml-ext-gate.R:1` and `:3`; 2 `object_usage_linter`: `tests/testthat/test-fiml-g3-parallel-covariates.R:106` and `:112`, helpers defined in other helper files). `origin/dev` measured the same way: 0 findings. Replace with the re-measured result after the fix |
| R CMD check | `R CMD build --no-manual --no-build-vignettes` then `_R_CHECK_FORCE_SUGGESTS_=false NOT_CRAN=false R CMD check --no-manual --ignore-vignettes --no-tests --as-cran` on a `git archive HEAD` copy, isolated library | Status: 1 NOTE (CRAN incoming feasibility: "Version jumps in minor (submitted: 0.16.0, existing: 0.3.2)"); 0 WARNING, 0 ERROR. Same NOTE as `dev` (version unchanged, 0.16.0). Examples and `--run-donttest` examples OK; tests skipped by option |
| New gate rows | `Rscript tests/sim/sem-fiml-ext-gate.R` (re-run on a `git archive HEAD` copy) | 129 rows, 129 pass: 8 structures x 2 seeds x 8 checks plus the refusal count (9 probes, 0 accepted) |
| Planted defects in the gate | `MUTANT=parcov_drop_path Rscript tests/sim/sem-fiml-ext-gate.R` and `MUTANT=parcov_orthogonal ...` (re-run on the same copy) | both stop with `Error: subscript out of bounds` (a structural crash at the parameter map, not a numeric gap): caught fail-closed, but not by a numeric comparison. The five earlier defects (`wrong_unit`, `no_offset`, `swap_b`, `dropped_cov`, `missing_guard`) were not re-run for this body |

Largest recorded discrepancy in the committed gate CSV against lavaan (limits in parentheses): estimates 3.2e-7 (1e-5),
covariance 3.8e-7 (1e-3), logLik 7.3e-12 (1e-6), NIE estimate 2.9e-7 (1e-5), NIE delta SE relative 5.2e-8 (2e-3);
retained, provenance, guard and unadmitted-accepted checks are exactly 0.

Not independently verified: the numerical-Hessian covariance check covers 2 of the 8 cells; OpenMx covers 1 cell; no
Hopper run; the OpenBLAS runner was not used.

## Admission checklist

- [x] 1. independent oracle: matched lavaan raw-data FIML with observed information (gate and `test-fiml-g3-parallel-covariates.R`: estimates 1e-5, covariance 1e-3, logLik 1e-6, `:=` products, their sum, the total and SEs), OpenMx raw-data FIML on one cell (free covariance, free direct path, one covariate), a from-scratch row-wise Gaussian likelihood with a zero-gradient check and an independent numerical Hessian (2 of the 8 cells), and closed-form complete-data OLS plus the exogenous and residual covariances (all 8 variants)
- [x] 2. reliability cell: `fiml-ext` gate, now 8 structures (`cov1`, `cov2`, `par_ind`, `par_free`, `parcov1_ind`, `parcov1_free`, `parcov2_ind`, `parcov2_free`) x 2 seeds x 8 checks plus the refusal count, 129 rows, all pass (re-run above); a small fixed-seed cell, not a coverage or large-replication study
- [x] 3. planted defect: gate defects `parcov_drop_path` and `parcov_orthogonal` (new) plus the five earlier ones, registered in `gates.csv`; the two new ones are caught by a crash at the parameter map rather than by a numeric gap (fail-closed; stated here so it is not read as a numeric detection); test-suite plants for a dropped covariate path, an orthogonal exogenous block, kernel transport, a swapped `a`, a zeroed Cov(b1, b2) and a dropped cross-path block, with one and two covariates (`test-fiml-g3-parallel-covariates.R`)
- [x] 4. metamorphic invariance: a written exogenous covariance in either order is the automatic one and a swapped mediator request keeps the sum; a covariate named the treatment with a free direct path matches lavaan with that role; the frozen pre-slice-3 tables (`tests/testthat/fixtures/fiml-tables-before-g2s3.rds`) are `identical()` to the current output
- [x] 5. fault injection: sparse missing patterns including both-mediator gaps and an all-empty row keep every pattern; near-boundary residual correlation stays fail-closed (a classed error, never a silent boundary solution); unadmitted topologies, wrong prepare shapes, extraction misuse and source-fit inference are refused with classed errors and no refit or RNG draw. Not covered: refit-failure injection for covariate parallel fits (their source-fit bootstrap is refused)
- [x] 6. registration: `tests/sim/gates.csv` row `fiml-ext` (129 rows, `oracle` = lavaan raw-data FIML, `mutants` = `wrong_unit|no_offset|swap_b|dropped_cov|missing_guard|parcov_drop_path|parcov_orthogonal|driver`); `tests/sim/structures.csv` rows "bounded random-X FIML with covariates" and "bounded random-X FIML with parallel mediators" (both name `fiml-ext`); `run-gates.R` structure list and driver cases; `R/sem-fiml.R` and `R/sem-fiml-interface.R` already in `tests/sim/risk-files.txt`
- [ ] 7. n/a: the OpenBLAS gates runner runs only on PRs to `main` and this PR targets `dev`, so no OpenBLAS run exists (not run); `fiml-ext` joins the `gates (rest)` shard on the release PR, and dev is gated locally (suite, lint, `R CMD check` above)

## Independent QA

PENDING: independent QA running. Verdict, oracle gaps and mutant counts to be filled in here: `<QA-RESULT-PLACEHOLDER>`

## Known unverified items

- Independent numerical Hessian agreement is checked on 2 of the 8 cells; OpenMx on 1 cell.
- No Hopper run; no OpenBLAS runner run.
- The two new gate defects are caught by a crash, not a numeric gap.
- Lint: 5 findings at the measured tip until the fix lands (placeholder row above).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
