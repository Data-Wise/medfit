# GRILL: medfit Extension D — multilevel mediation design decisions (2026-09-25)

**Target:** section 8 of [REVIEW-multilevel-mediation-2026-09-25.md](REVIEW-multilevel-mediation-2026-09-25.md)
**Status:** decided (D1-D14), 2026-09-25; D10-D14 triage two adverse reviews of spec revision 1. Open: spec items A1 (class name) and A2 (few-cluster thresholds)

Each row is appended as it is decided. Recommended answers were pre-filled from the review and
the codebase; the author's pick is recorded, with the recommendation noted when they differ.

## Decision Ledger

| # | Branch | Decision |
|---|---|---|
| D1 | Design scope | 2-1-1 (cluster-level treatment) is module 1; 1-1-1 (and the sigma_ab question) is module 2. Recommended, chosen. |
| D2 | Estimand (2-1-1) | Store a, b_W, b_B, c_prime (M cluster-mean centered). nie()/nde()/te(): NIE = a*b_B, NDE = c_prime. decompose(): own-mediator a*b_W and spillover/contextual a*(b_B - b_W), printed with the between-individual cross-world assumption (Talloen et al. 2016; Cheng & Li 2026). Recommended, chosen. |
| D3 | Centering | Both routes: fit_mediation(engine = "lmer", cluster = ) builds cluster-mean-centered models; extract_mediation() on user lmer fits accepts either correct parameterization (within-centered M + cluster mean, or raw M + cluster mean) and errors with the correct formula when the cluster-mean term is missing. Recommended, chosen. |
| D4 | Inference (2-1-1) | Block-diagonal @vcov (Cov(a_hat, bB_hat) = 0 assumed) so tidy()/confint() give delta-method SEs like other classes; guarded by a simulation-coverage test including unbalanced clusters. bootstrap_mediation() gains cluster resampling (resample clusters, refit; Field & Welsh 2007). Evidence: one simulated 2-1-1 dataset (60 x 10), cluster-bootstrap corr(a_hat, bB_hat) = -0.06 (B = 300), SE(a*bB) 0.124 bootstrap vs 0.126 delta with Cov = 0. Recommended, chosen. |
| D5 | Few clusters, REML, SE type | REML by default (fit route); lme4 model-based vcov by default; opt-in se_type = "kr" (Kenward-Roger via pbkrtest, Suggests); warn when the number of clusters is small, pointing to se_type = "kr" (threshold set in the spec; evidence: McNeish 2017 REML+KR adequate at 10 clusters for 2-1-1; Hox et al. 2014 ML-SEM unreliable below ~25). Recommended, chosen. |
| D6 | Class design | One S7 class per design, following the class-per-structure principle: a new 2-1-1 class in module 1 (stores a, b_within, b_between, c_prime, cluster name, number of clusters, cluster sizes, centering record; name fixed in the spec), a separate 1-1-1 class in module 2. MediationData is not extended, so RMediation and probmed see no change. Rejected: one class with a design property (validator and effect builders branch on design); extending MediationData. Recommended, chosen. |
| D7 | Module-1 scope guards | Accept Gaussian lmer fits with a cluster random intercept, covariates at either level, and random slopes on level-1 terms (including the within-cluster mediator); these leave the fixed effects, and so nie() = a*b_B, unchanged. Error, with a message naming the fix, on: any X-by-M product (including cross-level X by within-M), glmer or other non-Gaussian families, and a missing cluster random intercept. The simulation-coverage test gains a random-slope scenario. Rejected: random intercept only (forces needless refits); accepting glmer (a*b_B on the link scale is not the NIE). Recommended, chosen. |
| D8 | Cluster weighting (module 1) | nie() = a*b_B is identical in every cluster under the D7 scope, so it needs no weighting. decompose() reports own a*b_W and spillover a*(b_B - b_W), labeled cluster-average and large-cluster: Talloen et al. (2016, p. 367) define the split with the peer mean excluding the individual, then substitute the cluster mean (close in groups of 20 or more). Under the fitted model the exact own effect is a*b_W + a*(b_B - b_W)/n_j, so a warning fires when clusters are small (threshold set in the spec). Individual-average and exact finite-n_j versions are deferred to module 2. Rejected: an average = argument with the exact split now (more API; individual-average own effect ambiguous once b_Wj varies); no label or warning. Recommended, chosen. |
| D9 | Assumption printing | print()/summary() of the 2-1-1 class end with a short Estimand and assumptions block: design, the estimand behind each number, and its key identification assumption. The lines differ by component: per Talloen et al. (2016, abstract), in linear models the within (own) indirect effect stays unbiased under unmeasured additive upper-level M-Y confounding while the contextual (spillover) effect, and so the total a*b_B, does not; unmeasured lower-level M-Y confounding breaks both. decompose() adds the cross-world line (D2). tidy()/glance() stay plain tibbles; the full list goes in the Rd and the Methods article. Other classes unchanged. Rejected: docs only; a one-time message at extraction. Recommended, chosen. |
| D10 | Adverse review: KR scope (A4) | se_type = "kr" gives t intervals with Kenward-Roger df for the paths (a, b_W, b_B, c_prime); product intervals stay normal delta-method, and the few-cluster warning points to the cluster bootstrap for them. Reason: KR SEs equal the model SEs to about 0.1% (ratios 1.000-1.002 at J = 15, unbalanced), so KR only helps through df. The J = 15 scenario gates path coverage on Bradley's (0.925, 0.975) band. Rejected: dropping kr; min(df) t intervals for products (no source). Recommended, chosen. |
| D11 | Adverse review: approximation warning (A3) | decompose() warns when the D-own gap \|a*(b_B - b_W)\|/H exceeds half the own effect's SE; summary() always prints the gap. Reason: a fixed H < 20 trigger fires on most classroom trials even when the gap is negligible. Rejected: keep H < 20; no warning. Recommended, chosen. |
| D12 | Adverse review: cluster-mean rows (A5) | Both models fit identical complete-case rows and M-bar_j comes from them; print() adds that members missing from the analysis rows are assumed not to drive their peers' outcomes. Rejected: all rows with M observed (models on different rows, extract route needs data =). Recommended, chosen. |
| D13 | Adverse review: scope corrections (D7 amended) | Random slopes allowed on the within-mediator term only; slopes on raw M, on the cluster-mean term or on X error (a raw-M slope loads on M-bar_j and changes the model: delta b_B up to 0.06 in review runs). Products of a mediator term with a covariate error as well as with X. The fit engine cluster-mean centers level-1 covariates in the outcome model and adds their means (Talloen et al. 2016, eqs. 9-10, p. 370); without this the own effect loses its upper-level robustness. Applied as corrections; D7's intent unchanged. |
| D14 | Adverse review: bootstrap failures | Singular fits and convergence warnings in cluster-bootstrap refits count as failures, caught with withCallingHandlers, reported in the existing warning; @n_boot already holds successes. BootstrapResult unchanged. Rejected: a new slot (changes a class dependents consume). Recommended, chosen. |

