# S4a: native two-level ML core, implementation plan (2026-11-18)

**Status:** APPROVED 2026-11-18 (five slices; reliability cell `n/a: S4b`; unset `fixed_x` resolves silently to `FALSE`).
S4a.1 in progress.
**Branch:** `feature/twolevel-native-s4a` (from `origin/dev` at `22688951`). **Risk tier:** high (every slice edits files in
`tests/sim/risk-files.txt`). **Label:** experimental (the experimental-API exemption: Rd pages and NEWS say so). **Not released**
until T6/U4 and S4b are done.

## Sources (referenced, not copied)

These live on unmerged branches; this plan names them by path and does not copy them, so that the S4a PRs do not duplicate them
or conflict with them. **Each S4a PR rebases on `dev` after #482 and #483 merge.**

| Source | Path | Lands via |
|---|---|---|
| S4 sketch, oracles, risk tier | `planning/specs/PLAN-multilevel-mediation-2026-11-10.md` sections 0.5, 0.6, 0.8, 4, 5, 6, 7 | #482 |
| Tolerances TL-1 to TL-7 | `planning/specs/ADR-twolevel-oracle-tolerances-2026-11-18.md` | #482 |
| U2 and S4-dec decisions | `planning/PLAN-multilevel-remainder-2026-11-18.md`, Progress | #482 |
| OpenMx three-way oracle (U3) | the U3 test file and helper | #483 |
| Hand-built O8 likelihood | `tests/testthat/helper-twolevel-likelihood.R` (`tl_stats`, `tl_loglik` with defects `nj_free`/`no_mean`, `tl_check_loglik`, `tl_check_paths`, `tl_fit_lavaan`) | already on `dev` |

## Scope

In: observed variables only; two levels; fixed slopes (Q3); W/Z variable sets; per-size sufficient statistics; the likelihood
of sketch item 2; analytic gradient; the existing SLSQP pipeline and acceptance gate; joint vcov from the observed information;
per-level admissibility in the outcome ledger; `fit_sem(cluster = )`; `fit_mediation(engine = "sem", model = , cluster = )`
forwarding; `extract_mediation(<SEMFit>)` returning `TwoLevelMediationData` with provenance.

### Decisions this plan applies

- **`fixed_x` (U2).** At two levels an **unset** `fixed_x` resolves to `FALSE` (S1-Q2); only an **explicit** `fixed_x = TRUE`
  (or a name vector) raises the classed error `medfit_error_twolevel_fixed_x`. The `medfit_warning_default_change` machinery
  (`fx_unset`, `.native_defaults_resolve()`) is bypassed on the two-level path: it stays silent, because no 0.15 default ever
  applied to a two-level model. A test pins both.
- **`meanstructure`.** Between-level means are part of the model, so the two-level route needs the mean structure. Unset
  resolves to `TRUE`; explicit `meanstructure = FALSE` raises `medfit_error_twolevel_meanstructure`.
- **`level:` names (S4-dec).** The parser accepts `level: 1`/`2`, `level: within`/`between`, and `level: <cluster variable>`
  (lavaan parity), mapped to integers; anything else stays the existing malformed-level error.
- **Level-2 variances: unconstrained (do not pre-empt S4b).** S4a fits level-2 variances with no floor and no reference
  start. P1's eps = 1e-3 floor from the T6 study is **not** used. An inadmissible solution (negative level-2 variance,
  non-PD Sigma_B) is a classed error under Q8 and ADR D-11, with the fit kept in the ledger as evidence. Floor vs
  unconstrained is S4b's decision, after T6/U4.
- **Comparison convention (TL-3).** Every lavaan comparison uses `fixed.x = FALSE`, `information = "observed"`,
  `h1.information = "structured"`.

### Refused, each with a classed error and a test that triggers it

