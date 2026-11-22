# Novelty check, second pass: multilevel indirect-effect candidates

**Date:** 2026-11-21 (revised after an independent review) · **Status:** research note, docs only (no code, no release). It closes
the open items it could close; several boundary-theory and few-cluster sources remain unread or snippet-only (sections 2, 7, 8),
so it is **not** a complete review.
**Supersedes the open items of:** [LIT-multilevel-novelty-check-2026-11-21.md](LIT-multilevel-novelty-check-2026-11-21.md)
(sections 5 and 6 there; that file is unchanged except for a pointer line).
**Builds on:** [LIT-multilevel-sem-gaps-2026-11-11.md](LIT-multilevel-sem-gaps-2026-11-11.md) (gaps G1 to G13, ideas I1 to I10).
**Proposals written from this note:** kept private (not in this repository); this note refers to them as proposals A and B.

Labels, as in the earlier notes:

- **SOURCE**: a statement the cited text supports; reading depth is stated per source in section 2.
- **INFERENCE**: this note's own reading or derivation, including every "not found" claim. An absence claim is only as strong as
  its stated search scope (section 7).
- **UNVERIFIED**: taken from a model-generated answer (NotebookLM, a web-search summary) or a secondary citation, and not
  checked against the source text.
- **SCRATCH**: a computation run for this note in the scratch directory, not committed. It checks a stated model, not the
  package likelihood.

## 0. Corrections to the 2026-11-21 note

| # | Earlier statement | What the sources and the repository say |
|---|---|---|
| C1 | McNeish 2017 model "2-1-1 or 1-1-1 (not confirmed)" | **2-1-1** (X at level 2, M and Y at level 1), random intercepts, fixed slopes, ICC fixed at .20 in every cell (SOURCE, full text). |
| C2 | McNeish null cells "not confirmed" | **None.** Every cell has a nonzero indirect effect (small, 4% of the variance of Y; medium, 15%). "Power" is the share of intervals excluding 0 (SOURCE). |
| C3 | McNeish "keeps only replications where all methods converged" | Confirmed, and it matters: the filter requires MLM, ML-SEM and MCMC to all converge, and "nonconvergence" includes inadmissible estimates, non-PD matrices and any software error. Replications kept at J = 10: 792 to 944 of 1,000 (Table 2). So McNeish's ML-SEM coverage is conditional on joint convergence (SOURCE). |
| C4 | McNeish "Small-sample correction: REML with Kenward-Roger in the multilevel model" | Correct, but the comparison is **across model classes**: KR is applied to the manifest-mean multilevel model (SAS PROC MIXED), not to the SEM; McNeish states that no KR extension to SEM exists. Mplus ML-SEM was fit with full ML (SOURCE). |
| C5 | Li and Beretvas 2013: "upper-level mediation with measurement error", cluster size "not read" | **2-2-1** model: X and a latent M at level 2, a latent Y at level 1, four indicators each; balanced n = 20 or 40; ICC .05 or .15; G = 20, 40, 80; Mplus MLR; PRODCLIN intervals; null cells (a, b) = (0,0), (.3,0), (0,.3) and three ab = .09 cells (SOURCE; design, results and discussion read). |
| C6 | Candidate 5: section 5 of the earlier note presented the finite-`n` own/spillover identity as its own derivation ("derived by hand and has not been run against `decompose()`") and as a possible new exact `decompose()` | **That was an error of omission.** The exact finite-cluster identities `own = a [b_W + (b_B - b_W)/n_j]` and `spillover = a (b_B - b_W)(n_j - 1)/n_j` are **already in the repository**: `vignettes/articles/methods.qmd` (lines 259 to 285) and GRILL ext-D decisions D8 and D11, which cite Talloen et al. 2016 and defer the exact `decompose()` to "module 2". The identity also appears as an oracle in the 2-1-1 plan (T6). The earlier note re-derived a documented result and did not say so. The plan task is `PLAN-multilevel-mediation-2-1-1-2026-10-08.md` T6 (not the few-clusters T6). Verified again here, section 5. |
| C11 | The 2026-11-11 gaps note and the earlier note, and this note's first version, treated the 1-1-1 latent-mean setting as unstudied at small J | **Zigler and Ye 2019** (*MBR* 54(3)) compare MSEM, unconflated and conflated multilevel models in a **1-1-1** design with random within slopes, J = 30 to 500, balanced n = 20 and 40, ICC .1 and .3, with null conditions (between pathways zero; all pathways zero) and delta intervals (SOURCE, sections read). It was cited in the 2026-11-11 gaps note as `[ZiglerYe2019]` and was omitted from the first version of this note and of proposal B. Section 4. |
| C12 | "Neither has an arm that mirrors T6's null cell" (first version, section 4.3) | Li and Beretvas **do** report three null patterns, in a different model (2-2-1 with latent M and Y). Section 4.3 is rewritten. |
| C7 | Chernoff 1954 and Drton 2009 "not checked" | Both read in full (Chernoff by OCR). Chernoff gives the tangent-cone theorem and the 50:50 law; he does **not** state the product-null result. Drton gives the minimum-of-chi-squares limit and a union-of-lines example. Section 3. |
| C8 | Preacher 2015 survey "not read (UNVERIFIED)" for "the indirect effect exists only at the between level" | Now SOURCE from Preacher, Zyphur and Zhang 2010 (discussion; sentence read) and Zhang, Zyphur and Preacher 2009 (discussion; sentence read). The Preacher 2015 survey itself is still unread. |
| C9 | Candidate 4 table row "T6 ... the native model class" | T6 measured the **lavaan two-level adapter** (`PLAN-few-clusters-design-study-2026-11-16.md` section 1; memo: "P0, lavaan defaults"). The native S4a fit was not run in T6. The native model class is a feature of what comes after T6, not of T6. |
| C10 | "Arxiv 2606.13305 could not be confirmed" | Still unconfirmed and still not cited. A different preprint (arXiv 2609.29685, Hait, 30 Aug 2026) was found and read in part: section 4. |

