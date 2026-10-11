# Evidence fixtures: S1 findings re-derived and audit F1 reproduced (2026-10-11)

Plan task T1 (`tasks/plan.md`, ledger G5). The 2026-10-09 `s1-review` scripts are gone from disk and from git, so nothing here is
recovered: each S1 finding is re-derived from the surviving `../native-sem-2026-10-08/04b-constraint-contract.R` and
committed as a fixture that can fail. Exploratory code, not package code; nothing here is installed or exported.

## Run

```sh
cd planning/specs/evidence/native-sem-2026-10-11
./run-all.sh        # about 3 minutes; writes results/<script>.out; deletes each old output first; exits nonzero if any ASSERT fails
```

Each script runs from this directory (it sources `../native-sem-2026-10-08/common.R` and loads the package from the root four levels up).
The fixtures are seeded; two consecutive runs give byte-identical results apart from the warning lines and the R version line.

## Fixtures

| Script | Finding | Oracle (what makes it able to fail) | Result |
|---|---|---|---|
| `01-stationarity-units.R` | Q14: the 04b stationarity measure depended on the units of the data | Part A: the 04b table (61 starts on `a*b == 0`, the stalled start `(0,0,0,.5,.5)` plus 60 seeded random starts) at data scales 0.01, 1 and 100. ASSERTs: the 04b measure's largest converged value moves at least 100-fold across scales while the Newton decrement's moves at most 10-fold; at every scale converged decrements are at most 1e-4 and the stalled start's is at least 1e-2. Part B: the 0.7.0 gate itself (`.sem_fit_syntax()`, `.sem_gate()`) on the linear cells 04b's real runs used (`a + b == 0.2`, `a + b < 0.2`, `a + b > 0.2`, and no constraint) at the same scales. ASSERTs: every fit accepted, decrements at most 1e-6, estimates identical across scales, truncated runs far from the optimum at least 1e-2 | 04b measure on converged solutions: 6.1e-4 at scale 0.01, 4.0e-8 at scale 1 (15,000-fold); decrement: 6.9e-8, 3.1e-8, 7.8e-8 (2.5-fold). 0.7.0 gate: max decrement 1.3e-8 over 12 fits, smallest truncated decrement 7.4e-2 |
| `02-nnls-dependent-columns.R` | S25 / audit F5: the 04b NNLS divides 0/0 on dependent columns | `nnls()` copied verbatim from 04b. Two rank-deficient families (a duplicated and a summed column; the `t(rbind(Jineq, Jeq, -Jeq))` layout 04b's `kkt_general()` builds, which is rank deficient whenever an equality is active) at scales 1 to 1e6, 500 seeds each. ASSERTs: every problem is rank deficient; no failure at scale 1 (control); failures at scale 1e4; the first failing case, replayed with an instrumented copy, has a step length of exactly 0/0 for a column that entered with a weight above the 1e-12 absolute tolerance | failures of 500: 0 at scale 1; 118 to 146 (`dup`) and 240 to 269 (`mult`) at scales 1e2 to 1e6. Mechanism confirmed: seed 13, scale 1e4, weight 1.8e-8 |

`results/02-nnls-fixture.csv` is the hand-off to T7: the smallest failing `dup` case at scale 1e4 (matrix `A1..A5`, `b`) with the
reference solution from bounded least squares on the column-normalized problem. The T7 port must return a non-negative solution
whose squared residual on the normalized problem is within 1e-8 of that reference's, with no NaN and no error.

Positive control for fixture 2 (run a patched copy from a scratch directory: the script writes `results/` relative to where it runs, and an earlier run of the patched copy here overwrote `02-nnls-cases.csv` with all-ok rows, which was caught and regenerated): replacing the verbatim `nnls()` default `tol = 1e-12` with `1e6` (which never admits a column) makes
the "defect reproduces" ASSERT fail and the script exit nonzero.

`03-redundant-inequality-sets.R` (audit F1, plan T6) is the third fixture: nine constraint sets by 12 seeded datasets on the 0.7.0 code and on
a prototype that drops implied, satisfied inequality rows. ASSERTs: every coincident set fails on some seed (5 to 7 of 12 fit), the controls fit
12 of 12, the prototype fits all consistent sets and matches the independent set to 1e-6, and an inconsistent set still errors naming the
violated constraint. A near-dependence ladder (`a == b; a - b + k*cp > 1e-7`, k from 1e-6 to 1e-14) shows why the T6 rule drops an implied
row but never raises an error before the solve: the 1e-8 error rule would reject 5 of the 6 feasible sets, the 1e-12 drop-only rule rejects none. Background and design: `../../RESEARCH-redundant-constraints-2026-10-11.md`. Once T6 ships, the "defect reproduces"
assertion is inverted to "fixed" and the prototype is deleted.

## What these fixtures do not claim

- **Part A runs on the exploratory engine, not on 0.7.0.** 0.7.0 has no nonlinear constraints (that is W3), so `a*b == 0` cannot go
  through `.sem_gate()`. Part A compares the two stationarity measures on the same solver output; Part B then runs the real 0.7.0
  gate on the cells that are linear (the ones 04b's real runs used). The decrement in Part A uses the plain Hessian of F on the
  null space of the constraint Jacobian, as the linear gate does; the Lagrangian Hessian is W3's (T13).
- **Scale 0.001 is left out of Part A on purpose.** `common.R`'s `fml()` rejects an implied covariance whose smallest eigenvalue is
  at most 1e-10, an absolute test, so at that scale it rejects every start. That is the exploratory engine's own unit dependence, not
  the stationarity measure's; the package's `.sem_eval()` is not affected (Part B includes scale 0.01 and 100 through it).
- **At scale 0.01 the 04b measure stays below its 1e-3 threshold** (6.1e-4), so it does not yet reject a converged fit in these
  cells. The finding reproduced is the dependence on units (15,000-fold), with the safety margin shrinking from 2.5e7 to 1,600.
- **The NNLS failure is synthetic.** The S1 review found 0 of 32 real fits affected (audit F5). The fixture shows the code path is
  unsafe once a dependent column meets an absolute tolerance; it does not show 0.7.0 fits are wrong (0.7.0 skips the sign check when
  the active rows are linearly dependent, `R/sem-constraints.R`, and F1 will let such sets through, which is why T7 needs the fix).

## Versions

R 4.6.1; nloptr 2.2.1; medfit 0.7.0 (this worktree, branch `feature/0-8-0-foundations`, off `dev` at `2930cf4`). macOS.
