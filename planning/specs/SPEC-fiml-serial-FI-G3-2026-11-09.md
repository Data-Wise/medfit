---
title: "SPEC: bounded Gaussian random-X FIML for two serial mediators (FI-G3)"
date: 2026-11-09
status: draft rev 2 (maintainer decisions Q1-Q11 incorporated), specification only; no production change, no code written
plan: planning/PLAN-FIML-next-release-model-expansion-2026-11-01.md (section 4, FI-G3; needs the registry amendment in section 1.2 before slice work starts)
base: dev c5389f6d (FI-G2 slices 3-4 merged as #384); every code reference below was read in worktree feature-fiml-g2-covariates (task statement: identical to dev c5389f6d; its HEAD is f704ab02, with docs-only commits on top, not re-diffed)
decisions: []
---

# Scope

Contract for the serial slices of the bounded FIML family: X -> M1 -> M2 -> Y with independent disturbances, zero, one
or two observed covariates, in two shortcut variants (maintainer decision Q1): the **saturated** forward graph and the
**pure chain**. It is built on the dimension-generic kernel (`R/sem-fiml.R`) and the adapter
(`R/sem-fiml-interface.R`) and follows the structure of `SPEC-fiml-generic-kernel-2026-11-08.md` (kept on the
`feature-fiml-g2-covariates` line; sections 7 to 9 there are the covariate and parallel precedents this spec extends).

In scope: model classes, kernel changes, effects and delta-method inference, extraction and refusal contract, slices,
verification design, docs, open questions.

Out of scope: statistical admission and anything under the stage-0 guard (`bootstrap_mediation(source_fit =)` stays
withheld, `medfit_error_fiml_inference_unavailable`), correlated serial disturbances (plan: outside this scope), three or
more mediators, a single present shortcut, interactions, weights, constraints, fixed-X FIML. Nothing here is released:
until a variant has its own admission and release-scope decision it stays on a non-release branch and every public entry
point keeps refusing what is not admitted (plan R4).

Verified in this session (read-only): the code paths cited; lavaan 0.7-3 `sem()` frees no residual covariance for the
parallel or serial models (probed twice: by the maintainer's grill probe, and re-probed here for the parallel model, the
pure chain and the saturated graph, listwise and `missing = "ml"`, `fixed.x = FALSE`; 0 free off-diagonal `~~` rows in all
six fits). Not run: any medfit test, fit or gate. Each place where I could not verify something says `unverified`. The QA
report for FI-G2 slices 1-2 (`qa-g2-parallel.md`) was not available; only `qa-g3-parallel-covariates.md` was, and its
failure modes are used below.

# 1. Model class

Variables (kernel order X, [Z or Z1 Z2], M1, M2, Y); all observed, continuous, Gaussian, random-X.

| Edge | Kernel label | Alias | Saturated | Pure chain |
|---|---|---|---|---|
| X -> M1 | `a` | `a` | free, required | free, required |
| M1 -> M2 | `d1` | `d1` | free, required | free, required |
| M2 -> Y | `b` | `b` | free, required | free, required |
| X -> M2 | `a2` | `a2` | free, required | absent (structural zero) |
| M1 -> Y | `b1` | `b1` | free, required | absent (structural zero) |
| X -> Y | `cp` | `c_prime` | free, or fixed at exactly 0 | free, or fixed at exactly 0 |

Aliases follow `.serial_edges(2)` in `R/utils.R` (`a`, `a2`, `d1`, `b1`, `b`, `c_prime`; read), so the existing serial
effect code reads them without translation. In the chain, an absent edge is not stored as an alias and is recorded as
absent in `@mediator_predictors` / `@outcome_predictors`; `.serial_path_system()` treats a skip edge whose source is not a
predictor as a structural zero (read in `R/utils.R`), so the existing total-effect code needs no change for the chain.

## 1.1 Admitted variants (Q1: both)

**Decision (Q1, overrides the earlier recommendation).** Two serial shortcut states are admitted, each with zero, one or
two covariates and each with a free or exactly fixed-zero X -> Y path:

- **Saturated:** `a2` and `b1` present and free (the plan's original wording).
- **Pure chain:** `a2` and `b1` both absent (structural zeros). Not "fixed at 0": an absent edge has no table row.

Everything else is refused: exactly one of `a2`, `b1` present (partial shortcut set); a fixed, labeled, bounded, tied or
constrained shortcut; any fixed value other than exactly 0 on X -> Y; any start, bound, constraint.

Why both are coherent. The saturated graph with `cp` free has as many free parameters as the unrestricted multivariate
normal has moments: `q = p + p(p+1)/2` for `p = 4 + k` variables. It is just identified (df 0): the FIML estimate is a
one-to-one reparameterization of the unrestricted MVN MLE (recursive regressions on the moments). With `cp` fixed it has
one restriction. It cannot fail on misfit, only on identification (section 2.3). The pure chain imposes `a2 = b1 = 0`:
two restrictions with `cp` free (df 2), three with `cp` fixed at 0 (df 3). It is overidentified, so it can disagree with
the data; that makes it the one serial variant whose likelihood is a real restriction, and its oracles cannot use the
saturation identity (section 6).

**Rejected alternative: admit `a2` and `b1` as free/zero/absent switches independently.** Multiplies variants (the
mixed states, such as `a2` free with `b1` absent, are not in the maintainer's decision) and each needs its own
admission. Not admitted.

## 1.2 Registry amendment (required before slice work)

The plan's registry (`planning/PLAN-FIML-next-release-model-expansion-2026-11-01.md`, section "Target and limits") covers
three serial variants and states "An additional fixed or absent shortcut is not covered by this registry", so the pure
chain is outside it today. Amend the plan with this exact wording (planning edit; not made here):

1. Table row, replace the serial row with:
   `| Two serial mediators | 6 | Zero, one or two covariates, crossed with two shortcut states: the saturated forward graph (X-to-M2 and M1-to-Y free) and the pure chain (X-to-M2 and M1-to-Y absent); independent disturbances written as zero covariances. |`
2. Replace the paragraph "The 11 are model-family/shape variants ..." so that it reads "The 14 are model-family/shape
   variants"; replace "The 22 policy combinations" with "The 28 policy combinations".
3. Replace the sentences "For serial models, only the X-to-Y direct edge may be fixed at zero; the other prescribed
   forward shortcuts remain present and free. An additional fixed or absent shortcut is not covered by this registry."
   with: "For serial models two shortcut states are covered: both forward shortcuts (X-to-M2, M1-to-Y) present and free, or
   both absent. Within either state only the X-to-Y direct edge may be free or fixed exactly at zero. A single present
   shortcut, a fixed or labeled shortcut, and any other fixed or absent edge are not covered by this registry. Serial
   totals include every directed path of the declared state; for the pure chain the total indirect effect equals the
   chain indirect effect."
4. FI-G3 task text: change "Add the two-mediator serial graph, all mandated forward shortcuts and zero/one/two-covariate
   variants" to "... the two-mediator serial graph in both shortcut states (saturated and pure chain) and the
   zero/one/two-covariate variants of each"; change "Three named variants satisfy" to "Six named variants satisfy";
   add to the QA item "plant and detect, for the pure chain, a freed shortcut and, for the saturated graph, a wrongly
   dropped shortcut".
5. Grep the plan for every other `11` (variants) and `22` (policy combinations), including the admission section's
   "11 expanded variants", and update them to 14 and 28. Not enumerated here (unverified beyond the occurrences read).

Counts after the amendment: 2 covariate + 6 parallel + 6 serial = 14 variants; 28 policy combinations (variant x direct
policy).

# 2. Joint model for FIML and kernel changes

## 2.1 Models

Recursive, `Psi` diagonal, free intercepts, free exogenous means and covariance.

Saturated:

- `M1 = i_m1 + a X + sum_i gm1z_i Z_i + e_m1`
- `M2 = i_m2 + d1 M1 + a2 X + sum_i gm2z_i Z_i + e_m2`
- `Y  = i_y + b M2 + b1 M1 + [cp] X + sum_i gy_i Z_i + e_y`

Pure chain (no `a2 X` in M2, no `b1 M1` in Y):

- `M1 = i_m1 + a X + sum_i gm1z_i Z_i + e_m1`
- `M2 = i_m2 + d1 M1 + sum_i gm2z_i Z_i + e_m2`
- `Y  = i_y + b M2 + [cp] X + sum_i gy_i Z_i + e_y`

Both: `X`, `Z_i` free joint Gaussian, every pair covariance free (k >= 1), as in FI-G1. Covariates predict every
endogenous variable (plan), in the chain too. Variables may be incomplete; row identity, empty-row, standardization,
mask-pattern and Jacobian rules are those of the generic kernel spec sections 1 and 2 unchanged.

## 2.2 Independence of the disturbances (Q2: all three zeros written)

Disturbance independence among M1, M2 and Y is the plan's scope. Reasons: (i) the registry has no residual axis for
serial; (ii) correlated serial disturbances confound the structural reading (a residual covariance between M1 and M2
competes with `d1`; between M2 and Y with `b`); (iii) in the saturated graph with `cp` free, adding any residual
covariance exceeds the unrestricted moment count (not identified). Point (iii) is arithmetic from section 1.1 and holds
for the saturated variant only; in the chain, extra residual covariances would be identified (df 2) but stay out of scope
by the plan.

**Decision (Q2, overrides the earlier recommendation).** The independence of all three disturbance pairs must be
WRITTEN in the model syntax: `M1 ~~ 0*M2`, `M1 ~~ 0*Y` and `M2 ~~ 0*Y`, either order within a pair (`M2 ~~ 0*M1`
accepted). This matches the parallel form (`M1 ~~ 0*M2` required) and is stricter than "omission means independent".

Refusals (class `medfit_sem_fiml_error`, `stage = "input"`):

| Written | Refused with |
|---|---|
| `M1 ~~ 0*M2` omitted (the other two written) | message naming the missing pair `M1 ~~ 0*M2` |
| `M1 ~~ 0*Y` omitted | message naming `M1 ~~ 0*Y` |
| `M2 ~~ 0*Y` omitted | message naming `M2 ~~ 0*Y` |
| two or three omitted | one message listing every missing pair |
| a pair written free (label-less `M1 ~~ M2`), labeled, bounded, tied or fixed nonzero | "correlated disturbances not supported" |
| a duplicate statement (either order counts as the same pair) | topology diagnostic |
| a `~~` between a mediator or outcome and an exogenous variable | topology diagnostic |

Each row is its own test (including each single omission, since a parser that only checks the first missing pair passes
a one-pair test). Messages are proposals (wording unverified).

**Rationale, rewritten and version-pinned.** In lavaan 0.7-3, `sem()` with `fixed.x = FALSE` adds no residual
covariance among the observed endogenous variables for these models. Probed 2026-11-09 (maintainer's grill probe, and a
second probe in this session) for the parallel model and for serial syntax, with and without missing data (`missing =
"ml"` with 20 injected NAs; listwise): 0 free `~~` rows between different variables in every fit. The earlier claim in
the parallel code comments and spec ("lavaan's default would free it") is therefore NOT true of 0.7-3. Whether lavaan
0.6.x frees the parallel `M1 ~~ M2` is **UNVERIFIED**; it is not checked here, and it must not be cited as fact. A
one-off recheck on lavaan 0.6.x is recommended before the claim is cited again (open question 6; the claim is in
`R/sem-fiml-interface.R` comments for the parallel parser). What the requirement does buy, independent of any lavaan
version: the written model is the same model in every software that either frees or fixes the covariance, and it
mirrors the parallel contract, so users learn one rule. A test pins lavaan's current behavior (0 free residual
covariances for the fitted syntax on 0.7-3) so a version change fails loudly; that test says what the installed
lavaan does, not what 0.6.x did.

## 2.3 What changes in the kernel versus the four-variable parallel case

Nothing in the dimension-generic functions changes: `.sem_fiml_prepare_core()`, `.sem_fiml_eval()`, geometry, Hessian,
`.sem_fiml_solve()`, `.sem_fiml_starts()`, `.sem_fiml_lower()` and `.sem_fiml_variance_index()` read the variable count and
variance positions from the tables and layout (per the earlier spec; not re-read function by function here). Already
exercised: `test-fiml-generic-kernel-fourvar.R` drives the internals with exactly the pure chain X, M1, M2, Y (table
labels `a`, `d`, `b`, `cp`, read at line 8; `q = 12`) against the rowwise reference, independent geometry and Hessian, and
lavaan (not re-run). So the chain's kernel path is already covered for k = 0 at the internals level; what is new is the
adapter, class and covariates.

| Component | Parallel (4 variables) | Serial (4 variables) |
|---|---|---|
| Tables builder | `.sem_fiml_tables_med(2L, direct, residual_covariance, k)` (read: it returns `.sem_fiml_tables_parcov(k, ...)` for k > 0) | new `.sem_fiml_tables_ser(direct, k, shortcuts)`; `.sem_fiml_tables_med()` and its output stay byte-identical (`identical()` against the frozen fixtures). Builder arguments that distinguish the variants: `shortcuts = TRUE` (saturated) adds the rows `M2 <- X` (`a2`) and `Y <- M1` (`b1`); `shortcuts = FALSE` (chain) omits both rows (no fixed-zero row, so `q` drops by two). Nothing else differs; `direct` and `k` keep their meaning |
| Rows of `a` (paths) | `M_j <- X`, `Y <- M_j`, `Y <- X` | saturated: `M1 <- X`, `M2 <- X`, `M2 <- M1`, `Y <- M1`, `Y <- M2`, `Y <- X`; chain: `M1 <- X`, `M2 <- M1`, `Y <- M2`, `Y <- X`; both plus `M1 <- Z_i`, `M2 <- Z_i`, `Y <- Z_i` for k >= 1 |
| Layout | `paths`, `variances`, `intercepts`; `covariances` empty for k = 0 | same four elements, `covariances` empty for k = 0 (no free residual covariance exists) |
| Transport | path unit `scale_resp / scale_pred`; intercept absorbs `-center_pred * unit` per path into its response | identical rule. Saturated: the M2 intercept absorbs three terms (`d1`, `a2`, covariate paths) and the Y intercept three (`b`, `b1`, `cp`). Chain: M2 two terms (`d1`, covariates), Y two (`b`, `cp`) |
| Variance indices | `vx vm1 vm2 vy` (+ covariate variances) | the same four names; positions found by name through the layout |
| Jacobian | `sum_j n_j log scale_j` | identical |
| RAM implied moments | `(I - B)^-1` with B lower-triangular fill from `M_j <- X`, `Y <- M_j` | same formula; B has the `M2 <- M1` entry (and, saturated, `M2 <- X`, `Y <- M1`); no code change expected because `solve(I - B)` is used (unverified for `.sem_ram` derivatives with the new entries; the four-variable internal test covers the chain entry set without shortcuts) |

### Parameter counts (Q1; derived, to be pinned by the adapter's tie check `q`)

Formula, with `direct` = 1 when `cp` is free, 0 when fixed: saturated `q = 13 + 5k + C(k+1,2) + direct`; chain
`q = 11 + 5k + C(k+1,2) + direct`. Each covariate adds three paths (to M1, M2, Y), one variance and one intercept, plus
the exogenous covariances `C(k+1,2)`. The base: saturated 5 paths + 4 variances + 4 intercepts = 13 (+ `cp`); chain
3 paths + 4 + 4 = 11 (+ `cp`). The tie check compares `conv$ram$q` to this formula per variant, as the parallel parser
does (read: `12L + 5L * k + choose(k + 1L, 2L) + direct + free_cov`).

| Variant | k | p | moments `p + p(p+1)/2` | q, `cp` free | q, `cp` fixed 0 | df free / fixed |
|---|---|---|---|---|---|---|
| saturated | 0 | 4 | 14 | 14 | 13 | 0 / 1 |
| saturated | 1 | 5 | 20 | 20 | 19 | 0 / 1 |
| saturated | 2 | 6 | 27 | 27 | 26 | 0 / 1 |
| chain | 0 | 4 | 14 | 12 | 11 | 2 / 3 |
| chain | 1 | 5 | 20 | 18 | 17 | 2 / 3 |
| chain | 2 | 6 | 27 | 25 | 24 | 2 / 3 |

Parameter names. Saturated k = 0: `a a2 d1 b1 b [cp] vx vm1 vm2 vy ix im1 im2 iy`. Chain k = 0: `a d1 b [cp] vx vm1 vm2 vy ix
im1 im2 iy`. With covariates the labels follow the parallel scheme (`gm1z1`, `gm2z1`, `gy` for k = 1; `gy1 gy2` and the
index on variances and intercepts for k = 2; exogenous covariances `cxz`, `cxz1 cxz2 cz1z2`). Parameter order in
`ram$par_names` is not part of the contract (transport is by name); the final order is unverified until the tables
exist.

**Identification differs by variant.** In the parallel model the independence restriction pins `Cov(M1, M2)` through the
structure, so a mask set in which M1 and M2 are never observed together can still fit. In the saturated serial model
every pair of kernel variables has a free covariance, so a mask set in which some pair is never jointly observed leaves
that covariance flat: the moment-geometry rank gate should fail closed at stage `numerical` (expected, to be pinned by a
test; the fixed-zero direct saturated variant may still identify the `X`-`Y` pair through its restriction, to be pinned,
not assumed). Fits that parallel FIML accepts can therefore be refused by saturated serial FIML on the same data; this is
correct and must be documented, not worked around (Q9). The pure chain restricts `Cov(X, M2)`, `Cov(X, Y)` (when `cp` is
fixed) and `Cov(M1, Y)` through the structure, so some never-jointly-observed pairs may still fit in the chain
(unverified; test it, and record which pairs fail closed per variant).

# 3. Effects and delta-method inference

## 3.1 Effects (all from the path system of the existing class)

Saturated, aliases `a, a2, d1, b1, b, c'`:

- chain indirect effect `nie` (default of `nie()`): `a * d1 * b`.
- total indirect effect `nie_total` (`nie(type = "total")`, tidy key `nie_total`): `a d1 b + a2 b + a b1`.
- direct effect `nde` = `c'`.
- total effect `te` = `c' + nie_total`, computed as `[(I - B)^-1]_{Y,X}` by `.serial_total_effect()` over the edges present
  in `@mediator_predictors` / `@outcome_predictors`.

Pure chain, aliases `a, d1, b, c'` (`c'` = 0 when fixed):

- `nie` = `a d1 b`; `nie_total` = `nie` (no other directed path exists; the key is still reported and the two rows are
  identical); `nde` = `c'`; `te` = `c' + a d1 b`.

Independent check: the path products are enumerated by hand (saturated: X-M1-M2-Y, X-M2-Y, X-M1-Y, X-Y; chain:
X-M1-M2-Y, X-Y); the matrix form and the enumeration must agree to 1e-12.

## 3.2 Which covariance block is needed

Saturated: the full `6 x 6` block over `(a, a2, d1, b1, b, c_prime)`, from the fitted observed-information covariance (not
from separate regressions). Chain: the `3 x 3` block over `(a, d1, b)` extended to `4 x 4` with `c_prime` when free; a
fixed `c_prime` has a zero row and column. Gradients (derived here, to be asserted against an independent derivation):

| Effect | Variant | Gradient over the block |
|---|---|---|
| `nie` | both | over (a, a2, d1, b1, b, c'): (d1 b, 0, a b, 0, a d1, 0); chain over (a, d1, b, c'): (d1 b, a b, a d1, 0) |
| `nie_total` | saturated | (d1 b + b1, b, a b, a, a d1 + a2, 0) |
| `nie_total` | chain | equal to the chain `nie` gradient |
| `nde` | both | 1 on `c'`, 0 elsewhere |
| `te` | saturated | `nie_total` gradient with 1 for c' |
| `te` | chain | `nie` gradient with 1 for c' |

Equation structure explains which cross terms matter. Saturated: `a` in the M1 equation; `a2` and `d1` in the M2 equation;
`b1`, `b`, `c'` in the Y equation. Chain: `a` in M1, `d1` in M2, `b` and `c'` in Y.

- Complete data: the log-likelihood factors over equations, so the observed information, and the transported covariance,
  is exactly block diagonal across equations, and within an equation it is the ML OLS covariance (`sigma_ML^2 (Z'Z)^-1`).
  The chain `nie` SE then involves no cross terms (its three factors sit in three equations). Saturated `nie_total` and
  `te` still need `Cov(a2, d1)`, `Cov(b1, b)`, `Cov(b1, c')`, `Cov(b, c')`. For the pure chain, `te` needs only
  `Cov(b, c')` besides the three diagonal terms (`b` and `c'` share the Y equation).
- Incomplete data (MAR/MCAR): the cross-equation blocks become nonzero, so the chain `nie` SE also depends on
  `Cov(a, d1)`, `Cov(a, b)`, `Cov(d1, b)`. These are the FIML-specific terms and exactly what a separate-regression
  (lm-style) extraction drops. Their size is data-dependent (unverified).

## 3.3 Reuse versus a subclass

**Recommendation: one new internal subclass `FIMLSerialMediationData` of `SerialMediationData` (one class, both
variants; a `variant` property, values `"saturated"` and `"chain"`, also recorded inside `fit_context` so the hash
binding covers it and the validator requires the two to agree; question 5).** Same property `fit_context`, validator
mirroring `FIMLParallelMediationData` (source and parameter hashes, `method = "fiml"`, `x_policy = "random"`, `n_obs`,
`source_package = "medfit"`, the data hash), with differences: the sequential mediator order is checked
(`identical(vars[2:3], mediators)`, not `setequal`), `ctx$structure` must equal `"serial"`, and the validator checks
the stored alias vector, predictor lists and `variant` agree (chain: no `a2`/`b1` alias, `M1` absent from
`@outcome_predictors`, `X` absent from M2's predictors; saturated: both present). S4-registered in `R/zzz.R` next to the
other two (read: `S4_register(FIMLMediationData)` and `FIMLParallelMediationData` at lines 60-61). It inherits `nie`,
`nde`, `te`, `coef`, `vcov`, `nobs`, `.effect_gradients()` (through `S7_inherits(x, SerialMediationData)`, so the chain
gradient and `.serial_te_gradient()` are reused) and the serial tidy/confint bodies.

Rejected: reusing `SerialMediationData` unchanged. It has no `fit_context`, so the stage-0 provenance binding, the
`.sem_fiml_is()` test that makes every downstream consumer refuse bootstrap, `pm()` and `glance()`, and the origin rule
cannot attach; it would also look identical to a separately fitted lm/glm chain, whose `@vcov` has zero cross-equation
covariance. Rejected: two classes (one per variant): duplicates the validator and every refusal site for an alias-vector
difference.

Changes needed on inherited behavior (gaps found by reading the code; none of them exists for serial today):

1. `pm()` on a serial object has no `.sem_fiml_refuse()` call (`generics-effects.R`, the serial method calls
   `.serial_pm_from_total()` directly); the simple and parallel methods refuse. The subclass must refuse.
2. `.glance_serial_mediation_data()` has no `.sem_fiml_refuse()`; add it (simple and parallel glance have it).
3. `confint(parm = "effects")` for serial returns `nie`, `nde`, `te` only, so the reported `nie_total` has no interval.
   The FIML serial `confint(parm = "effects")` must also return `nie_total` for both variants (delta gradient from
   section 3.2; for the chain it equals the `nie` row), tested against the gradient built from the full extracted
   covariance and against `tidy(conf_int = TRUE)` for the same effect, with a planted defect that drops its row.
   `confint()` for `SerialMediationData` has no FIML branch: `method = "boot"` stops with the lm/glm advice ("call
   bootstrap_mediation() directly"), which is wrong advice for FIML; the effects warning says "consider
   bootstrap_mediation()"; and there is no origin guard. Add the FIML branch (refuse boot through `.sem_fiml_refuse`,
   FIML warning text, origin NA, note attribute), as in the parallel and simple methods.
4. `.sem_fiml_is()` must include the new class (read: it today tests `FIMLMediationData` or `FIMLParallelMediationData`
   plus the `SEMFit` branch); `bootstrap_mediation(mediation_data =)` then refuses it through the existing
   `.sem_fiml_refuse()` calls.
5. **Path rows per variant (Q4: all estimated paths).** `paths()` for a two-mediator serial object returns `a, d, b,
   c_prime` only (read: `R/methods-tidy.R` line 276 builds the serial tidy alias vector `a, d1.., b, c_prime`), so a
   `tidy()` of the saturated FIML object would hide the two estimated shortcut paths. The subclass `paths()` returns per
   variant:
   - saturated: `a, a2, d, b1, b, c_prime` (tidy alias vector `a, a2, d1, b1, b, c_prime`);
   - chain: `a, d, b` plus `c_prime` when free (tidy alias vector `a, d1, b[, c_prime]`).

   The chain list coincides with what the existing serial tidy already builds; the saturated list does not.
   **Contract (Codex adversarial review, 2026-11-09, carried over to both variants):** both consumers (`tidy()` and
   `confint(parm = "paths")`) must map every displayed path to a covariance row (alias rows first, error instead of
   guessing, as `.path_se()` does), never recycle fewer SEs over more estimates. Test every displayed path's SE and
   interval against the extracted `@vcov` diagonal, for `tidy()` and for `confint(parm = "paths")`, in both variants
   (six rows saturated; three or four rows chain); plant a defect that returns four aliases for the saturated object
   and require it to fail. Open point (question 2): for a fixed-zero direct path the chain list omits `c_prime` (as Q4
   reads, "+c_prime if free") but the existing simple/parallel FIML `paths()` always lists `c_prime` (comment at line
   203 of `R/methods-tidy.R`; behavior with a fixed zero unverified).

## 3.4 Exact-origin NA rule (Q8: per effect)

Existing rule (read: `.sem_fiml_origin()`, `R/sem-fiml-interface.R` line 545): returns one boolean (simple: `a == 0` and
`b == 0`; parallel: every `a_j` and `b_j` zero; anything else, including every serial object, `FALSE`); callers set only
`se["nie"]` to `NA`, with the note "NIE inference unavailable: zero delta gradient" (`R/methods-tidy.R` lines 345 and
372). The NIE delta gradient is zero only at an exact origin, where the delta SE would be exactly 0 and misleading.
Fits never produce exact zeros; the rule is reachable on constructed objects only. For serial two rules, one per effect:

- Chain `nie` = `a d1 b`: the gradient `(d1 b, a b, a d1)` is all zero if and only if **at least two** of `a`, `d1`, `b`
  are exactly zero. One exactly-zero factor leaves a nonzero gradient (for `a = 0`: `(d1 b, 0, 0)`), so the SE stays
  finite and must not be set to `NA`.
- Total indirect `nie_total` (key `nie_total`), saturated: the gradient is zero if and only if `a = a2 = b = b1 = 0`
  (`d1` unrestricted: `b = 0` from the `a2` component, `a = 0` from the `b1` component, then `b1 = 0` from the `a`
  component and `a2 = 0` from the `b` component). Withhold its SE only then.
- **Pure chain: `nie_total` = `nie`, so one rule:** both rows are withheld together when at least two of `a`, `d1`, `b`
  are exactly zero, and neither otherwise. (The saturated rule must not be applied to a chain object: `a2` and `b1` do not
  exist there; applying it would withhold nothing at `a = d1 = 0`.)
- `te` and `nde` are never withheld (`c'` has gradient 1).

The helper `.sem_fiml_origin()` becomes per effect for the serial class: it returns a named logical `c(nie, nie_total)`
chosen by `variant`, and the three call sites (`.tidy_paths_effects`, the two existing `confint()` methods plus the new
serial one) apply the right key. Off-by-one-factor bugs are the expected defect (planted defects D12, D13, D22 below; the
`[0,0]` interval defect class fixed in #383 is the precedent).

## 3.5 Inference scope and the stage-0 guard

Delta-method Wald intervals through `tidy()` and `confint(method = "normal")` stay available, as for every prior FIML
variant. Bootstrap intervals are withheld: `bootstrap_mediation(source_fit =)`, both methods, hits the stage-0 guard first
(`medfit_error_fiml_inference_unavailable`); with the guard mocked open the serial fit must still be refused before any
RNG draw or refit by a new class `medfit_error_fiml_serial_source_fit` (section 4.4), for both variants. No source-fit
interval exists for this family until its own admission.

# 4. Naming, extraction and refusals

## 4.1 Structure detection, variant detection and names

`.sem_fiml_model()` today routes by variable count: `length(x) %in% 1:3` with `length(roles$obs) == length(x) + 3L` goes
to `.sem_fiml_model_par()`, whose first topology check refuses an `M ~ M` regression as "unsupported FIML topology or
correlated disturbances" (router lines 17-70 and the parallel parser at line 140, read). The serial router goes in front
of it, and the structure router change belongs to slice S1 (section 5):

1. Exactly one outcome (the only left-hand side that is never a right-hand side) and two other endogenous variables.
   A regression between those two endogenous variables selects the serial parser; no such regression selects the
   existing parallel parser unchanged; both directions present is a cycle and is refused.
2. **Variant detection inside the serial parser.** Let `A` = the number of exogenous variables absent from M2's equation
   and `S` = whether `Y ~ M1` is written.
   - `A = 0` and `S` present: saturated.
   - `A = 1` (k = 0: X absent from M2; k >= 1: exactly one exogenous variable absent, and it is X) and `S` absent: chain.
   - every other combination (`A = 0` with `Y ~ M1` absent; `A = 1` with `Y ~ M1` present; `A >= 2`): refused with a
     topology diagnostic naming the partial shortcut set. For k >= 1 in the chain, "X" is structurally the one
     exogenous variable with no path to M2; the saturated `X` rule (fixed-zero Y path, else first by appearance) applies
     only to the saturated variant.

Names: kernel `X`, `Z`/`Z1 Z2`, `M1`, `M2`, `Y`; data names stay in the adapter's `spec$vars`, `spec$mediators`,
`spec$covariate`. `M1` is the mediator with no mediator among its predictors, `M2` the other; this is structural, not
order of appearance (the parallel rule is order of appearance). New spec fields `spec$structure = "serial"` and
`spec$variant`. Every consumer that today tests `!is.null(spec$mediators)` (table selection in `.sem_fiml_syntax()`,
`.sem_fiml_extract()` dispatch through `likelihood$mediators`, `.bootstrap_fiml()`) must branch on `structure` and then
on `variant`, because serial also has two mediators and would otherwise be built with the parallel tables (planted
defects D8, D17). The `likelihood` list records `structure`, `variant` and `mediators` in sequential order. The table
call is `.sem_fiml_tables_ser(direct, k, shortcuts = (variant == "saturated"))`.

## 4.2 Extraction rules

`extract_mediation(fit, treatment = X, mediator = c(m_first, m_second))`:

- `mediator` must name both fitted mediators in structural order (length 2, `m_first` then `m_second`). **Reversed order
  is refused (Q7)** with a classed error that names the fitted order; it is not reordered: it asks for a different model
  (M2 -> M1).
- `structure` accepts `"auto"` or `"serial"` for a serial fit; `"parallel"` is refused (and `"serial"` stays refused for
  a parallel fit, as QA verified).
- `decomposition` accepts `"auto"` or `"two_way"`; `standardized`, `interaction`, `outcome` other than Y, unknown
  arguments, a single mediator, a non-fitted or repeated mediator, a covariate named as mediator: refused.
- **Treatment, saturated variant (Q6: a covariate may be the treatment).** Follows the covariate precedent (FI-G1, FI-G2
  slices 3-4): with `cp` free any exogenous variable may be named the treatment (the kernel is symmetric in the exogenous
  block); a covariate named the treatment takes `a = gm1z_i`, `a2 = gm2z_i`, `c_prime = gy_i`, with `d1`, `b1`, `b`
  unchanged; with one Y path fixed at 0 that variable is the only valid treatment.
- **Treatment, chain variant: provisional refusal, needs a maintainer decision (question 1).** The chain is not
  symmetric in the exogenous block: X has no path to M2, but every covariate does (and to Y). Naming a covariate `Z` the
  treatment would give it a free `Z -> M2` path (`gm2z`, an `a2`-type path that the chain does not contain for `X`) and
  would silently change which effects `nie_total` stands for (`nie_total != nie` for `Z`) while the stored variant says
  chain. Recommendation: the chain's treatment is structural (the exogenous variable with no M2 path); naming a
  covariate is refused with `medfit_error_fiml_extract_unsupported`. This departs from the literal reading of Q6 for the
  chain at k >= 1 only, and is flagged so the maintainer can overrule it (the alternative is to extract such a covariate
  with `a2 = gm2z`, `b1 = 0` fixed, `variant = "chain-covariate-treatment"`, a third effect rule).
- Output `FIMLSerialMediationData`: `a_path`, `d_path` (scalar `d1`), `b_path`, `c_prime`; `@estimates` carries the alias
  names for the variant (saturated `a a2 d1 b1 b c_prime`, needed: `.serial_path_system()` returns "no coefficient ... is
  stored" and `te()` becomes `NA` with a warning if a present skip edge has no stored coefficient; chain `a d1 b`
  and `c_prime`); `@vcov` is the alias block of the variant (`6 x 6` saturated; `3 x 3` or `4 x 4` chain), full
  cross-block from the fitted covariance, a fixed-zero or omitted `c_prime` a zero row and column; `@mediator_predictors`
  lists, for M1 `X` (+ covariates), for M2 saturated `X`, `M1` (+ covariates) and chain `M1` (+ covariates);
  `@outcome_predictors` lists saturated `M1`, `M2`, `X` (+ covariates), chain `M2`, `X` (+ covariates), so every present
  and every absent edge is recorded; `sigma_mediators`, `sigma_y` from the variances.
- `fit_context` carries `structure`, `variant`, `mediators` (sequential), covariates, the source hashes (as parallel), and
  provenance for the binding.
- Name collision hazard: parallel and serial both use the strings `a2`, `b1`, but with different roles in the extraction
  (`a1 a2 b1 b2` versus `a a2 d1 b1 b`). The extractor must be selected by `structure`, never by presence of an alias.

## 4.3 Refusals at fit

All fit refusals are class `medfit_sem_fiml_error` (`stage = "input"`; numerical failures `stage = "numerical"` with
attempts retained). Messages below are proposals (wording unverified); the class and the condition are the contract.

| Condition | Refused with |
|---|---|
| three or more mediators; a mediator not affected by X; a mediator that does not affect Y; mediator affecting X; a cycle (`M1 ~ M2` and `M2 ~ M1`) | topology diagnostic (class above) |
| partial shortcut set: `X -> M2` without `M1 -> Y`, or `M1 -> Y` without `X -> M2` (section 4.1, variant detection) | topology diagnostic naming the partial set |
| absent `M1 -> M2`, absent `X -> M1`, absent `M2 -> Y` (partial chain) | topology diagnostic naming the missing path |
| a fixed, labeled, bounded or tied `a2` or `b1` | "shortcut paths are free or absent" |
| residual-independence statements: an omitted pair, a free, labeled, nonzero or duplicated one, or one tied to an exogenous variable (section 2.2, one row per case) | the section 2.2 messages |
| fixed value other than `Y ~ 0*X`; `lower()`, `start()`, constraints, `:=`, ties (`q` mismatch against the per-variant formula), labels that tie | as for prior variants |
| covariates: three or more; a covariate with no path to M1, M2 or Y; at k >= 1 an omitted Y path from any exogenous variable (Q3); two or more fixed Y paths; partial exogenous covariance set; fixed or fixed-zero covariate paths; chain: zero or two or more exogenous variables absent from M2 | as FI-G1 / FI-G2 slices 3-4, plus the chain rule |
| `fixed_x` not explicit `FALSE`, weights, `control`, `information`, `se_type`, `meanstructure`, `n_starts` | as for every FIML fit |
| observed variables: interaction `:`, non-numeric, non-finite, all-NA columns, fewer than 2 observed values, zero scale | as for every FIML fit |
| non-identified masks (rank-deficient geometry, including a pair never jointly observed), no accepted candidate per solver, disagreeing likelihoods, ill-conditioned information | `stage = "numerical"` (Q9: the existing rank gate; no bespoke pre-check) |

**Direct-path policy (Q3).** k = 0: `Y ~ X` free, `Y ~ 0*X`, or omitted (= fixed 0), as in the three-variable and
parallel forms, in both variants. k >= 1: every exogenous variable has a written Y path (free; at most one fixed at
exactly 0 and, in the chain, only X's), as in FI-G1 and FI-G2: an omitted Y path is ambiguous with a covariate acting on
the mediators only, so it is refused.

## 4.4 Refusals at extract and source fit

- Extract: class `medfit_error_fiml_extract_unsupported`, message pattern as the parallel form ("FIML extraction supports
  only the fitted unstandardized two-way serial mediation naming both mediators in order").
- Consumers refuse a serial FIML object as they refuse simple and parallel ones: `pm()`, `glance()`, `quick()`,
  `confint(method = "boot")`, `bootstrap_mediation(mediation_data =)`, `bootstrap_mediation(data =)`, `mbco_sem`,
  `compare_lr`, `anova`, AIC/BIC on the extracted object. `pm()` and `glance()` need the new `.sem_fiml_refuse()` calls
  (section 3.3).
- Source fit: the order in `R/bootstrap-fiml.R` is unchanged: the stage-0 guard first, then the covariate refusal
  (`medfit_error_fiml_covariate_source_fit`, which a serial fit with covariates still triggers by precedent), then a
  structure refusal. New class `medfit_error_fiml_serial_source_fit` for a serial fit without covariates (either
  variant), raised before any RNG draw or refit, for both methods (parametric and nonparametric). The existing parallel
  refusal must not fire for a serial fit (it tests `spec$mediators`, which is set for serial too; section 4.1).
- Merge condition R4: before any slice merges, tests show that every still-unadmitted topology, variant and policy is
  refused at fit, extract and both source-fit methods (including: slices not yet merged, for example the chain while only
  the saturated variant is public, and k = 1 and 2 while only k = 0 is public).
- Gate refusal probes (R4 count, must stay 0): two existing probes change meaning once serial is admitted. The `serial`
  probe (`M1 ~ X`, `M2 ~ M1`, `Y ~ M2 + X`, read in `tests/sim/sem-fiml-ext-gate.R`) is the chain with a free direct path
  and no residual zeros, so it stays refused, now for the omitted-zeros reason (Q2); `parallel_covariate_serial` (the
  saturated-like set with `M1 ~~ 0*M2` only) stays refused for omitted zeros as well. Keep both, relabel them as Q2
  probes, and add probes for the partial shortcut set, a reversed-order extraction, each single omitted zero, a free
  serial residual covariance, and (until its slice is merged) each not-yet-public variant.

# 5. Slices and variant counts

The registry after amendment: six serial variants (saturated and chain, each with zero, one or two covariates), twelve
policy cells (variant x direct policy: free, fixed at 0). FI-G2 slices 3-4 (parallel with covariates) are the template:
tests first (red commit), then the feature commit per slice, a frozen-table fixture captured before the slice, QA per
slice, the V14 parity run once per slice (Q10).

| Slice | Public variants after the slice | q (direct free / fixed 0) | Notes |
|---|---|---|---|
| S0 | none | n/a | freeze fixture `fiml-tables-before-g3s1.rds` from the base commit: every table shape reachable through public entry points (the earlier fixtures hold 8 and 10 shapes; shape count to be taken from the code) |
| S1 | saturated, k = 0 | 14 / 13 | the router change (section 4.1, including variant detection and the chain/partial-shortcut refusals), `.sem_fiml_tables_ser(direct, k, shortcuts)` with both values implemented but the chain not yet reachable from the public entry points, parser (`spec$structure`, `spec$variant`), class with the `variant` slot, extraction, per-effect origin helper, Q2 refusals, all section 3.3 edits |
| S2 | + chain, k = 0 | 12 / 11 | chain parser branch enabled, chain extraction, chain effect rules and origin rule, chain oracles and planted defects; reuses S1 machinery, so the diff is small and the evidence is per-variant |
| S3 | + saturated and chain, k = 1 | sat 20 / 19; chain 18 / 17 | `.sem_fiml_tables_ser(direct, 1L, shortcuts)`; FI-G1 exogenous-covariance rules; covariate-as-treatment mapping (saturated; chain per question 1) |
| S4 | + saturated and chain, k = 2 | sat 27 / 26; chain 25 / 24 | same builder, `k = 2`, `.sem_fiml_par_cov_max()`-style limit for serial |

Leaner order, and why. The task's reference order (S1 sat k = 0, S2 sat k = 1, S3 sat k = 2, S4-S6 chain k = 0..2) gives
seven PRs. This spec proposes five (S0 plus four): the chain k = 0 immediately after the saturated k = 0, because the
router, class and refusal logic change once in S1 and the second shortcut state is proven where it is cheapest to
debug (no covariates, df = 2, the one variant whose kernel path is already covered at the internals level); the
covariate slices then add one covariate count for both variants, because the covariate code (exogenous covariance block,
`gm1z gm2z gy` rows, transport) is the same code and is variant-independent by construction (the `shortcuts` flag only
toggles two rows). Cost: S3 and S4 are larger PRs and need per-variant QA verdicts inside one slice; fallback: split
S3 and S4 per variant (seven PRs) if QA finds the evidence too large to review. The parity run (V14) is once per slice,
about ten background minutes each (ledger Q10).

One PR per slice, each to `dev` only on the maintainer's instruction (feature branch workflow; the Hopper freeze caveat:
cut the Hopper harness commit on `ba50f998`, not on a later `dev`). Public variants total after S4: six; policy cells
twelve; registry after amendment: 14 variants, 28 policy combinations.

# 6. Verification design (admission checklist, per slice)

Independent oracles; production helpers appear only as the code under test. Tolerances follow the earlier slices.
Column "V" = variant: S saturated, C chain, both.

| # | V | Item | Oracle | Tolerance |
|---|---|---|---|---|
| V1 | both | estimates, observed-information covariance, logLik, n | lavaan 0.7-3 raw-data FIML (`missing = "ml"`, `fixed.x = FALSE`, observed information), both direct policies, MCAR, MAR, sparse masks including an all-NA row, all fifteen masks present. Saturated syntax as section 2.1; chain syntax `M1 ~ X`, `M2 ~ M1`, `Y ~ M2 [+ X]` with the three residual zeros written | estimates 1e-5, vcov normalized 1e-3, logLik 1e-6 |
| V2 | both | indirect effects and SEs | lavaan `:=`. Saturated: `ind1 := a*d1*b`, `ind_tot := a*d1*b + a2*b + a*b1`, `te := ind_tot + cp` (free direct) or `te := ind_tot` (fixed-zero direct, a literal zero; no `cp` label exists). Chain: `ind1 := a*d1*b`, `te := ind1 + cp` (free) or `te := ind1` (fixed-zero); `nie_total` is compared to `ind1` | 1e-5 estimates, SE relative 2e-3 |
| V3 | both | complete-data neutrality | `lm` equation by equation. Saturated: `M1 ~ X [+Z]`, `M2 ~ M1 + X [+Z]`, `Y ~ M1 + M2 + X [+Z]` (free direct; fixed-zero direct: the Y regression omits X). **Chain: `M1 ~ X [+Z]`, `M2 ~ M1 [+Z]` (no X), `Y ~ M2 [+ X if free] [+Z]` (no M1).** Exogenous ML covariance, ML residual variances (`mean(r^2)`), means; plus `vcov` exactly block diagonal across equations with ML-OLS within-equation blocks. (The chain's likelihood factors over equations for any regressor set, so equation-wise ML is exact despite the overidentification) | 1e-7 (1e-6 for blocks) |
| V4 | S only | saturation identity (free direct) | unrestricted multivariate normal FIML (all moments free) in lavaan or an independent EM, mapped to the recursive parameters by recursive regressions from the moments: the serial FIML estimate must equal it, the logLik must equal the unrestricted logLik. Does NOT apply to the chain | estimates 1e-5, logLik 1e-6 |
| V5 | both | fixed-zero direct df | saturated: LR against the unrestricted logLik equals the lavaan chi-square for `Y ~ 0*X` (df 1). Chain: see V16 | 1e-5 |
| V6 | both | rowwise likelihood, independent Hessian and moment geometry | adapt the `gk_*` / `gk4_*` references with `a2`, `b1` (saturated) and without them (chain; the existing four-variable test is already the chain, k = 0) | value 1e-8, gradient 1e-6 |
| V7 | both | OpenMx supporting cells | mxTryHard, status 0, at least: saturated k = 0 free, saturated k = 1 fixed-zero, chain k = 0 free, chain k = 2 MAR; est 1e-5, vcov relative 1e-3 | est 1e-5, vcov rel 1e-3 |
| V8 | both | hand delta SEs | from extracted `@vcov`. Saturated: chain `nie` (3 x 3 block), `nie_total` (5 x 5), `te` (6 x 6). Chain: `nie` (3 x 3), `te` (4 x 4), `nie_total` row equal to the `nie` row; all equal to `tidy()` to 1e-12; path enumeration equals `[(I-B)^-1]_{Y,X}` to 1e-12 | 1e-12 |
| V9 | both | covariate/path confusion | DGP with large, distinct covariate effects on M1, M2 and Y, treatment named as X and (saturated only) as each covariate, lavaan with the label moved; reversed-mediator extraction refused (Q7); chain: naming a covariate as treatment refused (question 1) | 1e-7 lm, 1e-5 lavaan |
| V10 | both | near-boundary and identification | residual correlations or `M2 ~ M1` near deterministic, n = 25 to 500, complete and 20% MCAR, a pair never jointly observed (record, per variant, which pairs fail closed: expected saturated refuses more than chain, unverified), weak `a` with `d1`, `b` near 0: every outcome is a fit that agrees with lavaan where lavaan converges, or a classed `medfit_sem_fiml_error`; no silent boundary solution | fail-closed check |
| V11 | both | refusals | every row of sections 2.2, 4.3 and 4.4 at fit, extract, both source-fit methods (guard closed, and guard mocked open for the structure class), per variant | class and condition exact |
| V12 | both | exact origin | forged objects with the fit-context hash rebound. Saturated: `a = d1 = 0` withholds chain `nie` SE; `a = 0` only keeps it finite and equal to the hand value; `a = a2 = b = b1 = 0` withholds `nie_total`; near-origin controls keep finite SEs. **Chain: `a = d1 = 0`, `a = b = 0` and `d1 = b = 0` each withhold both `nie` and `nie_total`; `a = 0` alone keeps both finite and equal to the hand value; `te` never withheld.** Tampering without rebinding the hash is rejected by the validator | exact / 1e-12 |
| V13 | both | frozen tables | fixture from S0: tables for every earlier shape `identical()` to the current builders and to the base-commit source | `identical()` |
| V14 | both | stage-0 simple model parity (R2), once per slice (Q10) | two installs (branch and `dev`), all earlier shapes x four datasets (MAR, MCAR 30%, MAR, complete), `identical()` on theta, vcov, logLik, nll, attempts, n, tidy effects, extracted vcov | bit identical |
| V15 | both | `fiml-ext` gate rows | section 6.2 | section 6.2 |
| V16 | C | chain restriction test | LR = 2 (logLik of the medfit saturated fit with `cp` free minus logLik of the chain fit) equals the lavaan chi-square of the chain fit with `missing = "ml"` (lavaan's baseline is its own unrestricted H1) with df 2 (free direct) or 3 (fixed-zero direct), the df taken from `q` against the moment count and equal to lavaan's df; the LR is nonnegative and equal for the two direct policies' nesting (`logLik(chain, cp free) >= logLik(chain, cp fixed)`). Also: with a DGP whose `a2` and `b1` are 0 the chain and saturated estimates agree up to sampling error; with a DGP whose `a2` is large the chain LR is large (the test can fail) | 1e-5 on the chi-square; exact df |
| V17 | both | variant routing | the same data and the two syntaxes are routed to the two variants; a saturated syntax never produces a chain object and conversely; the `variant` slot matches the fitted `q` | exact |

## 6.1 Planted defects

Each needs a positive control (the unmutated copy passes the battery) and must fail at least one test; the battery must
include incomplete cells (the cross-equation defects are invisible on complete data) and cells with distinct large path
values. D1-D16 apply to the saturated variant (and to the chain wherever the component exists); D17-D23 are the
variant-specific additions.

| ID | Defect | Why it needs care |
|---|---|---|
| D1 | `d1` and `b` swapped in the path rows or extraction | the chain `nie` estimate `a d1 b` is invariant to a `d1`/`b` swap; only the path rows, `nie_total`, `te` and the SEs expose it. In the chain `nie_total` and `te` are also invariant under a consistent swap of estimate and variance, so it shows only in the path rows and their SEs; the DGP needs `d1 != b` and unequal SEs |
| D2 | `a` and `a2` swapped | changes `nie_total`, `te` (saturated) |
| D3 | `b1` aliased to `c_prime` (or `c'` taken from `b1`) | shortcut-path confusion |
| D4 | omitted shortcut: `a2 b` and `a b1` dropped from `nie_total` / `te` (plan-mandated) | chain `nie` unchanged; saturated only |
| D5 | cross-equation covariance blocks zeroed in the extracted `@vcov` (lm-style) | invisible on complete data (blocks are zero there); caught only by MAR/MCAR cells |
| D6 | within-equation covariance zeroed (diagonal only) | `Cov(a2, d1)`, `Cov(b1, b)` drive `nie_total` and `te` (saturated); `Cov(b, c')` drives chain `te` |
| D7 | wrong chain gradient: parallel-style `(b, a)`, a gradient missing `d1`, or components permuted | both variants |
| D8 | serial fit built with the parallel tables or extracted by the parallel extractor | `structure` branch missing; the shared alias strings `a2`, `b1` make this fail silently |
| D9 | mediator order taken by appearance instead of structure | |
| D10 | transport: the M2 intercept does not absorb `-center_M1 * unit(d1)`, or the Y intercept loses the `b1` term (saturated) or the `b` term (chain) | |
| D11 | covariate named treatment: `a2` from `gm1z`, wrong covariate index, `c'` from the wrong `gy` | as parallel D; saturated |
| D12 | origin rule too broad: SE withheld when a single chain factor is 0 | |
| D13 | origin rule too narrow or missing for `nie_total`; or `te` withheld | |
| D14 | `pm()` or `glance()` not refused for the serial class; `confint(method = "boot")` giving the lm/glm advice | |
| D15 | serial source-fit not refused (guard mocked open) or refused with the parallel class | |
| D16 | exogenous covariance block dropped from the tables | as FI-G1 |
| D17 | variant routed wrongly: a chain syntax fitted as saturated, or conversely; `shortcuts` flag inverted | caught by V17, V16 and the `q` formula |
| D18 | pure chain with `a2` or `b1` accidentally freed (rows present, `variant = "chain"`) | the chain logLik equals the saturated logLik (LR = 0), df 0 instead of 2, `q` formula fails, V16 |
| D19 | saturated variant with `a2` or `b1` wrongly fixed at 0 or dropped (a hidden chain) | V4 (saturation identity) and V1 fail: the logLik drops below the unrestricted one; chain-shaped tables with a saturated label |
| D20 | chain `d1` and `b` rows swapped in the tables or in the alias vector (as D1 for the chain) | only the path rows and their SEs expose it; V3 equation-wise OLS catches it directly |
| D21 | chain gradient wrong: `nie_total` taken from the saturated gradient formula with absent `a2`, `b1` read as 0 but with stale storage, or the chain `te` gradient missing the `c'` entry | V8 |
| D22 | chain origin rule uses the saturated rule (`a = a2 = b = b1 = 0`) so `a = d1 = 0` does not withhold; or withholds only `nie`, not `nie_total` | V12 |
| D23 | chain extraction records `M1` in `@outcome_predictors` or `X` in M2's predictors (storage says saturated, estimates say chain): `te()` then reads a missing coefficient | `te()` becomes `NA` with a warning or a wrong total; V8, V17 |

## 6.2 `fiml-ext` gate arithmetic (verified against the code, not copied)

Read in `tests/sim/run-gates.R` (the `"fiml-ext"` branch) and `tests/sim/sem-fiml-ext-gate.R`: the gate has 8 structures
(`cov1`, `cov2`, `par_ind`, `par_free`, `parcov1_ind`, `parcov1_free`, `parcov2_ind`, `parcov2_free`) x 2 seeds (`4111`,
`7219`) x 8 checks (`estimates`, `covariance`, `likelihood`, `retained`, `provenance`, `nie_estimate`, `nie_se`, `guard`)
plus one row (`refusals:unadmitted_accepted`) = 8 x 2 x 8 + 1 = 129, matching `tests/sim/gates.csv` (`fiml-ext`, 129). The
earlier draft figure `11 x 2 x 8 + 1 = 177` is arithmetically correct for 11 structures but does not describe this
gate: 11 is the registry's 11 variants, the gate has 8, and it also does not count the serial variants.

With six serial structures added (`ser_sat0`, `ser_sat1`, `ser_sat2`, `ser_chain0`, `ser_chain1`, `ser_chain2`): 14
structures x 2 x 8 + 1 = **225** rows. Direct policy: every current structure's DGP and model fits a free direct path
(read in `make_data` and `models`); no structure fits a fixed-zero direct path, so the gate today reports only the free
policy, with the fixed-zero policy covered by the unit and QA tests (V1-V5, V16). Two options: (A) follow the precedent,
gate rows for the free policy only: 225; (B) add a fixed-zero structure per serial variant (six more): 20 structures x
2 x 8 + 1 = 321 rows, and record each policy at its own granularity as the plan's admission rule asks (question 3).
Recommendation: A, with the fixed-zero cells in the V-tests and revisited at admission. Either way: update
`expected_rows` in `gates.csv` and the `expected` vector and the "eight structures" message in `run-gates.R`, extend the
mutants column (`wrong_unit|no_offset|swap_b|dropped_cov|missing_guard|parcov_drop_path|parcov_orthogonal|driver`) with
serial mutants (for example `ser_swap_db`, `ser_drop_shortcut`, `ser_chain_free_shortcut`), and add a `structures.csv`
row for the serial family (the existing row is "bounded random-X FIML with covariates"; the format beyond that line is
unverified). The refusal count (currently nine probes) grows with the probes of section 4.4 and must stay 0.

# 7. Docs to change

Roxygen/Rd and prose (generated `.Rd` through `devtools::document()`): `R/fit-sem.R` (the "Bounded FIML" section, which
today ends "Serial mediation ... stay refused"), `R/aab-generics.R` (`extract_mediation()` FIML paragraph), the
`SerialMediationData` mention in `R/classes.R` only if the subclass is documented; `R/sem-syntax-help.R`
(`?"medfit-syntax"` FIML rows, unverified whether FIML syntax is tabulated there); `NEWS.md`; `.STATUS`; the plan file's
FI-G3 entries and the registry amendment (section 1.2). Articles that mention parallel FIML and need the serial
counterpart or an update of the "refused" lists (grep hit, content not read): `vignettes/articles/native-guide.qmd`,
`extraction.qmd`, `models.qmd`, `model-native-multi.qmd`, `example-gpa.qmd`, `methods.qmd` (add the Bounded FIML serial
formulas: chain and total indirect gradients for both variants, the saturation note for the saturated variant, the
overidentification and df for the chain, the origin rule). `tests/testthat/test-guide-native-fiml.R` quotes error
messages of the pages and must be extended for every new message the guide quotes. Docs state: both variants and when to
use which (the chain is a restriction that the data can reject, the saturated graph is a reparameterization of the
saturated model); the three residual zeros must be written and the lavaan rationale of section 2.2 with its version;
identification is stricter for the saturated variant (pair never jointly observed); `nie` is the chain only and
`nie_total` the sum of all indirect paths (equal in the chain variant); bootstrap and `pm()` unavailable.

# 8a. Maintainer decisions (grill, 2026-11-09)

Ledger: `planning/GRILL-fiml-serial-FI-G3-2026-11-09.md`. Where this section conflicts with sections 1-7 or the recommendations in section 8, this section wins. In short: Q1 admit the saturated graph AND the pure chain (overrides); Q2 require all three residual zeros written (overrides); Q3 omitted `Y ~ X` fixed 0 at k = 0 only; Q4 all estimated paths per variant; Q5 effects `nie`, `nie_total`, `nde`, `te`; Q6 covariate may be treatment; Q7 refuse reversed order; Q8 per-effect origin rule; Q9 keep the rank gate; Q10 parity once per slice; Q11 print chain and covariates (may slip).

Revision 2 (this file) applies those decisions. Sections changed: scope and front matter; section 1 (rewritten: variant table, 1.1 admitted variants, new 1.2 registry amendment with exact wording); section 2.1 (both models), 2.2 (rewritten for Q2 with the version-pinned lavaan rationale), 2.3 (builder arguments, per-variant tables and parameter counts); section 3.1-3.5 (chain effects and gradients, per-variant covariance block, one class with a `variant` slot, per-variant path rows, per-effect origin rule); section 4.1-4.4 (router and variant detection, extraction including Q6 and Q7, refusals including Q2 and Q3, source-fit and gate probes); section 5 (slice plan, five PRs); section 6 (variant column, new V16 and V17, new D17-D23, new 6.2 gate arithmetic); section 7 (docs). Section 8 is kept below as the record of the questions, each marked resolved with its decision. Section 9 holds the questions that this revision raises.

# 8. Open questions for the maintainer (all resolved; see 8a and the ledger)

1. **Shortcut policy.** RESOLVED (Q1, overrides): saturated AND pure chain admitted. Registry amendment in section 1.2.
2. **Residual independence by omission or written.** RESOLVED (Q2, overrides): all three zeros written; omission refused.
   Lavaan claim version-pinned in section 2.2; the 0.6.x behavior stays unverified.
3. **Omitted `Y ~ X` for k = 0.** RESOLVED (Q3): admitted as fixed 0 at k = 0; refused for k >= 1.
4. **Reporting the shortcut paths.** RESOLVED (Q4): all estimated paths per variant (section 3.3 item 5).
5. **Which effects are admission targets.** RESOLVED (Q5): `nie`, `nie_total`, `nde`, `te`; per-path specific effects
   deferred.
6. **Covariate as treatment in S2 and S3.** RESOLVED (Q6): allowed (saturated variant); the chain at k >= 1 is raised
   again in question 1 of section 9.
7. **Reversed mediator order in `extract_mediation()`.** RESOLVED (Q7): refused with a classed error naming the fitted
   order.
8. **Origin rule scope.** RESOLVED (Q8): per effect; the chain variant has the single rule of section 3.4.
9. **Identification messaging.** RESOLVED (Q9): keep the rank gate, document it, no pre-check.
10. **Parity cadence.** RESOLVED (Q10): once per slice; Hopper harness commit on `ba50f998`.
11. **Printing.** RESOLVED (Q11): print the chain and covariates; cosmetic, may slip.

# 9. New open questions raised by revision 2

1. **Chain with covariates: covariate as treatment.** The chain is asymmetric in the exogenous block (X has no M2 path;
   covariates have one), so Q6 does not carry over unchanged. Recommendation: refuse a covariate as treatment in the
   chain (treatment is structural); allow it in the saturated variant as Q6 says. Alternative: allow it with `a2 = gm2z`
   and a third effect rule.
2. **`c_prime` row when the direct path is fixed at zero.** Q4 reads "chain: a, d, b, +c_prime if free"; existing
   simple and parallel FIML `paths()` list `c_prime` regardless (behavior with a fixed zero unverified). Recommendation:
   follow the existing behavior in both serial variants (always list `c_prime`, value 0, SE 0), so tidy shapes do not
   depend on the policy; the alternative is the literal reading, which makes the saturated variant (six rows always) and
   the chain (three or four) inconsistent.
3. **Gate rows per direct policy.** Free policy only (225 rows) or both policies (321 rows) for the six serial
   structures. Recommendation: free only, as every current structure, with fixed-zero in the V-tests; revisit at
   admission.
4. **Slice order.** Five PRs (S0, S1 sat k = 0, S2 chain k = 0, S3 both k = 1, S4 both k = 2) versus seven (one variant and
   covariate count per PR). Recommendation: five; fall back to seven if QA finds S3 or S4 too large.
5. **`variant` as a class property mirrored in `fit_context`** versus only in `fit_context`. Recommendation: property
   plus context, the validator requires agreement, so a forged object cannot change the effect rule without breaking
   the hash.
6. **Recheck lavaan 0.6.x residual-covariance behavior.** The claim in the parallel parser comments (lavaan "would free"
   the covariance) is false on 0.7-3 and unverified on 0.6.x. Recommendation: a one-off recheck on 0.6.x (installable
   in a scratch library) before the comment and the docs cite it; until then say "lavaan 0.7-3 frees none" only.
7. **Refusal probes.** Relabel the `serial` and `parallel_covariate_serial` gate probes as Q2 probes and add the new ones
   of section 4.4 (the probe count changes from nine). Recommendation: yes, as section 4.4 lists; confirm the intended
   final probe set at the S1 review.
