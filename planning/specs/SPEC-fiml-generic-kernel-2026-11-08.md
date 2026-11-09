---
title: "SPEC: dimension-generic observed-data FIML kernel (FI-G0a)"
date: 2026-11-08
status: draft, specification and oracles only; no production change
plan: planning/PLAN-FIML-next-release-model-expansion-2026-11-01.md (section 1, FI-G0)
base: a92e8d4a (claude/restore-b0bd19 tip: dev ecbfb19f plus the unmerged stage-0 release-guard commits)
decisions: []
---

# Scope

Internal contract only. It states what a dimension-generic version of the bounded Gaussian FIML kernel
(`R/sem-fiml.R`, `R/sem-fiml-interface.R`) must compute, and which behavior of the existing X -> M -> Y model it must
reproduce exactly. It admits no topology: unadmitted topologies and direct-path policies stay refused at `fit_sem()`,
`extract_mediation()` and `bootstrap_mediation(source_fit =)`. Generic internals alone expose nothing new (FI-G0d).

Out of scope: statistical admission, inference (the `source_fit` interval path is withheld by the stage-0 guard,
`medfit_error_fiml_inference_unavailable`, and this task must not touch it), covariates, parallel and serial graphs.

# 1. Generic likelihood contract

Model class (internal, random-X, continuous Gaussian, recursive): `p` observed variables `v`, a strictly
lower-triangular-after-ordering path matrix `B` (acyclic), diagonal disturbance covariance `Psi`, and intercept vector
`nu`, all free parameters real, variances positive. Implied moments

- `mu = (I - B)^-1 nu`, `Sigma = (I - B)^-1 Psi (I - B)^-T`.

Row `i` with observed index set `O_i` (non-empty) contributes
`0.5 * (|O_i| log(2 pi) + log det Sigma[O_i,O_i] + (y_i[O_i] - mu[O_i])' Sigma[O_i,O_i]^-1 (y_i[O_i] - mu[O_i]))`.
A row with `O_i` empty contributes exactly 0 and is not counted in `n`. No row is dropped for partial missingness
(raw FIML); a pattern is the set `O_i`.

**Pattern summaries.** Rows are grouped by the mask key `paste0(!is.na(z[i, ]), collapse = "")`, groups ordered by
`split()` on that key (lexicographic on the strings `"FALSE..."` < `"TRUE..."`). Each group stores
`ids` (row indices into the input matrix, ascending), `cols` (observed column indices), `n`, `mean` (column means of
the standardized block) and `covariance` (crossprod of the centered block divided by `n`; ML divisor, not `n - 1`).
The all-empty mask is a group with `cols = integer(0)`; evaluation, difference, gradient and geometry skip it. The
group total of `n * (mean-dev + covariance)` reproduces the rowwise sum, so the grouped value must equal the rowwise
sum to rounding (reference: loop over rows, no grouping).

