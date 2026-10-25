# BRAINSTORM: semopy as a third independent oracle in medfit quality control (2026-10-24)

Assumption: "sempoy" in the request is [semopy](https://pypi.org/project/semopy/), the Python SEM package (web search found no package named sempoy). Status of every semopy claim below: **from its PyPI page and search snippets, not tested here**. Items marked VERIFY are the spike's job.

## Spike result (2026-10-24, semopy 2.3.11 through `uv run --with semopy==2.3.11`)

- Quick win 1 is done: the simple model on `mediation_demo` matches `fit_sem(fixed_x = TRUE)` to about 1e-6 in
  estimates and 3e-8 in SEs, **only with `options = {"ftol": 1e-12}`**. semopy's default stop (9 SLSQP iterations)
  leaves `a` at 0.456039 instead of 0.455996, a 4e-5 gap; any semopy gate must set the tolerance.
- Labels (`a*treatment`) work. `ab := a*b` raises `NotImplementedError: ab is an unknown command`, so defined
  parameters are computed outside semopy.
- The exogenous variance is not estimated (no row), as lavaan's `fixed.x = TRUE`; compare against `fixed_x = TRUE`.
- `obj = "FIML"` on the raw data gives different estimates (a = 0.611); not investigated, not used.
- Script and output saved as `tests/sim/oracles/semopy-simple.py` and `.csv`; shown on the site in
  `vignettes/articles/syntax-crosswalk.qmd`, tied to the native fit by `tests/testthat/test-syntax-crosswalk.R`.

## What the QC has today (from `tests/sim/gates.csv`, `structures.csv`)

| Oracle | Used by | Language | Optimizer lineage |
|---|---|---|---|
| lavaan | parity, se, reliability, factor, four-way-kat, compare-lr | R | its own (nlminb / BFGS family) |
| OpenMx | constrained parity, compare-lr | R | SLSQP/NPSOL family |
| hand oracle, `lm`, `glm`, nonparametric bootstrap | four-way, SE tests | R | none |

medfit's own solver is nloptr SLSQP. semopy's default is the ML objective with SLSQP (scipy) ([PyPI](https://pypi.org/project/semopy/)), so on solver lineage it is **not** independent of medfit or OpenMx; it is independent in code, language, parameterization and defaults. That is still useful (an implementation bug in medfit's likelihood or SE code would not be shared), but it does not test "SLSQP pathologies" independently. VERIFY whether semopy's other optimizers (the README says other objectives and optimizers can be passed) are usable for a non-SLSQP cross-check.

## Quick wins (< 30 min)
1. **Spike, no repo change:** `uv run --with semopy` a script that fits the `mediation_demo` simple model (`mediator1 ~ a*treatment`, `outcome ~ b*mediator1 + cp*treatment`) and prints estimates, SEs and log-likelihood; compare with `fit_sem()` at 1e-6. Decides everything below.
2. **Write down the rule now:** semopy joins only if estimates agree with lavaan to the parity tolerance on at least the observed and latent cells; disagreement is a finding to investigate, not a tolerance to widen.
3. **Check maintenance:** latest release and date (libraries.io lists 2.3.11) before taking a CI dependency.

## Medium effort (1-2 hrs)
- [ ] **Shape B (recommended): subprocess script, JSON out.** `tests/sim/semopy-oracle.py` reads a CSV the R gate writes, fits, writes JSON; the R gate reads it. No reticulate, no R Suggests entry; the gate skips (reports `n/a`, never silently passes) when `uv`/Python/semopy is absent, mirroring how a missing lavaan is a failed gate in CI but a skip locally.
- [ ] **Scope the first gate to what semopy supports:** unconstrained observed, latent, parallel, serial structures (the `parity` and `se` rows). The PyPI page confirms fixing a coefficient to a value (`y ~ 2*x1 + x2`); equality constraints, defined parameters (`:=`) and nonlinear constraints are **unconfirmed** (VERIFY in the [syntax page](https://semopy.com/syntax.html)), so constraint gates keep OpenMx.
- [ ] **Align conventions before comparing:** covariance denominator (N vs N-1), latent scaling defaults, SE type (expected vs observed information), parameter naming and order, ordinal handling off. Each is a known source of false disagreement; list them in the gate's header comment.
- [ ] **Registration:** a `gates.csv` row (`oracle` = `semopy`, `mutants`), rows in `structures.csv`, an ADR decision (D-12: third oracle, why, scope, what it does not test), env fingerprint adds Python and semopy versions so a changed version raises the monthly alert like lavaan/OpenMx do.

## Long-term (future sessions)
- [ ] Put the semopy gate in `qc-monthly` first, not in the PR gates: new external dependency, a different runtime, and the gates job already hit its 75-minute limit twice on 2026-10-24 (cause unproven). Promote to the PR gates after three clean monthly runs.
- [ ] Use semopy as a tie-breaker role: when lavaan and native disagree on an unconstrained cell, the third vote is recorded in the results CSV.
- [ ] If semopy supports random effects (semopy 2 adds them, per its [2021 paper](https://arxiv.org/abs/2106.01140v1)), consider it as an oracle for the 2-1-1 cluster structure; VERIFY it matches `lmer`-based `ClusterMediationData`, which has no SEM oracle today.

## Risks
| Risk | Mitigation |
|---|---|
| Convention mismatch looks like a medfit bug | Spike compares to lavaan first; only semopy-vs-lavaan-vs-native three-way gaps count |
| Python dependency drift | Pin version in the CI install and report it in the fingerprint |
| Same-solver blind spot | State it in the ADR; do not claim solver independence |
| Slower or flakier CI | Monthly job first; subprocess with a timeout |
| semopy maintenance stalls | Check release dates in quick win 3; treat as optional oracle (skip = `n/a`) |

## Open questions for the author
1. Scope: parity and SEs only, or also log-likelihood and fit indices?
2. CI placement: monthly-only first (recommended) or straight into the `rest` shard?
3. Is "sempoy" semopy, as assumed?

## Recommended next step
-> Run quick win 1 (the spike). It costs under 30 minutes, needs no repo change, and answers whether semopy agrees with lavaan at all, which gates every other item here.
