# REVIEW: Multilevel (clustered) mediation — estimands, assumptions, gaps

**Date:** 2026-09-25 · **Purpose:** decide what medfit Extension D should estimate before
writing its spec · **Status:** review complete; Ext D decisions open (section 7)

**Sources and method.** About 40 sources from three routes: 21 full texts in the author's
Zotero library, the NotebookLM notebook "Mediation and Interaction" (123 sources), and
open-web searches (Crossref, PubMed, PMC, arXiv, CRAN). Every cited DOI was checked against
Crossref on 2026-09-25. Page locators refer to the journal pagination where printed.
Read depth is graded in section 8; a source is used for a claim only at the depth listed there.
"Not found" below means not found among these sources — the gap-finder's full verification
sweep (all databases, preprint servers, experts) has not been done, so no gap here is confirmed.

---

## 1. Where treatment sits decides which estimands are even defined

| Design | X (treatment) | M | Y | Typical setting |
|---|---|---|---|---|
| 1-1-1 | individual, varies within cluster | individual | individual | multisite trials, repeated measures within persons |
| 2-1-1 | cluster | individual | individual | cluster-randomized trials (CRTs) |
| 2-2-1 | cluster | cluster | individual | CRTs with a cluster-level mediator |
| 1-1-2, 1-2-1, 2-1-2 | mixed | mixed | cluster | covered by multilevel SEM only |

McNeish (2017) reports that 75% of the multilevel-SEM mediation studies it reviewed use 2-1-1
or 1-1-1 models, and that the median study has 44 clusters. With a cluster-level X, the X→M effect cannot vary within a cluster, so a
random a-path — and with it any a·b covariance term — does not arise (Preacher et al., 2010,
p. 210; Zhang et al., 2009).

## 2. Model-based definitions (multilevel modeling and multilevel SEM)

| Estimand | Definition | Source |
|---|---|---|
| Conflated product | a·b from models that mix within- and between-cluster variation (no centering, one slope per path) | Krull & MacKinnon (1999, 2001) |
| Level-specific | Within: a_W·b_W; Between: a_B·b_B (or a·γ₀₂ in 2-1-1), after cluster-mean centering or with latent cluster means | Zhang et al. (2009); Preacher et al. (2010, 2011) |
| Average random indirect effect | E[a_j b_j] = a·b + σ_ab, with a_j, b_j cluster-specific random slopes (1-1-1, both paths random) | Kenny et al. (2003); Bauer et al. (2006) |
| Heterogeneity | Var(a_j b_j), the spread of cluster-specific effects (not a sampling variance; assumes normal random effects) | Bauer et al. (2006) |

How these relate, per the sources:

- Preacher et al. (2010, Table 1, p. 211) list the Kenny/Bauer 1-1-1 models under
  "conflation or bias"; in their framework Bauer's model is the special case with within and
  between effects constrained equal. After decomposition, the covariance form survives only
  as the *within* effect, μ_a·μ_b + ψ(a_j, b_j).
- Tofighi, West & MacKinnon (2013, pp. 290, 301) show that an omitted level-2 variable induces
  correlated random slopes; the within indirect effect a_W·b_W is then conditional on that
  variable at its grand mean, and the covariance term is induced by it. They recommend fitting
  the model with and without correlated M/Y random effects and, if σ_ab is nonzero, searching
  for the omitted moderator or running a sensitivity analysis (p. 301).
- Tofighi & Kelley (2016, pp. 91–92) state that under their Assumptions 1–5 (correct form,
  reliability, no method bias, no omitted confounder, no interactions) E[a_j b_j] =
  a_W·b_W and σ_ab = 0; when the assumptions fail, the E[a_j b_j] expression is not a causal,
  unbiased estimate. They also note a nonzero between-equation covariance may lack a
  substantive interpretation.
