# Multilevel remainder: order of work (2026-11-18)

**Status:** active. Implementation is authorized for the sim-independent tasks below. **No release until the few-clusters
simulations (T6, and U4 that it feeds) are done.** Gap register: `PLAN-multilevel-implementation-gaps-2026-11-11.md`.
S4 source plan: `specs/PLAN-multilevel-mediation-2026-11-10.md` (copied here from branch `claude/plan-multilevel-394-f40512`,
`bff838ad`; sections 0.5 tolerances, 0.6 parser note, 0.8 S1 grill, 5 S4 sketch, 6 oracles, 7 risk tier).
Standing decisions unchanged: Q3 (fixed slopes), Q4 (contrast descriptive), Q8 and ADR D-11 (native fits error on a Heywood case).

Pipeline per task: `medfit-orchestrator` (worktree from `origin/dev`, implementer, oracle QA, gates, docs), one PR to `dev`
per task, merge only on the maintainer's word.

## Tasks

| # | Task | Gate | Risk tier | Output |
|---|---|---|---|---|
| U1 | Fix the S4 tolerances in writing (source plan 0.5) | sim-independent | low (docs) | ADR with a `decisions:` list |
| U3 | Three-way oracle agreement: hand-built O8 likelihood, lavaan, OpenMx | sim-independent | low (tests only) | test file plus helper |
| U2 | Native fixed-moment convention (source plan 0.8, S1-Q2) | sim-independent; **maintainer decision first** | low | decision, then oracle or guard |
| S4-dec | S4 decisions before code: parser `level:` names (0.6), U2 scope | maintainer | n/a | decisions in the ADR |
| S4a | Native two-level ML core: W/Z sets, per-size sufficient statistics, likelihood, gradient, SLSQP, joint vcov, per-level admissibility | sim-independent; **stop before code** | **high** (risk files) | feature branch, experimental label, seven-item checklist |
| S4b | Reliability cell, level-2 variance parametrization (floor vs unconstrained) | **gated on T6/U4** | high | gate rows, `structures.csv` |
| IG2 | Cluster-robust SEs (S6) | after S4 | high | scope note: [SCOPE-IG2-cluster-robust-se-2026-11-19.md](specs/SCOPE-IG2-cluster-robust-se-2026-11-19.md) |
| IG3 | Two-level tests (product null per level, equal indirect effects) | after S4; boundary law | high | scope note: [SCOPE-IG3-twolevel-tests-2026-11-19.md](specs/SCOPE-IG3-twolevel-tests-2026-11-19.md) |
| IG5s | Serial mediators at two levels | maintainer scope decision | n/a | decision only |
| IG4 | Random-slope estimand | NO-GO | n/a | reopens only if Q3 is reopened |
| IG6 | Latent mediators, shared loadings (S5) | NO-GO | n/a | reopens after U5 (Jak et al.; Heywood evidence) |

## Order

1. **U1** first: every later oracle is judged against these tolerances.
2. **U3** next. Two-level OpenMx was never tested (source plan section 6); it needs a relational (joined) model. A disagreement
   beyond the U1 tolerances stops the pipeline and goes to the maintainer.
3. **U2**: S1-Q2 already decided that native two-level defaults to `fixed_x = FALSE`. If S4 ships `fixed_x = FALSE` only, with a
   classed error for `fixed_x = TRUE` at two levels, U2 leaves the S4 blocker list and becomes a later oracle. Maintainer decides.
4. **S4-dec**, then **S4a** on its own branch under the experimental label. S4a may merge before T6 ends; it is not released.
5. **S4b** after T6/U4. Release checklist names T6/U4 as its only remaining gate.

## Stop points

- Before any S4 code.
- Any maintainer decision: U2 scope, parser names, serial scope, floor vs unconstrained.
- Any oracle disagreement beyond the U1 tolerances.

## Done when

U1 to U3 merged to `dev` with oracle evidence; S4a on a reviewed branch or merged as experimental; the release checklist names
T6/U4 as its only remaining gate.

## Progress

- [x] U1
- [x] U3 (2026-11-18): three-way oracle (hand-built O8, lavaan, OpenMx) merged in #483 (`10a7250e`)
- [x] U2 (decision, 2026-11-18): S4 ships `fixed_x = FALSE` only; `fixed_x = TRUE` on a two-level model is a classed error; the fixed-moment oracle is later work, not an S4 blocker
- [x] S4-dec (2026-11-18): native `level:` accepts integers, `within`/`between`, and the cluster variable's name (lavaan parity)
- [x] S4a (2026-11-19): S4a.1 to S4a.5 merged; S4a.1 #486, S4a.2 #489, S4a.3 #491, S4a.4 #492, S4a.5 in #493 (`707f53a7`)
- [x] IG2 (2026-11-19): CR0 cluster-robust SEs for the native two-level fit, #499 (`ae8a343e`); CLAUDE.md note #500
- [x] IG3 T-A (2026-11-20): `mbco_sem()` on native two-level fits, #501 (`9dc55c3e`)
- [x] IG3 T-B (2026-11-20): `twolevel_equal_indirect()`, #502 (`2b1c6311`); size gate made hard on the REPS = 2000
  baseline, #505 (`59969ebd`); sign-twin starts explained instead of warned, #507 (`b72971a9`). D6 (two-level
  `compare_lr()`) stays deferred.
- [ ] S4b (gated on T6/U4)
- [ ] IG5s serial scope (maintainer decision only)

## Release gate (reconciled 2026-11-21)

T6 is done (`studies/few-clusters/T6-results-memo.md`, 169,000 rows). U4 is produced by T8, which needs T6 and T7;
T7 (cluster bootstrap) is no-go until **M2** (bootstrap scope and compute) is decided. Remaining path to a release:
M2 decision -> T7 at the authorized scope, or M2 drops T7 -> T8 (decision table, U4 package, the T8 maintainer
questions: ICC source, unequal n = 5 non-convergence, P1/P2X mismatch) -> S4b, if the maintainer keeps it in the
release -> release checklist. Every sim-independent task above is merged.