**Standardization and constants.** Per column: `center = colMeans(na.rm)`, `scale = sd(na.rm)` (`n - 1` divisor over
that column's observed entries). Fitting runs on `z = (data - center) / scale`. The grouped value on `z` omits the
log-Jacobian, so the original-scale likelihood is

- `nll_original = nll_standardized + sum_j n_j log(scale_j)` with `n_j` the number of observed entries in column `j`
  (empty rows contribute no entries). This is `p$jacobian`; the fit stores `nll = best$value + p$jacobian`.

**Transport.** Parameters are carried in the order of `ram$par_names`. The standardized-to-original map is affine,
`q_original = offset + transport %*% theta_standardized`, with, for a path `r <- s` (response `r`, predictor `s`),
unit `scale_r / scale_s`; variances unit `scale^2`; intercept of `r`:
`scale_r * nu_std_r + center_r - sum_s q_rs * center_s`, i.e. `offset = center` on the intercept rows, intercept unit
`scale_r`, and `transport[intercept_r, path_rs] = -center_s * unit_rs`. The covariance of original-scale estimates is
`V = transport %*% H^-1 %*% t(transport)` with `H` the observed-information Hessian of the raw standardized NLL. The
generic transport must satisfy, for every admitted graph, the moment identity `mu = center + scale * mu_std`,
`Sigma = D Sigma_std D` (`D = diag(scale)`), checked independently by recovering the structural parameters from the
original-scale moments by recursive regressions.

**Derivatives.** `.sem_fiml_eval` returns the gradient of the unscaled standardized NLL in `theta` coordinates:
per group `n * (0.5 * <W - W T W, dSigma_k[O,O]> - dmu_k[O]' W d)` with `W = Sigma[O,O]^-1`,
`d = mean - mu[O]`, `T = covariance + d d'`. It must equal a central-difference derivative of the rowwise reference
likelihood. The observed information is the central-difference Jacobian of that gradient (Richardson 4/3 combination,
step `eps^(1/3) * max(|theta|, 1)`, variance steps capped at `theta / 10`); the moment geometry (`.sem_fiml_geometry`)
is the rank diagnostic and must equal the Fisher-type sum `n_g (dmu' W dmu + 0.5 tr(W dSigma W dSigma))` over groups.

**Numerical safeguards to retain.** Cholesky-based evaluation returning `NULL` (the objective maps `NULL` to `1e10`,
the gradient to zeros) for a non-positive-definite or non-factorable `Sigma[O,O]`; variance lower bound `1e-10`; three
fixed starts (`initial`, `initial + 0.12 sin(k)`, `initial - 0.15 cos(k)`) times two solvers (SLSQP then nlminb with
an anchored same-solver refinement); local stationarity `<= 1e-5` in original units; six attempts, one accepted per
solver required, accepted likelihood spread `<= 1e-8 * n`; moment-geometry and Hessian rank gates with the singular
tolerance `.sem_singular_tol`. These constants are numerics, not options.

# 2. Behavior of the existing model that must be preserved

"Existing model" = X -> M -> Y, `M ~ a*X`, `Y ~ b*M [+ cp*X]`, one exogenous, one mediator, one outcome, observed
continuous variables, intercepts free, variances free, `fixed_x = FALSE` explicitly.

## 2.1 Parameters and names

| Item | Contract |
|---|---|
| Internal order (`ram$par_names`) | `a, b, cp, vx, vm, vy, ix, im, iy` with `cp` omitted when the direct path is fixed at zero (`q = 9` or `8`) |
| Public/coef names (via `.sem_fiml_model()$map`) | `a, b, cp` map to the model's own coefficient names for `M ~ X`, `Y ~ M`, `Y ~ X`; `vx, vm, vy` to `X~~X, M~~M, Y~~Y`; `ix, im, iy` to `X~1, M~1, Y~1` (with the user's variable names); the map is positional, never by label |
| Parameter set | exactly 9 (free direct) or 8 (direct fixed at 0) parameters, no duplicates, no extras; `vcov` rows and columns carry the same names and multiplicity |
| Direct path | free (`cp` estimated) or fixed exactly at `0` (rows `Y ~ 0*X`); the zero path is reported as a fixed row of the table, never a parameter. Any other fixed value, bound or start is refused |
| Labels | user labels are ignored for role identification (topology authoritative); a label equal to a reserved alias must not change roles |

## 2.2 Row identity, retained and empty rows

- `row_id` has the length of the data, no `NA`, no duplicates; defaults to `seq_len(nrow)`.
- `rows$original = row_id`; `rows$retained = row_id[rowSums(!is.na(data)) > 0]`; `rows$empty = row_id[the rest]`.
- `n` (and `nobs()`) = number of retained rows; `n_dropped` = number of empty rows. `data` stored on the fit is the
  retained rows in original order.
- `rows$patterns[[k]]` carries, per group, original `row_id`s (`ids` mapped through `row_id`), the variable names of
  the observed columns, and `n`; `rows$complete` = complete cases of the input.
