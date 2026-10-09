# Evidence scripts: native SEM engine (2026-10-08)

Reproduces the numbers quoted in `../../GRILL-native-sem-engine-medfit-2026-10-08.md` and
`../../SPEC-sem-grammar-2026-10-08.md`. Exploratory code, not package code; nothing here is installed or exported.

## Run

```sh
cd planning/specs/evidence/native-sem-2026-10-08
./run-all.sh                         # about 3 minutes; writes results/<script>.out; deletes each old output first and exits nonzero if any script fails
REPS=5 ./run-all.sh                  # quick benchmark
LAVAAN_ALT_LIB=/path/to/lib ./run-all.sh   # also re-runs the lavaan probe under another lavaan version
```

Each script must be run from this directory (they `source("common.R")` by relative path).

## Versions used for the committed outputs

R 4.6.1; nloptr 2.2.1; alabama 2025.1.0; ucminf 1.2.3; OpenMx 2.22.11 (no NPSOL); numDeriv 2016.8.1.1;
Matrix 1.7.5; lavaan 0.7.2 (`results/01-probe-lavaan.out`) and 0.7.3 (`results/01-probe-lavaan-alt.out`).
Machine: macOS, 18 cores (affects only the parallel timings). Timings vary by about 5% between runs.

## Scripts

| Script | What it shows | Ledger / spec reference |
|---|---|---|
| `common.R` | the RAM engine (model builder, implied covariance, ML discrepancy, analytic gradient) copied from missingmed `dev/spike-ram-nloptr-vs-openmx.R`, plus `pd_ok()` (positive-definite start test, added in review round 3) | all |
| `00-spike-ram-nloptr-vs-openmx.R` | the original spike (verbatim copy); `02` sources it | P0 |
| `01-probe-lavaan.R` | `lavParseModelString()` output for the grammar subset: bound folding, dropped `y1`, `level:` rows | spec section 2 |
| `02-p0-openmx-information.R` | OpenMx SEs vs observed and expected information; the `n/(n-1)` convention. The Hessian-matrix lines in this output are **not valid evidence** (relative differences blow up on near-zero entries); the SE lines are | ledger P0 facts, K10 |
| `03-bench-optimizers.R` | 5 unconstrained optimizers x 3 model shapes x n of 50/200/1000 x default and random starts x 30 datasets, against lavaan | research table, K10 context |
| `04-constrained-solvers.R` | nloptr SLSQP vs alabama on `a*b == 0` and `a + b == 0.5`, 10 starts | research table |
| `04b-constraint-contract.R` | syntactic linearity (16 expressions), 5-start rule with valid starts, stalled start, feasibility gate, failure-or-spread warning rule (5 stubbed cases + 2 integration runs); acceptance gate with nloptr status and KKT stationarity (6 stubbed cases, threshold calibration); inequality KKT with non-negative multipliers (base-R NNLS checked against L-BFGS-B, the planted wrong-sign case, real nloptr inequality runs); the older numeric three-point check is kept in the output for comparison | spec 4.5 |
| `05-speed.R` | per-call cost, vectorized objective, dense vs sparse, parallel fits | research table, K7b |
| `05b-optimizer-speed.R` | nloptr SLSQP/LBFGS vs nlminb with the vectorized objective | research table |
| `06-evaluator-prototype.R` | locked constraint evaluator, planted caller-side `exp` defect, 28 rejection inputs (incl. `5L`, hex, `1i`, `Inf`), 14 valid expressions compared with R's own evaluation, and the result-domain guard (8 non-finite results rejected, 5 valid boundary expressions accepted); prints `TALLY` lines | spec 4.2a |

## Seeds

`03`: `set.seed(100000 * model_index + 100 * n + rep)` per dataset. `04`: `set.seed(3)` for the data, `set.seed(100 + i)` for the
extra starts. `04b`: data `set.seed(3)`, user starts `set.seed(11)`, multi-start `seed = i`. `05`: `set.seed(7)`.
`02` and `00`: seeds 1 and 2 inside the spike. Results are exactly reproducible on the same package versions.

## Known limits

- `03` uses the original (slow) objective so its timings are comparable with the spike; `05` shows the vectorized one is 23x faster per call.
- `03` counts a mismatch with lavaan as a failure; it does not separate "solver stalled" from "lavaan sits on another local solution".
- Sparse timings use synthetic lower-triangular matrices, not fitted models.
- Rsolnp and lbfgsb3c failed to link on the recording machine (local gcc path), so they are not benchmarked.