| Input | Error class | Why |
|---|---|---|
| `level:` blocks without `cluster =` (and `cluster =` without `level:` blocks) | `medfit_error_twolevel_cluster` | replaces the "two-level estimation is not implemented" stop in `R/sem-fit.R:97` |
| more than two levels; J < 2; cluster column missing or with `NA` | `medfit_error_twolevel_cluster` | sketch item 1, section 6 guards |
| latent variables (`=~`) at either level | `medfit_error_twolevel_latent` | S5 is NO-GO |
| `x:m` product at either level | `medfit_error_twolevel_product` | sketch "what stays out" |
| `weights =`, `se_type = "sandwich"` | `medfit_error_twolevel_weights` | S6 (IG2) |
| `missing = "fiml"` | `medfit_error_twolevel_missing` | S7 |
| nonlinear constraints and zero-product branches | `medfit_error_twolevel_nonlinear` | per-level branch handling is IG3, after S4 |
| a W variable constant within every cluster; a Z variable in a `level: 1` row | `medfit_error_twolevel_varset` | sketch item 1 |
| a within-only variable (named only in `level: 1` rows) | `medfit_error_twolevel_varset` | the O8 oracle and the sketch assume every W variable has a between part; lavaan's within-only set is later work |
| a valid two-level model before S4a.4 | `medfit_error_twolevel_not_implemented` | S4a.1 to S4a.3 have no fitter; the guards end in this stop so no single-level fit runs on pooled rows |
| explicit `fixed_x = TRUE`; `meanstructure = FALSE` | see above | U2; between means |
| `information = "expected"` | `medfit_error_twolevel_information` | no expected-information oracle in S4a |

**Cross-level labels (S1-Q3).** The same label at both levels is an equality constraint (linear, so the existing pipeline
handles it); the extracted object records `cross_level_equal` and its contrast is `NA` (constrained) by the #415 rule, keyed by
free-parameter index, never by name. Tested against lavaan with the same labels.

## Slices (one PR each, each with the seven-item checklist and its own stop)

Test-first: in each slice the oracle test and its planted defect are written and fail before the code exists.