- The sources split on how to read σ_ab. Kenny et al. (2003) and Bauer et al. (2006) treat it
  as part of the average indirect effect; Tofighi et al. (2013) and Tofighi & Kelley (2016)
  read a nonzero σ_ab as a sign of an omitted level-2 variable. Vuorre & Bolger (2018) provide
  Bayesian within-person software (bmlm) that estimates it (sections read, W).
- Bauer et al. (2006, p. 158) call the independence of cross-equation residuals in their model
  particularly questionable; their model also assumes predictors uncorrelated with the random
  effects.
- Preacher et al. (2010) hold that any design with a level-2 variable mediates only at the
  between level; Pituch & Stapleton (2012) argue that in CRTs a participant-level mediator
  carries a cross-level effect a·b₁ in addition to a cluster-level one.

## 3. Potential-outcome definitions

**Cluster-level treatment (2-1-1, CRTs).**

- VanderWeele (2010) defines individual-level CDE, NDE and NIE of a cluster-level
  treatment, averaged over individuals, and extends them to outcomes that depend on a summary
  of cluster-mates' mediators (p. 528 ff.).
- Under within-cluster interference, the NIE splits into an effect through one's own mediator
  and a spillover effect through others' mediators: VanderWeele, Hong, Jones & Brown (2013);
  Talloen et al. (2016, pp. 365, 369), who call them within and contextual indirect effects;
  Cheng & Li (2026), who call them individual and spillover mediation effects (IME, SME);
  Ohnishi & Li (2026), with several mediators.
- Cheng & Li (2026) define each effect in two versions: a **cluster-average** (every cluster
  weighted equally) and an **individual-average** (clusters weighted by size). The two differ
  under informative cluster size.
- In linear random-intercept models without X×M, the g-formula reduces to coefficient
  products (VanderWeele, 2010; Talloen et al., 2016, p. 369); with non-identity links the
  conditional effects must be integrated over the random effects (VanderWeele, 2010).

**Treatment within clusters (1-1-1, multisite).**

- Qin & Hong (2017, abstract) define site-specific natural effects and target their
  population average and between-site variance, estimated by ratio-of-mediator-probability
  weighting.
- Bind, VanderWeele, Coull & Schwartz (2016) define subject-specific and marginal NDE/NIE
  under generalized mixed models with random slopes in both the mediator and outcome models;
  in the linear case their indirect effect contains the covariance of the random slopes
  (notebook passage of their Section 2). Their clusters are subjects measured repeatedly, and
  they recommend allowing correlated random effects.
- Di Maria & Didelez (2024, p. 7) show that correlation between the mediator-model and
  outcome-model random effects makes their separable effects unidentifiable in a longitudinal
  DAG — a direct tension with reading σ_ab as part of a causal effect.

## 4. The bridge — an unpublished derivation, to be checked

Not found as a published result: a statement of when a·b + σ_ab equals a population-level
natural indirect effect for cross-sectional 1-1-1 clustering, and with which cluster weighting.
Bind et al. (2016) is the closest, for repeated measures.

Our derivation (not from a source): suppose

1. X is randomized within clusters;
2. the within-cluster models are linear with identity links:
   M_ij = α_j + a_j X_ij + e, Y_ij = β_j + c′_j X_ij + b_j M_ij + e;
3. there is no X×M interaction;
4. within-cluster sequential ignorability holds, including the cross-world condition, and b_j
   is identified from within-cluster variation (M cluster-mean centered or cluster means
   included) — Talloen et al. (2016) show the within effect survives only *additive*
   cluster-level M–Y confounding;
5. there is no interference within clusters.

Then the cluster-specific NIE is a_j b_j, its equal-weight average over clusters is
a·b + σ_ab (the cluster-average NIE), and the individual-average NIE is
E[N_j a_j b_j] / E[N_j]. Under Tofighi & Kelley's stronger assumptions σ_ab = 0 and both
equal a_W·b_W. This needs a written proof and a simulation check before any medfit
documentation relies on it.

