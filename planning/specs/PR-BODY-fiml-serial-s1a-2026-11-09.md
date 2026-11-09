## Summary

FI-G3 slice S1a (serial FIML, internals only), on top of the merged FI-G0 to FI-G3 parallel-covariate work. This slice
adds the serial parser and router, the Q2 refusals, the serial table builder and the refusal probes. There is **no
public serial variant**: every serial syntax is refused at fit with a classed `medfit_sem_fiml_error` until slice S1b.

- Router and parser (`R/sem-fiml-interface.R`): serial structure `M1 -> M2 -> Y` (saturated and chain variants, zero to
  two covariates) is recognized, its variant detected from every written term (fixed ones included), and the
  treatment, structural mediators and parameter map are returned. Mediators are structural, not in order of
  appearance.
- Q2 refusals: each omitted, free, labeled, fixed-nonzero, duplicated or exogenous-tied residual zero among
  `M1 ~~ 0*M2`, `M1 ~~ 0*Y`, `M2 ~~ 0*Y` is refused, naming exactly the offending pair(s).
- `.sem_fiml_tables_ser()` (`R/sem-fiml.R`): the serial table builder for both shortcut states (variants), with the
  spec's parameter counts.
- Source-fit refusal ordering (`R/bootstrap-fiml.R`): a serial source fit is refused with the serial class before any RNG
  draw or refit.
- `tests/sim/sem-fiml-ext-gate.R`: 24 refusal probes (was 9), including every serial variant for k = 0 to 2, each
  checked for its reason; two serial planted defects (`serial_admitted`, `serial_router_off`).

No statistical admission, coverage or global-optimality claim is made. No push, release or CRAN step is part of this
change.

Not run: any check on the OpenBLAS gates runner, the platform matrix, statistical coverage, a Hopper run, the vignette
build in `R CMD check`.

## Evidence (pre-PR testing, tree = branch tip)

Local machine: macOS aarch64, R 4.6.2. Tree: worktree `feature/fiml-serial-s1a`, tip `2587f718`, 7 commits above
`origin/dev` `be232f57`. Gates, lint and check were run on `git archive HEAD` copies with isolated libraries
(`find.package("medfit")` verified).

| Check | Command | Result |
|---|---|---|
| Full suite | `NOT_CRAN=true Rscript -e 'r <- as.data.frame(devtools::test(reporter="silent", stop_on_failure=FALSE))'` | 190 files, 2023 tests, 15149 expectations, 0 failed, 0 errors, 2 skipped (measured 2026-11-09 on the tip, by the implementer; not re-run by the gates pass) |
| Lint | isolated source install of `git archive HEAD`, `R_LIBS=<lib> Rscript -e 'lintr::lint_package()'` | 0 findings at the final tip (isolated install, `find.package` verified). The gates run at `2587f718` found 1 (`indentation_linter`, `tests/testthat/test-fiml-g3-serial-router.R:699`), fixed by a one-space dedent in the last commit. `origin/dev` measured the same way: 0 |
| R CMD check | `R CMD build --no-manual --no-build-vignettes`, then `_R_CHECK_FORCE_SUGGESTS_=false NOT_CRAN=false R CMD check --as-cran --no-manual --ignore-vignettes --no-tests` | Status: 1 NOTE (CRAN incoming feasibility: "Version jumps in minor (submitted: 0.16.0, existing: 0.3.2)"); 0 WARNING, 0 ERROR. Same NOTE as `dev`. Examples and `--run-donttest` examples OK; tests skipped by option. A first attempt died on a CRAN-server timeout in the incoming check (network) and was re-run unchanged |
| Gate verdicts | `Rscript tests/sim/run-gates.R --sim --only fiml,fiml-ext` | `fiml` PASS (24 rows of 24); `fiml-ext` PASS (129 rows of 129, 129 pass, `unadmitted_accepted` = 0); OVERALL PASS, 12 of 12 driver checks |
| Gate planted defects | `MUTANT=<name> Rscript tests/sim/sem-fiml-ext-gate.R` for all nine registered names | all nine stop with a failing gate: `wrong_unit`, `no_offset`, `swap_b`, `dropped_cov` fail numeric rows; `missing_guard` fails the guard row (1 vs 0); `serial_admitted` makes `unadmitted_accepted` = 6 (limit 0); `serial_router_off` makes it 15 (limit 0); `parcov_drop_path` and `parcov_orthogonal` stop with `Error: subscript out of bounds` (a structural crash, not a numeric gap: caught fail-closed) |
| Driver mutants | `Rscript tests/sim/run-gates.R --mutants --only fiml,fiml-ext` | every mutation rejected, every control passes (exit 0) |
| Parity (V14) | the implementer's and QA's parity run against `origin/dev` | QA: see section `Independent QA` below |