| # | Slice | Files (risk files in bold) | Oracle and acceptance | Planted defects (TL-7: each must fail its tolerance) |
|---|---|---|---|---|
| S4a.1 | Parser names; guards; W/Z detection | **`R/sem-parse.R`**, **`R/sem-model.R`**, **`R/fit-sem.R`** (signature `cluster = NULL`), `tests/testthat/test-api-freeze.R` | Every refuse-table row triggered through `fit_sem()`; `level: within` / `between` / cluster name parse to the same table as `1`/`2`; W/Z sets match a hand classification on the fixtures | Z given a within row; a constant W variable accepted; name mapping swapped (within to 2) |
| S4a.2 | Per-size sufficient statistics and the likelihood at fixed theta | **`R/sem-ml.R`** (`.sem_sample_ml2()`, two-level `.sem_eval`) | Equal to `tl_loglik()` at the same theta to 1e-10 (arithmetic identity); equal to lavaan `logLik()` at lavaan's estimates to 1e-6 relative without Z; nested-fit difference to 1e-6 absolute with Z (TL-4); balanced data run through the unbalanced code equals the balanced closed form | n_j replaced by the mean size; dropped `p_w log n_j`; dropped (n_j - 1) log abs(Sigma_W); dropped Sigma_B,WZ block |
| S4a.3 | Analytic gradient | **`R/sem-ml.R`** (`.sem_grad`, `.sem_dsigma` per block) | Central differences of the S4a.2 objective at 20 random admissible thetas, relative 1e-6 | sign error in the Sigma_W/n_j chain term; gradient of the balanced form used on unbalanced data |
| S4a.4 | Optimizer and joint vcov | **`R/sem-optim.R`**, **`R/sem-fit.R`**, `R/sem-se.R` | Estimates vs lavaan `fixed.x = FALSE`: TL-1 (`max(0.01 SE, 1e-4)`, via `tl_check_paths()`); SEs: TL-2 (1e-3 relative); OpenMx third oracle: TL-5 (from #483); independent optimizer: `optim()` on `tl_loglik()`; frozen fixtures 1e-6 (TL-6). Fixtures: balanced n = 5 and unbalanced n in 2..9, J = 100 and J = 40; with and without a cluster-only Z; nonzero cross-level covariance (`abs(Cov(a_w, a_b)) > 1e-4` asserted) | zeroed cross-level vcov block (the `a_w - a_b` SE gap, 5.6% in the source fixture, must exceed 1e-3); SLSQP stopped early (gate must reject) |
| S4a.5 | Admissibility, extraction, provenance | `R/sem-outcomes.R`, `R/extract-sem.R`, `R/classes-twolevel.R`, `R/methods-sem.R` | Per-level admissibility in `fit@diagnostics$ledger` (validators extended); a seeded fixture with a negative level-2 variance and `converged = TRUE` errors with the ledger kept; `extract_mediation(<SEMFit>)` gives a `TwoLevelMediationData` equal to the lavaan adapter's object on the same data within TL-1/TL-2, with `@vcov` the joint 6 x 6 block; `glance()` reports df, total logLik, N, J, cluster-size range | admissibility from `converged` only; vcov rows keyed by name (fails on the shared-label fixture) |

Metamorphic checks (checklist item 4, in S4a.4): relabeling clusters and reordering rows leave every estimate and SE unchanged
to 1e-10; adding a constant to a variable moves only its intercepts (within and between means), to 1e-8.

Fault injection (item 5, in S4a.4/S4a.5): a singular Sigma_W start, a cluster of size 1 among larger ones, all clusters of
size 1 (refused: no within information), and an `NA` in the cluster column each give the documented classed condition, never a
silent fit.

## Seven-item admission checklist (per slice PR; the final state after S4a.5)

| Item | S4a state |
|---|---|
| Independent oracle | hand-built O8 likelihood (`helper-twolevel-likelihood.R`), `optim()` on it, lavaan `fixed.x = FALSE`, OpenMx (U3) |
| Reliability cell | **n/a: S4b, gated on T6/U4.** The level-2 parametrization the cell would test is undecided; `test-gate-coverage.R` requires a gate per structure, not a reliability gate (verified: the FIML structures carry one gate each) |
| Planted defect | per slice, table above; each is a `MUTANT=` token in the gate script |
| Metamorphic invariance | cluster relabeling, row order, constant shift |
| Fault injection | singular start, size-1 clusters, `NA` cluster ids |
| Registration | new `twolevel-parity` row in `tests/sim/gates.csv` (`oracle` = "O8 hand likelihood, lavaan fixed.x = FALSE, OpenMx"; `mutants` = the S4a.2 and S4a.4 tokens), driven by a new `tests/sim/sem-twolevel-parity-gate.R`; new `structures.csv` row `two-level observed (1-1-1),syntax,twolevel-parity,model-twolevel`. Lands in S4a.4, the first slice with a fitted result |
| Platform run | `gates.yaml` dispatched on the OpenBLAS runner for the `twolevel-parity` gate before S4a.4 merges (memory: gates-runner-uses-openblas) |

S4b adds the reliability gate to the same `structures.csv` row.

## Docs (with S4a.5; experimental label throughout)

`?fit_sem` (`cluster`), `?"medfit-syntax"` (`level:` names and the refuse table), `model-twolevel.qmd` (a native section
next to the adapter: what differs, `fixed_x = FALSE` only, unconstrained level-2 variances), NEWS (experimental, behavior:
the "not implemented" error is replaced), `.STATUS`. Every error message the page quotes gets a triggering test
(`test-guide-*.R` rule).

## Stop points

1. **Now:** maintainer approval of this plan (open questions below).
2. After each slice's PR is opened: merge only on the maintainer's word.
3. Any oracle disagreement beyond TL-1 to TL-5: stop and report, never widen a tolerance (ADR TL-7).
4. If the lavaan fixtures show inadmissible level-2 variances at J = 40, stop: that is S4b territory.

## Open questions for the maintainer

1. **Slice count.** Five PRs (as above), or merge S4a.2 and S4a.3 (likelihood and gradient) into one PR, giving four?
2. **Reliability cell.** Mark the checklist item `n/a: S4b` (recommended; the gate-coverage test allows it), or hold the
   `structures.csv` registration until S4b?
3. **`fixed_x` unset at two levels.** Resolve silently to `FALSE` with no default-change warning (recommended), or emit a
   one-time note?

## Progress

- [x] Plan approved (2026-11-18)
- [ ] S4a.1
- [ ] S4a.2
- [ ] S4a.3
- [ ] S4a.4
- [ ] S4a.5
