# FIML stage-0 timing pilot: manifest (frozen before execution)

Feasibility only. Cannot remove cells, relabel regimes, change gates or choose M/B.
Maintainer limits (2026-11-07): 2 h total wall-clock, 15 min per cell, local machine.

- **Source:** commit pinned in `pilot.R` output (`git rev-parse HEAD`, tree must be clean);
  study-only override of `.fiml_source_inference_admitted` applied in-process by the
  script; no package source is changed and the override is never committed.
- **Environment:** recorded in `env.txt` by the script (R, BLAS, cores, packages).
- **Design (one fixed slice of the proposed 60-cell grid, not a sample of it):**
  n in {200, 500}; paths (a,b) = (.4,.4); missingness in {MCAR, observed-X MAR, all-empty MCAR}
  as defined in `../fiml-admission-design/README.md`; direct path in {free c=.2, fixed 0}
  = 12 cells. Collection cap for all-empty MCAR: 10 x n collected records, hit = logged failure.
- **Work per cell:** D = 3 datasets (disjoint pilot seeds 9100001+, never reusable for the
  confirmatory ledger). Per dataset: one FIML fit; one `method = "nonparametric"` call,
  `effect = "nie"`, `n_boot = B` with B = 999 row refits; one `method = "parametric"` call,
  `effect = "nie"`, `n_boot = 20000` draws. Timed separately, sequential, `parallel = FALSE`.
- **Caps and handling:** per-cell wall-clock 15 min (cell stopped, logged `timeout`, remaining
  datasets for it marked unattempted); total 2 h (stop, log remaining cells `unattempted`).
  Failures and timeouts are recorded, not dropped.
- **Outputs:** `pilot-log.csv` (one row per cell x dataset x method: status, seconds,
  failure reason), `env.txt`, summary printed. Extrapolation to a full stage is arithmetic
  on this log and is reviewed separately.
- **Stop conditions:** dirty tree, source mismatch, or guard override not confirmed -> do not run.