## 5. Identification assumptions specific to clustering

| Assumption | Why it matters | Sources |
|---|---|---|
| No interference between clusters (partial interference) | Required by every PO definition above | VanderWeele (2010); Cheng & Li (2026) |
| Within-cluster interference | Changes the estimand (own-mediator vs spillover); individual-level treatment with interference is not developed | VanderWeele (2010, pp. 539–540); VanderWeele et al. (2013) |
| Cross-world independence between individuals | Needed for the own/spillover split, not for the total NIE | Talloen et al. (2016); Cheng & Li (2026) |
| Cluster-level M–Y confounding | Biases the between and conflated effects; within effect robust only to additive confounding | Talloen et al. (2016); Tofighi et al. (2013); Tofighi & Kelley (2016) |
| Random effects independent of covariates | The random-effects model assumes it; fixed effects tolerate cluster-constant confounding | Kim & Steiner (2021, abstract); Bauer et al. (2006) |
| Informative cluster size | Separates cluster-average from individual-average effects | Cheng & Li (2026) |
| Few clusters | ML multilevel SEM unreliable below roughly 25 clusters; REML with Kenward–Roger trustworthy at 10 for 2-1-1 | Hox et al. (2014); McNeish (2017) |
| Centering | Uncentered slopes conflate levels; manifest cluster means bias between effects when clusters are sampled sparsely | Zhang et al. (2009); Lüdtke et al. (2008, abstract); Preacher et al. (2011) |

## 6. Estimators and software

| Route | What it gives | Limits |
|---|---|---|
| Separate lme4 models | a, b, c′ and cluster-mean-centered within/between slopes; REML | no σ_ab and no cross-equation Cov(â, b̂) (Kenny et al., 2003; Bauer et al., 2006) |
| Stacked single model (Bauer et al., 2006) in nlme | a, b, σ_ab, Cov(â, b̂), Var(a_j b_j) | linear, continuous M and Y, uncorrelated M/Y residuals; Bauer et al. found bootstrapping slow |
| Multilevel SEM (Mplus; lavaan ≥ 0.7 `rv()`) | latent-mean within/between effects, level-specific designs | needs many clusters; lavaan random slopes are new and restricted (per the CRAN docs, unverified here by a fit) |
| Bayesian (bmlm, brms joint models) | a, b, σ_ab with priors; brms correlates random effects across formulas | priors matter with few clusters; Falk et al. (2024, abstract) report better Bayesian coverage but lower power than bootstraps |
| `mediation` (Tingley et al., 2014) | group-specific and group-averaged ACME from separate merMod fits | see note below |
| RMPW (MultisiteMediation, CRAN) | site-specific NIE distribution (Qin & Hong, 2017) | weighting, not random-coefficient models |
| Doubly robust CRT estimators (DRmediateCRT, GitHub) | cluster- and individual-average NIE, IME, SME (Cheng & Li, 2026) | not on CRAN |

**Local illustration (one simulated draw, not a study).** Data: 150 clusters of 12, a = 0.5,
b = 0.4, Var(a_j) = Var(b_j) = 0.16, σ_ab = 0.08, so a·b + σ_ab = 0.280. Separate lmer fits gave
a·b = 0.206; adding the covariance of the BLUPs gave 0.247; `mediation::mediate()` on the same
fits gave an averaged ACME of 0.247 (95% interval 0.191 to 0.316); the stacked nlme model gave
0.295 with σ̂_ab = 0.099. The match between `mediate()` and the BLUP plug-in is consistent with
averaging group-specific BLUP predictions, whose covariance is shrunk; one draw cannot show
bias. Script: session scratchpad (not committed).

**Known answer for any joint fit.** `multilevelmediation` 0.5.0 ships `BPG06dat` (the Bauer
et al. 2006 supplementary data); its test snapshot records a = 0.6120, b = 0.5880,
σ_ab = 0.0925, indirect 0.4524 (stacked nlme, REML, random a and b). Using it requires
installing that package or fetching the data.