- Reordering rows (with their ids) must not change the likelihood value, the estimates or the group membership by id.
- An all-empty row contributes 0 to the likelihood and nothing to `n`, `jacobian`, or any group statistic.
- `NaN` is treated as missing (current behavior of the mask via `is.na`); `Inf`/`-Inf` are refused. This is recorded as
  current behavior, not endorsed (open question 3).

## 2.3 Refusals of `.sem_fiml_prepare()` (class `medfit_sem_fiml_error`)

| Message | Condition |
|---|---|
| `unsupported FIML setting` | any `...`, `fixed_x` not exactly `FALSE`, `direct` not a single non-`NA` logical |
| `invalid FIML input` | not a numeric matrix; `ncol != 3`; column names not exactly `X, M, Y` in that order; any non-finite non-`NA` entry; `row_id` of wrong length, with `NA`, or duplicated |
| `variable has insufficient observations` | any column with fewer than 2 observed entries |
| `variable has no positive scale` | any column with zero or non-finite standard deviation |

## 2.4 Refusals of `.sem_fiml_model()` and `fit_sem(missing = "fiml")`

Refused with class `medfit_sem_fiml_error`, `stage = "input"` (or an earlier plain error for the argument checks):

- argument settings: `fixed_x` unset or not `FALSE`; `meanstructure` not `TRUE`; `information != "observed"`;
  `se_type != "model"`; any `weights`; any `control`; `n_starts` not `NULL`/3; non-numeric or object columns; missing
  model variables.
- topology: constraints, `:=` definitions, bounds, starts, levels other than 1; operators other than `~`, `~~`, `~1`;
  not exactly three observed variables with one exogenous, one outcome and one mediator; interaction (`:`) variables;
  duplicated rows; a missing `M ~ X` or `Y ~ M`; any term outside `{M~X, Y~M, Y~X, variances, intercepts}`
  (covariates, a second mediator, correlated disturbances such as `M ~~ Y`, reverse paths, a path from `M` to `X`);
  fixed values other than a zero direct path (e.g. `M ~ 0*X`, `X ~ 0*1`); parameter ties (`q` not 9/8, e.g. shared
  labels or `a == b`).
- numerical (stage `numerical`, attempts retained): non-identified masks (rank-deficient moment geometry), no accepted
  candidate per solver, disagreeing optimizer likelihoods, ill-conditioned observed information.
- `extract_mediation()` accepts only the fitted treatment, mediator and outcome, unstandardized, `structure = "auto"`,
  `decomposition` `auto` or `two_way`; every other argument or name is refused with
  `FIML extraction supports only the fitted simple unstandardized two-way mediation`.
- every other consumer (`pm`, `quick`, `glance`, `confint(method = "boot")`, `mbco_sem`, `compare_lr`, `anova`, `AIC`,
  `BIC`, `bootstrap_mediation(mediation_data =)`) refuses a bounded FIML object; `bootstrap_mediation(source_fit =)`
  refuses before any other check, draw or refit (stage-0 guard), and no option or environment variable bypasses it.

The R2 ordering constraint applies: a generic refactor must reproduce all of the above, bit for bit within the frozen
tolerances, before it can merge, and the stage-0 study source must then be re-pinned.

# 3. Independent reference cases (G0b)

Oracle file: `tests/testthat/test-fiml-generic-kernel-oracle.R`. Every reference is a from-scratch calculation
(explicit matrices, rowwise loops, closed-form inversion of the recursive model); production helpers appear only as
the code under test. lavaan is a supporting cross-check where installed (`tests/testthat/test-sem-fiml-oracles.R`
already compares the fitted estimates, covariance and likelihood to lavaan and to the rowwise oracle).