Gate rows are not a coverage study: two seeds per structure, fixed-seed cells. The committed gate CSVs
(`tests/sim/results/sem-fiml-gate-2026-11-09.csv`, `sem-fiml-ext-gate-2026-11-09.csv`) are the runs of the implementer;
the gates pass above re-ran both on the tip copy.

## Admission checklist

- [x] 1. independent oracle: the serial table fit against three oracles independent of the production kernel, in `tests/testthat/test-fiml-g3-serial-router.R`: the spec's own parameter-count formula (both variants, k = 0 to 2, direct path free or fixed), equation-wise ML OLS from `lm` for complete data (the chain's likelihood factors over equations), and matched lavaan raw-data FIML (`missing = "ml"`) for the table solve with incomplete data, on every residual-zero mask lavaan converges on. No oracle run by the QA agent is recorded here: see the QA section
- [x] 2. reliability cell: `fiml-ext` gate, 8 structures x 2 seeds x 8 checks plus the refusal count (129 rows, all pass, re-run above); the new refusal probes (24, up from 9) are counted, must be 0 admitted. A small fixed-seed cell, not a coverage or large-replication study; no serial structure is in the numeric cells because no serial fit is public yet
- [x] 3. planted defect: gate defects `serial_admitted` and `serial_router_off` (new; caught by the refusal count, 6 and 15 admitted against a limit of 0) plus the seven earlier ones (re-run above; two of them are caught by a crash, stated in the evidence table); test-suite plants in the parser and builder (positive control first): a label swap on a table row, only the first missing zero reported, `0*` terms ignored, router off (`test-fiml-g3-serial-router.R`)
- [x] 4. metamorphic invariance: mediators are structural, not in order of appearance; either order of a residual pair is accepted; the chain's treatment is found whatever its name or position; the frozen pre-slice fixtures (`tests/testthat/fixtures/fiml-tables-before-g2s3.rds` and the post-S1a `fiml-tables-after-g3s1a.rds`, `fiml-refusals-after-g3s1a.rds`) pin the non-serial tables and refusals identical
- [x] 5. fault injection: omitted, free, labeled, fixed-nonzero, duplicated and exogenous-tied residual zeros refused with the pair named; a missing path, a cycle, a third mediator, three covariates and interactions refused; every serial syntax in every policy cell refused at fit with the not-yet-available reason; serial source-fit inference refused before any RNG draw or refit for k = 0, 1, 2; a serial fit cannot be extracted (classed refusal, not the parallel extractor); every non-theory-forced residual-zero mask is a finite fit or a classed error, never a silent boundary solution (V10). Not covered: refit-failure injection (no serial source-fit bootstrap exists yet)
- [x] 6. registration: `tests/sim/gates.csv` row `fiml-ext` (129 rows, 24 refusal probes, `oracle` = lavaan raw-data FIML, `mutants` = `wrong_unit|no_offset|swap_b|dropped_cov|missing_guard|parcov_drop_path|parcov_orthogonal|serial_admitted|serial_router_off|driver`); `tests/sim/structures.csv` rows for the FIML structures already name `fiml-ext` (no new public structure in this slice); `R/sem-fiml.R` and `R/sem-fiml-interface.R` are in `tests/sim/risk-files.txt`
- [ ] 7. n/a: the OpenBLAS gates runner runs only on PRs to `main` and this PR targets `dev`, so no OpenBLAS run exists (not run); `fiml-ext` joins the `gates (rest)` shard on the release PR, and dev is gated locally (suite, lint, `R CMD check` above)

