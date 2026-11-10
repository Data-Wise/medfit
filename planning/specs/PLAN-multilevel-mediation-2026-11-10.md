# Plan: joint two-level mediation for 1-1-1 designs (issue #394)

**Date:** 2026-11-10 · **Status:** DRAFT for the maintainer; nothing implemented, no PR, nothing posted on the issue ·
**Issue:** [Data-Wise/medfit#394](https://github.com/Data-Wise/medfit/issues/394) ·
**Evidence:** [RESEARCH-multilevel-mediation-2026-11-10.md](RESEARCH-multilevel-mediation-2026-11-10.md) (read first; section numbers below refer to it) ·
**Predecessor:** 2-1-1 plan `PLAN-multilevel-mediation-2-1-1-2026-10-08.md` (module 1, shipped 0.6.0). This plan is **module 2**
and, by D1/D6/D15 of `GRILL-multilevel-mediation-ext-d-2026-09-25.md`, still needs its own grill before code.

## 1. Feasibility verdict

| Part | Verdict | Why |
|---|---|---|
| Adapter for fitted two-level lavaan models | **Cheap, low risk (M)** | lavaan 0.7.3 already returns the joint `vcov`, the level-keyed parameter table and `:=` contrast SEs; reproduced and matched to all printed digits (research 2.1). The work is keying by level, a new class, and a delta-method builder over the joint covariance |
| Early guard on `extract_mediation(<lavaan>)` for two-level fits | **Trivial (XS), do now** | today it silently returns a within-level `MediationData` with N = total rows (research section 1); a guard turns a wrong answer into an error |
| Native two-level ML (observed variables, fixed slopes, cluster ID) | **Hard but tractable (L)** | the likelihood is 8 lines of R and was matched to lavaan (research 2.3). Hard parts: stacking two RAM blocks into the existing parameter vector, level-specific gradients/information, identification, Heywood handling, optimizer files are high-risk |
| Latent mediators with cross-level shared loadings | **Hard (L on top)** | needs equality across levels in the constraint machinery plus a latent-level admissibility story; lavaan already shows Heywood cases |
| Missing data (FIML) inside clusters | **Blocked / defer (XL)** | `R/sem-fiml*.R` is single-level; pattern-wise cluster-wise likelihood is new theory and code |
| Cluster-robust (sandwich) SE | **Medium (M)** after native ML | per-cluster scores needed; `R/sem-sandwich.R` is observation-wise (42 lines) |
| Random slopes, non-Gaussian indicators | **Out** | Bauer et al. (2006): a_j b_j with random slopes has E = ab + sigma_ab, a different estimand; lavaan's `rv()` is new and restricted |

Nothing here is blocked by an external dependency. The one real blocker is process: module 2 has no grill, and the native
route changes optimizer files (section 7).

## 2. Recommendation (slice order)

1. **S0 guard** (now, own tiny PR): `extract_mediation()` on a lavaan fit with more than one level errors, pointing at the
   upcoming two-level adapter. No new class. *Effort: 0.5 day.*
2. **S1 grill + spec** (before any code): decisions in section 9. *1 session.*
3. **S2 adapter** `extract_mediation(<lavaan two-level>)` -> new class, effects, SEs, print/summary/tidy/confint. Oracle is
   lavaan itself (`:=` SE) plus the hand-built delta method and a nonparametric cluster-bootstrap check. *~5 to 7 days.*
4. **S3 oracle harness** (independent of lavaan's optimizer): hand-built cluster likelihood in `tests/testthat/helper-ml2.R`,
   minimized with `optim`, and a simulation helper with known truth. Built **before** any native estimator, as in the 2-1-1 plan.
   *~3 days.*
5. **S4 native two-level ML, observed variables, fixed slopes** (`fit_sem(model, data, cluster = "id")` with `level:` blocks).
   *~3 to 4 weeks including gates.*
6. **S5 latent mediators and shared loadings.** *~2 weeks.*
7. **S6 cluster-sandwich SE** and **S7 FIML** as separate, optional milestones (tracked in the issue as the issue itself
   proposes).

Why adapter first: it delivers the estimands and the joint-covariance contrast the issue asks for on day one, fits the issue's own
suggested first release, and builds the class, generics, docs and tests that the native route needs anyway. Risk: users may
treat the adapter as native support; the docs say lavaan does the estimation.

## 3. Class design

**Recommendation: a new S7 class `TwoLevelMediationData`** (working name; alternatives `MultilevelMediationData`,
`WithinBetweenMediationData`). Rejected: extending `ClusterMediationData` (D6; its validator, effect builders and
`decompose()` assume a single `a_path` and the cluster-level-treatment parameterization, and its `@vcov` is over alias rows
`a, c_prime, b_within, b_between`).

Properties (sketch):

| Property | Type | Notes |
|---|---|---|
| `a_within`, `b_within`, `c_within` | numeric scalar | level-1 paths X -> M, M -> Y, X -> Y |
| `a_between`, `b_between`, `c_between` | numeric scalar | level-2 paths; latent cluster means when estimated jointly |
| `estimates`, `vcov` | named numeric / matrix | **joint** covariance over the level-qualified paths, alias rows `a_w, b_w, c_w, a_b, b_b, c_b` (cross-level blocks kept, never zeroed) |
| `treatment`, `mediator`, `outcome`, `cluster` | character | latent mediator allowed (name of the factor) |
| `n_obs`, `n_clusters`, `cluster_sizes` | integer | as in `ClusterMediationData` |
| `source` | character | `"lavaan"` or `"native"` |
| `estimator`, `se_type`, `converged`, `admissible` | character/logical | `admissible` is **not** `converged`: reads post-check and level-specific variances (research 2.2) |
| `diagnostics` | list | per-level variance diagnostics, shared-loading flag, Heywood flag |
| `call`, `model`, `cluster_var`, `refit_args` | call / character / character / list | fit provenance for optional object-based refitting (bootstrap route 3); no raw data stored by default |
| `parameterization` | character | `"latent_cluster_mean"` (joint ML) vs a manifest-mean parameterization if a lavaan model used one |

Validator: finite paths; `vcov` symmetric PSD-ish with matching alias names; `n_clusters >= 2`; sum of `cluster_sizes` = `n_obs`.

`SEMFit` stays the container for the native route (`extract_mediation(<SEMFit>)` returns the new class, as it returns
`InteractionMediationData` for products today).

## 4. API

- **Effects (existing generics, new methods):**
  `nie(x, level = c("within", "between"))` (default: both, as a named numeric); `nde()`, `te()`, `pm()` per level;
  `decompose(x)` returns a `contrast` row = within minus between with the joint-covariance SE; `paths(x)` returns the six
  level-qualified paths. The contrast sign (within minus between, as in the issue) is a grill decision.
- **Inference:** a new `.effect_se()` gradient builder for the class in `R/effect-se.R`: gradient of `a_w b_w`, `a_b b_b`,
  `a_w b_w - a_b b_b` taken over the joint `vcov` (verified identical to lavaan's `:=` SE; research 2.1). `tidy()`, `confint()`,
  `summary()`, `print()` follow the existing pattern (`R/methods-tidy.R`, `R/methods-base.R`).
- **Bootstrap (revised after adversarial review).** `bootstrap_mediation()` is *not* object-based: it takes a `statistic_fn`
  callback, raw `data` and `cluster = "<column>"` (nonparametric resampling draws whole clusters and gives each draw a fresh
  cluster id, so a cluster drawn twice is refit as two clusters; `R/bootstrap.R:251`, doc lines 32-36). The new class stores
  neither data nor a refit recipe, so `bootstrap_mediation(x, cluster = ...)` does **not** work and is not promised. S2 ships:
  1. **Callback route (S2, documented recipe + helper).** `bootstrap_mediation(statistic_fn, method = "nonparametric",
     data = d, cluster = "id")` with `statistic_fn(data)` refitting the two-level lavaan model and returning
     `nie(extract_mediation(fit, ...), level = )` or the contrast. The recipe lives on the model page and in the cookbook;
     an internal helper `.two_level_refit_stat(model, treatment, mediator, outcome, effect)` builds the closure so users do not
     hand-write it.
  2. **Parametric route.** `bootstrap_mediation(mediation_data = x, method = "parametric")` draws from the joint `@vcov`; needs a
     branch for the new class (check in S2 how `.bootstrap_parametric()` reads the object; if it only knows the existing
     classes, add the branch). Its draws keep the cross-level covariance.
  3. **Object-based refitting (optional, S2b or with S4).** The class retains *fit provenance*: `@call` (the `extract_mediation`
     call), `@model` (lavaan or medfit syntax string), `@cluster` (column name), `@refit_args` (estimator, `se`, constraints) and,
     for the adapter, a reference to the raw data only when the user passes `data =` (never silently pulled from the lavaan
     object). With provenance, a `source_fit =`-style route (precedent: the FIML `source_fit` route, `R/bootstrap.R:264`) can
     refit without a callback. Decision for the grill (question 12); until it is taken, only routes 1 and 2 exist.
  Test (required, through the exact public call): `bootstrap_mediation(statistic_fn, method = "nonparametric", data = d,
  cluster = "id", seed = s, n_boot = B)` where `statistic_fn` records, per refit, the number of distinct cluster ids and the
  row count, with a seed that draws at least one cluster twice (asserted from the recorded sizes: some refit data have more rows
  than a draw of J distinct clusters would allow only if relabeling failed). Assertions: every refit sees J distinct ids;
  the duplicated cluster appears as two clusters; the bootstrap SE of the contrast is within Monte Carlo error of the
  hand-built delta-method SE. Planted defect: mock the relabel helper (`.relabel_clusters()`, the 2-1-1 plan's P2 device) to
  the identity and require the test to fail (duplicated ids collapse into one larger cluster, the refit sees fewer clusters).
- **Entry points:**
  - S2: `extract_mediation(<lavaan>, treatment, mediator, outcome)` detects a two-level fit (`lavInspect(fit, "nclusters")`
    non-null / two blocks) and builds the class; no new arguments except optional `level_names`.
  - S4: `fit_sem(model, data, cluster = "id", ...)` accepts `level:` blocks only when `cluster` is given;
    `fit_mediation(engine = "native", model = , cluster = )` forwards; the error message in `R/sem-fit.R:97` becomes the
    "cluster missing" message when `cluster` is absent. `fit_mediation(formula-based, engine = "lmer")` is unchanged (it is the
    2-1-1 route).
- **Syntax:** reuse the existing parser (`level: <int>` is already parsed into `parameters$level`). Grill: whether to add
  lavaan-style cross-level label sharing (`l2*m2` repeated) as the shared-loading mechanism (the parser already supports
  shared labels within a level; across levels it needs the constraint step to treat labels globally).

## 5. Native two-level estimation (S4/S5) sketch

1. **Variable sets (revised after adversarial review).** Not one observed vector for everyone. Partition the model's observed
   variables into `W` (measured at level 1: have a within part and a between part; p_w of them) and `Z` (cluster-only: constant
   within every cluster, no within covariance row or column; q of them). Detection: a variable is in `Z` iff it is constant
   within every cluster **and** appears only in `level: 2` rows (error if it appears in a `level: 1` row; error if a `W`
   variable is accidentally constant). Per cluster j the statistics are n_j, the mean ybar_j and scatter S_j of the **W**
   columns, and z_j (one value) for `Z`. `.sem_sample_ml2()` returns these per distinct cluster size. Listwise deletion only
   (FIML out).
2. **Likelihood with separate sets.** With Omega_j = [[Sigma_W/n_j + Sigma_B,WW, Sigma_B,WZ], [Sigma_B,ZW, Sigma_B,ZZ]], b_j = (ybar_j, z_j) and mu = (mu_W, mu_Z):
   `-2 logL = sum_j [ (n_j - 1)(p_w log 2pi + log|Sigma_W|) + tr(Sigma_W^-1 S_j) + (p_w + q) log 2pi + log|Omega_j|
   + (b_j - mu)' Omega_j^-1 (b_j - mu) + p_w log n_j ]`. The `p_w log n_j` term is the Jacobian of the raw-rows to
   (mean, deviations) change of variables; it involves only `W` (cluster-only variables have no rows to transform). With q = 0 this
   equals the formula of research 2.3 exactly. **Verified numerically** (research 2.5). Cluster-only covariates enter only through
   Omega_j: they add rows/columns to the between block, have no within variance, and their between-level paths
   (`m ~ z`, `y ~ z` at level 2) live in `A_B`, `S_B`. Two RAM blocks: `A_W, S_W` over `W`; `A_B, S_B` over `W` and `Z`; the
   union is the parameter vector. Unbalanced clusters: one Cholesky of Omega_j per distinct n_j (the covariance depends on n_j only
   through Sigma_W/n_j).
3. **Gradients/information:** analytic gradient by the chain rule through Sigma_W and Sigma_B (reuse `.sem_dsigma()`); information by the
   existing observed/expected paths in `R/sem-ml.R`, with the two-level Hessian block structure. Finite-difference Hessian
   (as in the mean-structure centered coordinates) is the fallback and the oracle for the analytic one.
4. **Optimizer:** the existing SLSQP pipeline and acceptance gate (`R/sem-optim.R`, `R/sem-constraints.R`) apply unchanged in
   structure; new work is level-2 variance floors/reference starts (Heywood, research 4.6) and the exact zero-product branch
   handling for `a_w*b_w == 0` / `a_b*b_b == 0` (reuse `.sem_fit_branches()` per level).
5. **Cross-level joint covariance:** from the joint information inverse (`R/sem-se.R`); the contrast uses the joint block.
6. **Ledger and diagnostics:** extend the outcome ledger (`R/sem-outcomes.R`) with per-level admissibility; `glance()` reports
   df, the total logLik, N, J and the cluster-size range.
7. **Cluster-robust SE (S6):** per-cluster score vectors from the same likelihood; the sandwich replaces
   `.sem_sandwich()` for two-level fits only.
8. **FIML (S7):** separate track; not designed here.

What stays out: random slopes, non-Gaussian indicators, three or more levels, categorical/ordinal outcomes, X-by-M products at
either level (D13-style guard: refuse with a classed error), multigroup two-level, level-specific fit indices beyond the
global chi-square.

## 6. Tests and oracles

| Test | Oracle | Why it can fail |
|---|---|---|
| Hand-built likelihood equals lavaan `logLik()` and medfit's `-F` | the closed form with **separate W and Z sets** (section 5 item 2; research 2.3 and 2.5) on balanced and unbalanced fixtures, **with and without a cluster-only covariate** (`z` constant within clusters, `m ~ z` and `y ~ z` at level 2). Without Z the absolute value must match lavaan; with Z the objective must match lavaan up to the parameter-free constant of research 2.5 and ΔlogL between nested fits must match lavaan exactly | any term error (missing (n_j - 1) log\|Sigma_W\|, wrong n_j, a within row for Z, a dropped p_w log n_j) breaks it |
| Path estimates and joint `vcov` equal lavaan's to 1e-6 (est) / 1e-3 relative (SE) | lavaan two-level raw-data fits: balanced n = 5, unbalanced n in 2..9, J = 100 and J = 40 | frozen SLSQP fixtures are pinned at 1e-6 (memory: `frozen-slsqp-fixtures-need-1e-6`) |
| **Nonzero cross-level covariance fixture** | observed model gives small but nonzero cross-level entries (e.g. `Cov(aw, ab) = -0.00076` balanced, research 2.1); latent shared-loading fixture gives correlations -0.07 and -0.11. The plan's fixture is seeded so that `abs(Cov(a_w, a_b)) > 1e-4`, asserted in the test | planted defect: zero the cross-level block of `vcov` and require the contrast SE to differ (the SE gap must exceed a stated threshold) |
| Contrast SE equals `sqrt(g' V g)` and lavaan's `:=` SE (matched to 8 digits in 2.1) | lavaan `:=`; hand delta method; nonparametric cluster bootstrap (n = 1000) within MC error | planted defect: gradient with a sign error on one path |
| Shared loadings across levels | lavaan with the same labels; equality of the two loading vectors at the solution to 1e-8 | defect: unshared loadings |
| Heywood / inadmissible | a seeded latent fixture where lavaan reports negative ov variance with `converged = TRUE`; medfit must report `admissible = FALSE` | defect: using `converged` only |
| Cluster-only covariate fixture (S3, before S4) | built in `helper-ml2.R`: J = 120, n_j in 2..9, `z` between-only, nonzero `Cov(z, x_B)`; oracle = hand likelihood minimized with `optim` and lavaan; paths and joint vcov to 1e-6 / 1e-3 | planted defect: give `z` a within variance row; or drop the Omega_j `Sigma_B,WZ` block. Either must fail |
| Unbalanced vs balanced | the two code paths agree when all n_j are equal (a balanced fit run through the unbalanced code) | defect: n_j replaced by the mean size |
| Independent optimizer oracle | `optim` on the hand-built likelihood | guards against a shared bug with lavaan's optimizer |
| Guards | `level:` without `cluster`; cluster var missing; J < 2; ICC = 0 variable; X-by-M product; non-Gaussian | classed errors |
| Simulation gates (S3/S4) | coverage of the within, between and contrast CIs at J in {20, 50, 100}, n in {5, 20}; reliability cell; tolerances frozen before the run | registered in `tests/sim/gates.csv` (`oracle`, `mutants` columns) and `tests/sim/structures.csv` |
| OpenMx cross-check | **not planned**: two-level OpenMx fitting was not tested here (research 2.3) |  |

The adapter (S2) needs only the lavaan, hand-delta and bootstrap rows (the bootstrap row includes the duplicate-cluster test through the public call, section 4); the likelihood and optimizer rows belong to S3/S4.

## 7. Risk tier and admission checklist

- **S0/S2/S3:** touch `R/extract-lavaan.R`, `R/classes.R`, `R/effect-se.R`, generics, methods, docs, tests; **none of the files in
  `tests/sim/risk-files.txt`** (`R/sem-ml.R`, `sem-model.R`, `sem-constraints.R`, `sem-optim.R`, `sem-parse.R`, `sem-fit.R`,
  `tests/sim/gates.csv`, `R/fit-sem.R`, `R/sem-fiml.R`, `R/sem-fiml-interface.R`). Normal tier: standard PR checks.
- **S4/S5:** necessarily edit `sem-ml.R`, `sem-model.R`, `sem-optim.R`, `sem-fit.R`, `fit-sem.R`, and probably
  `sem-parse.R` and `sem-constraints.R` (parameter vector, objective, solver path): **high-risk**. The PR body must carry the
  seven-item admission checklist, each ticked or `n/a: <reason>`: independent oracle (hand-built likelihood), reliability
  cell, planted defect, metamorphic invariance (cluster relabeling and row reordering must not change anything; adding a
  constant to a variable moves only intercepts), fault injection, registration (`gates.csv` row with `oracle` and `mutants`;
  `structures.csv` row), platform run on the OpenBLAS runner (memory: `gates-runner-uses-openblas`). `test-gate-coverage.R`
  fails if a structure has no gate. `qc-monthly` will pick up the new gate.
- **Release:** S2 can ship as a minor release alone. S4 should wait for a release with the OpenBLAS gate green (main-only
  expensive CI per `CLAUDE.md`).
- **Agent harness:** plan-task work goes through the `medfit-orchestrator` skill (implementer in a worktree, `medfit-oracle-qa`,
  `medfit-gates`, `medfit-docs`).

## 8. Docs

- Model page "Multilevel mediation (1-1-1)" in the Models menu (landing page, index, menu; `test-model-pages*.R` enforces
  the listing), including: within vs between indirect effects, the contrast, what the adapter does vs the native engine,
  admissibility and small-J warnings, and a link to the 2-1-1 page.
- Cookbook recipe(s) (observed two-level; latent shared loadings), refcard entry for each new export and the class
  (`test-refcard-coverage.R`), `methods.qmd` formulas (likelihood, delta method with the joint covariance, contrast),
  `?"medfit-syntax"` table row for `level:` and `cluster =`, NEWS, `.STATUS`, roadmap line replaced.
- Each error message the new page quotes needs a test that triggers it (house rule, `test-guide-*.R`).
- Cross-references to `ClusterMediationData` and the lavaan comparison article (`test-lavaan-comparison.R`).

## 9. Open questions for the maintainer (grill agenda)

1. **Order:** adapter first (recommended) or native first? Is a lavaan-dependent first release acceptable to the ecosystem
   (lavaan is Suggests; the native engine avoids that)?
2. **Class:** new `TwoLevelMediationData` (recommended) vs another name; one class for both lavaan and native sources (recommended)?
3. **Estimand definition:** the within indirect effect a_w b_w is defined **conditional on the random-intercept structure with
   fixed slopes**; the between effect uses *latent* cluster means (joint ML). Is that the intended default, and should
   a manifest-mean option (lmer-style centering, as in the 2-1-1 route) also be offered for comparison?
4. **Contrast** sign and name (`within - between`, as in the issue) and whether `nie()` returns both levels by default.
5. **Scope guard:** refuse X-by-M products at both levels in slice 1 (recommended, as D7/D13 did)?
6. **Missing data:** is listwise deletion inside clusters acceptable for the native route until a FIML milestone? The issue
   itself defers it.
7. **Small J:** what minimum number of clusters triggers an error vs a warning (the 2-1-1 plan used a warning threshold in the
   spec); research 4.6 suggests warnings below about 50 and an error below about 10. Needs a stated, evidence-backed rule.
8. **Heywood policy:** flag-only (`admissible = FALSE` with a warning) or classed error (the dropped-zero-product branch is an
   error per ADR D-11)? Recommendation: error from `fit_sem()`, flag from the adapter (the adapter reports someone else's fit).
9. **S0 guard:** ship the `extract_mediation(<lavaan>)` guard immediately, independent of the grill? (A silent wrong-level
   extraction is a correctness bug; the CLAUDE.md "correctness fixes" exemption from the deprecation period applies.)
10. **Release target** and whether this displaces the FIML admission work currently queued (`planning/PLAN-FIML-statistical-admission-2026-11-01.md`).
11. **Bootstrap API:** callback + parametric only (recommended for S2) or also object-based refitting through retained provenance (route 3)?
    Storing the model string and refit arguments is cheap; storing data is a memory and privacy decision.
12. **logLik convention with cluster-only covariates:** lavaan's reported `logLik()` differs from the exact Gaussian density by a
    parameter-free constant (170.5453 in the fixture, identical for two nested fits; research 2.5). Which convention does medfit
    report (recommended: the exact density, documented, with absolute AIC/BIC not comparable to lavaan when cluster-only variables
    are present)?
13. **Cluster-only covariate detection:** automatic (constant within clusters and only in `level: 2` rows) or declared (a `between =`
    argument)? Recommended: automatic with an error on any ambiguity.
14. **Effort and sign-off:** the estimates below are single-developer-with-agents; confirm they fit the roadmap.

## 10. Effort summary

| Slice | Content | Estimate | Risk tier |
|---|---|---|---|
| S0 | lavaan two-level guard | 0.5 day | normal |
| S1 | grill + spec | 1 session | n/a |
| S2 | adapter, class, generics, methods, docs | 5-7 days | normal |
| S3 | oracle harness (incl. cluster-only covariate fixture) and simulation helpers | ~3-4 days | normal (tests/sim only) |
| S4 | native observed-variable two-level ML, `cluster =`, gates | 3-4 weeks | **high** |
| S5 | latent mediators, shared loadings | ~2 weeks | high |
| S6 | cluster sandwich | ~1 week | high |
| S7 | FIML in clusters | unscoped (XL) | high |

Total to the issue's first scope (S0-S5): roughly 7 to 9 weeks; the adapter alone (S0-S3) delivers the estimands in about two
weeks.

---

## Draft comment for issue #394 (NOT posted; needs the maintainer's go-ahead)

> Thanks for the detailed request. I looked at what is in place and at what lavaan 0.7.3 returns for two-level fits.
>
> **State today.** 2-1-1 (cluster-level treatment) shipped in 0.6.0 as `ClusterMediationData`; 1-1-1 was deferred as "module 2" and has no spec yet. The native fitter still refuses `level:` blocks (`R/sem-fit.R`). Separately, `extract_mediation()` on a two-level lavaan fit currently returns a single-level `MediationData` built from the within block without any warning; I plan to turn that into an error first.
>
> **What lavaan gives.** On balanced and unbalanced simulated clusters, and on `Demo.twolevel`, lavaan returns the full joint `vcov` over level-qualified paths with nonzero cross-level entries, and its `:=` contrast SE for `a_w*b_w - a_b*b_b` equals the delta-method SE from that joint covariance to 8 digits. The two-level Gaussian likelihood (cluster-wise sufficient statistics) also reproduces lavaan's `logLik()` from a short hand-built formula, which gives an independent oracle for a native fit.
>
> **Proposed order.** (1) a guard on the lavaan extractor; (2) an adapter for fitted two-level lavaan models returning a new class with level-qualified paths, the joint covariance and the within, between and contrast effects; (3) an oracle harness; (4) native two-level ML for observed variables with `fit_sem(..., cluster =)`; (5) latent mediators with shared loadings; FIML and cluster-sandwich SEs stay later milestones, random slopes and non-Gaussian indicators stay out. The plan and the evidence are in `planning/specs/`.
>
> A few decisions need your input before code: class name and shape, the contrast sign, whether to refuse X-by-M products in the first slice, the small-J policy, and whether listwise deletion is acceptable until FIML.
