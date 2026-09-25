# GRILL: medfit Extension D — multilevel mediation design decisions (2026-09-25)

**Target:** section 8 of [REVIEW-multilevel-mediation-2026-09-25.md](REVIEW-multilevel-mediation-2026-09-25.md)
**Status:** decided (D1-D9), 2026-09-25; feeds the Ext D spec

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

## Open Questions

Left for the spec to settle, or to check before implementation:

- **Thresholds.** The few-cluster warning (D5) and the small-cluster warning (D8) need numbers.
  Anchors: McNeish (2017) on REML and Kenward-Roger with few clusters; Hox et al. (2014) on
  ML-SEM below about 25 clusters; Talloen et al. (2016, p. 367) on groups of 20 or more.
- **Class and argument names.** The 2-1-1 class name (D6) and the `cluster =` / `se_type = "kr"`
  spellings (D3, D5) are fixed in the spec.
- **Block-diagonal vcov (D4).** One simulated dataset gave corr(a_hat, bB_hat) = -0.06. The
  coverage test must show it holds with unbalanced clusters and random within-slopes (D7).
- **Bridge derivation (review section 4).** Unpublished and unchecked; it bears on module 2
  only and must not be cited as a result.
- **Known-answer check for module 2.** Reproducing the BPG06dat values with lavaan needs a
  package install (ask first).
- **Unread full texts.** Bind et al. (2016) and Qin & Hong (2017) were read in part; module 2
  needs both in full before its spec cites them.

## Next

1. Commit this ledger to `dev`.
2. Write `SPEC-multilevel-mediation-2-1-1-<date>.md` (module 1) from D1-D9, citing only
   sources read for the review.
3. Module 2 (1-1-1) gets its own grill after module 1 ships.