**Inference detail.** Bauer et al.'s variance for a·b + σ_ab keeps second-order terms
(Var(â)Var(b̂), Cov(â, b̂)²) and needs Var(σ̂_ab) and Cov(â, b̂) — the latter only from a joint
fit. Monte Carlo intervals performed well in their simulations. Field & Welsh (2007) show the
cluster bootstrap is consistent under the random-effect model.

## 7. Gaps (not found among the sources reviewed)

| Gap | Type |
|---|---|
| No stated result on when a·b + σ_ab equals a population NIE for cross-sectional clustering, with its cluster weighting and X×M terms (section 4) | theory |
| Interventional (randomized) effects for clustered or multisite designs | method |
| Individual-level treatment with within-cluster interference | method |
| Cluster-level confounding that is non-additive or correlated with the random slopes | robustness |
| Few clusters with random slopes | robustness |
| No CRAN package that estimates a causal cluster- or individual-average NIE from random-slope mixed models with the estimand stated | software |
| No hierarchical sensitivity analysis in software (Talloen et al., 2016, p. 386) | software |
| REML vs ML for plugging variance components into effect formulas — not evaluated in the sources read (our observation) | theory |

## 8. Decisions for Extension D

These are the choices that change the class, the extractor and the documentation. They are
open; nothing in this review decides them.

1. **Design scope first:** 2-1-1 (CRTs, where PO theory and linear g-formula results exist),
   1-1-1 (multisite, where the a·b + σ_ab question lives), or both in sequence.
2. **Estimand the class stores:** level-specific within/between, a·b + σ_ab, or PO effects
   (NIE/NDE, and own-mediator vs spillover in CRTs), with a·b + σ_ab labeled by its conditions.
3. **Cluster weighting:** cluster-average, individual-average, or both.
4. **Centering:** whether medfit centers M (and X) itself or requires the user to.
5. **Estimation route:** separate lme4 fits (no σ_ab, no Cov(â, b̂)), a joint fit
   (nlme stacking or lavaan `rv()`), or both — decided by whether σ_ab is in the estimand.
6. **Inference:** delta method (needs Var(σ̂_ab)), Monte Carlo, or cluster bootstrap.

## 9. Sources and read depth

F = full text (Zotero PDF, read by us or a reading agent, with locators spot-checked);
W = full text or sections from the web (PMC or author copy); N = passages via the NotebookLM
notebook; A = abstract only.

