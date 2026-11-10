# Research: joint two-level SEM for 1-1-1 mediation (issue #394)

**Date:** 2026-11-10 · **Status:** research note, read-only investigation (no code written) ·
**Issue:** [Data-Wise/medfit#394](https://github.com/Data-Wise/medfit/issues/394) ·
**Companion:** [PLAN-multilevel-mediation-2026-11-10.md](PLAN-multilevel-mediation-2026-11-10.md)

Everything marked **[run]** was executed locally on 2026-11-09 (lavaan 0.7.3, lme4 2.1.0, R from this machine);
everything marked **[unverified]** was not.

---

## 1. What medfit already has

| Piece | State | Where |
|---|---|---|
| 2-1-1 cluster mediation (treatment at the cluster level, Gaussian) | **Shipped in 0.6.0** (PRs #90-#92, #95, #100). `ClusterMediationData` with `a_path`, `b_within`, `b_between`, `c_prime`, KR t intervals, cluster bootstrap | `R/classes.R:1937`, `R/extract-lmer.R`, `R/fit-lmer.R`, spec `SPEC-multilevel-mediation-2-1-1-2026-09-25.md` |
| 1-1-1 designs (treatment varies within clusters) and sigma_ab | **Explicitly deferred to "module 2"** with "its own grill" (D1, D6, D15 in `GRILL-multilevel-mediation-ext-d-2026-09-25.md`; spec line 39, 62). Module 2 was never started: no spec, no grill file, no mention in `.STATUS`-linked plans after 0.6.0 | `planning/medfit-roadmap.md:1991` ("Module 2 ... follows") |
| Class-per-design rule | D6: "a separate 1-1-1 class in module 2. MediationData is not extended." `ClusterMediationData` is named for the 2-1-1 design (D15, spec A1) | GRILL D6, D15 |
| Native SEM engine (ML, RAM) | Parser already reads `level: <integer>` lines and stores a `level` column in `parsed$parameters` (`R/sem-parse.R:322-326`); the fitter refuses any row with `level != 1` | `R/sem-fit.R:96-98` |
| Exact error | `two-level estimation is not implemented: the model uses `level:` blocks` | `R/sem-fit.R:97` |
| `fit_sem()`/`fit_mediation(engine = "native")` arguments | no `cluster` argument anywhere in the native route; `cluster =` exists only on the lmer engine and on `bootstrap_mediation()` | `R/fit-sem.R`, `R/fit-lmer.R` |
| `extract_mediation(<lavaan>)` | Single-level only. **On a two-level lavaan fit it does not error: it returns an ordinary `MediationData` built from the first (within) block** **[run]**: a = 0.3071, b = 0.5035 equal the within-level `aw`, `bw` (between values were 0.687 and 0.344), `n_obs` = 543 (all observations), no warning. A silent wrong-level extraction | `R/extract-lavaan.R:117` onward |
| Effect generics | `nie/nde/te/pm/paths/decompose` are S7 generics with one method per class; `ClusterMediationData` already has `decompose()` (own, spillover) | `R/aab-generics.R`, `R/generics-effects.R`, `R/effect-se.R` |
| Roadmap and ecosystem | `medfit-roadmap.md` lists multilevel and "random slopes" under the module-2 backlog; the mediationverse hub (`~/projects/r-packages/mediation-planning/`, read-only) has only `[ ] Multilevel mediation` in IDEAS and "lmer Engine" in `docs/ROADMAP.md`; no 1-1-1 plan there | grep of both trees |
| Issue history | #394 filed 2026-11-10; the issue text cites medfit 0.7.0 (stale: the current line is 0.16.0). The `level:` refusal text is unchanged | `gh issue view 394` |

**What has not been done:** no two-level likelihood, no `level:`-aware parser validation, no cluster ID argument in the native
fitter, no adapter for two-level lavaan fits, no class with level-qualified paths, no cross-level covariance anywhere.
The existing 2-1-1 class deliberately uses a *different* estimator (lmer, REML) and a *different* parameterization (cluster
mean + within term in one outcome equation, block-diagonal `@vcov` of alias rows `a`, `c_prime`, `b_within`,
`b_between`); it has no within/between pair for `a` and no cross-level covariance because in 2-1-1 `a` is purely
between.

**Design consequence recorded in D6:** the 1-1-1 class must be new, not a property bolt-on to `ClusterMediationData`.

## 2. What lavaan provides **[run]**

Installed: **lavaan 0.7.3**. All claims below were reproduced with the script
`/private/tmp/claude-501/scratch/ml.R` and `ml2.R` (scratch, not committed; the plan turns them into test fixtures).

### 2.1 The issue's claims, tested

Model (observed x, m, y; two levels; fixed slopes; cluster id `id`; 100 clusters; balanced n = 5 and unbalanced n in 2..9):

```
level: 1                 level: 2
  m ~ aw*x                 m ~ ab*x
  y ~ bw*m + cw*x          y ~ bb*m + cb*x
iw := aw*bw ; ib := ab*bb ; diff := iw - ib
```

| Claim in #394 | Result |
|---|---|
| lavaan fits it on `lavaan::Demo.twolevel` (200 clusters of 5 to 20, `y1`-`y8`, `x1`-`x3`, `w1`-`w2`, `level`, `cluster`) | Yes. The issue's `fw =~ y1+y2+y3` / `fb =~ y1+y2+y3` model converges with `cluster = "cluster"`, 200 clusters of sizes 5 to 20 (`ncluster.size` = 4 counts distinct sizes, not the average). |
| Estimator and information | `estimator = "ML"`, `se = "standard"`, `h1 = TRUE`; `converged` TRUE. The ML here is the exact (non-EM) cluster-wise Gaussian likelihood for unbalanced data. `estimator = "MLR"`, `se = "robust.huber.white"` and `missing = "fiml"` are all accepted (fit object returned; not checked for numbers) |
| Joint covariance of level-specific paths | `vcov(fit)` is 12 x 12 over all free parameters, with level-2 parameters suffixed `.l2` (`m~~m.l2`, ...). The four path estimates have a full 4 x 4 block; cross-level entries are **not zero**: balanced `Cov(aw, ab) = -0.00076`, `Cov(aw, bb) = 0.00042`; latent-mediator fixture correlations `Cor(aw, ab) = -0.068`, `Cor(bw, bb) = -0.109`. Within-level `Cov(aw, bw)` is exactly 0 in the observed model (separate equations, orthogonal information) |
| `:=` contrast SE uses the joint covariance | Yes. Hand delta method `sqrt(g' V g)` with `g = (bw, aw, -bb, -ab)` over the joint `vcov` equals lavaan's `diff` SE to all printed digits: balanced 0.08421823 vs 0.08421823; unbalanced 0.06925929 vs 0.06925929 |
| Level-specific defined parameters | `iw`, `ib`, `diff` appear in `parameterEstimates()` with `block = 0`, `level = 0` |
| Shared loadings across levels | `fw =~ m1 + l2*m2 + l3*m3` and `fb =~ m1 + l2*m2 + l3*m3` converge. Warning (not an error): `level-specific fit measures are not available: the model contains (equality) constraints involving parameters from different levels` |
| Likelihood | Reproduced by a hand-built cluster-wise Gaussian likelihood (below): `-2604.74` hand vs `-2604.74` lavaan on an unbalanced 100-cluster fixture (agreement checked at six printed digits; the plan requires 1e-8) |

Not verified: that medfit 0.7.0 produced the issue's exact error text (the current text is identical, `R/sem-fit.R:97`).

### 2.2 How to get the objects out of a lavaan two-level fit

- `lavInspect(fit, "nclusters")`, `"cluster.size"`, `"ncluster.size"` (number of distinct sizes), `"nobs"` (per-block).
- `parTable(fit)` has `block` (1 = within, 2 = between), `level` and `group`; free-parameter rows give `label`, `free` (the
  `vcov()` index), so the join `match(label, free$label)` yields the vcov rows for any labeled path. Unlabeled paths need
  `(lhs, op, rhs, level)` matching: `m ~ x` appears in both levels with identical `lhs/op/rhs`, so **level must be part of the key**
  (the current lavaan extractor keys on `lhs/op/rhs` only, which is why it silently picks block 1).
- `lavInspect(fit, "implied")` is a list with elements `within` and `<cluster name>` (here `id`), each with `cov` (and `mean` at level 2).
  Within-level matrices carry the observed variables of the model; any variable that exists only at level 2 is absent from `within`.
- Defined parameters: `lavaan` evaluates `:=` with the full vcov, so `diff` is already correct; medfit needs its own delta
  method only because the extractor builds `estimates`/`vcov` itself.
- Admissibility: `lavInspect(fit, "post.check")` was TRUE for the J = 20 observed-variable fit; for the latent
  fixture lavaan warned `some estimated ov variances are negative` (a Heywood case at level 2) while still reporting
  `converged = TRUE`. So `converged` alone is not an admissibility check; medfit must read `post.check` and the diagonal of each
  level's `theta`/`psi` itself. [run]

### 2.3 Independent oracle: the likelihood is simple enough to hand-build **[run]**

With balanced or unbalanced clusters, cluster j with n_j rows, observed vector y_ij in R^p, within covariance Sigma_W, between
covariance Sigma_B and mean mu:

```
-2 logL = sum_j [ n_j p log(2 pi) + (n_j - 1) log|Sigma_W| + log|Sigma_W + n_j Sigma_B|
                  + tr(Sigma_W^{-1} S_j) + n_j (ybar_j - mu)' (Sigma_W + n_j Sigma_B)^{-1} (ybar_j - mu) ]
```

where S_j = sum_i (y_ij - ybar_j)(y_ij - ybar_j)'. This is the standard closed form (Muthén 1994; McDonald and Goldstein 1989
for the balanced case; the unbalanced case needs one term per distinct cluster size, which lavaan and Mplus implement). The
implementation above took 8 lines of R and matched lavaan's `logLik()` on the unbalanced fixture, so a hand-built likelihood is
a feasible **independent oracle** that does not depend on lavaan's optimizer (it takes lavaan's *implied* Sigma_W and Sigma_B as
inputs; for a fully independent optimizer oracle the plan has the hand likelihood minimized with `optim`). The cost per
evaluation is O(J p^3), with at most one decomposition of Sigma_W and one per distinct cluster size, versus O(p^3) for the
single-level fit.

