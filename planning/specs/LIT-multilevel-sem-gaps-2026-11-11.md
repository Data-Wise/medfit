# Literature review: multilevel SEM, research gaps, medfit implementation gaps and new ideas

**Date:** 2026-11-11 · **Status:** research note, docs only (no code, no release) · **Branch:** `claude/multilevel-sem-lit-gaps-52c5de`,
cut from `origin/dev` at `91f4c39b` · **Issue:** [Data-Wise/medfit#394](https://github.com/Data-Wise/medfit/issues/394)

Citations are written `[Key]` and resolve to the reference list in section 7. Three labels separate what a source says
from what this note infers:

- **SOURCE**: a statement a source's abstract or text supports (or, for a metadata-only source, its title).
- **INFERENCE**: this note's reading, including every "no source found" claim (absence from a search is weak evidence).
- **SPECULATIVE**: an idea no source tests, offered for discussion.

---

## 1. Scope and method

**Question.** Where is the multilevel structural equation modeling (SEM) literature thin, what does medfit lack
against the other software, and which new research directions follow? The emphasis is two-level (observed and latent)
mediation, because medfit's open slices S4 (native two-level fitter) and S5 (latent mediators in a two-level model)
depend on it.

**Prior notes this builds on (not redone).** The two-level literature note, the plan and the grill decisions live on the
branch `claude/plan-multilevel-394-f40512` at commit `bff838ad`, not on `dev`:
`planning/specs/RESEARCH-multilevel-mediation-2026-11-10.md` (the "literature note": likelihood construction, lavaan
checks) and `planning/specs/PLAN-multilevel-mediation-2026-11-10.md` (slices S0 to S7; decisions Q1 to Q11 in its section 0).
The task text named `LIT-multilevel-mediation-2026-11-10.md` and `planning/GRILL-multilevel-mediation-2026-11-10.md`;
neither file exists on that branch. The Q1 to Q11 decisions are in the plan's section 0, and the module-1 grill is
`planning/specs/GRILL-multilevel-mediation-ext-d-2026-09-25.md` (on `dev`). The earlier review
`planning/specs/REVIEW-multilevel-mediation-2026-09-25.md` (on `dev`) is the 2-1-1 literature pass. Where this note
quotes a fact from the 2026-11-10 note, it says so; the claims about `R/` come from this branch.

**What was searched.** On 2026-11-11, five research passes (estimation; model structure and mediation; testing, missing
data and causal interpretation; cross-disciplinary computation; software) ran against:

- the Crossref REST API (every cited DOI was fetched; title, authors, year, journal and DOI in section 7 are rendered from
  the Crossref record, not typed), plus DataCite for the one record Crossref lacks (Hox 2012);
- the OpenAlex abstract text for the same DOIs;
- web search for 2023 to 2026 work and for package documentation;
- local runs: `lavaan` 0.7-3, `OpenMx` 2.22.11, `mediation` 4.5.1 (help pages and small fits) and the Mplus 8th
  edition User's Guide text (PDF from the vendor).

Not used: the Zotero connector (connection refused during this session), the Obsidian vault and PubMed. The search is
not exhaustive; it is a gap-finding pass.

**Evidence tiers.**

- **Tier A**: Crossref metadata matched and the abstract was read (often only the first part; the entry notes this).
- **Tier B**: Crossref metadata matched; the abstract was not retrievable or not read. For tier B this note claims only what
  the title says.
- **Unverified**: not opened, or could not be matched; never cited as support. The unverified items are listed in 1.1.
- Full texts were not read in general. Anything beyond an abstract is marked.

**Counts.** 126 sources are cited: 116 tier A (abstract read) and 10 tier B (metadata only). The research passes opened 188 sources in all (153 tier A, 35 tier B); the other 62 are not cited here. Not verified and not cited: 14 items in 1.1; marked `[CITE]` in the text: 1 (the MBCO reference). The research passes were run by subagents; each cited DOI was fetched again from Crossref or DataCite in a final pass to build section 7.

### 1.1 Not verified, so not cited as support

Muthén and Asparouhov on categorical outcomes in Mplus (no matching record); Hayes (2013) and Bolger and Laurenceau
(2013) as books; Zhang and Wang multilevel mediation; a multilevel Kelava (latent interaction)
paper; Muthén and Asparouhov's 2010 Bayesian Mplus report; Lee and Poon (1998); Schmidt (1969); Kish (1965); Raudenbush
and Bryk; Kang and Imai; Bollen's boundary-LR work; any Enders 2023 FIML paper; the Mplus web-note records with
`10.61700` DOIs (non-standard records). Specific numbers (for example Meuleman and Billiet's cluster thresholds) that came
from a search summary rather than a text are not stated; Hox's abstract supplies the figure used below.
The MBCO paper (the model-based constrained-optimization test for mediation) is named in 6.1 and 5 without a verified
reference: **[CITE]**.

---

## 2. The multilevel SEM landscape

### 2.1 Estimation

**Full-information ML (FIML) and the pseudobalanced shortcut.** Muthén's approach fits multilevel covariance structures
with conventional SEM software [Muthen1994]; its pseudobalanced version was evaluated with unequal groups [HoxMaas2001] (INFERENCE: it is an approximate estimator). McDonald and Goldstein give the two-level
model and, for balanced designs, a likelihood discrepancy function and fit test [McDonaldGoldstein1989]; Lee derives ML and
generalized least squares for unbalanced designs [Lee1990]. Liang and Bentler give an EM algorithm for the unbalanced
two-level model [LiangBentler2004]. A simulation of the pseudobalanced estimator found the within part unproblematic and the
between part the main difficulty [HoxMaas2001]; in a later unbalanced factor-model study, between-level bias fell fastest
for ML, then DWLS, then MLR, then pseudobalanced (which needed 200 or more groups) [HoxMaasBrinkhuis2010].
Two-level ML is also what modern software implements: lavaan's default estimator and EM, Mplus ML/MLR/MUML (section 3).

**Two-stage and level-by-level.** Yuan and Bentler fit multiple single-level models and note that a joint statistic does
not locate the misspecified level [YuanBentler2007]. A related 2026 paper fits two-level SEMs to summary statistics
[JakCheung2026].

**Robust and sandwich inference.** Yuan and Bentler give sandwich covariances and a rescaled statistic for two-level normal
theory ML under nonnormality [YuanBentler2002]; the same authors compare eight test statistics for multilevel SEM
[YuanBentler2003] (tier B: title only). Complex-sample SEM and weights are covered by [MuthenSatorra1995] and
[Stapleton2002]. INFERENCE: none of these abstracts treats a product of coefficients (an indirect effect) with a small
number of clusters.

**Bayesian MSEM.** Bayesian multilevel latent covariate models can resolve convergence problems and reduce bias against ML
[DepaoliClifton2015]; they had fewer inadmissible solutions in the multilevel latent contextual model [Zitzmann2016].
A reanalysis of a country-level simulation reports about 20 countries sufficing for Bayesian estimation versus 50 to 100
for ML [Hox2012]. Counterweight: diffuse default priors can bias small-sample estimates as much as ML [Smid2019]; the use of Bayesian
methods for small samples is also discussed in [McNeish2016] (abstract read; no finding stated). Recent small-sample work compares ML and Bayes for 1-2-1 mediation in MSEM [LiJia2026] and proposes
shrinkage covariance estimation for few groups [Walther2025a]. blavaan implements Bayesian SEM [MerkleRosseel2018].

**Small numbers of clusters and effective sample size.** The group-level N is the main restriction on multilevel regression
accuracy [MaasHox2005]. A cautionary simulation note on MSEM mediation with small samples says ML-SEM needs about 100 clusters and that the
median published study has 44 [McNeish2017] (abstract, read in part). The design effect rule of thumb (ignore clustering below 2) was never studied systematically
[LaiKwok2015]. Power and sample-size results exist for multilevel mediation in three-level cluster-randomized trials
[Kelcey2020]. INFERENCE: no source combines clusters, cluster size and ICC into one rule for a between-level indirect effect.

**Categorical outcomes.** ML for multilevel ordinal factor models uses EM with adaptive quadrature [GrilliRampichini2007];
GLLAMM generalizes multilevel SEM to mixed response types [RabeHesketh2004]; pairwise ML handles discrete responses with
random slopes [BarendseRosseel2023]; single-level robust ML versus categorical least squares is studied in
[Rhemtulla2012]. Two-level WLSMV evidence was not verified.

### 2.2 Model structure

**Mediation designs.** Lower-level (1-1-1) mediation with random slopes was formalized by Kenny, Korchmaros and Bolger,
who show the indirect effect and its standard error must include the covariance of the random a and b effects
[KennyKorchmarosBolger2003]; Bauer, Preacher and Gil give the mean and variance of the indirect effect under random slopes and
extend to moderated mediation [BauerPreacherGil2006]. Krull and MacKinnon compare single-level and multilevel mediation for
group-level and individual-level variables [KrullMacKinnon2001]. HLM-based estimates conflate within and between effects
[Zhang2009]; the MSEM framework separates them and allows a level-2 outcome [Preacher2010]; three-level data need
further strategies [Preacher2011]. Cluster-level treatment (2-1-1) and the cross- versus cluster-level process
distinction are in [PituchStapleton2012], with bootstrap-based tests for upper-level mediation in [Pituch2008].
For the full 2-1-1, 1-1-1 and 2-2-1 table, see the 2026-09-25 review; this note adds the sources below.

**Random slopes in SEM.** Mehta and Neale show the equivalence of mixed models and multilevel SEM and place random slopes
in a SEM likelihood through definition variables [MehtaNeale2005]. Zigler and Ye compare MSEM, unconflated and conflated MLM
for a 1-1-1 model with random slopes and note large gaps for 1-1-1 designs [ZiglerYe2019]. A 2026 preprint gives an
efficient interval method for the random-slope 1-1-1 model [FalkSavchenko2026] (**preprint, not peer reviewed**).
Cross-level covariance is usually omitted by default setups [BaiPoon2009].

**Latent covariates and contextual effects.** Manifest cluster means can bias contextual effects, and a latent-covariate
approach corrects this [Ludtke2008]; a taxonomy separates measurement-error and sampling-error unreliability
[Ludtke2011]; a "doubly latent" model integrates both [MarshEtAl2009]; aggregate regression is biased for group-level
outcomes [CroonVanVeldhoven2007]; centering choices matter [EndersTofighi2007]. Centering of predictors and mediators in
multilevel and time-series models is treated in [AsparouhovMuthen2019] (**abstract partly read; no finding stated**).
The "Lüdtke latent versus manifest aggregation bias" in medfit's two routes is therefore documented: the 2-1-1 lmer route
uses cluster-mean centering; the lavaan two-level route uses latent cluster means (the 2026-11-10 literature note, section 4.7).

**Cross-level interactions and moderated mediation.** Multilevel moderation conflates levels and uses observed means unless
latent interactions are modeled, via random coefficients or latent moderated structural equations (LMS)
[PreacherZhangZyphur2016], [KleinMoosbrugger2000]; Bayesian estimation of latent interactions at one or two levels
[AsparouhovMuthen2021]; moderated mediation indices [PreacherRuckerHayes2007], [Hayes2015], Bayesian versions
[WangPreacher2015], [LeeKim2026] (a multilevel Bayesian comparison). INFERENCE: this strand is Bayesian or LMS-based;
no frequentist, closed-form-friendly multilevel index of moderated mediation turned up.

**Longitudinal and intensive-longitudinal.** Dynamic SEM [AsparouhovHamakerMuthen2018], [HamakerEtAl2018], a two-level primer
[McNeishHamaker2020], a three-level extension [AsparouhovMuthen2026], sample-size needs [SchultzbergMuthen2018], the cost of
fixing random variances [JongerlingLaurenceauHamaker2015], heterogeneity of causal processes [BolgerEtAl2019], and models in
which within-person effects drive between-person outcomes [Neubauer2023]. INFERENCE: dynamic multilevel mediation is
mostly Bayesian.

### 2.3 Identification

Single-level identification rules exist [BollenDavis2009]; the mixed-model equivalence gives a construction for random
slopes [MehtaNeale2005]; approximate-zero priors help when ML cannot identify the model [MuthenAsparouhov2012]. INFERENCE: no
verified rule set exists for two-level models with random slopes. From the 2026-11-10 literature note (run locally, lavaan
0.7-3): a level-1 variable with zero between variance makes the level-2 equations unidentified; level-2 variances
reach the boundary first and lavaan reports negative variances with `converged = TRUE`.

### 2.4 Fit and testing

**Level-specific fit.** Joint chi-square can miss level-specific misfit; level-specific chi-square, CFI and RMSEA from
partially saturated models fix this [RyuWest2009]; separate single-level models also locate the level [YuanBentler2007];
conventional indices are weak for between-level misfit across 100 to 300 groups [Hsu2015]. For nonlinear multilevel SEM the
literature says no adequate test statistic exists, with a robust LR test examined for single-level latent interactions
[SchermellehEngelEtAl2014].

**LR tests with constraints and boundary values.** A null that puts a variance on its boundary makes the LR difference
test follow a mixture of chi-squares [SelfLiang1987], [StramLee1994], [Stoel2006] (stated for SEM generally); the
boundary theory also covers Wald and score tests [Andrews2001]; constrained estimation can mask misspecification, so a
global fit under constraints needs care [SavaleiKolenikov2008]. INFERENCE: no source read combines a boundary
between-level variance, a nonlinear product null (a times b), and a level-specific global statistic.

**Information criteria.** Marginal AIC suits population questions and conditional AIC suits cluster questions
[VaidaBlanchard2005]; the conditional version ignores random-effect covariance uncertainty [GrevenKneib2010]; both are for
linear mixed models. INFERENCE: nothing found extends them to latent-variable two-level SEM.

### 2.5 Missing data

Direct ML and two-stage ML for structural models with missing data are single-level results [YuanBentler2000]. A
Monte Carlo study evaluates FIML in multilevel SEM across missing-data patterns and ICC [Niu2024] (abstract read; its results were not). Multiple imputation for multilevel designs [LudtkeRobitzschGrund2017], [GrundLudtkeRobitzsch2018],
[EndersKellerLevy2018]; MAR methods are biased for models with incomplete interactive or polynomial terms, motivating
model-based imputation [EndersDuKeller2020] (relevant because a treatment-by-mediator product is such a term).
INFERENCE: FIML with incomplete cluster-level variables or products, with robust standard errors, is open.

### 2.6 Causal interpretation

Potential-outcomes mediation for independent units [ImaiKeeleTingley2010] and the four-way decomposition
[VanderWeele2014] carry no clustering. Interference theory [HudgensHalloran2008], [TchetgenVanderWeele2012],
[OgburnVanderWeele2014] and spillover estimands in group-randomized trials [VanderWeele2013] bring clustering in.
For a 2-1-1 design, the counterfactual identification of the within and contextual indirect effects is in
[Talloen2016]. Weighting approaches handle clustered or multisite mediation [HongDeutschHill2015], [QinHong2017],
[QinHongDeutschBein2019]; recent semiparametric and Bayesian nonparametric work handles cluster-randomized trials with
interference [ChengLi2026], [OhnishiLi2025]; a causal reading of multilevel and latent growth models appears in
[DiMariaDidelez2024]; confounding in multilevel mediation is addressed by sensitivity work [TofighiKelley2016]. INFERENCE:
none of these identifies the latent-mean between/within SEM paths causally without further assumptions, and the link
between a between-level SEM path and a spillover estimand is not established in anything read.

---

## 3. Software comparison matrix

Access date 2026-11-11. Each cell is value (evidence). **unverified** means no documentation or run was seen. Evidence
keys: LOCAL = run or help page on this machine; UG = Mplus User's Guide text; WEB = fetched page or search summary
(secondary); medfit cells were checked against `R/` at `91f4c39b`.

### 3.1 Estimation engines

| Row | lavaan 0.7-3 | Mplus (UG 8th ed.) | OpenMx 2.22.11 | blavaan 0.6-1 | Stata (`gsem`, `sem`; `mixed` unverified) | medfit 0.16.0 |
|---|---|---|---|---|---|---|
| Structures | two-level via `level:` blocks and `cluster=`; observed and latent (LOCAL fit, WEB tutorial) | TWOLEVEL, THREELEVEL, CROSSCLASSIFIED, COMPLEX TWOLEVEL (UG) | multilevel via primary/join keys and `mxExpectationRAM(between=)` (LOCAL help); official example not found | two-level random intercept, complete continuous data (WEB summary, secondary) | `gsem` random intercepts with `M1[id]` notation (WEB, Example 38g); `sem` single level | native SEM single level (`R/sem-fit.R:96-98` refuses `level:`); 2-1-1 via lmer; 1-1-1 two-level via lavaan adapter |
| Estimators | ML, MLR, EM (`optim_method = "em"`), DWLS/ULS for ordered (LOCAL help) | MUML, ML, MLR, MLF, WLS family, BAYES (UG table) | ML (`mxFitFunctionML`, `fellner` option) (LOCAL help) | Bayes (Stan/JAGS) | `gsem` adaptive quadrature (stated generally; unverified here) | native ML single level; lmer REML (2-1-1); two-level ML delegated to lavaan |
| SEs and inference | observed information; MLR robust; `:=` delta SEs (LOCAL) | MODEL INDIRECT; bootstrap SEs (UG; cluster resampling unverified) | observed information, `mxSE`, `mxCI` profile CIs (LOCAL exports) | posterior summaries | `nlcom`; `estat teffects` after multilevel `gsem` unverified | delta-method effect SEs; HC0 sandwich (casewise, single level, `R/sem-sandwich.R`); Kenward-Roger (2-1-1); joint-covariance sub-block (two-level adapter) |
| Latent variables across levels | two-level CFA/SEM supported; shared-loading equality via labels expressible but not run | latent variables at each level (UG) | between level latent with linked indicators (WEB forum, secondary) | unverified | `gsem` latent variables at the group level (WEB) | native single-level latent; the two-level adapter reads named path rows; latent two-level behavior unverified here |
| Random slopes | yes since 0.7: `rv()`; ML only, continuous, single group (LOCAL help) | `s | y ON x`, numerical integration (UG) | via definition variables (forum; official example not found) | not supported per mailing-list summary (may be stale) | random-slope models in `gsem` (WEB Example 38g) | none |
| Constraints | labels, equality, `:=` (LOCAL ran); nonlinear constraints in two-level fits unverified | MODEL CONSTRAINT linear and nonlinear (UG) | `mxConstraint` and `mxAlgebra` exported (LOCAL); multilevel use unverified | cross-level equality reported unsupported (WEB, may be stale) | `constraints()`; multilevel unverified | native linear and nonlinear (SLSQP) in single level only |
| Missing data in multilevel | `missing = "ml"` through EM (LOCAL help; run returned an object, not inspected) | FIML under ML/MLR (UG; details unverified) | unverified | unverified | unverified | bounded FIML single level, numeric columns, observed information only (`R/fit-sem.R` docs) |
| Categorical at two levels | ordered outcomes only with DWLS/ULS (LOCAL error text) | WLSMV, ML with integration, BAYES (UG) | unverified | unverified | families and links; multilevel cell unverified | none (Gaussian; categorical covariates as dummies) |
| Bootstrap | resamples whole clusters (LOCAL message) | `BOOTSTRAP` option; cluster resampling unverified | `mxBootstrap`; cluster resampling unverified | not applicable | unverified | `bootstrap_mediation(cluster =)` resamples clusters with fresh ids; `twolevel_statistic()` callbacks (`R/bootstrap.R`, `R/twolevel-statistic.R`) |
| Known limits | two levels only; negative variances only a warning at J = 8, n = 4; unbalanced fits (LOCAL) | three levels (UG) | forum: key columns integer or factor | new feature; no >2 levels (WEB) | multilevel mediation by user-written equations (Statalist, no official page) | two-level adapter refuses standardized paths, products, more than one mediator, 2-1-1 designs; warns on few clusters, inadmissible fits; within-only object when ICC < 0.01 (`R/extract-lavaan-twolevel.R`) |

### 3.2 Mediation and other packages

| Package | Multilevel capability (evidence) |
|---|---|
| `mediation` 4.5.1 | `mediate()` accepts lmer/glmer (`merMod`) fits, `group.out`, `cluster=`, quasi-Bayesian simulation, `boot = TRUE`, `robustSE` (LOCAL help) [tingley2014mediation] |
| `multilevelmediation` 0.5.0 | 1-1-1 only; moderators on a and b; continuous M and Y; imports nlme, glmmTMB, brms, MCMCpack (WEB CRAN) |
| `bmlm` 1.3.15 | Bayesian multilevel mediation with Stan; 1-1-1; further claims unverified (WEB CRAN) [vuorre2018bmlm] |
| `brms` / Stan | multivariate formulas, `set_rescor(TRUE)`, shared varying-effect labels correlate varying effects across responses (WEB vignette); mediation example not read [burkner2017brms], [Carpenter2017] |
| `piecewiseSEM` 2.3.1 | imports lme4 and nlme; mixed-effects component models claimed in the paper, not stated on CRAN (unverified) [lefcheck2016piecewisesem] |
| `lavaan.mi` 0.1-1, `semTools` 0.5-10 | pool lavaan fits over imputations; extension functions; multilevel features not seen on the CRAN pages (unverified) |
| `semopy` (Python) | the 2020 paper describes the package [igolkina2020semopy]; semopy 2 adds random effects from linear mixed models per the arXiv abstract at <https://arxiv.org/abs/2106.01140> (preprint, metadata unverified); two-level SEM not described (unverified) |
| `StructuralEquationModels.jl` | ML, GLS, FIML, multigroup; multilevel not mentioned on the docs front page (unverified) |
| MLmed | SPSS macro for multilevel mediation (WEB); 2-1-1 random-slope support unverified |
| Mplus via `MplusAutomation` | not checked; Mplus itself is in 3.1 |
| Not checked | `sem` (Fox), `psych` multilevel helpers, `umx`, `lslx`, `regsem`, `dynr`, `ctsem`, `lvnet`, `gllamm`, `lavaan.survey`, SAS PROC CALIS/MIXED, EQS, LISREL, Amos, DPM |

---

## 4. Literature gaps

Each gap lists what is unsolved, the closest work, and the evidence. "Closest" means closest among the sources read.

| # | Gap | Closest work | Evidence and tier |
|---|---|---|---|
| G1 | **Likelihood-based inference for a random indirect effect with latent cluster means.** The mean indirect effect is ab + cov(a_j, b_j), and the covariance enters the variance; fixed-slope models drop it. | [KennyKorchmarosBolger2003], [BauerPreacherGil2006], [ZiglerYe2019]; Bayesian [LeeKim2026]; efficient intervals in a preprint [FalkSavchenko2026] | SOURCE for the formulas and the 1-1-1 gap; INFERENCE for "no likelihood-based general method" (absence) |
| G2 | **Small-J behavior of between-level indirect effects, and a design rule combining J, n and ICC.** Bayesian priors matter [Smid2019]; ML needs 50 to 100 clusters [Hox2012]; median published study has 44 [McNeish2017]. | [LiJia2026] (1-2-1, ML versus Bayes), [Walther2025a] | SOURCE for each finding; INFERENCE for the missing combined rule |
| G3 | **LR and chi-square testing under a boundary variance, a nonlinear product null and a level-specific statistic together.** | [Stoel2006], [RyuWest2009], [SavaleiKolenikov2008] | SOURCE for the parts; INFERENCE that the combination is open |
| G4 | **Causal reading of the latent-mean between/within paths, and the map from a between-level SEM path to a spillover estimand.** | [Talloen2016] (2-1-1), [VanderWeele2013], [ChengLi2026] | INFERENCE (absence) |
| G5 | **Missing data in two-level SEM with incomplete cluster-level variables or products, and cluster-robust SEs for clustered FIML.** | [Niu2024], [EndersDuKeller2020], [YuanBentler2000] (single level) | INFERENCE |
| G6 | **Information criteria and model comparison for latent-variable two-level SEM.** | [VaidaBlanchard2005], [GrevenKneib2010] (linear mixed models) | INFERENCE |
| G7 | **Cluster-robust inference for products of coefficients with few clusters.** The sandwich for two-level ML exists [YuanBentler2002]; small-cluster adjustments live in other fields (section 6). | [Pituch2008] (bootstrap, 2-1-1), [Lai2021boot] | INFERENCE |
| G8 | **Categorical mediators at two levels:** effect definitions and SEs. | [GrilliRampichini2007] (factor model), [DepaoliClifton2015] (dichotomous outcome), [BarendseRosseel2023] | INFERENCE; no dedicated multilevel mediation paper found |
| G9 | **Level-specific sensitivity analysis for omitted confounding with latent means and random slopes.** | [TofighiKelley2016] | INFERENCE |
| G10 | **Identification rules and level-specific fit for random-slope or nonlinear MSEM.** | [MehtaNeale2005], [SchermellehEngelEtAl2014] | INFERENCE |
| G11 | **Within-person effects driving between-person outcomes (1-1-2 style):** general identification and inference. | [Neubauer2023], [CroonVanVeldhoven2007] | INFERENCE |
| G12 | **ML-based multilevel dynamic mediation with small-sample guarantees.** | [JongerlingLaurenceauHamaker2015], [SchultzbergMuthen2018] | INFERENCE |
| G13 | **A frequentist multilevel index of moderated mediation.** | [LeeKim2026] (Bayesian), [WangPreacher2015] (single level) | INFERENCE |

Top five by value to medfit: G2, G1, G3, G5, G4.

---

## 5. medfit implementation gaps

### 5.1 What `R/` has at `91f4c39b`

- **Native engine:** single level only. The parser reads `level:` lines (`R/sem-parse.R:322-326`); the fitter errors on any
  row with `level != 1` (`R/sem-fit.R:96-98`). `fit_sem()` has no `cluster` argument, and `fit_mediation(engine = "native")` stops if `cluster` is supplied (`R/fit-sem.R:451-452`).
- **2-1-1:** `ClusterMediationData` through `fit_mediation(engine = "lmer", cluster = )`, Kenward-Roger intervals
  (`R/extract-lmer.R`, `R/fit-lmer.R`).
- **1-1-1:** `TwoLevelMediationData` (`R/classes-twolevel.R`) built by `extract_mediation(<two-level lavaan fit>)`
  (`R/extract-lavaan-twolevel.R`): fixed slopes, one mediator, within/between paths from the parameter table, joint
  covariance sub-block, within-only object when between is unidentified, classed errors for standardized paths, products,
  structure arguments and 2-1-1 designs, warnings for few clusters and inadmissible fits. `twolevel_statistic()` builds
  bootstrap callbacks (parametric from the object; cluster refit through lavaan) (`R/twolevel-statistic.R`).
  A sibling change to the contrast rule is in progress; this note describes `dev` as it stands.
- **Oracle:** a hand-built pure-R two-level likelihood (O8, `tests/testthat/helper-twolevel-likelihood.R`) with
  `test-twolevel-likelihood-oracle.R`.
- **Missing data:** bounded FIML for single-level observed models only; `R/sem-fiml*.R`. The roadmap lists multilevel FIML among
  deferred items (`planning/medfit-roadmap.md:1935`).
- **SEs:** `R/sem-sandwich.R` is casewise and single level (42 lines).

### 5.2 Gaps against the best comparator, ranked by value and cost

Cost labels follow the plan's own scale (S, M, L, XL).

| Rank | Gap | Who offers it (evidence) | Value | Cost | Notes |
|---|---|---|---|---|---|
| 1 | Native two-level ML, observed, fixed slopes (S4) | lavaan, Mplus, OpenMx (section 3) | high: removes the lavaan dependency for estimation, enables everything below | L (plan: 3 to 4 weeks) | assessed in 5.3 |
| 2 | Cluster-aware robust SE and few-cluster adjustments | lavaan MLR two-level, Mplus MLR/MLF; small-cluster adjustments in econometrics (section 6) | high for G2, G7 | M after S4 (per-cluster scores) | the plan lists it as S6 |
| 3 | Two-level tests: equal indirect effects across levels, product-null per level | none verified in any package | high (G3); novel | M to L after S4 | idea I1, I2 in section 6 |
| 4 | Random slopes and the a-b covariance (a different estimand, E[ab] = ab + cov) | lavaan 0.7 `rv()`, Mplus, bmlm/brms, multilevelmediation | high for G1 | L, new class and estimand | the plan marks random slopes "out" (Q-decisions); revisit as an open question |
| 5 | More than one mediator in a two-level model | multilevelmediation? (1-1-1 only, mediator count unverified); lavaan syntax allows it | medium | M | the adapter refuses it today |
| 6 | Latent mediators with cross-level shared loadings (S5) | lavaan, Mplus | medium | L on top of S4 | assessed in 5.3 |
| 7 | Level-specific fit (partially saturated models) | Mplus, lavaan workflows [RyuWest2009] | medium | M after S4 | two fits per level; chi-square only |
| 8 | Two-level FIML | lavaan (EM), Mplus | medium (G5) | XL | the plan defers it (S7) |
| 9 | Categorical outcomes at two levels | Mplus, Stata, lavaan DWLS | low for medfit's current scope | XL | out |
| 10 | Three levels, cross-classified | Mplus only | low | XL | out |
| 11 | Bayesian two-level | blavaan, Mplus, bmlm/brms | low (not medfit's lane) | not planned | small-J argument for it exists (G2); out of scope |

### 5.3 S4 and S5, assessed

**What an exact ML implementation of S4 needs.** From the plan (section 5 of the 2026-11-10 plan, **not repeated in
full here**): variable sets W (level 1) and Z (cluster-only); cluster-wise sufficient statistics per distinct cluster size;
two RAM blocks stacked into one parameter vector; the `-2 log L` sum with one Cholesky of the cluster covariance per distinct
size; analytic gradient by the chain rule through Sigma_W and Sigma_B with a finite-difference Hessian as fallback and oracle;
the existing SLSQP pipeline and acceptance gate; per-level admissibility in the outcome ledger.
The literature adds four things:

1. **A start-value and oracle path through EM.** Liang and Bentler's EM for unbalanced two-level SEM [LiangBentler2004] is a
   natural independent estimator and a robust start; lavaan also offers EM (section 3). INFERENCE.
2. **A decision on level-2 variance parametrization.** Hard floors in SLSQP (the plan's choice, the same device as the #213 fix)
   versus an unconstrained parametrization of the covariance matrix [Pinheiro1996] (tier B: the title says only
   "unconstrained parametrizations"; the Cholesky and matrix-log forms are background knowledge) versus a penalized
   likelihood that avoids boundary variance estimates [Chung2013] (abstract). INFERENCE: a boundary solution is an infinite
   parameter value under a log-type parametrization, which changes SEs and LR behavior; the choice should be an experiment, not an assumption.
3. **The boundary LR law** for any between-level variance null [SelfLiang1987], [Stoel2006], so `anova()` for two-level
   fits should not report a plain chi-square p value when a variance is at its bound.
4. **A sandwich** [YuanBentler2002] only after the likelihood is trusted (S6).

**Computational cost.** DERIVED from the plan's likelihood (INFERENCE, not benchmarked): per objective evaluation, one
Cholesky of a (p + q) by (p + q) matrix per distinct cluster size D, plus quadratic forms over the J clusters, so roughly
O(D (p + q)^3 + J (p + q)^2); memory is O(D (p + q)^2) for the factors plus the sufficient statistics. For a mediation model
(p + q around 3 to 6) this is small next to the SLSQP and constraint overhead. The cost is engineering and evidence, not
flops.

**Risk.** The plan's own list stands: optimizer files are on the high-risk list (`tests/sim/risk-files.txt` includes
`R/sem-ml.R`, `R/sem-optim.R`, `R/sem-constraints.R`, `R/sem-fit.R`), so the seven-item admission checklist applies. Added from
the literature: level-2 variance Heywood cases at small J (G2); non-convex likelihood, so multiple starts and the acceptance
gate matter; ICC near zero makes Sigma_B singular; the sample sizes at which lavaan itself is trustworthy are an evidence
question (Hox 2012, Smid 2019, McNeish 2017) and belong in the reliability grid.
Oracles available now: O8 (hand-built), lavaan, OpenMx (two-level replication of an Mplus example exists in the OpenMx
test suite per a file listing; content unread), and, as a speculative extra, Stan or TMB for likelihood and gradient
(section 6).

**S5 (latent mediators).** Needs cross-level equality in the constraint machinery plus a per-level admissibility story.
Latent contextual models have well-documented small-sample trouble that Bayesian estimation reduces [Zitzmann2016],
[DepaoliClifton2015]; between-level misfit is hard to detect with conventional indices [Hsu2015]; cluster-level factor
models in lavaan have their own evaluation recipe [Jak2021] (abstract read). INFERENCE: S5 should follow S4's oracle and
reliability cells, not run in parallel, and its first oracle must be lavaan on a latent fixture (the plan notes lavaan already
reports negative variances with `converged = TRUE` there).

### 5.4 Top three recommendations

1. **Proceed with S4 as planned, but gate it on three things the literature adds:** the O8 oracle plus lavaan plus OpenMx,
   a reliability grid that includes small-J, low-ICC and unbalanced cells (G2), and an explicit parametrization experiment for
   level-2 variances (floor versus log-Cholesky).
2. **Plan S6 together with a small-cluster inference choice:** cluster-score sandwich, then a bias-reduced or bootstrap
   interval for the between-level indirect effect, validated against the existing cluster bootstrap callbacks (G7).
3. **Build the two-level equality and product-null tests after S4,** using the existing nonlinear-constraint pipeline and the
   zero-product branch machinery per level (idea I1, I2): the one place medfit's current engine is closer to a solution
   than any comparator found.

---

## 6. New research ideas

Where a cross-disciplinary source is tier B (title only), the table says so; the transfer claims are labeled. Nothing here is a
finding.

### 6.1 Ranked ideas

| Rank | Idea | Gap | Why novel (INFERENCE) | Feasibility | Independent oracle |
|---|---|---|---|---|---|
| I1 | **Two-level model-based constrained-optimization (MBCO-style) tests** for the within and between indirect effects (a times b = 0 at one level or both), splitting the zero-product null into exact linear branches per level (as medfit does single-level) and using a boundary-aware reference law | G3 | no source read combines product nulls, boundary variances and two levels; MBCO itself: **[CITE]** | medium after S4; the branch machinery exists (`.sem_fit_branches()`) | lavaan refits with a = 0 or b = 0 per level; Monte Carlo null calibration; the O8 hand likelihood |
| I2 | **A formal test of equal indirect effects across levels** (a_w b_w = a_b b_b) as a nonlinear equality constraint, replacing the descriptive contrast | G3 | the current contrast is descriptive by design; a test needs the constrained fit | medium after S4; nonlinear rows exist | lavaan constrained fit (nonlinear constraints in two-level unverified); parametric bootstrap under the null |
| I3 | **Manifest-versus-latent cluster-mean diagnostic**: medfit already has both routes (lmer cluster-mean centering and lavaan latent means); the gap between their between-level paths flags latent-mean bias as cluster size and ICC change [Ludtke2008], [Mundlak1978], [Bell2015] | G2 | a built-in diagnostic using two routes in one package is not described in sources read; econometrics transfer is SPECULATIVE | high (both routes shipped) | simulation with known between and within truth, over n_j and ICC |
| I4 | **Few-cluster robust inference for products of coefficients:** small-cluster adjustments (a degrees-of-freedom correction [Imbens2016], small-sample variance estimators [Pustejovsky2018], bootstrap improvements for clustered errors [Cameron2008]) applied to the between-level indirect effect from cluster scores; the abstracts address regression, not products of coefficients | G7 | SPECULATIVE transfer from econometric regression to a product of two path estimates | medium after S6 | cluster bootstrap callbacks already shipped; coverage grid |
| I5 | **Conditional-AIC-style criterion for two-level SEM** using effective degrees of freedom [VaidaBlanchard2005], [GrevenKneib2010] | G6 | nothing found for latent-variable multilevel SEM | low to medium; theory first | leave-cluster-out predictive log-likelihood |
| I6 | **Interference-aware reading of the between-level path:** state the assumptions under which a between a-path times b-path is a spillover-type indirect effect [VanderWeele2013], [Talloen2016], [Aronow2017] | G4 | a theory note linking latent-mean SEM paths to spillover estimands was not found | theory-heavy; docs value even without proof | simulate from a structural causal model with known spillover and compare to the g-formula truth |
| I7 | **Level-2 variance handling experiment:** floors, matrix-log and penalty compared on Heywood-prone cells [Pinheiro1996] (tier B: title only), [Chung2013] | G2 | the comparison inside a SEM engine with constraints is not described | high (part of S4) | lavaan's Heywood fixtures; Bayesian posterior mode as reference |
| I8 | **Automatic-differentiation oracles (Stan or TMB)** for the two-level likelihood and its gradient [Carpenter2017] (abstract: Stan defines a log probability function), [Kristensen2016] (abstract: user-defined joint likelihood, automatic differentiation in the title) | testing the analytic gradient | an oracle, not a method | high for p = 3; needs the Stan toolchain | the oracle itself |
| I9 | **Balanced-design closed forms** as exact start values and a check: the balanced likelihood splits into two single-level pieces [McDonaldGoldstein1989], [Muthen1994] | S4 start values | known result used as a test | high | pooled-within and between covariance fits |
| I10 | **Two-level FIML through EM** (E-step with Gaussian conditionals; analog of [LiangBentler2004]) | G5 | not explored for medfit's engine | XL | lavaan two-level `missing = "ml"` |

### 6.2 Cross-disciplinary map

| Field | What was solved (title-level) | Multilevel SEM analog | Status |
|---|---|---|---|
| Mixed-model computation | ML/REML for linear mixed models [Bates2015]; REML and marginal-likelihood estimation for semiparametric models [Wood2011]; a package in which the user defines a joint likelihood and automatic differentiation plus Laplace approximation do the rest [Kristensen2016] | exact gradients for the two-level likelihood; the idea of concentrating out mean parameters (profiling) is background knowledge, INFERENCE | SPECULATIVE; p is small, so the gain may be negligible |
| Genetics | average-information matrix for REML variance components is computationally convenient [Gilmour1995] (abstract); fast mixed-model algorithms for association studies [Lippert2011], [Zhou2012] (tier B: titles only) | cheap curvature for covariance parameters; the eigen-rotation mechanism behind the fast algorithms is background knowledge, INFERENCE | SPECULATIVE; likely unnecessary at mediation-model sizes |
| Econometrics | clustered errors and few clusters [Cameron2008], [Cameron2015], [Imbens2016], [Pustejovsky2018], [MacKinnon2023] (abstracts); the Mundlak correction for correlated lower-level covariates and higher-level residuals [Bell2015] (abstract), [Mundlak1978] (tier B); [Hansen2007], [Wooldridge2019] (tier B) | I3, I4 | SPECULATIVE transfer |
| Psychometrics | multilevel IRT [Fox2001], [Kamata2001], [Adams1997] | latent mediators with item-level data (S5 extension) | SPECULATIVE |
| Ecology | hierarchical Bayesian uncertainty accounting [Cressie2009], [Clark2005] | small-J priors | SPECULATIVE; not medfit's lane |
| Network and interference | general interference [Aronow2017], [OgburnEtAl2022] | I6 | SPECULATIVE |
| Numerical methods | unconstrained parametrizations of covariance matrices [Pinheiro1996] (tier B: title only); penalized likelihood against boundary variance estimates [Chung2013]; a Riemannian framework for tensor computing [Pennec2006] (tier B: title only) | I7 | the Chung transfer is most direct; Pinheiro and Pennec are SPECULATIVE |

Treat the map as a reading list, not as established transfers.

---

## 7. References

References are cited by key. Each entry is the Crossref BibTeX record of its DOI fetched on 2026-11-11, rekeyed to this
note's citation keys (Hox 2012 comes from DataCite). Tier A: abstract read; tier B: metadata only (claims limited to the title).

```bibtex
% tier A
@article{Adams1997, title={Multilevel Item Response Models: An Approach to Errors in Variables Regression}, volume={22}, ISSN={1935-1054}, DOI={10.3102/10769986022001047}, number={1}, journal={Journal of Educational and Behavioral Statistics}, publisher={American Educational Research Association (AERA)}, author={Adams, Raymond J. and Wilson, Mark and Wu, Margaret}, year={1997}, month=Mar, pages={47–76} }

% tier A
@article{Andrews2001, title={Testing When a Parameter is on the Boundary of the Maintained Hypothesis}, volume={69}, ISSN={1468-0262}, DOI={10.1111/1468-0262.00210}, number={3}, journal={Econometrica}, publisher={The Econometric Society}, author={Andrews, Donald W. K.}, year={2001}, month=May, pages={683–734} }

% tier A
@article{Aronow2017, title={Estimating average causal effects under general interference, with application to a social network experiment}, volume={11}, ISSN={1941-7330}, DOI={10.1214/16-aoas1005}, number={4}, journal={The Annals of Applied Statistics}, publisher={Institute of Mathematical Statistics}, author={Aronow, Peter M. and Samii, Cyrus}, year={2017}, month=Dec, pages={1912–1947} }

% tier A
@article{AsparouhovHamakerMuthen2018, title={Dynamic Structural Equation Models}, volume={25}, ISSN={1532-8007}, DOI={10.1080/10705511.2017.1406803}, number={3}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Asparouhov, Tihomir and Hamaker, Ellen L. and Muthén, Bengt}, year={2017}, month=Dec, pages={359–388} }

% tier B
@article{AsparouhovMuthen2019, title={Latent Variable Centering of Predictors and Mediators in Multilevel and Time-Series Models}, volume={26}, ISSN={1532-8007}, DOI={10.1080/10705511.2018.1511375}, number={1}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Asparouhov, Tihomir and Muthén, Bengt}, year={2018}, month=Sept, pages={119–142} }

% tier A
@article{AsparouhovMuthen2021, title={Bayesian estimation of single and multilevel models with latent variable interactions}, volume={28}, ISSN={1532-8007}, DOI={10.1080/10705511.2020.1761808}, number={2}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Asparouhov, Tihomir and Muthén, Bengt}, year={2020}, month=June, pages={314–328} }

% tier A
@article{AsparouhovMuthen2026, title={Three-Level Dynamic Structural Equation Modeling}, volume={33}, ISSN={1532-8007}, DOI={10.1080/10705511.2025.2608122}, number={2}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Asparouhov, Tihomir and Muthén, Bengt}, year={2026}, month=Jan, pages={281–309} }

% tier A
@article{BaiPoon2009, title={Using Mx to Analyze Cross-Level Effects in Two-Level Structural Equation Models}, volume={16}, ISSN={1532-8007}, DOI={10.1080/10705510802561527}, number={1}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Bai, Yun and Poon, Wai-Yin}, year={2009}, month=Jan, pages={163–178} }

% tier A
@article{BarendseRosseel2023, title={Multilevel
                    <scp>SEM</scp>
                    with random slopes in discrete data using the pairwise maximum likelihood}, volume={76}, ISSN={2044-8317}, DOI={10.1111/bmsp.12294}, number={2}, journal={British Journal of Mathematical and Statistical Psychology}, publisher={Wiley}, author={Barendse, Maria T. and Rosseel, Yves}, year={2023}, month=Jan, pages={327–352} }

% tier A
@article{Bates2015, title={Fitting Linear Mixed-Effects Models Using
                    <b>lme4</b>}, volume={67}, ISSN={1548-7660}, DOI={10.18637/jss.v067.i01}, number={1}, journal={Journal of Statistical Software}, publisher={Foundation for Open Access Statistic}, author={Bates, Douglas and Mächler, Martin and Bolker, Ben and Walker, Steve}, year={2015} }

% tier A
@article{BauerPreacherGil2006, title={Conceptualizing and testing random indirect effects and moderated mediation in multilevel models: New procedures and recommendations.}, volume={11}, ISSN={1082-989X}, DOI={10.1037/1082-989x.11.2.142}, number={2}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Bauer, Daniel J. and Preacher, Kristopher J. and Gil, Karen M.}, year={2006}, pages={142–163} }

% tier A
@article{Bell2015, title={Explaining Fixed Effects: Random Effects Modeling of Time-Series Cross-Sectional and Panel Data}, volume={3}, ISSN={2049-8489}, DOI={10.1017/psrm.2014.7}, number={1}, journal={Political Science Research and Methods}, publisher={Cambridge University Press (CUP)}, author={Bell, Andrew and Jones, Kelvyn}, year={2014}, month=May, pages={133–153} }

% tier A
@article{BolgerEtAl2019, title={Causal processes in psychology are heterogeneous.}, volume={148}, ISSN={0096-3445}, DOI={10.1037/xge0000558}, number={4}, journal={Journal of Experimental Psychology: General}, publisher={American Psychological Association (APA)}, author={Bolger, Niall and Zee, Katherine S. and Rossignac-Milon, Maya and Hassin, Ran R.}, year={2019}, month=Apr, pages={601–618} }

% tier A
@article{BollenDavis2009, title={Two Rules of Identification for Structural Equation Models}, volume={16}, ISSN={1532-8007}, DOI={10.1080/10705510903008261}, number={3}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Bollen, Kenneth A. and Davis, Walter R.}, year={2009}, month=July, pages={523–536} }

% tier A
@article{Cameron2008, title={Bootstrap-Based Improvements for Inference with Clustered Errors}, volume={90}, ISSN={1530-9142}, DOI={10.1162/rest.90.3.414}, number={3}, journal={Review of Economics and Statistics}, publisher={MIT Press}, author={Cameron, A. Colin and Gelbach, Jonah B. and Miller, Douglas L.}, year={2008}, month=Aug, pages={414–427} }

% tier A
@article{Cameron2015, title={A Practitioner’s Guide to Cluster-Robust Inference}, volume={50}, ISSN={1548-8004}, DOI={10.3368/jhr.50.2.317}, number={2}, journal={Journal of Human Resources}, publisher={University of Wisconsin Press}, author={Colin Cameron, A. and Miller, Douglas L.}, year={2015}, pages={317–372} }

% tier A
@article{Carpenter2017, title={<i>Stan</i>
                    : A Probabilistic Programming Language}, volume={76}, ISSN={1548-7660}, DOI={10.18637/jss.v076.i01}, number={1}, journal={Journal of Statistical Software}, publisher={Foundation for Open Access Statistic}, author={Carpenter, Bob and Gelman, Andrew and Hoffman, Matthew D. and Lee, Daniel and Goodrich, Ben and Betancourt, Michael and Brubaker, Marcus and Guo, Jiqiang and Li, Peter and Riddell, Allen}, year={2017} }

% tier A
@article{ChengLi2026, title={Semiparametric causal mediation analysis of cluster-randomized trials for indirect and spillover effects}, volume={82}, ISSN={1541-0420}, DOI={10.1093/biomtc/ujag017}, number={1}, journal={Biometrics}, publisher={Oxford University Press (OUP)}, author={Cheng, Chao and Li, Fan}, year={2026}, month=Jan }

% tier A
@article{Chung2013, title={A Nondegenerate Penalized Likelihood Estimator for Variance Parameters in Multilevel Models}, volume={78}, ISSN={1860-0980}, DOI={10.1007/s11336-013-9328-2}, number={4}, journal={Psychometrika}, publisher={Cambridge University Press (CUP)}, author={Chung, Yeojin and Rabe-Hesketh, Sophia and Dorie, Vincent and Gelman, Andrew and Liu, Jingchen}, year={2013}, month=Oct, pages={685–709} }

% tier A
@article{Clark2005, title={Why environmental scientists are becoming Bayesians}, volume={8}, ISSN={1461-0248}, DOI={10.1111/j.1461-0248.2004.00702.x}, number={1}, journal={Ecology Letters}, publisher={Wiley}, author={Clark, James S.}, year={2004}, month=Dec, pages={2–14} }

% tier A
@article{Cressie2009, title={Accounting for uncertainty in ecological analysis: the strengths and limitations of hierarchical statistical modeling}, volume={19}, ISSN={1939-5582}, DOI={10.1890/07-0744.1}, number={3}, journal={Ecological Applications}, publisher={Wiley}, author={Cressie, Noel and Calder, Catherine A. and Clark, James S. and Hoef, Jay M. Ver and Wikle, Christopher K.}, year={2009}, month=Apr, pages={553–570} }

% tier A
@article{CroonVanVeldhoven2007, title={Predicting group-level outcome variables from variables measured at the individual level: A latent variable multilevel model.}, volume={12}, ISSN={1082-989X}, DOI={10.1037/1082-989x.12.1.45}, number={1}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Croon, Marcel A. and van Veldhoven, Marc J. P. M.}, year={2007}, month=Mar, pages={45–57} }

% tier A
@article{DepaoliClifton2015, title={A Bayesian Approach to Multilevel Structural Equation Modeling With Continuous and Dichotomous Outcomes}, volume={22}, ISSN={1532-8007}, DOI={10.1080/10705511.2014.937849}, number={3}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Depaoli, Sarah and Clifton, James P.}, year={2015}, month=Mar, pages={327–351} }

% tier A
@article{DiMariaDidelez2024, title={Longitudinal mediation analysis with multilevel and latent growth models: a separable effects causal approach}, volume={24}, ISSN={1471-2288}, DOI={10.1186/s12874-024-02358-4}, number={1}, journal={BMC Medical Research Methodology}, publisher={Springer Science and Business Media LLC}, author={Di Maria, Chiara and Didelez, Vanessa}, year={2024}, month=Oct }

% tier A
@article{EndersDuKeller2020, title={A model-based imputation procedure for multilevel regression models with random coefficients, interaction effects, and nonlinear terms.}, volume={25}, ISSN={1082-989X}, DOI={10.1037/met0000228}, number={1}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Enders, Craig K. and Du, Han and Keller, Brian T.}, year={2020}, month=Feb, pages={88–112} }

% tier A
@article{EndersKellerLevy2018, title={A fully conditional specification approach to multilevel imputation of categorical and continuous variables.}, volume={23}, ISSN={1082-989X}, DOI={10.1037/met0000148}, number={2}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Enders, Craig K. and Keller, Brian T. and Levy, Roy}, year={2018}, month=June, pages={298–317} }

% tier A
@article{EndersTofighi2007, title={Centering predictor variables in cross-sectional multilevel models: A new look at an old issue.}, volume={12}, ISSN={1082-989X}, DOI={10.1037/1082-989x.12.2.121}, number={2}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Enders, Craig K. and Tofighi, Davood}, year={2007}, pages={121–138} }

% tier A
@article{FalkSavchenko2026, title={Computationally efficient interval estimation for the 1-1-1 multilevel mediation analysis model in R: A replication of Bauer, Preacher, and Gil (2006)}, DOI={10.31234/osf.io/ms39n_v2}, publisher={Center for Open Science}, author={Falk, Carl F. and Savchenko, Elizabeth}, year={2026}, month=Oct }

% tier A
@article{Fox2001, title={Bayesian Estimation of a Multilevel IRT Model Using Gibbs Sampling}, volume={66}, ISSN={1860-0980}, DOI={10.1007/bf02294839}, number={2}, journal={Psychometrika}, publisher={Cambridge University Press (CUP)}, author={Fox, Jean-Paul and Glas, Cees A. W.}, year={2001}, month=June, pages={271–288} }

% tier A
@article{Gilmour1995, title={Average Information REML: An Efficient Algorithm for Variance Parameter Estimation in Linear Mixed Models}, volume={51}, ISSN={0006-341X}, DOI={10.2307/2533274}, number={4}, journal={Biometrics}, publisher={JSTOR}, author={Gilmour, Arthur R. and Thompson, Robin and Cullis, Brian R.}, year={1995}, month=Dec, pages={1440} }

% tier A
@article{GrevenKneib2010, title={On the behaviour of marginal and conditional AIC in linear mixed models}, volume={97}, ISSN={0006-3444}, DOI={10.1093/biomet/asq042}, number={4}, journal={Biometrika}, publisher={Oxford University Press (OUP)}, author={Greven, Sonja and Kneib, Thomas}, year={2010}, month=July, pages={773–789} }

% tier A
@article{GrilliRampichini2007, title={Multilevel Factor Models for Ordinal Variables}, volume={14}, ISSN={1532-8007}, DOI={10.1080/10705510709336734}, number={1}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Grilli, Leonardo and Rampichini, Carla}, year={2007}, month=Jan, pages={1–25} }

% tier A
@article{GrundLudtkeRobitzsch2018, title={Multiple Imputation of Missing Data for Multilevel Models: Simulations and Recommendations}, volume={21}, ISSN={1552-7425}, DOI={10.1177/1094428117703686}, number={1}, journal={Organizational Research Methods}, publisher={SAGE Publications}, author={Grund, Simon and Lüdtke, Oliver and Robitzsch, Alexander}, year={2017}, month=May, pages={111–149} }

% tier A
@article{HamakerEtAl2018, title={At the Frontiers of Modeling Intensive Longitudinal Data: Dynamic Structural Equation Models for the Affective Measurements from the COGITO Study}, volume={53}, ISSN={1532-7906}, DOI={10.1080/00273171.2018.1446819}, number={6}, journal={Multivariate Behavioral Research}, publisher={Informa UK Limited}, author={Hamaker, E. L. and Asparouhov, T. and Brose, A. and Schmiedek, F. and Muthén, B.}, year={2018}, month=Apr, pages={820–841} }

% tier B
@article{Hansen2007, title={Asymptotic properties of a robust variance matrix estimator for panel data when is large}, volume={141}, ISSN={0304-4076}, DOI={10.1016/j.jeconom.2006.10.009}, number={2}, journal={Journal of Econometrics}, publisher={Elsevier BV}, author={Hansen, Christian B.}, year={2007}, month=Dec, pages={597–620} }

% tier A
@article{Hayes2015, title={An Index and Test of Linear Moderated Mediation}, volume={50}, ISSN={1532-7906}, DOI={10.1080/00273171.2014.962683}, number={1}, journal={Multivariate Behavioral Research}, publisher={Informa UK Limited}, author={Hayes, Andrew F.}, year={2015}, month=Jan, pages={1–22} }

% tier A
@article{HongDeutschHill2015, title={Ratio-of-Mediator-Probability Weighting for Causal Mediation Analysis in the Presence of Treatment-by-Mediator Interaction}, volume={40}, ISSN={1935-1054}, DOI={10.3102/1076998615583902}, number={3}, journal={Journal of Educational and Behavioral Statistics}, publisher={American Educational Research Association (AERA)}, author={Hong, Guanglei and Deutsch, Jonah and Hill, Heather D.}, year={2015}, month=June, pages={307–340} }

% tier A
@article{Hox2012,
  author = {Hox, Joop J.C.M. and Van De Schoot, Rens and Matthijsse, Suzette},
  title = {How few countries will do? Comparative survey analysis from a Bayesian perspective},
  year = {2012},
  journal = {Survey Research Methods},
  doi = {10.18148/srm/2012.v6i2.5033}
}

% tier A
@article{HoxMaas2001, title={The Accuracy of Multilevel Structural Equation Modeling With Pseudobalanced Groups and Small Samples}, volume={8}, ISSN={1532-8007}, DOI={10.1207/s15328007sem0802_1}, number={2}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Hox, Joop J. and Maas, Cora J. M.}, year={2001}, month=Apr, pages={157–174} }

% tier A
@article{HoxMaasBrinkhuis2010, title={The effect of estimation method and sample size in multilevel structural equation modeling}, volume={64}, ISSN={1467-9574}, DOI={10.1111/j.1467-9574.2009.00445.x}, number={2}, journal={Statistica Neerlandica}, publisher={Wiley}, author={Hox, Joop J. and Maas, Cora J. M. and Brinkhuis, Matthieu J. S.}, year={2010}, month=Apr, pages={157–170} }

% tier A
@article{Hsu2015, title={Detecting Misspecified Multilevel Structural Equation Models with Common Fit Indices: A Monte Carlo Study}, volume={50}, ISSN={1532-7906}, DOI={10.1080/00273171.2014.977429}, number={2}, journal={Multivariate Behavioral Research}, publisher={Informa UK Limited}, author={Hsu, Hsien-Yuan and Kwok, Oi-man and Lin, Jr Huang and Acosta, Sandra}, year={2015}, month=Mar, pages={197–215} }

% tier A
@article{HudgensHalloran2008, title={Toward Causal Inference With Interference}, volume={103}, ISSN={1537-274X}, DOI={10.1198/016214508000000292}, number={482}, journal={Journal of the American Statistical Association}, publisher={Informa UK Limited}, author={Hudgens, Michael G and Halloran, M. Elizabeth}, year={2008}, month=June, pages={832–842} }

% tier A
@article{ImaiKeeleTingley2010, title={A general approach to causal mediation analysis.}, volume={15}, ISSN={1082-989X}, DOI={10.1037/a0020761}, number={4}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Imai, Kosuke and Keele, Luke and Tingley, Dustin}, year={2010}, pages={309–334} }

% tier A
@article{Imbens2016, title={Robust Standard Errors in Small Samples: Some Practical Advice}, volume={98}, ISSN={1530-9142}, DOI={10.1162/rest_a_00552}, number={4}, journal={Review of Economics and Statistics}, publisher={MIT Press}, author={Imbens, Guido W. and Kolesár, Michal}, year={2016}, month=Oct, pages={701–712} }

% tier A
@article{Jak2021, title={Evaluating Cluster-Level Factor Models with lavaan and Mplus}, volume={3}, ISSN={2624-8611}, DOI={10.3390/psych3020012}, number={2}, journal={Psych}, publisher={MDPI AG}, author={Jak, Suzanne and Jorgensen, Terrence D. and Rosseel, Yves}, year={2021}, month=May, pages={134–152} }

% tier A
@article{JakCheung2026, title={Fitting two-level structural equation models to summary statistics: Leveling up meta-analytic structural equation modeling.}, ISSN={1082-989X}, DOI={10.1037/met0000864}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Jak, Suzanne and Cheung, Mike W. -L.}, year={2026}, month=Aug }

% tier A
@article{JongerlingLaurenceauHamaker2015, title={A Multilevel AR(1) Model: Allowing for Inter-Individual Differences in Trait-Scores, Inertia, and Innovation Variance}, volume={50}, ISSN={1532-7906}, DOI={10.1080/00273171.2014.1003772}, number={3}, journal={Multivariate Behavioral Research}, publisher={Informa UK Limited}, author={Jongerling, Joran and Laurenceau, Jean-Philippe and Hamaker, Ellen L.}, year={2015}, month=May, pages={334–349} }

% tier A
@article{Kamata2001, title={Item Analysis by the Hierarchical Generalized Linear Model}, volume={38}, ISSN={1745-3984}, DOI={10.1111/j.1745-3984.2001.tb01117.x}, number={1}, journal={Journal of Educational Measurement}, publisher={Wiley}, author={Kamata, Akihito}, year={2001}, month=Mar, pages={79–93} }

% tier A
@article{Kelcey2020, title={Power and Sample Size Determination for Multilevel Mediation in Three-Level Cluster-Randomized Trials}, volume={56}, ISSN={1532-7906}, DOI={10.1080/00273171.2020.1738910}, number={3}, journal={Multivariate Behavioral Research}, publisher={Informa UK Limited}, author={Kelcey, Ben and Xie, Yanli and Spybrook, Jessaca and Dong, Nianbo}, year={2020}, month=Apr, pages={496–513} }

% tier A
@article{KennyKorchmarosBolger2003, title={Lower level mediation in multilevel models.}, volume={8}, ISSN={1082-989X}, DOI={10.1037/1082-989x.8.2.115}, number={2}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Kenny, David A. and Korchmaros, Josephine D. and Bolger, Niall}, year={2003}, pages={115–128} }

% tier A
@article{KleinMoosbrugger2000, title={Maximum Likelihood Estimation of Latent Interaction Effects with the LMS Method}, volume={65}, ISSN={1860-0980}, DOI={10.1007/bf02296338}, number={4}, journal={Psychometrika}, publisher={Cambridge University Press (CUP)}, author={Klein, Andreas and Moosbrugger, Helfried}, year={2000}, month=Dec, pages={457–474} }

% tier A
@article{Kristensen2016, title={<b>TMB</b>
                    : Automatic Differentiation and Laplace Approximation}, volume={70}, ISSN={1548-7660}, DOI={10.18637/jss.v070.i05}, number={5}, journal={Journal of Statistical Software}, publisher={Foundation for Open Access Statistic}, author={Kristensen, Kasper and Nielsen, Anders and Berg, Casper W. and Skaug, Hans and Bell, Bradley M.}, year={2016} }

% tier A
@article{KrullMacKinnon2001, title={Multilevel Modeling of Individual and Group Level Mediated Effects}, volume={36}, ISSN={1532-7906}, DOI={10.1207/s15327906mbr3602_06}, number={2}, journal={Multivariate Behavioral Research}, publisher={Informa UK Limited}, author={Krull, Jennifer L. and MacKinnon, David P.}, year={2001}, month=Apr, pages={249–277} }

% tier A
@article{Lai2021boot, title={Bootstrap Confidence Intervals for Multilevel Standardized Effect Size}, volume={56}, ISSN={1532-7906}, DOI={10.1080/00273171.2020.1746902}, number={4}, journal={Multivariate Behavioral Research}, publisher={Informa UK Limited}, author={Lai, Mark H. C.}, year={2020}, month=Apr, pages={558–578} }

% tier A
@article{LaiKwok2015, title={Examining the Rule of Thumb of Not Using Multilevel Modeling: The “Design Effect Smaller Than Two” Rule}, volume={83}, ISSN={1940-0683}, DOI={10.1080/00220973.2014.907229}, number={3}, journal={The Journal of Experimental Education}, publisher={Informa UK Limited}, author={Lai, Mark H. C. and Kwok, Oi-man}, year={2014}, month=July, pages={423–438} }

% tier A
@article{Lee1990, title={Multilevel analysis of structural equation models}, volume={77}, ISSN={1464-3510}, DOI={10.1093/biomet/77.4.763}, number={4}, journal={Biometrika}, publisher={Oxford University Press (OUP)}, author={LEE, SIK-YUM}, year={1990}, pages={763–772} }

% tier A
@article{LeeKim2026, title={Comparing Bayesian random coefficient prediction and latent interaction models for multilevel moderated mediation}, volume={16}, ISSN={1664-1078}, DOI={10.3389/fpsyg.2025.1543330}, journal={Frontiers in Psychology}, publisher={Frontiers Media SA}, author={Lee, Sooyong and Kim, Soyoung}, year={2026}, month=Mar }

% tier A
@article{LiJia2026, title={Addressing Small Sample Concerns for Multilevel Mediation in MSEM Framework: A Comparison of Alternative Strategies}, ISSN={1532-8007}, DOI={10.1080/10705511.2026.2679039}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Li, Yue and Jia, Fan}, year={2026}, month=July, pages={1–21} }

% tier A
@article{LiangBentler2004, title={An EM Algorithm for Fitting Two-Level Structural Equation Models}, volume={69}, ISSN={1860-0980}, DOI={10.1007/bf02295842}, number={1}, journal={Psychometrika}, publisher={Cambridge University Press (CUP)}, author={Liang, Jiajuan and Bentler, Peter M.}, year={2004}, month=Mar, pages={101–122} }

% tier B
@article{Lippert2011, title={FaST linear mixed models for genome-wide association studies}, volume={8}, ISSN={1548-7105}, DOI={10.1038/nmeth.1681}, number={10}, journal={Nature Methods}, publisher={Springer Science and Business Media LLC}, author={Lippert, Christoph and Listgarten, Jennifer and Liu, Ying and Kadie, Carl M and Davidson, Robert I and Heckerman, David}, year={2011}, month=Sept, pages={833–835} }

% tier A
@article{Ludtke2008, title={The multilevel latent covariate model: A new, more reliable approach to group-level effects in contextual studies.}, volume={13}, ISSN={1082-989X}, DOI={10.1037/a0012869}, number={3}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Lüdtke, Oliver and Marsh, Herbert W. and Robitzsch, Alexander and Trautwein, Ulrich and Asparouhov, Tihomir and Muthén, Bengt}, year={2008}, month=Sept, pages={203–229} }

% tier A
@article{Ludtke2011, title={A 2 × 2 taxonomy of multilevel latent contextual models: Accuracy–bias trade-offs in full and partial error correction models.}, volume={16}, ISSN={1082-989X}, DOI={10.1037/a0024376}, number={4}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Lüdtke, Oliver and Marsh, Herbert W. and Robitzsch, Alexander and Trautwein, Ulrich}, year={2011}, month=Dec, pages={444–467} }

% tier A
@article{LudtkeRobitzschGrund2017, title={Multiple imputation of missing data in multilevel designs: A comparison of different strategies.}, volume={22}, ISSN={1082-989X}, DOI={10.1037/met0000096}, number={1}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Lüdtke, Oliver and Robitzsch, Alexander and Grund, Simon}, year={2017}, month=Mar, pages={141–165} }

% tier A
@article{MaasHox2005, title={Sufficient Sample Sizes for Multilevel Modeling}, volume={1}, ISSN={1614-2241}, DOI={10.1027/1614-2241.1.3.86}, number={3}, journal={Methodology}, publisher={Hogrefe Publishing Group}, author={Maas, Cora J. M. and Hox, Joop J.}, year={2005}, month=Jan, pages={86–92} }

% tier A
@article{MacKinnon2023, title={Cluster-robust inference: A guide to empirical practice}, volume={232}, ISSN={0304-4076}, DOI={10.1016/j.jeconom.2022.04.001}, number={2}, journal={Journal of Econometrics}, publisher={Elsevier BV}, author={MacKinnon, James G. and Nielsen, Morten Ørregaard and Webb, Matthew D.}, year={2023}, month=Feb, pages={272–299} }

% tier A
@article{MarshEtAl2009, title={Doubly-Latent Models of School Contextual Effects: Integrating Multilevel and Structural Equation Approaches to Control Measurement and Sampling Error}, volume={44}, ISSN={1532-7906}, DOI={10.1080/00273170903333665}, number={6}, journal={Multivariate Behavioral Research}, publisher={Informa UK Limited}, author={Marsh, Herbert W. and Lüdtke, Oliver and Robitzsch, Alexander and Trautwein, Ulrich and Asparouhov, Tihomir and Muthén, Bengt and Nagengast, Benjamin}, year={2009}, month=Nov, pages={764–802} }

% tier A
@article{McDonaldGoldstein1989, title={Balanced versus unbalanced designs for linear structural relations in two‐level data}, volume={42}, ISSN={2044-8317}, DOI={10.1111/j.2044-8317.1989.tb00911.x}, number={2}, journal={British Journal of Mathematical and Statistical Psychology}, publisher={Wiley}, author={McDonald, Roderick P. and Goldstein, Harvey}, year={1989}, month=Nov, pages={215–232} }

% tier A
@article{McNeish2016, title={On Using Bayesian Methods to Address Small Sample Problems}, volume={23}, ISSN={1532-8007}, DOI={10.1080/10705511.2016.1186549}, number={5}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={McNeish, Daniel}, year={2016}, month=June, pages={750–773} }

% tier A
@article{McNeish2017, title={Multilevel Mediation With Small Samples: A Cautionary Note on the Multilevel Structural Equation Modeling Framework}, volume={24}, ISSN={1532-8007}, DOI={10.1080/10705511.2017.1280797}, number={4}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={McNeish, Daniel}, year={2017}, month=Feb, pages={609–625} }

% tier A
@article{McNeishHamaker2020, title={A primer on two-level dynamic structural equation models for intensive longitudinal data in Mplus.}, volume={25}, ISSN={1082-989X}, DOI={10.1037/met0000250}, number={5}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={McNeish, Daniel and Hamaker, Ellen L.}, year={2020}, month=Oct, pages={610–635} }

% tier A
@article{MehtaNeale2005, title={People are variables too: Multilevel structural equations modeling.}, volume={10}, ISSN={1082-989X}, DOI={10.1037/1082-989x.10.3.259}, number={3}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Mehta, Paras D. and Neale, Michael C.}, year={2005}, month=Sept, pages={259–284} }

% tier A
@article{MerkleRosseel2018, title={<b>blavaan</b>
                    : Bayesian Structural Equation Models via Parameter Expansion}, volume={85}, ISSN={1548-7660}, DOI={10.18637/jss.v085.i04}, number={4}, journal={Journal of Statistical Software}, publisher={Foundation for Open Access Statistic}, author={Merkle, Edgar C. and Rosseel, Yves}, year={2018} }

% tier B
@article{Mundlak1978, title={On the Pooling of Time Series and Cross Section Data}, volume={46}, ISSN={0012-9682}, DOI={10.2307/1913646}, number={1}, journal={Econometrica}, publisher={JSTOR}, author={Mundlak, Yair}, year={1978}, month=Jan, pages={69} }

% tier A
@article{Muthen1994, title={Multilevel Covariance Structure Analysis}, volume={22}, ISSN={1552-8294}, DOI={10.1177/0049124194022003006}, number={3}, journal={Sociological Methods &amp; Research}, publisher={SAGE Publications}, author={MUTHÉN, BENGT O.}, year={1994}, month=Feb, pages={376–398} }

% tier A
@article{MuthenAsparouhov2012, title={Bayesian structural equation modeling: A more flexible representation of substantive theory.}, volume={17}, ISSN={1082-989X}, DOI={10.1037/a0026802}, number={3}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Muthén, Bengt and Asparouhov, Tihomir}, year={2012}, month=Sept, pages={313–335} }

% tier A
@article{MuthenSatorra1995, title={Complex Sample Data in Structural Equation Modeling}, volume={25}, ISSN={0081-1750}, DOI={10.2307/271070}, journal={Sociological Methodology}, publisher={JSTOR}, author={Muthen, Bengt O. and Satorra, Albert}, year={1995}, pages={267} }

% tier A
@article{Neubauer2023, title={How within-person effects shape between-person differences: A multilevel structural equation modeling perspective.}, volume={28}, ISSN={1082-989X}, DOI={10.1037/met0000481}, number={5}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Neubauer, Andreas B. and Brose, Annette and Schmiedek, Florian}, year={2023}, month=Oct, pages={1069–1086} }

% tier A
@article{Niu2024, title={Impact of missing data and ICC on full information maximum-likelihood estimation in multilevel SEMs}, volume={19}, ISSN={1875-9068}, DOI={10.3233/mas-231444}, number={1}, journal={Model Assisted Statistics and Applications}, publisher={SAGE Publications}, author={Niu, Chunling}, year={2024}, month=Mar, pages={49–59} }

% tier A
@article{OgburnEtAl2022, title={Causal Inference for Social Network Data}, volume={119}, ISSN={1537-274X}, DOI={10.1080/01621459.2022.2131557}, number={545}, journal={Journal of the American Statistical Association}, publisher={Informa UK Limited}, author={Ogburn, Elizabeth L. and Sofrygin, Oleg and Díaz, Iván and van der Laan, Mark J.}, year={2022}, month=Dec, pages={597–611} }

% tier A
@article{OgburnVanderWeele2014, title={Causal Diagrams for Interference}, volume={29}, ISSN={2168-8745}, DOI={10.1214/14-sts501}, number={4}, journal={Statistical Science}, publisher={Institute of Mathematical Statistics}, author={Ogburn, Elizabeth L. and VanderWeele, Tyler J.}, year={2014}, month=Nov, pages={559–578} }

% tier A
@article{OhnishiLi2025, title={A Bayesian Nonparametric Approach to Mediation and Spillover Effects with Multiple Mediators in Cluster-Randomized Trials}, volume={121}, ISSN={1537-274X}, DOI={10.1080/01621459.2025.2544366}, number={553}, journal={Journal of the American Statistical Association}, publisher={Informa UK Limited}, author={Ohnishi, Yuki and Li, Fan}, year={2025}, month=Oct, pages={716–728} }

% tier B
@article{Pennec2006, title={A Riemannian Framework for Tensor Computing}, volume={66}, ISSN={1573-1405}, DOI={10.1007/s11263-005-3222-z}, number={1}, journal={International Journal of Computer Vision}, publisher={Springer Science and Business Media LLC}, author={Pennec, Xavier and Fillard, Pierre and Ayache, Nicholas}, year={2006}, month=Jan, pages={41–66} }

% tier B
@article{Pinheiro1996, title={Unconstrained parametrizations for variance-covariance matrices}, volume={6}, ISSN={1573-1375}, DOI={10.1007/bf00140873}, number={3}, journal={Statistics and Computing}, publisher={Springer Science and Business Media LLC}, author={Pinheiro, Jos� C. and Bates, Douglas M.}, year={1996}, month=Sept, pages={289–296} }

% tier A
@article{Pituch2008, title={The Performance of Methods to Test Upper-Level Mediation in the Presence of Nonnormal Data}, volume={43}, ISSN={1532-7906}, DOI={10.1080/00273170802034844}, number={2}, journal={Multivariate Behavioral Research}, publisher={Informa UK Limited}, author={Pituch, Keenan A. and Stapleton, Laura M.}, year={2008}, month=June, pages={237–267} }

% tier A
@article{PituchStapleton2012, title={Distinguishing Between Cross- and Cluster-Level Mediation Processes in the Cluster Randomized Trial}, volume={41}, ISSN={1552-8294}, DOI={10.1177/0049124112460380}, number={4}, journal={Sociological Methods &amp; Research}, publisher={SAGE Publications}, author={Pituch, Keenan A. and Stapleton, Laura M.}, year={2012}, month=Oct, pages={630–670} }

% tier A
@article{Preacher2010, title={A general multilevel SEM framework for assessing multilevel mediation.}, volume={15}, ISSN={1082-989X}, DOI={10.1037/a0020141}, number={3}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Preacher, Kristopher J. and Zyphur, Michael J. and Zhang, Zhen}, year={2010}, pages={209–233} }

% tier A
@article{Preacher2011, title={Alternative Methods for Assessing Mediation in Multilevel Data: The Advantages of Multilevel SEM}, volume={18}, ISSN={1532-8007}, DOI={10.1080/10705511.2011.557329}, number={2}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Preacher, Kristopher J. and Zhang, Zhen and Zyphur, Michael J.}, year={2011}, month=Apr, pages={161–182} }

% tier A
@article{PreacherRuckerHayes2007, title={Addressing Moderated Mediation Hypotheses: Theory, Methods, and Prescriptions}, volume={42}, ISSN={1532-7906}, DOI={10.1080/00273170701341316}, number={1}, journal={Multivariate Behavioral Research}, publisher={Informa UK Limited}, author={Preacher, Kristopher J. and Rucker, Derek D. and Hayes, Andrew F.}, year={2007}, month=June, pages={185–227} }

% tier A
@article{PreacherZhangZyphur2016, title={Multilevel structural equation models for assessing moderation within and across levels of analysis.}, volume={21}, ISSN={1082-989X}, DOI={10.1037/met0000052}, number={2}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Preacher, Kristopher J. and Zhang, Zhen and Zyphur, Michael J.}, year={2016}, month=June, pages={189–205} }

% tier A
@article{Pustejovsky2018, title={Small-Sample Methods for Cluster-Robust Variance Estimation and Hypothesis Testing in Fixed Effects Models}, volume={36}, ISSN={1537-2707}, DOI={10.1080/07350015.2016.1247004}, number={4}, journal={Journal of Business &amp; Economic Statistics}, publisher={Informa UK Limited}, author={Pustejovsky, James E. and Tipton, Elizabeth}, year={2017}, month=June, pages={672–683} }

% tier A
@article{QinHong2017, title={A Weighting Method for Assessing Between-Site Heterogeneity in Causal Mediation Mechanism}, volume={42}, ISSN={1935-1054}, DOI={10.3102/1076998617694879}, number={3}, journal={Journal of Educational and Behavioral Statistics}, publisher={American Educational Research Association (AERA)}, author={Qin, Xu and Hong, Guanglei}, year={2017}, month=Mar, pages={308–340} }

% tier A
@article{QinHongDeutschBein2019, title={Multisite Causal Mediation Analysis in the Presence of Complex Sample and Survey Designs and Non-Random Non-Response}, volume={182}, ISSN={1467-985X}, DOI={10.1111/rssa.12446}, number={4}, journal={Journal of the Royal Statistical Society Series A: Statistics in Society}, publisher={Oxford University Press (OUP)}, author={Qin, Xu and Hong, Guanglei and Deutsch, Jonah and Bein, Edward}, year={2019}, month=Apr, pages={1343–1370} }

% tier A
@article{RabeHesketh2004, title={Generalized Multilevel Structural Equation Modeling}, volume={69}, ISSN={1860-0980}, DOI={10.1007/bf02295939}, number={2}, journal={Psychometrika}, publisher={Cambridge University Press (CUP)}, author={Rabe-Hesketh, Sophia and Skrondal, Anders and Pickles, Andrew}, year={2004}, month=June, pages={167–190} }

% tier A
@article{Rhemtulla2012, title={When can categorical variables be treated as continuous? A comparison of robust continuous and categorical SEM estimation methods under suboptimal conditions.}, volume={17}, ISSN={1082-989X}, DOI={10.1037/a0029315}, number={3}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Rhemtulla, Mijke and Brosseau-Liard, Patricia É. and Savalei, Victoria}, year={2012}, month=Sept, pages={354–373} }

% tier A
@article{RyuWest2009, title={Level-Specific Evaluation of Model Fit in Multilevel Structural Equation Modeling}, volume={16}, ISSN={1532-8007}, DOI={10.1080/10705510903203466}, number={4}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Ryu, Ehri and West, Stephen G.}, year={2009}, month=Oct, pages={583–601} }

% tier A
@article{SavaleiKolenikov2008, title={Constrained versus unconstrained estimation in structural equation modeling.}, volume={13}, ISSN={1082-989X}, DOI={10.1037/1082-989x.13.2.150}, number={2}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Savalei, Victoria and Kolenikov, Stanislav}, year={2008}, pages={150–170} }

% tier A
@article{SchermellehEngelEtAl2014, title={Evaluation of model fit in nonlinear multilevel structural equation modeling}, volume={5}, ISSN={1664-1078}, DOI={10.3389/fpsyg.2014.00181}, journal={Frontiers in Psychology}, publisher={Frontiers Media SA}, author={Schermelleh-Engel, Karin and Kerwer, Martin and Klein, Andreas G.}, year={2014}, month=Mar }

% tier A
@article{SchultzbergMuthen2018, title={Number of Subjects and Time Points Needed for Multilevel Time-Series Analysis: A Simulation Study of Dynamic Structural Equation Modeling}, volume={25}, ISSN={1532-8007}, DOI={10.1080/10705511.2017.1392862}, number={4}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Schultzberg, Mårten and Muthén, Bengt}, year={2017}, month=Dec, pages={495–515} }

% tier A
@article{SelfLiang1987, title={Asymptotic Properties of Maximum Likelihood Estimators and Likelihood Ratio Tests under Nonstandard Conditions}, volume={82}, ISSN={1537-274X}, DOI={10.1080/01621459.1987.10478472}, number={398}, journal={Journal of the American Statistical Association}, publisher={Informa UK Limited}, author={Self, Steven G. and Liang, Kung-Yee}, year={1987}, month=June, pages={605–610} }

% tier A
@article{Smid2019, title={Bayesian Versus Frequentist Estimation for Structural Equation Models in Small Sample Contexts: A Systematic Review}, volume={27}, ISSN={1532-8007}, DOI={10.1080/10705511.2019.1577140}, number={1}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Smid, Sanne C. and McNeish, Daniel and Miočević, Milica and van de Schoot, Rens}, year={2019}, month=May, pages={131–161} }

% tier A
@article{Stapleton2002, title={The Incorporation of Sample Weights Into Multilevel Structural Equation Models}, volume={9}, ISSN={1532-8007}, DOI={10.1207/s15328007sem0904_2}, number={4}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Stapleton, Laura M.}, year={2002}, month=Oct, pages={475–502} }

% tier A
@article{Stoel2006, title={On the likelihood ratio test in structural equation modeling when parameters are subject to boundary constraints.}, volume={11}, ISSN={1082-989X}, DOI={10.1037/1082-989x.11.4.439}, number={4}, journal={Psychological Methods}, publisher={American Psychological Association (APA)}, author={Stoel, Reinoud D. and Garre, Francisca Galindo and Dolan, Conor and van den Wittenboer, Godfried}, year={2006}, pages={439–455} }

% tier A
@article{StramLee1994, title={Variance Components Testing in the Longitudinal Mixed Effects Model}, volume={50}, ISSN={0006-341X}, DOI={10.2307/2533455}, number={4}, journal={Biometrics}, publisher={JSTOR}, author={Stram, Daniel O. and Lee, Jae Won}, year={1994}, month=Dec, pages={1171} }

% tier A
@article{Talloen2016, title={Estimation of Indirect Effects in the Presence of Unmeasured Confounding for the Mediator–Outcome Relationship in a Multilevel 2-1-1 Mediation Model}, volume={41}, ISSN={1935-1054}, DOI={10.3102/1076998616636855}, number={4}, journal={Journal of Educational and Behavioral Statistics}, publisher={American Educational Research Association (AERA)}, author={Talloen, Wouter and Moerkerke, Beatrijs and Loeys, Tom and De Naeghel, Jessie and Van Keer, Hilde and Vansteelandt, Stijn}, year={2016}, month=Aug, pages={359–391} }

% tier A
@article{TchetgenVanderWeele2012, title={On causal inference in the presence of interference}, volume={21}, ISSN={1477-0334}, DOI={10.1177/0962280210386779}, number={1}, journal={Statistical Methods in Medical Research}, publisher={SAGE Publications}, author={Tchetgen, Eric J Tchetgen and VanderWeele, Tyler J}, year={2010}, month=Nov, pages={55–75} }

% tier A
@article{TofighiKelley2016, title={Assessing Omitted Confounder Bias in Multilevel Mediation Models}, volume={51}, ISSN={1532-7906}, DOI={10.1080/00273171.2015.1105736}, number={1}, journal={Multivariate Behavioral Research}, publisher={Informa UK Limited}, author={Tofighi, Davood and Kelley, Ken}, year={2016}, month=Jan, pages={86–105} }

% tier A
@article{VaidaBlanchard2005, title={Conditional Akaike information for mixed-effects models}, volume={92}, ISSN={0006-3444}, DOI={10.1093/biomet/92.2.351}, number={2}, journal={Biometrika}, publisher={Oxford University Press (OUP)}, author={Vaida, Florin and Blanchard, Suzette}, year={2005}, month=June, pages={351–370} }

% tier A
@article{VanderWeele2013, title={Mediation and Spillover Effects in Group-Randomized Trials: A Case Study of the 4Rs Educational Intervention}, volume={108}, ISSN={1537-274X}, DOI={10.1080/01621459.2013.779832}, number={502}, journal={Journal of the American Statistical Association}, publisher={Informa UK Limited}, author={Vanderweele, Tyler J. and Hong, Guanglei and Jones, Stephanie M. and Brown, Joshua L.}, year={2013}, month=June, pages={469–482} }

% tier A
@article{VanderWeele2014, title={A Unification of Mediation and Interaction: A 4-Way Decomposition}, volume={25}, ISSN={1044-3983}, DOI={10.1097/ede.0000000000000121}, number={5}, journal={Epidemiology}, publisher={Ovid Technologies (Wolters Kluwer Health)}, author={VanderWeele, Tyler J.}, year={2014}, month=Sept, pages={749–761} }

% tier A
@article{Walther2025a, title={Shrinking Small Sample Problems in Multilevel Structural Equation Modeling via Regularization of the Sample Covariance Matrix}, volume={32}, ISSN={1532-8007}, DOI={10.1080/10705511.2024.2380919}, number={1}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Walther, Julia-Kim and Hecht, Martin and Zitzmann, Steffen}, year={2024}, month=Aug, pages={46–65} }

% tier A
@article{WangPreacher2015, title={Moderated Mediation Analysis Using Bayesian Methods}, volume={22}, ISSN={1532-8007}, DOI={10.1080/10705511.2014.935256}, number={2}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Wang, Lijuan (Peggy) and Preacher, Kristopher J.}, year={2014}, month=Sept, pages={249–263} }

% tier A
@article{Wood2011, title={Fast Stable Restricted Maximum Likelihood and Marginal Likelihood Estimation of Semiparametric Generalized Linear Models}, volume={73}, ISSN={1467-9868}, DOI={10.1111/j.1467-9868.2010.00749.x}, number={1}, journal={Journal of the Royal Statistical Society Series B: Statistical Methodology}, publisher={Oxford University Press (OUP)}, author={Wood, Simon N.}, year={2010}, month=Sept, pages={3–36} }

% tier B
@article{Wooldridge2019, title={Correlated random effects models with unbalanced panels}, volume={211}, ISSN={0304-4076}, DOI={10.1016/j.jeconom.2018.12.010}, number={1}, journal={Journal of Econometrics}, publisher={Elsevier BV}, author={Wooldridge, Jeffrey M.}, year={2019}, month=July, pages={137–150} }

% tier A
@article{YuanBentler2000, title={5. Three Likelihood-Based Methods for Mean and Covariance Structure Analysis with Nonnormal Missing Data}, volume={30}, ISSN={1467-9531}, DOI={10.1111/0081-1750.00078}, number={1}, journal={Sociological Methodology}, publisher={SAGE Publications}, author={Yuan, Ke-Hai and Bentler, Peter M.}, year={2000}, month=Aug, pages={165–200} }

% tier A
@article{YuanBentler2002, title={On Normal Theory Based Inference for Multilevel Models with Distributional Violations}, volume={67}, ISSN={1860-0980}, DOI={10.1007/bf02295130}, number={4}, journal={Psychometrika}, publisher={Cambridge University Press (CUP)}, author={Yuan, Ke-Hai and Bentler, Peter M.}, year={2002}, month=Dec, pages={539–561} }

% tier B
@article{YuanBentler2003, title={Eight test statistics for multilevel structural equation models}, volume={44}, ISSN={0167-9473}, DOI={10.1016/s0167-9473(02)00349-3}, number={1-2}, journal={Computational Statistics &amp; Data Analysis}, publisher={Elsevier BV}, author={Yuan, Ke-Hai and Bentler, Peter M.}, year={2003}, month=Oct, pages={89–107} }

% tier A
@article{YuanBentler2007, title={3. Multilevel Covariance Structure Analysis by Fitting Multiple Single-Level Models}, volume={37}, ISSN={1467-9531}, DOI={10.1111/j.1467-9531.2007.00182.x}, number={1}, journal={Sociological Methodology}, publisher={SAGE Publications}, author={Yuan, Ke-Hai and Bentler, Peter M.}, year={2007}, month=Aug, pages={53–82} }

% tier A
@article{Zhang2009, title={Testing Multilevel Mediation Using Hierarchical Linear Models: Problems and Solutions}, volume={12}, ISSN={1552-7425}, DOI={10.1177/1094428108327450}, number={4}, journal={Organizational Research Methods}, publisher={SAGE Publications}, author={Zhang, Zhen and Zyphur, Michael J. and Preacher, Kristopher J.}, year={2008}, month=Dec, pages={695–719} }

% tier B
@article{Zhou2012, title={Genome-wide efficient mixed-model analysis for association studies}, volume={44}, ISSN={1546-1718}, DOI={10.1038/ng.2310}, number={7}, journal={Nature Genetics}, publisher={Springer Science and Business Media LLC}, author={Zhou, Xiang and Stephens, Matthew}, year={2012}, month=June, pages={821–824} }

% tier A
@article{ZiglerYe2019, title={A Comparison of Multilevel Mediation Modeling Methods: Recommendations for Applied Researchers}, volume={54}, ISSN={1532-7906}, DOI={10.1080/00273171.2018.1527676}, number={3}, journal={Multivariate Behavioral Research}, publisher={Informa UK Limited}, author={Zigler, Christina K. and Ye, Feifei}, year={2019}, month=Jan, pages={338–359} }

% tier A
@article{Zitzmann2016, title={A Bayesian Approach for Estimating Multilevel Latent Contextual Models}, volume={23}, ISSN={1532-8007}, DOI={10.1080/10705511.2016.1207179}, number={5}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Zitzmann, Steffen and Lüdtke, Oliver and Robitzsch, Alexander and Marsh, Herbert W.}, year={2016}, month=Aug, pages={661–679} }

% tier A
@article{burkner2017brms, title={<b>brms</b>
                    : An
                    <i>R</i>
                    Package for Bayesian Multilevel Models Using
                    <i>Stan</i>}, volume={80}, ISSN={1548-7660}, DOI={10.18637/jss.v080.i01}, number={1}, journal={Journal of Statistical Software}, publisher={Foundation for Open Access Statistic}, author={Bürkner, Paul-Christian}, year={2017} }

% tier A
@article{igolkina2020semopy, title={semopy: A Python Package for Structural Equation Modeling}, volume={27}, ISSN={1532-8007}, DOI={10.1080/10705511.2019.1704289}, number={6}, journal={Structural Equation Modeling: A Multidisciplinary Journal}, publisher={Informa UK Limited}, author={Igolkina, Anna A. and Meshcheryakov, Georgy}, year={2020}, month=Feb, pages={952–963} }

% tier A
@article{lefcheck2016piecewisesem, title={<scp>piecewiseSEM</scp>
                    : Piecewise structural equation modelling in
                    <scp>r</scp>
                     for ecology, evolution, and systematics}, volume={7}, ISSN={2041-210X}, DOI={10.1111/2041-210x.12512}, number={5}, journal={Methods in Ecology and Evolution}, publisher={Wiley}, author={Lefcheck, Jonathan S.}, editor={Freckleton, Robert}, year={2015}, month=Dec, pages={573–579} }

% tier A
@article{tingley2014mediation, title={<b>mediation</b>
                    :
                    <i>R</i>
                    Package for Causal Mediation Analysis}, volume={59}, ISSN={1548-7660}, DOI={10.18637/jss.v059.i05}, number={5}, journal={Journal of Statistical Software}, publisher={Foundation for Open Access Statistic}, author={Tingley, Dustin and Yamamoto, Teppei and Hirose, Kentaro and Keele, Luke and Imai, Kosuke}, year={2014} }

% tier B
@article{vuorre2018bmlm, title={Within-subject mediation analysis for experimental data in cognitive psychology and neuroscience}, volume={50}, ISSN={1554-3528}, DOI={10.3758/s13428-017-0980-9}, number={5}, journal={Behavior Research Methods}, publisher={Springer Science and Business Media LLC}, author={Vuorre, Matti and Bolger, Niall}, year={2017}, month=Dec, pages={2125–2143} }
```

