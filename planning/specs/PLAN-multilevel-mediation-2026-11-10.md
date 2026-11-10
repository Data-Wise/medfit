# Plan: joint two-level mediation for 1-1-1 designs (issue #394)

**Date:** 2026-11-10 · **Status:** DRAFT, revision 4 (Fable review + grill decisions folded in, section 0 controls); nothing implemented, no PR, nothing posted on the issue ·
**Issue:** [Data-Wise/medfit#394](https://github.com/Data-Wise/medfit/issues/394) ·
**Evidence:** [RESEARCH-multilevel-mediation-2026-11-10.md](RESEARCH-multilevel-mediation-2026-11-10.md) (read first; section numbers below refer to it) ·
**Predecessor:** 2-1-1 plan `PLAN-multilevel-mediation-2-1-1-2026-10-08.md` (module 1, shipped 0.6.0). This plan is **module 2**
and, by D1/D6/D15 of `GRILL-multilevel-mediation-ext-d-2026-09-25.md`, still needs its own grill before code.

## 0. Revision 4 (controlling): Fable 5.2 adversarial review and the 11 grill decisions

**Precedence.** Where this section and a later section disagree, **this section wins**; the superseded text is marked
`[superseded by section 0]` where it was edited. Sources: the maintainer's grill ledger
(`planning/GRILL-multilevel-mediation-2026-11-10.md` on branch `claude/restore-b0bd19`, Q1-Q11, every recommended option
accepted) and the Fable review scripts `e1.R`, `e2.R`, `e3.R`, all re-run here on lavaan 0.7.3 (results in research 2.6). The
companion `LIT-multilevel-mediation-2026-11-10.md` is **not present** in that worktree (only the grill ledger is), so its
findings are used here only as summarized in the ledger.

### 0.1 Grill decisions folded in (Q1-Q11, closed)

Q1 adapter first (guard, then adapter with the new class; native later). Q2 one `TwoLevelMediationData` for the adapter and the
later native fitter, with a `source` property. Q3 estimand: `a_w b_w` conditional on fixed slopes (`sigma_ab = 0` stated),
latent cluster means for the between effect, manifest-mean option as a labeled alternative. Q4 contrast `within - between`,
**descriptive** (delta method over the joint covariance), not a test; **`nie()` returns the within effect by default** and
`level =` selects `"between"`, `"contrast"` or both (this replaces section 4's "classed error when `level` is missing"
[superseded]). Q5 refuse treatment-by-mediator products at both levels (classed error). Q6 adapter passes lavaan's
`missing = "fiml"` through; native is listwise with loud row and cluster counts. Q7 small J: warn below 50 clusters, error
below 10, constants editable, **but see 0.4: the adapter never errors on J**. Q8 Heywood: native `fit_sem()` errors (classed,
ADR D-11); adapter flags `admissible = FALSE` with a warning. Q9 S0 guard ships now as its own PR. Q10 guard now, adapter in
the next minor, native later, does not displace FIML admission. Q11 bootstrap (a): scalar `statistic_fn` callbacks in the public
calls, a helper that builds the within, between and contrast callbacks, end-to-end tests of the exact calls incl. duplicate-cluster
resamples; object-based dispatch (b) deferred (S2c). Consequences added to the S2 oracle list: lavaan `se = "robust.huber.white"`,
`missing = "fiml"` and lavaan's cluster bootstrap, as exposed options and as oracles. Shared loadings across levels (Jak et al.)
stay a testable restriction, not a default.

### 0.2 Review findings and what the re-run showed

| # | Finding | Severity | Reproduced? | Change in this plan |
|---|---|---|---|---|
| 1 | Between effect and contrast unidentified when X is cluster-mean centered or randomized within | HIGH | **Yes.** Centered X: `converged` TRUE, `ab` 0.000 with SE NA, `cb` SE 1406, vcov "not positive definite" warning. Between SD of X 0.05: `converged` TRUE, `post.check` TRUE, `ab` SE 0.731 (true value 0.7). Raw X with true between variance 0: `converged` FALSE and `bb` -36 | 0.3 |
| 2 | Detection must use `nlevels`, not `nclusters`; S0 guard must cover `ngroups > 1` | HIGH | **Yes.** A `cluster=` single-level fit has `nlevels` 1 and `nclusters` 1 (so does a no-cluster fit; the old rule "`nclusters` non-null" fires for everything). Multigroup single-level fit: `extract_mediation()` returns group 1 (a = 0.451) with `n_obs` = total 500. lavaan itself refuses multigroup plus multilevel in one model, so `nlevels > 1` and `ngroups > 1` never co-occur | 0.3, S0 spec |
| 3 | Same label at both levels is a silent equality constraint; vcov has duplicate column names | HIGH | **Yes.** `m ~ a*x` at both levels: one value reported twice (`a` 0.367 at both levels), `colnames(vcov)` contain `a b cp` twice; the current extractor returns `MediationData` with a = 0.367 | 0.3 |
| 4 | Planted defect "zero the cross-level block" cannot fail on the contrast SE | HIGH | **Yes.** Zeroing the cross-level block moves the contrast SE from 0.1954 to 0.1945 (0.48%), under bootstrap MC error. For `a_w - a_b` the gap is 5.6% (0.1898 vs 0.1792), and the entry `Cov(a_w, a_b)` = -0.00195 is asserted directly | 0.5 |
| 5 | `fixed.x` / information conventions and optimizer error | HIGH | **Yes.** lavaan defaults `fixed.x = TRUE` (between-level `x ~~ x` is `free = 0`); estimates differ from `fixed.x = FALSE` by about 5e-5, SEs by 3-4% (`se(ab)` 0.166 vs 0.172); lavaan's default optimizer is about 1e-5 away from the closed form (`bb` -0.000498 vs closed form -0.000508); a tight-tolerance run warns "solution has NOT been found". Default information is `observed` with `h1.information` `structured`; expected and observed `diff` SEs differ by 5e-7 here | 0.5 |
| 6 | Oracle circularity | MEDIUM | Reasoned, not re-run beyond item 5's closed form (which reproduces) | 0.5 |
| 7 | Contrast semantics and `standardized = TRUE` | MEDIUM | **Yes.** `standardizedSolution()` standardizes per level (`ab` 0.670 vs raw 0.690), so an extractor `standardized = TRUE` (`R/extract-lavaan.R:124`) would mix scales | 0.6 |
| 8 | Small J | MEDIUM | **Yes.** J = 20, n = 5 (300 reps): `post.check` TRUE in 73% (27% fail), 295/300 usable, `ab` 95% CI coverage 0.908; J = 50: `post.check` 98%, coverage 0.953-0.970 (the J = 20 `fixed.x = FALSE` row did not finish in the run, since the script ends there) | 0.4 |
| 9 | Drift and omissions | MEDIUM | `R/sem-parse.R:323` regex `^level\s*:\s*[0-9]+$` rejects `level: within`; **not reproduced as a lavaan claim**: lavaan accepts `level: within` and `level: between` (converged), and also a level named like the cluster variable (`level: id`) in a test here. Risk-files lists differ: `claude/restore-b0bd19` lacks `R/sem-fiml.R` and `R/sem-fiml-interface.R`, `origin/dev` has them (use `origin/dev`'s) | 0.7 |

Not reproduced: nothing in the review was refuted. Two details I could not check: the review's claim about `fixed.x` SE gaps at the 3-4% level matched (`se(ab)` 3.4%); the "27% at J = 20" matched (0.73). The Mplus and brms comparators below were not run (no Mplus; brms two-level SEM is not a comparator for ML joint covariance).

### 0.3 Adapter specification changes (S0 and S2)

- **Detection.** `lavInspect(fit, "nlevels") > 1` identifies a two-level fit. `nclusters` and the block count are not used (both are 1 for
  `cluster=` single-level fits). Regression test: a `cluster = "id"` single-level fit must still extract (it is a legitimate
  cluster-robust single-level fit) and a true two-level fit must not.
- **S0 guard** errors (classed) on `nlevels > 1` **or** `ngroups > 1`, with distinct messages: a two-level fit points at the
  coming adapter; a multigroup fit says medfit does not extract per-group results yet (today it silently returns group 1 with the
  total N). The S0 implementer has been told.
- **Keying.** Paths are found from `parTable()` with `level`/`block` as part of the key and vcov rows by **free-parameter index**,
  never by label or column name (duplicate names are possible, finding 3). Planted defects: swap levels (`ab` read as `aw`);
  group-1/level-1 mis-keying on an unlabeled model; a mismatch of the `.l2` suffix.
- **Cross-level equality.** From the parameter table, detect any free index shared by a within and a between parameter (same label at
  both levels, or an explicit `==`). The class records `cross_level_equal` (the equated path names). A path equated across levels is reported
  as such; a **contrast that is identically zero by constraint is reported `NA` with a classed message, not `0 +/- 0`**.
  Within and between effects keep their SEs from the free-index vcov.
- **Degenerate between X (and M).** The adapter computes per level, for X and M, the between variance share (ICC-type ratio
  `Sigma_B / (Sigma_B + Sigma_W)` from the implied matrices) and the between SD, and sets `between_identified`:
  FALSE if an ICC is below 0.01, a between SE is `NA`, the vcov is not positive definite, or `converged` is FALSE; a softer warning
  band for an ICC below 0.05 (the 0.05 SD case above has `post.check` TRUE yet SE 0.731, so `post.check` is not enough).
  **The class is within-only-capable**: when `between_identified` is FALSE the between paths, `nie(level = "between")` and the
  contrast are `NA_real_` and signal a classed condition (`medfit_between_unidentified`); within effects and their SEs remain.
- **`standardized = TRUE` refuses** for a two-level fit with a classed error (lavaan standardizes per level, so mixing is wrong).
- **fixed.x and information are stored** on the class (`fixed_x`, `information`, `h1_information`, `se_type`) and printed in
  `summary()`; the adapter reports the fit it was given and does not refit.
- **Missing data.** `missing = "fiml"` fits pass through; `n_obs` and cluster counts come from `lavInspect(fit, "nobs")`/`"nclusters"` on the fitted object
  (FIML keeps 500 rows and 100 clusters where listwise keeps 416 and 99 in the review fixture).
- **Defined-parameter interplay.** The contrast is `a_w b_w - a_b b_b`. Its null is `a_w b_w = a_b b_b`; it is degenerate (zero
  gradient) when all four paths are 0, and in practice it is a noisy between-vs-within comparison dominated by the between SE (SE 0.195 vs
  0.025 in the review fixture). Documented as descriptive (Q4).
- **`pm()` and `te()`** are defined per level: `te(level = w) = a_w b_w + c_w`, `te(level = b) = a_b b_b + c_b`,
  `pm = nie / te` per level; no cross-level total or proportion.

### 0.4 Small J: warning versus error

The adapter never errors on J (it reports someone else's fit): it warns, citing admissibility, below 50 clusters, with the J = 20
evidence above (27% `post.check` failures, coverage 0.908). The **error below 10 clusters applies to the native route only**
(Q7/Q8 reconciled).

### 0.5 Tests, oracles and tolerances (replaces the 1e-6 / 1e-3 tolerances in section 6 [superseded])

- **Tolerances scale by SE.** Estimates: `|diff| <= 0.01 * SE` and at least 1e-4 absolute against lavaan (observed gaps: 5e-5 vs
  SE 0.17); against a closed form the gap floor is lavaan's own optimizer error (about 1e-5), so the oracle for the *adapter's
  arithmetic* uses the lavaan fit's own numbers (exact to 1e-10) and the oracle for lavaan itself uses SE-scaled tolerances.
  SEs: 1e-3 relative **only** against `fixed.x = FALSE` at the same information; against a default (`fixed.x = TRUE`) fit the
  documented gap is 3-4% by design and is *not* a tolerance.
- **Native comparison convention.** Native fits are compared with lavaan `fixed.x = FALSE` (full ML, no fixed between moment) until the
  second grill defines a two-level fixed-moment convention (0.8, question 2).
- **Independent oracles added to S2 (not only lavaan):** the balanced saturated closed form (`Sigma_W = S_PW`, `Sigma_B = (S_B - S_PW)/n`;
  verified here to 1e-5 against lavaan) for a balanced saturated model; `lm()` on cluster-centered data for the within paths and
  `lm()` on cluster means for a manifest between check (labeled approximate); lavaan `se = "robust.huber.white"`, `missing =
  "fiml"` and its cluster bootstrap as exposed options; lme4 (`lmer` with the within and between terms) as a point-estimate comparator for the
  manifest-mean parameterization only (2-1-1 machinery), because it yields no cross-level covariance. Mplus and brms comparators
  are **not planned**: Mplus is unavailable here and brms does not give the ML joint covariance; the grill may reopen this.
- **S3 hand-built likelihood is scheduled before S2 merges** (it can be written while S2 is in review), so the adapter is not validated
  only against the software it wraps.
- **Planted defect for cross-level covariance (corrected).** Assert the vcov entries directly (`Cov(a_w, a_b)` = -0.00195 in the fixture is
  nonzero and must be carried through to `@vcov`); and use a functional where the block matters, `a_w - a_b` (SE 0.1898 joint vs 0.1792
  with the block zeroed, 5.6%), as the delta-method check. The contrast `a_w b_w - a_b b_b` (0.48%) and the bootstrap are sanity checks only.
- **Further planted defects:** level swap; group-1/level-1 mis-keying on unlabeled models; `.l2` suffix mismatch; same-label-at-both-levels read as a
  free contrast; `post.check`-only admissibility (the SD 0.05 fixture must be flagged).
- **Additional tests:** the three degenerate-X fixtures of finding 1 (centered, SD 0.05, within-randomized) returning within-only results with the
  classed condition; the `nlevels`/`ngroups` guard; `standardized = TRUE` refusal; `cross_level_equal` fixture; `test-dependents-contract.R` updated
  (a new class is not a `MediationData` for probmed and RMediation: document and test that they error cleanly or are unaffected, and add the class to the
  contract table); `NEWS.md` and the version bump (a new exported class and `extract_mediation()` behavior change: minor version, behavior-change note,
  as the CLAUDE.md correctness exemption requires).

### 0.6 Parser note

`R/sem-parse.R:323` accepts only `level: <integer>`, while lavaan also accepts `level: within`, `level: between` and a level named like the
cluster variable (verified here). The native route needs a decision before S4 (accept the lavaan names, or document integer-only).

### 0.7 Slice verdicts (after the review)

| Slice | Verdict | Condition |
|---|---|---|
| S0 guard | **GO** | `nlevels > 1` or `ngroups > 1`; regression tests of 0.3 |
| S1 grill | **REOPEN** | second grill below (0.8) |
| S2 adapter | **conditional GO** | after findings 1-6 are in the spec (0.3, 0.5); **budget 8-12 days** (the 2-1-1 module took five PRs) |
| S3 oracle harness | **GO** | closed-form oracle scheduled with S2 (before S2 merges) |
| S4 native observed ML | **NO-GO as written** | until tolerances (0.5) and the `fixed_x` convention (0.8) are defined |
| S5 latent mediators, shared loadings | **NO-GO** | until the identification literature (Jak et al.; Heywood evidence) is read |
| S6, S7 | unchanged | later milestones |

### 0.8 S1 second grill: four undecided items (recommendation first)

1. **Degenerate between X (or M).** *Recommendation: return a within-only result with `between_identified = FALSE`, `NA` between
   paths and contrast and a classed condition (`medfit_between_unidentified`), triggered by an ICC below 0.01, an `NA` between SE, a non-PD vcov or
   non-convergence; a warning band at ICC below 0.05.* Alternative: always error (loses the valid within effects, and a fit with
   `post.check` TRUE and SE 0.731 would still slip through at 0.05). Evidence: three fixtures in 0.2 row 1.
2. **`fixed.x` convention, adapter and native.** *Recommendation: the adapter reports the lavaan setting it was given and stores
   it; native two-level defaults to `fixed_x = FALSE` (full ML, comparable with lavaan `fixed.x = FALSE`) until a fixed-between-moment convention is
   derived and has an oracle; the docs state that contrast SEs from a `fixed.x = TRUE` fit are conditional-on-X and 3-4% narrower for the between
   paths.* Alternative: mirror lavaan (`fixed.x = TRUE` default) in native, which makes native and lavaan agree by default but ties medfit to
   lavaan's undocumented between-moment choice.
3. **Cross-level label policy.** *Recommendation: detect cross-level equality from the parameter table (shared free index), record
   `cross_level_equal`, report the contrast as `NA` (constrained), keep within and between effects and key vcov rows by free index.* Alternative: refuse any
   cross-level shared label (simpler, but blocks the legitimate shared-loading case of S5, where sharing is intended).
4. **`standardized = TRUE`.** *Recommendation: refuse for two-level fits with a classed error.* Alternative: standardize each level with
   its own SDs and label the result "level-specific", which is a new estimand with no oracle in this plan.

---

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

- **Effects (existing generics, new methods; revised against `R/generics-effects.R`).** `nie()`, `nde()`, `te()`, `pm()` are
  documented to return a **scalar** of class `mediation_effect` with a `type` attribute (`.glance_*` reads `unclass(nie(x))[[1]]`),
  so the new methods keep that contract: `nie(x, level = c("within", "between", "contrast"))` returns one scalar, and calling
  `nie(x)` with `level` missing returns the within effect (Q4; the label says so) [superseded by section 0: earlier text made this an error]. The extra argument is allowed because the generic is `function(x, ...)`. `nde(x, level = c("within", "between"))`
  returns `c_w` or `c_b`; `te()`/`pm()` take the same `level`. `paths(x)` returns a named numeric of the six level-qualified paths
  (as `paths()` does for `ClusterMediationData`). `decompose(x)` returns a **named numeric with a `label` attribute and no SE**
  (the `ClusterMediationData` method does exactly that): `c(within = a_w b_w, between = a_b b_b, contrast = within - between)`.
  Standard errors are not returned by `decompose()`; they come from `tidy()`/`confint()`/`summary()` (earlier text of this plan
  said `decompose()` returns the contrast with its SE; corrected).
- **Inference (checked against current signatures).** The internal builders are dispatched on the class: add a branch for the new
  class to `.effect_se()` / `.effect_se_or_na()` / `.path_se()` in `R/effect-se.R` (the `ClusterMediationData` branch is at
  `R/effect-se.R:184`) with the gradients of `a_w b_w`, `a_b b_b` and `a_w b_w - a_b b_b` over the joint `@vcov` (verified
  identical to lavaan's `:=` SE; research 2.1). Public calls and what each needs:
  `confint(object, parm = c("paths", "effects"), level = 0.95)` returns a two-column matrix (new `S7::method(confint, <class>)`
  in `R/methods-base.R`, mirroring `confint` for `ClusterMediationData`); `tidy(x, type = c("all", "paths", "effects"),
  conf_int = FALSE, conf_level = 0.95)` is routed by the S7_inherits chain in `tidy_s7_object()` (`R/methods-tidy.R:92`), so a
  new `.tidy_two_level_mediation_data()` and a branch there are required, plus `glance()`; `coef(object, ...)`, `vcov(object, ...)`,
  `nobs(object, ...)` get methods in `R/methods-base.R`; `print(x, ...)` and `summary(object, level = 0.95, ...)` go in
  `R/classes.R` with a `registerS3method("print", "summary_<class>", ...)` line in `R/zzz.R` (as for the cluster class), and
  `S7::S4_register(<class>)` goes in `.onLoad()` before `methods_register()`. `.assert_param_mediation_data()`
  (`R/bootstrap.R:680`) gets the class added (a one-line change).
- **Bootstrap (revised after adversarial review).** `bootstrap_mediation()` is *not* object-based: it takes a `statistic_fn`
  callback, raw `data` and `cluster = "<column>"` (nonparametric resampling draws whole clusters and gives each draw a fresh
  cluster id, so a cluster drawn twice is refit as two clusters; `R/bootstrap.R:251`, doc lines 32-36). The new class stores
  neither data nor a refit recipe, so `bootstrap_mediation(x, cluster = ...)` does **not** work and is not promised. S2 ships:
  1. **Callback route (S2, documented recipe + helper).** `bootstrap_mediation(statistic_fn, method = "nonparametric",
     data = d, cluster = "id")` with `statistic_fn(data)` refitting the two-level lavaan model and returning
     `nie(extract_mediation(fit, ...), level = )` or the contrast. The recipe lives on the model page and in the cookbook;
     an internal helper `.two_level_refit_stat(model, treatment, mediator, outcome, effect)` builds the closure so users do not
     hand-write it.
  2. **Parametric route (revised; confirmed against `R/bootstrap.R`).** `bootstrap_mediation()` asserts `statistic_fn` is a function
     before dispatch (line 275) and `.bootstrap_parametric()` calls it on every draw (`statistic_fn(boot_params[i, ])`, a **named
     numeric vector** over `names(@estimates)`; it also calls `statistic_fn(mu)` for the point estimate) and needs scalar returns
     (`vapply(..., numeric(1))`). So `bootstrap_mediation(mediation_data = x, method = "parametric")` with no callback **cannot
     work** and is not promised. The public call is
     `bootstrap_mediation(statistic_fn = function(p) p[["a_w"]] * p[["b_w"]] - p[["a_b"]] * p[["b_b"]], method = "parametric",
     mediation_data = x, n_boot = B, seed = s)`, which needs only (i) the class added to `.assert_param_mediation_data()`, and
     (ii) `@estimates` and `@vcov` carrying the alias rows `a_w, b_w, c_w, a_b, b_b, c_b` in matching order (the class validator
     enforces it). Draws come from `MASS::mvrnorm(mu, Sigma)` over the **joint** vcov, so cross-level covariance is kept.
     The documentation recipe lists ready callbacks for within, between and contrast. This is the recommended design (option a).
     Object-based effect dispatch (option b) is costed separately as optional slice S2c in section 10 and is not promised.
  3. **Object-based refitting (optional, S2b or with S4).** The class retains *fit provenance*: `@call` (the `extract_mediation`
     call), `@model` (lavaan or medfit syntax string), `@cluster` (column name), `@refit_args` (estimator, `se`, constraints) and,
     for the adapter, a reference to the raw data only when the user passes `data =` (never silently pulled from the lavaan
     object). With provenance, a `source_fit =`-style route (precedent: the FIML `source_fit` route, `R/bootstrap.R:264`) can
     refit without a callback. Decision for the grill (question 12); until it is taken, only routes 1 and 2 exist.
  Tests (required, each through the exact public call, written before the code):
  (i) *parametric*: `bootstrap_mediation(statistic_fn = <contrast callback>, method = "parametric", mediation_data = x, n_boot = 4000,
  seed = s)` returns a `BootstrapResult` whose `estimate` equals `unclass(nie(x, level = "contrast"))[[1]]` and whose
  `sd(boot_estimates)` is within Monte Carlo error of the delta-method SE from `tidy()`; planted defect: draw from
  `diag(diag(vcov))` (cross-level covariance zeroed) and require the SE comparison to fail on the nonzero-covariance fixture;
  also a call with `mediation_data = x` and no `statistic_fn` must error with the existing "argument statistic_fn is missing"
  style message (documented, so users are told the callback is needed);
  (ii) *nonparametric with clusters*: `bootstrap_mediation(statistic_fn, method = "nonparametric", data = d, cluster = "id",
  seed = s, n_boot = B)` where `statistic_fn` records, per refit, the number of distinct cluster ids and the row count, with a
  seed that draws at least one cluster twice; assert every refit sees J distinct ids and that the duplicated cluster appears
  as two clusters, and that the bootstrap SE of the contrast is within Monte Carlo error of the hand-built delta-method SE;
  planted defect: mock the relabel helper (`.relabel_clusters()`, the 2-1-1 plan's P2 device) to the identity and require the
  test to fail.
- **Entry points (signatures checked):**
  - S2: `extract_mediation(<lavaan>, treatment, mediator, outcome)` detects a two-level fit with `lavInspect(fit, "nlevels") > 1` [superseded by section 0: `nclusters` and block counts are not valid, they are 1 for `cluster=` single-level fits] and builds the class; no new arguments except optional `level_names`.
  - S4: `fit_sem()` has no `cluster` argument today (`R/fit-sem.R:354`: `model, data, information, n_starts, control, weights, se_type, meanstructure, fixed_x, sampling_weights, missing`), so adding `cluster = NULL` is a signature change (an additive argument; it joins the API-freeze table in `tests/testthat/test-api-freeze.R`). `fit_sem(model, data, cluster = "id", ...)` accepts `level:` blocks only when `cluster` is given;
    `fit_mediation(engine = "native", model = , cluster = )` already has a `cluster` argument (used by the lmer engine, `R/fit-glm.R:238`); the native branch `.fit_mediation_native()` does not take it yet and must forward it, with a guard that today's native route errors on `cluster` without `level:` blocks; the error message in `R/sem-fit.R:97` becomes the
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

## 9. Open questions for the maintainer (grill agenda) [superseded by section 0: Q1-Q11 are decided there; items 12-13 and the four items of 0.8 remain open]

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
11. **Bootstrap API (revised):** recommend (a): explicit scalar `statistic_fn` callbacks in the public call for both the parametric
    and the nonparametric/cluster routes (no change to `bootstrap_mediation()` beyond one supported-class entry). Option (b),
    object-based effect dispatch, would add a generic (working name `effect_fn(x, effect = c("within", "between", "contrast"))`
    returning a closure over the named parameter vector, plus a branch in `bootstrap_mediation()` that builds `statistic_fn`
    when it is missing for these classes, and a refit recipe for the nonparametric route (retained provenance, route 3). It
    touches the public generic set and every existing mediation class, so it is a separate slice (S2c, 4-6 days, grill first).
    Do you want (a) now and (b) deferred?
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
| S2 | adapter, class, generics, methods, docs, degenerate-X handling, label policy, fixed.x/information, oracles | 8-12 days (review revision; was 5-7) | normal |
| S2c | optional: object-based effect dispatch for `bootstrap_mediation()` (generic, branch, provenance refit) | 4-6 days, grill first | normal |
| S3 | oracle harness (incl. cluster-only covariate fixture) and simulation helpers | ~3-4 days | normal (tests/sim only) |
| S4 | native observed-variable two-level ML, `cluster =`, gates (NO-GO until section 0.5 and 0.8 are settled) | 3-4 weeks | **high** |
| S5 | latent mediators, shared loadings (NO-GO until the identification literature is read) | ~2 weeks | high |
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
