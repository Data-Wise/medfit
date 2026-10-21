# GRILL: #249 comparison engines for constrained LR fits (2026-10-21)

Target: issue #249 and `planning/specs/PLAN-constrained-lr-solver-2026-10-19.md`. Codebase-first sweep found: medfit never calls
OpenMx or lavaan for the user (OpenMx is Suggests and gate-script only); Tiers 1 and 2, the `solver =` argument and the
`status` column are not implemented; plan §7.2 item 4 (`slsqp_legacy` for two minor releases, then removed) contradicts the
issue's D18 (SLSQP stays user-selectable, never default); `test-api-freeze.R` pins exported signatures.

## Decisions

| # | Question | Decision | Why |
|---|---|---|---|
| 1 | Home of the comparison path | A new exported function (working name `compare_lr()`), engines `openmx` and `lavaan`, Suggests guarded | Additive under the API freeze; the warnings need a code path to live in; an argument on `mbco_sem()`/`anova()` would break a frozen signature |
| 2 | When the warnings fire (amended 2026-10-21 after the Codex adversarial review) | Only on directly observed evidence, never from an LR value alone. OpenMx: warn when the returned parameters violate the product constraint (residual above tolerance) or the constraint has a zero Jacobian at the start; an LR of 0 by itself is not evidence, because a valid fit has LR = 0 when the unrestricted optimum satisfies the null. lavaan: warn when its statistic exceeds the restricted maximum by a margin, checked against an accepted comparable fit. Messages name the engine version tested. When medfit has no accepted comparable result, report the comparison as `unresolved` and assign no fault | A version-pinned blanket warning goes stale when upstream fixes OpenMx#433 or lavaan; LR = 0 alone would falsely accuse a valid fit |
| 3 | D18 and D20 | Split out of #249 into a new issue for the solver implementation (M3). #249 = comparison function, two detected-failure warnings, the "never pose `a*b == 0`" guard test, plan text synced | D18 needs the AUGLAG/Tier 0-1 path that does not exist; today SLSQP is the only constrained solver, and a `solver` argument is a frozen-signature change |
| 4 | Testing (amended with the review) | Injected engine results for unit tests, with cases: a constraint-violating OpenMx fit (warns); a **valid zero-LR null fit (must not warn)**; a lavaan statistic above the restricted maximum (warns); an **unresolved or rejected medfit branch (reports `unresolved`, no fault assigned)**; a planted no-detection defect. Plus a live gate in `tests/sim` that records engine versions and whether each known failure still reproduces and never fails on an upstream fix | Deterministic in `noSuggests`; the live part tracks upstream without going red; the two new cases are the false-accusation paths the review found |
| 5 | Release | Own 0.12.0 release, GitHub-only | New export is a minor; no solver behavior changes |
| 6 | SLSQP's fate (author, 2026-10-21) | **Keep SLSQP as a permanent, user-selectable backup; never the default.** The plan's `slsqp_legacy` two-release removal is dropped | Resolves the D18 vs §7.2-4 conflict. No behavior change until the AUGLAG/Tier 0-1 path exists, so SLSQP stays the only constrained solver for now |

## Oracle status (amended after the Codex review)

medfit's zero-product LR is exact in structure (the null set is a union of branches) but each branch is a numerical refit
(`R/sem-mbco.R`), and the solver plan says an unresolved branch makes the statistic unresolved
(`PLAN-constrained-lr-solver-2026-10-19.md` §7.2 item 1). The comparison treats medfit as the reference only when every
branch fit is accepted and the likelihoods are comparable; otherwise the result is `unresolved`.

## Tasks for #249

- [ ] `compare_lr()` (name to confirm at implementation): runs OpenMx or lavaan on the same model, reports their LR beside medfit's, flags disagreement beyond a tolerance
- [ ] Classed warnings (neutral wording), on observed evidence only: OpenMx constraint violated in the returned fit or zero Jacobian at the start; lavaan statistic above an accepted comparable restricted maximum; `unresolved` when no accepted comparable medfit result
- [ ] Guard test: `a*b == 0` is never posed as a constraint in medfit's own path
- [ ] Unit tests with injected engine results (incl. a valid zero-LR null fit that must not warn, and an unresolved branch) and a planted defect; live gate in `tests/sim` with a `gates.csv` row (report-only on upstream fixes)
- [ ] Refcard row, NEWS, `test-dependents-contract.R` and `test-api-freeze.R` updates for the new export
- [ ] Sync the plan: SLSQP stays selectable (decision 6), D18/D20 move to the solver issue

## Follow-on

The implementation plan is `planning/specs/PLAN-compare-lr-249-2026-10-21.md` (PR #277); its own grill (P1-P5: T0 go/no-go, model precheck, narrow class, two starts, tolerance) refines decisions 2 and 4 above.

## Open questions

- Function name and exact signature.
- Tolerance for "disagreement" between engine LR and medfit LR.
- The new solver-implementation issue (D18, D20, Tier 0/1/2, `status`, `require =`) is still to be filed.
