# BRAINSTORM: medfit 0.8.0 (native SEM hardening, lavaan comparison, consistency, ecosystem placement)

**Date:** 2026-10-11 | **Depth:** deep | **Focus:** arch | **Branch:** dev
**Grill ledger:** [GRILL-medfit-0-8-0-2026-10-11.md](GRILL-medfit-0-8-0-2026-10-11.md)

**Research:** two Opus 5.5 agents (read-only). Their findings are cited below with the
agents' own evidence tags: **[P]** probed, **[C]** code reading, **[R]** reviewer figure never
rerun, **[U]** unverified. Spot-checked by the main session: `fit_mediation()` takes a single
`mediator` string; `SEMFit` has no `tidy()` registration in `R/methods-tidy.R`; CLAUDE.md lists
seven classes (SEMFit is the eighth) and engines "glm, lmer, brms". Everything else is the
agents' report and needs re-verification before it drives a PR.

## Decisions taken in this session (user answers)

| Question | Decision |
|---|---|
| Theme | One release: SEM hardening + consistency audit + lavaan doc, on top of the unreleased dev fixes |
| CRAN | 0.8.0 is GitHub-only (as 0.7.0); CRAN step decided after the nloptr check |
| Nonlinear-constraint bar | OpenMx parity gate on a fixed problem set + KKT checks, with planted defects |
| lavaan doc | pkgdown article that runs both engines at site build; feature table checked by a test |
| Separate SEM package | No unless evidence says otherwise (see Section 3: evidence says no) |
| Breaking changes | Lifecycle deprecation with 2-month notice; correctness fixes exempt (CLAUDE.md) |
| nloptr | Already in Imports and drives SLSQP; nonlinear constraints extend it, no new solver |

## 1. Recommended 0.8.0 scope (ordered)

Main risk first: **nonlinear constraints (S25) rest on an S1 review that is not closed**, whose
scripts are neither in git nor on disk, and on an NNLS stationarity gate that was never ported
from the evidence script into `R/` [agent audit]. Do the foundations before the nonlinear step.

| # | Item | Size | Depends on |
|---|---|---|---|
| W1 | Recover S1 evidence into git; rerun the `04b` stationarity table; port the NNLS gate (column scaling, relative tolerance, step guard, dependent-column fixture); unify the bound verdict (plain gate rejects, projected gate only warns, F4). Changes accept/reject on fits 0.7.0 ships: NEWS entry | M | none |
| W2 | Fix F1 (consistent but redundant inequality sets rejected, e.g. `a == b; a - b < 0` fails "status 5") and F2 (`a > 1; a < 0.5` leaks an internal `lb <= ub` assertion); named errors for `Y ~ Y` and duplicate `Y ~ X` rows | S | parallel with W1 |
| W3 | S25 nonlinear constraints: nonlinear rows to closures, central-difference Jacobian, active set and SE projection from the Jacobian at the solution, Lagrangian-Hessian acceptance gate, zero-product branch split, best-of-n multi-start with spread warning | L | W1 |
| W4 | `SEMFit` methods: `tidy()`, `glance()`, `confint()`; report chi-square and df; **`anova()` / a two-model likelihood-ratio test for nested `SEMFit`s (G9)**; one coefficient-naming convention; align argument names (`sampling_weights` vs `weights`, `mbco_sem(fit)` vs `object`) | M to L | none |
| W5 | Docs: CLAUDE.md and AGENTS.md (eight classes, engines table), `methods.qmd` gaps, NEWS 0.7.0 serial/parallel wording, the lavaan comparison article | S | W4 for the table |
| W6 | E1 0.8.x matrix row after release (cross-repo write: ask first) | XS | release |
| Defer | Mean structure and FIML, four-way on native fits, several mediators in `fit_mediation(engine = "native")` | L | later |

### W3 design notes (nonlinear constraints with nloptr)