## Independent QA

`medfit-oracle-qa` (own code, scripts and mutants; no tracked report file): **PASS on all 7 items, no blocking defect.**

- Tables and kernel: for all 12 cells (k = 0, 1, 2 x direct free/fixed x saturated/chain) q matches an independent edge enumeration and the spec formula (saturated 14/20/27 free, 13/19/26 fixed; chain 12/18/25 free, 11/17/24 fixed; df 0/1 and 2/3). The existing kernel accepts all 12 on complete data (n = 400): estimates and ML variances match equation-wise OLS to 1.4e-8, saturated cells match the unrestricted MVN MLE to 6.2e-9 or better and the unrestricted logLik. Chain and saturated missing-data cells match lavaan raw-data FIML (estimates 3.7e-6, logLik 5.5e-9).
- Router: 116 syntaxes (variant x k x direct free/fixed/omitted x zero sets x partial shortcuts x labeled/tied/fixed shortcuts x F6 cases) all refused at `fit_sem` with `medfit_sem_fiml_error` and the real reason named (each single omitted zero covariance is named, the variant is named); none reached a fit or the parallel or covariate parser.
- Frozen fixtures (R2/R4): the pre-S1a fixtures are untouched; all 22 frozen table shapes are `identical()`; of 92 near-miss refusals 37 changed (36 `ser_*` plus the `serial` gate probe), each allowed by spec 4.4; no `par*`, `cov*` or other `simple_*` entry changed.
- Source-fit order (F2): reachable by mocking `.fiml_serial_admitted`; 12 cells; guard closed gives `medfit_error_fiml_inference_unavailable`, guard open gives `medfit_error_fiml_serial_source_fit`; parallel and covariate classes unchanged (order guard, serial, covariate, parallel).
- Planted defects: 9 of 9 caught with an unmutated positive control (freed chain shortcut, dropped saturated `b1`, wrong q, router order, F6 relabel, omitted zero accepted, first-missing-only, wrong source-fit class, serial check removed).
- V14 parity with `origin/dev` `be232f57` (two installs): 16 shapes x 4 datasets (MAR, MCAR 30%, complete) = 64 cells, 576 fields, 0 differences.
- V10 never-jointly-observed pairs (internals): saturated with a free direct path refuses all 6 pairs (rank-deficient moment Jacobian); with a fixed-zero direct path and in the chain, acceptance is data-dependent (some seeds refuse with "no accepted candidate"); every accepted fit matched lavaan, none silently wrong. UNVERIFIED: whether those acceptances are structurally or only generically identified. A robustness flag for S2.

Observations, not blockers: three mediators keeps the pre-S1a message (real but not serial-specific); at k = 2 a missing exogenous covariance gets the generic serial message; `M2 ~ M1 + X` with Z omitted is a valid chain whose treatment is Z and is refused only by the blanket S1a gate, so S1b needs an explicit rule; the k = 1 covariate labels are `gm1z1`, `gm2z1` (labels are not contract).

## Known unverified items

- No Hopper run; no OpenBLAS runner run; no platform matrix.
- No serial fit is public, so no serial numeric cell exists in the gate yet; the serial table builder is checked through
  internals against `lm` (complete data) and lavaan (incomplete data) in the test suite.
- The full-suite count is the implementer's measurement on the tip, not re-run in this gates pass.
- Lint: one `indentation_linter` finding at the tip until the one-space dedent lands (see the evidence table).
- The QA verdict above is a placeholder until the independent QA report is in.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
