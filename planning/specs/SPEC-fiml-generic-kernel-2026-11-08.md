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
