# Native SEM optimizer robustness plan (2026-10-20)

Invariant: every returned fit either agrees with an independent numerical oracle or carries an explicit warning/diagnostic; bad solver output is refused or retried. No wrong number is silently returned.

| Layer | Case | Expected verdict | State |
| --- | --- | --- | --- |
| 1: metamorphic | Scale each observed variable by 1e-3 and 1e3; row and syntax order; OLS paths | Accept, transformed natural-unit paths and unchanged discrepancy; OLS agreement | Implemented |
| 1: metamorphic | Redundant linear equality; equivalent linear expression; alternate starts | Accept, same estimates and discrepancy | Implemented |
| 2: fault injection | Status -1/-2/-3/2/5/6; nonfinite, out-of-box, inconsistent objective; thrown wrapper error | Refuse or retry with warning; status 4 accepted only at a gated optimum | Implemented; current-behavior exceptions recorded in tests |
| 3: edge-case grid | Near-singular covariance, tight bounds, constraint rank, scale extremes | Accept with oracle, warn, or refuse with reason | Not yet implemented |
| 4: randomized oracle sweep | Seeded model/data/start grid versus independent OLS or lavaan/OpenMx | Accept within tolerance, warn, or refuse | Not yet implemented |
| 5: cross-platform | Repeat frozen cases on Linux, macOS, Windows and alternate BLAS | Same verdict and numerical tolerance | Not yet implemented |

Tolerances: paths 1e-5 absolute after unit transport, discrepancy 1e-6, OLS paths 1e-5, constraint residual 1e-6. Use fixed seeds and 150-250 rows. A planted `.sem_solve_one` defect omits conversion from solver coordinates to natural units and must turn the scaled-fit test red; the existing redundancy defect test in `test-sem-constraints.R` covers the independent-row filter. Run only the two new files and lint in this worktree.

Current-behavior exceptions to the invariant: the unconstrained gate accepts a solver point outside a bound, and `.sem_optimize()` returns a solver-reported objective even when it differs from `F(theta)`. Both have `# BUG?` assertions in Layer 2; this test-only branch leaves implementation repair for a separate change.
