# medsim adapter for the stage-0 FIML study (DRAFT, local only)

Status: 2026-11-09. Nothing here has been submitted or run on Hopper, and no full-size study has run. The hand-written
harness one level up (`run-chunk.R`, `check-complete.R`, `shared-refits.R`, `stage0.sbatch`, ...) is unchanged and remains the
reference. Plan: `planning/PLAN-FIML-admission-via-medsim-2026-11-09.md` (P1 and P2).

## Files

| File | Purpose |
| --- | --- |
| `adapter.R` | Setup (library, guard override, shared refits, receipt), one medsim scenario per cell, the method, `stage0_adapter_run_task()` (one array task), `stage0_medsim_long()` (back to the 21 `run-chunk.R` columns), `stage0_adapter_combine()` |
| `analysis.R` | The decision-side analysis: attempted-replication denominator, ledger, receipts and truth checks |
| `run-cells.R` | Thin wrapper over `stage0_run_cells()` (analysis.R): chunks, medsim combine (any violation stops), long CSV + wide RDS, then the gate; used by the parity and defect tests |
| `smoke.R` | Smoke runner: 4 cells x 3 datasets x 3 chunks, B = 40, medsim combine and audit, then the analysis |
| `tests/parity.R`, `tests/ref-inject.R`, `tests/inject-prelude.R` | Parity against `run-chunk.R`, with a seed-formula mutant and injected refit failures |
| `tests/defects.R` | Planted defects, each with a positive control |
| `tests/run-all.sh` | Everything above |

## How it maps

* One medsim scenario per cell (`cell001`), one replication per dataset, one wide row per dataset (6 calls x 12 fields,
  plus a receipt). `medsim_run_chunk()` splits the replications of a cell across chunks, so a stage-0 task is
  `(cell, chunk)` with a per-cell output directory (`<out>/cellNNN/chunk_000k.rds`); medsim's template covers one chunk id per
  array task only, so the task-id-to-(cell, chunk) mapping would live in the run script.
* Seeds: medsim seeds each replication with `.medsim_det_seed(name, rep)` and gives the data generator only `n`. The generator
  recovers `rep` by matching the RNG state against `set.seed(det_seed(name, r))` (exact; stops if no match) and re-seeds with
  `stage0_seed(cell, dataset)`, so the data equal `run-chunk.R`'s. The truth pass calls the generator with `n_truth = 1` and gets
  a placeholder.
* `n_cores = 1` (sequential; the shared-refit patch is an in-process namespace patch, not fork-safe by design).
* The medsim chunk file is replaced by a complete re-run (seeded, idempotent), unlike `run-chunk.R`, which refuses to overwrite.
* The collapse audit runs on NIE/TE estimates and interval ends only: every other numeric column is constant or discrete by
  design (fixed-direct NDE is exactly 0, truths, counts), and `collapse_exclude` is by name.

## Receipt in every row

`rcp_medsim_version`, `rcp_medsim_commit` (`STAGE0_MEDSIM_COMMIT`, required), `rcp_medfit_commit`, `rcp_fp_sha256`,
`rcp_r_version`, `rcp_blas`, `rcp_B`, `rcp_draws`, and three logicals checked at call time: the fit is a FIML fit
(`medfit:::.sem_fiml_is`), the guard override is in force, the shared-refit patch is installed. `stage0_receipts()` stops on a
non-constant value, a FALSE logical, or a call whose `requested` differs from the nominal B or draws. The `requested == B` check is
close to tautological (the adapter passes B itself); the real guards are the logicals and the ledger. `medsim_run_chunk()` adds its
own chunk provenance (R, medsim, dependency versions, host, `code_sha` = the fingerprinted medfit commit).

## Run it

```bash
# one-time, isolated library (medsim is read-only; build from a clean archive of the pinned commit)
git -C <medsim> archive <commit> | tar -x -C <scratch>/medsim-src
R CMD INSTALL --no-docs --library=<scratch>/lib <scratch>/medsim-src
# environment (see adapter.R): STAGE0_FINGERPRINT, STAGE0_MEDSIM_LIB, STAGE0_MEDSIM_COMMIT, STAGE0_B=40, STAGE0_DRAWS=200 ...
Rscript planning/studies/fiml-stage0-hopper/medsim/smoke.R <empty outdir> 3 3
bash planning/studies/fiml-stage0-hopper/medsim/tests/run-all.sh <empty workdir>
```

## What is verified (local, B = 40, 200 draws, 3 datasets per cell)

* Parity: 12 clean cells (every regime, miss type, direct on/off, both n; 216 records per side), a collection-cap failure
  (`generation_failed`), a zero budget (`unattempted_budget`), and 4 cells with injected refit failures (36 of 36 nonparametric
  calls `withheld` with NA intervals) and injected warnings: identical records, every column except `seconds`. Compared as the
  text `write.table` produces on both sides (15 significant digits), not bit by bit; chunk counts alternate 1 and 3 so the
  replication-offset path is covered. A seed-formula mutant is reported as not identical.