| Cell | Claim | Oracle | Tolerance |
|---|---|---|---|
| R1 observed-subvector value | `.sem_fiml_eval(theta)$value + jacobian` equals the rowwise NLL of the raw data at the transported parameters | rowwise loop over raw rows | 1e-8 absolute |
| R2 pattern summaries | `groups` partition the retained rows; each group's `mean`, ML `covariance`, `cols` and `n` equal a from-scratch recomputation | direct recomputation per mask | 1e-12 |
| R3 transport | `offset + transport %*% theta` equals the structural parameters recovered from the original-scale moments by recursive regressions; transport is affine-exact between two random vectors | moment inversion | 1e-9 |
| R4 gradient | analytic gradient equals Richardson central differences of the rowwise reference in `theta` | rowwise reference | 1e-6 |
| R5 row identities | retained/empty ids, `n`, group ids under custom `row_id` and under row permutation (value invariant) | by construction | exact / 1e-10 |
| R6 constants | `jacobian = sum_j n_j log(scale_j)`; value difference between two datasets related by an affine map equals the Jacobian change | hand calculation | 1e-9 |
| R7 refusals | every row of 2.3 and the topology/argument refusals of 2.4 fail with the stated class and message; unadmitted topology never reaches the kernel; guard refuses `source_fit` | behavior pinned | exact |

Missingness patterns: each single-variable pattern, pairs, the full set (all seven non-empty masks), an all-empty row,
complete data (single group), two rows per pattern (minimal), and a pattern in which one column has exactly two
observed entries. Both direct policies (free, fixed at zero).

Planted defects (each test must fail under the mutation, via `sem_mutate()` on the code under test; in
`fx_skip_covr()`): (D1) ML divisor `length(ids)` replaced by `length(ids) - 1`; (D2) the log-Jacobian dropped
(`n_j` replaced by the row count); (D3) the `im` transport term `-center[1] * units["a"]` sign flipped; (D4) an empty
row counted in `n`; (D5) the observed index `j <- g$cols` replaced by all columns in the likelihood loop; (D6) the
`2 * pi` constant dropped. A mutation that does not change the result is a failed oracle.

# 4. Decisions (maintainer, 2026-11-08)

1. **Decided.** `R/sem-fiml.R` may change on this feature branch only. No push, PR or merge to `dev` or `main`; it must
   not merge before the stage-0 decision plus a pinned old-model parity proof (R2) and a re-pinned study source.
2. **Decided.** Base stays `a92e8d4a` plus the spec and oracle commits; the branch is rebased onto `dev` after the guard
   merges. Kernel commits stay isolated: spec, tests and `R/sem-fiml.R` only.
3. **Decided.** `NaN` stays missing via `is.na` in `.sem_fiml_prepare()`; preserve exactly, no change. `Inf`/`-Inf`
   remain refused as `invalid FIML input`.
4. **Decided.** "Both source-fit entry points" are the parametric and nonparametric methods of
   `bootstrap_mediation(source_fit =)`, the only exported function with `source_fit`. The stage-0 guard is untouched.

# 5. Parity protocol for G0c/G0d

Before the first production change a golden snapshot of the existing model was captured from the unchanged kernel:
`tests/testthat/fixtures/fiml-generic-golden.rds`, produced by `gk_write_golden()` in
`tests/testthat/helper-fiml-golden.R`. It holds, for the eight missingness kinds times both direct-path policies
(16 cells): parameter names and order, `q`, prepared quantities (groups, standardized data, center, scale, units,
transport, offset, Jacobian, row ledger), kernel numerics at a fixed point (value, gradient, Hessian at two multipliers,
moment geometry, likelihood difference), and the end-to-end fit through `fit_sem()` (coefficients, covariance, logLik,
attempt ledger, solver call count, ledger fields, table, likelihood context, extracted NIE/NDE/TE, paths, estimates)
or the refusal (class, message, stage, attempts) for the cells that fail (`minimal free`, `ytwo free`, `ytwo zero`).
`tests/testthat/test-fiml-generic-kernel-golden.R` recompares after every step: prepared and kernel quantities at
1e-12 (bit-for-bit on the capturing machine), fitted results at 1e-6 (frozen SLSQP tolerance), discrete fields
(statuses, acceptance, solver calls, names, messages) identical. A step that cannot meet this is not made; it is
reported (observable behavior must not change).

