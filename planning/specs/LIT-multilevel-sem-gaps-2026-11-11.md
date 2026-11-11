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

**Counts (cited sources).** 126 sources are cited: 93 tier A (abstract read), 33 tier B (metadata only). The five research passes opened 188 sources in all (130 tier A, 58 tier B); the other 62 are not cited here. Unverified or `[CITE]` items: the items listed in 1.1 plus the MBCO reference marked **[CITE]**. The research passes were run by subagents; each cited DOI was re-fetched from Crossref or DataCite in a final pass to render section 7.

### 1.1 Not verified, so not cited as support

Muthén and Asparouhov on categorical outcomes in Mplus (no matching record); Hayes (2013), Bolger and Laurenceau (2013)
and Hong (2015, tier B only) as books; Zhang and Wang multilevel mediation; a multilevel Kelava (latent interaction)
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
with conventional SEM software [Muthen1994]; it is an approximate estimator. McDonald and Goldstein give the two-level
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
accuracy [MaasHox2005]. ML-SEM mediation needs about 100 clusters according to one review, while published studies have a
median of 44 [McNeish2017]. The design effect rule of thumb (ignore clustering below 2) was never studied systematically
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

| Row | lavaan 0.7-3 | Mplus (UG 8th ed.) | OpenMx 2.22.11 | blavaan 0.6-1 | Stata (`gsem`, `sem`, `mixed`) | medfit 0.16.0 |
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
| `semopy` (Python) | random effects from linear mixed models (arXiv abstract); two-level SEM not described (unverified) [igolkina2020semopy] |
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
  row with `level != 1` (`R/sem-fit.R:96-98`). No `cluster` argument exists in `fit_sem()`.
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
   versus unconstrained matrix-log or Cholesky parametrizations [Pinheiro1996] (tier B, title only) versus a penalty
   [Chung2013] (tier B, title only). INFERENCE: a boundary solution is an infinite parameter value under log-Cholesky, which
   changes SEs and LR behavior; the choice should be an experiment, not an assumption.
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
models in lavaan have their own evaluation recipe [Jak2021] (tier B). INFERENCE: S5 should follow S4's oracle and
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

Cross-disciplinary sources below are mostly **tier B (title only)**; the transfer claims are labeled. Nothing here is a
finding.

### 6.1 Ranked ideas

| Rank | Idea | Gap | Why novel (INFERENCE) | Feasibility | Independent oracle |
|---|---|---|---|---|---|
| I1 | **Two-level model-based constrained-optimization (MBCO-style) tests** for the within and between indirect effects (a times b = 0 at one level or both), splitting the zero-product null into exact linear branches per level (as medfit does single-level) and using a boundary-aware reference law | G3 | no source read combines product nulls, boundary variances and two levels; MBCO itself: **[CITE]** | medium after S4; the branch machinery exists (`.sem_fit_branches()`) | lavaan refits with a = 0 or b = 0 per level; Monte Carlo null calibration; the O8 hand likelihood |
| I2 | **A formal test of equal indirect effects across levels** (a_w b_w = a_b b_b) as a nonlinear equality constraint, replacing the descriptive contrast | G3 | the current contrast is descriptive by design; a test needs the constrained fit | medium after S4; nonlinear rows exist | lavaan constrained fit (nonlinear constraints in two-level unverified); parametric bootstrap under the null |
| I3 | **Manifest-versus-latent cluster-mean diagnostic**: medfit already has both routes (lmer cluster-mean centering and lavaan latent means); the gap between their between-level paths flags latent-mean bias as cluster size and ICC change [Ludtke2008], [Mundlak1978], [Bell2015] | G2 | a built-in diagnostic using two routes in one package is not described in sources read; econometrics transfer is SPECULATIVE | high (both routes shipped) | simulation with known between and within truth, over n_j and ICC |
| I4 | **Few-cluster robust inference for products of coefficients:** CR2-type or wild-cluster adjustments applied to the between-level indirect effect from cluster scores [Cameron2008], [Pustejovsky2018], [Imbens2016] (all tier B) | G7 | SPECULATIVE transfer from econometrics to a product of two path estimates | medium after S6 | cluster bootstrap callbacks already shipped; coverage grid |
| I5 | **Conditional-AIC-style criterion for two-level SEM** using effective degrees of freedom [VaidaBlanchard2005], [GrevenKneib2010] | G6 | nothing found for latent-variable multilevel SEM | low to medium; theory first | leave-cluster-out predictive log-likelihood |
| I6 | **Interference-aware reading of the between-level path:** state the assumptions under which a between a-path times b-path is a spillover-type indirect effect [VanderWeele2013], [Talloen2016], [Aronow2017] (tier B) | G4 | a theory note linking latent-mean SEM paths to spillover estimands was not found | theory-heavy; docs value even without proof | simulate from a structural causal model with known spillover and compare to the g-formula truth |
| I7 | **Level-2 variance handling experiment:** floors, matrix-log and penalty compared on Heywood-prone cells [Pinheiro1996], [Chung2013] (tier B) | G2 | the comparison inside a SEM engine with constraints is not described | high (part of S4) | lavaan's Heywood fixtures; Bayesian posterior mode as reference |
| I8 | **Automatic-differentiation oracles (Stan or TMB)** for the two-level likelihood and its gradient [Carpenter2017], [Kristensen2016] (tier B) | testing the analytic gradient | an oracle, not a method | high for p = 3; needs the Stan toolchain | the oracle itself |
| I9 | **Balanced-design closed forms** as exact start values and a check: the balanced likelihood splits into two single-level pieces [McDonaldGoldstein1989], [Muthen1994] | S4 start values | known result used as a test | high | pooled-within and between covariance fits |
| I10 | **Two-level FIML through EM** (E-step with Gaussian conditionals; analog of [LiangBentler2004]) | G5 | not explored for medfit's engine | XL | lavaan two-level `missing = "ml"` |

### 6.2 Cross-disciplinary map

