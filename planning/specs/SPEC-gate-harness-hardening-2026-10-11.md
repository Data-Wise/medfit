# Spec: harden the gate driver (plan T3b; Codex review findings 1 and 4)

**Date:** 2026-10-11 | **Status:** specified, not implemented | **Files:** `tests/sim/run-gates.R`, `tests/sim/gates.csv`,
`tests/sim/sem-constrained-gate.R` | **Origin:** adversarial review of the research note, `RESEARCH-redundant-constraints-2026-10-11.md` section 5

## Problem 1: `--sim` can pass on results it did not produce

`run_gates.R --sim` runs each gate script with its exit status and output discarded, then reads the newest `<prefix>-<date>.csv` within 14
days of today. Every gate script writes `tests/sim/results/<prefix>-<Sys.Date()>.csv` at the very end (`sem-parity-gate.R:145`,
`sem-constrained-gate.R:123,126`, `sem-se-gate.R:61`, `sem-reliability.R:144`). A script that crashes before that line leaves the
committed 2026-10-09 and 2026-10-10 baselines as the newest eligible file, and the driver reports PASS for a checkout it never ran.

### Options considered

| Option | Behavior | Verdict |
|---|---|---|
| A. Exit status plus freshness: require the child's exit status to be 0 and the results file's modification time to be at or after the moment the child started | No change to the four gate scripts; works the same-day (file overwritten) and the new-day case; a crash or a skipped write fails | **Chosen** |
| B. Isolated results directory: an environment variable (`GATE_RESULTS_DIR`) that each script honors, and a fresh temporary directory per `--sim` run | Strongest: the committed baselines cannot be confused with new output, and `--sim` stops writing into the repo | Better long term; costs four script edits and a convention. Defer, note in the harness table |
| C. Delete the old CSVs before running | Simple | Rejected: destroys the committed baselines the default verdict mode reads |

### Design (option A)

- `run_child(script)` records `t0 <- Sys.time()` and runs `system2("Rscript", script, stdout = log, stderr = log)` with the log written to
  `tests/sim/results/gates-<script>.log` (gitignored), so a failure is diagnosable instead of silent. It returns the exit status.
- The gate scripts print PASS/FAIL and exit 0 on completion (verified: no `quit()` or `stop()` signals a gate failure), so a nonzero status
  means the script crashed. Requiring status 0 does not contradict the "verdicts come from the CSV" rule: the CSV still decides pass or fail.
- `load_results()` takes an optional `not_before` time. In `--sim` mode it is `t0`: a file older than `t0` is a failure with the message
  `<file> was not written by this run (modified <time>, run started <time>)`.
- Default verdict mode (no `--sim`) is unchanged: it checks the committed baselines against the 14-day window.

### Acceptance

- A mutant in `--mutants`: a stub gate script that exits 1 without writing, with an older passing CSV present in the results directory, makes
  the `--sim` path fail with the child's status named. A second mutant: the script exits 0 but writes nothing (stale file only) fails with the
  not-written message. The control, a stub that writes a passing CSV, passes.
- Planted defect: removing the `not_before` check must turn the second mutant red.

## Problem 2: the stationarity check ignores the acceptance threshold

The `stationarity` verdict computes `min(non-accepted decrement) / max(accepted decrement) >= 10` and never compares either group with
`.sem_stat_tol` (1e-3), although the calibration rule is two-sided: the threshold must sit at least 10x above the largest accepted decrement
and at least 10x below the smallest decrement of a run that stalled far from the optimum. A common rescaling of every decrement (a broken
scale) keeps the ratio and passes.

### Measurement (fresh run of `sem-constrained-gate.R` with the distance saved, 2026-10-11, scratch copy)

| Quantity | Value |
|---|---|
| accepted starts | 120, largest decrement 3.6e-8 (27,778x below the threshold) |
| truncated runs with a finite decrement | 80 |
| of those, far from the optimum (distance > 1e-2 in natural units) | 73, smallest decrement 0.014 (14x above the threshold) |
| near the optimum (distance <= 1e-2) | 7, decrements 0.00196 to 0.0181 |
| rejected-by-gate starts | 480 rows, all decrement NA (never reach a decrement; by design) |

The 7 near runs are why the check must use the distance: the raw smallest truncated decrement is 1.96e-3, only 2x the threshold, so a naive
10x test on all truncated runs fails on a healthy engine. The committed CSV does not carry the distance (the script builds it and drops it on
write), so the file must be regenerated with the field.

### Design

1. `sem-constrained-gate.R` keeps `dist` in the stationarity CSV (`att` rows get `NA`); the `keep` vector gains `"dist"`. Regenerate and commit
   `sem-constrained-stationarity-<date>.csv`.
2. `gates.csv` stationarity row gains the threshold in `tol_est` (1e-3) and the distance cutoff in `tol_se` (1e-2), so nothing is hard-coded
   in the driver. A `--fast` check asserts `tol_est` equals the package's `.sem_stat_tol`, so drift between `gates.csv` and `R/sem-optim.R`
   fails the run; the distance cutoff is a harness constant.
3. The verdict has three checks: largest accepted decrement `<= tol / 10`; smallest decrement of a far truncated run `>= 10 * tol`; every
   finite truncated decrement `> tol` (the gate would reject every truncated run). The 10x ratio check stays as the report line.

### Acceptance

- Mutants: all decrements multiplied by 1e-6 (the far group falls below `10 * tol`) and by 1e6 (the accepted group rises above `tol / 10`)
  both fail; measured: x1e-6 fails the far margin, x1e6 fails the accepted margin, and the ratio-only check passes both.
- Control: the regenerated CSV passes all three checks (27,778x and 14x margins).
- Planted defect: dropping the distance filter must turn the control red (the near runs break the 10x test).

## Not in scope

- Option B (isolated results directory). Revisit if a second stale-file incident occurs.
- Changing the calibrated thresholds (`.sem_stat_tol`, `.sem_singular_tol`): fixed at checkpoint A, ledger D19.
