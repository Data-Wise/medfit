# CLAUDE.md for medfit Package

This file provides guidance to Claude Code when working with code in this repository.

---

## Quick Reference

**Package Type**: R package (S7-based mediation infrastructure)
**Main Branch**: `main` | **Dev Branch**: `dev`
**Minimum R**: 4.1.0 (native pipe `|>`)

### Essential Commands

```r
# Development cycle
devtools::load_all()              # Load package
devtools::document()              # Update docs
devtools::test()                  # Run tests
devtools::check()                 # R CMD check

# Documentation
pkgdown::build_site()             # Build website
usethis::use_pkgdown_github_pages()  # Initial setup

# Testing
testthat::test_file("tests/testthat/test-classes.R")
covr::package_coverage()          # Target: >90%
```

### Workflow Keywords

- `doc` - Update planning documentation, README, and NEWS
- `check` - Run R CMD check --as-cran, build/preview website, check GitHub Actions
- `sync` - Commit and push changes to remote

---

## About This Package

**medfit** is the foundation package for the mediationverse ecosystem, providing:
- **S7 classes**: `MediationData`, `InteractionMediationData`, `SerialMediationData`, `ParallelMediationData`, `JointMediationData`, `ClusterMediationData`, `BootstrapResult`, `SEMFit` (native SEM fit)
- **Extraction**: Generic `extract_mediation()` with methods for lm/glm/lavaan/lmer and `SEMFit` (native)
- **Fitting**: Formula-based `fit_mediation()` with the `glm`, `regmedint` and `lmer` (cluster-level treatment, `cluster =`) engines, case `weights`, and `se_type = "sandwich"` (HC3); `fit_sem()` and `fit_mediation(engine = "native", model = )` fit medfit model syntax with the native ML engine (`SEMFit`; `fixed_x = TRUE` or names fixes exogenous moments at the sample values, as lavaan's `fixed.x = TRUE`: same structural results, conditional logLik)
- **Inference**: delta-method effect SEs in `tidy()`/`confint()`; bootstrap (parametric, nonparametric, plugin)
- **Data**: bundled simulated `mediation_demo` for every workflow
- **Math**: every formula lives in `vignettes/articles/methods.qmd` (Methods and Formulas)

**Core Principle**: medfit provides infrastructure, not effect sizes. Dependent packages (probmed, RMediation, medrobust) add methodological contributions.

### Package Ecosystem

| Package | Uses medfit for | Adds |
|---------|----------------|------|
| **probmed** | Fitting, extraction, bootstrap | P_med computation, visualization |
| **RMediation** | Extraction, bootstrap utilities | DOP, MBCO, MC methods |
| **medrobust** | Optional naive estimates | Sensitivity bounds, falsification |

---

## Coding Standards

### Style and Conventions

- **R version**: 4.1.0+ (native pipe `|>`)
- **OOP**: S7 modern object system
- **Style**: tidyverse with native pipe
- **Naming**: snake_case for functions/properties, CamelCase for classes

### File Organization

```
R/
├── aaa-imports.R           # Package imports
├── aab-generics.R          # S7 generics (load before methods!)
├── medfit-package.R        # Package documentation
├── classes.R               # S7 class definitions (all eight classes)
├── data.R                  # mediation_demo documentation
├── fit-glm.R               # fit_mediation(), glm engine, weights/sandwich
├── fit-regmedint.R         # regmedint engine adapter
├── fit-lmer.R              # lmer engine: cluster means, rewritten formulas, REML fits
├── extract-lm.R            # lm/glm extraction (simple, four-way, serial, parallel)
├── extract-joint.R         # JointMediationData worker, stacked-OLS vcov
├── extract-lavaan.R        # lavaan extraction
├── extract-lmer.R          # ClusterMediationData from lme4 fits (term detection by value, KR)
├── sem-*.R                 # native SEM engine internals: parse, expr, model, ml, optim, constraints, se, sandwich, fit, mbco (mbco_sem()), outcomes (the versioned outcome ledger, `fit@diagnostics$ledger`, its validators `.sem_valid_outcome()` and `.sem_valid_mbco_outcome()`, and the D2 literal zero/nonzero certificates, `.sem_literal_zero_certificate()`)
├── fit-sem.R               # fit_sem(), .fit_mediation_native()
├── extract-sem.R           # accessor seam (lavaan and native), extract_mediation() for SEMFit
├── methods-sem.R           # SEMFit print/summary/coef/vcov/nobs/logLik; sem-syntax-help.R is ?"medfit-syntax"
├── compare-lr.R, compare-lr-openmx.R   # compare_lr(): detector (.lr_assess), lavaan and OpenMx adapters
├── native-defaults.R       # 0.15.0 defaults resolver, lenient fixed_x subset
├── generics-effects.R      # nie/nde/te/pm/paths/decompose
├── effect-se.R             # delta-method gradients, .effect_se(), .path_se()
├── methods-base.R          # print/summary/coef/vcov/confint/nobs
├── methods-tidy.R          # tidy()/glance()
├── med.R                   # med()/quick()
├── bootstrap.R             # Bootstrap infrastructure (cluster resampling via cluster =)
├── utils.R                 # Utilities, serial path system (te() over all paths)
└── zzz.R                   # .onLoad() for dispatch
```

### Naming Patterns

**Functions:**
- Exports: `fit_mediation()`, `extract_mediation()`, `bootstrap_mediation()`
- Internal: `.fit_mediation_glm()`, `.bootstrap_parametric()`

**Arguments:**
- `formula_y`, `formula_m` - Model specifications
- `treatment`, `mediator`, `outcome` - Variable names
- `engine` - "glm", "lmer", "regmedint", "native" ("brms" is planned)
- `method` - "parametric", "nonparametric", "plugin"
- `n_boot`, `ci_level` - Bootstrap parameters

**S7 Classes:**
- CamelCase: `MediationData`, `BootstrapResult`
- Properties: snake_case (`@a_path`, `@boot_estimates`)

---

## Defensive Programming Essentials

### 1. Input Validation with checkmate

**ALWAYS** validate arguments at function entry:

```r
my_function <- function(x, method, data) {
  # --- Input Validation ---
  checkmate::assert_numeric(x, .var.name = "x")
  checkmate::assert_choice(method, c("parametric", "nonparametric"), .var.name = "method")
  checkmate::assert_data_frame(data, min.rows = 1, .var.name = "data")

  # Allow NULL for optional args
  checkmate::assert_string(optional_arg, null.ok = TRUE, .var.name = "optional_arg")

  # ... function body
}
```

**Quick reference:**
- `assert_string()` - Single character
- `assert_numeric()` - Numeric vector
- `assert_count()` - Single positive integer
- `assert_flag()` - Single logical
- `assert_choice()` - Value from set
- `assert_data_frame()` - Data frame
- `assert_multi_class()` - Any of multiple classes

### 2. Ellipsis Validation

```r
my_function <- function(x, ...) {
  rlang::check_dots_used()  # Error on unused dots (catches typos)
}
```

### 3. S7 Class Validation

```r
MyClass <- S7::new_class(
  "MyClass",
  properties = list(
    x = S7::class_numeric
  ),
  validator = function(self) {
    if (any(self@x < 0)) return("x must be non-negative")
    NULL  # Return NULL if valid
  }
)
```

### 4. Critical Rules

- **Never** use `library()` or `require()` in package functions
- **Always** use explicit namespacing: `stats::glm()`, `MASS::mvrnorm()`
- **Clean up** side effects with `on.exit()`
- **Test** error conditions for all validation

---

## S7 Object System Quick Guide

### Core Classes

**MediationData** (Simple: X → M → Y)
- Paths: `a_path`, `b_path`, `c_prime`
- Inference: `estimates`, `vcov`
- Metadata: `treatment`, `mediator`, `outcome`, `n`

**InteractionMediationData** (Simple with X × M: four-way decomposition)
- Paths plus `interaction` (θ₃); components `cde`, `int_ref`, `int_med`, `pie`; `m_star`
- E[M | X = 0] uses the mediator model's design-column means (factor dummies; case-weighted)

**SerialMediationData** (Serial: X → M1 → M2 → Y)
- Paths: `a_path`, `d_path` (vector), `b_path`, `c_prime`
- Flexible: scalar `d_path` for 2 mediators, vector for 3+
- Properties: `mediators` (names), `mediator_predictors` (list)
- `nie()` is the chain effect by default; `nie(type = "total")` and `te()`/`pm()` sum every path (skip paths stored as `a2`, `b1`, `d1_3`, ...)

**ParallelMediationData** (X → M_j → Y)
- `a_paths`, `b_paths`; NIE = Σ a_j b_j. lm/glm `@vcov` omits Cov(a_j, a_j')

**JointMediationData** (several mediators with X × M products)
- Joint NDE/NIE/CDE over the mediator block (VanderWeele & Vansteelandt 2014); stacked-OLS `@vcov`; `joint_effects()` for bootstrapping

**ClusterMediationData** (treatment assigned to clusters, 2-1-1)
- Paths `a_path`, `b_within`, `b_between`, `c_prime`; NIE = a × b_between, own a × b_within, spillover a × (b_between − b_within) (`decompose()`, labeled large-cluster approximation, D11 warning)
- `extract_mediation()` on `lmer` fits finds the mean/within/raw terms by value; `fit_mediation(engine = "lmer", cluster = )`; `se_type = "kr"` for Kenward-Roger t intervals; `bootstrap_mediation(cluster = )` for cluster resampling

**BootstrapResult**
- Inference: `estimate`, `ci_lower`, `ci_upper`
- Distribution: `boot_estimates`
- Metadata: `method`, `n_boot`

### S7 Documentation Patterns

**Class constructors:**
```r
#' @param a_path Numeric scalar: effect of treatment on mediator
#' @return A MediationData S7 object
#' @export
MediationData <- S7::new_class(...)
```

**Methods:**
```r
#' @param x A MediationData object
#' @noRd  # CRITICAL: Don't use @export for S7 methods!
S7::method(print, MediationData) <- function(x, ...) { ... }
```

**Generics:**
```r
#' @param object Fitted model object
#' @param ... Additional arguments passed to methods
#' @export
extract_mediation <- S7::new_generic("extract_mediation", dispatch_args = "object")
```

### S7 Method Registration (REQUIRED)

In `R/zzz.R`:

```r
.onLoad <- function(libname, pkgname) {
  # 1. Register classes with S4 (BEFORE methods_register!)
  S7::S4_register(MediationData)
  S7::S4_register(SerialMediationData)
  S7::S4_register(BootstrapResult)

  # 2. Register methods
  S7::methods_register()

  # 3. Register Suggested package methods
  if (requireNamespace("lavaan", quietly = TRUE)) {
    tryCatch(.register_lavaan_method(), error = function(e) invisible(NULL))
  }
}
```

**Import full methods package:**
```r
#' @import methods
```

---

## Documentation Quick Guide

### LaTeX Equations by Context

| Context | File | Inline | Display |
|---------|------|--------|---------|
| Function docs | `.Rd` / roxygen2 | `\eqn{a \times b}{a * b}` | `\deqn{...}{...}` |
| Vignettes | `.qmd` | `$a \times b$` | `$$...$$` |

**Roxygen2 rules:**
- Two-argument form: `\eqn{latex}{ascii}` (LaTeX + fallback)
- No whitespace between command and arguments
- Avoid Unicode (θ, Σ) in .Rd files - use `\eqn{\theta}`, `\eqn{\Sigma}`

### Quarto Vignettes

**Chunk format (PREFERRED):**
````markdown
```{r}
#| label: my-chunk
#| eval: false
#| echo: true
x <- 1 + 1
```
````

**Not this:**
````markdown
```{r my-chunk, eval=FALSE, echo=TRUE}
x <- 1 + 1
```
````

**Key differences:**
- Hash-pipe (`#|`) for options
- Hyphens in labels: `my-chunk` not `my_chunk`
- Lowercase booleans: `true`/`false` not `TRUE`/`FALSE`

### pkgdown Configuration

**Initial setup:**
```r
usethis::use_pkgdown_github_pages()  # Creates gh-pages, workflow, config
```

**_pkgdown.yml essentials:**
- List ALL exported topics in `reference:`
- Use `starts_with()` for method patterns
- Enable MathJax: `template: math-rendering: mathjax`
- Local builds go to `docs/`; the site is published by the `pkgdown.yaml` workflow to `gh-pages`

**Vignette dependencies:**
- Add to DESCRIPTION `Suggests` OR
- Use `Config/Needs/website` for website-only deps

**Computationally expensive vignettes:**
```r
usethis::use_article("article-name")  # Not included in R CMD check
```

---

## Testing Strategy

### Coverage

- **Target**: >90% overall, 100% critical paths
- **Critical**: S7 classes, extraction, bootstrap
- **Policy integration**: PR #370 merged into `dev` as `c42e306e`; exact-head
  lint, pkgdown and risk-tier passed; merged feature branch/worktree cleaned up.
- **Hosted coverage**: PRs to `main` and pushes to `main`, unconditionally,
  including metadata-only release merges. No coverage on dev PRs or dev pushes.
  Run development checks locally using Rforge; retain independent numerical oracles.
  For lint, install the current source into an isolated library and verify fresh R
  resolves it before scanning; preserve dependency libraries and record source provenance.
  This coverage policy does not change other fast hosted checks.
- **Release-only cost**: keep the platform matrix and OpenBLAS gates deferred
  until release to `main`; this policy does not disable fast PR checks.

### Organization

```
tests/testthat/
├── helper-test-data.R, helper-joint.R   # Test data generators, joint oracles
├── test-classes*.R, test-validators.R   # S7 validation
├── test-extract-*.R                     # lm/glm, lavaan, serial, parallel, interaction, joint
├── test-cluster-211.R, test-cluster-boot.R, test-cluster-harness.R, helper-cluster.R   # cluster mediation: guards, oracles, KR, fit engine, cluster bootstrap, harness
├── test-refcard-coverage.R, test-cookbook-consistency.R   # refcard names every export and class; cookbook recipes, links and cluster data match methods.qmd
├── test-model-pages*.R, test-guide-*.R   # every model page is on the landing page, index and menu; links and cookbook anchors resolve; each error message the pages and guides quote is triggered, and Suggests-dependent cases skip when the package is absent
├── test-lavaan-comparison.R             # the lavaan comparison article's feature table: each row's status is probed live against lavaan
├── test-effect-se.R, test-confint-paths.R, test-methods-*.R   # SEs, confint, tidy
├── test-serial-total-effect.R           # te() over every path
├── test-fit-*.R                         # glm, regmedint, m_star, native (test-fit-sem.R)
├── test-sem-*.R, helper-sem.R           # native SEM engine: parser, model, optimizer, constraints, SEs, weights, MBCO, methods, probmed gate, product term (`test-sem-product-*.R`: token, table, materialize, rules, mean, modeltest, extract; `test-four-way-oracle-*.R` with `helper-four-way-oracle.R`; the evidence contract: `test-sem-outcomes`, `-literal-certificates`, `-branch-map`, `-post-fit` (+ `-qa`), `-mbco-root` (+ `-qa`), `test-compare-lr-retained-null`)
├── test-native-defaults*.R, helper-native-defaults.R   # default-change warning, 0.15 option, lenient subset; oracle gate (tests/sim/native-defaults-oracle.R)
├── test-bootstrap*.R                    # Bootstrap methods
└── test-mediation-demo.R                # bundled data known answers
```

Verify numeric claims against an independent oracle (lavaan `:=`, `lm(Y ~ X + C)`
for the total effect, a hand calculation, or a nonparametric bootstrap) and plant a
defect the test must catch; the SE tests use this pattern throughout.

### Optimizer quality control (new model classes)

A change that alters the objective, the parameter vector, the constraint set, the bounds or the solver path
(`tests/sim/risk-files.txt`) is high-risk: its PR body carries the seven-item admission checklist, each item ticked or
`n/a: <reason>` (the `risk-tier` workflow checks it): independent oracle, reliability cell, planted defect,
metamorphic invariance, fault injection, registration (`gates.csv` row with `oracle` and `mutants`, a row in
`tests/sim/structures.csv`), platform run on the OpenBLAS runner. Every new structure needs at least an oracle, a
reliability cell and a planted defect; `test-gate-coverage.R` fails when a gate row is not real or a structure has no
gate. The `qc-monthly` workflow records one history row a month on the `qc-results` branch and opens an issue on a
failing gate or a changed environment. Decisions live in `planning/specs/ADR-*.md`; each carries a `decisions:` list
in its front matter (`test-adr-front-matter.R`). Plan and ledger: `planning/specs/BRAINSTORM-optimizer-quality-control-2026-10-23.md`.

### What to Test

1. **S7 validation** - Type checking, validators, edge cases
2. **Extraction** - Accuracy, consistency, model types
3. **Fitting** - Valid output, formula parsing, convergence
4. **Bootstrap** - Reproducibility, CI coverage (~95%), parallel vs sequential
5. **Edge cases** - Small n, non-convergence, singular matrices, missing data

---

## Code Architecture

### Function Hierarchy

**User-facing:**
1. `fit_mediation()` - Fit models with formula interface
2. `extract_mediation()` - Extract from fitted models
3. `bootstrap_mediation()` - Bootstrap inference

**Internal:**
- `.fit_mediation_glm()` - GLM engine
- `.bootstrap_parametric()` - Parametric bootstrap
- `.bootstrap_nonparametric()` - Nonparametric bootstrap
- `.bootstrap_plugin()` - Plugin estimator

### Model Extraction Pattern

All `extract_mediation()` methods:
1. Validate inputs (variable names exist; unsupported products error)
2. Extract parameters (a, b, c'; plus d, skip paths, θ₃ as the structure needs)
3. Extract covariance matrix, with alias rows (`a`, `b`, `c_prime`, `d1`, ...)
4. Extract residual variances (if Gaussian)
5. Get data (if available); store covariate means on `@data` when effects need them
6. Create the S7 object for the structure (see `?extract_mediation`)
7. Return

Effect SEs (`tidy()`, `confint()`, `summary()`) all go through one gradient
builder per class in `R/effect-se.R`; path SEs through `.path_se()` (alias rows
first, error instead of guessing).

### Bootstrap Methods

| Method | Samples from | Speed | Use case |
|--------|-------------|-------|----------|
| Parametric | N(θ̂, Σ̂) | Fast | Default, assumes normality |
| Nonparametric | Resample data, refit | Slow | Robust, no normality needed |
| Plugin | Point estimate only | Fastest | Quick checks, no CI |

**Parallel processing:**
- Uses `parallel::mclapply()` (Unix)
- Auto-detects cores
- Set seed for reproducibility

### Native SEM constraint pipeline (`R/sem-constraints.R`, `R/sem-optim.R`)

Linear `==`, `<`, `>` constraints become unit-length rows `a'theta + b` (`.sem_constraint_rows()`); the
solver (nloptr SLSQP) gets constant Jacobians in natural units `x = theta / u`; every solution passes the
acceptance gate (status, constraint residual, Newton decrement on the active null space) with **all** rows.
Redundancy rule: SLSQP stops on a rank-deficient active Jacobian (LICQ fails), so the solver is handed an
independent subset of the equality rows (`.sem_independent_rows()`, #122), and the gate still checks every
row, so contradictory sets error. An inequality row in the span of the equality rows (residual below 1e-12) has a
constant value on the equality set; when it is satisfied it is active everywhere, the same degeneracy, so
`.sem_drop_implied_ineq()` (T6) drops it from the solver's rows and the gate still checks it. A violated implied row
is kept and left to the gate (no up-front error: near-dependence is not proof of infeasibility). Background and evidence:
`planning/specs/RESEARCH-redundant-constraints-2026-10-11.md`.

Nonlinear rows (`cp == a*b`, `a*b > k`, sums of products): `.sem_nl_rows()` builds closures over validated call trees
(guarded evaluator `.sem_expr_value`), values and Jacobians by central differences recomputed at every point, `cons$nl`
(equalities) and `cons$nli` (inequalities as `c <= 0`); the active set orders linear equalities, nonlinear equalities,
linear then nonlinear inequalities, and the Jacobian for the gate and the covariance projection `Z (Z' I Z)^-1 Z'` is
evaluated at the solution, not the start. The gate uses the Lagrangian Hessian (`.sem_lagrangian_hessian()`); with a
nonlinear row every start is tried and the best accepted one kept (spread warning when optima differ). A product of
labels set to zero is solved exactly by `.sem_fit_branches()` (one linear fit per factor, up to 64, clean start each).
`.sem_polish()` takes Newton steps on the KKT system of the active set after SLSQP is accepted (SLSQP stops about
3e-5 short along a flat tangent) and keeps the polished point only if the gate accepts it again. Evidence:
`tests/sim/sem-nonlinear-gate.R` (240 runs, `MUTANT=` switches) and `tests/sim/sem-mbco-k-size.R`.

### Native mean structure (`R/sem-ml.R`, `R/sem-fit.R`, `R/sem-optim.R`, `R/sem-constraints.R`)

Any `~1` row (also `y ~ 1 + x`) turns `ram$has_mean` on and frees every unwritten observed intercept (lavaan parity);
`y ~ 0*1` is a restriction (df + 1), a free latent `~1` errors, `meanstructure` is tri-state. The mean term is additive
in F, the information and the sandwich scores (no cross block). Scale rule (G9): the information, its inverse and the
gates work in centered coordinates `phi` (`.sem_center_map()`, `theta = T (phi + c0)`, Hessian by directional finite
differences, `V = T V_phi T'`); a fit whose intercepts are all free and absent from constraints, bounds and starts
runs on mean-centered data and maps back (`.sem_shift_ok()`). Intercept constraints keep the plain solver coordinates
with a centered gate: checked to mean/sd 1e3, not 1e5. `anova()` treats a covariance-only fit as having free implicit
intercepts (`.sem_anova_table()`). Four-way on a `SEMFit` needs the `:` product (below); a product turns the mean structure on. Gates:
`tests/sim/sem-mean-constrained-gate.R` (`MUTANT=badshift|nocenter`), the OLS oracle in `test-sem-mean-*.R`.

### Native product term and four-way (`R/sem-parse.R`, `R/sem-model.R`, `R/sem-fit.R`, `R/sem-anova.R`, `R/extract-sem.R`)

`x:m` on a regression's right side is an observed exogenous column `x * m`, built by `.sem_materialize_products()` after
listwise deletion; `.sem_product_name(a, b)` (C-locale sort, `m:x` for `x`, `m`) is the one name every consumer uses. A
product turns the mean structure on (`meanstructure = FALSE` errors). Supported class (`.sem_check_product_parsed()`,
`.sem_check_product_completed()`): recursive, rule 8 (no factor that is the target or a descendant), no outcome residual
covariance (the auto-added pure-outcome one is fixed at 0 with one note, GRILL H6), no shared, fixed, bounded or constrained
coefficient, free unshared intercepts; each rejection message is tabulated in `?"medfit-syntax"` and the native model
page. `.sem_product_modeltest()` marks the global test invalid when a product factor is a regression target or the exogenous
block is restricted: `glance()` chi-square/df/p are `NA` with a note, `anova()` and `mbco_sem()` refuse
(`.sem_check_modeltest()`), `information = "expected"` is refused for an endogenous factor; `.sem_chisq()` is the raw statistic (`glance()` reads it for valid fits, the gates read it when the verdict is `NA`).
`extract_mediation(<SEMFit>)` returns `InteractionMediationData` when the outcome equation carries the
treatment-by-mediator product (names carry the canonical `m:x`); another product on the treatment or mediator is refused.
Plan and evidence: `planning/specs/PLAN-native-four-way-2026-10-12.md`.

---

## Ecosystem Coordination

### Central Planning

Location: `~/projects/r-packages/mediation-planning/` (start at `PROJECT-HUB.md`). medfit's
`planning/ECOSYSTEM-COORDINATION.md` is a separate 2025-12 brainstorm snapshot, not a copy.

| Document | Purpose |
|----------|---------|
| `docs/ECOSYSTEM-COORDINATION.md` | Version matrix, change propagation, releases |
| `docs/MONTHLY-CHECKLIST.md` | Health checks |

### Change Propagation

When changes affect dependent packages:
- Run `tests/testthat/test-dependents-contract.R` and update its table when changing class properties or exports.
1. **Document** - Update NEWS.md with ecosystem notes
2. **Test** - `revdepcheck::revdep_check()`
3. **Notify** - Create issue with 2-month notice for breaking changes
4. **Coordinate** - Schedule updates before release

### Breaking Changes

1. GitHub issue with `[BREAKING]` prefix
2. 2-month deprecation period minimum
3. Use `lifecycle::deprecate_warn()`
4. Document migration path
5. Update ECOSYSTEM-COORDINATION.md

**Exemption — correctness fixes:** a change that replaces a wrong result with the right one
(e.g. #81 serial `te()`/`pm()`, #82 `confint()` path rows) skips the deprecation period: there is
no behavior worth preserving. Ship it with a NEWS behavior-change note and at least a minor
version bump, and check dependents' usage first (decided 2026-09-24,
`planning/specs/GRILL-0.5.0-release-2026-09-24.md`).

---

## Common Pitfalls

1. **Variable name mismatches** - Ensure treatment/mediator match model
2. **Ignoring convergence warnings** - Check `converged` property
3. **Using plugin for inference** - Always bootstrap for CIs
4. **Skipping validation** - Use checkmate everywhere
5. **Breaking compatibility** - Coordinate with ecosystem
6. **Suppressing errors without understanding** - Research first, fix properly

---

## Important Implementation Details

### Extensible Mediation Architecture

**Design principle**: Separate classes for separate structures.

| Class | Structure | Indirect effect |
|---|---|---|
| `MediationData` | X → M → Y | a × b |
| `InteractionMediationData` | X → M → Y with X × M | INTmed + PIE (VanderWeele 2014 four-way) |
| `SerialMediationData` | X → M1 → … → Mk → Y | chain a × d × … × b; total over every path via `nie(type = "total")` |
| `ParallelMediationData` | X → M_j → Y | Σ a_j b_j |
| `JointMediationData` | several mediators with X × M products | joint NIE over the block |
| `ClusterMediationData` | cluster-level X → M → Y with mixed models | a × b_between (own a × b_within, spillover the rest) |

**Why separate classes?** Clean separation, no over-engineering, extend without
breaking existing code, type safety via S7 validators.

### Engines

| Engine | Package | Method | Status |
|--------|---------|--------|--------|
| `"glm"` | (internal) | fit, then `extract_mediation()` | ✓ |
| `"regmedint"` | regmedint (Suggests) | VanderWeele closed-form | ✓ (no weights/sandwich) |
| `"lmer"` | lme4, pbkrtest (Suggests) | mixed models for cluster-level treatment; `cluster =`, `se_type = "kr"` | ✓ (no weights/sandwich/families) |
| `"native"` | (internal) | maximum-likelihood SEM from model syntax (`model = `, one mediator through `fit_mediation()`; serial and parallel through `fit_sem()` then `extract_mediation()`); latent mediators, linear and nonlinear constraints, `weights`/`se_type = "sandwich"`; `anova()`, `tidy()`/`glance()`; `mbco_sem()` (k paths) | ✓ (observed intercepts and means, `meanstructure =`, the `:` product term with four-way through `extract_mediation()` in a supported class; no latent means, no latent products) |
| `"gformula"`, `"ipw"` | CMAverse | G-computation, IPW | Planned |
| `"tmle"` | tmle3 | Targeted learning | Future |

---

## Troubleshooting

### S7 "Class has not been registered with S4"

**Fix:**
1. Call `S7::S4_register(ClassName)` in `.onLoad()`
2. Call `S4_register()` BEFORE `methods_register()`
3. Import full methods: `@import methods`

### S7 "Overwriting method" Messages

During `devtools::load_all()`:
- **Known development-time issue** (GitHub #474)
- Does NOT affect installed packages
- Do NOT suppress with `suppressMessages()`

### lavaan Extraction Failures

**Parameter label conflicts:**
- When model uses `M ~ a*X`, parameter already named "a"
- Check `names(lavaan::coef(fit))` before adding aliases

**Data type issues:**
- `lavaan::lavInspect(object, "data")` may return matrix
- Convert to data.frame or return NULL

### Bootstrap Not Reproducible

- Set seed before calling
- For parallel: set seed before parallel call
- Verify same `n_boot`

### R File Loading Order

- S7 generics MUST load before methods
- Use prefixes: `aaa-imports.R`, `aab-generics.R`
- Methods in `extract-*.R` need `aab-generics.R` first

---

## Agent Harness

**Goal:** run plan-task work (a task from `planning/PLAN-*.md`, or a native-engine fix) through one repeatable
pipeline: implement test-first in a feature worktree, verify against an independent oracle with planted defects, pass
the risk tier and lint, sync the docs, open the PR to `dev`.

**Entry point (advisory):** for plan-task work, a native-engine fix, or a re-run of one, invoke the
`medfit-orchestrator` skill first. Questions, explanations, status checks, one-line edits and release work do not go
through it.

Agents are in `.claude/agents/` (`medfit-implementer`, `medfit-oracle-qa`, `medfit-gates`, `medfit-docs`); skills in
`.claude/skills/` (`medfit-orchestrator`, `medfit-oracle-check`, `medfit-risk-tier`). Task state lives in the plan
file; GitHub Issues are only linked from PRs. Agents' reports go to `_agents_workspace/` (git- and Rbuild-ignored).

| Date | Change | Target | Reason |
|---|---|---|---|
| 2026-10-24 | Initial harness: 4 agents, 3 skills, tools registry | `.claude/agents/`, `.claude/skills/` | Make the 0.14.0 plan-task pipeline (implement, oracle QA, gates, docs) repeatable |

---

## Additional Resources

### Planning Documents

**Package:** `planning/medfit-roadmap.md`
**Active plan:** none. Completed: `planning/PLAN-FIML-native-guide-fixture-2026-10-30.md` (PR #371 squash-merged into dev as `04b7ac8c`; exact reviewed head `a1f03ddf` passed lint/pkgdown/risk-tier, merged tree identical; docs/local gates/user visual PASS; local and remote feature branch/worktree absent, 423 evidence files archived and hash-verified; metadata reconciliation local only; main-only coverage unchanged). Completed: `planning/PLAN-FIML-minibook-unit-2026-10-30.md` (Chapter 8 merged into dev via PR #368, `e2f028f9`; six exact-head fast checks PASS; local numerical/docs/render/USER-visual gates PASS; feature branch/worktree removed, 805 evidence files archived and verified; duplicate post-merge coverage run 41155534928 cancelled at user request; reviewed PR coverage and Codecov PASS; no release/main merge/expensive CI). `planning/PLAN-FIML-regression-oracles-2026-10-30.md` (regression oracles and minibook support clarification merged via PR #367, `fb879fac`; post-merge coverage run 41147354533 and Codecov PASS; merged branch/worktree removed with 200 evidence files archived and verified). `planning/PLAN-FIML-bounded-integration-2026-10-29.md` (bounded FIML merged into dev via PR #364, `a894e45e`; post-merge fast coverage and Codecov PASS; included in planned 0.16 (unreleased; see `planning/SCOPE-0.16-FIML-2026-10-30.md`); 23,086 local evidence entries archived and verified; merged branch/worktree removed). `planning/PLAN-360-boundary-regression-2026-10-29.md` (issue #360 boundary regression; local implementation, independent QA and gates PASS; PR #363 to dev, namespace lint repair awaiting hosted CI). `planning/PLAN-357-first-milestone-2026-10-29.md` (issue #357 reduced milestone; merged into dev via PR #361, `446cf12d`; post-merge coverage PASS, cleanup verified); `planning/PLAN-d4-covariance-correction-2026-10-28.md` (merged into dev via PR #358, `b9af937a`). Previous: `planning/PLAN-0.15.0-native-defaults-flip-2026-10-26.md` (released); `planning/PLAN-missingmed-evidence-D1-D4-2026-10-24.md` (P0-P4 merged; Checkpoint 2 recorded in `.STATUS`). Keep plans under `planning/`; `tasks/plan.md` and `tasks/todo.md` are the closed `fixed_x` plan.
**Ecosystem:** `~/projects/r-packages/mediation-planning/docs/ECOSYSTEM-COORDINATION.md`

### Related Packages

| Package | Repository | Purpose |
|---------|-----------|---------|
| probmed | github.com/data-wise/probmed | Probabilistic effect size (P_med) |
| RMediation | github.com/data-wise/rmediation | CIs (DOP, MBCO) |
| medrobust | github.com/data-wise/medrobust | Sensitivity analysis |
| medsim | github.com/data-wise/medsim | Simulation infrastructure |

---

**Last Updated**: 2026-10-26
**Maintained by**: medfit development team

**Current status** (2026-10-26: **0.15.0 released** (tag `v0.15.0` at `e068d75`, GitHub-only; the native defaults flip: unset `fixed_x` fixes the exogenous observed variables, unset `meanstructure` is TRUE, explicit arguments kept; `options(medfit.native_defaults)` ignored, removed in the development version; #347-#350, [BREAKING] #329 closed); 2026-10-26: **0.14.1 released** (tag `v0.14.1` at `e9803f1`, GitHub-only; the D1-D4 evidence contract, #336-#342, plus the covr fix and QC docs, #344, #345); 2026-10-24: **0.14.0 released** (tag `v0.14.0` at `b7d7566`, GitHub-only) (plan `planning/PLAN-0.14.0-native-defaults-2026-10-24.md`; PRs #315-#328: pinned-SE fix, `compare_lr()` with `fixed_x` and means in lavaan and OpenMx, the once-per-session `medfit_warning_default_change` and `options(medfit.native_defaults = "0.15")`, the native-defaults oracle gate, the agent harness; the 0.15.0 flip is announced in [BREAKING] #329); **0.13.0 released**, tag `v0.13.0` at `bb0edf0`, GitHub-only, see `.STATUS`; release PR #307 was admin-merged after both gates shards timed out on ubuntu-26.04, and the same tree passed the gates on ubuntu-24.04; 0.13.0 adds the capped status -4 restoration and unresolved MBCO results (#300) and makes a dropped zero-product branch an error from `fit_sem()` (#303); 0.12.0 adds `compare_lr()` (#249: the product-null LR in lavaan or OpenMx against `mbco_sem()`, evidence-only classed warnings, the `compare-lr` gate in `tests/sim`) and the #238 acceptance-gate fix; 0.11.1 was released 2026-10-20 (tag `v0.11.1`); the paragraph below describes 0.11.0, released 2026-10-17): CRAN has **0.3.2** (accepted 2026-07-23). `main` and GitHub are at **0.15.0** (0.11.0 was released 2026-10-17: release PR #244, tag `v0.11.0` at `35941ee`; r-universe follows the build, about 2 h) (GitHub-only releases, not submitted to CRAN, as 0.5.0 to 0.10.0). By the 2026-10-17 grill (G1) 0.11.0 goes to CRAN after a soak whose exit is a checklist (probmed and RMediation suites against the tag, the r-universe build, the CI gate green on `main`); RMediation submits its SEMFit-pair feature only after medfit 0.11.0 is accepted. 0.11.0 ships categorical covariates in native syntax (0/1 dummies, `g:m` products, `fixed_x = "g"`), population-average four-way SEs on request (`options(medfit.covariate_mean_variance = TRUE)`), the #213 fix (nonlinear-constrained fits no longer wander to negative variances; a floor on variances in nonlinear rows and a reference start), a default-start fallback and a single-start warning in the native optimizer, S7 1.0 compatibility (`S7_on_load`/`S7_on_build` guarded; the full suite and the registrations are identical on S7 `main` and 0.2.2), and the native engine without its "experimental" label (exported signatures, `SEMFit` properties and the `?medfit-syntax` grammar change only through a deprecation; `tests/testthat/test-api-freeze.R` pins them). CI: `.github/workflows/gates.yaml` runs the simulation gates in two Linux shards on PRs to `main` (`gates (rest)` and `gates (reliability)` are required checks on `main` since 2026-10-21; the #238 floor fixture is fixed and runs strict, and since #292/#290 the floor gate also compares every floor row with an independent floored oracle on the OpenBLAS runner), `s7-watch.yaml` checks CRAN's S7 version and the lifecycle gate against S7 `main` weekly, and `R-CMD-check` runs on `main` only (dev is gated locally with `scripts/check-local.sh`). 0.10.0 ships the `:` product term in native syntax and the four-way decomposition from a native fit through `extract_mediation()`, inside a documented supported class (rules 8 and 9; a product turns the mean structure on; chi-square is `NA` and `anova()`/`mbco_sem()` refuse when a product factor is a regression target; #181, #187-#193), with the native oracles and colon-path gates (`tests/sim/`) and the native mini-book (#183). 0.9.0 shipped observed intercepts and means in the native engine (centered coordinates, intercept constraints, `anova()` across mean status; #174) and `fixed_x` (#175, lavaan's `fixed.x = TRUE`: same structural results, conditional logLik; plan `tasks/plan.md`), with cookbook recipe 18 and step 9 of the native tutorial (#176-#180). 0.8.0 shipped nonlinear constraints in the native engine (`cp == a*b`, `a*b > k`, the exact zero-product branch split, best-effort sums of products, a Newton polish), `mbco_sem(paths = )` for a product of k paths, `anova()`/`tidy()`/`glance()`/`confint()` for `SEMFit`, one lavaan-style naming convention, the lavaan comparison article and cookbook recipes 12 and 13 (#140-#163). 0.7.0 (released 2026-10-10, tag `v0.7.0`) shipped the native maximum-likelihood SEM engine (`fit_sem()`/`SEMFit`, `fit_mediation(engine = "native")`, sampling weights and the sandwich covariance, `mbco_sem()`, and the OpenMx parity and constrained gates; #110-#124) with its docs (`?"medfit-syntax"`, cookbook recipe 11, the native section of the methods article). Plan and decisions for 0.8.0: `tasks/plan.md`, `tasks/todo.md`, `planning/specs/GRILL-medfit-0-8-0-2026-10-11.md`. 0.6.0 (2026-10-09) shipped Ext D module 1, 2-1-1 cluster mediation (`ClusterMediationData`, `engine = "lmer"`, `se_type = "kr"`, cluster bootstrap; #90-#92, #95, #100), the Reference Card and Cookbook articles (#94, #97), and 30 fewer published internal reference pages (#98). 0.5.0 (2026-09-25) changed two results: serial `te()`/`pm()` now sum every path (#81), and `confint(parm = "paths")` finds rows by name and errors instead of guessing (#82, which also fixed wrong lavaan path SEs). The site documents 0.15.0; the 0.10.0 docs overhaul (#134-#139) added a Models menu with 14 model pages, a home page and Getting Started rewrite, and a Guides menu); `main` deploys it, and `gh workflow run pkgdown.yaml --ref dev` publishes `dev` docs to the root while the Version has no `.9000`; `nobs()` now counts the rows the models used (#138). Articles evaluate their code at site build, and the pkgdown workflow runs on PRs to `dev`. Per-PR detail lives in `.STATUS`. 

### CRAN check practice (learned 2026-06-10, extended 2026-07-20)

- **Before any CRAN submit, run the strict flavors** — plain `--as-cran` and the win-builder
  pretest install Suggests and skip `\donttest`, so they miss failures CRAN's *ongoing* farm
  later flags:

  ```r
  devtools::check(cran = TRUE, args = "--run-donttest",
                  env_vars = c("_R_CHECK_DEPENDS_ONLY_" = "true",
                               "_R_CHECK_SUGGESTS_ONLY_" = "true",
                               "_R_CHECK_CRAN_INCOMING_" = "true",
                               "_R_CHECK_CRAN_INCOMING_REMOTE_" = "true"))
  ```

  This caught the default parametric bootstrap hard-requiring **MASS** → MASS is now in
  **`Imports`** (not Suggests). A `noSuggests` CI job guards this on every push. The two
  `_R_CHECK_CRAN_INCOMING_*` vars simulate CRAN's new/updated-submission feasibility checks
  (Date freshness, hidden-file scan, remote URL/DOI validation) — run them every time, not
  just for first submissions.
- Any Suggests pkg used unconditionally must move to Imports, or be guarded with
  `requireNamespace()` in code **and** `skip_if_not_installed()` in tests. `\donttest` examples
  run under `--as-cran`; only genuinely-unrunnable code may keep `\dontrun{}`.
- **`.Rbuildignore` is independent of `.gitignore`** — a directory git-ignores (e.g. the
  `.remember/` session-memory scratch dir used across the mediationverse repos) still gets
  swept into the tarball by `R CMD build` unless it's *also* in `.Rbuildignore`. `git status`
  clean proves nothing about what ships. Caught by the incoming-check's hidden-file NOTE
  during 0.3.1 prep; all 6 mediationverse repos now Rbuildignore `.remember`.
- **Run `urlchecker::url_check()` and `spelling::spell_check_package()` every cycle** — CRAN's
  own submission server runs `aspell` on Description/Rd/vignettes, so a clean local check must
  too. Domain jargon (method acronyms, S7 class names, DOI journal-code fragments) will always
  false-positive; maintain `inst/WORDLIST` as the allowlist rather than rewording legitimate
  terminology. Genuine hits are usually hyphenation artifacts (e.g. "mis-ordered" tokenizing
  to "mis") — reword those, don't just whitelist the fragment. **Caveat:** `R CMD check`'s own
  "Possibly misspelled words in DESCRIPTION" sub-check needs a local `aspell` binary — if this
  machine doesn't have one (`which aspell`), that specific check silently doesn't run and
  `devtools::check()` will under-report (0.3.1: local said 0 notes, win-builder — which does
  run `aspell` — found 1 on both devel and release: the cited author surname "VanderWeele").
  Treat win-builder as the source of truth for this particular NOTE, not the local machine.
- **`cran-comments.md` must be re-synced against the actual check output immediately before
  submission**, not written speculatively weeks ahead. The 0.3.1 draft described an
  incoming-feasibility NOTE that had already stopped occurring once the cadence window
  passed, and cited a `revdep/cran.md` file that was never created — both looked plausible
  but were wrong. Regenerate the check-results section and the revdep section from a fresh
  run right before `submit_cran()`.
- **Scale the reverse-dependency check to the actual risk.** Full `revdepcheck::revdep_check()`
  builds isolated libraries for both the CRAN and dev versions of every revdep and diffs
  complete `R CMD check` output — worth it for a large revdep count or a hard `Imports`
  dependent (e.g. probmed once it pins medfit ≥0.3.0). For a single `Suggests`-only revdep
  (medfit's only current one, RMediation), installing the dev build into a scratch
  `.libPaths()` and running the dependent's existing test suite answers the same question in
  under a minute.
- CRAN submission is maintainer-manual: `devtools::submit_cran()` needs an interactive session
  and CRAN emails a confirmation link to click — it cannot be fired headless.