OpenMx 2.x is installed here; whether it can fit a two-level model with a cluster-level likelihood in this environment was
**not tested** [unverified]. The hand-built likelihood is the stronger oracle anyway because it is independent code.

### 2.4 lavaan limitations relevant to the plan

- Two-level models in lavaan: only **two** levels, Gaussian continuous or ordered/ML via `estimator = "ML"` or `"MLR"`; cluster
  covariates in the cluster-level model are allowed (variables observed only at level 2 appear as `w` level-2 columns).
- Random slopes: new in 0.7 (`rv()`), restricted; out of scope here (spec D7/D13 reasoning).
- Small J: a J = 20 unbalanced fit converged **[run]** with level-2 residual variances around 0.29 to 0.30 (positive); the
  literature warns that bias in level-2 estimates and non-convergence rise as J falls below roughly 50 to 100 (see 3).
- `Demo.twolevel` fits with cross-level equality constraints suppress level-specific fit statistics; the constrained *likelihood*
  is still fine.

## 3. Literature (all verified to exist by search on 2026-11-09)

Verification status: bibliographic metadata (journal, volume, pages) confirmed from at least one indexed source per item; full
texts were **not** all read. Claims about content below are limited to what abstracts or sources confirmed.

| Reference | Verified | Relevance |
|---|---|---|
| Preacher, K. J., Zyphur, M. J., and Zhang, Z. (2010). A general multilevel SEM framework for assessing multilevel mediation. *Psychological Methods, 15*(3), 209-233. doi:10.1037/a0020141 | yes | The MSEM framework for 2-1-1, 1-1-1 and 2-2-1 designs with within/between decomposition (abstract-confirmed) |
| Zhang, Z., Zyphur, M. J., and Preacher, K. J. (2009). Testing multilevel mediation using hierarchical linear models: Problems and solutions. *Organizational Research Methods, 12*(4), 695-719. doi:10.1177/1094428108327450 | yes | Why conflated single-slope a*b is biased; cluster-mean centering recommendation |
| Preacher, K. J., Zhang, Z., and Zyphur, M. J. (2011). Alternative methods for assessing mediation in multilevel data: The advantages of multilevel SEM. *Structural Equation Modeling, 18*(2), 161-182. doi:10.1080/10705511.2011.557329 | yes | Simulation evidence that MSEM has less bias and better CI coverage than two MLM approaches (2-1-1 designs; the 1-1-1 case with latent group means is discussed in the Preacher 2010/2011 line, not re-verified here) |
| Bauer, D. J., Preacher, K. J., and Gil, K. M. (2006). Conceptualizing and testing random indirect effects and moderated mediation in multilevel models. *Psychological Methods, 11*(2), 142-163. doi:10.1037/1082-989X.11.2.142 | yes | 1-1-1 with **random** slopes: E[a_j b_j] = ab + sigma_ab; marks the boundary of the fixed-slope scope |
| Muthén, B. O. (1994). Multilevel covariance structure analysis. *Sociological Methods & Research, 22*(3), 376-398. doi:10.1177/0049124194022003006 | yes | The between/within covariance decomposition and the ML objective |
| Liang, J., and Bentler, P. M. (2004). An EM algorithm for fitting two-level structural equation models. *Psychometrika, 69*(1), 101-122. doi:10.1007/BF02295842 | yes | Alternative estimation (EM) for unbalanced two-level SEM |
| Yuan, K.-H., and Bentler, P. M. (2007). Multilevel covariance structure analysis by fitting multiple single-level models. *Sociological Methodology, 37*, 53-82. doi:10.1111/j.1467-9531.2007.00182.x | yes | Two-step alternative, per-level fit assessment |
| Lüdtke, O., Marsh, H. W., Robitzsch, A., Trautwein, U., Asparouhov, T., and Muthén, B. (2008). The multilevel latent covariate model: A new, more reliable approach to group-level effects in contextual studies. *Psychological Methods, 13*(3), 203-229. doi:10.1037/a0012869 | yes (six authors) | Latent vs manifest cluster means; why the observed-mean (MMC) split is biased when clusters are small or ICC low |
| Rosseel, Y. (2012). lavaan: An R package for structural equation modeling. *Journal of Statistical Software, 48*(2), 1-36 | not re-searched (well known); lavaan's two-level options are documented at the lavaan tutorial page cited in #394 |
| Talloen et al. (2016) | already cited in the 2-1-1 spec and `REVIEW-multilevel-mediation-2026-09-25.md`; not re-verified here |