## 1. Final verdict table

"Closest prior work read" names only sources actually read (depth in section 2).

| # | Candidate | Verdict | Closest prior work read | What a new result would look like | Feasibility |
|---|---|---|---|---|---|
| A | Joint LR law: product null at a level, boundary level-2 variance, level-specific statistic; and its application to equal indirect effects across levels | **Partly known; the specific joint instance is open, and whether it is nonstandard is a conjecture resting on an unfinished identification calculation** | Chernoff 1954, Self and Liang 1987, Drton 2009 (general cone law; union of lines gives `min` of chi-squares); Tofighi and Kelley 2020 (single-level product null, chi-square reference, multilevel left open); Cox and Kelcey 2023 (2-1-1) and Zigler and Ye 2019 (1-1-1): empirical near-zero rejection at the all-zero null | The limit law of the T-A statistic when the level-2 residual variance of M is local to zero (`psi_M = h / sqrt(J)`), where `b_b` loses identification: a theorem or a calibrated approximation, plus a size/power study in medfit. SCRATCH on a partial-information model suggests the between-level information is singular at `psi_M = 0` and `b_b` is not orthogonal to `psi_M` (section 3.4); the profiled full-model calculation has **not** been done. | Medium. The simulation half is cheap (extends `tests/sim/sem-twolevel-mbco-size.R`). The theory half is hard and may reduce to a numerical calibration. |
| B | Few-clusters guidance and validation study for between-level indirect effects | **Partly known; downgraded to package guidance unless a same-estimand remedy arm adds a result** | Zigler and Ye 2019 (1-1-1 MSEM, random slopes, J >= 30), McNeish 2017, Li and Beretvas 2013, Preacher, Zhang and Zyphur 2011, Cox and Kelcey 2023, Li and Jia 2026 (abstract only), Hait 2026 (preprint) | What remains after Zigler and Ye: **J below 30 (10, 20), unequal small clusters, fixed slopes, failure categories with coverage-and-availability reported side by side, the variance-floor arm, and a matched same-estimand cluster-bootstrap remedy.** These are scope and accounting differences, not a new model class. | High for the T6-based guidance (data exist). The remedy arm is gated on T8 and the bootstrap-scope decision (M2: T7 dropped for the next release). |
| C | Individual versus spillover split of the 2-1-1 indirect effect: exact finite-`n_j` identity and an assumptions note | **Known** (inside this project; Talloen et al. 2016 per project notes, unread here) | `methods.qmd` lines 259 to 285; GRILL ext-D D8, D11; Cheng and Li 2026 (estimands and the linear working model s6); VanderWeele et al. 2013 (nonparametric within-classroom and spillover effects) | Only two open pieces: the split under unequal cluster sizes (the two parametrizations stop being equivalent, section 5.3) and the latent-mean bridge. Both are code or documentation items, not a paper. | Not a research proposal. A code item for the deferred "module 2". |
| D | Global-optimum handling for the sign-symmetric constraint `a_w b_w = a_b b_b` (#504) | **Known theory applied; not publishable as a paper** | Wang, Song and Xia 2021 (arXiv 2108.13729, sections read): generalized trust-region subproblem with an equality constraint, Moré's global characterization as quoted there, the secular function, a bound on local nonglobal minimizers; Moré 1993 itself abstract only. SCRATCH: in the Gaussian limit the problem has exactly this form. | A software certificate (the secular-equation scan with a positive-semidefiniteness check) for #504, not a methods paper. | Cheap, but belongs in #504, not in a proposal. |
| E | Serial (product-of-three) null at two levels (IG5s) | **Single-level known; two-level not found in the stated scope** | Taylor, MacKinnon and Tein 2008 (joint significance and bootstrap, simulation); Tofighi and Kelley 2020 (MBCO simulation cell with all three paths zero, `Figure 5`); Drton 2009 (union of coordinate hyperplanes) | Folded into A: the tangent cone of `a d b = 0` at the origin is a union of three hyperplanes, so the same machinery gives `min` of three. No separate proposal. | Gated on the IG5s scope decision (maintainer). |

Defensible contributions: **A** (narrow; theory is a conjecture, calibration is certain) and **B** (guidance, now package-level
unless the remedy arm adds a result). C and D are dropped as proposals (sections 5, 6 and the index).

## 2. Sources and reading depth

All local PDFs were extracted with `pdftotext`; two scanned articles (Chernoff, Self and Liang) were OCRed with `tesseract`
and read in the OCR text. Extracted text is treated as data.

| Source | Where | Depth | Used for |
|---|---|---|---|
| McNeish 2017, *SEM* 24 | Zotero PDF | **Full text** (all but the reference list): literature review, models, small-sample methods, design, results tables 2 to 4, limits | Items (a); C1 to C4 |
| Li and Beretvas 2013, *SEM* 20(2) | Zotero PDF | **Sections**: abstract, design conditions, data generation, evaluation criteria, results (inadmissible rates, bias, SE bias, coverage, power), discussion, limitations. The measurement-model algebra was not read. | Item (a); C5 |
| Preacher, Zhang and Zyphur 2011 | Zotero PDF | **Sections**: abstract, simulation design, convergence definition. Results tables not read. | Item (a) |
| Preacher, Zyphur and Zhang 2010 | Zotero PDF | **Snippet-level**: the sample-size paragraph and the "strictly between-group" sentence | Items (a), (f) |
| Zhang, Zyphur and Preacher 2009 | Zotero PDF | **Snippet-level**: one discussion paragraph | Item (f) |
| Hox 2013 (handbook chapter) | Zotero PDF | **Sections**: sample-size paragraph | Item (a) |
| Tofighi and Thoemmes 2014 | Zotero PDF | **Sections**: the 2-1-1 centering passage | Item (f) |
| Pituch and Stapleton 2012 | Zotero PDF | **Snippet-level**: contextual effect `b_B - b_W` passage | Item (f) |
| Blalock 1984 | Zotero PDF (text layer garbled; OCRed) | **Sections**: the contextual-effects model and its aggregation (equations 4 and 5) and keyword scans for group size and for excluding the individual (no hits) | Item (f) |
| VanderWeele 2010 | Zotero PDF | **Keyword scan plus the two spillover passages** (lines on interference as future work); no linear within/between algebra found | Item (f) |
| VanderWeele, Hong, Jones and Brown 2013 (JASA) | Zotero PDF | **Sections**: abstract, effect definitions, identification formulas (14) and (15), the passage on ignoring interference | Item (f) |
| Cheng and Li 2026, *Biometrics* 82(1) | Zotero PDF + supplement | **Sections**: abstract, estimands and Assumptions 1 to 5, parametric-model notes; supplement working model (s6) and Remark 4 region | Item (f) |
| Chernoff 1954, *Ann. Math. Stat.* 25 | Zotero scan, OCR | **Full text** (6 pages) | Item (c) |
| Self and Liang 1987, *JASA* 82 | Zotero scan, OCR | **Sections**: abstract, introduction, definition of the cone approximation, Theorem 3 and its proof sketch, closing discussion of Case 8. Cases 2 to 9 were not read line by line. | Items (c), (e) |
| Drton 2009, *Ann. Statist.* 37 | Zotero PDF (arXiv version) | **Sections**: abstract, section 1 (introductory examples), section 2 (Theorem 2.6 and the conditional-independence example), and the finite-union result in section 3 (extracted lines about 426 to 454); the rest of section 3 and section 4 were not read | Items (c), (d), (e) |
| Andrews 2000, *Econometrica* 68 | Zotero PDF | **Introduction** (first page of a 7-page note) | Item (e) |
| Andrews 2001, *Econometrica* 69 | web search | **Snippet only** (abstract). The Cowles discussion paper 1229 PDF could not be retrieved: the Yale server returned an HTML page, not the PDF. | Item (e) |
| Molenberghs and Verbeke 2007, *Am. Stat.* 61 | Zotero PDF | **Sections**: abstract and section 2 (mixture results; Stram and Lee cited secondarily) | Item (e) |
| Stram and Lee 1994; Shapiro 1985, 1988; Silvapulle and Sen 2005 | secondary citation in Molenberghs and Verbeke; the Silvapulle and Sen book has no PDF in Zotero | **Not read** | Item (e); marked [CITE] |
| Tofighi and Kelley 2020, *Psych. Methods* (MBCO) | Zotero PDF | **Sections**: abstract, the LRT definition and its reference law, the three-path simulation (`Figure 5` caption), the limitations paragraph on multilevel data | Items (c), (d), (e) |
| Tofighi 2020, *Frontiers* (bootstrap MBCO) | Zotero PDF | **Abstract and introduction** | Item (e) |
| Taylor, MacKinnon and Tein 2008 | Zotero PDF | **Sections**: abstract, test descriptions, the joint-significance size argument | Item (d) |
| Tofighi and Kelley 2020, *MBR* (sequential mediation) | Zotero PDF | **Abstract and introduction** | Item (d) |
| Krstic et al. 2019 (product of three random variables) | Zotero PDF | **Abstract**: a telecommunications paper on the level-crossing rate; not about mediation tests | Item (d) |
| Cox and Kelcey 2023, *Stat. Neerl.* | web fetch, PDF read | **Sections**: abstract, simulation design, Table 3 (2-1-1) | Items (a), (b) |
| Hait 2026, arXiv 2609.29685 (preprint, not peer reviewed; header "v1 [stat.ME] 30 Aug 2026") | PDF fetched and read | **Sections**: abstract, introduction, section 2.2, section 14.4 (Study 3), limitations | Items (a), (b), (f) |
| Zigler and Ye 2019, *MBR* 54(3) | Zotero PDF | **Sections**: abstract, introduction, simulation design (Table 2), outcome definitions, the Type I error statement for the all-zero condition, the discussion on choosing a method; results tables 3 to 13 located but not read cell by cell. The number of replications (1,000) is stated; convergence handling for the simulation was not found in the text read. | Items (a), (b); C11 |
| Li and Jia 2026, *SEM* (DOI 10.1080/10705511.2026.2679039) | Crossref and OpenAlex metadata | **Abstract only**: ML versus Bayesian estimators in a 1-2-1 mediation within MSEM, small and incomplete samples. The publisher page returned 403; full text not read. | Item (b) |
| Wang, Song and Xia 2021, arXiv 2108.13729 | PDF fetched and read | **Sections**: abstract, introduction, section 2 (Moré's Theorems 2.1 and 2.2 as quoted), Theorem 4.1 and the start of its proof (secular function) | Item (g) |
| Cox and Kelcey 2023 journal | note | the PDF read here is *Statistica Neerlandica* (DOI 10.1111/stan.12291); one web-search summary called it *Statistics in Medicine*, which is wrong for this paper | Items (a), (b) |
| Hox et al. 2014 (PMC3912451) | web fetch (earlier note) | first ~40,000 of ~66,000 characters | Item (a) |
| Moré 1993; Draisma et al. 2016; "Sign Switching" (a 2025 paper on a McGill psychology server) | web search | **Snippet only**; the Sign Switching URL returned 404 on fetch | Item (g) |
| NotebookLM answers (2 queries: "Multiple Paths Mediation", "LRT and PMED") | `nlm` CLI | **UNVERIFIED** leads only; the second notebook contains project-internal notes, so it is not independent evidence | Items (c), (d), (e) |
| Talloen et al. 2016; Rockwood thesis; Loh et al. 2022; Preacher 2015 survey | not in Zotero or not retrievable | **Not read**; Talloen 2016 cited from project notes only | [CITE] |

## 3. Items (c), (e), (d): the likelihood-ratio law

### 3.1 What the sources establish

- **Chernoff 1954 (SOURCE, full text).** If the null set and the alternative set are approximated at the true point by
  positively homogeneous sets (cones), and the restricted MLE is consistent, then `-2 log lambda` has the limit law of the LR
  for the cone problem with one observation from `N(theta, J^-1)` (Theorem 1). For a smooth one-sided boundary the limit is
  zero half the time and chi-square(1) otherwise (the introduction and Example 1). Chernoff's worked examples include a planar wedge bounded by two lines through the origin (Example 1) and the first
  quadrant with the origin as the alternative (Example 3). **He does not discuss a product null.**
- **Self and Liang 1987 (SOURCE, sections).** Theorem 3 gives the same cone representation for a true point on the boundary of
  the parameter space: the limit is `inf |Z - cone_0|^2 - inf |Z - cone_1|^2` for `Z ~ N(0, I^-1)`. The paper's closing
  discussion says a nuisance parameter on the boundary can give a limit that is **not** a mixture of chi-squares (Case 8) and
  that the law "varies in a discontinuous way" with the location of the nuisance parameter relative to the boundary, which
  makes finite-sample behavior near the boundary depend on proximity.
- **Drton 2009 (SOURCE, sections).** For semi-algebraic nulls the tangent cone governs the limit (Theorem 2.6); boundary points
  give chi-bar-square laws, singularities give nonstandard limits; for a finite union of smooth pieces the limit is a minimum
  of chi-square variables (the finite-union theorem in section 2 and the paragraph after Theorem 2.6). The conditional-independence example after Theorem 2.6 (trivariate normal,
  null `sigma_12 = 0` and `sigma_13 sigma_23 = 0`) gives `W_12 + min(W_13, W_23)` with independent chi-square(1) pieces at a
  diagonal covariance. This is a **product-of-two-parameters null**, so the structure of the mediation problem has a worked
  precedent, in a different model.
- **Molenberghs and Verbeke 2007 (SOURCE, sections).** For a closed convex cone the null law is a mixture of chi-squares; for
  variance components Stram and Lee 1994 derived the `0.5 (chi^2_k + chi^2_{k+1})` law (cited secondarily here).
- **Tofighi and Kelley 2020, MBCO (SOURCE, sections).** The paper states that the LRT for `H0: beta1 beta2 = 0`, refit with
  the nonlinear constraint, "has a large sample chi-squared distribution (Wilks, 1938)" and lists the several ways the null
  can hold (`beta1 = 0`, `beta2 = 0`, or both). It reports a simulation cell for the three-path product with all three paths
  zero. It states that extending MBCO to multilevel data "remains a topic for future study".
- **Cox and Kelcey 2023 (SOURCE, Table 3).** In a 2-1-1 cluster-randomized simulation (40 clusters of 20; double null
  `a = b = 0`) the Sobel and joint-significance tests reject at .000 and the other tests at .000 to .002, against a nominal
  .05. Zigler and Ye 2019 (SOURCE, sections) report between-indirect Type I error below .02 for unconflated multilevel and MSEM fits
when all pathways are zero, in a 1-1-1 design. Both are the empirical face of origin conservatism in multilevel designs.

### 3.2 The product null at a smooth point and at the origin (INFERENCE plus SCRATCH)

Write `LR_a` and `LR_b` for the LRs of `a = 0` and `b = 0` (each profiled over the other path). The T-A statistic is
`min(LR_a, LR_b)`. By Chernoff's Theorem 1 applied to the cone `{a = 0} union {b = 0}` (Drton's finite-union paragraph gives
the same), the squared distance to a union is the minimum of the squared distances, so at the origin the limit is
`min(Z_a^2, Z_b^2)` with `Z_a, Z_b` the standardized path estimators, correlated with the correlation `rho` implied by `J^-1`.
Away from the origin (one path nonzero) the limit is chi-square(1). This is a derivation; neither Chernoff nor Drton states it
for `ab = 0`. Separately, `min(LR_a, LR_b) <= LR_b` holds for every resolved fit, so a test rejecting at the chi-square(1)
critical value for the minimum rejects no more often than the single-path test of `b = 0`; that inequality is exact but does
not by itself give a size guarantee for the single-path test near a variance boundary.

SCRATCH (4 million draws per row): `P(min(Z_a^2, Z_b^2) > 3.841)` = .0024 (`rho` = 0), .0049 (.3), .0125 (.6), .0297 (.9); for
three independent coordinates .00013 against `alpha^3` = .000125. So the conservatism at the origin holds for independent path
estimators and weakens as `|rho|` grows. Whether `rho` is near zero for the two-level between-level paths is not established
(single-level recursive models give uncorrelated `a`, `b` under normal theory, INFERENCE; the latent-mean two-level model was
not checked).

### 3.3 The serial null (item d)

`a d b = 0` is a union of three coordinate hyperplanes in `(a, d, b)`, so the tangent cone at the origin is that union and
the same argument gives `min(Z_a^2, Z_d^2, Z_b^2)` (INFERENCE). Taylor, MacKinnon and Tein 2008 study the three-path test
by simulation and note that the joint-significance rejection rate is the product of the individual rejection probabilities
(SOURCE, sections); Tofighi and Kelley 2020 include an all-zero three-path cell. **Search scope for "two-level three-path":**
Zotero library titles (6,591 items) and abstracts for "three-path", "serial", "sequential"; 3 web searches; one NotebookLM
notebook (59 sources; answer UNVERIFIED, "no source addresses it"). Nothing found (INFERENCE). The product-of-three
distribution paper in the library (Krstic et al. 2019) is a telecommunications result and not a testing paper.

### 3.4 The boundary variance changes the problem class (SCRATCH, INFERENCE)

Self and Liang Case 9 (orthogonal information, nuisance on the boundary) would leave the product law unchanged. The check
for the two-level model: take the between-level cluster-mean model `Sigma = Sigma_B(theta) + Sigma_W / n` for `(X, M, Y)` with
`M_B = a X_B + zeta_M`, `Var(zeta_M) = psi_M`, and compute the Fisher information of the between-level parameters with
`Sigma_W` fixed (a partial-information check; `n` = 10, `J` = 100).

| `psi_M` | smallest eigenvalue of the information | `SE(b_B)` | `Corr(b_B, c'_B)` |
|---|---|---|---|
| .50 | 50 | .122 | -.53 |
| .05 | 2.3 | .613 | -.95 |
| 0 | 9e-14 (singular) | not finite | not finite |

At `psi_M = 0` the between-level `M_B` is an exact function of `X_B`, so `b_B` and `c'_B` are not separately identified; the
information entry between `b_B` and `psi_M` is nonzero (9.1) while the one for `a_B` is zero. This is **not** the orthogonal
case: it is a nuisance parameter (`b_B`) that is not identified when another parameter (`psi_M`) sits on its boundary, which is
the "parameter not identified under the null" family. Andrews 2001 addresses a related setting (snippet only; the
abstract mentions a nuisance parameter present only under the alternative); whether its theorems apply here was not checked.
The consequence for the T-A statistic is conjectural. The open premise is the **profiled full-model information** (the
full two-level likelihood with the within-level covariance estimated, after profiling out the remaining nuisance parameters)
as `psi_M` goes to 0: the partial-information check above is not that calculation, and a positive fitted floor is a different
experiment from a true zero variance. If the premise holds, the null law near `psi_M = h / sqrt(J)` may depend on `h`; until it
is checked, no single reference law (chi-square(1), chi-bar-square, `min` of chi-squares) can be assumed or excluded. The existing single-level `mbco_sem()` documentation and IG3 section 4 ("no closed-form law is claimed") are
consistent with this. medfit's adapter thresholds (ICC and few-cluster warnings) are the practical guard.

Bootstrap calibration at the boundary: Andrews 2000 (SOURCE, introduction) shows the bootstrap is not consistent when a
parameter is on a boundary defined by inequality constraints, for the estimator's distribution; for a statistic whose null
law is discontinuous in a boundary nuisance parameter (Self and Liang), a parametric bootstrap that plugs in the estimated
nuisance parameter is therefore suspect near the boundary (INFERENCE). IG3's D2 ("calibrated by a parametric bootstrap at
small J") should carry that caveat.

### 3.5 Search scope for "joint LR law with product null, boundary variance and level-specific statistic"

Searched: the Zotero library (titles, plus creator lists for Drton, Self, Liang, Stram, Andrews, Silvapulle, Chernoff,
Shapiro); the MBCO papers' text; 3 web searches ("multilevel MBCO" and "two-level likelihood ratio indirect effect" as one
query, "Andrews 2001 boundary", "serial mediation two-level likelihood ratio"); two NotebookLM notebooks (answers
UNVERIFIED: "no source in the notebook treats it jointly"). Nothing found (INFERENCE). Absence is weak evidence: no search
of Web of Science, Scopus or the statistics and econometrics theory literature on "weak identification at the boundary".

