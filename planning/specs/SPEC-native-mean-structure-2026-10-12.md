# SPEC: Mean structure for the native SEM engine

**Status:** draft | **Date:** 2026-10-12 | **Target:** 0.9.0 (GitHub-only, like 0.5.0 to 0.8.0)
**Source:** [BRAINSTORM-native-mean-structure-2026-10-12.md](BRAINSTORM-native-mean-structure-2026-10-12.md)

## User story

As a medfit user fitting a model with `fit_sem()` or `fit_mediation(engine = "native")`, I want to write `y ~ 1` (intercepts, exogenous means, latent means) and have the engine fit the mean structure by maximum likelihood, so that I get lavaan-comparable intercepts and likelihoods, constrained-intercept models, and a base for four-way decomposition, without leaving medfit.

## Scope

**In:** observed intercepts; exogenous means; latent intercepts and means with identification checks; `meanstructure` argument plus auto-on when `~1` appears; weights and the sandwich covariance; `anova()`, `mbco_sem()`, `tidy()`, `glance()`, `coef()`, `vcov()`; constraints (linear and nonlinear) on intercepts.

**Out (follow-ups):** four-way decomposition via native `extract_mediation()`; multi-group; FIML for missing data (listwise stays); robust chi-square.

## Behavior

1. A model with no `~1` term and `meanstructure` unset fits exactly as in 0.8.0 (same estimates, `logLik`, df).
2. A free or nonzero-fixed `~1` turns the mean structure on; `meanstructure = TRUE` turns it on with saturated free intercepts for the observed variables (lavaan semantics); `meanstructure = FALSE` with a free `~1` is an error that names the term.
3. ML discrepancy adds `(xbar - mu)' Sigma^-1 (xbar - mu)`, `mu = F (I - A)^-1 m`; coefficient names follow lavaan (`y~1`).
4. A latent variable with a free mean and no fixed/constrained indicator intercept stops with a message naming it.
5. `anova(fit0, fit1)` refuses fits that differ in mean-structure status.
6. `extract_mediation(<SEMFit>)` returns the same effects as the covariance-only fit for the same model; intercept rows never enter effect or path SEs.

## Acceptance criteria

- [ ] Saturated free intercepts reproduce the covariance-only estimates, SEs, df, and chi-square to 1e-6.
- [ ] Estimates, SEs, and logLik match lavaan `meanstructure = TRUE` to 1e-4 on the four model forms (simple, serial, parallel, latent mediator); sandwich SEs match lavaan `sampling.weights`.
- [ ] OpenMx reaches the same optimum on a constrained-intercept model (`skip_if_not_installed("OpenMx")`).
- [ ] Analytic gradient and information equal finite differences with a theta-dependent mean.
- [ ] Planted defects each fail a named test: gradient without `dmu`; information with the cross block zeroed; scores centered at the sample mean.
- [ ] Nonlinear constraint gate (`tests/sim/sem-nonlinear-gate.R`) passes with intercept variants.
- [ ] The "no mean structure" statements are gone from `R/fit-sem.R`, `man/fit_sem.Rd`, four articles, and the lavaan comparison table row flips (verified live).
- [ ] Full suite green and `R CMD check --as-cran` clean; strict-flavor check run before any submission.

## Phases

| Phase | Content | Gate |
|---|---|---|
| 1 | Parser/table: accept `~1`, `meanstructure` arg; RAM `m` vector; `mu`; discrepancy + gradient + information; `.sem_sample()` keeps raw data and `xbar` | gradient vs finite differences; saturated-equals-covariance regression |
| 2 | Scores, sandwich, weights; df and counts; `anova()` refusal | lavaan sandwich parity |
| 3 | Constraints and `mbco_sem()` with intercepts | nonlinear gate variants |
| 4 | Latent means and identification | lavaan table per model form; OpenMx parity |
| 5 | `SEMFit` methods (`coef`, `vcov`, `tidy`, `glance`, `logLik`), extraction skips intercepts | extraction equality test |
| 6 | Docs, NEWS, `.STATUS`, CLAUDE.md | doc currency check; link and count tests |

## Test plan

| Tier | Plan |
|---|---|
| unit | parser, `S + d d'` identity, `dmu` Jacobian, identification checks |
| regression | saturated-equals-covariance-only |
| integration | `fit_sem()` and `fit_mediation(engine = "native")` end to end with weights and sandwich |
| dependency | lavaan and OpenMx parity |
| planted defect | three mutants above, via `MUTANT=` switches |
| N/A | count-cascade: no new command, skill, or agent |

Stubs are red-first, each with `# TODO(author): delete if not contract-bearing`.

## Documentation

NEWS `[Unreleased]`; `?"medfit-syntax"`; `man/fit_sem.Rd`; `model-native.qmd`, `native-guide.qmd`, `model-native-multi.qmd`, `guide-troubleshooting.qmd`; lavaan comparison table; `methods.qmd` (discrepancy with mean term); CLAUDE.md Engines row; `.STATUS`. Version and count lines are excluded (handled at release).

## Risks

Block-diagonal information assumption; latent-mean identification; scope (largest option chosen: phase 4 may split into its own release if phase 1 to 3 land cleanly); AIC/anova comparability; SLSQP with intercepts under nonlinear constraints. Detail in the BRAINSTORM.

## Open questions

1. lavaan's auto-fixed latent rows under `meanstructure = TRUE`; verify before phase 4.
2. Does `.sem_step_floor()` need a mean term?
3. Expose `meanstructure =` on `fit_mediation(engine = "native")` or syntax-only?

## Next

`/craft:plan planning/specs/SPEC-native-mean-structure-2026-10-12.md` for the task breakdown, ahead of a feature branch from `dev`.

---

Grill decisions and errata (supersede where they differ): [GRILL-native-mean-structure-2026-10-12.md](GRILL-native-mean-structure-2026-10-12.md)