**Considered and dropped:** Lachowicz, Preacher and Kelley (2018) *A novel measure of effect size for mediation analysis*
(Psychological Methods) is real (verified) but concerns the upsilon effect size, not multilevel estimation; it is not needed for
this plan. McDonald and Goldstein (1989) was named from memory and **not verified** here; the plan does not rely on it (Muthén
1994 covers the same likelihood).

Not verified and therefore not relied on: Mplus-internal implementation details (Muthén and Asparouhov), sample-size rules of
thumb for J, and any claim that lavaan's two-level ML is identical to Mplus's (the hand-built likelihood match above is the
actual evidence).

## 4. How the Gaussian two-level likelihood is built

Observed vector y_ij = mu + y_B,j + y_W,ij with y_B,j ~ N(0, Sigma_B) independent of y_W,ij ~ N(0, Sigma_W).

1. **Cluster-wise sufficient statistics.** For each cluster: n_j, the mean ybar_j, and the within scatter matrix S_j. A fixed-slope
   model with only complete data needs nothing else (the likelihood depends on the data only through these), so the statistics
   are computed once and the optimizer touches O(distinct sizes + J) small matrices.
2. **Balanced clusters (all n_j = n).** The likelihood collapses to two Wishart-type pieces: a within part on the pooled within
   covariance S_PW = sum_j S_j / (N - J) with N - J degrees of freedom and a between part on the weighted covariance of the
   cluster means with J - 1 degrees of freedom and Sigma_W + n Sigma_B; this is why balanced two-level SEM is "two single-level
   fits" (Muthén 1994).
