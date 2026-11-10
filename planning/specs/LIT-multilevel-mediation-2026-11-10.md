# Literature review: multilevel mediation, two-level SEM and the #394 plan

**Date:** 2026-11-10 · **Status:** DRAFT evidence note; nothing implemented, nothing posted on GitHub ·
**Issue:** [Data-Wise/medfit#394](https://github.com/Data-Wise/medfit/issues/394) ·
**Plan it supports:** `PLAN-multilevel-mediation-2026-11-10.md` (branch `claude/plan-multilevel-394-f40512`; not edited here).

## 0. How to read this note

**Two separate tags on every entry.** They are not interchangeable.

- **M (metadata).** `M=V` means the identifier resolved on the Crossref API and the returned first author, title, venue and
  pages match the work meant (checked 2026-11-10). `M=V-index` means it was matched on a publisher or journal index but has no
  DOI. `M=U` means not independently verified here (it comes from a secondary source or from the book's bibliography only).
  Years follow the print volume; where Crossref's issued year differs (usually online-first) the entry says so.
- **C (content).** `C=BOOK-READ` means the causal mediation book's own notes record a read of specific printed pages; any
  page or equation number in this note comes from those notes and nowhere else. `C=NOT-READ` means nobody on this task read the
  paper: the annotation uses only the title, the venue and (where stated) an abstract-level search summary, and gives **no**
  equation numbers, page numbers or numeric thresholds.

**How verification was done.** `/lit:ref` was invoked with no subcommand, so it only printed its routing text; its Zotero path
was unusable (the zotero MCP failed to connect, ECONNREFUSED). Verification was therefore done by hand against the Crossref
API (DOI lookup and title/author queries) and web search. `/lit:synthesize` loaded as a method description only (it needs a
supplied corpus); its no-fabrication guard was applied by hand. The `savant:literature-gap-finder`,
`savant:mediation-meta-analyst` and `savant:longitudinal-sequential-mediation` skills were **not** invoked: no pooled effects
are needed here and longitudinal designs are out of scope for #394. The gap analysis in section 6 is a manual Method by Setting
pass in the gap-finder's spirit, not its output.

**Carried-forward attribution caveats (do not promote).** From the book's
`docs/workflow/multilevel-propositions-2026-09-25.md`: the P1-P5 reading, the individual-weighted NIE^I covariance term
Cov(N_j, a_j b_j) / E[N_j], the self-inclusive own/spillover formulas, "no interference iff b_B = b_W", and Remark 1's
fixed-size equivalence are **"derived there; not found in the sources read."** They are not claims of this note. Everything in
the book's Proposition 1 that is attributed (NIE^C = ab + sigma_ab) is Kenny et al. (2003, eq. 9) and Bauer et al. (2006, eq. 5).

## 1. What the book has already established (Step 1, read-only)

Files read: `multilevel-propositions-2026-09-25.md`, `GRILL-part-multilevel-longitudinal-2026-09-25.md`,
`SPEC-multilevel-discrete-2026-09-26.md`, `PROPOSAL-ch-multilevel-sensitivity-2026-10-01.md`,
`BRIEF-ch-three-level-mediation-2026-10-02.md`, `NEEDS-PDF-multilevel.bib`, `GATE-lit-expand-2026-10-04.md`,
`RESEARCH-multilevel-2026-09-25.md`, the `references.bib` multilevel entries and the per-paper notes in
`notes/literature/multilevel-*.md`. Nothing in the book repository was written or run.

**Notation.** Clusters j = 1..J with N_j members; designs named by level as X-M-Y (2-1-1, 1-1-1, 2-2-1, 1-(1,1)-1, ...);
cluster-specific coefficients (alpha_j, a_j, beta_j, c'_j, b_j) drawn from a superpopulation; a = E a_j, b = E b_j,
sigma_ab = Cov(a_j, b_j); E_j over clusters; a_W, b_W, a_B, b_B for within and between slopes; UMM = group-mean-centered M plus
the observed cluster mean; MSEM = latent within/between split. Potential mediators M_ij(x).

**Established (with provenance).**

| Item | Status in the book | Source / caveat |
|---|---|---|
| E[a_j b_j] = ab + sigma_ab in 1-1-1 (cluster-equal weights) | Established, attributed | Kenny et al. 2003 eq. 9 (p. 118, bivariate normality); Bauer et al. 2006 eq. 5 |
| Individual-weighted NIE^I with Cov(N_j, a_j b_j) term | Derived in the book; **not found in the sources read** | Kenny's examples are balanced (200 x 10, 72 x 10) |
| Per-cluster OLS product a_j-hat b_j-hat unbiased for a_j b_j under P1-P4 | Derived in the book (checks B3/B5/B6) | Device for exhibiting conditions; the book does not recommend it over joint fits |
| Two readings of sigma_ab: part of the average NIE vs a signal of an omitted level-2 moderator | Decided (D10), conditions stated | Bauer 2006; Kenny 2003; Tofighi, West and MacKinnon 2013 (full orthogonality); Tofighi and Kelley 2016 |
| A cluster-varying X-by-M term manufactures an estimated sigma_ab near Var(a_j)/2 | Derived and simulated in the book (B5), scoped to V1-V2 and the per-cluster sample covariance | Not covered: P3 breaks, P1 breaks, joint random-coefficient sigma_ab. Never apply beyond that scope |
| Conflation: uncentered or grand-mean-centered M slope is a weighted blend of b_W and b_B | Established | Zhang, Zyphur and Preacher 2009 p. 704; Krull and MacKinnon 2001; Enders and Tofighi 2007. The precision-weight closed form is derived in the book, attribution open |
| UMM is biased for b_B when Y depends on a latent cluster mean; MSEM is not (but noisy) | Established and checked | Preacher, Zyphur and Zhang 2010 eq. 2 (p. 212, balanced 2-1-1, appendix A); Lüdtke et al. 2008 Study 3. Book check: MSEM between slope 2.3 times UMM's Monte Carlo SD at J = 200, n = 5 |
| Which estimator is unbiased depends on whether Y responds to the latent or the realized cluster mean | Established | Lüdtke et al. 2008 Study 3 and p. 223; book check: MSEM -.22 against true .14 under a realized-mean generator. The closed forms for the 2-1-1 b path were derived in the book, attribution open |
| Between-only rule: with any level-2 variable in X, M, Y the indirect effect exists only between clusters | Established | Preacher et al. 2010 pp. 210, 213, 222; Zhang et al. 2009 p. 704 for 2-1-1 |
| Four-step practice guide (right levels; check ICCs, fall back below about .05; fit within first; fit both) | Established | Preacher et al. 2010 p. 224; "Between model almost always differs from Within model" (same page) |
| Limits of MSEM: full ML only, two levels, small J can give inadmissible between estimates, delta-method CIs only in Mplus | Established | Preacher et al. 2010 pp. 222-223 |
| 2-1-1 potential-outcome estimands, own/peer split | Established for own/peer; rest derived | VanderWeele 2010 pp. 515-540 (individual-weighted averages, eq. 2); Talloen et al. 2016 eqs. 1-2, p. 365, additive class-level confounding p. 368 (M1) |
| Three-level strategies (VCM, CEM, CCM); effects cannot cross levels | Read | Preacher 2011, printed pp. 691-727 (book notes); CCM blends three levels' slopes (p. 714) |
| 1-1-1 interval estimators: L1 bootstrap fails when a slope varies; L2 and residual bootstraps hold up; brms intervals keep coverage | Read | Falk et al. 2024 (30/60/90 clusters of 60, normal, correct model only) |
| Skewed residuals in 2-1-1: "robust" resampling methods did worse than parametric bootstrap | Read | Pituch and Stapleton 2008 (random intercepts only, SAS) |
| Omitted-confounder sensitivity for two-level 1-1-1 with random slopes | Proposed chapter, source gate read | Tofighi and Kelley 2016 pp. 86-105; "diagnostic covariance is only a clue" |
| Non-Gaussian outcomes: GLMM coefficients are cluster-specific; ab + sigma_ab is not the marginal NIE | Spec implemented | SPEC-multilevel-discrete; medfit's Ext D lists glmer as a non-goal |

**Flagged unverified or needing a PDF (carry forward unchanged).** NEEDS-PDF (absent from Zotero): VanderWeele, Hong, Jones and
Brown (2013); Qin and Hong (2017); Field and Welsh (2007); Falk et al. (2024; later read via another copy); Cao and Li (2025);
Kim and Steiner (2021). File missing: Preacher (2011, three-level; later read per `references.bib`). No attachment: Raudenbush
and Bryk (2002), the lead for the precision-weight attribution. Unread Tier 2: Preacher, Zhang and Zyphur (2011); Marsh et al.
(2009); Pituch, Whittaker and Stapleton (2005); Pituch, Stapleton and Kang (2006); Hox et al. (2014); Li and Beretvas (2013);
Grund, Lüdtke and Robitzsch (2017); Kreft, de Leeuw and Aiken (1995); Snijders and Bosker (1999). Unread in read papers:
Lüdtke et al. (2008) supplement; VanderWeele (2010) online appendix with proofs; Talloen (2016) online appendices. The
book's Zhang et al. note adds a caveat the paper does not state: CWC(M) recovers the between slope only when Y depends on the
realized group mean. **Open items flagged by the book itself** (do not rely on): Tofighi et al. 2013 Table 1 c'_w against
eq. 20 and an "RMSE" column; Krull and MacKinnon 2001 coach SE .0170 vs eq. 5's .0151; Enders and Tofighi 2007 two gross t
misses and the p. 131 equivalence scope; Kenny 2003 Table 1 mixing sigma_ab = .112/.113.

**What the book does not have:** a two-level likelihood derivation, any treatment of unbalanced cluster-wise ML, identification
of the joint two-level model, sandwich or cluster-robust SEs for two-level SEM, shared (cross-level) measurement loadings,
Heywood handling, FIML in clusters, or a within-minus-between indirect-effect contrast with a joint covariance.

## 2. Annotated bibliography

### (a) Multilevel mediation estimation

**a1. Kenny, D. A., Korchmaros, J. D., & Bolger, N. (2003).** Lower level mediation in multilevel models. *Psychological
Methods, 8*(2), 115-128. doi:10.1037/1082-989X.8.2.115 · **M=V · C=BOOK-READ (pp. 115-127).** 1-1-1 with random a and b; gives
E[a_j b_j] = ab + sigma_ab (eq. 9, p. 118) under normality and states it fails without it. Estimator: per-unit OLS slopes,
unweighted covariance. Bears on #394: estimand definition for the average indirect effect and the cross-path covariance;
no joint likelihood, no SE with cross-level covariance.

**a2. Bauer, D. J., Preacher, K. J., & Gil, K. M. (2006).** Conceptualizing and testing random indirect effects and moderated
mediation in multilevel models: New procedures and recommendations. *Psychological Methods, 11*(2), 142-163.
doi:10.1037/1082-989X.11.2.142 · **M=V · C=BOOK-READ (pp. 142-160, appendix 162-163).** Stacked single-equation mixed model with
five random effects; returns the covariance of random effects (including Cov(a_j, b_j)) and the sampling covariance of
estimates; separates heterogeneity of the indirect effect from precision of the average ab + sigma_ab (eq. 5; eqs. 9-10
sampling variances); 168-cell simulation, coverage about 94% normal and about 90% skewed random effects (p. 151). Assumes
uncorrelated M and Y level-1 residuals, "required to identify" the M to Y effect (p. 144). Unbalanced designs and latent
variables are named as limitations (p. 159). Bears on #394: this is the random-slope estimand the plan excludes (a different
estimand, ab + sigma_ab), and the identification assumption for b; the product-term SE with a joint covariance appears here
in mixed-model form.

**a3. Krull, J. L., & MacKinnon, D. P. (2001).** Multilevel modeling of individual and group level mediated effects.
*Multivariate Behavioral Research, 36*(2), 249-277 (Crossref pages 249-277; the book read pp. 249-275).
doi:10.1207/S15327906MBR3602_06 · **M=V · C=BOOK-READ.** Single-level vs multilevel mediation with group-level and individual-level
effects, delta-type standard errors. The book flags one SE miss (.0170 vs .0151). Bears on #394: early SE formulas to
cross-check the delta method; not a joint-likelihood source.

**a4. Zhang, Z., Zyphur, M. J., & Preacher, K. J. (2009).** Testing multilevel mediation using hierarchical linear models:
Problems and solutions. *Organizational Research Methods, 12*(4), 695-719 (Crossref issued 2008 online-first).
doi:10.1177/1094428108327450 · **M=V · C=BOOK-READ (pp. 695-717).** Uncentered M mixes within and between slopes (p. 704); recommends
group-mean centering with the cluster mean reintroduced (UMM). Bears on #394: centering and the within/between decomposition
for the manifest-mean option (plan question 3); the book adds the realized-vs-latent-mean caveat.

**a5. Preacher, K. J., Zyphur, M. J., & Zhang, Z. (2010).** A general multilevel SEM framework for assessing multilevel
mediation. *Psychological Methods, 15*(3), 209-233. doi:10.1037/a0020141 · **M=V · C=BOOK-READ (pp. 209-224, appendix A 228-229).**
Splits every level-1 variable into latent within and between parts and fits both structural models jointly; Between-only rule;
UMM bias under a latent mean (eq. 2); four-step guide; between and within models "almost always" differ. Uses Mplus full ML, no
REML; delta-method CIs only in Mplus, Monte Carlo CIs through a utility. Bears on #394: the closest published specification of
what #394 plans (within and between structural models with latent cluster means) and its limits; supports latent-mean
parameterization and warns that the between structural model is generally not the within model.

**a6. Preacher, K. J., Zhang, Z., & Zyphur, M. J. (2011).** Alternative methods for assessing mediation in multilevel data:
The advantages of multilevel SEM. *Structural Equation Modeling, 18*(2), 161-182. doi:10.1080/10705511.2011.557329 ·
**M=V · C=NOT-READ** (in Zotero; Tier 2 unread). By title, a simulation or comparison of multilevel SEM against regression
approaches for multilevel mediation. Bears on #394 only as a pointer for small-sample behavior; read before citing any result.

**a7. Preacher, K. J. (2011).** Multilevel SEM strategies for evaluating mediation in three-level data. *Multivariate Behavioral
Research, 46*(4), 691-731 (book read pp. 691-727). doi:10.1080/00273171.2011.589280 · **M=V · C=BOOK-READ.** Three-level
VCM/CEM/CCM; a slope blended over levels when slopes vary; "no generally available software" at the time (p. 693); VCM
cannot allow random level-1 slopes across level 2 without misspecification (p. 705). Bears on #394: out of scope (three
levels), but p. 705 is the nearest read source on what a fixed-slope model does when slopes vary.

**a8. Tofighi, D., West, S. G., & MacKinnon, D. P. (2013).** Multilevel mediation analysis: The effects of omitted variables in
the 1-1-1 model. *British Journal of Mathematical and Statistical Psychology, 66*(2), 290-307 (Crossref issued 2012 online).
doi:10.1111/j.2044-8317.2012.02051.x · **M=V · C=BOOK-READ (pp. 290-307).** Omitted level-2 moderator can produce sigma_ab; the
omitted-moderator reading holds under full orthogonality. Two open misses are logged in the book (c'_w vs eq. 20; RMSE column).
Bears on #394: the interpretation of a nonzero random-slope covariance; reinforces that the plan's estimand is not the
random-slope average.

**a9. Tofighi, D., & Kelley, K. (2016).** Assessing omitted confounder bias in multilevel mediation models. *Multivariate
Behavioral Research, 51*(1), 86-105. doi:10.1080/00273171.2015.1105736 · **M=V · C=BOOK-READ (pp. 86-105).** Quantitative
sensitivity for a two-level 1-1-1 model with random intercepts and slopes and one known or proxy confounder; MSEM-based; the
book reproduced the published ranges from the saved estimates but did not independently reproduce the MSEM fits. Bears on #394:
a later sensitivity layer; same within/between two-level mediation target.

**a10. Tofighi, D., & Thoemmes, F. (2014).** Single-level and multilevel mediation analysis. *Journal of Early Adolescence,
34*(1), 93-119 (Crossref issued 2013 online). doi:10.1177/0272431613511331 · **M=V · C=NOT-READ** (Zotero Tier 2). Tutorial
overview by the same author group; use for software notes after reading.

**a11. Tofighi, D., MacKinnon, D. P., & Yoon, M. (2009).** Covariances between regression coefficient estimates in a single
mediator model. *British Journal of Mathematical and Statistical Psychology, 62*(3), 457-484. doi:10.1348/000711008X331024 ·
**M=V · C=NOT-READ.** By title, the covariance between the a and b estimates in a single-level model, which is the term the
delta-method SE of a product needs; the multilevel analogue is the cross-block of the joint covariance. Bears on #394: SE
theory for the product; confirm content before quoting.

**a12. Tofighi, D., & MacKinnon, D. P. (2011).** RMediation: An R package for mediation analysis confidence intervals. *Behavior
Research Methods, 43*(3), 692-700. doi:10.3758/s13428-011-0076-x · **M=V · C=BOOK-READ (pp. 692-699).** **Tofighi, D., &
MacKinnon, D. P. (2016).** Monte Carlo confidence intervals for complex functions of indirect effects. *Structural Equation
Modeling, 23*(2), 194-205 (Crossref issued 2015 online). doi:10.1080/10705511.2015.1057284 · **M=V · C=BOOK-READ (pp. 194-202,
appendix 204-205).** Distribution-of-product and Monte Carlo intervals from an estimate vector and its covariance. Bears on
#394: the Monte Carlo interval for the contrast a_w b_w - a_B b_B is a candidate that needs only the joint covariance.

**a13. Tofighi, D., & Kelley, K. (2020).** Improved inference in mediation analysis: Introducing the model-based constrained
optimization procedure. *Psychological Methods, 25*(4), 496-515. doi:10.1037/met0000259 · **M=V · C=BOOK-READ (pp. 496-501 and
sections).** Likelihood-based (constrained) test for the indirect effect. **Tofighi, D., & Kelley, K. (2020).** Indirect effects
in sequential mediation models: Evaluating methods for hypothesis testing and confidence interval formation. *Multivariate
Behavioral Research, 55*(2), 188-210 (Crossref issued 2019 online). doi:10.1080/00273171.2019.1618545 · **M=V · C=BOOK-READ
(pp. 188-200, 205-207).** Bears on #394: the MBCO idea is a likelihood-ratio route that medfit already has for single-level
SEMs (`mbco_sem()`); whether it extends to a two-level contrast is a design question, not a literature result.

**a14. Enders, C. K., & Tofighi, D. (2007).** Centering predictor variables in cross-sectional multilevel models: A new look at
an old issue. *Psychological Methods, 12*(2), 121-138. doi:10.1037/1082-989X.12.2.121 · **M=V · C=BOOK-READ (pp. 121-138).**
Group-mean vs grand-mean centering; the book flags a p. 131 equivalence claim that holds for targets but not for estimates
under random slopes. Bears on #394: centering choices for the manifest-mean option.

**a15. Lüdtke, O., Marsh, H. W., Robitzsch, A., Trautwein, U., Asparouhov, T., & Muthén, B. (2008).** The multilevel latent
covariate model. *Psychological Methods, 13*(3), 203-229. doi:10.1037/a0012869 (DOI from Crossref title query) · **M=V ·
C=BOOK-READ (pp. 203-229, supplement unread).** Latent vs manifest group means; the MMC/MLC contrast in Study 3 and p. 223;
sampling-ratio argument; precision cost of the latent route (pp. 213-214). Bears on #394: the case for latent cluster means as
the default and for stating which cluster-level causal story the estimator assumes.
**Lüdtke, O., Marsh, H. W., Robitzsch, A., & Trautwein, U. (2011).** A 2 x 2 taxonomy of multilevel latent contextual models:
Accuracy-bias trade-offs in full and partial error-correction models. *Psychological Methods, 16*(4), 444-467.
doi:10.1037/a0024376 · **M=V · C=NOT-READ.** By title, extends the latent/manifest trade-off.
**Marsh, H. W., et al. (2009).** Doubly-latent models of school contextual effects. *Multivariate Behavioral Research, 44*(6),
764-802. doi:10.1080/00273170903333665 · **M=V · C=NOT-READ.**

**a16. Asparouhov, T., & Muthén, B. (2019).** Latent variable centering of predictors and mediators in multilevel and time-series
models. *Structural Equation Modeling, 26*(1), 119-142 (Crossref issued 2018 online). doi:10.1080/10705511.2018.1511375 ·
**M=V · C=NOT-READ.** By title, latent-variable centering for predictors and mediators, i.e. the manifest-vs-latent
mean question applied to mediation. Bears on #394 plan question 3; read before relying.

**a17. Rights, J. D., et al. (2020).** The danger of conflating level-specific effects of control variables when primary
interest lies in level-2 effects. *British Journal of Mathematical and Statistical Psychology, 73*(2), 194-211 (Crossref issued
2019 online; first author Rights, remaining authors not checked here). doi:10.1111/bmsp.12194 · **M=V · C=NOT-READ.** By title,
directly about level-specific effects of covariates. Bears on #394's cluster-only covariate treatment; read before using.

**a18. Raudenbush, S. W., & Sampson, R. (1999).** Assessing direct and indirect effects in multilevel designs with latent
variables. *Sociological Methods & Research, 28*(2), 123-153. doi:10.1177/0049124199028002001 · **M=V · C=NOT-READ.** By title,
an early latent-variable multilevel direct/indirect-effect treatment. Bears on #394 as an early source for latent
between-level quantities; read before citing.

**a19. Raudenbush, S. W., & Bryk, A. S. (2002).** *Hierarchical linear models* (2nd ed.). Sage. · **M=U** (book, not
Crossref-indexed; existence from the book's Zotero record only) · **C=NOT-READ** (the book lists it as the lead for the precision-weight attribution).

**a20. Hayes, A. F., & Rockwood, N. J. (2020).** Conditional process analysis: Concepts, computation, and advances in the modeling
of the contingencies of mechanisms. *American Behavioral Scientist, 64*(1), 19-54 (Crossref issued 2019 online).
doi:10.1177/0002764219859633 · **M=V · C=NOT-READ.** Single-level conditional-process emphasis, tangential to #394.
**Rockwood, N. J., & Hayes, A. F. (2022).** Multilevel mediation analysis (chapter), in *Multilevel Modeling Methods with
Introductory and Advanced Applications*, pp. 567-597. doi:10.1108/978-1-64802-873-120251020 · **M=V** (Crossref record; the
DOI string carries a 2025 stamp while the issued year is 2022, so confirm the year and editors before citing) · **C=NOT-READ.**
Software-oriented (an SPSS macro, per the title search); bears only on user-facing expectations. Hayes's 2013 book is not
verified here (**M=U**).

**a21. Pituch, K. A., & Stapleton, L. M. (2008).** The performance of methods to test upper-level mediation in the presence of
nonnormal data. *Multivariate Behavioral Research, 43*(2), 237-267. doi:10.1080/00273170802034844 · **M=V · C=BOOK-READ (pp.
237-265).** 2-1-1 only, random intercepts only, 20 or 40 sites; the "robust" resampling methods did worse than the parametric
bootstrap and empirical-M test. Bears on #394's sandwich/bootstrap option: "robust" is not automatically better, and this
evidence is 2-1-1, not two-level SEM. **Pituch, Whittaker, & Stapleton (2005)** MBR 40(1), 1-23, doi:10.1207/s15327906mbr4001_1
**M=V · C=NOT-READ.** **Pituch, Stapleton, & Kang (2006)** MBR 41(3), 367-400, doi:10.1207/s15327906mbr4103_5 **M=V ·
C=NOT-READ.** **Pituch, Murphy, & Tate (2010)** Three-level models for indirect effects in school- and class-randomized
experiments in education. *Journal of Experimental Education, 78*(1), 60-95 (Crossref issued 2009; print year to confirm),
doi:10.1080/00220970903224685 **M=V · C=NOT-READ.**

**a22. Falk, C. F., Vogel, T. A., Hammami, S., & Miočević, M. (2024).** Multilevel mediation analysis in R: A comparison of
bootstrap and Bayesian approaches. *Behavior Research Methods, 56*(2), 750-764 (Crossref issued 2023 online).
doi:10.3758/s13428-023-02079-4 · **M=V · C=BOOK-READ (pp. 750-764).** See section 1. Cluster resampling and brms intervals hold up
at 30-90 clusters of 60 (balanced, normal, correct model); level-1 bootstrap fails when a slope varies. Bears on #394: supports
cluster resampling for the bootstrap option; says nothing about unbalanced clusters, few clusters, or SEM.
**Field, C. A., & Welsh, A. H. (2007).** Bootstrapping clustered data. *Journal of the Royal Statistical Society B, 69*(3),
369-390. doi:10.1111/j.1467-9868.2007.00593.x · **M=V · C=NOT-READ** (NEEDS-PDF in the book). General theory of cluster
bootstrap schemes.

**a23. Software for estimation.** **Rosseel, Y. (2012).** lavaan: An R package for structural equation modeling. *Journal of
Statistical Software, 48*(2). doi:10.18637/jss.v048.i02 · **M=V · C=NOT-READ.** **lavaan multilevel tutorial**,
https://lavaan.ugent.be/tutorial/multilevel.html · **M=V-index** (located by web search; page not fully read) · **C=NOT-READ
beyond the search summary.** Summary: separate `level: 1`/`level: 2` blocks, `cluster =` in the fit call, random intercepts
only, continuous data, non-convergence tied to few clusters with almost no between-level variance, example data
`Demo.twolevel`. **Vuorre, M., & Bolger, N. (2018).** Within-subject mediation analysis for experimental data in cognitive
psychology and neuroscience. *Behavior Research Methods, 50*(5), 2125-2143 (Crossref issued 2017 online).
doi:10.3758/s13428-017-0980-9 · **M=V · C=NOT-READ** (the book routes it to the within-person chapter). The `bmlm` package
(Vuorre) is on CRAN, doi:10.32614/cran.package.bmlm **M=V (CRAN record) · C=NOT-READ.** **Bürkner, P.-C. (2017).** brms: An R
package for Bayesian multilevel models using Stan. *Journal of Statistical Software, 80*(1). doi:10.18637/jss.v080.i01 **M=V ·
C=NOT-READ.** Mplus is the reference implementation for the MSEM papers above (Preacher et al. 2010 used full ML in Mplus).

### (b) The math: likelihood, estimators, SEs, behavior in small samples

None of these entries was read by anyone on this task. Where the book read a paper, that is stated; otherwise the annotation is
title-level only.

**b1. Goldstein, H., & McDonald, R. P. (1988).** A general model for the analysis of multilevel data. *Psychometrika, 53*(4),
455-467. doi:10.1007/BF02294400 · **M=V · C=NOT-READ.** **McDonald, R. P., & Goldstein, H. (1989).** Balanced versus unbalanced
designs for linear structural relations in two-level data. *British Journal of Mathematical and Statistical Psychology,
42*(2), 215-232. doi:10.1111/j.2044-8317.1989.tb00911.x · **M=V · C=NOT-READ.** By title, the two-level structural model and the
balanced-vs-unbalanced distinction. Bears on #394: candidate origin of the group-wise (cluster-size-specific) likelihood
the plan sketches from the oracle; confirm before citing the form.

**b2. Muthén, B. O. (1989).** Latent variable modeling in heterogeneous populations. *Psychometrika, 54*(4), 557-585.
doi:10.1007/BF02296397 · **M=V · C=NOT-READ.** By title a multi-group paper; its role in two-level estimation is asserted in the
request and in secondary literature but **not checked here**. **Muthén, B. O. (1990).** Mean and covariance structure analysis
of hierarchical data. Paper at the Psychometric Society meeting, Princeton; UCLA Statistics Series 62 · **M=U** (existence
confirmed only through secondary reference lists in a web search; no primary copy found; Muthén's page says copies are by
request) · **C=NOT-READ.** **Muthén, B. O. (1994).** Multilevel covariance structure analysis. *Sociological Methods &
Research, 22*(3), 376-398. doi:10.1177/0049124194022003006 · **M=V · C=NOT-READ.** **Muthén, B., & Satorra, A. (1995).** Complex
sample data in structural equation modeling. *Sociological Methodology, 25*, 267 (Crossref lists the start page only).
doi:10.2307/271070 · **M=V · C=NOT-READ.** These are the standard references for the pseudo-balanced ("MUML") approach; the
description of MUML as an approximate, consistent-but-not-full-ML estimator is secondary (see Yuan and Hayashi, b4) and was
not verified from the primary papers.

**b3. Lee, S.-Y., & Poon, W.-Y. (1998).** Analysis of two-level structural equation models via EM type algorithms. *Statistica
Sinica, 8*(3), 749-766. No DOI; **M=V-index** (the journal's index page and secondary citations agree on volume and pages) ·
**C=NOT-READ.** By the search summary of the abstract: ML for a general two-level SEM with unbalanced design framed as a
missing-data problem with latent group vectors treated as missing. **Liang, J., & Bentler, P. M. (2004).** An EM algorithm for
fitting two-level structural equation models. *Psychometrika, 69*(1), 101-122. doi:10.1007/BF02295842 · **M=V · C=NOT-READ.**
**Bentler, P. M., & Liang, J. (2003).** Two-level mean and covariance structures: Maximum likelihood via an EM algorithm, in
*Multilevel Modeling* (Routledge), pp. 55-70. doi:10.4324/9781410606747-7 · **M=V** (Crossref; chapter, editors not
checked) **· C=NOT-READ.** Bears on #394: full-ML (EM) estimation for unbalanced two-level SEM is established; the plan's
cluster-size-grouped likelihood plus a general optimizer is a different computation of the same ML quantity, which the lavaan
match in the plan's research already tests numerically.

**b4. Yuan, K.-H., & Hayashi, K. (2005).** On Muthén's maximum likelihood for two-level covariance structure models.
*Psychometrika, 70*(1), 147-167. doi:10.1007/s11336-003-1070-8 · **M=V · C=NOT-READ.** By title, a study of Muthén's ML
estimator for the two-level model; use it to state exactly when the pseudo-balanced estimator departs from full ML (not
verified here). **Bentler, P. M., et al. (2011).** Constrained maximum likelihood estimation for two-level mean and covariance
structure models. *Educational and Psychological Measurement, 71*(2), 325-345. doi:10.1177/0013164410381272 · **M=V ·
C=NOT-READ** (first author Bentler per Crossref; co-authors not checked). By title, ML with parameter constraints for
two-level models, relevant to admissibility.

**b5. Yuan, K.-H., & Bentler, P. M. (2002).** On normal theory based inference for multilevel models with distributional
violations. *Psychometrika, 67*(4), 539-561. doi:10.1007/BF02295130 · **M=V · C=NOT-READ.** **Yuan, K.-H., & Bentler, P. M.
(2007).** Multilevel covariance structure analysis by fitting multiple single-level models. *Sociological Methodology, 37*(1),
53-82. doi:10.1111/j.1467-9531.2007.00182.x · **M=V · C=NOT-READ.** **Yuan, K.-H., & Bentler, P. M. (2000).** Three
likelihood-based methods for mean and covariance structure analysis with nonnormal missing data. *Sociological Methodology,
30*(1), 165-200. doi:10.1111/0081-1750.00078 · **M=V · C=NOT-READ.** Bears on #394: the sandwich (robust) route in two-level
SEM and likelihood-based handling of missing data; the plan's S6/S7 depend on content that was not read.
**Cameron, A. C., & Miller, D. L. (2015).** A practitioner's guide to cluster-robust inference. *Journal of Human Resources,
50*(2), 317-372. doi:10.3368/jhr.50.2.317 · **M=V · C=NOT-READ.** General cluster-robust variance background, not SEM-specific;
the few-clusters problem for cluster-robust SEs is a general theme there (title-level knowledge only).

**b6. Hox, J. J., & Maas, C. J. M. (2001).** The accuracy of multilevel structural equation modeling with pseudobalanced groups
and small samples. *Structural Equation Modeling, 8*(2), 157-174. doi:10.1207/S15328007SEM0802_1 · **M=V · C=NOT-READ.**
**Hox, J. J., Maas, C. J. M., & Brinkhuis, M. J. S. (2010).** The effect of estimation method and sample size in multilevel
structural equation modeling. *Statistica Neerlandica, 64*(2), 157-170. doi:10.1111/j.1467-9574.2009.00445.x · **M=V ·
C=NOT-READ.** **Maas, C. J. M., & Hox, J. J. (2005).** Sufficient sample sizes for multilevel modeling. *Methodology, 1*(3),
86-92. doi:10.1027/1614-2241.1.3.86 · **M=V · C=NOT-READ.** **McNeish, D., & Stapleton, L. M. (2016).** Modeling clustered data
with very few clusters. *Multivariate Behavioral Research, 51*(4), 495-518. doi:10.1080/00273171.2016.1167008 · **M=V ·
C=NOT-READ.** **McNeish, D. (2017).** Small sample methods for multilevel modeling: A colloquial elucidation of REML and the
Kenward-Roger correction. *Multivariate Behavioral Research, 52*(5), 661-670. doi:10.1080/00273171.2017.1344538 · **M=V ·
C=NOT-READ.** **Depaoli, S., & Clifton, J. P. (2015).** A Bayesian approach to multilevel structural equation modeling with
continuous and dichotomous outcomes. *Structural Equation Modeling, 22*(3), 327-351. doi:10.1080/10705511.2014.937849 ·
**M=V · C=NOT-READ.** Bears on #394: small-J and pseudo-balanced behavior. **No numeric threshold for J is taken from any of
these** because none was read; the plan's "warn below about 50, error below about 10" (research 4.6) has no source in this
note and stays a project decision.

**b7. Heywood and improper solutions.** **Chen, F., Bollen, K. A., Paxton, P., Curran, P. J., & Kirby, J. B. (2001).** Improper
solutions in structural equation models: Causes, consequences, and strategies. *Sociological Methods & Research, 29*(4),
468-508. doi:10.1177/0049124101029004003 · **M=V · C=NOT-READ.** **Kolenikov, S., & Bollen, K. A. (2012).** Testing negative error
variances: Is a Heywood case a symptom of misspecification? *Sociological Methods & Research, 41*(1), 124-167.
doi:10.1177/0049124112442138 · **M=V · C=NOT-READ** (subtitle from memory; Crossref returned the main title only). Bears on
#394: the policy question "admissible vs converged"; the book's Preacher 2010 note (pp. 222-223) is the only read source tying
inadmissible between-level estimates to few clusters.

**b8. Larsen, R. (2011).** Missing data imputation versus full information maximum likelihood with second-level dependencies.
*Structural Equation Modeling, 18*(4), 649-662. doi:10.1080/10705511.2011.607721 · **M=V · C=NOT-READ.** By title, FIML vs
imputation when data are clustered.

**b9. Product and delta method.** **Sobel, M. E. (1982).** Asymptotic confidence intervals for indirect effects in structural
equation models. *Sociological Methodology, 13*, 290. doi:10.2307/270723 · **M=V · C=NOT-READ.** The delta-method SE of a
product uses the covariance of the two estimates (see a11); for a contrast across levels the gradient is taken over the joint
covariance (the plan's own verification against lavaan `:=` SEs is the primary evidence here, not any paper).

### (c) Multilevel SEM: shared loadings, latent mediators, software, fit and missing data

**c1. Mehta, P. D., & Neale, M. C. (2005).** People are variables too: Multilevel structural equations modeling. *Psychological
Methods, 10*(3), 259-284. doi:10.1037/1082-989X.10.3.259 · **M=V · C=NOT-READ.** By title, a multilevel SEM framework built from
individual-level models with random coefficients (the SEM-as-mixed-model view). Bears on #394: the alternative
(random-coefficient) formulation and its link to slopes that vary; read before claiming anything about shared loadings.

**c2. Rabe-Hesketh, S., Skrondal, A., & Pickles, A. (2004).** Generalized multilevel structural equation modeling.
*Psychometrika, 69*(2), 167-190. doi:10.1007/BF02295939 · **M=V · C=NOT-READ.** GLLAMM framework (title-level). Bears on #394:
a general latent-variable multilevel framework (non-Gaussian responses, latent variables at several levels) that sits outside
the plan's Gaussian scope.

**c3. Jak, S., Oort, F. J., & Dolan, C. V. (2013).** A test for cluster bias: Detecting violations of measurement invariance
across clusters in multilevel data. *Structural Equation Modeling, 20*(2), 265-282. doi:10.1080/10705511.2013.769392 · **M=V ·
C=NOT-READ.** **Jak, S., Oort, F. J., & Dolan, C. V. (2014).** Measurement bias in multilevel data. *Structural Equation
Modeling, 21*(1), 31-39. doi:10.1080/10705511.2014.856694 · **M=V · C=NOT-READ.** **Jak, S., et al. (2017).** Relating
measurement invariance, cross-level invariance, and multilevel reliability. *Frontiers in Psychology, 8*, 1640.
doi:10.3389/fpsyg.2017.01640 · **M=V** (first author Jak per Crossref; co-authors not checked) **· C=NOT-READ.** By title,
these treat when measurement is the same across clusters and how that relates to equal loadings across levels. Bears on #394:
equal within and between loadings is a **testable restriction** (title-level reading), not a default; the plan should offer a
test or at least a diagnostic. Details (which parameters, which tests) must be read from the papers.

**c4. Stapleton, L. M., et al. (2016).** Construct meaning in multilevel settings. *Journal of Educational and Behavioral
Statistics, 41*(5), 481-520. doi:10.3102/1076998616646200 · **M=V** (first author Stapleton per Crossref; co-authors not
checked) **· C=NOT-READ.** By title, what a construct means at each level; bears on whether a between-level latent mediator
means the same thing as the within-level one.

**c5. Talloen, W., et al. (2019).** Consequences of unreliability of cluster means and unmeasured confounding on the estimation
of contextual effects. *Structural Equation Modeling, 26*(2), 191-211 (Crossref title begins "Consequences of Unreliability of
Cluster Means and Unmeasure..."; remainder truncated in the lookup; issued year per Crossref 2018 online). doi:10.1080/10705511.2018.1533406
· **M=V** (truncated title) **· C=NOT-READ.** Bears on #394: latent vs manifest cluster means for contextual effects.

**c6. Fit and missing data in multilevel SEM.** No primary source on level-specific fit indices or on pattern-wise cluster
likelihood with missing data was located and verified for this note beyond b5 and b8 (titles only). This is a gap (section 6).

### (d) Causal multilevel mediation (only as it bears on a SEM estimator)

**d1. VanderWeele, T. J. (2010).** Direct and indirect effects for neighborhood-based clustered and longitudinal data.
*Sociological Methods & Research, 38*(4), 515-544 (Crossref pages; the book read pp. 515-540). doi:10.1177/0049124110366236 ·
**M=V · C=BOOK-READ (pp. 515-540, online appendix proofs unread).** Potential-outcome NDE/NIE for clustered data with
individual-weighted averages (eq. 2); NIE defined with own and others' mediators moving together (pp. 532-533), not split. Bears
on #394: the causal reading of the within effect is individual-weighted; the 1-1-1 estimand in a SEM is not stated here.

**d2. Talloen, W., Moerkerke, B., Loeys, T., De Naeghel, J., Van Keer, H., & Vansteelandt, S. (2016).** Estimation of indirect
effects in the presence of unmeasured confounding for the mediator-outcome relationship in a multilevel 2-1-1 mediation model.
*Journal of Educational and Behavioral Statistics, 41*(4), 359-391 (the book read pp. 359-387). doi:10.3102/1076998616636855 ·
**M=V · C=BOOK-READ.** Within-slope identification under additive cluster-level confounding in linear 2-1-1 (M1, p. 368; p. 385
"in linear models"); own/peer split eqs. 1-2, p. 365. Bears on #394: supports using within-cluster variation when the primary
concern is cluster-level confounding of M and Y; scope is linear and additive. Note the book's caveat that the self-inclusive
formulas and "b_B = b_W iff no interference" are **derived in the book, not found in Talloen**.

**d3. VanderWeele, T. J., Hong, G., Jones, S. M., & Brown, J. L. (2013).** Mediation and spillover effects in group-randomized
trials: A case study of the 4Rs educational intervention. *Journal of the American Statistical Association, 108*(502), 469-482.
doi:10.1080/01621459.2013.779832 · **M=V · C=NOT-READ** (NEEDS-PDF). **Qin, X., & Hong, G. (2017).** A weighting method for
assessing between-site heterogeneity in causal mediation mechanism. *Journal of Educational and Behavioral Statistics,
42*(3), 308-340. doi:10.3102/1076998617694879 · **M=V · C=NOT-READ** (NEEDS-PDF). Both are design-based multisite or group-randomized
treatments of mediation and spillover; relevant to the estimand discussion, not to SEM estimation.

**d4. Tingley, D., Yamamoto, T., Hirose, K., Keele, L., & Imai, K. (2014).** mediation: R package for causal mediation analysis.
*Journal of Statistical Software, 59*(5). doi:10.18637/jss.v059.i05 · **M=V · C=BOOK-READ** (the book's note covers all prose pp.
1-36; its multilevel section pp. 16-20). **Imai, K., Keele, L., & Tingley, D. (2010).** A general approach to causal mediation
analysis. *Psychological Methods, 15*(4), 309-334. doi:10.1037/a0020761 · **M=V · C=NOT-READ.** General single-level framework;
I found no multilevel extension attributable to Imai and colleagues beyond the package's multilevel support documented in
Tingley et al., so none is claimed.

**d5. Cheng, C., & Li, F. (2026).** Semiparametric causal mediation analysis of cluster-randomized trials for indirect and
spillover effects. *Biometrics, 82*. doi:10.1093/biomtc/ujag017 · **M=V · C=BOOK-READ** (`references.bib` readnote; page range
not re-checked here). **Cao, Z., & Li, F. (2025).** Assessing mediation in cross-sectional stepped wedge cluster randomized
trials. *Statistics in Medicine, 44*(15-17), e70175. doi:10.1002/sim.70175 · **M=V · C=NOT-READ** (NEEDS-PDF). **Di Maria, C., &
Didelez, V. (2024).** Longitudinal mediation analysis with multilevel and latent growth models: A separable effects approach.
*BMC Medical Research Methodology, 24*. doi:10.1186/s12874-024-02358-4 · **M=V · C=BOOK-READ** (book note; pages not re-checked).
**Ohnishi, Y., & Li, F. (2026).** *JASA* (book Zotero `CJ22GZYM`) · **M=U** (not re-verified here) · **C=NOT-READ.**
**Kim, Y., & Steiner, P. M. (2021).** Causal graphical views of fixed effects and random effects models. *British Journal of
Mathematical and Statistical Psychology, 74*(2), 165-183 (Crossref issued 2020 online). doi:10.1111/bmsp.12217 · **M=V ·
C=NOT-READ** (the book keeps both a NEEDS-PDF and a read-note record; treat as unread here). These are design-based or
longitudinal; they inform which estimands are causal but not how to estimate within/between effects by SEM.

**d6. Tangential, exist but not multilevel-mediation sources:** Hong & Raudenbush (2006), Evaluating kindergarten retention
policy, *JASA, 101*(475), 901-910, doi:10.1198/016214506000000447 · **M=V · C=NOT-READ.** Hong & Raudenbush (2008), Causal
inference for time-varying instructional treatments, *JEBS, 33*(3), 333-362, doi:10.3102/1076998607307355 · **M=V ·
C=NOT-READ.** Vansteelandt, Bekaert & Lange (2012), Imputation strategies for the estimation of natural direct and indirect
effects, *Epidemiologic Methods, 1*(1), 131-158, doi:10.1515/2161-962x.1014 · **M=V · C=NOT-READ.** Tchetgen Tchetgen &
Shpitser (2012), Semiparametric theory for causal mediation analysis, *Annals of Statistics, 40*(3), 1816-1845,
doi:10.1214/12-AOS990 · **M=V · C=NOT-READ.** None is cited as support for any claim below.

### Requested items not located or not matched

- **Lachowicz, Preacher & Kelley (2018)** (*Psychological Methods, 23*(2), 244-261, doi:10.1037/met0000165, **M=V · C=BOOK-READ**
  for its definition passage and NHST caution, pp. about 249-251 and 258-259): this is a **novel effect-size measure (upsilon)
  paper, not a paper on the covariance of random slopes.** It is not a source for sigma_ab. The sources for sigma_ab are Kenny
  et al. (2003) and Bauer et al. (2006), both read in the book.
- **Hayes (2013) book, Hayes and Rockwood** on multilevel mediation: only the 2020 article and a 2022 chapter were found in
  Crossref; see a20.
- **Park and Kürüm** (suggested from memory): no matching record was found in Crossref and the item is omitted; **unverified, not cited.**
- **Pseudo-balanced / MUML primary papers** are listed in b2 but their content was not read, so no description of the estimator
  rests on them.

## 3. Software probe: lavaan 0.7.3 (primary evidence, run 2026-11-10)

An installed-package probe on simulated data (J = 60 clusters of 6; within paths `aw`, `bw`; between paths `ab`, `bb`;
`ind := aw*bw - ab*bb`). It shows what the installed lavaan does; it is not a validation of anything.

| Option on `sem(model, data, cluster = "id")` | Result |
|---|---|
| default | fits (listwise nobs 303 with 60 injected missing cells; estimates aw .455, bw .483, ab .824, bb .424) |
| `se = "robust.huber.white"` | accepted; SEs differ from the standard ones (ab SE .122 vs .095 under FIML) |
| `missing = "fiml"` with injected NAs | accepted, converged; nobs 360 vs 303 listwise; estimates shift (aw .440, bw .470) |
| `se = "robust.sem"` | **refused** with a message listing the allowed multilevel options (none, standard, robust.huber.white, bootstrap) |
| `test = "yuan.bentler.mplus"` | accepted |
| `se = "bootstrap"` | accepted; lavaan notes the bootstrap resamples whole clusters |

At this size the between slope bb had SE .69 (listwise) and .40 to .42 (FIML), a single seed that illustrates between-level
imprecision at J = 60 and is not evidence about any threshold. The plan's research note found the joint `vcov` and `:=`
contrast SEs to match to the printed digits; that stays the plan's own finding. These probes mean the S2 adapter can offer
robust, FIML and cluster-bootstrap options by passing through to lavaan, and that lavaan can serve as an oracle for the
native S6/S7 work. "Accepted" means the option runs, not that it is validated.

## 4. What this implies for the #394 plan

Each point states what the **read** literature supports, what it does not, and its source.

1. **Within and between estimand definitions (plan section 9, Q3).** Supported as definitions: a_w b_w and a_B b_B are the
   within and between indirect effects of a two-level SEM with latent cluster means (Preacher et al. 2010, book-read), and
   the Between-only rule governs designs with a level-2 variable (same, pp. 210, 213, 222). Caveats: (i) the plan fixes slopes,
   so it estimates a_w b_w as a product of average slopes; with random slopes the average indirect effect is ab + sigma_ab
   (Kenny 2003; Bauer 2006), a different estimand, and the book derives that a pooled estimator need not target it. State that
   a_w b_w is conditional on fixed slopes; (ii) the book's own checks show the unbiased estimator depends on whether Y responds
   to a latent or a realized cluster mean (Lüdtke 2008; Preacher 2010 note), so the plan must state its cluster-level causal
   story rather than call latent means "the" truth; (iii) the book says the between model almost always differs from the
   within model (Preacher 2010 p. 224), so no equality of structural slopes should be imposed.
2. **The within-minus-between contrast.** **Not supported by any read source.** The nearest read relatives are the contextual
   effect b_B - b_W (Lüdtke 2008; Enders and Tofighi 2007; Preacher 2010 Table 2 reports an indirect-effect contrast between two
   mediators within a level, not a within-vs-between contrast) and the book's own "no interference iff b_B = b_W", which is
   **derived in the book, not found in the sources read**. The contrast's arithmetic (delta method with the joint covariance)
   is standard, but its interpretation as a causal quantity is not supported here. Treat it as a descriptive or diagnostic
   contrast and keep the grill question on sign and naming.
3. **Joint covariance and delta method.** The delta method for a product needs the covariance of the two estimates (Tofighi,
   MacKinnon and Yoon 2009, title-level). Keeping the cross-level blocks is consistent with this and with how lavaan's `:=`
   behaves in the plan's research; no read source gives the multilevel formula, so the plan's lavaan and bootstrap oracles are
   the real evidence, as the plan already says.
4. **Shared loadings.** Equal loadings across levels is a real, published, testable restriction (title-level: Jak, Oort and
   Dolan 2013, 2014; Jak et al. 2017), not a default. Recommend that S5 treat equality as an option with a diagnostic, and
   say in the docs that unequal loadings are not an error. No source read here gives the identification conditions; read
   Mehta and Neale 2005 and the Jak papers before the grill decides.
5. **Cluster-only covariates.** The Between-only rule and the plan's "within-level variables that exist only at level 2 enter
   the between block only" are consistent with Preacher et al. (2010) (book-read). Rights et al. (2020) is directly on point but
   unread; read it before finalizing how cluster-level controls enter the within vs between equations.
6. **Bootstrap and sandwich options.** Cluster resampling is the supported bootstrap (Falk 2024: L1 bootstrap fails when a slope
   varies; L2 and residual hold up; balanced, 30-90 clusters, normal, correct model only). A cluster sandwich is available
   in lavaan today (probe), but the only read evidence on "robust" methods (Pituch and Stapleton 2008, 2-1-1, 20 or 40 sites)
   shows robust variants doing worse than parametric ones in that setting, so do not present the sandwich as an upgrade
   without a simulation of your own. Yuan and Bentler's sandwich theory for two-level models is unread.
7. **Known pitfalls to document.**
   - **Bauer et al. random-slope term:** a_w b_w with fixed slopes omits sigma_ab if slopes vary (Bauer 2006; Kenny 2003); the plan
     already excludes random slopes, so say so in the docs. (Lachowicz et al. 2018 is not a source for this.)
   - **Centering/latent vs manifest means:** the manifest-mean option is biased for b_B under a latent mean (Preacher 2010 eq. 2)
     and the latent option is noisy (book check: 2.3 times the SD at J = 200, n = 5), and each is wrong under the other
     generator; offer both with that statement.
   - **Small J:** Preacher et al. (2010, pp. 222-223) report inadmissible between estimates with few clusters; the lavaan
     tutorial ties non-convergence to few clusters and near-zero between variance (search-level). No threshold is read-supported;
     the plan's 10/50 numbers are a project decision.
   - **Heywood:** the plan's admissible-vs-converged distinction is consistent with the improper-solutions literature
     (Chen et al. 2001; Kolenikov and Bollen 2012, titles only), which was not read.
   - **Informative cluster size:** the equal-weight vs size-weighted indirect effect differ when sizes vary; the book derives
     this (not found in the sources read) and VanderWeele (2010) is individual-weighted. The plan must say which weighting
     a ML two-level estimate implies (an open question; not settled by any read source).
8. **Estimator choice (full ML vs pseudo-balanced).** The plan's full-ML cluster-size-grouped likelihood is in the lineage of
   the EM/ML papers (b1, b3); the pseudo-balanced estimator is an approximation whose properties were not verified from the
   primary papers. Document full ML as the target and use the lavaan match as the oracle; do not claim equivalence to Mplus's
   default estimator without reading Yuan and Hayashi (2005).
9. **S6/S7 sequencing.** The probe shows lavaan already supports FIML and cluster sandwich SEs for two-level fits, so the
   adapter (S2) can expose them; the native-engine versions remain the work the plan describes. No read literature changes that.

## 5. Already in the book vs new

| Topic | In the book already | New here (all at metadata level unless stated) |
|---|---|---|
| E[a_j b_j] = ab + sigma_ab, sigma_ab readings | Yes (Kenny, Bauer, Tofighi et al.; read) | none |
| Centering, conflation, latent vs manifest means | Yes (Zhang, Krull, Enders, Preacher 2010, Lüdtke; read) | Lüdtke 2011, Asparouhov and Muthén 2019, Marsh 2009 as unread leads |
| Two-level MSEM specification and limits | Yes (Preacher 2010, 2011; read) | lavaan option probe (section 3) |
| Joint ML likelihood, unbalanced clusters, EM | No | Goldstein and McDonald, Lee and Poon, Liang and Bentler, Muthén 1994 as unread leads |
| Pseudo-balanced (MUML) vs full ML | No | Yuan and Hayashi 2005, Hox and Maas 2001 as unread leads; not verified |
| Delta-method SE with a cross-level covariance block | Single-level SE sources only | Tofighi, MacKinnon and Yoon 2009 (unread) |
| Within-minus-between indirect-effect contrast | Only the contextual b_B - b_W and a derived b_B = b_W statement | none supported; stated as a gap |
| Cluster-robust (sandwich) SE for two-level SEM | No; Pituch and Stapleton 2008 (2-1-1) read | Yuan and Bentler 2002, 2007; lavaan accepts `robust.huber.white` (probe) |
| Cluster bootstrap | Yes (Falk 2024 read; Field and Welsh unread) | none |
| Shared loadings / cross-level invariance | No | Mehta and Neale, Jak et al., Stapleton et al. (unread) |
| Small J, Heywood | Preacher 2010 pp. 222-223 (read) | Hox, McNeish, Depaoli, Chen, Kolenikov and Bollen (unread) |
| FIML in clusters | Brief note in the research plan; Grund et al. 2017 unread | Larsen 2011, Yuan and Bentler 2000 (unread); lavaan FIML probe |
| Causal multilevel mediation | VanderWeele 2010, Talloen 2016 (read) | Hong and Raudenbush, Imai et al., Tchetgen Tchetgen and Shpitser as tangential (unread) |
| Software (lavaan, Mplus, brms, bmlm) | Mplus as in Preacher 2010 | Rosseel 2012, Bürkner 2017, bmlm, lavaan tutorial page (unread) |
| Three-level, random-slope sensitivity | Yes (Preacher 2011, Tofighi and Kelley 2016) | none |

## 6. Gaps and open questions

Method by Setting pass (manual): rows are the topics in (a)-(d), columns are observed variables, latent variables,
unbalanced clusters, small J, missing data.

1. **No read source on the joint two-level likelihood, identification of the joint model, or unbalanced ML.** Read Goldstein and
   McDonald (1988), McDonald and Goldstein (1989), Muthén (1994) and Lee and Poon (1998) before the grill; the plan's oracle (the
   eight-line closed form matched to lavaan) is stronger evidence than any of them.
2. **No source defines or tests a within-minus-between indirect-effect contrast** (causal or statistical). Decide whether it is
   a descriptive output or a hypothesis test; if a test, the null needs stating (equal indirect effects does not follow from
   equal structural slopes).
3. **Estimand for weighted vs unweighted aggregation under unequal cluster sizes:** which does a two-level ML estimate target?
   The book's own derivation says they differ; no read source resolves it for SEM.
4. **Pseudo-balanced vs full ML:** claims about MUML's approximation were not verified from primary sources (Yuan and Hayashi
   2005 unread).
5. **Cluster-robust inference for two-level SEM** (Yuan and Bentler; Cameron and Miller) and its few-clusters behavior is
   unread; the only read comparative evidence is for 2-1-1 mixed models and recommends against assuming robustness helps.
6. **Shared-loading identification and cross-level invariance tests** are unread (Jak et al.; Mehta and Neale; Stapleton et al.).
7. **Small-J guidance** with an evidence-backed rule: none read. A project simulation (S3/S4 gate) is the realistic route; the
   literature leads are in b6.
8. **FIML in clusters** for two-level SEM beyond lavaan's option: pattern-wise cluster likelihood theory unread.
9. **Level-specific fit indices** for two-level SEM: not located.
10. **Items needing a PDF or a read before any quotation:** Preacher, Zhang and Zyphur (2011); Marsh et al. (2009); Lüdtke et al.
    (2011); Asparouhov and Muthén (2019); Rights et al. (2020); Raudenbush and Sampson (1999); Rockwood and Hayes (2022; verify
    year); Hox et al. (2014, not located by DOI here). Carry the book's NEEDS-PDF list unchanged.
11. **Authors' name checks:** several Crossref first-author-only records (Rights, Jak, Stapleton, Talloen 2019, Bentler 2011) need
    the co-author list confirmed before a bibliography entry is final.
12. **Unverified request items:** Hayes 2013 book, Muthén 1990 primary copy, Park and Kürüm; the Muthén 1989 link to two-level
    estimation. None is cited as support.
