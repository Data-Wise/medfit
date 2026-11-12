# Issue #369: shipped work versus unresolved solver scope

Status: clause-level reconciliation complete locally, 2026-10-31 MDT. Source:
released main/tag `c37c7ee8b1cd1e47d0d61f3d55b0a5fce335c7cc`; dev `f1aaf332`.
No numerical implementation or acceptance guarantee changes. This is source/test
inspection, not a fresh numerical or external-engine run. The separately reviewed
NEWS correction is PR #376, not part of this worktree.

## #249 clause dispositions

| Existing clause | Disposition | Owning evidence / remaining action |
|---|---|---|
| Run OpenMx/lavaan on the same model and report their LR beside medfit; flag disagreement | Shipped | `R/compare-lr.R`: `.lr_reference()` calls `mbco_sem()`; assessment checks model/context/full-fit agreement and LR/residual discrepancies. `compare_lr()` selects lavaan/OpenMx. `R/compare-lr-openmx.R` and the lavaan adapter retain default/zero starts. `tests/testthat/test-compare-lr.R` and `test-compare-lr-openmx.R` cover these routes. |
| Neutral, classed constraint-dropped/statistic-above-reference warnings | Shipped | `R/compare-lr.R:109-120`; observed-evidence conditions retain `medfit_warning_engine_constraint_dropped` and `medfit_warning_engine_statistic_above_max`. The warnings do not establish an external global maximum. |
| Do not pose the zero-product constraint to medfit's own solver | Shipped | `.lr_reference()` delegates to `mbco_sem()`; `test-compare-lr.R:42` explicitly guards this route. |
| D18: SLSQP selectable, never default, with Tier 0/1 cross-check | Not satisfied by released implementation | `R/sem-optim.R:383` defaults to `NLOPT_LD_SLSQP`; `fit_sem()` has no explicit Tier 0/1 solver-selection contract. Existing `control` algorithm overrides are not fulfillment of this entire clause. Retain for owner scope decision; do not silently change the optimizer. |
| D20: standardization always on | Unresolved as written | `.sem_solve_one()` uses natural-parameter preconditioning by default and supports `precondition = FALSE` internally (`R/sem-optim.R:80-82`). This is not proof of the imported plan's universal data-standardization requirement. Define the intended model/solver domain before deciding satisfied, revised or deferred. |
| Sync imported merged solver plan | Unresolved | `planning/specs/PLAN-constrained-lr-solver-2026-10-19.md` is an explicitly upstream-owned snapshot and still says drop SLSQP. It is now labeled historical with this reconciliation pointer; the upstream source was not edited or re-synchronized. |

The remaining solver clauses are not new post-release defects established by
this reconciliation: they are unfulfilled or unclear design obligations. #320
remains the known, correctly flagged external-engine limitation. No change to
external engine warning text or upstream OpenMx issue #433 was made.

## #357 reduced first milestone

Delivered by PR #361 (`446cf12d`) and shipped in 0.16.0. Current source/help/tests
cover the supported independent nonzero product, both sign branches, unresolved
branch refusal, separate validated `search_evidence`, actual attempt/status
preservation, matching existing-reference SEs without refits, and independent
regressions. See `R/sem-nonzero.R` (including `.sem_validate_search()`), `R/fit-sem.R:144-166`,
`tests/testthat/test-sem-nonzero*.R`, and the completed #357 plan.

Global certificates, general coupled-product charts and broad cross-API reporting
were excluded from that reduced milestone. They are separate unassigned designs,
not unfinished #357 acceptance. #357 remains open as of inspection; owner issue
closure is administrative and was not performed in this #369-only update.

## Other lifecycle item

#360's bounded boundary-oracle regression shipped through PR #363 (`edcf23d8`)
and `tests/testthat/test-sem-boundary-oracle.R`; its issue remains open. Numerical
agreement in those designs is not a general global-convergence proof. No closure
or title change was made to #360.

## Next disposition

Update #369 with these clause-level results, keeping it open for applying the
appropriate #249 task-box changes and owner closure/re-scoping of #357/#360.
Do not create duplicate solver/roadmap issues or restart completed release gates.
The [roadmap current board](medfit-roadmap.md#current-board) owns future ordering;
no version/date or implementation is assigned here.