* Defects caught (26 checks): a dropped chunk, a duplicated cell, failed/incomplete/withheld intervals in the denominator (and the
  complete-only denominator shown to differ), a seed-formula change, swapped truth columns, receipt violations. Each has a positive
  control (the clean run passes the same checks).

## QA gaps, closed (second round)

* G1: `stage0_integrity()` flags a `complete` row with `failed`/`interrupted`/`unattempted` > 0 or `successful != requested`
  (planted: a withheld row relabeled `complete` with the parametric interval copied in and `failed > 0` kept).
* G2: `stage0_coverage(L, W, truth, cells, nd)` runs `stage0_gate()` first: ledger integrity, receipts and `stage0_truth_check`
  must all pass or it stops listing every problem. `smoke.R` and `run-cells.R` use it. Planted: mixed `rcp_B`, a restored
  shared-refit patch (a real run-cells run with the patch removed exits nonzero), a swapped truth table.
* G3: `stage0_adapter_run_task()` refuses to replace an existing `chunk_NNNN.rds` ("output exists") unless `overwrite = TRUE`.
  medsim's generated submit script sets `--requeue`; a requeued task therefore hits this guard (or needs an identical-content
  check) instead of silently replacing a chunk, which also differs from medsim's own replace-on-rerun behavior.
* G4: the combine in `run-cells.R` uses `on_violation = "stop"` (tested: a missing chunk stops `stage0_run_cells()`).
  `STAGE0_GATE=off` (combine violations become warnings, no final gate) is used only by the cap/budget parity runs, whose cells are all failure rows.

## What is NOT verified

* No Hopper run, no submission, no full-size run; scheduling, `MaxArraySize`, queueing and walltime are untested.
* The BLAS here is Homebrew OpenBLAS 0.3.34 on macOS (R 4.6.2); Hopper uses a spack R module with its own BLAS. Parity must be
  re-run in the pinned Hopper environment (plan P3). Warnings are not columns of the 21-column record, so the injected-warning
  case shows only that nothing breaks, not that per-replicate warnings match.
* Local runs load the working tree with `STAGE0_ALLOW_ANY_COMMIT=1`; `R/` and `DESCRIPTION` are identical to the stage-0 freeze
  `ba50f998` (`git diff ba50f998 HEAD -- R DESCRIPTION` is empty), but the receipt commit is the fingerprint commit I wrote
  (`bac4ca15`), not a Hopper build.
* The `fit_failed` dataset-level path is not exercised by parity (no natural trigger); `stage0_medsim_long()` handles it as
  `run-chunk.R` does but only the cap and budget failure paths are compared.
* Nothing here freezes a decision rule: `stage0_returned()` counts a call as returned only for status `complete` with a finite,
  ordered interval (PREREG P7 is still to be enumerated; the draft's interim rule would count any status outside the four failure
  statuses). The pass flags are exploratory. `medsim_analyze_coverage()` is not used.

## medsim findings

* Installed: medsim 0.6.0.9000 built from commit `bb6a30916217d632c334e8c559234f81d51f594b` (disk head; the system library has 0.5.1).
  0.5.1 has no `medsim_run_failure`: a task-level error in the parallel path was dropped silently (fixed in 0.6.0, #43). The
  adapter runs sequentially and also checks the ledger, but pin 0.6.x.
* Silent K = 1 fallback: `.medsim_md_implist()` (`R/methods_missing.R`, present in v0.5.0, v0.5.1 and 0.6.0.9000) returns a single
  complete-case frame whenever `use_mi` is false, the data have no missing values, `mice` is not installed, or `mice()` errors
  (the error is caught and discarded). It belongs to medsim's own MI methods, so a saved row cannot tell K = 20 from K = 1. This
  adapter never calls it; the receipt and ledger make the equivalent failure visible for the FIML refits.
* `medsim_write_submit_script()` (inspected only, not used): it hard-codes `module load r/4.4.0-ytj2` by default (the hand-written
  `stage0.sbatch` loads `r/4.4.0-fyqw`, a different BLAS) and has no `module purge`, `R_LIBS_USER`, OPENBLAS/OMP exports,
  fingerprint `sha256sum -c`, clean-tree or HEAD check, working-directory change or account line, and it always sets `--requeue`.
  Replacing `stage0.sbatch` would mean re-implementing those gates in a wrapper.
* `check-complete.R` (unchanged) lists four failure statuses, so a legitimate `withheld`/`incomplete` call would make it report
  INCOMPLETE OR INCONSISTENT; `analysis.R` presents those rows to it as `error` rows. That is a pre-existing gap for P7.
