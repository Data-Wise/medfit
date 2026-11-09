## Summary

FI-G3 slice S1b: the first public serial FIML variant, the saturated serial model with no covariates (k = 0), on top of
the merged S1a router and refusals. `fit_sem()` with `missing = "ml"` now fits `X -> M1 -> M2 -> Y` with the direct
path free or fixed and all three residual covariances fixed at zero (the Q2 syntax); the chain variant and every
k >= 1 syntax stay refused with a classed `medfit_sem_fiml_error` until S2 to S4.

- New class `FIMLSerialMediationData` (`R/classes.R`) with a `variant` slot; extraction through `extract_mediation()`
  and `fit_sem()` (`R/fit-sem.R`, `R/sem-fiml-interface.R`).
- Six path rows; `nie()` (chain), `nie_total`, `nde()`, `te()` with delta-method SEs; per-effect origin rule.
- Consumer refusals: `pm()`, `glance()`, `quick()` and bootstrap each refuse a serial FIML fit with a classed error.
- `confint()` contract, including `nie_total`.
- Gate `fiml-ext`: new structure `ser_sat0` (9 structures x 2 seeds x 8 checks + 1 = 145 rows); four serial planted
  defects added to the gate (`ser_swap_db`, `ser_drop_cross`, `ser_total_gradient`, `ser_drop_shortcut`).
- Docs: NEWS, roxygen (`fit_sem`, `extract_mediation`, man pages regenerated), native guide, models, methods, README
  and the book chapter scope sentences.

No statistical admission, coverage or global-optimality claim is made. No push, release or CRAN step is part of this
change.

Not run: any check on the OpenBLAS gates runner, the platform matrix, statistical coverage, a Hopper run, the vignette
build in `R CMD check`, the full suite by the gates pass.

## Evidence (pre-PR testing, tree = branch tip)

Local machine: macOS aarch64, R 4.6.2. Tree: worktree `feature/fiml-serial-s1b`, tip `91b3371c`, 7 commits above
`origin/dev` `cd0d0317`. Lint, check and gates were run on `git archive HEAD` copies with isolated libraries
(`find.package("medfit")` verified to point at the isolated library for lint).

| Check | Command | Result |
|---|---|---|
| Full suite | `NOT_CRAN=true Rscript -e 'r <- as.data.frame(devtools::test(reporter="silent", stop_on_failure=FALSE))'` | final tip `<SUITE-FINAL-PLACEHOLDER>`. Implementer measurement at `6174c573`: 2072 tests, 16077 expectations, 0 failed, 0 errors, 2 skipped, 4 warnings; not re-run after the final commit `91b3371c` (a test-only commit) by the implementer or by the gates pass |
| Lint | isolated source install of `git archive HEAD`, `R_LIBS=<lib> Rscript -e 'lintr::lint_package()'` with the repo `.lintr` | 0 findings at `91b3371c` (`origin/dev` per the S1a record: 0; not re-measured) |
| R CMD check | `R CMD build --no-manual --no-build-vignettes`, then `_R_CHECK_FORCE_SUGGESTS_=false NOT_CRAN=false R CMD check --as-cran --no-manual --ignore-vignettes --no-tests` | Status: 1 NOTE (CRAN incoming feasibility: "Version jumps in minor (submitted: 0.16.0, existing: 0.3.2)"); 0 WARNING, 0 ERROR. Same NOTE as `dev`. Rd files, Rd cross-references, code/documentation mismatches, `\usage`, examples and `--run-donttest` examples all OK; tests skipped by option |
| Gate verdicts | `NOT_CRAN=true Rscript tests/sim/run-gates.R --sim --only fiml,fiml-ext` | `fiml` PASS (24 rows of 24); `fiml-ext` PASS (145 rows of 145, `unadmitted_accepted` = 0); OVERALL PASS, 12 of 12 driver checks |
| Gate planted defects | `MUTANT=<name> Rscript tests/sim/sem-fiml-ext-gate.R` for all 13 registered names | all 13 stop with a failing gate. Numeric rows fail: `wrong_unit` (28 rows), `no_offset` (18), `swap_b` (23), `dropped_cov` (12), `ser_swap_db` (4: serial `nie_estimate`, `nie_se`), `ser_drop_cross` (2: serial `nie_se`), `ser_total_gradient` (2: serial `nie_se`); `missing_guard` fails 18 guard rows; `serial_admitted` makes `unadmitted_accepted` = 5 (limit 0). Caught by a structural crash instead of a numeric gap (fail-closed): `parcov_drop_path`, `parcov_orthogonal` (`subscript out of bounds`), `serial_router_off` (`unsupported FIML topology`), `ser_drop_shortcut` (`length(labels) == conv$ram$q is not TRUE`) |
| Driver mutants | `Rscript tests/sim/run-gates.R --mutants --only fiml,fiml-ext` | every mutation rejected, every control passes (exit 0) |
| Parity (V14) | the implementer's and QA's parity run against `origin/dev` | implementer: 72 of 72 cells identical; QA: `<QA-RESULT-PLACEHOLDER>` |

