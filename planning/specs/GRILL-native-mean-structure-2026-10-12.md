# GRILL: native mean structure (medfit)

| | |
|---|---|
| **Date** | 2026-10-12 |
| **Target** | [SPEC-native-mean-structure-2026-10-12.md](SPEC-native-mean-structure-2026-10-12.md) (draft) |
| **Brainstorm** | [BRAINSTORM-native-mean-structure-2026-10-12.md](BRAINSTORM-native-mean-structure-2026-10-12.md) |
| **Status** | 5 decisions (G1 pre-answered from the code; G2-G5 asked). The SPEC body is not rewritten; the errata and the changed scope below supersede it where they differ, and the plan must carry them. |

## Decision Ledger

| # | Branch | Decision |
|---|---|---|
| G1 (pre-answered, shown for override) | Is the mean/covariance information a "cross block"? | **No: it is additive over the same theta.** Under normality `I_jk = dmu_j' Sigma^-1 dmu_k + (1/2) tr(Sigma^-1 dSigma_j Sigma^-1 dSigma_k)`; there is no mean-covariance cross term. Evidence: `.sem_info_expected` (`R/sem-ml.R:238`) is the covariance part only, so it needs the mean term added. The BRAINSTORM's "cross block" wording and its planted defect "zero the information cross block" are replaced by "omit the mean term from the information". Scores likewise gain an additive `dmu' Sigma^-1 (x_i - mu)` term. |
| G2 | Release shape: one release or split? (weakest recommendation) | **Split: observed first, latent later** (recommended). Latent mean/intercept rows keep a clear "not yet supported" error until lavaan's identification rules are verified (open question 1). Supersedes the SPEC's all-phases-in-0.9.0 target. |
| G3 | How do covariance-only fits stay untouched? (implementation regret) | **One code path gated by a `has_mean` flag, plus a gate:** F, gradient, SEs, and logLik on the existing frozen and OpenMx fixtures match 0.8.0 to 1e-12 with the flag off (recommended). Consequence: edits to `.sem_eval`/`.sem_scores`/`.sem_sample` are covered bit for bit; no second copy of the numerics. |
| G4 | Four-way via native: this release or follow-up? (benefit honesty) | **Pulled forward** (recommended was: proceed with an honest NEWS and one constraint example). Reverses brainstorm decision 5. Honest benefit statement still required: in a saturated-mean fit paths, NIE, NDE, and SEs equal today's; the payoff is constrained intercepts and four-way. Four-way needs only observed intercepts (E[M \| X = 0]), so it does not wait for latent means. |
| G5 | X×M representation for four-way | **Add a `:` product operator to the native grammar** (recommended was: a user-supplied product column). This amends the frozen `SPEC-sem-grammar-2026-10-08.md`; the amendment needs its own approval before any parser work (see Open Questions). |
| G6 | Sequencing (reversibility and scope creep) | **Three releases:** 0.9.0 observed mean structure (SPEC phases 1-3, 5, 6); 0.10.0 grammar amendment, `:` operator, four-way via native; 0.11.0 latent means (SPEC phase 4). Each gated by its own oracle (recommended). Supersedes the SPEC's single 0.9.0 target. |

## Open Questions

- **Grammar amendment spec** (new deliverable, before 0.10.0): a `:` operator makes the product a derived variable, not an observed column. Its variance and covariances with X and M, how it enters the likelihood (random product vs. conditioned on X and M), and how `extract_mediation()` reads it are undecided. The frozen spec needs an explicit approval to amend.
- Which rows lavaan auto-fixes for latent variables under `meanstructure = TRUE` (gates 0.11.0).
- Does `.sem_step_floor()` (`R/sem-ml.R:278`) need a mean term?
- Expose `meanstructure =` on `fit_mediation(engine = "native")` or syntax-only?
- Four-way oracle: VanderWeele four-way components against `regmedint` and the glm four-way path on the same data (to settle in the 0.10.0 plan).
