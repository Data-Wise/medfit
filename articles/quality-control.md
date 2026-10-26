# Quality control of the optimizer

This page records how the native engine’s optimizer is tested and where
its technical decisions are written down. The two tables below are
generated from the repository files at site build
(`tests/sim/gates.csv`, `tests/sim/structures.csv` and the front matter
of `planning/specs/ADR-*.md`), so they cannot drift from them. Plan and
ledger:
`planning/specs/BRAINSTORM-optimizer-quality-control-2026-10-23.md`. The
model syntax for the external oracles (lavaan, OpenMx, and the candidate
semopy) is on [One model in medfit, lavaan, OpenMx and
semopy](https://data-wise.github.io/medfit/articles/syntax-crosswalk.md).

## Principles

- Every number has an independent oracle (lavaan, OpenMx, OLS, a hand
  calculation or a known truth).
- Every gate has a planted defect it must catch, and the driver plants
  defects in every gate’s results.
- An unresolved result beats a wrong one: a refit or a branch that
  cannot be fitted is reported as unresolved or stops the fit; it is
  never replaced by the best of the others.
- Evidence is designed before it is run: the gate’s thresholds and
  design are committed first.

## Gate catalog

| Gate | Checked against | Planted defects | Structures |
|:---|:---|:---|:---|
| parity | lavaan and OpenMx (estimates, SEs) | driver | observed; latent; parallel; serial |
| constrained | OpenMx constrained fit | driver | linear constraints |
| se | OpenMx and lavaan standard errors | driver | observed; latent; parallel; serial |
| stationarity | labeled accepted and truncated fits (decrement separation) | driver, driver:scale_down, driver:scale_up | linear constraints |
| reliability | lavaan fit on the same data | driver | observed; latent |
| product-null | chi-square null distribution (known answer) | endogenous, wrongdf | product term and four-way |
| product-null-colon | chi-square null distribution (known answer) | endogenous, wrongdf | product term and four-way |
| product-fixed-var | chi-square null (calibrated rows) and documented-miscalibrated rows | wrongvar, wrongdf | product term and four-way |
| product-fixed-var-colon | chi-square null (calibrated rows) and documented-miscalibrated rows | wrongvar, wrongdf | product term and four-way |
| product-corr | OLS and SUR hand regressions | nocorr, olsdrop | product term and four-way |
| product-corr-colon | OLS and SUR hand regressions | nocorr, olsdrop | product term and four-way |
| four-way-kat | hand oracle with known truth, glm and lavaan routes | nocovgrad, unwtd_glm, unwtd_lavaan, oracle, wrongtruth | product term and four-way |
| s7-lifecycle | fresh-process install against CRAN S7 and S7 main | nounion, noonload | S7 install lifecycle |
| nonlinear-profile | independent oracle (tests/sim/oracle213.R) | noref, noflips, nofloor, absfloor, oracle1, driver:all_flagged, driver:floor_disproved_silent | nonlinear constraints |
| nonlinear-parity | OpenMx mxConstraint and an independent SE oracle | linear, larger, estoff, stale, noproj | nonlinear constraints |
| fixed-x | lavaan fixed.x and the free fit | countrestrict, noshift, droppair, jointlik, acceptbad, aicwarnonly, driver:no_lavaan | fixed_x |
| mean-constrained | lavaan and the invariance of the shifted fit | badshift, nocenter, driver:no_lavaan, driver:lavaan_partial | observed intercepts and means |
| factor | hand-coded dummies and lavaan | wrongref, nofix, noncanon, oneprod, afterdelete, nolevelcheck, halffix, driver:no_lavaan | factor covariates |
| bootstrap-coverage | known truth a\*b = 0.15 (interval coverage) | narrow, wrongtruth | bootstrap inference |
| oracle-sweep | independent randomized oracle (OLS) | badshift | observed |
| compare-lr | lavaan and OpenMx likelihood ratios | noresidual, zeroresid, fixedset, fixedset_openmx, driver:unresolved_converged, driver:ref_off | zero-product branches |
| restoration | first-order cost bound derived in the Methods article | infslack, rawdist, nocurv, nopinv, nonorm, nodispatch | nonlinear constraints |
| native-defaults | lavaan fixed.x/meanstructure/sampling.weights and a hand-calculated conditional likelihood | fixedx_logical, product_free, driver | observed intercepts and means; fixed_x; native defaults (fixed_x x meanstructure) |

A token in *Planted defects* is a `MUTANT=` value of the gate’s script;
the driver (`tests/sim/run-gates.R --mutants`) also plants tolerance,
missing, failed, unreadable and stale results in every gate.
`test-gate-coverage.R` fails when a row has no oracle, names a defect
its script does not contain, or when a structure has no gate.

## Decision log

| Id | Decision | Status | Date | ADR |
|:---|:---|:---|:---|:---|
| E-1 | fixed_x defaults to TRUE: warn in 0.14.0, flip in 0.15.0 | decided | 2026-10-24 | ADR-native-defaults-2026-10-24 |
| E-2 | meanstructure defaults to TRUE on the same schedule as fixed_x | decided | 2026-10-24 | ADR-native-defaults-2026-10-24 |
| E-3 | One default for fit_sem() and fit_mediation(engine = ‘native’) | decided | 2026-10-24 | ADR-native-defaults-2026-10-24 |
| E-4 | compare_lr() supports fixed_x and a saturated mean structure | decided | 2026-10-24 | ADR-native-defaults-2026-10-24 |
| E-5 | Only the default is lenient about statements on exogenous variables | decided | 2026-10-24 | ADR-native-defaults-2026-10-24 |
| E-6 | Dependents get a \[BREAKING\] notice and pass the settings explicitly | decided | 2026-10-24 | ADR-native-defaults-2026-10-24 |
| E-7 | Tests and gates that encode the old defaults pin them | decided | 2026-10-24 | ADR-native-defaults-2026-10-24 |
| E-8 | Fix the pinned-parameter SE under a mean structure before the flip | decided | 2026-10-24 | ADR-native-defaults-2026-10-24 |
| E-9 | Opt-in to the new defaults through options(medfit.native_defaults) | decided | 2026-10-24 | ADR-native-defaults-2026-10-24 |
| E-10 | Unset is detected with missing(); fit_mediation() forwards only supplied settings | decided | 2026-10-24 | ADR-native-defaults-2026-10-24 |
| E-11 | The fixed_x default fixes product columns too | decided | 2026-10-24 | ADR-native-defaults-2026-10-24 |
| E-12 | Reliability under the new defaults is a 0.15.0 blocker | decided | 2026-10-24 | ADR-native-defaults-2026-10-24 |
| E-13 | The fixed_x default resolves to an explicit subset (provenance) | decided | 2026-10-24 | ADR-native-defaults-2026-10-24 |
| E-14 | Versioned resolution: 0.15.0 ignores the opt-in option | decided | 2026-10-24 | ADR-native-defaults-2026-10-24 |
| E-15 | An oracle matrix gates the flip | decided | 2026-10-24 | ADR-native-defaults-2026-10-24 |
| A | SLSQP as the default solver (D19) | accepted | 2026-10-09 | ADR-native-solver-and-engines-2026-10-23 |
| B | Tiered path for constrained fits (D16; Tier 0 shipped, Tier 1 and the fallback not implemented) | approved | 2026-10-19 | ADR-native-solver-and-engines-2026-10-23 |
| D-1 | Motivation for nlminb is reliability, not speed | decided | 2026-10-23 | ADR-native-solver-and-engines-2026-10-23 |
| D-2 | nlminb starts at the zero-product branch fits | decided | 2026-10-23 | ADR-native-solver-and-engines-2026-10-23 |
| D-3 | A branch reaches nlminb by pinning coordinates | decided | 2026-10-23 | ADR-native-solver-and-engines-2026-10-23 |
| D-4 | Unconstrained default and an option (measurement gate first) | proposed | 2026-10-23 | ADR-native-solver-and-engines-2026-10-23 |
| D-5 | nlminb as a cross-check on branch fits | conditional | 2026-10-23 | ADR-native-solver-and-engines-2026-10-23 |
| D-6 | Constrained default and the order of the tiered path | decided | 2026-10-23 | ADR-native-solver-and-engines-2026-10-23 |
| D-7 | Plain linear constraints stay on SLSQP until AUGLAG is measured | decided | 2026-10-23 | ADR-native-solver-and-engines-2026-10-23 |
| D-8 | D-4 reliability gate is a paired non-inferiority test | decided | 2026-10-23 | ADR-native-solver-and-engines-2026-10-23 |
| D-9 | The gate design is fixed before the first run | decided | 2026-10-23 | ADR-native-solver-and-engines-2026-10-23 |
| D-10 | Latent structures in the D-4 gate | decided | 2026-10-23 | ADR-native-solver-and-engines-2026-10-23 |
| D-11 | A partial branch result is an error (PR \#303) | decided | 2026-10-23 | ADR-native-solver-and-engines-2026-10-23 |
| D-12 | The D1 outcome ledger rides on the D-11 error as \$ledger | decided | 2026-10-24 | ADR-native-solver-and-engines-2026-10-23 |

Each ADR opens with a YAML `decisions:` list (`id`, `title`, `status`,
`date`, optional `supersedes`); `test-adr-front-matter.R` checks it. The
ADR is the source; this table only reads it.

## Evidence validators

A native fit carries an outcome ledger (`fit@diagnostics$ledger`, since
0.14.1): the restriction, the sample, the optimizer’s acceptance state,
the discrepancy and the notices, one node per zero-product branch. The
ledger is evidence, and the code that decides whether evidence is
accepted is itself a QC subject: a false acceptance passes a forged or
mismatched fit, and a false refusal turns a genuine result into an
error.
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
runs the validators twice, on the ledger of the fit it is given and on
its own root ledger before it returns. A refusal is the error
`medfit_error_ledger`, a class that is never an optimizer failure and
never becomes an unresolved row. The semantics of the ledger are in the
[troubleshooting
guide](https://data-wise.github.io/medfit/articles/guide-troubleshooting.md);
the decisions are ADR D-11 and D-12.

**What the validators accept and refuse.** A node is accepted only when
what it must contain can be rebuilt from its own constraints and the
call: the child count and branch map, the IDs and parents, the shared
sample (by digest), domain and settings, the minimum over the resolved
branches, and, for a certified-empty branch, the premises of its
certificate. A forged ID, count, state, digest, certificate or dropped
child is refused. The MBCO root additionally ties each null to the
returned `$tests` table and to the settings its refit used.

**Genuine shapes must validate.** A validator is also tested the other
way: every shape
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
can produce must pass it. The shapes of a null node are:

| Shape | Arises when | Evidence in the suite |
|----|----|----|
| plain resolved | an ordinary refit with `a == 0` | `test-sem-mbco-root.R` |
| resolved zero-product union | the null holds a zero-product row and its branches resolve | `test-sem-mbco-root-qa.R` |
| covariance-retained | the refit’s optimizer accepted and its covariance stage failed (warning, `covariance = "failed"`) | `test-sem-post-fit.R`, `test-sem-mbco-root.R` |
| covariance-failed branch in a union | one branch of a union lost its covariance; the node reports the first such branch | `test-sem-post-fit.R`, `test-sem-mbco-root-qa.R` |
| certified excluded | the null contradicts the fit’s own literal equalities | `test-sem-mbco-root.R` |
| union with an excluded branch | a certified-empty branch beside a resolved one | `test-sem-literal-certificates.R` |
| all-excluded union | every branch certified empty: unresolved, no likelihood | `test-sem-mbco-root.R`, `test-sem-literal-certificates.R` |
| failed with the engine’s ledger | the refit stopped with an error that carries its own ledger | `test-sem-mbco-root.R` |
| failed bare node | the refit stopped with no ledger, so [`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md) builds the node: no likelihood, no witness, the condition | `test-sem-mbco-root.R` |
| failed union with a failed branch | a union where at least one branch is unresolved and the others are resolved or excluded | `test-sem-mbco-root.R` |
| latent | a model with a latent mediator, through the same path | `test-sem-mbco.R` |

`test-sem-mbco-root-qa.R` adds the grid of genuine calls (plain, k
paths, inequality, equality, boundary, `fixed_x` both ways, mean
structure, expected information, `n_starts` and `control` overrides) and
the sandwich fit.

**What is deliberately not decided.** Some forgeries cannot be told from
a genuine result without refitting, and the validator does not claim to
catch them: a consistent rewrite of the root sample together with every
`sample_hash`, and an altered parameter value inside the parameter table
of a null. The free text of the condition of a failed null (message,
class and call) is not checked. An all-excluded null is validated
against its own certificates only, so a foreign self-consistent
all-excluded union is accepted; the statistic is `NA` either way, so no
number changes.

## Adding a model

A change that alters the objective, the parameter vector, the constraint
set, the bounds or the solver path (the files in
`tests/sim/risk-files.txt`) is high-risk, and its pull request body
carries this checklist, each item ticked or `n/a: <reason>` (the
`risk-tier` workflow checks it). Every new model class needs at least
items 1 to 3.

| \# | Check | Evidence |
|----|----|----|
| 1 | Independent oracle | lavaan, OpenMx, OLS or a hand calculation agrees within a stated tolerance |
| 2 | Reliability cell | the structure is in the reliability grid (default and random starts, the data scales) |
| 3 | Planted defect | a mutant the gate must reject |
| 4 | Metamorphic invariance | rescaling a variable, reordering syntax, or a redundant constraint leaves the answer unchanged |
| 5 | Fault injection | bad solver statuses and non-finite values are refused or retried, never accepted |
| 6 | Registration | a `gates.csv` row with `oracle` and `mutants`, and a row in `structures.csv` |
| 7 | Platform run | the gate passes on the OpenBLAS runner |

## The monthly run

The `qc-monthly` workflow runs the gates on `dev` on the first of each
month, appends one row to a history on the `qc-results` branch (the
environment fingerprint, one PASS or FAIL per gate, the largest
restoration ratio, the reliability match rate, the oracle-sweep
outcomes), and opens one deduplicated GitHub issue when a gate fails or
the R version, BLAS library, nloptr, lavaan or OpenMx version changes.
The runner image is recorded and never alerts. Drift bands are not set
yet: they need about eight rows (eight months at this cadence; a manual
run adds one sooner), and a change merged to `dev` can go unseen for up
to a month unless a run is started by hand or a pull request carries the
`run-qc` label. The workflow has not run on GitHub at the time of
writing, so the history does not exist yet.

## Known limits

- No latent-model solver benchmark exists; the solver decisions that
  depend on one are marked proposed in the decision log.
- Gates run on the runner’s OpenBLAS; the reference BLAS needs a
  separate container.
- Other seeds and scales of the nonlinear floor fixture are not covered.
- The evidence validators are not a gate: `R/sem-outcomes.R` and
  `R/sem-mbco.R` are not in `tests/sim/risk-files.txt` and no
  `gates.csv` row registers them, so their protection is the unit tests
  and the admission checklist, not the OpenBLAS gate run.
- The validators cannot detect a consistent rewrite of the root sample
  and its hashes, an altered parameter value inside the parameter table
  of a null, or a changed condition text of a failed null (see Evidence
  validators).
- An all-excluded null is validated against its own certificates, not
  against the fit’s model, so a self-consistent foreign union is
  accepted (the statistic is `NA` regardless).
- A complete enumeration of zero-product branches is not a
  global-optimum certificate, and a ledger records what a fit did, not
  that its optimum is the global one.

## Lessons from the 0.14.1 port

The recurring defect of the ledger port was the false refusal of a
genuine result, not the acceptance of a forgery: a sandwich fit refused
because its nulls are refit model-based while the root records the
sandwich setting, and an all-excluded zero-product null refused as
malformed. Each was found by the full suite or an adversarial reviewer
and missed by the hand-built grids, which tested the shapes their
authors had thought of. The rule that came out of it is the table above:
list every shape the engine can produce and require each to validate,
then run the whole suite, since the engine reaches shapes no grid
enumerates.

Two process notes. Coverage instrumentation rewrites function bodies, so
a mutant that replaces source text in a function cannot find it under
`covr`; those mutants skip under coverage and run in every other check.
And the review that found the MBCO root ledger without a validator was
an adversarial review, a reader independent of the slice’s own QA,
looking for what the author’s tests assume. The record of the release is
`planning/specs/RESULT-qc-0.14.1-d1-d4-2026-10-25.md`.