## 4. Items (a), (b): small-J comparators and how T6 differs

### 4.1 What each comparator is

| | McNeish 2017 | Li and Beretvas 2013 | Zigler and Ye 2019 | Preacher, Zhang, Zyphur 2011 | Cox and Kelcey 2023 | Hait 2026 (preprint) | T6 (`studies/few-clusters/T6-results-memo.md`) |
|---|---|---|---|---|---|---|---|
| Design | 2-1-1 | 2-2-1, latent M and Y | **1-1-1** | 2-1-1 | 2-2-1 and 2-1-1 (cluster-randomized) | observed-mean level-specific estimators | **1-1-1** two-level, observed variables with latent cluster means |
| Estimator | REML+KR multilevel model; Mplus full-ML SEM; Mplus MCMC | Mplus MLR SEM; composites with a multilevel model | Mplus 7 MSEM; unconflated and conflated multilevel models | Mplus ML SEM; CMM and UMM | multilevel model; six tests incl. p3 | delta method, sandwich | lavaan two-level ML via the medfit adapter (P0, P1 floor) |
| Slopes | fixed | fixed | **random within a and b slopes** (cov(a_w, b_w) = -.113, 0, .113) | fixed (random b in supplement) | fixed | constant | fixed (Q3) |
| ICC | .20 only | .05, .15 | .1 and .3 (same for X, M, Y; also Y only) | .05 to .40 | .20 | varied | ICC_X .05, .20, .40 (ICC_M implied) |
| J | 10, 15, 25, 50, 100 | 20, 40, 80 | **30, 60, 100, 500** | 20 to 1,000 | 40, 80 | 15, 25, 40, 60, 100 | 10, 20, 30, 50, 100 |
| Cluster size | 7-14 or 80-160, unbalanced | 20, 40 balanced | 20, 40 balanced | 5, 20, 50 | 20, 40 | 10 to 30 | 5, 20; equal or CV about .5 |
| Null cells | none | (0,0), (.3,0), (0,.3) | between pathways 0 (within nonzero); all pathways 0 | none | double and single nulls | none | `NIE_B = 0` as `b_b = 0` only (never the origin) |
| Interval | delta, PRODCLIN, Monte Carlo | PRODCLIN | delta (Wald) only | not read | Sobel, joint, MC, bootstrap, p3 | delta | delta and Monte Carlo |
| Failures | only replications where all three methods converged (Table 2) | rates reported by G, ICC (up to about 40%); statistics on "1,000 converged solutions" | not found in the text read (convergence handling unverified) | converged only | not reported in the part read | not applicable | six explicit categories; unconditional and conditional coverage |
| Reps per cell | 1,000 | 1,000 | 1,000 | 2,000 | 500 | 600 | 1,000 (169,000 rows) |
| Small-J remedy | KR on the manifest-mean model | none | none (compares multilevel-model variants) | none | none | cluster bootstrap recommended, "not studied here" | none yet (T7 dropped for the next release) |