3. **Unbalanced clusters.** The between part has one term per cluster size because Sigma_W + n_j Sigma_B varies with n_j; the
   closed form in 2.3 is exact and needs no EM. Cost: one Cholesky of Sigma_W + n Sigma_B per **distinct** n_j.
4. **Model-implied matrices.** Sigma_W and Sigma_B each come from a RAM model (A_W, S_W and A_B, S_B), and mu from the level-2
   intercepts. This fits the existing `.sem_ram()` machinery: two RAM blocks stacked into one parameter vector, the objective
   being the sum of cluster-wise terms. Level-1 variables that are observed at both levels have both a within and a between
   column; variables measured only at level 2 appear in the between model only.
5. **Identification.** Each level is identified separately (marker or fixed latent variance per level; with shared loadings
   across levels the cross-level equality supplies extra df); an observed variable that exists at both levels needs both
   variance parts: a variable with zero between variance (ICC = 0) makes Sigma_B singular and the level-2 equations
   unidentified, which lavaan reports as non-positive-definite.
6. **Heywood risk and small J.** Level-2 residual variances are estimated from J cluster means, so they hit the boundary
   first. In the latent fixture lavaan reported negative ov variances with `converged = TRUE` **[run]**. The plan requires a
   per-level admissibility check, a bound or reference start for level-2 variances (the same device as in the #213 fix for the
   single-level nonlinear case) and a clear error or flag when a variance is non-positive.