Gate rows are two fixed seeds per structure, not a coverage study. The committed gate CSV
(`tests/sim/results/sem-fiml-ext-gate-2026-11-09.csv`) is the implementer's run; the gates pass above re-ran the gate
on the tip copy and passed.

## Admission checklist

- [x] 1. independent oracle: saturated serial k = 0 fit against lavaan (raw-data FIML), the unrestricted MVN MLE identity (complete data), equation-wise OLS (`lm`), a rowwise Hessian for the observed information, and OpenMx on one cell, in `tests/testthat/test-fiml-g3-serial-saturated.R` and `test-fiml-g3-serial-effects.R` (oracles implementer-run); the gate's `ser_sat0` cell compares the chain NIE, total indirect effect and total effect to lavaan `:=` values. Independent QA verdict: `<QA-RESULT-PLACEHOLDER>`
- [x] 2. reliability cell: `fiml-ext` gate, 9 structures (new `ser_sat0`) x 2 seeds x 8 checks plus the refusal count, 145 rows, all pass, re-run on the tip copy above. A small fixed-seed cell, not a coverage or large-replication study
- [x] 3. planted defect: four new gate defects `ser_swap_db` (d1/b swap), `ser_drop_cross` (dropped cross block), `ser_total_gradient` (wrong gradient) and `ser_drop_shortcut`, plus the nine earlier ones, all caught (see the evidence table); the test suite plants, each with a positive control first, in `tests/testthat/test-fiml-g3-serial-defects.R`: d1/b swap, dropped cross block, wrong gradients, per-effect origin-rule defects, consumer refusals, admission predicates
- [x] 4. metamorphic invariance: mediators are structural, not in order of appearance; the d1/b relabeling leaves the chain NIE invariant, so the gate checks the total indirect effect and its SE too; frozen fixtures (`tests/testthat/fixtures/fiml-refusals-after-g3s1b.rds`, built by `make-fiml-after-g3s1b.R`) pin the non-serial tables and the unchanged refusals; V14 parity with `origin/dev` on non-serial fits (72 of 72 identical, implementer-run)
- [x] 5. fault injection: chain and k >= 1 syntaxes refused at fit; consumer refusals (`pm`, `glance`, `quick`, bootstrap) are classed errors; per-effect origin-rule defects are planted in the test suite; `confint()` for `nie_total` and the effect rows; refusal probes in the gate (25, among them the serial Q2, shortcut, not-yet-public, reversed-order and never-jointly-observed probes) must admit 0. Not covered: refit-failure injection (no serial bootstrap exists)
- [x] 6. registration: `tests/sim/gates.csv` row `fiml-ext` (145 rows, `oracle` = lavaan raw-data FIML, `mutants` = `wrong_unit|no_offset|swap_b|dropped_cov|missing_guard|parcov_drop_path|parcov_orthogonal|serial_admitted|serial_router_off|ser_swap_db|ser_drop_cross|ser_total_gradient|ser_drop_shortcut|driver`); `tests/sim/structures.csv` row "bounded random-X FIML with serial mediators" names `fiml-ext` (the gate cell is `ser_sat0`); `R/sem-fiml-interface.R` is in `tests/sim/risk-files.txt`
- [ ] 7. n/a: the OpenBLAS gates runner runs only on PRs to `main` and this PR targets `dev`, so no OpenBLAS run exists (not run); `fiml-ext` joins the `gates (rest)` shard on the release PR, and dev is gated locally (suite, lint, `R CMD check` above)

## Independent QA

`medfit-oracle-qa` verdict: `<QA-RESULT-PLACEHOLDER>`

## Known unverified items

- No Hopper run; no OpenBLAS runner run; no platform matrix.
- The full-suite figure on the final tip is `<SUITE-FINAL-PLACEHOLDER>`; the implementer's figure is at `6174c573`, two commits earlier.
- Chain and k >= 1 are refused; no numeric cell exists for them.
- The independent QA verdict and V14 parity from QA are placeholders until the QA report is in.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