Generalization steps (each its own commit, golden test green after each, planted defects added per step):

- T: transport (units, offset, transport matrix) derived from a parameter layout of the model's RAM tables instead of
  literals for `a, b, cp, vx, ...`.
- S: variance indices, lower bounds, starts and the SLSQP unit matrix from the layout and the number of variables.
- E: evaluation and geometry loops over the layout (value, gradient, difference, Hessian step caps).

The public adapter (`.sem_fiml_model()` and the topology refusals) is verified, not generalized: no new topology or
direct-path policy is activated.

# 6. G0c/G0d status (2026-11-08)

Done, golden snapshot green after each step (transport bit-identical to the baseline):

- T: `.sem_fiml_tables()`, `.sem_fiml_layout()`, `.sem_fiml_transport()` replace the literal transport.
- S: `.sem_fiml_variance_index()`, `.sem_fiml_starts()`, `.sem_fiml_lower()` and the solver unit matrix come from the
  layout.
- E: `.sem_fiml_prepare_core(data, tables)` and `.sem_fiml_solve(p)` are dimension-generic; `.sem_fiml_prepare()` and
  `.sem_fiml_fit()` remain the only callers and pass only the X -> M -> Y tables. Evaluation, difference, geometry and
  Hessian were already free of three-variable literals. A four-variable chain with a direct path, run through the
  internals only (`test-fiml-generic-kernel-fourvar.R`), matches the rowwise reference, the independent geometry and
  Hessian, and lavaan (estimates 1e-5, logLik 1e-6, covariance 1e-3).
- G0d: refusals unchanged at prepare, fit (13 topology and policy cases), extract and both `source_fit` methods; no
  public entry builds other tables.

Not changed: `.sem_fiml_model()` (adapter, topology refusals), `R/sem-fiml-interface.R`, the stage-0 guard.
Merge remains blocked on the stage-0 decision and the pinned old-model parity proof.

# 7. FI-G1 slice 1: one observed covariate (2026-11-08)

Public variant added: `fit_sem(model, data, missing = "fiml", fixed_x = FALSE)` and `extract_mediation()` for exactly four
observed numeric variables, two exogenous (X and the covariate Z), one mediator M, one outcome Y:

- Regressions `M ~ X + Z` and `Y ~ M + X + Z`. The covariate paths (`M ~ Z`, `Y ~ Z`) and `M ~ X`, `Y ~ M` are free.
- Joint random-X covariance: `X ~~ Z` is a free parameter (added automatically; written explicitly in either order it
  is the same parameter; fixed, duplicated or omitted-by-constraint it is refused). Independent disturbances.
- Direct-path policy: both Y paths (`Y ~ X`, `Y ~ Z`) must be written. Both free, or exactly one fixed at zero
  (`0*X`). An omitted Y path is refused: it is ambiguous with a covariate acting on M only, which is not a complete
  covariate. The variable whose Y path is fixed is the treatment `X` of the fit, the other the covariate `Z`. With both
  Y paths free, the first exogenous variable by appearance is `X`, and extraction may name either as the treatment
  (the kernel is symmetric).
- Incomplete data: any of X, Z, M, Y may be incomplete (all non-empty observed patterns), exactly the existing
  three-variable contract (all-empty rows dropped; unidentified masks fail the rank gate at stage `numerical`).
- Parameters (14, or 13 without a direct path): `a gm b [cp] gy vx vz vm vy cxz ix iz im iy`. Kernel: the generic
  `.sem_fiml_prepare_core()`/`.sem_fiml_solve()` with `.sem_fiml_tables_cov1()`; the layout gained a `covariances`
  element (empty for the three-variable tables), transported with unit `scale_row * scale_col`.
- Extraction: `FIMLMediationData` with `a`, `b`, `c_prime` of the chosen treatment and the full fitted covariance in
  `@vcov`; `fit_context$covariate` records Z. Standardized, structure, decomposition, interaction and any other
  argument stay refused as before.
