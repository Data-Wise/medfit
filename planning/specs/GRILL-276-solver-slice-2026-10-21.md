# GRILL: #276 after slice 1 (2026-10-21)

Target: next steps for medfit #276 once the floored comparator exists (PR #289 merged, #290 draft). Inputs: `PLAN-floor-comparator-276-2026-10-21.md` (AR1-AR7, G1, G2), `PLAN-constrained-lr-solver-2026-10-19.md`, `.github/workflows/gates.yaml`. Five branches, one question each; option 1 was the Recommended answer in every branch and was chosen.

## Decisions

| # | Branch | Decision | Consequence accepted |
|---|--------|----------|----------------------|
| D1 | #290 outcome if any runner dispatch shows a disproved floor row | #290 stays draft as the failing test; counts go to #276; it lands together with the solver fix | the floor gap stays unguarded on `dev` until the solver slice ships; `dev` stays green |
| D2 | where `gates` is a required check | required on `main` only (branch-protection change on `main`, maintainer's setting); `dev` stays advisory | a gate regression can sit on `dev` until the next release PR; zero-disproved is enforced at release time |
| D3 | solver slice scope | decided from the measured runner data: zero disproved -> status plumbing only; any disproved -> in-package outer certificate for the standardized-mediation constraint first (a disproved fit becomes a refit or `unresolved`) | decision waits for the 5 dispatches; no speculative solver work; Tier 1 charts and AUGLAG stay out until the plan's benchmark rule for q != 0 passes |
| D4 | how status reaches users | `certification` field in `SEMFit@diagnostics$optimum` only; no argument added to `fit_sem()`/`fit_mediation()`; `require =` and `solver =` deferred | users can read but not refuse weaker statuses yet; `test-api-freeze.R` untouched |
| D5 | status vocabulary | `exact` (every zero-product branch converged, best taken), `local` (best accepted start, no independence claim), `unresolved` (independent check disproved it or a necessary branch failed); `charted` is added only when Tier 1 ships and passes its benchmark | no label without a producer; avoids the global-optimum misreading (Codex findings 6, 7) |

## Open questions

- The 5 gate dispatches on `feature/floor-gate-276` (post-G2 head) decide D1 and D3; record the per-run floor-row counts in `.STATUS` and on #276.
- The `main` branch-protection change (D2) is the maintainer's to make; not done by this session.
- Syncing the older plan's `slsqp_legacy` text to D18 (permanent backup) is still owed.