Also relevant, read at the abstract level only: **Li and Jia 2026** (*SEM*, DOI 10.1080/10705511.2026.2679039): ML versus Bayesian
estimators in a **1-2-1** mediation within MSEM with small and incomplete samples. It is a different design (upper-level
outcome), compares estimators rather than a small-sample interval remedy for ML, and its tables were not read.

Findings of the comparators relevant to B (SOURCE within each design): McNeish reports ML-SEM delta-interval coverage of 63%
to 97% against 93% to 97% for REML+KR, and a required J "closer to 50 rather than 100" in favorable cells; Li and Beretvas
recommend at least 80 clusters for their latent-variable model, with inadmissible rates of 19.7%, 6.7%, 2.5% at G = 20, 40,
80; Zigler and Ye state that theirs is the first direct comparison of MSEM, UMM and CMM in a 1-1-1 design, report between
Type I error below .02 for UMM and MSEM when all pathways are zero, and find UMM needs fewer groups than MSEM for power in
some cells; Hait reports between-level coverage rising from .883 at J = 15 to about .925, attributes the shortfall to the
sandwich variance at small J, and calls the bootstrap "safer" without testing it.

### 4.2 What T6 and proposal B add, and what they do not (INFERENCE from the table)

**Not new:** the existence of a small-J problem for ML-SEM mediation (McNeish, Li and Beretvas, Zigler and Ye, Hox et al.);
a 1-1-1 MSEM evaluation of between and within indirect effects (Zigler and Ye, with random slopes, J >= 30, balanced
clusters, delta intervals); the near-zero rejection at the all-zero null (Zigler and Ye, Cox and Kelcey, Li and Beretvas
Table 6 shows MLSEM coverage up to 100% in some `a = 0` cells). Any statement that a 1-1-1 slice is distinct, or that no
prior 1-1-1 cell exists, is wrong and was removed from the first version of this note.