| Source | DOI | Depth |
|---|---|---|
| Bauer, Preacher & Gil (2006). *Psychological Methods*, 11(2), 142–163 | 10.1037/1082-989X.11.2.142 | F |
| Bind, VanderWeele, Coull & Schwartz (2016). *Biostatistics*, 17(1), 122–134 | 10.1093/biostatistics/kxv029 | N |
| Cao & Li (2025). *Statistics in Medicine*, 44 | 10.1002/sim.70175 | A |
| Cheng & Li (2026). *Biometrics*, 82(1) | 10.1093/biomtc/ujag017 | F |
| Di Maria & Didelez (2024). *BMC Medical Research Methodology*, 24 | 10.1186/s12874-024-02358-4 | F |
| Falk, Vogel, Hammami & Miočević (2024). *Behavior Research Methods*, 56(2), 750–764 | 10.3758/s13428-023-02079-4 | A |
| Field & Welsh (2007). *JRSS-B*, 69(3), 369–390 | 10.1111/j.1467-9868.2007.00593.x | A |
| Hox, Moerbeek, Kluytmans & van de Schoot (2014). *Frontiers in Psychology*, 5 | 10.3389/fpsyg.2014.00078 | F |
| Kenny, Korchmaros & Bolger (2003). *Psychological Methods*, 8(2), 115–128 | 10.1037/1082-989X.8.2.115 | F |
| Kim & Steiner (2021). *BJMSP*, 74(2), 165–183 | 10.1111/bmsp.12217 | A |
| Krull & MacKinnon (1999). *Evaluation Review*, 23(4), 418–444 | 10.1177/0193841X9902300404 | F |
| Krull & MacKinnon (2001). *Multivariate Behavioral Research*, 36(2), 249–277 | 10.1207/S15327906MBR3602_06 | F |
| Lüdtke, Marsh, Robitzsch & Trautwein (2008). *Psychological Methods*, 13(3), 203–229 | 10.1037/a0012869 | A |
| McNeish (2017). *Structural Equation Modeling*, 24(4), 609–625 | 10.1080/10705511.2017.1280797 | F |
| Ohnishi & Li (2026). *JASA*, 121(553), 716–728 | 10.1080/01621459.2025.2544366 | F |
| Pituch & Stapleton (2012). *Sociological Methods & Research*, 41(4), 630–670 | 10.1177/0049124112460380 | F |
| Preacher, Zyphur & Zhang (2010). *Psychological Methods*, 15(3), 209–233 | 10.1037/a0020141 | F |
| Preacher, Zhang & Zyphur (2011). *Structural Equation Modeling*, 18(2), 161–182 | 10.1080/10705511.2011.557329 | F |
| Qin & Hong (2017). *JEBS*, 42(3), 308–340 | 10.3102/1076998617694879 | A |
| Talloen, Moerkerke, Loeys & De Naeghel (2016). *JEBS*, 41(4), 359–391 | 10.3102/1076998616636855 | F |
| Tingley, Yamamoto, Hirose, Keele & Imai (2014). *Journal of Statistical Software*, 59(5) | 10.18637/jss.v059.i05 | W (section 4) |
| Tofighi, West & MacKinnon (2013). *BJMSP*, 66(2), 290–307 | 10.1111/j.2044-8317.2012.02051.x | F |
| Tofighi & Kelley (2016). *Multivariate Behavioral Research*, 51(1), 86–105 | 10.1080/00273171.2015.1105736 | F |
| VanderWeele (2010). *Sociological Methods & Research*, 38(4), 515–544 | 10.1177/0049124110366236 | F |
| VanderWeele, Hong, Jones & Brown (2013). *JASA*, 108(502), 469–482 | 10.1080/01621459.2013.779832 | W |
| Vuorre & Bolger (2018). *Behavior Research Methods*, 50(5), 2125–2143 | 10.3758/s13428-017-0980-9 | W (sections) |
| Zhang, Zyphur & Preacher (2009). *Organizational Research Methods*, 12(4), 695–719 | 10.1177/1094428108327450 | F |

Also read but not used for claims above: Asparouhov & Muthén (2019, 10.1080/10705511.2018.1511375,
W); Pituch et al. (2005, 10.1207/s15327906mbr4001_1, F; 2006, 10.1207/s15327906mbr4103_5, F);
Tofighi & Thoemmes (2014, 10.1177/0272431613511331, F); Yuan & MacKinnon (2009,
10.1037/a0016972, W); Park & Kaplan (2015, 10.1080/00273171.2014.1003770, A); Reardon &
Raudenbush (2013, 10.1177/0049124113494575, A). Zheng & Zhou (2015, 10.1111/rssb.12082, F) is
excluded: its "multilevel intervention" is a multi-valued treatment, not clustering.

**Leads not verified or not read (do not cite):** Qin & Hong JSM 2014 proceedings (no DOI);
single-author arXiv preprint on pooled vs level-respecting indirect effects; arXiv preprints
on few-cluster and stepped-wedge mediation beyond Cao & Li; Cheng & Li supplementary Remark 6
(interventional reinterpretation of IME/SME), not yet obtained; Lachowicz, Sterba & Preacher
(2015); Preacher (2015, *Annual Review*).