## Open Questions

Left for the spec to settle, or to check before implementation:

- **A1, A2** in the spec: the class name, and the few-cluster thresholds (J < 25 with model SEs,
  J < 10 always), which are medfit's choices; McNeish (2017) and Hox et al. (2014) do not test
  lme4 model-based SEs below 25 clusters.
- **Block-diagonal vcov (D4).** A first-order argument plus one simulated dataset (corr -0.06).
  The spec's simulation gates (SE ratio, cross-replication correlation) must hold with unbalanced
  clusters and random within-slopes.
- **Bridge derivation (review section 4).** Unpublished and unchecked; it bears on module 2
  only and must not be cited as a result.
- **Known-answer check for module 2.** Reproducing the BPG06dat values with lavaan needs a
  package install (ask first).
- **Unread full texts.** Bind et al. (2016) and Qin & Hong (2017) were read in part; module 2
  needs both in full before its spec cites them.

## Next

1. ~~Commit this ledger to `dev`~~ — done (`fe6ff2f`).
2. ~~Write the module-1 spec~~ — `SPEC-multilevel-mediation-2-1-1-2026-09-25.md`, revision 2
   after two adverse reviews (D10-D14).
3. Approve spec items A1 and A2, then write the plan.
4. Module 2 (1-1-1) gets its own grill after module 1 ships.