**What remains different, as scope and accounting rather than as a model class:**

1. **Smaller J and smaller, unequal clusters.** Zigler and Ye start at J = 30 with balanced n = 20 and 40; T6 covers J = 10
   and 20, n = 5, and unequal sizes (CV about .5). T6's failure mass sits in unequal n = 5 cells (14 of 24 cells above 20%
   failure). McNeish's unbalanced cells (7 to 14, 80 to 160) are a different shape of imbalance and are not comparable
   without the size distributions.
2. **Fixed slopes (Q3) versus random slopes.** This is a model difference in medfit's favor of simplicity, not an advance;
   Zigler and Ye's random-slope design may be harder, and their results do not transfer in either direction without a run.
3. **Failure accounting and coverage-and-availability.** T6 counts a missing interval as a miss (unconditional) and also
   reports coverage over clean fits (conditional). It is therefore a coverage-and-availability measure; the within-level
   shortfall is availability (correlation .999 between coverage and availability across P0 cells). McNeish's all-converged
   filter and Li and Beretvas's "converged solutions" are conditional on convergence; whether Zigler and Ye's are is not
   known from the text read. This is an accounting difference, and its size depends on the conditioning each study used.
4. **The floor arm (P1).** No comparator read studies a level-2 variance floor. T6: failures fall to about 0, but the floor
   binds in a median 70% of fits and the sensitivity coverage (at-bound counted as a miss) is about .28 to .30.
