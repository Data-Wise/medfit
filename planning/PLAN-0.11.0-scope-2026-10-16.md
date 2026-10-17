# PLAN: medfit 0.11.0 scope (2026-10-16)

**Status:** proposal for the author's decision; nothing implemented. Produced by a read-only Plan agent (Opus) from
`.STATUS`, the two 0.10.1/0.11.0 proposals, the roadmap, the specs, NEWS, and open issues and PRs. Two claims were
re-checked by hand: PR #214 and issue #213 exist as described. Not verified: that CRAN 0.3.2 fails under development
S7 (inferred from the shared nullable-union pattern), the S7 1.0 CRAN date, whether #214 passes medfit's suite, and
whether probmed adopted `fit_sem()` for P_med MBCO or only evaluated it.

## Recommendation: Option B (middle), about 3-4 working days

Ship everything on `dev`, plus **#214** (S7 compatibility), a **narrow fix for #213**, and a written
**exit-criteria file for the "experimental" label**. Latent means, Ext D module 2 and Ext E stay out.

1. **#214 cannot wait.** An S7 maintainer opened it today: medfit "fails to install or load with development S7".
   S7's main branch heads a 1.0.0 with breaking changes. CRAN 0.3.2 has 18 nullable property unions (dev has 23), so
   CRAN medfit is likely exposed too. That would be a third CRAN trigger outside GRILL-0.8.0-release R1.
2. **#213 is the only item with a named consumer** (probmed, evaluating `fit_sem()` for MBCO intervals). Reproducer and
   workaround (`Vm > 1e-4`) are in the issue.
3. **The `dev` content is done and green:** strict check 0/0/0, 6340 tests pass, docs gaps closed (#216, #217).
4. **"Drop experimental at 0.11.0" is a recorded commitment** (`.STATUS` `fixed_x_and_experimental`, GRILL G13, criteria
   undefined), and RMediation's CRAN hold depends on it. Write the criteria now; drop the label at the first release
   that meets them.

## Candidates

| # | What | Size | Risk | Consumer |
|---|---|---|---|---|
| F1 | Ship `dev` as is (factor covariates, covariate-mean variance, AIC/BIC guard, docs) | S, ~0.5 d | low | users, probmed |
| F2 | S7 compatibility, PR #214 (targets `main`; port to `dev`) | S, 3-5 h | med (`.onLoad`/`.onUnload`) | everyone |
| F3 | #213: variance floor or step rejection only with nonlinear constraints; flag a status-3 stop far above the optimum | M, 1-1.5 d | med (optimizer behavior) | probmed, RMediation |
| F4 | Exit criteria for "experimental" | S, 1-2 h | low | RMediation |
| F5 | Register the factor gate in `run-gates.R`/`gates.csv` | S, 2-3 h | low | release evidence |
| F6 | Triage the 2 skips and 42 warnings; pandoc `--mathjax` deprecation | S, 2 h | none | maintainers |
| F7 | `bootstrap_mediation()` helper for four-way | S-M, 0.5 d | low | users (recipe 20 covers it) |
| F8 | Latent means | L, 5+ d | med-high | none named |
| F9 | Ext D module 2 (1-1-1) / Ext E | L, weeks | high | none named |
| F10 | Hygiene: close #130, refresh roadmap Next Actions | S, 1 h | none | none |

## Options

| | A Minimal | **B Recommended** | C Ambitious |
|---|---|---|---|
| Includes | F1, F2 | F1-F6, F10 | B plus F7, F8 |
| Effort | ~1 d | ~3-4 d | ~2 wk |
| Slips | nothing | F3 if it changes unconstrained fits | F8 (identification, parity gates) |
| Downside | ships a known probmed bug | slightly later | feature with no consumer |

## Tasks for B (feature branch from `dev`, squash to `dev`, red tests first, suite green after each)

1. **T1 S7 compatibility:** port #214 onto a `dev` branch (or ask the contributor to retarget it to `dev`; never
   `main`); fold its NEWS bullet into the development section; red test `test-s4-registration.R`; suite on S7 0.2.2 and
   `RConsortium/S7@main`; e2e transcript (install, load, unload, reload).
2. **T2 #213 red tests:** the issue's two seeds (LR about 0 at the unconstrained estimate) plus one unconstrained fit
   that must stay bit-identical (frozen fixture).
3. **T3 #213 fix:** floor or step rejection when nonlinear rows exist; non-convergence flag on a far status-3 stop;
   oracle is the issue's 30-case profile-inversion agreement (about 2.5e-7); planted defect (remove the floor, the test
   must fail); NEWS behavior note; e2e with the reproducer.
4. **Checkpoint 1:** adversarial review of T3; if any unconstrained fit changes, narrow the fix.
5. **T4 factor gate registration:** verdict function, `gates.csv` row, `MUTANT=` defects exit 1.
6. **T5 experimental-exit GRILL:** criteria (no open correctness issue on the engine, every native gate registered and
   green, lavaan and OpenMx parity green, an API freeze list); record the decision; the author pastes the RMediation
   message.
7. **T6 hygiene:** triage notes in `.STATUS`; roadmap refresh; close #130 at release.
8. **Checkpoint 2 (release gate):** full suite, `lintr` after `load_all()`, strict check (CLAUDE.md recipe),
   `urlchecker::url_check()`, `spelling::spell_check_package()`.
9. **Release:** bump to 0.11.0; NEWS header; `.STATUS` and CLAUDE.md "Current status"; grep for "0.10.0" leftovers;
   `dev` to `main` merge-commit PR with the evidence summary; CI green on `main`; tag `v0.11.0`; GitHub release;
   r-universe via the packages list (allow about 2 h, no manual dispatch); pkgdown deploys from `main`; back-merge.

## Decisions for the author

| # | Decision | Recommended |
|---|---|---|
| D1 | Does S7 1.0 force CRAN action, and how: a 0.3.3 patch from the v0.3.2 tag, or submit 0.11.0? | Confirm the S7 date and any CRAN mail first. If forced, submit 0.11.0 (it also fixes the #83 bugs and unblocks probmed's `medfit (>= 0.3.0)` gate); fall back to 0.3.3 only if the deadline is under 2 weeks |
| D2 | #213 scope: floor only with nonlinear constraints, or always | Only with nonlinear constraints (an always-on floor changes every fit) |
| D3 | Drop "experimental" in 0.11.0 | No: write the criteria now, drop the label at the first release that meets them |
| D4 | Include F7 | No, recipe 20 covers it |
| D5 | Latent means | 1.0, or later if no consumer appears; record in the roadmap |

## Risks

- S7 1.0 has other breaking items (`convert()`, subclass constructors, `S7_on_build()`); a grep found no `convert()` or
  `parent =` in the class definitions, but there was no full audit.
- The #213 fix may move optimizer paths in existing constrained fits; frozen fixtures and gates are the guard.
- `mediation-planning/PROJECT-HUB.md` is stale (lists medfit 0.2.1); the roadmap's Next Actions is stale (2026-10-10).
- RMediation's own "mature" trigger is undefined (its `.STATUS`, 2026-10-13 hold).
