# Multilevel implementation gaps: register and unblock conditions (2026-11-11)

**Status:** planning only; nothing here is authorized. Source: `specs/LIT-multilevel-sem-gaps-2026-11-11.md` sections 5.2 to 5.4
(ranking and evidence live there; this file does not repeat them). The roadmap's [Current board](medfit-roadmap.md#current-board)
owns priority. Standing decisions stay: Q3 (fixed slopes, `sigma_ab = 0`), Q4 (the contrast is descriptive), Q8 and ADR D-11
(native fits error on a Heywood case). The release is not authorized; none of this is in 0.17.0.

## Gap register (medfit side)

| ID | Gap | Cost | State | Blocked by |
|---|---|---|---|---|
| IG1 | Native two-level ML, observed, fixed slopes (S4) | L | NO-GO as written | U1 to U4 below |
| IG2 | Cluster-robust SEs and few-cluster adjustments (S6) | M after S4 | not started (code); scope note: [specs/SCOPE-IG2-cluster-robust-se-2026-11-19.md](specs/SCOPE-IG2-cluster-robust-se-2026-11-19.md) | IG1 |
| IG3 | Two-level tests: product null per level, equal indirect effects across levels (optional, separate from the descriptive contrast) | M to L after S4 | not started (code); scope note: [specs/SCOPE-IG3-twolevel-tests-2026-11-19.md](specs/SCOPE-IG3-twolevel-tests-2026-11-19.md) | IG1; boundary-aware reference law |
| IG4 | 1-1-1 random-slope estimand, `E[ab] = ab + cov(a_j, b_j)` | L, new class | needs a decision to reopen Q3 | maintainer |
| IG5 | More than one mediator in a two-level model (the adapter refuses it) | M | done for parallel mediators (experimental `TwoLevelParallelMediationData`, PRs #460 to #463 and the T5 docs; plan `planning/PLAN-IG5-twolevel-parallel-2026-11-15.md`); serial mediators still refused | none |
| IG6 | Latent mediators with shared loadings (S5) | L on top of S4 | NO-GO | identification review (U5) |
| IG7 | Level-specific fit, two-level FIML, categorical, three-level, Bayesian | M to XL | deferred or out | IG1; scope |

## Unblock conditions for IG1 (S4)

- **U1** The plan's tolerances (plan 0.5) are fixed in writing.
  Done 2026-11-18: `planning/specs/ADR-twolevel-oracle-tolerances-2026-11-18.md` (TL-1 to TL-7).
- **U2** The native fixed-moment convention has an oracle (plan 0.8, S1-Q2).
- **U3** Oracles agree: the hand-built O8 likelihood, lavaan, and OpenMx.
- **U4** A reliability grid with small-J, low-ICC and unbalanced cells, plus a level-2 variance parametrization experiment (floor versus unconstrained), with Q8 and D-11 unchanged.
  **Met 2026-11-23** (few-clusters study T8): the grid (120 cells, R = 1000) and the lavaan default-versus-floor experiment (49 cells, paired) are done, Q8 and D-11 are unchanged, and the U4 package is `studies/few-clusters/T8-README.md`
  (per-cell table, P0/P1 comparison, adapter-threshold evidence, decision table, P1 selection rule).
  Limits: the cluster-bootstrap arm was not run beyond six pilot cells (T7 dropped 2026-11-21, later work, not a gate); the P1 arm is a lavaan proxy and does not settle the native S4 parametrization (S4b, plan section 5, M5); the decision table is the delta and MC verdict under the M8 failure cutoffs, with a coverage rule left to the maintainer as a labeled proposal.
- **U5** (for IG6 only) The identification literature (Jak et al. shared loadings; Heywood evidence) is read; still open.

The seven-item admission checklist applies to any S4 PR: the solver files are on `tests/sim/risk-files.txt`.

## Order if work is authorized

1. The few-clusters design study (proposal 2 in the book repository) supplies the U4 grid and needs only the shipped adapter.
2. IG5 is done for parallel mediators; serial two-level mediation would need its own scope decision.
3. S4, then IG2 and IG3. IG4 only if Q3 is reopened.

## Not decided here

Whether to start any of this before the 0.17.0 release; the maintainer decides.
