# GRILL: #249 comparison engines for constrained LR fits (2026-10-21)

Target: issue #249 and `planning/specs/PLAN-constrained-lr-solver-2026-10-19.md`. Codebase-first sweep found: medfit never calls
OpenMx or lavaan for the user (OpenMx is Suggests and gate-script only); Tiers 1 and 2, the `solver =` argument and the
`status` column are not implemented; plan §7.2 item 4 (`slsqp_legacy` for two minor releases, then removed) contradicts the
issue's D18 (SLSQP stays user-selectable, never default); `test-api-freeze.R` pins exported signatures.

## Decisions

| # | Question | Decision | Why |
|---|---|---|---|
| 1 | Home of the comparison path | A new exported function (working name `compare_lr()`), engines `openmx` and `lavaan`, Suggests guarded | Additive under the API freeze; the warnings need a code path to live in; an argument on `mbco_sem()`/`anova()` would break a frozen signature |
| 2 | When the warnings fire | Only on a detected failure, using medfit's exact zero-product LR as the oracle; the message names the engine version tested | A version-pinned blanket warning goes stale when upstream fixes OpenMx#433 or lavaan; detection is independent of versions. Non-zero-product constraints get the disagreement flag only |
| 3 | D18 and D20 | Split out of #249 into a new issue for the solver implementation (M3). #249 = comparison function, two detected-failure warnings, the "never pose `a*b == 0`" guard test, plan text synced | D18 needs the AUGLAG/Tier 0-1 path that does not exist; today SLSQP is the only constrained solver, and a `solver` argument is a frozen-signature change |
| 4 | Testing | Injected engine results for unit tests (LR = 0 on a product null; a statistic above the exact one) with a planted no-detection defect; plus a live gate in `tests/sim` that records engine versions and whether each known failure still reproduces and never fails on an upstream fix | Deterministic in `noSuggests`; the live part tracks upstream without going red |
| 5 | Release | Own 0.12.0 release, GitHub-only | New export is a minor; no solver behavior changes |
| 6 | SLSQP's fate (author, 2026-10-21) | **Keep SLSQP as a permanent, user-selectable backup; never the default.** The plan's `slsqp_legacy` two-release removal is dropped | Resolves the D18 vs §7.2-4 conflict. No behavior change until the AUGLAG/Tier 0-1 path exists, so SLSQP stays the only constrained solver for now |

## Tasks for #249

- [ ] `compare_lr()` (name to confirm at implementation): runs OpenMx or lavaan on the same model, reports their LR beside medfit's, flags disagreement beyond a tolerance
- [ ] Classed warnings (neutral wording): OpenMx dropped or zero-Jacobian product constraint; lavaan statistic above the exact restricted maximum
- [ ] Guard test: `a*b == 0` is never posed as a constraint in medfit's own path
- [ ] Unit tests with injected engine results and a planted defect; live gate in `tests/sim` with a `gates.csv` row (report-only on upstream fixes)
- [ ] Refcard row, NEWS, `test-dependents-contract.R` and `test-api-freeze.R` updates for the new export
- [ ] Sync the plan: SLSQP stays selectable (decision 6), D18/D20 move to the solver issue

## Open questions

- Function name and exact signature.
- Tolerance for "disagreement" between engine LR and medfit LR.
- The new solver-implementation issue (D18, D20, Tier 0/1/2, `status`, `require =`) is still to be filed.