5. **A matched same-estimand remedy** (cluster bootstrap on the same latent-mean fit) is not in any comparator read; Hait
   recommends it untested. It is not yet run in T6 (T7 dropped) and is the one arm that could make B more than guidance.

A contrast worth reading carefully: McNeish's ML-SEM coverage of 63% at J = 10 is conditional on joint convergence, while T6
shows low unconditional coverage mostly from missing intervals. The two are not contradictory (different design and
conditioning); no cell is a replication of the other.

### 4.3 What the comparators leave for T8

The T6 null cell is `b_b = 0` with `a_b != 0`. Li and Beretvas have three null patterns in a **2-2-1 latent-variable model**
(balanced, G >= 20); Zigler and Ye have between-zero and all-zero conditions in a **1-1-1 random-slope model** (J >= 30,
balanced, delta only); McNeish and Preacher et al. have no null cells. A T8 decision table that reports size at null cells
and a minimum J for unequal small clusters would be distinct as a **table over a different region of the design space**
(J = 10 to 30, n = 5, unequal sizes, fixed slopes, failure categories). Each ingredient is established. The earlier verdict
("guidance and validation, not new theory") stands, and after Zigler and Ye the stand-alone-paper case rests on the
remedy arm, not on the 1-1-1 setting.

## 5. Item (f): individual versus spillover split

### 5.1 Where the identity is stated

- In the repository: `vignettes/articles/methods.qmd` lines 259 to 285 give `own = a [b_W + (b_B - b_W)/n_j]` and
  `spillover = a (b_B - b_W)(n_j - 1)/n_j`, with derivation by shifting one member's mediator (SOURCE, repository text);
  GRILL ext-D D8 and D11 record the decision to ship the large-cluster approximation with a warning and to defer the exact
  version; `R/generics-effects.R` lines 742 to 770 implement the warning (the "D-own gap" `|a (b_B - b_W)| / H`).
- In the literature read: Cheng and Li 2026 define the cluster-average individual and spillover mediation effects by
  switching the member's own mediator or the other members' mediators (SOURCE), and their supplement's linear working model
  (s6) is `E[Y | A=a, M, C, N] = beta0 + beta1 M_j + beta2 mean(M_{-j}) + ...` (SOURCE). **No closed-form identity linking
  `(beta1, beta2)` to a within/between parametrization was found in the portions read** (main text sections 1 to 3 and parts of
  4; supplement s6 and Remark 4 region). VanderWeele et al. 2013 give nonparametric formulas for the two effects with a
  summary `G` of the others' mediators (SOURCE); no within/between algebra in the sections read. Talloen et al. 2016 is
  credited for the split in the project's own GRILL notes (unread here).

