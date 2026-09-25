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
- **S7 classes**: `MediationData`, `InteractionMediationData`, `SerialMediationData`, `ParallelMediationData`, `JointMediationData`, `BootstrapResult`
- **Extraction**: Generic `extract_mediation()` with methods for lm/glm/lavaan
- **Fitting**: Formula-based `fit_mediation()` with the `glm` and `regmedint` engines, case `weights`, and `se_type = "sandwich"` (HC3)
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
├── classes.R               # S7 class definitions (all six classes)
├── data.R                  # mediation_demo documentation
├── fit-glm.R               # fit_mediation(), glm engine, weights/sandwich
├── fit-regmedint.R         # regmedint engine adapter
├── extract-lm.R            # lm/glm extraction (simple, four-way, serial, parallel)
├── extract-joint.R         # JointMediationData worker, stacked-OLS vcov
├── extract-lavaan.R        # lavaan extraction
├── generics-effects.R      # nie/nde/te/pm/paths/decompose
├── effect-se.R             # delta-method gradients, .effect_se(), .path_se()
├── methods-base.R          # print/summary/coef/vcov/confint/nobs
├── methods-tidy.R          # tidy()/glance()
├── med.R                   # med()/quick()
├── bootstrap.R             # Bootstrap infrastructure
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
- `engine` - "glm", "lmer", "brms"
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
- Website builds to `docs/`

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

### Organization

```
tests/testthat/
├── helper-test-data.R, helper-joint.R   # Test data generators, joint oracles
├── test-classes*.R, test-validators.R   # S7 validation
├── test-extract-*.R                     # lm/glm, lavaan, serial, parallel, interaction, joint
├── test-effect-se.R, test-confint-paths.R, test-methods-*.R   # SEs, confint, tidy
├── test-serial-total-effect.R           # te() over every path
├── test-fit-*.R                         # glm, regmedint, m_star
├── test-bootstrap*.R                    # Bootstrap methods
└── test-mediation-demo.R                # bundled data known answers
```

Verify numeric claims against an independent oracle (lavaan `:=`, `lm(Y ~ X + C)`
for the total effect, a hand calculation, or a nonparametric bootstrap) and plant a
defect the test must catch; the SE tests use this pattern throughout.

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

**Why separate classes?** Clean separation, no over-engineering, extend without
breaking existing code, type safety via S7 validators.

### Engines

| Engine | Package | Method | Status |
|--------|---------|--------|--------|
| `"glm"` | (internal) | fit, then `extract_mediation()` | ✓ |
| `"regmedint"` | regmedint (Suggests) | VanderWeele closed-form | ✓ (no weights/sandwich) |
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

## Additional Resources

### Planning Documents

**Package:** `planning/medfit-roadmap.md`
**Ecosystem:** `~/projects/r-packages/mediation-planning/docs/ECOSYSTEM-COORDINATION.md`

### Related Packages

| Package | Repository | Purpose |
|---------|-----------|---------|
| probmed | github.com/data-wise/probmed | Probabilistic effect size (P_med) |
| RMediation | github.com/data-wise/rmediation | CIs (DOP, MBCO) |
| medrobust | github.com/data-wise/medrobust | Sensitivity analysis |
| medsim | github.com/data-wise/medsim | Simulation infrastructure |

---

**Last Updated**: 2026-09-25
**Maintained by**: medfit development team

**Current status** (2026-09-25): CRAN has **0.3.2** (accepted 2026-07-23). `main`, GitHub and r-universe are at **0.5.0** (released 2026-09-25, tag `v0.5.0`; GitHub-only by decision, not submitted to CRAN), a minor bump because two changes alter results: serial `te()`/`pm()` now sum every path (#81), and `confint(parm = "paths")` finds rows by name and errors instead of guessing (#82, which also fixed wrong lavaan path SEs). Also in 0.5.0: `JointMediationData` (#76/#77), the Methods and Formulas article (#79), four-way factor covariates (#78), joint SEs with `data =` (#80). Articles now evaluate their code at site build, and the pkgdown workflow runs on PRs to `dev`. Per-PR detail lives in `.STATUS`.

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