- Still refused at prepare, fit, extract and both `source_fit` methods: every other topology and direct-path policy
  (two covariates, a covariate on only one equation, covariate as mediator, parallel, serial, interaction, correlated
  disturbances, ties, bounds, constraints, defined parameters, fixed nonzero or fixed covariate paths). The stage-0
  guard is unchanged; with it mocked open, a covariate fit is additionally refused by `.bootstrap_fiml()`
  (`medfit_error_fiml_covariate_source_fit`), so no source-fit interval exists for the variant.

# 8. FI-G1 slice 2: two observed covariates (2026-11-08)

Public variant added, on the same entry points as section 7: five observed numeric variables, three exogenous (X, Z1,
Z2), one mediator M, one outcome Y; regressions `M ~ X + Z1 + Z2` and `Y ~ M + X + Z1 + Z2`.

- One covariate-count generalization: `.sem_fiml_tables_cov(k, direct)` (k = 1 or 2; `.sem_fiml_tables_cov1()` is
  `k = 1` and unchanged) and `.sem_fiml_model_cov()`. Kernel variable order X, Z1, Z2, M, Y.
- Parameters (20, or 19 without a direct path): `a gm1 gm2 b [cp] gy1 gy2 vx vz1 vz2 vm vy cxz1 cxz2 cz1z2 ix iz1 iz2 im iy`.
  Covariances are free for every exogenous pair, in either written order. The automatic completion adds all three
  pairs only when none is written; a partial explicit set leaves the unwritten pairs at zero in the completed table,
  which is an orthogonality restriction, so it is refused (the model is not silently completed).
- Treatment rule (extends section 7 to three exogenous variables): every exogenous variable must have a written Y path.
  Zero fixed Y paths: the first exogenous variable by appearance is `X`, the other two are the covariates `Z1`, `Z2` in
  order of appearance, and extraction may name any of the three as the treatment (the kernel is symmetric; the other two
  are then the covariates). Exactly one Y path fixed at zero: that variable is the treatment `X` and the only valid
  extraction treatment, the other two are the covariates. Two or more fixed Y paths, any nonzero fixed value, an omitted
  Y path and any fixed covariate path to M are refused.
- Extraction as in section 7: `a`, `b`, `c_prime` of the chosen treatment, the full fitted covariance in `@vcov`,
  `fit_context$covariate` the two remaining exogenous variables (data names).
- Still refused at prepare, fit, extract and both `source_fit` methods: three or more covariates, a covariate on one
  equation only, covariate as mediator, fixed-zero or fixed covariate paths, covariate residual covariances and every
  topology listed in section 7. The stage-0 guard is unchanged; a covariate fit (one or two) is additionally refused by
  `.bootstrap_fiml()` (`medfit_error_fiml_covariate_source_fit`).

# 9. FI-G2 slice 1: two parallel mediators, independent disturbances (2026-11-08)

Public variant added, on the same entry points as sections 7 and 8: four observed numeric variables, one exogenous
(X), two mediators, one outcome; regressions `M1 ~ X`, `M2 ~ X`, `Y ~ M1 + M2 [+ X]`, with the independence of the two
mediator disturbances written as `M1 ~~ 0*M2` (either order).

- One mediator-count generalization: `.sem_fiml_tables_med(j, direct)` (j = 1 or 2); `.sem_fiml_tables()` is `j = 1`
  and is identical (`identical()`) to the previous literal tables for both direct policies. The generic
  `.sem_fiml_prepare_core()`/`.sem_fiml_solve()` are unchanged; the three-variable and covariate paths do not touch any
  new code (golden snapshot and slice tests unchanged). Kernel variable order X, M1, M2, Y.
- Parameters (13, or 12 without a free direct path): `a1 a2 b1 b2 [cp] vx vm1 vm2 vy ix im1 im2 iy`. No free
  covariance parameter exists, so the layout's `covariances` element is empty.
