---
title: "SPEC: bounded Gaussian random-X FIML for two serial mediators (FI-G3)"
date: 2026-11-09
status: draft, specification only; no production change, no code written
plan: planning/PLAN-FIML-next-release-model-expansion-2026-11-01.md (section 4, FI-G3)
base: dev c5389f6d (FI-G2 slices 3-4 merged as #384); every code reference below was read in worktree feature-fiml-g2-covariates, identical to dev c5389f6d
decisions: []
---

# Scope

Contract for the serial slices of the bounded FIML family: X -> M1 -> M2 -> Y with independent disturbances, zero, one
or two observed covariates, built on the dimension-generic kernel (`R/sem-fiml.R`) and the adapter
(`R/sem-fiml-interface.R`). It follows the structure of `SPEC-fiml-generic-kernel-2026-11-08.md` (kept on the
`feature-fiml-g2-covariates` line; sections 7 to 9 there are the covariate and parallel precedents this spec extends).

In scope: model class, kernel changes, effects and delta-method inference, extraction and refusal contract, slices,
verification design, docs, open questions.

Out of scope: statistical admission and anything under the stage-0 guard (`bootstrap_mediation(source_fit =)` stays
withheld, `medfit_error_fiml_inference_unavailable`), correlated serial disturbances (plan: outside this scope), three or
more mediators, interactions, weights, constraints, fixed-X FIML. Nothing here is released: until a variant has its own
admission and release-scope decision it stays on a non-release branch and every public entry point keeps refusing what
is not admitted (plan R4).

Verified in this session (read-only): the code paths cited; lavaan 0.7-3 `sem()` adds no residual covariance for the
serial model (section 2.4). Not run: any medfit test, fit or gate. Each place where I could not verify something says
`unverified`. The QA report for FI-G2 slices 1-2 (`qa-g2-parallel.md`) is not in `_agents_workspace/`; only
`qa-g3-parallel-covariates.md` was available, and its failure modes are used below.

# 1. Model class

Variables (kernel order X, [Z or Z1 Z2], M1, M2, Y); all observed, continuous, Gaussian, random-X.

| Edge | Kernel label | Meaning | Status in this spec |
|---|---|---|---|
| X -> M1 | `a` | chain, first link | free, required |
| M1 -> M2 | `d1` | chain, middle link (existing serial alias `d1`) | free, required |
| M2 -> Y | `b` | chain, last link | free, required |
| X -> M2 | `a2` | skip path (existing serial alias `a2`) | free, required |
| M1 -> Y | `b1` | skip path (existing serial alias `b1`) | free, required |
| X -> Y | `cp` (alias `c_prime`) | direct path | free, or fixed at exactly 0 |

Aliases follow `.serial_edges(2)` in `R/utils.R` (`a`, `a2`, `d1`, `b1`, `b`, `c_prime`), so the existing serial effect code
reads them without translation.

## 1.1 Decision: which edges are admitted in slice 1

**Recommendation.** All three forward shortcuts the registry prescribes (`X -> M2`, `M1 -> Y`, `X -> Y`) are part of the
model; `a2` and `b1` are always present and free; only `X -> Y` may be fixed, and only at exactly 0 (or omitted, which
means 0, as in the three-variable and parallel forms; section 4.3 for covariates). Any other fixed value, a fixed or absent
`a2` or `b1`, a bound, start, label tie or constraint is refused.

Reason: the plan text is explicit ("all prescribed forward shortcuts"; "only the X-to-Y direct edge may be fixed at zero;
the other prescribed forward shortcuts remain present and free; an additional fixed or absent shortcut is not covered by
this registry"), and the plan's FI-G3 QA item requires an omitted-shortcut defect to be planted and detected. This
differs from the task framing "optional X -> M2 (free/zero/absent)", which would be a new variant outside the registry.

**Consequence worth stating (derived, to be pinned by tests).** With `a2`, `b1` and `cp` free and independent
disturbances, the model has as many free parameters as the unrestricted multivariate normal has moments: `q = p + p(p+1)/2`
for `p = 4 + k` variables (14, 20, 27 for k = 0, 1, 2). It is just identified: the FIML estimate is a one-to-one
reparameterization of the unrestricted MVN MLE (recursive regressions on the moments). With `cp` fixed at 0 it has one
restriction (df = 1). So the free-direct variants cannot fail on misfit; they can fail on identification (section 2.3).

**Rejected alternative A: pure chain** (`M1 ~ X`, `M2 ~ M1`, `Y ~ M2` [+ `Y ~ X`], two or three df). It is the textbook "a d b"
model, but the registry does not cover it, its zero shortcuts change the degeneracy structure of the total indirect
effect, and an absent shortcut is exactly what the plan wants refused. If wanted, it is a separate variant needing a
registry amendment (question 1).

**Rejected alternative B: admit `a2` and `b1` as free/zero/absent switches in slice 1.** Multiplies variants (3 shortcut
states per shortcut) and each needs its own admission; the maintainer's registry counts 3 serial variants, not 3 x 9.

# 2. Joint model for FIML and kernel changes

## 2.1 Model

Recursive, `Psi` diagonal, free intercepts, free exogenous means and covariance:

- `M1 = i_m1 + a X + sum_i gm1z_i Z_i + e_m1`
- `M2 = i_m2 + d1 M1 + a2 X + sum_i gm2z_i Z_i + e_m2`
- `Y  = i_y + b M2 + b1 M1 + [cp] X + sum_i gy_i Z_i + e_y`
- `X`, `Z_i`: free joint Gaussian, every pair covariance free (k >= 1), as in FI-G1.

Variables may be incomplete; row identity, empty-row, standardization, mask-pattern and Jacobian rules are those of the
generic kernel spec sections 1 and 2 unchanged.

## 2.2 Independence of the disturbances: why, and what is refused

Disturbance independence among M1, M2 and Y is the plan's scope ("independent disturbances"; "correlated serial
disturbances remain outside this scope"). Reasons: (i) the registry has one serial variant per covariate count, not a
residual axis; (ii) correlated serial disturbances confound the structural reading (a residual covariance between M1 and
M2 competes with `d1`; between M2 and Y with `b`) and change the identification structure; (iii) with `d1`, `b1`, `b` all
free, adding residual covariances among M1, M2, Y would exceed the unrestricted moment count (not identified).
Point (iii) is arithmetic from section 1.1 and is a hard reason, not only a scope choice.

Refused: any free, labeled, bounded, or nonzero-fixed `~~` between two of M1, M2, Y, or between a mediator or outcome and
an exogenous variable; any duplicate statement. Accepted (recommendation, question 2): no statement (omission means
independent), or an explicit `0*` fixed covariance for any of the three pairs, either order, as a redundant statement.

## 2.3 What changes in the kernel versus the four-variable parallel case

Nothing in the dimension-generic functions changes: `.sem_fiml_prepare_core()`, `.sem_fiml_eval()`, geometry, Hessian,
`.sem_fiml_solve()`, `.sem_fiml_starts()`, `.sem_fiml_lower()` and `.sem_fiml_variance_index()` read the variable count and
variance positions from the tables and layout. This is not new: `test-fiml-generic-kernel-fourvar.R` already drives the
internals with exactly the chain X, M1, M2, Y (paths `a`, `d`, `b`, `cp`; q = 12) against the rowwise reference,
independent geometry and Hessian, and lavaan (per the earlier spec, section 6; not re-run here). What is new:

| Component | Parallel (4 variables) | Serial (4 variables) |
|---|---|---|
| Tables builder | `.sem_fiml_tables_med(2L, direct, residual_covariance, k)` | new `.sem_fiml_tables_ser(direct, k)`; `.sem_fiml_tables_med()` and its output stay byte-identical (`identical()` against the frozen fixtures) |
| Rows of `a` (paths) | `M_j <- X`, `Y <- M_j`, `Y <- X` | `M1 <- X`, `M2 <- X`, `M2 <- M1`, `Y <- M1`, `Y <- M2`, `Y <- X`; plus `M1 <- Z_i`, `M2 <- Z_i`, `Y <- Z_i` for k >= 1 |
| Layout | `paths`, `variances`, `intercepts`; `covariances` empty for k = 0 | same four elements, `covariances` empty for k = 0 (no free residual covariance exists) |
| Transport | path unit `scale_resp / scale_pred`; intercept absorbs `-center_pred * unit` per path into its response | identical rule. New fact: the M2 intercept now absorbs three terms (`d1`, `a2`, covariate paths) and the Y intercept three (`b`, `b1`, `cp`) |
| Variance indices | `vx vm1 vm2 vy` (+ covariate variances) | the same four names; positions found by name through the layout |
| Jacobian | `sum_j n_j log scale_j` | identical |
| RAM implied moments | `(I - B)^-1` with B lower-triangular fill from `M_j <- X`, `Y <- M_j` | same formula; B now has the M2 <- M1 entry, so `Sigma[X, M2]` and `Sigma[X, Y]` pick up indirect terms; no code change expected because `solve(I - B)` is used (unverified for `.sem_ram` derivatives with the new entry; the four-variable internal test covers it for the chain without shortcuts) |
| Free parameters | 12 or 13 (+3k + k + k + C(k+1,2); +1 if free residual covariance) | 13 or 14 for k = 0 |

Free-parameter counts (listed in the adapter's tie check, `q`):

| k | p | moments `p + p(p+1)/2` | q, `cp` free | q, `cp` fixed 0 | df |
|---|---|---|---|---|---|
| 0 | 4 | 14 | 14 | 13 | 0 / 1 |
| 1 | 5 | 20 | 20 | 19 | 0 / 1 |
| 2 | 6 | 27 | 27 | 26 | 0 / 1 |

Formula: `q = 13 + 5k + C(k+1, 2) + direct` (13 base: five paths, four variances, four intercepts; each covariate adds
three paths `gm1z gm2z gy`, a variance, an intercept; plus the exogenous covariances). Parameter name list, k = 0:
`a a2 d1 b1 b [cp] vx vm1 vm2 vy ix im1 im2 iy`; with covariates the labels follow the parallel scheme (`gm1z1`, `gm2z1`,
`gy` for k = 1, `gy1 gy2` and the index on variances and intercepts for k = 2, exogenous covariances `cxz`, `cxz1 cxz2
cz1z2`). Parameter order in `ram$par_names` is not part of the contract (transport is by name); the final order is
unverified until the tables exist.

**Identification is stricter than in the parallel case.** In the parallel model the independence restriction pins
`Cov(M1, M2)` through the structure, so a mask set in which M1 and M2 are never observed together can still fit. In the
saturated serial model every pair of kernel variables has a free covariance, so a mask set in which some pair is never
jointly observed leaves that covariance flat: the moment-geometry rank gate should fail closed at stage `numerical`
(expected, to be pinned by a test; the fixed-zero direct variant may still identify the `X`-`Y` pair through its
restriction, also to be pinned, not assumed). Fits that parallel FIML accepts can therefore be refused by serial FIML on
the same data; this is correct and must be documented (section 7), not worked around.

# 3. Effects and delta-method inference

## 3.1 Effects (all from the path system of the existing class)

With aliases `a, a2, d1, b1, b, c'`:

- chain indirect effect `nie` (default of `nie()`): `a * d1 * b`.
- total indirect effect `nie_total` (`nie(type = "total")`, tidy key `nie_total`): `a d1 b + a2 b + a b1`, every directed
  X -> Y path except the direct one.
- direct effect `nde` = `c'`.
- total effect `te` = `c' + nie_total`, computed as `[(I - B)^-1]_{Y,X}` by `.serial_total_effect()` over the edges
  present in `@mediator_predictors` / `@outcome_predictors`.

Independent check: the four path products can be enumerated by hand (X-M1-M2-Y, X-M2-Y, X-M1-Y, X-Y); the matrix form
and the enumeration must agree to 1e-12.

## 3.2 Which covariance block is needed

The effect gradients need the full `6 x 6` block over `(a, a2, d1, b1, b, c_prime)`, taken from the fitted
observed-information covariance (not from separate regressions). Gradients (derived here, to be asserted against an
independent derivation in tests):

| Effect | Gradient over (a, a2, d1, b1, b, c') |
|---|---|
| `nie` (chain) | (d1 b, 0, a b, 0, a d1, 0) |
| `nie_total` | (d1 b + b1, b, a b, a, a d1 + a2, 0) |
| `nde` | (0, 0, 0, 0, 0, 1) |
| `te` | `nie_total` gradient with 1 for c' |

Equation structure explains which cross terms matter. `a` is in the M1 equation; `a2` and `d1` in the M2 equation;
`b1`, `b`, `c'` in the Y equation.

- Complete data: the log-likelihood factors over equations, so the observed information, and the transported covariance,
  is exactly block diagonal across equations (zero covariance between, say, `a` and `d1`), and within an equation it is the
  ML OLS covariance (`sigma_ML^2 (Z'Z)^-1`). The chain `nie` SE then involves no cross terms (its three factors sit in
  three equations); `nie_total` and `te` still need the within-equation covariances `Cov(a2, d1)` and
  `Cov(b1, b)`, `Cov(b1, c')`, `Cov(b, c')`, which are large when the regressors correlate. Dropping them is the lm-style
  within-block loss.
- Incomplete data (MAR/MCAR): the cross-equation blocks become nonzero, so the chain `nie` SE also depends on
  `Cov(a, d1)`, `Cov(a, b)`, `Cov(d1, b)`. These are the FIML-specific terms, and exactly what a separate-regression
  (lm-style) extraction drops. Their size is data-dependent (unverified; the parallel QA found the within-equation
  `Cov(b1, b2)` dominant and `Cov(a1, a2)` near zero).

## 3.3 Reuse versus a subclass

**Recommendation: a new internal subclass `FIMLSerialMediationData` of `SerialMediationData`**, property `fit_context`,
validator mirroring `FIMLParallelMediationData` (source and parameter hashes, `method = "fiml"`, `x_policy = "random"`,
`n_obs`, `source_package = "medfit"`, the data hash), with two differences: the sequential mediator order is checked
(`identical(vars[2:3], mediators)`, not `setequal`) and `ctx$structure` must equal `"serial"`. S4-registered in `R/zzz.R`
next to the other two. It inherits `nie`, `nde`, `te`, `coef`, `vcov`, `nobs`, `.effect_gradients()` (through
`S7_inherits(x, SerialMediationData)`, so the chain gradient and `.serial_te_gradient()` are reused) and the serial
tidy/confint bodies.

Rejected: reusing `SerialMediationData` unchanged. It has no `fit_context`, so the stage-0 provenance binding, the
`.sem_fiml_is()` test that makes every downstream consumer refuse bootstrap, `pm()` and `glance()`, and the origin rule
cannot attach; it would also look identical to a separately fitted lm/glm chain, whose `@vcov` has zero cross-equation
covariance.

Changes needed on inherited behavior (gaps found by reading the code; none of them exists for serial today):

1. `pm()` on a serial object has no `.sem_fiml_refuse()` call (`generics-effects.R`, the serial method calls
   `.serial_pm_from_total()` directly); the simple and parallel methods refuse. The subclass must refuse.
2. `.glance_serial_mediation_data()` has no `.sem_fiml_refuse()`; add it (simple and parallel glance have it).
3a. (Added after the second Codex review.) `confint(parm = "effects")` for serial returns `nie`, `nde`, `te` only, so the
   reported `nie_total` has no interval. The FIML serial `confint(parm = "effects")` must also return `nie_total`
   (delta gradient from section 3.4), tested against the gradient built from the full extracted covariance and against
   `tidy(conf_int = TRUE)` for the same effect, with a planted defect that drops its row.
   `confint()` for `SerialMediationData` has no FIML branch: `method = "boot"` stops with the lm/glm advice
   ("call bootstrap_mediation() directly"), which is wrong advice for FIML; the effects warning says "consider
   bootstrap_mediation()"; and there is no origin guard. Add the FIML branch (refuse boot through `.sem_fiml_refuse`,
   FIML warning text, origin NA, note attribute), as in the parallel and simple methods.
4. `.sem_fiml_is()` must include the new class; `bootstrap_mediation(mediation_data =)` then refuses it through the
   existing `.sem_fiml_refuse()` calls.
5. `paths()` for a two-mediator serial object returns `a, d, b, c_prime` only, so a `tidy()` of the FIML object would hide
   the two estimated shortcut paths. Recommendation (question 4): a subclass `paths()` returning `a, a2, d, b1, b,
   c_prime` and a tidy path alias vector `a, a2, d1, b1, b, c_prime`; the base-class method is untouched.
   **Contract (added after the Codex adversarial review, 2026-11-09):** the existing serial `tidy()` and `confint()`
   supply only four path aliases (`a, d1, b, c_prime`). Both consumers must map all six displayed paths to covariance
   rows (alias rows first, error instead of guessing, as `.path_se()` does), never recycle four SEs over six estimates.
   Test every one of the six path SEs and intervals against the extracted `@vcov` diagonal, for `tidy()` and for
   `confint(parm = "paths")`; plant a defect that returns four aliases and require it to fail.

## 3.4 Exact-origin NA rule

Existing rule: the NIE delta gradient is zero only at an exact origin, where the delta SE would be exactly 0 and
misleading; the SE is then withheld (`NA`, plus the note "NIE inference unavailable: zero delta gradient"). Fits never
produce exact zeros; the rule is reachable on constructed objects only. For serial two rules, one per effect:

- Chain `nie` = `a d1 b`: the gradient `(d1 b, a b, a d1)` is all zero if and only if **at least two** of `a`, `d1`, `b`
  are exactly zero. One exactly-zero factor leaves a nonzero gradient (for `a = 0`: `(d1 b, 0, 0)`), so the SE stays
  finite and must not be set to `NA`. (Check: `a = d1 = 0` gives `(0, 0, 0)`; `a = 0` alone gives `d1 b != 0`.)
- Total indirect `nie_total` (key `nie_total`): the gradient above is zero if and only if `a = a2 = b = b1 = 0` (`d1`
  unrestricted: `b = 0` from the `a2` component, `a = 0` from the `b1` component, then `b1 = 0` from the `a` component
  and `a2 = 0` from the `b` component). Withhold its SE only then.
- `te` and `nde` are never withheld (`c'` has gradient 1).

The shared helper `.sem_fiml_origin()` returns one boolean today and callers set only `se["nie"]` to `NA`. For the serial
class it needs to report per effect key (chain, total) and the three call sites (`.tidy_paths_effects`, the two
`confint()` methods plus the new serial one) must apply the right key. Off-by-one-factor bugs are the expected defect here
(planted defects D12, D13 below).

## 3.5 Inference scope and the stage-0 guard

Delta-method Wald intervals through `tidy()` and `confint(method = "normal")` stay available, as for every prior FIML
variant. Bootstrap intervals are withheld: `bootstrap_mediation(source_fit =)`, both methods, hits the stage-0 guard first
(`medfit_error_fiml_inference_unavailable`); with the guard mocked open the serial fit must still be refused before any
RNG draw or refit by a new class `medfit_error_fiml_serial_source_fit` (section 4.4). No source-fit interval exists for
this variant until its own admission.

# 4. Naming, extraction and refusals

## 4.1 Structure detection and names

`.sem_fiml_model()` today routes by variable count: `length(x) %in% 1:3` with `length(roles$obs) == length(x) + 3L` goes
to `.sem_fiml_model_par()`, whose first topology check refuses an `M ~ M` regression as "unsupported FIML topology or
correlated disturbances". The serial router goes in front of it: with exactly one outcome (the only left-hand side that
is never a right-hand side) and two other endogenous variables, a regression between those two endogenous variables
selects the serial parser; no such regression selects the existing parallel parser unchanged; both directions present is
a cycle and is refused.

Names: kernel `X`, `Z`/`Z1 Z2`, `M1`, `M2`, `Y`; data names stay in the adapter's `spec$vars`, `spec$mediators`,
`spec$covariate`. `M1` is the mediator with no mediator among its predictors, `M2` the other; this is structural, not
order of appearance (the parallel rule is order of appearance). `spec$structure = "serial"` is a new field. Every
consumer that today tests `!is.null(spec$mediators)` (table selection in `.sem_fiml_syntax()`, `.sem_fiml_extract()`
dispatch through `likelihood$mediators`, `.bootstrap_fiml()`) must branch on `structure` instead, because serial also
has two mediators and would otherwise be built with the parallel tables (planted defect D8). The `likelihood` list records
`structure` and `mediators` in sequential order.

## 4.2 Extraction rules

`extract_mediation(fit, treatment = X, mediator = c(m_first, m_second))`:

- `mediator` must name both fitted mediators in structural order (length 2, `m_first` then `m_second`). The reverse
  order is refused (recommendation, question 7), not reordered: it asks for a different model (M2 -> M1).
- `structure` accepts `"auto"` or `"serial"` for a serial fit; `"parallel"` is refused (and `"serial"` stays refused for
  a parallel fit, as QA verified).
- `decomposition` accepts `"auto"` or `"two_way"`; `standardized`, `interaction`, `outcome` other than Y, unknown
  arguments, a single mediator, a non-fitted or repeated mediator, a covariate named as mediator: refused.
- Treatment follows the covariate precedent (FI-G1, FI-G2 slices 3-4): with `cp` free any exogenous variable may be named
  the treatment (kernel is symmetric in the exogenous block); a covariate named the treatment takes `a = gm1z_i`,
  `a2 = gm2z_i`, `c_prime = gy_i`, with `d1`, `b1`, `b` unchanged; with one Y path fixed at 0 that variable is the only
  valid treatment.
- Output `FIMLSerialMediationData`: `a_path`, `d_path` (scalar `d1`), `b_path`, `c_prime`; `@estimates` carries the alias
  names `a a2 d1 b1 b c_prime` (needed: `.serial_path_system()` returns "no coefficient ... is stored" and `te()` becomes
  `NA` with a warning if `a2` or `b1` is missing); `@vcov` is the `6 x 6` alias block, full cross-block from the fitted
  covariance, the fixed-zero or omitted `c_prime` a zero row and column; `@mediator_predictors` lists, for M1 `X` (+
  covariates), for M2 `X`, `M1` (+ covariates); `@outcome_predictors` lists `M1`, `M2`, `X` (+ covariates), so every
  shortcut edge is recorded as present; `sigma_mediators`, `sigma_y` from the variances.
- `fit_context` carries `structure`, `mediators` (sequential), covariates, the source hashes (as parallel), and
  provenance for the binding.
- Name collision hazard: parallel and serial both use the strings `a2`, `b1`, but with different roles in the extraction
  (`a1 a2 b1 b2` versus `a a2 d1 b1 b`). The extractor must be selected by `structure`, never by presence of an alias.

## 4.3 Refusals at fit

All fit refusals are class `medfit_sem_fiml_error` (`stage = "input"`; numerical failures `stage = "numerical"` with
attempts retained). Messages below are proposals (wording unverified); the class and the condition are the contract.

| Condition | Refused with |
|---|---|
| three or more mediators; a mediator not affected by X; a mediator that does not affect Y; mediator affecting X; a cycle (`M1 ~ M2` and `M2 ~ M1`) | topology diagnostic (class above) |
| absent or fixed `X -> M2` (`a2`) or `M1 -> Y` (`b1`); absent `M1 -> M2`, `M1 <- X`, `Y <- M2` (pure chain, partial chain) | topology diagnostic naming the missing forward path |
| any free, labeled, bounded or nonzero covariance among M1, M2, Y, or between them and an exogenous variable | "correlated disturbances not supported" |
| fixed value other than `Y ~ 0*X`; `lower()`, `start()`, constraints, `:=`, ties (`q` mismatch), labels that tie | as for prior variants |
| mixed parallel-and-serial syntax beyond the saturated serial graph (for example parallel mediators plus `M2 ~ M1` but no `Y ~ M1`) | covered by the absent-shortcut row |
| covariates: three or more; a covariate with no path to M1, M2 or Y; an omitted Y path from any exogenous variable; two or more fixed Y paths; partial exogenous covariance set; fixed or fixed-zero covariate paths | as FI-G1 / FI-G2 slices 3-4 |
| `fixed_x` not explicit `FALSE`, weights, `control`, `information`, `se_type`, `meanstructure`, `n_starts` | as for every FIML fit |
| observed variables: interaction `:`, non-numeric, non-finite, all-NA columns, fewer than 2 observed values, zero scale | as for every FIML fit |
| non-identified masks (rank-deficient geometry, including a pair never jointly observed), no accepted candidate per solver, disagreeing likelihoods, ill-conditioned information | `stage = "numerical"` |

Direct-path policy for k = 0: `Y ~ X` free, `Y ~ 0*X`, or omitted (= fixed 0), as in the three-variable and parallel
forms. For k >= 1: every exogenous variable has a written Y path (free; at most one fixed at exactly 0), as in
FI-G1 and FI-G2: an omitted Y path is ambiguous with a covariate acting on the mediators only.

## 4.4 Refusals at extract and source fit

- Extract: class `medfit_error_fiml_extract_unsupported`, message pattern as the parallel form ("FIML extraction supports
  only the fitted unstandardized two-way serial mediation naming both mediators in order").
- Consumers refuse a serial FIML object as they refuse simple and parallel ones: `pm()`, `glance()`, `quick()`,
  `confint(method = "boot")`, `bootstrap_mediation(mediation_data =)`, `bootstrap_mediation(data =)`, `mbco_sem`,
  `compare_lr`, `anova`, AIC/BIC on the extracted object. `pm()` and `glance()` need the new `.sem_fiml_refuse()` calls
  (section 3.3).
- Source fit: the order in `R/bootstrap-fiml.R` is unchanged: the stage-0 guard first, then the covariate refusal
  (`medfit_error_fiml_covariate_source_fit`, which a serial fit with covariates still triggers by precedent), then a
  structure refusal. New class `medfit_error_fiml_serial_source_fit` for a serial fit without covariates, raised before
  any RNG draw or refit, for both methods (parametric and nonparametric). The existing parallel refusal must not fire for
  a serial fit (it tests `spec$mediators`, which is set for serial too; section 4.1).
- Merge condition R4: before any slice merges, tests show that every still-unadmitted topology and policy is refused at
  fit, extract and both source-fit methods (including: slices not yet merged, for example k = 1 and 2 while only k = 0 is
  public).

# 5. Slices and variant counts

The plan registers three serial variants: zero, one, two covariates. The direct-path policy (free, fixed at 0) is a
within-variant axis, not extra variants; completion evidence is recorded per policy (plan section 1). FI-G2 slices 3-4
(parallel with covariates) are the template: tests first (red commit), then the feature commit per slice, a frozen-table
fixture captured before the slice, QA per slice.

| Slice | Public variant | q (direct free / fixed 0) | Notes |
|---|---|---|---|
| S0 | none | n/a | freeze fixture `fiml-tables-before-g3s1.rds` from the base commit: every table shape reachable through public entry points (the earlier fixtures hold 8 and 10 shapes; shape count to be taken from the code) |
| S1 | serial, no covariates | 14 / 13 | tables builder, router, parser (`spec$structure`), class, extraction, origin rule, refusals; includes all section 3.3 edits |
| S2 | serial, one covariate | 20 / 19 | `.sem_fiml_tables_ser(direct, 1L)`; FI-G1 treatment and exogenous-covariance rules; covariate-as-treatment mapping |
| S3 | serial, two covariates | 27 / 26 | same builder, `k = 2`, `.sem_fiml_par_cov_max()`-style limit for serial |

Order S1 -> S2 -> S3, one PR per slice, each to `dev` only on the maintainer's instruction (feature branch workflow; and
the Hopper freeze caveat: cut the Hopper harness commit on `ba50f998`, not on a later `dev`). Three public variants
total (S1 to S3), six policy cells (variant x direct policy), consistent with the registry (11 variants in all: 2
covariate, 6 parallel, 3 serial).

# 6. Verification design (admission checklist, per slice)

Independent oracles; production helpers appear only as the code under test. Tolerances follow the earlier slices.

| # | Item | Oracle | Tolerance |
|---|---|---|---|
| V1 | estimates, observed-information covariance, logLik, n | lavaan 0.7-3 raw-data FIML (`missing = "ml"`, `fixed.x = FALSE`, observed information), both direct policies, MCAR, MAR, sparse masks including an all-NA row, all fifteen masks present | estimates 1e-5, vcov normalized 1e-3, logLik 1e-6 |
| V2 | indirect effects and SEs | lavaan `:=` definitions: `ind1 := a*d1*b`, `ind_tot := a*d1*b + a2*b + a*b1`, `te := ind_tot + cp` for a free direct path; for the fixed-zero direct policy `te := ind_tot` (a literal zero, no `cp` label exists); their delta SEs | 1e-5 estimates, SE relative 2e-3 |
| V3 | complete-data neutrality | `lm` equation by equation (`M1 ~ X [+Z]`, `M2 ~ M1 + X [+Z]`, `Y ~ M1 + M2 + X [+Z]` for the free direct path; for the fixed-zero direct policy the Y regression omits X: `Y ~ M1 + M2 [+Z]`, because `lm` with X estimates the very path the policy fixes), exogenous ML covariance, ML residual variances (`mean(r^2)`), means; plus `vcov` exactly block diagonal across equations with ML-OLS within-equation blocks | 1e-7 (1e-6 for blocks) |
| V4 | saturation identity (free direct) | unrestricted multivariate normal FIML (all moments free) in lavaan or an independent EM, mapped to the recursive parameters by recursive regressions from the moments: the serial FIML estimate must equal it, the logLik must equal the unrestricted logLik | estimates 1e-5, logLik 1e-6 |
| V5 | fixed-zero direct df = 1 | LR against the unrestricted logLik equals the lavaan chi-square for `Y ~ 0*X` | 1e-5 |
| V6 | rowwise likelihood, independent Hessian and moment geometry | adapt the `gk_*` / `gk4_*` references with `a2`, `b1` | value 1e-8, gradient 1e-6 |
| V7 | OpenMx supporting cells | mxTryHard, status 0, at least k = 0 free, k = 1 fixed-zero, k = 2 MAR | est 1e-5, vcov relative 1e-3 |
| V8 | hand delta SEs | from extracted `@vcov`: chain (3 x 3 block), total indirect (5 x 5), `te` (6 x 6), equal to `tidy()` to 1e-12; path enumeration equals `[(I-B)^-1]_{Y,X}` to 1e-12 | 1e-12 |
| V9 | covariate/path confusion | DGP with large, distinct covariate effects on M1, M2 and Y, treatment named as X and as each covariate, lavaan with the label moved; reversed-mediator extraction refused | 1e-7 lm, 1e-5 lavaan |
| V10 | near-boundary and identification | residual correlations or `M2 ~ M1` near deterministic, n = 25 to 500, complete and 20% MCAR, a pair never jointly observed, weak `a` with `d1`, `b` near 0: every outcome is a fit that agrees with lavaan where lavaan converges, or a classed `medfit_sem_fiml_error`; no silent boundary solution. Expectation (unverified) that serial refuses more cells than parallel in sparse masks | fail-closed check |
| V11 | refusals | every row of section 4.3 and 4.4 at fit, extract, both source-fit methods (guard closed, and guard mocked open for the structure class) | class and condition exact |
| V12 | exact origin | forged objects with the fit-context hash rebound: `a = d1 = 0` withholds chain SE; `a = 0` only keeps it finite and equal to the hand value; `a = a2 = b = b1 = 0` withholds `nie_total`; near-origin controls keep finite SEs; tampering without rebinding the hash is rejected by the validator | exact / 1e-12 |
| V13 | frozen tables | fixture from S0: tables for every earlier shape `identical()` to the current builders and to the base-commit source | `identical()` |
| V14 | stage-0 simple model parity (R2) | two installs (branch and `dev`), all earlier shapes x four datasets (MAR, MCAR 30%, MAR, complete), `identical()` on theta, vcov, logLik, nll, attempts, n, tidy effects, extracted vcov | bit identical |
| V15 | `fiml-ext` gate rows | one structure per slice added (k = 0, 1, 2), two seeds, the existing eight checks, both direct policies reported separately, serial refusal probes added to the admitted-unadmitted-topology count (must stay 0); mutants column extended | row count: unverified arithmetic `11 x 2 x 8 + 1 = 177` if the grid is unchanged; the implementer confirms in `tests/sim/run-gates.R` |

## 6.1 Planted defects

Each needs a positive control (the unmutated copy passes the battery) and must fail at least one test; the battery must
include incomplete cells (the cross-equation defects are invisible on complete data) and cells with distinct large path
values.

| ID | Defect | Why it needs care |
|---|---|---|
| D1 | `d1` and `b` swapped in the path rows or extraction | the chain `nie` estimate `a d1 b` is invariant to a `d1`/`b` swap; only the path rows, `nie_total`, `te` and the SEs expose it |
| D2 | `a` and `a2` swapped | changes `nie_total`, `te` |
| D3 | `b1` aliased to `c_prime` (or `c'` taken from `b1`) | shortcut-path confusion |
| D4 | omitted shortcut: `a2 b` and `a b1` dropped from `nie_total` / `te` (plan-mandated) | chain `nie` unchanged |
| D5 | cross-equation covariance blocks zeroed in the extracted `@vcov` (lm-style) | invisible on complete data (blocks are zero there); caught only by MAR/MCAR cells |
| D6 | within-equation covariance zeroed (diagonal only) | `Cov(a2, d1)`, `Cov(b1, b)` drive `nie_total` and `te` |
| D7 | wrong chain gradient: parallel-style `(b, a)`, a gradient missing `d1`, or components permuted | |
| D8 | serial fit built with the parallel tables or extracted by the parallel extractor | `structure` branch missing; the shared alias strings `a2`, `b1` make this fail silently |
| D9 | mediator order taken by appearance instead of structure | |
| D10 | transport: the M2 intercept does not absorb `-center_M1 * unit(d1)`, or the Y intercept loses the `b1` term | |
| D11 | covariate named treatment: `a2` from `gm1z`, wrong covariate index, `c'` from the wrong `gy` | as parallel D |
| D12 | origin rule too broad: SE withheld when a single chain factor is 0 | |
| D13 | origin rule too narrow or missing for `nie_total`; or `te` withheld | |
| D14 | `pm()` or `glance()` not refused for the serial class; `confint(method = "boot")` giving the lm/glm advice | |
| D15 | serial source-fit not refused (guard mocked open) or refused with the parallel class | |
| D16 | exogenous covariance block dropped from the tables | as FI-G1 |

# 7. Docs to change

Roxygen/Rd and prose (generated `.Rd` through `devtools::document()`): `R/fit-sem.R` (the "Bounded FIML" section, which
today ends "Serial mediation ... stay refused"), `R/aab-generics.R` (`extract_mediation()` FIML paragraph), the
`SerialMediationData` mention in `R/classes.R` only if the subclass is documented; `R/sem-syntax-help.R`
(`?"medfit-syntax"` FIML rows, unverified whether FIML syntax is tabulated there); `NEWS.md`; `.STATUS`; the plan file's
FI-G3 entries. Articles that mention parallel FIML and need the serial counterpart or an update of the "refused" lists
(grep hit, content not read): `vignettes/articles/native-guide.qmd`, `extraction.qmd`, `models.qmd`,
`model-native-multi.qmd`, `example-gpa.qmd`, `methods.qmd` (add the Bounded FIML serial formulas: chain and total
indirect gradients, the saturation note, the origin rule). `tests/testthat/test-guide-native-fiml.R` quotes error
messages of the pages and must be extended for every new message the guide quotes. Docs state: identification is
stricter than parallel (pair never jointly observed), `nie` is the chain only and `nie_total` the sum of all indirect
paths, bootstrap and `pm()` unavailable.

# 8a. Maintainer decisions (grill, 2026-11-09)

Ledger: `planning/GRILL-fiml-serial-FI-G3-2026-11-09.md`. Where this section conflicts with sections 1-7 or the recommendations in section 8, this section wins. In short: Q1 admit the saturated graph AND the pure chain (overrides); Q2 require all three residual zeros written (overrides); Q3 omitted `Y ~ X` fixed 0 at k = 0 only; Q4 all estimated paths per variant; Q5 effects `nie`, `nie_total`, `nde`, `te`; Q6 covariate may be treatment; Q7 refuse reversed order; Q8 per-effect origin rule; Q9 keep the rank gate; Q10 parity once per slice; Q11 print chain and covariates (may slip). Sections 3-7 still describe the saturated graph only and must be extended for the pure chain before implementation.

# 8. Open questions for the maintainer

1. **Shortcut policy.** Admit only the saturated forward graph (`a2`, `b1` present and free; only `cp` fixable at 0), per
   the plan's wording. Recommendation: yes. Alternative: also admit the pure chain (no `a2`, `b1`) as a separate variant
   (needs a registry amendment and its own admission).
2. **Residual independence by omission or written.** Parallel requires writing `M1 ~~ 0*M2` because "lavaan's default
   would free it". For serial, medfit's completion adds no residual covariance and lavaan 0.7-3 `sem()` freed none either
   (probed here for the serial and the parallel models; `lavaan::lavaanify` plus a `sem()` fit on simulated data).
   Recommendation: accept omission and redundant explicit `0*` statements for serial, with a test that pins lavaan's
   behavior so a version change fails loudly. Alternative: require writing the three zero covariances (consistent with
   parallel, noisier). Separate point: my probe did not reproduce the parallel spec's lavaan claim for 0.7-3; it may be
   version-specific (unverified); worth a one-off recheck before it is cited again.
3. **Omitted `Y ~ X` for k = 0.** Recommendation: admit as fixed 0, like the three-variable and parallel forms; refuse
   for k >= 1. Alternative: require it written for serial too.
4. **Reporting the shortcut paths.** Recommendation: `FIMLSerialMediationData` has its own `paths()` listing `a, a2, d,
   b1, b, c_prime` and tidy shows all six rows. Alternative: leave `paths()` (four rows) and show shortcuts only through
   `nie_total`/`te`.
5. **Which effects are admission targets, and per-path specific indirect effects.** Recommendation: deliver `nie` (chain),
   `nie_total`, `nde`, `te` only, as the existing serial tidy does; defer specific effects (`a d1 b`, `a2 b`, `a b1`
   individually) to the admission design. Needs a maintainer statement of which effects the serial admission will test.
6. **Covariate as treatment in S2 and S3.** Recommendation: allow, as in FI-G1 and FI-G2 slices 3-4 (kernel symmetric;
   previously QA-verified). Alternative: treatment fixed to the X of the model.
7. **Reversed mediator order in `extract_mediation()`.** Recommendation: refuse. Alternative: silently reorder.
8. **Origin rule scope.** Recommendation: withhold the SE of `nie` when at least two of (`a`, `d1`, `b`) are exact zeros
   and of `nie_total` when `a = a2 = b = b1 = 0`, both with the existing note; implemented through a per-effect helper.
   Alternative: only the chain rule.
9. **Identification messaging.** A pair never jointly observed makes serial FIML refuse at stage `numerical` where parallel
   fits. Recommendation: keep the existing rank gate and document it; do not add a bespoke pre-check in these slices.
10. **Parity cadence.** Recommendation: the V14 two-install parity run once per slice (as QA did for FI-G2), not only at the
    end; and cut the Hopper harness commit on `ba50f998`.
11. **Printing.** `print()` of the extracted FIML parallel object names no covariates (QA observation E). Recommendation:
    for serial print the chain "X -> M1 -> M2 -> Y" with the covariates; cosmetic, can slip.