```mermaid
flowchart TD
  A[constraint text] --> B{classify}
  B -- linear --> C[constant Jacobian rows<br/>existing path]
  B -- nonlinear --> D[expression closure c theta<br/>guarded evaluator]
  D --> E[central-difference Jacobian<br/>step eps^1/3 * max abs x, 1]
  C --> F[SLSQP via nloptr]
  E --> F
  F --> G{acceptance gate}
  G -- status, residual --> H[feasibility]
  G -- Lagrangian Hessian PD --> I[stationarity, NNLS multiplier signs]
  H --> J[accept or named error]
  I --> J
  K[zero-product a*b == 0] --> L[solve each linear branch<br/>keep the minimum]
  L --> F
```

- **Branch problem** (`a*b == 0`): two local optima (F 0.0952 at a = 0, 0.1061 at b = 0), and
  no local algorithm resolves it. Recommended: detect products fixed at zero and solve each
  linear branch exactly (this is what `mbco_sem()` already does); use best-of-n multi-start with
  a spread warning for other nonlinear rows; add `NLOPT_LD_AUGLAG` only as a fallback for
  status -4, and only if a benchmark shows it helps [agent audit; AUGLAG benchmark [U]].
- Multi-start evidence: SLSQP 34/60 to 56/60 with multi-start, still misses 4 [R].
- A Lagrangian Hessian `H + sum(lambda * grad^2 c)` is needed in the gate because a product
  constraint is curved; the 0.7.0 gate uses H alone [C].
- `:=` names used inside a constraint (`ab > 0`) become nonlinear and error today [P]: this
  closes with W3.
- Unblocks ecosystem work: probmed's MBCO cannot move onto medfit until nonlinear constraints
  exist (Section 3).

### Failure modes to expose (audit F1-F6)

F1 redundant inequality sets rejected; F2 infeasible bounds give an internal message; F3 first
accepted start wins, so a gate-passing local optimum is returned silently; F4 bound verdict
differs between the plain and projected gates; F5 two simultaneously active inequalities on a
fitted model untested (G1); F6 sign check passes silently when `m'H^-1 m <= 0` [C, U].

## 2. lavaan vs medfit (content for the comparison article)

| Feature | medfit native | Status |
|---|---|---|
| `~ =~ ~~`, labels, fixed values, start/lower/upper | yes | Supported |
| Several modifiers on one term; means, thresholds, `<~`, multigroup, multilevel | no | Unsupported |
| Comma shorthand, `CONSTRAINT()`, fixed exogenous covariates | yes | Different by design |
| Estimators | ML only | Partial |
| Missing data | listwise, no FIML | Partial |
| Categorical indicators | no | Unsupported |
| Information matrix | observed (lavaan: expected) | Different by design |
| Robust SEs and weights | HC0 sandwich; equals lavaan robust SE in a probe (0.04667864) | Supported |
| Linear `== < >` constraints | yes (F1 bug) | Supported |
| Nonlinear constraints | rejected | Unsupported until W3 |
| `:=` defined parameters | values and delta-method SEs; match lavaan to 1e-8 | Supported |
| chi-square, CFI, RMSEA, SRMR | not reported (n*F equals lavaan chi-square 0.9340537 in a probe) | Unsupported until W4 |
| logLik, AIC, BIC | means counted in df | Different by design |
| Standardized estimates, modification indices, fitted, residuals | no | Unsupported |
| Mediation extraction and MBCO | yes, no four-way; `mbco_sem()` is medfit-only | Supported |
| Speed (n = 300, 20 reps, one machine) | 5.5 vs 10.9 ms observed; 8.4 vs 20.4 ms latent | [P] |

Article plan: run both engines on `mediation_demo` at site build; a test asserts every table
row's status against a live probe (pattern: the cookbook consistency tests).

## 3. Ecosystem placement: no separate SEM package

**Evidence against a split** (agent survey, cited file paths need re-verification):
1. Native route reuses medfit's lavaan extraction workers through an accessor seam; a sibling
   would need that seam exported or the 1263-line worker file duplicated.
2. `fit_mediation(engine = "native")` and the SEMFit class are wired into medfit (`zzz.R`).
3. No dependent uses `fit_sem`, `SEMFit` or `mbco_sem` yet; missingmed plans to (J8).
4. SEM adds one hard dependency (nloptr); OpenMx stays Suggests.
5. The grill ledger decided "build in medfit" (J1).