Older background (SOURCE): Blalock 1984 (OCR; sections) writes the contextual-effects model `Y_ij = a + b1 X_ij + b2 Xbar_j + e`
and its aggregate `Ybar_j = a + (b1 + b2) Xbar_j` (equations 4 and 5), the same `b_B = beta_own + beta_group` structure; his
text does not treat the group mean as including or excluding the individual (keyword scan: no hits). VanderWeele 2010 mentions
spillover effects only as future work in the passages found. So the finite-`n` translation between a leave-one-out peer mean and
a within/between parametrization is not stated in any source read except the project's own methods article; it follows from an
elementary change of regressors, and the claim here is only that it is documented in the repository, not that it is new or that
no paper states it.

### 5.2 Numerical check (SCRATCH, package installed from this worktree into a scratch library)

Data: 200 balanced clusters of 5, generated from a linear model in the member's own mediator and the mean of the others,
`beta1 = .4`, `beta2 = .2`. Two `lmer` fits (REML) with the same random intercept: (i) own mediator plus leave-one-out mean;
(ii) within-centered mediator plus observed cluster mean (medfit's parametrization).

| Quantity | Value |
|---|---|
| own coefficient, (i) | 0.38401506 |
| `b_W (n - 1)/n + b_B / n`, from (ii) | 0.38401506 |
| peer coefficient, (i) | 0.17362489 |
| `(n - 1)/n (b_B - b_W)`, from (ii) | 0.17362489 |
| own + peer | 0.55763995 |
| `b_B`, from (ii) | 0.55763995 |

The identity holds to 8 digits, as expected for a linear reparametrization of the fixed-effect design. `decompose()` on the
same data reports own 0.1668 and spillover 0.1063 (large-cluster approximation); the exact values `a [b_W + (b_B - b_W)/n]`
= 0.1881 and `a (b_B - b_W)(n - 1)/n` = 0.0850 equal `a beta1` and `a beta2` from fit (i). Truth is own 0.20, spillover 0.10
(estimation noise from one dataset; no calibration claim).

### 5.3 The one open piece: unequal cluster sizes (INFERENCE, light SCRATCH)

If `beta1`, `beta2` are constant, then `b_B = beta1 + beta2` is constant but
`b_W = beta1 - beta2 / (n_j - 1)` depends on the cluster size. With unequal sizes the two models are therefore not
equivalent: a model with constant `b_W` implies cluster-size-varying `(beta1, beta2)`, and conversely. A 20-replication
run (J = 400, sizes drawn from {3, 5, 10, 30}) gave mean `decompose()` own 0.2035 and spillover 0.1188 against truth .20
and .10, with the exact-form leave-one-out values .2134 and .1078: the discrepancies are small in that design and 20
replications do not support a calibration claim. The estimand question (which model is "true" under imbalance) is a
documentation and module-2 item (GRILL D8), not a research contribution.

### 5.4 Assumptions note (item C, narrowed)

SOURCE: Preacher, Zyphur and Zhang 2010 (discussion): all multilevel mediation models aside from 1-1-1 describe a mediation
effect "strictly at the between-group level of analysis"; Zhang et al. 2009: with group-mean centering, mediation effects
"exist only at Level-2"; Tofighi and Thoemmes 2014: with cluster-mean centering the indirect effect can only exist at the
cluster level, while grand-mean centering plus the cluster mean splits it into a within and a unique between (contextual)
indirect effect. Cheng and Li 2026: the individual and spillover split needs sequential ignorability and a between-individual
cross-world independence assumption (Assumption 5). INFERENCE: medfit's labels "own" and "spillover" are
interference-framework quantities that need the Cheng and Li and VanderWeele et al. assumptions; the project's methods
article already tabulates them (lines 303 to 306). Hait 2026 (preprint) adds estimands under partial interference with
cluster-mean exposure and a "contextual analogue"; its sections 4 and 5 were not read.

## 6. Item (g): the #504 sign-orthant question

GitHub issue #504 reports a spread warning on every `twolevel_equal_indirect()` fit and asks whether accepted starts reach
genuinely different local optima. In the repository the constraint `a_w b_w = a_b b_b` has 8 sign patterns compatible with the
equality (16 patterns for four signs, half with `sign(a_w b_w) = sign(a_b b_b)`).

### 6.1 What the optimization literature read says (SOURCE, sections)

Wang, Song and Xia 2021 (arXiv 2108.13729; sections read: abstract, introduction, section 2, Theorem 4.1 and its proof start):

- The generalized trust-region subproblem with an equality constraint, `min f(x)` subject to `g(x) = 0` with `f`, `g` quadratic
  and possibly indefinite, is exactly the form of the Gaussian-limit problem below (`f` positive definite, `g` a homogeneous
  indefinite quadratic).
- Moré's global characterization, as quoted there (Theorem 2.1, under a Slater condition): `x*` is a global minimizer iff
  `g(x*) = 0` and some `lambda*` satisfies `(A + lambda* B) x* + a + lambda* b = 0` with `A + lambda* B` positive semidefinite.
  Moré 1993 itself was not read (abstract snippet only); the statement is read in its quotation.
- Theorem 4.1: under a simultaneous-diagonalization condition (`mu1 A + mu2 B` positive definite for some `mu1, mu2`, which holds
  here with `A = W` positive definite), the number of local nonglobal minimizers is at most `min{n1 + 1, n}`; the secular
  function `phi(lambda)` has at most `2 min{n1 + 1, n}` zeros. Two-dimensional problems can have two local nonglobal minimizers.
  For `n = 4` the bound is 4, so scratch counts of at most one nonglobal minimizer are consistent with it but the bound is not
  tight in that case (not claimed to be).
- At a local nonglobal minimizer the standard second-order sufficient condition is necessary, and all local nonglobal
  minimizers can be found in polynomial time.

My scratch scan of `lambda` is the zero set of that secular function; the statement that "exactly one stationary point has
`W - lambda J` positive semidefinite" (200 of 200 diagonal-`W` draws, below) is Moré's characterization applied to this
instance.

### 6.2 Scratch computation in the Gaussian limit (SCRATCH, INFERENCE)

The nearest-point problem `min (x - t)' W (x - t)` subject to `x1 x2 = x3 x4`, with `J` the symmetric matrix such that
`grad g = J x` for `g(x) = x1 x2 - x3 x4`. Stationarity gives `(W - lambda J) x = W t`.

- With `W = I`: the constraint reduces to `c (1 + lambda^2) + lambda |t|^2 = 0`, `c = t1 t2 - t3 t4`; the two real roots satisfy
  `lambda1 lambda2 = 1`. The Hessian of the Lagrangian on the tangent space has eigenvalues `1 - lambda` and `1 + lambda`, so
  exactly one root has `|lambda| < 1` and is a local minimum; the other is a saddle. So in the identity metric the constrained
  optimum is unique (hand derivation; 100 of 100 random `t` confirmed numerically).
- With a random positive-definite `W` (a scan of `lambda` over [-6, 6], 3,001 points; one draw missed), 147 of 300 draws had two
  local minima. That scan range was too narrow for widely varying scales, so it is superseded by the next line.
- With a **diagonal** `W` (the realistic shape if the path estimators are uncorrelated), using a `lambda` range proportional to
  the largest eigenvalue of `W`: 24 of 200 draws (12%) had two local minima for log-precisions with standard deviation 1, and
  40 of 200 (20%) when the between-level precisions had standard deviation 2 on the log scale. In all 200 draws of the first
  set, exactly one stationary point satisfied `W - lambda J` positive semidefinite (the global certificate). An earlier,
  narrower grid had given 11% and 16%; the revised figures are the ones to use.

So a "twin" is a genuine second local minimum of the constrained fit when the information metric is anisotropic, not only an
optimizer artifact, and the global optimum is identified by the scalar equation plus the positive-semidefiniteness check.
The real likelihood is not quadratic, so this is a statement about the local quadratic model only. **Verdict:** known theory
applied to a specific constraint; the publishable value is as a software certificate in #504 (accept a start only if
`W - lambda J` is positive semidefinite at its multiplier; compare twins by the scalar equation), not as a paper. The
Euclidean-distance-degree literature (Draisma et al. 2016, record only) and the "Sign Switching" paper (snippet only;
the URL returned 404; the snippet concerns reflection of factor loadings in latent variable models, which is a different
kind of sign indeterminacy from a product constraint) were not read.