7. **Cluster-mean quantities for identification of the within/between split of the observed X and M.** With observed X and M
   in the *joint* model, the "latent cluster mean" parameterization (Lüdtke et al. 2008) is what the joint ML implicitly uses
   (the between part is the latent cluster mean), which is the reason the joint ML is preferred over the manifest-mean
   centering that the 2-1-1 lmer route uses.
8. **Missing data.** Within-cluster FIML is not closed-form; lavaan handles it with per-pattern cluster-wise computations. Out of
   scope for slice 1 (the existing FIML machinery in `R/sem-fiml*.R` is single-level).
9. **Cluster-robust SE.** Under the correct model the observed/expected information from this likelihood already accounts for
   clustering. A sandwich with cluster scores would protect against non-normality only and needs the per-cluster score
   (a `-2 logL` gradient per cluster); the existing `R/sem-sandwich.R` is 42 lines and is observation-wise, so a
   cluster-score variant is new work.

## 5. Open facts to settle in the grill (not decided here)

1. Whether the first deliverable should be the adapter (cheap, wide value) or native estimation (hard, on-brand).
2. Class name and shape (plan section 3).
3. Contrast sign convention and whether `nie()` of the new class returns within, between or both.
4. Whether to put an early guard on `extract_mediation(<lavaan>)` for multilevel fits (verified silent wrong-level extraction in 1).