| Field | What was solved (title-level) | Multilevel SEM analog | Status |
|---|---|---|---|
| Mixed-model computation | profiled deviance with sparse Cholesky [Bates2015]; REML and Laplace with automatic differentiation [Wood2011], [Kristensen2016] | reduce SLSQP dimension by concentrating out means; exact gradients | SPECULATIVE; p is small, so the gain may be negligible |
| Genetics | rotate the dense covariance to a diagonal once [Lippert2011], [Zhou2012]; average-information REML [Gilmour1995] | balanced clusters need one decomposition; cheap curvature for covariance parameters | SPECULATIVE; likely unnecessary at mediation-model sizes |
| Econometrics | cluster-robust inference and small-cluster fixes [Cameron2015], [MacKinnon2023], [Hansen2007]; correlated random effects [Mundlak1978], [Wooldridge2019], [Bell2015] | I3, I4 | SPECULATIVE transfer |
| Psychometrics | multilevel IRT [Fox2001], [Kamata2001], [Adams1997] | latent mediators with item-level data (S5 extension) | SPECULATIVE |
| Ecology | hierarchical Bayesian uncertainty accounting [Cressie2009], [Clark2005] | small-J priors | SPECULATIVE; not medfit's lane |
| Network and interference | general interference [Aronow2017], [OgburnEtAl2022] | I6 | SPECULATIVE |
| Numerical methods | log-Cholesky parametrization [Pinheiro1996]; penalized boundary estimation [Chung2013]; manifold geometry of covariance matrices [Pennec2006] | I7 | the Pinheiro and Chung transfers are most direct; Pennec is SPECULATIVE |

Several entries rest on title-level evidence (tier B). Treat the map as a reading list, not as established transfers.

---

## 7. References

References are cited by key. Each entry is rendered from the Crossref record of its DOI on 2026-11-11 (title, authors, year,
journal, DOI). Tier A: abstract read; tier B: metadata only (claims limited to the title).