**Revisit a split only if** a dependent needs SEM without the rest of medfit, or the CRAN check
of nloptr forces it. If nloptr fails CRAN checks the fallback is Suggests behind
`requireNamespace()`, not a package split. **nloptr on CRAN/r-hub is unchecked [U].**

**Consolidation targets** (all through lifecycle deprecation; none execute in 0.8.0 unless noted):

| Pkg | Move | Notes |
|---|---|---|
| RMediation | Rebase OpenMx MBCO on `mbco_sem()` (J10); lavaan to Suggests; `ci_medfit.R` reuse `.path_se()` | removes OpenMx and a hard lavaan import |
| medsim | Delegate copied a/b fits, Sobel SE, Rubin variance, MBCO, MC CI to owners; `methods_pmed.R` mislabeled MBCO | largest duplication |
| probmed | Bootstrap re-implements `bootstrap_mediation()`; depends on internal `m_<pred>`/`y_<pred>` names | MBCO there is a different estimand, blocked on W3 |
| medfit | Export a sanctioned API: coefficient-name contract and a pooled-object constructor | replaces internals probmed and missingmed lean on (`pool.R:130-134` nulls `@data`/`@sigma_m` to pass the validator) |
| all | One `tidy` generic (`generics::tidy`); RMediation defines its own, missingmed re-exports broom's | masking order issue, dispatch failure unverified |
| medrobust | Manifest says "suggests medfit" but DESCRIPTION has none; `*_legacy` simulation code looks dead | housekeeping |
| mediationverse | missingmed absent from the meta-package | housekeeping |

## 4. Test plan (red-first; tiers by change shape)

| Tier | Plan |
|---|---|
| unit | NNLS gate on dependent columns (the 0/0 case); F1, F2 fixtures; `Y ~ Y` and duplicate-row errors; bound-verdict parity (F4) |
| integration | OpenMx-parity gate on a fixed nonlinear problem set; KKT checks; planted defect (nonlinear row misclassified as linear must be caught); G1 fixture `a+b<0.2; a-b<0.1`; best-of-n on a two-optima latent model; `:=` inside a constraint |
| e2e | lavaan article builds and its table matches live probes; `SEMFit` `tidy`/`glance`/`confint` against lavaan |
| dependency | nloptr CRAN-flavor check (r-hub, win-builder); revdep run of probmed and RMediation suites against dev |
| count-cascade | pkgdown reference lists every export; refcard names every export and class |

Stubs TODO(author): delete if not contract-bearing. Per `e2e-before-pr`, each behavior PR needs
a transcript of a run that can fail.

## 5. Documentation

CHANGELOG/NEWS `[Unreleased]` entries for W1 (verdict change), W3, W4; `methods.qmd` (near-singular
rejection, bound verdict split, nonlinear section); `?"medfit-syntax"` nonlinear constraint
syntax; the lavaan comparison article and Models menu entry; CLAUDE.md and AGENTS.md (eight
classes, engines table); cookbook recipe for nonlinear MBCO. Version and count lines stay in the
release step.

## 6. Open questions for the 0.8.0 grill

1. Does the verdict change in W1 (unified bound gate) qualify as a correctness fix exempt from
   deprecation, or does it need a notice?
2. Is the zero-product branch split enough for 0.8.0, or does the parity gate also require
   general nonlinear rows (`a*b == c`, inequalities on products)?
3. Which of the consolidation moves start in 0.8.0 (medfit-side API export only, or the
   dependents' PRs too)? Cross-repo writes need your go-ahead each time.
4. Run the nloptr CRAN-flavor check before or after W3?
5. Where do the recovered S1 scripts live (`planning/specs/evidence/`)?

## Recommended next step

Start W1 and W2 together: they are small, independent of the nonlinear design, and their
fixtures de-risk W3. Grill the open questions first
(`/craft:grill planning/specs/BRAINSTORM-medfit-0-8-0-2026-10-11.md`).