## 7. Search scopes and limits

- **Zotero library** (read-only copy of the database, 6,591 titled items): title searches for the terms in the task
  (boundary, singular, nonstandard, likelihood ratio, chi-bar, variance component, three-path, serial, sequential, spillover,
  interference, contextual, cluster-randomized mediation, Heywood, MBCO, bilinear, sign, Talloen, Asparouhov, Drton, Chernoff,
  Silvapulle, Self, Stram) and later "comparison of multilevel mediation" (which found Zigler and Ye, a miss of the first
  pass); creator searches for about 34 surnames; an abstract-field search for "three-path", "product of three",
  "serial mediation", "sequential mediation". Talloen, Asparouhov (the 2019 paper), Stram and Lee, Andrews 2001 and
  Silvapulle and Sen (PDF) are not available as readable files.
- **Web search:** 8 queries (MBCO multilevel; Andrews 2001; serial mediation two-level; few-cluster KR and bootstrap; sign
  indeterminacy and bilinear constraints; Moré 1993; Draisma et al.; Andrews Cowles paper), 3 more for the follow-up (the
  2026 SEM DOI, Crossref and OpenAlex metadata), and 6 page fetches (three PDFs read; Cowles paper and the Sign Switching
  PDF unavailable; publisher page 403). Summaries are UNVERIFIED; only fetched and read PDFs are cited as read.
- **NotebookLM:** two queries; answers UNVERIFIED.
- **Not a systematic review.** No search of Web of Science, Scopus or Google Scholar; no systematic query of the
  few-cluster mediation literature, which is how Zigler and Ye was first missed; the mathematics and optimization literature
  beyond two PDFs and a few snippets. Every "not found" in this note is limited to these scopes.
- **Not read** (extracted or listed only): Talloen 2016 and 2018, Preacher 2015, Silvapulle and Sen 2005, Stram and Lee 1994,
  Andrews 2001 (full text), Moré 1993, Rockwood thesis, Loh et al. 2022, Pustejovsky and Tipton 2018, Li and Jia 2026
  (beyond the abstract), the results tables of Zigler and Ye 2019, Preacher et al. 2011, Li and Beretvas 2013 (derivations).
- **SCRATCH computations** are not committed. Their scripts live in the session's scratch directory; the sign-orthant and
  information checks are small enough to reproduce from the descriptions in sections 3.4 and 6.

## 8. Open items after this note

1. **Zigler and Ye results tables.** Read the between-effect coverage and Type I tables against the T6 grid (J = 30 is the
   only shared J) before writing any statement about 1-1-1 small-J behavior.
2. **Profiled full-model information** for the two-level model as the level-2 residual variance of the mediator goes to 0.
   Not started; it decides whether proposal A's theory half has a premise. Retrieve Andrews 2001 in full first.
3. Read Talloen et al. 2016 around p. 367 and confirm the peer-mean definition against `methods.qmd`.
4. Read Hait 2026 sections 4 and 5 before any statement about interference estimands in medfit docs.
5. Decide whether the near-zero correlation of the path estimators holds in the latent-mean two-level model; it controls
   the size of the origin conservatism (section 3.2).
6. Read Pustejovsky and Tipton 2018 before naming any small-sample sandwich correction for an SEM score.
7. #504 remains with the `feature/504-twin-certificate` work; the secular-equation certificate is offered there, not
   implemented here.