- **[Adams1997]** Adams, R., Wilson, M., Wu, M. (1997). Multilevel Item Response Models: An Approach to Errors in Variables Regression. Journal of Educational and Behavioral Statistics 22(1), 47-76. doi:[10.3102/10769986022001047](https://doi.org/10.3102/10769986022001047) (tier B)
- **[Andrews2001]** Andrews, D. (2001). Testing When a Parameter is on the Boundary of the Maintained Hypothesis. Econometrica 69(3), 683-734. doi:[10.1111/1468-0262.00210](https://doi.org/10.1111/1468-0262.00210) (tier A)
- **[Aronow2017]** Aronow, P., Samii, C. (2017). Estimating average causal effects under general interference, with application to a social network experiment. The Annals of Applied Statistics 11(4), 1912-1947. doi:[10.1214/16-aoas1005](https://doi.org/10.1214/16-aoas1005) (tier B)
- **[AsparouhovHamakerMuthen2018]** Asparouhov, T., Hamaker, E., Muthén, B. (2018). Dynamic Structural Equation Models. Structural Equation Modeling: A Multidisciplinary Journal 25(3), 359-388. doi:[10.1080/10705511.2017.1406803](https://doi.org/10.1080/10705511.2017.1406803) (tier A)
- **[AsparouhovMuthen2019]** Asparouhov, T., Muthén, B. (2019). Latent Variable Centering of Predictors and Mediators in Multilevel and Time-Series Models. Structural Equation Modeling: A Multidisciplinary Journal 26(1), 119-142. doi:[10.1080/10705511.2018.1511375](https://doi.org/10.1080/10705511.2018.1511375) (tier B)
- **[AsparouhovMuthen2021]** Asparouhov, T., Muthén, B. (2021). Bayesian estimation of single and multilevel models with latent variable interactions. Structural Equation Modeling: A Multidisciplinary Journal 28(2), 314-328. doi:[10.1080/10705511.2020.1761808](https://doi.org/10.1080/10705511.2020.1761808) (tier A)
- **[AsparouhovMuthen2026]** Asparouhov, T., Muthén, B. (2026). Three-Level Dynamic Structural Equation Modeling. Structural Equation Modeling: A Multidisciplinary Journal 33(2), 281-309. doi:[10.1080/10705511.2025.2608122](https://doi.org/10.1080/10705511.2025.2608122) (tier A)
- **[BaiPoon2009]** Bai, Y., Poon, W. (2009). Using Mx to Analyze Cross-Level Effects in Two-Level Structural Equation Models. Structural Equation Modeling: A Multidisciplinary Journal 16(1), 163-178. doi:[10.1080/10705510802561527](https://doi.org/10.1080/10705510802561527) (tier A)
- **[BarendseRosseel2023]** Barendse, M., Rosseel, Y. (2023). Multilevel SEM with random slopes in discrete data using the pairwise maximum likelihood. British Journal of Mathematical and Statistical Psychology 76(2), 327-352. doi:[10.1111/bmsp.12294](https://doi.org/10.1111/bmsp.12294) (tier A)
- **[Bates2015]** Bates, D., Mächler, M., Bolker, B., Walker, S. (2015). Fitting Linear Mixed-Effects Models Using lme4. Journal of Statistical Software 67(1). doi:[10.18637/jss.v067.i01](https://doi.org/10.18637/jss.v067.i01) (tier B)
- **[BauerPreacherGil2006]** Bauer, D., Preacher, K., Gil, K. (2006). Conceptualizing and testing random indirect effects and moderated mediation in multilevel models: New procedures and recommendations.. Psychological Methods 11(2), 142-163. doi:[10.1037/1082-989x.11.2.142](https://doi.org/10.1037/1082-989x.11.2.142) (tier A)
- **[Bell2015]** Bell, A., Jones, K. (2015). Explaining Fixed Effects: Random Effects Modeling of Time-Series Cross-Sectional and Panel Data. Political Science Research and Methods 3(1), 133-153. doi:[10.1017/psrm.2014.7](https://doi.org/10.1017/psrm.2014.7) (tier B)
- **[BolgerEtAl2019]** Bolger, N., Zee, K., Rossignac-Milon, M., Hassin, R. (2019). Causal processes in psychology are heterogeneous.. Journal of Experimental Psychology: General 148(4), 601-618. doi:[10.1037/xge0000558](https://doi.org/10.1037/xge0000558) (tier A)
- **[BollenDavis2009]** Bollen, K., Davis, W. (2009). Two Rules of Identification for Structural Equation Models. Structural Equation Modeling: A Multidisciplinary Journal 16(3), 523-536. doi:[10.1080/10705510903008261](https://doi.org/10.1080/10705510903008261) (tier A)
- **[Cameron2008]** Cameron, A., Gelbach, J., Miller, D. (2008). Bootstrap-Based Improvements for Inference with Clustered Errors. Review of Economics and Statistics 90(3), 414-427. doi:[10.1162/rest.90.3.414](https://doi.org/10.1162/rest.90.3.414) (tier B)
- **[Cameron2015]** Colin Cameron, A., Miller, D. (2015). A Practitioner’s Guide to Cluster-Robust Inference. Journal of Human Resources 50(2), 317-372. doi:[10.3368/jhr.50.2.317](https://doi.org/10.3368/jhr.50.2.317) (tier B)
- **[Carpenter2017]** Carpenter, B., Gelman, A., Hoffman, M., Lee, D., Goodrich, B., Betancourt, M., et al. (2017). Stan : A Probabilistic Programming Language. Journal of Statistical Software 76(1). doi:[10.18637/jss.v076.i01](https://doi.org/10.18637/jss.v076.i01) (tier B)
- **[ChengLi2026]** Cheng, C., Li, F. (2026). Semiparametric causal mediation analysis of cluster-randomized trials for indirect and spillover effects. Biometrics 82(1). doi:[10.1093/biomtc/ujag017](https://doi.org/10.1093/biomtc/ujag017) (tier A)
- **[Chung2013]** Chung, Y., Rabe-Hesketh, S., Dorie, V., Gelman, A., Liu, J. (2013). A Nondegenerate Penalized Likelihood Estimator for Variance Parameters in Multilevel Models. Psychometrika 78(4), 685-709. doi:[10.1007/s11336-013-9328-2](https://doi.org/10.1007/s11336-013-9328-2) (tier B)
- **[Clark2005]** Clark, J. (2005). Why environmental scientists are becoming Bayesians. Ecology Letters 8(1), 2-14. doi:[10.1111/j.1461-0248.2004.00702.x](https://doi.org/10.1111/j.1461-0248.2004.00702.x) (tier B)
- **[Cressie2009]** Cressie, N., Calder, C., Clark, J., Hoef, J., Wikle, C. (2009). Accounting for uncertainty in ecological analysis: the strengths and limitations of hierarchical statistical modeling. Ecological Applications 19(3), 553-570. doi:[10.1890/07-0744.1](https://doi.org/10.1890/07-0744.1) (tier B)
- **[CroonVanVeldhoven2007]** Croon, M., van Veldhoven, M. (2007). Predicting group-level outcome variables from variables measured at the individual level: A latent variable multilevel model.. Psychological Methods 12(1), 45-57. doi:[10.1037/1082-989x.12.1.45](https://doi.org/10.1037/1082-989x.12.1.45) (tier A)
- **[DepaoliClifton2015]** Depaoli, S., Clifton, J. (2015). A Bayesian Approach to Multilevel Structural Equation Modeling With Continuous and Dichotomous Outcomes. Structural Equation Modeling: A Multidisciplinary Journal 22(3), 327-351. doi:[10.1080/10705511.2014.937849](https://doi.org/10.1080/10705511.2014.937849) (tier A)
- **[DiMariaDidelez2024]** Di Maria, C., Didelez, V. (2024). Longitudinal mediation analysis with multilevel and latent growth models: a separable effects causal approach. BMC Medical Research Methodology 24(1). doi:[10.1186/s12874-024-02358-4](https://doi.org/10.1186/s12874-024-02358-4) (tier A)
- **[EndersDuKeller2020]** Enders, C., Du, H., Keller, B. (2020). A model-based imputation procedure for multilevel regression models with random coefficients, interaction effects, and nonlinear terms.. Psychological Methods 25(1), 88-112. doi:[10.1037/met0000228](https://doi.org/10.1037/met0000228) (tier A)
- **[EndersKellerLevy2018]** Enders, C., Keller, B., Levy, R. (2018). A fully conditional specification approach to multilevel imputation of categorical and continuous variables.. Psychological Methods 23(2), 298-317. doi:[10.1037/met0000148](https://doi.org/10.1037/met0000148) (tier A)
- **[EndersTofighi2007]** Enders, C., Tofighi, D. (2007). Centering predictor variables in cross-sectional multilevel models: A new look at an old issue.. Psychological Methods 12(2), 121-138. doi:[10.1037/1082-989x.12.2.121](https://doi.org/10.1037/1082-989x.12.2.121) (tier A)
- **[FalkSavchenko2026]** Falk, C., Savchenko, E. (2026). Computationally efficient interval estimation for the 1-1-1 multilevel mediation analysis model in R: A replication of Bauer, Preacher, and Gil (2006). . doi:[10.31234/osf.io/ms39n_v2](https://doi.org/10.31234/osf.io/ms39n_v2) (tier A)
- **[Fox2001]** Fox, J., Glas, C. (2001). Bayesian Estimation of a Multilevel IRT Model Using Gibbs Sampling. Psychometrika 66(2), 271-288. doi:[10.1007/bf02294839](https://doi.org/10.1007/bf02294839) (tier B)
- **[Gilmour1995]** Gilmour, A., Thompson, R., Cullis, B. (1995). Average Information REML: An Efficient Algorithm for Variance Parameter Estimation in Linear Mixed Models. Biometrics 51(4), 1440. doi:[10.2307/2533274](https://doi.org/10.2307/2533274) (tier B)
- **[GrevenKneib2010]** Greven, S., Kneib, T. (2010). On the behaviour of marginal and conditional AIC in linear mixed models. Biometrika 97(4), 773-789. doi:[10.1093/biomet/asq042](https://doi.org/10.1093/biomet/asq042) (tier A)
- **[GrilliRampichini2007]** Grilli, L., Rampichini, C. (2007). Multilevel Factor Models for Ordinal Variables. Structural Equation Modeling: A Multidisciplinary Journal 14(1), 1-25. doi:[10.1080/10705510709336734](https://doi.org/10.1080/10705510709336734) (tier A)
- **[GrundLudtkeRobitzsch2018]** Grund, S., Lüdtke, O., Robitzsch, A. (2018). Multiple Imputation of Missing Data for Multilevel Models. Organizational Research Methods 21(1), 111-149. doi:[10.1177/1094428117703686](https://doi.org/10.1177/1094428117703686) (tier A)
- **[HamakerEtAl2018]** Hamaker, E., Asparouhov, T., Brose, A., Schmiedek, F., Muthén, B. (2018). At the Frontiers of Modeling Intensive Longitudinal Data: Dynamic Structural Equation Models for the Affective Measurements from the COGITO Study. Multivariate Behavioral Research 53(6), 820-841. doi:[10.1080/00273171.2018.1446819](https://doi.org/10.1080/00273171.2018.1446819) (tier A)
- **[Hansen2007]** Hansen, C. (2007). Asymptotic properties of a robust variance matrix estimator for panel data when is large. Journal of Econometrics 141(2), 597-620. doi:[10.1016/j.jeconom.2006.10.009](https://doi.org/10.1016/j.jeconom.2006.10.009) (tier B)
- **[Hayes2015]** Hayes, A. (2015). An Index and Test of Linear Moderated Mediation. Multivariate Behavioral Research 50(1), 1-22. doi:[10.1080/00273171.2014.962683](https://doi.org/10.1080/00273171.2014.962683) (tier A)
- **[HongDeutschHill2015]** Hong, G., Deutsch, J., Hill, H. (2015). Ratio-of-Mediator-Probability Weighting for Causal Mediation Analysis in the Presence of Treatment-by-Mediator Interaction. Journal of Educational and Behavioral Statistics 40(3), 307-340. doi:[10.3102/1076998615583902](https://doi.org/10.3102/1076998615583902) (tier A)
- **[Hox2012]** Hox, Joop J.C.M., Van De Schoot, Rens, Matthijsse, Suzette (2012). How few countries will do? Comparative survey analysis from a Bayesian perspective. Survey Research Methods. doi:[10.18148/srm/2012.v6i2.5033](https://doi.org/10.18148/srm/2012.v6i2.5033) (tier A)
- **[HoxMaas2001]** Hox, J., Maas, C. (2001). The Accuracy of Multilevel Structural Equation Modeling With Pseudobalanced Groups and Small Samples. Structural Equation Modeling: A Multidisciplinary Journal 8(2), 157-174. doi:[10.1207/s15328007sem0802_1](https://doi.org/10.1207/s15328007sem0802_1) (tier A)
- **[HoxMaasBrinkhuis2010]** Hox, J., Maas, C., Brinkhuis, M. (2010). The effect of estimation method and sample size in multilevel structural equation modeling. Statistica Neerlandica 64(2), 157-170. doi:[10.1111/j.1467-9574.2009.00445.x](https://doi.org/10.1111/j.1467-9574.2009.00445.x) (tier A)
- **[Hsu2015]** Hsu, H., Kwok, O., Lin, J., Acosta, S. (2015). Detecting Misspecified Multilevel Structural Equation Models with Common Fit Indices: A Monte Carlo Study. Multivariate Behavioral Research 50(2), 197-215. doi:[10.1080/00273171.2014.977429](https://doi.org/10.1080/00273171.2014.977429) (tier A)
- **[HudgensHalloran2008]** Hudgens, M., Halloran, M. (2008). Toward Causal Inference With Interference. Journal of the American Statistical Association 103(482), 832-842. doi:[10.1198/016214508000000292](https://doi.org/10.1198/016214508000000292) (tier A)
- **[ImaiKeeleTingley2010]** Imai, K., Keele, L., Tingley, D. (2010). A general approach to causal mediation analysis.. Psychological Methods 15(4), 309-334. doi:[10.1037/a0020761](https://doi.org/10.1037/a0020761) (tier A)
- **[Imbens2016]** Imbens, G., Kolesár, M. (2016). Robust Standard Errors in Small Samples: Some Practical Advice. Review of Economics and Statistics 98(4), 701-712. doi:[10.1162/rest_a_00552](https://doi.org/10.1162/rest_a_00552) (tier B)
- **[Jak2021]** Jak, S., Jorgensen, T., Rosseel, Y. (2021). Evaluating Cluster-Level Factor Models with lavaan and Mplus. Psych 3(2), 134-152. doi:[10.3390/psych3020012](https://doi.org/10.3390/psych3020012) (tier B)
- **[JakCheung2026]** Jak, S., Cheung, M. (2026). Fitting two-level structural equation models to summary statistics: Leveling up meta-analytic structural equation modeling.. Psychological Methods. doi:[10.1037/met0000864](https://doi.org/10.1037/met0000864) (tier A)
- **[JongerlingLaurenceauHamaker2015]** Jongerling, J., Laurenceau, J., Hamaker, E. (2015). A Multilevel AR(1) Model: Allowing for Inter-Individual Differences in Trait-Scores, Inertia, and Innovation Variance. Multivariate Behavioral Research 50(3), 334-349. doi:[10.1080/00273171.2014.1003772](https://doi.org/10.1080/00273171.2014.1003772) (tier A)
- **[Kamata2001]** Kamata, A. (2001). Item Analysis by the Hierarchical Generalized Linear Model. Journal of Educational Measurement 38(1), 79-93. doi:[10.1111/j.1745-3984.2001.tb01117.x](https://doi.org/10.1111/j.1745-3984.2001.tb01117.x) (tier B)
- **[Kelcey2020]** Kelcey, B., Xie, Y., Spybrook, J., Dong, N. (2021). Power and Sample Size Determination for Multilevel Mediation in Three-Level Cluster-Randomized Trials. Multivariate Behavioral Research 56(3), 496-513. doi:[10.1080/00273171.2020.1738910](https://doi.org/10.1080/00273171.2020.1738910) (tier A)
- **[KennyKorchmarosBolger2003]** Kenny, D., Korchmaros, J., Bolger, N. (2003). Lower level mediation in multilevel models.. Psychological Methods 8(2), 115-128. doi:[10.1037/1082-989x.8.2.115](https://doi.org/10.1037/1082-989x.8.2.115) (tier A)
- **[KleinMoosbrugger2000]** Klein, A., Moosbrugger, H. (2000). Maximum Likelihood Estimation of Latent Interaction Effects with the LMS Method. Psychometrika 65(4), 457-474. doi:[10.1007/bf02296338](https://doi.org/10.1007/bf02296338) (tier A)
- **[Kristensen2016]** Kristensen, K., Nielsen, A., Berg, C., Skaug, H., Bell, B. (2016). TMB : Automatic Differentiation and Laplace Approximation. Journal of Statistical Software 70(5). doi:[10.18637/jss.v070.i05](https://doi.org/10.18637/jss.v070.i05) (tier B)
- **[KrullMacKinnon2001]** Krull, J., MacKinnon, D. (2001). Multilevel Modeling of Individual and Group Level Mediated Effects. Multivariate Behavioral Research 36(2), 249-277. doi:[10.1207/s15327906mbr3602_06](https://doi.org/10.1207/s15327906mbr3602_06) (tier A)
- **[Lai2021boot]** Lai, M. (2021). Bootstrap Confidence Intervals for Multilevel Standardized Effect Size. Multivariate Behavioral Research 56(4), 558-578. doi:[10.1080/00273171.2020.1746902](https://doi.org/10.1080/00273171.2020.1746902) (tier A)
- **[LaiKwok2015]** Lai, M., Kwok, O. (2015). Examining the Rule of Thumb of Not Using Multilevel Modeling: The “Design Effect Smaller Than Two” Rule. The Journal of Experimental Education 83(3), 423-438. doi:[10.1080/00220973.2014.907229](https://doi.org/10.1080/00220973.2014.907229) (tier A)
- **[Lee1990]** LEE, S. (1990). Multilevel analysis of structural equation models. Biometrika 77(4), 763-772. doi:[10.1093/biomet/77.4.763](https://doi.org/10.1093/biomet/77.4.763) (tier A)
- **[LeeKim2026]** Lee, S., Kim, S. (2026). Comparing Bayesian random coefficient prediction and latent interaction models for multilevel moderated mediation. Frontiers in Psychology 16. doi:[10.3389/fpsyg.2025.1543330](https://doi.org/10.3389/fpsyg.2025.1543330) (tier A)
- **[LiJia2026]** Li, Y., Jia, F. (2026). Addressing Small Sample Concerns for Multilevel Mediation in MSEM Framework: A Comparison of Alternative Strategies. Structural Equation Modeling: A Multidisciplinary Journal, 1-21. doi:[10.1080/10705511.2026.2679039](https://doi.org/10.1080/10705511.2026.2679039) (tier A)
- **[LiangBentler2004]** Liang, J., Bentler, P. (2004). An EM Algorithm for Fitting Two-Level Structural Equation Models. Psychometrika 69(1), 101-122. doi:[10.1007/bf02295842](https://doi.org/10.1007/bf02295842) (tier A)
- **[Lippert2011]** Lippert, C., Listgarten, J., Liu, Y., Kadie, C., Davidson, R., Heckerman, D. (2011). FaST linear mixed models for genome-wide association studies. Nature Methods 8(10), 833-835. doi:[10.1038/nmeth.1681](https://doi.org/10.1038/nmeth.1681) (tier B)
- **[Ludtke2008]** Lüdtke, O., Marsh, H., Robitzsch, A., Trautwein, U., Asparouhov, T., Muthén, B. (2008). The multilevel latent covariate model: A new, more reliable approach to group-level effects in contextual studies.. Psychological Methods 13(3), 203-229. doi:[10.1037/a0012869](https://doi.org/10.1037/a0012869) (tier A)
- **[Ludtke2011]** Lüdtke, O., Marsh, H., Robitzsch, A., Trautwein, U. (2011). A 2 × 2 taxonomy of multilevel latent contextual models: Accuracy–bias trade-offs in full and partial error correction models.. Psychological Methods 16(4), 444-467. doi:[10.1037/a0024376](https://doi.org/10.1037/a0024376) (tier A)
- **[LudtkeRobitzschGrund2017]** Lüdtke, O., Robitzsch, A., Grund, S. (2017). Multiple imputation of missing data in multilevel designs: A comparison of different strategies.. Psychological Methods 22(1), 141-165. doi:[10.1037/met0000096](https://doi.org/10.1037/met0000096) (tier A)
- **[MaasHox2005]** Maas, C., Hox, J. (2005). Sufficient Sample Sizes for Multilevel Modeling. Methodology 1(3), 86-92. doi:[10.1027/1614-2241.1.3.86](https://doi.org/10.1027/1614-2241.1.3.86) (tier A)
- **[MacKinnon2023]** MacKinnon, J., Nielsen, M., Webb, M. (2023). Cluster-robust inference: A guide to empirical practice. Journal of Econometrics 232(2), 272-299. doi:[10.1016/j.jeconom.2022.04.001](https://doi.org/10.1016/j.jeconom.2022.04.001) (tier B)
- **[MarshEtAl2009]** Marsh, H., Lüdtke, O., Robitzsch, A., Trautwein, U., Asparouhov, T., Muthén, B., et al. (2009). Doubly-Latent Models of School Contextual Effects: Integrating Multilevel and Structural Equation Approaches to Control Measurement and Sampling Error. Multivariate Behavioral Research 44(6), 764-802. doi:[10.1080/00273170903333665](https://doi.org/10.1080/00273170903333665) (tier A)
- **[McDonaldGoldstein1989]** McDonald, R., Goldstein, H. (1989). Balanced versus unbalanced designs for linear structural relations in two‐level data. British Journal of Mathematical and Statistical Psychology 42(2), 215-232. doi:[10.1111/j.2044-8317.1989.tb00911.x](https://doi.org/10.1111/j.2044-8317.1989.tb00911.x) (tier A)
- **[McNeish2016]** McNeish, D. (2016). On Using Bayesian Methods to Address Small Sample Problems. Structural Equation Modeling: A Multidisciplinary Journal 23(5), 750-773. doi:[10.1080/10705511.2016.1186549](https://doi.org/10.1080/10705511.2016.1186549) (tier A)
- **[McNeish2017]** McNeish, D. (2017). Multilevel Mediation With Small Samples: A Cautionary Note on the Multilevel Structural Equation Modeling Framework. Structural Equation Modeling: A Multidisciplinary Journal 24(4), 609-625. doi:[10.1080/10705511.2017.1280797](https://doi.org/10.1080/10705511.2017.1280797) (tier A)
- **[McNeishHamaker2020]** McNeish, D., Hamaker, E. (2020). A primer on two-level dynamic structural equation models for intensive longitudinal data in Mplus.. Psychological Methods 25(5), 610-635. doi:[10.1037/met0000250](https://doi.org/10.1037/met0000250) (tier A)
- **[MehtaNeale2005]** Mehta, P., Neale, M. (2005). People are variables too: Multilevel structural equations modeling.. Psychological Methods 10(3), 259-284. doi:[10.1037/1082-989x.10.3.259](https://doi.org/10.1037/1082-989x.10.3.259) (tier A)
- **[MerkleRosseel2018]** Merkle, E., Rosseel, Y. (2018). blavaan : Bayesian Structural Equation Models via Parameter Expansion. Journal of Statistical Software 85(4). doi:[10.18637/jss.v085.i04](https://doi.org/10.18637/jss.v085.i04) (tier A)
- **[Mundlak1978]** Mundlak, Y. (1978). On the Pooling of Time Series and Cross Section Data. Econometrica 46(1), 69. doi:[10.2307/1913646](https://doi.org/10.2307/1913646) (tier B)
- **[Muthen1994]** MUTHÉN, B. (1994). Multilevel Covariance Structure Analysis. Sociological Methods & Research 22(3), 376-398. doi:[10.1177/0049124194022003006](https://doi.org/10.1177/0049124194022003006) (tier A)
- **[MuthenAsparouhov2012]** Muthén, B., Asparouhov, T. (2012). Bayesian structural equation modeling: A more flexible representation of substantive theory.. Psychological Methods 17(3), 313-335. doi:[10.1037/a0026802](https://doi.org/10.1037/a0026802) (tier A)
- **[MuthenSatorra1995]** Muthen, B., Satorra, A. (1995). Complex Sample Data in Structural Equation Modeling. Sociological Methodology 25, 267. doi:[10.2307/271070](https://doi.org/10.2307/271070) (tier A)
- **[Neubauer2023]** Neubauer, A., Brose, A., Schmiedek, F. (2023). How within-person effects shape between-person differences: A multilevel structural equation modeling perspective.. Psychological Methods 28(5), 1069-1086. doi:[10.1037/met0000481](https://doi.org/10.1037/met0000481) (tier A)
- **[Niu2024]** Niu, C. (2024). Impact of missing data and ICC on full information maximum-likelihood estimation in multilevel SEMs. Model Assisted Statistics and Applications 19(1), 49-59. doi:[10.3233/mas-231444](https://doi.org/10.3233/mas-231444) (tier A)
- **[OgburnEtAl2022]** Ogburn, E., Sofrygin, O., Díaz, I., van der Laan, M. (2024). Causal Inference for Social Network Data. Journal of the American Statistical Association 119(545), 597-611. doi:[10.1080/01621459.2022.2131557](https://doi.org/10.1080/01621459.2022.2131557) (tier A)
- **[OgburnVanderWeele2014]** Ogburn, E., VanderWeele, T. (2014). Causal Diagrams for Interference. Statistical Science 29(4), 559-578. doi:[10.1214/14-sts501](https://doi.org/10.1214/14-sts501) (tier A)
- **[OhnishiLi2025]** Ohnishi, Y., Li, F. (2026). A Bayesian Nonparametric Approach to Mediation and Spillover Effects with Multiple Mediators in Cluster-Randomized Trials. Journal of the American Statistical Association 121(553), 716-728. doi:[10.1080/01621459.2025.2544366](https://doi.org/10.1080/01621459.2025.2544366) (tier A)
- **[Pennec2006]** Pennec, X., Fillard, P., Ayache, N. (2006). A Riemannian Framework for Tensor Computing. International Journal of Computer Vision 66(1), 41-66. doi:[10.1007/s11263-005-3222-z](https://doi.org/10.1007/s11263-005-3222-z) (tier B)
- **[Pinheiro1996]** Pinheiro, J., Bates, D. (1996). Unconstrained parametrizations for variance-covariance matrices. Statistics and Computing 6(3), 289-296. doi:[10.1007/bf00140873](https://doi.org/10.1007/bf00140873) (tier B)
- **[Pituch2008]** Pituch, K., Stapleton, L. (2008). The Performance of Methods to Test Upper-Level Mediation in the Presence of Nonnormal Data. Multivariate Behavioral Research 43(2), 237-267. doi:[10.1080/00273170802034844](https://doi.org/10.1080/00273170802034844) (tier A)
- **[PituchStapleton2012]** Pituch, K., Stapleton, L. (2012). Distinguishing Between Cross- and Cluster-Level Mediation Processes in the Cluster Randomized Trial. Sociological Methods & Research 41(4), 630-670. doi:[10.1177/0049124112460380](https://doi.org/10.1177/0049124112460380) (tier A)
- **[Preacher2010]** Preacher, K., Zyphur, M., Zhang, Z. (2010). A general multilevel SEM framework for assessing multilevel mediation.. Psychological Methods 15(3), 209-233. doi:[10.1037/a0020141](https://doi.org/10.1037/a0020141) (tier A)
- **[Preacher2011]** Preacher, K., Zhang, Z., Zyphur, M. (2011). Alternative Methods for Assessing Mediation in Multilevel Data: The Advantages of Multilevel SEM. Structural Equation Modeling: A Multidisciplinary Journal 18(2), 161-182. doi:[10.1080/10705511.2011.557329](https://doi.org/10.1080/10705511.2011.557329) (tier A)
- **[PreacherRuckerHayes2007]** Preacher, K., Rucker, D., Hayes, A. (2007). Addressing Moderated Mediation Hypotheses: Theory, Methods, and Prescriptions. Multivariate Behavioral Research 42(1), 185-227. doi:[10.1080/00273170701341316](https://doi.org/10.1080/00273170701341316) (tier A)
- **[PreacherZhangZyphur2016]** Preacher, K., Zhang, Z., Zyphur, M. (2016). Multilevel structural equation models for assessing moderation within and across levels of analysis.. Psychological Methods 21(2), 189-205. doi:[10.1037/met0000052](https://doi.org/10.1037/met0000052) (tier A)
- **[Pustejovsky2018]** Pustejovsky, J., Tipton, E. (2018). Small-Sample Methods for Cluster-Robust Variance Estimation and Hypothesis Testing in Fixed Effects Models. Journal of Business & Economic Statistics 36(4), 672-683. doi:[10.1080/07350015.2016.1247004](https://doi.org/10.1080/07350015.2016.1247004) (tier B)
- **[QinHong2017]** Qin, X., Hong, G. (2017). A Weighting Method for Assessing Between-Site Heterogeneity in Causal Mediation Mechanism. Journal of Educational and Behavioral Statistics 42(3), 308-340. doi:[10.3102/1076998617694879](https://doi.org/10.3102/1076998617694879) (tier A)
- **[QinHongDeutschBein2019]** Qin, X., Hong, G., Deutsch, J., Bein, E. (2019). Multisite Causal Mediation Analysis in the Presence of Complex Sample and Survey Designs and Non-Random Non-Response. Journal of the Royal Statistical Society Series A: Statistics in Society 182(4), 1343-1370. doi:[10.1111/rssa.12446](https://doi.org/10.1111/rssa.12446) (tier A)
- **[RabeHesketh2004]** Rabe-Hesketh, S., Skrondal, A., Pickles, A. (2004). Generalized Multilevel Structural Equation Modeling. Psychometrika 69(2), 167-190. doi:[10.1007/bf02295939](https://doi.org/10.1007/bf02295939) (tier A)
- **[Rhemtulla2012]** Rhemtulla, M., Brosseau-Liard, P., Savalei, V. (2012). When can categorical variables be treated as continuous? A comparison of robust continuous and categorical SEM estimation methods under suboptimal conditions.. Psychological Methods 17(3), 354-373. doi:[10.1037/a0029315](https://doi.org/10.1037/a0029315) (tier A)
- **[RyuWest2009]** Ryu, E., West, S. (2009). Level-Specific Evaluation of Model Fit in Multilevel Structural Equation Modeling. Structural Equation Modeling: A Multidisciplinary Journal 16(4), 583-601. doi:[10.1080/10705510903203466](https://doi.org/10.1080/10705510903203466) (tier A)
- **[SavaleiKolenikov2008]** Savalei, V., Kolenikov, S. (2008). Constrained versus unconstrained estimation in structural equation modeling.. Psychological Methods 13(2), 150-170. doi:[10.1037/1082-989x.13.2.150](https://doi.org/10.1037/1082-989x.13.2.150) (tier A)
- **[SchermellehEngelEtAl2014]** Schermelleh-Engel, K., Kerwer, M., Klein, A. (2014). Evaluation of model fit in nonlinear multilevel structural equation modeling. Frontiers in Psychology 5. doi:[10.3389/fpsyg.2014.00181](https://doi.org/10.3389/fpsyg.2014.00181) (tier A)
- **[SchultzbergMuthen2018]** Schultzberg, M., Muthén, B. (2018). Number of Subjects and Time Points Needed for Multilevel Time-Series Analysis: A Simulation Study of Dynamic Structural Equation Modeling. Structural Equation Modeling: A Multidisciplinary Journal 25(4), 495-515. doi:[10.1080/10705511.2017.1392862](https://doi.org/10.1080/10705511.2017.1392862) (tier A)
- **[SelfLiang1987]** Self, S., Liang, K. (1987). Asymptotic Properties of Maximum Likelihood Estimators and Likelihood Ratio Tests under Nonstandard Conditions. Journal of the American Statistical Association 82(398), 605-610. doi:[10.1080/01621459.1987.10478472](https://doi.org/10.1080/01621459.1987.10478472) (tier A)
- **[Smid2019]** Smid, S., McNeish, D., Miočević, M., van de Schoot, R. (2020). Bayesian Versus Frequentist Estimation for Structural Equation Models in Small Sample Contexts: A Systematic Review. Structural Equation Modeling: A Multidisciplinary Journal 27(1), 131-161. doi:[10.1080/10705511.2019.1577140](https://doi.org/10.1080/10705511.2019.1577140) (tier A)
- **[Stapleton2002]** Stapleton, L. (2002). The Incorporation of Sample Weights Into Multilevel Structural Equation Models. Structural Equation Modeling: A Multidisciplinary Journal 9(4), 475-502. doi:[10.1207/s15328007sem0904_2](https://doi.org/10.1207/s15328007sem0904_2) (tier A)
- **[Stoel2006]** Stoel, R., Garre, F., Dolan, C., van den Wittenboer, G. (2006). On the likelihood ratio test in structural equation modeling when parameters are subject to boundary constraints.. Psychological Methods 11(4), 439-455. doi:[10.1037/1082-989x.11.4.439](https://doi.org/10.1037/1082-989x.11.4.439) (tier A)
- **[StramLee1994]** Stram, D., Lee, J. (1994). Variance Components Testing in the Longitudinal Mixed Effects Model. Biometrics 50(4), 1171. doi:[10.2307/2533455](https://doi.org/10.2307/2533455) (tier A)
- **[Talloen2016]** Talloen, W., Moerkerke, B., Loeys, T., De Naeghel, J., Van Keer, H., Vansteelandt, S. (2016). Estimation of Indirect Effects in the Presence of Unmeasured Confounding for the Mediator–Outcome Relationship in a Multilevel 2-1-1 Mediation Model. Journal of Educational and Behavioral Statistics 41(4), 359-391. doi:[10.3102/1076998616636855](https://doi.org/10.3102/1076998616636855) (tier A)
- **[TchetgenVanderWeele2012]** Tchetgen, E., VanderWeele, T. (2012). On causal inference in the presence of interference. Statistical Methods in Medical Research 21(1), 55-75. doi:[10.1177/0962280210386779](https://doi.org/10.1177/0962280210386779) (tier A)
- **[TofighiKelley2016]** Tofighi, D., Kelley, K. (2016). Assessing Omitted Confounder Bias in Multilevel Mediation Models. Multivariate Behavioral Research 51(1), 86-105. doi:[10.1080/00273171.2015.1105736](https://doi.org/10.1080/00273171.2015.1105736) (tier A)
- **[VaidaBlanchard2005]** Vaida, F., Blanchard, S. (2005). Conditional Akaike information for mixed-effects models. Biometrika 92(2), 351-370. doi:[10.1093/biomet/92.2.351](https://doi.org/10.1093/biomet/92.2.351) (tier A)
- **[VanderWeele2013]** Vanderweele, T., Hong, G., Jones, S., Brown, J. (2013). Mediation and Spillover Effects in Group-Randomized Trials: A Case Study of the 4Rs Educational Intervention. Journal of the American Statistical Association 108(502), 469-482. doi:[10.1080/01621459.2013.779832](https://doi.org/10.1080/01621459.2013.779832) (tier A)
- **[VanderWeele2014]** VanderWeele, T. (2014). A Unification of Mediation and Interaction. Epidemiology 25(5), 749-761. doi:[10.1097/ede.0000000000000121](https://doi.org/10.1097/ede.0000000000000121) (tier A)
- **[Walther2025a]** Walther, J., Hecht, M., Zitzmann, S. (2025). Shrinking Small Sample Problems in Multilevel Structural Equation Modeling via Regularization of the Sample Covariance Matrix. Structural Equation Modeling: A Multidisciplinary Journal 32(1), 46-65. doi:[10.1080/10705511.2024.2380919](https://doi.org/10.1080/10705511.2024.2380919) (tier A)
- **[WangPreacher2015]** Wang, L., Preacher, K. (2015). Moderated Mediation Analysis Using Bayesian Methods. Structural Equation Modeling: A Multidisciplinary Journal 22(2), 249-263. doi:[10.1080/10705511.2014.935256](https://doi.org/10.1080/10705511.2014.935256) (tier A)
- **[Wood2011]** Wood, S. (2011). Fast Stable Restricted Maximum Likelihood and Marginal Likelihood Estimation of Semiparametric Generalized Linear Models. Journal of the Royal Statistical Society Series B: Statistical Methodology 73(1), 3-36. doi:[10.1111/j.1467-9868.2010.00749.x](https://doi.org/10.1111/j.1467-9868.2010.00749.x) (tier B)
- **[Wooldridge2019]** Wooldridge, J. (2019). Correlated random effects models with unbalanced panels. Journal of Econometrics 211(1), 137-150. doi:[10.1016/j.jeconom.2018.12.010](https://doi.org/10.1016/j.jeconom.2018.12.010) (tier B)
- **[YuanBentler2000]** Yuan, K., Bentler, P. (2000). 5. Three Likelihood-Based Methods for Mean and Covariance Structure Analysis with Nonnormal Missing Data. Sociological Methodology 30(1), 165-200. doi:[10.1111/0081-1750.00078](https://doi.org/10.1111/0081-1750.00078) (tier A)
- **[YuanBentler2002]** Yuan, K., Bentler, P. (2002). On Normal Theory Based Inference for Multilevel Models with Distributional Violations. Psychometrika 67(4), 539-561. doi:[10.1007/bf02295130](https://doi.org/10.1007/bf02295130) (tier A)
- **[YuanBentler2003]** Yuan, K., Bentler, P. (2003). Eight test statistics for multilevel structural equation models. Computational Statistics & Data Analysis 44(1-2), 89-107. doi:[10.1016/s0167-9473(02)00349-3](https://doi.org/10.1016/s0167-9473(02)00349-3) (tier B)
- **[YuanBentler2007]** Yuan, K., Bentler, P. (2007). 3. Multilevel Covariance Structure Analysis by Fitting Multiple Single-Level Models. Sociological Methodology 37(1), 53-82. doi:[10.1111/j.1467-9531.2007.00182.x](https://doi.org/10.1111/j.1467-9531.2007.00182.x) (tier A)
- **[Zhang2009]** Zhang, Z., Zyphur, M., Preacher, K. (2009). Testing Multilevel Mediation Using Hierarchical Linear Models. Organizational Research Methods 12(4), 695-719. doi:[10.1177/1094428108327450](https://doi.org/10.1177/1094428108327450) (tier A)
- **[Zhou2012]** Zhou, X., Stephens, M. (2012). Genome-wide efficient mixed-model analysis for association studies. Nature Genetics 44(7), 821-824. doi:[10.1038/ng.2310](https://doi.org/10.1038/ng.2310) (tier B)
- **[ZiglerYe2019]** Zigler, C., Ye, F. (2019). A Comparison of Multilevel Mediation Modeling Methods: Recommendations for Applied Researchers. Multivariate Behavioral Research 54(3), 338-359. doi:[10.1080/00273171.2018.1527676](https://doi.org/10.1080/00273171.2018.1527676) (tier A)
- **[Zitzmann2016]** Zitzmann, S., Lüdtke, O., Robitzsch, A., Marsh, H. (2016). A Bayesian Approach for Estimating Multilevel Latent Contextual Models. Structural Equation Modeling: A Multidisciplinary Journal 23(5), 661-679. doi:[10.1080/10705511.2016.1207179](https://doi.org/10.1080/10705511.2016.1207179) (tier A)
- **[burkner2017brms]** Bürkner, P. (2017). brms : An R Package for Bayesian Multilevel Models Using Stan. Journal of Statistical Software 80(1). doi:[10.18637/jss.v080.i01](https://doi.org/10.18637/jss.v080.i01) (tier B)
- **[igolkina2020semopy]** Igolkina, A., Meshcheryakov, G. (2020). semopy: A Python Package for Structural Equation Modeling. Structural Equation Modeling: A Multidisciplinary Journal 27(6), 952-963. doi:[10.1080/10705511.2019.1704289](https://doi.org/10.1080/10705511.2019.1704289) (tier B)
- **[lefcheck2016piecewisesem]** Lefcheck, J. (2016). piecewiseSEM : Piecewise structural equation modelling in r for ecology, evolution, and systematics. Methods in Ecology and Evolution 7(5), 573-579. doi:[10.1111/2041-210x.12512](https://doi.org/10.1111/2041-210x.12512) (tier B)
- **[tingley2014mediation]** Tingley, D., Yamamoto, T., Hirose, K., Keele, L., Imai, K. (2014). mediation : R Package for Causal Mediation Analysis. Journal of Statistical Software 59(5). doi:[10.18637/jss.v059.i05](https://doi.org/10.18637/jss.v059.i05) (tier B)
- **[vuorre2018bmlm]** Vuorre, M., Bolger, N. (2018). Within-subject mediation analysis for experimental data in cognitive psychology and neuroscience. Behavior Research Methods 50(5), 2125-2143. doi:[10.3758/s13428-017-0980-9](https://doi.org/10.3758/s13428-017-0980-9) (tier B)