- Mediators are `M1`, `M2` in order of appearance of their regressions. Direct-path policy: free, fixed at exactly zero
  (`0*X`), or omitted (the same three policies as the three-variable model).
- Residual policy decision: the independence must be WRITTEN. An omitted `M1 ~~ M2` is refused (lavaan's default frees
  that covariance, medfit's completion does not, so silence is ambiguous across the two; the free covariance is the
  next slice and must not become reachable by omission). A free or nonzero `M1 ~~ M2`, a duplicate, and any covariance
  with Y or X are refused.
- Class decision: a new internal subclass `FIMLParallelMediationData` of `ParallelMediationData` (property
  `fit_context`, validator mirroring `FIMLMediationData`, S4-registered). `FIMLMediationData` is not extended: its
  parent holds scalar `a_path`/`b_path`. The subclass inherits the parallel `nie`/`nde`/`te`/`paths`/`tidy`/`confint`
  methods and the parallel branch of the effect-gradient builder (`a1..`, `b1..`), so the sum of the two products has
  the delta-method gradient `(b1, b2, a1, a2)` over the FULL covariance.
- Extraction: `extract_mediation(fit, treatment = "X", mediator = c("M1", "M2"))`, either mediator order (`a_j`, `b_j`
  follow the requested order; the sum and its SE do not change). `@vcov` carries the alias rows `a1 a2 b1 b2 c_prime`
  with the full fitted observed-information covariance (`Cov(a1, a2)`, `Cov(b1, b2)`, `Cov(a_i, b_j)` all retained; the
  fixed-zero or omitted direct path is a zero row and column). `structure = "parallel"` is accepted for a parallel fit
  (and still refused for a simple fit); a single mediator, a mediator that is not a fitted one, a repeated mediator,
  standardized, `interaction`, `decomposition = "four_way"`, `outcome` other than Y and every other argument are refused
  (`FIML extraction supports only ...`).
- Consumers refuse the object as they refuse a simple FIML object: `pm()`, `glance()`, `quick()`,
  `confint(method = "boot")`, `bootstrap_mediation(mediation_data = )`. `print()` states the FIML context and
  `tidy()` carries `fit_context`.
- The exact-origin rule (all `a_j = b_j = 0`, NIE SE `NA` for a zero delta gradient) covers the parallel class too (fixed
  in #383, `25dd504c`, also with covariates): the estimates are exact zeros only on constructed objects, and no fit
  reaches it.
- Still refused at prepare, fit, extract and both `source_fit` methods: a free or implicit mediator residual
  covariance, mediators affecting each other (serial), a mediator that does not affect Y or is not affected by X, three
  or more mediators, any covariate with the parallel structure, interactions, ties, constraints, bounds, defined
  parameters, fixed nonzero or fixed `a`/`b` paths. The stage-0 guard is unchanged; a parallel fit is additionally
  refused by `.bootstrap_fiml()` (`medfit_error_fiml_parallel_source_fit`) before any RNG draw or refit.
- Evidence (`tests/testthat/test-fiml-g2-parallel.R`): lavaan raw-data FIML for estimates, SEs, logLik and the `:=`
  products, their SUM and the total, in the free, zero and omitted direct variants; the rowwise likelihood oracle and
  an independent Hessian; closed-form complete-data OLS, ML covariances and the exact block structure. Planted defects
  with positive controls: dropped `M2 -> Y` path, untransported covariance, `c'` wired to `b1`, `a1`/`a2` swapped,
  and the cross-path covariance dropped (the lm-style `Cov(a1, a2)`, `Cov(b1, b2)` omission and the whole
  cross-mediator block). On the fixed-zero fixture the sum's SE is 0.0488 (lavaan 0.0488); the lm-style omission gives
  0.0843 and the dropped block 0.0849; `Cov(a1, a2)` is 1.7e-05 (about zero under independent disturbances) and
  `Cov(b1, b2)` is -4.3e-03 (the term that matters), so the lm omission bites here through `Cov(b1, b2)` only.
