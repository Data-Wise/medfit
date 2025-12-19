# CLAUDE.md for medfit Package

This file provides guidance to Claude Code when working with code in
this repository.

------------------------------------------------------------------------

## Quick Reference

**Package Type**: R package (S7-based mediation infrastructure) **Main
Branch**: `main` \| **Dev Branch**: `dev` **Minimum R**: 4.1.0 (native
pipe `|>`)

### Essential Commands

``` r
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
- `check` - Run R CMD check –as-cran, build/preview website, check
  GitHub Actions
- `sync` - Commit and push changes to remote

------------------------------------------------------------------------

## About This Package

**medfit** is the foundation package for the mediationverse ecosystem,
providing: - **S7 classes**: `MediationData`, `SerialMediationData`,
`BootstrapResult` - **Extraction**: Generic
[`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md)
with methods for lm/glm/lavaan - **Fitting**: Formula-based
[`fit_mediation()`](https://data-wise.github.io/medfit/dev/reference/fit_mediation.md)
with multiple engines - **Bootstrap**: Three methods (parametric,
nonparametric, plugin)

**Core Principle**: medfit provides infrastructure, not effect sizes.
Dependent packages (probmed, RMediation, medrobust) add methodological
contributions.

### Package Ecosystem

| Package        | Uses medfit for                 | Adds                              |
|----------------|---------------------------------|-----------------------------------|
| **probmed**    | Fitting, extraction, bootstrap  | P_med computation, visualization  |
| **RMediation** | Extraction, bootstrap utilities | DOP, MBCO, MC methods             |
| **medrobust**  | Optional naive estimates        | Sensitivity bounds, falsification |

------------------------------------------------------------------------

## Coding Standards

### Style and Conventions

- **R version**: 4.1.0+ (native pipe `|>`)
- **OOP**: S7 modern object system
- **Style**: tidyverse with native pipe
- **Naming**: snake_case for functions/properties, CamelCase for classes

### File Organization

    R/
    ├── aaa-imports.R           # Package imports
    ├── aab-generics.R          # S7 generics (load before methods!)
    ├── medfit-package.R        # Package documentation
    ├── classes.R               # S7 class definitions
    ├── fit-glm.R              # GLM engine
    ├── extract-lm.R           # lm/glm extraction
    ├── extract-lavaan.R       # lavaan extraction
    ├── bootstrap.R            # Bootstrap infrastructure
    ├── utils.R                # Utilities
    └── zzz.R                  # .onLoad() for dispatch

### Naming Patterns

**Functions:** - Exports:
[`fit_mediation()`](https://data-wise.github.io/medfit/dev/reference/fit_mediation.md),
[`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md),
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/dev/reference/bootstrap_mediation.md) -
Internal: `.fit_mediation_glm()`, `.bootstrap_parametric()`

**Arguments:** - `formula_y`, `formula_m` - Model specifications -
`treatment`, `mediator`, `outcome` - Variable names - `engine` - “glm”,
“lmer”, “brms” - `method` - “parametric”, “nonparametric”, “plugin” -
`n_boot`, `ci_level` - Bootstrap parameters

**S7 Classes:** - CamelCase: `MediationData`, `BootstrapResult` -
Properties: snake_case (`@a_path`, `@boot_estimates`)

------------------------------------------------------------------------

## Defensive Programming Essentials

### 1. Input Validation with checkmate

**ALWAYS** validate arguments at function entry:

``` r
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

**Quick reference:** - `assert_string()` - Single character -
`assert_numeric()` - Numeric vector - `assert_count()` - Single positive
integer - `assert_flag()` - Single logical - `assert_choice()` - Value
from set - `assert_data_frame()` - Data frame - `assert_multi_class()` -
Any of multiple classes

### 2. Ellipsis Validation

``` r
my_function <- function(x, ...) {
  rlang::check_dots_used()  # Error on unused dots (catches typos)
}
```

### 3. S7 Class Validation

``` r
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

- **Never** use [`library()`](https://rdrr.io/r/base/library.html) or
  [`require()`](https://rdrr.io/r/base/library.html) in package
  functions
- **Always** use explicit namespacing:
  [`stats::glm()`](https://rdrr.io/r/stats/glm.html),
  [`MASS::mvrnorm()`](https://rdrr.io/pkg/MASS/man/mvrnorm.html)
- **Clean up** side effects with
  [`on.exit()`](https://rdrr.io/r/base/on.exit.html)
- **Test** error conditions for all validation

------------------------------------------------------------------------

## S7 Object System Quick Guide

### Core Classes

**MediationData** (Simple: X → M → Y) - Paths: `a_path`, `b_path`,
`c_prime` - Inference: `estimates`, `vcov` - Metadata: `treatment`,
`mediator`, `outcome`, `n`

**SerialMediationData** (Serial: X → M1 → M2 → Y) - Paths: `a_path`,
`d_path` (vector), `b_path`, `c_prime` - Flexible: scalar `d_path` for 2
mediators, vector for 3+ - Properties: `mediators` (names),
`mediator_predictors` (list)

**BootstrapResult** - Inference: `estimate`, `ci_lower`, `ci_upper` -
Distribution: `boot_estimates` - Metadata: `method`, `n_boot`

### S7 Documentation Patterns

**Class constructors:**

``` r
#' @param a_path Numeric scalar: effect of treatment on mediator
#' @return A MediationData S7 object
#' @export
MediationData <- S7::new_class(...)
```

**Methods:**

``` r
#' @param x A MediationData object
#' @noRd  # CRITICAL: Don't use @export for S7 methods!
S7::method(print, MediationData) <- function(x, ...) { ... }
```

**Generics:**

``` r
#' @param object Fitted model object
#' @param ... Additional arguments passed to methods
#' @export
extract_mediation <- S7::new_generic("extract_mediation", dispatch_args = "object")
```

### S7 Method Registration (REQUIRED)

In `R/zzz.R`:

``` r
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

``` r
#' @import methods
```

------------------------------------------------------------------------

## Documentation Quick Guide

### LaTeX Equations by Context

| Context       | File             | Inline                    | Display           |
|---------------|------------------|---------------------------|-------------------|
| Function docs | `.Rd` / roxygen2 | `\eqn{a \times b}{a * b}` | `\deqn{...}{...}` |
| Vignettes     | `.qmd`           | `$a \times b$`            | `$$...$$`         |

**Roxygen2 rules:** - Two-argument form: `\eqn{latex}{ascii}` (LaTeX +
fallback) - No whitespace between command and arguments - Avoid Unicode
(θ, Σ) in .Rd files - use `\eqn{\theta}`, `\eqn{\Sigma}`

### Quarto Vignettes

**Chunk format (PREFERRED):**

```` markdown
```{r}
#| label: my-chunk
#| eval: false
#| echo: true
x <- 1 + 1
```
````

**Not this:**

```` markdown
```{r my-chunk, eval=FALSE, echo=TRUE}
x <- 1 + 1
```
````

**Key differences:** - Hash-pipe (`#|`) for options - Hyphens in labels:
`my-chunk` not `my_chunk` - Lowercase booleans: `true`/`false` not
`TRUE`/`FALSE`

### pkgdown Configuration

**Initial setup:**

``` r
usethis::use_pkgdown_github_pages()  # Creates gh-pages, workflow, config
```

\*\*\_pkgdown.yml essentials:\*\* - List ALL exported topics in
`reference:` - Use `starts_with()` for method patterns - Enable MathJax:
`template: math-rendering: mathjax` - Website builds to `docs/`

**Vignette dependencies:** - Add to DESCRIPTION `Suggests` OR - Use
`Config/Needs/website` for website-only deps

**Computationally expensive vignettes:**

``` r
usethis::use_article("article-name")  # Not included in R CMD check
```

------------------------------------------------------------------------

## Testing Strategy

### Coverage

- **Target**: \>90% overall, 100% critical paths
- **Critical**: S7 classes, extraction, bootstrap

### Organization

    tests/testthat/
    ├── helper-test-data.R      # Test data generators
    ├── test-classes.R          # S7 validation
    ├── test-extract-lm.R       # lm/glm extraction
    ├── test-extract-lavaan.R   # lavaan extraction
    ├── test-fit-glm.R          # GLM fitting
    ├── test-bootstrap.R        # Bootstrap methods
    └── test-utils.R            # Utilities

### What to Test

1.  **S7 validation** - Type checking, validators, edge cases
2.  **Extraction** - Accuracy, consistency, model types
3.  **Fitting** - Valid output, formula parsing, convergence
4.  **Bootstrap** - Reproducibility, CI coverage (~95%), parallel vs
    sequential
5.  **Edge cases** - Small n, non-convergence, singular matrices,
    missing data

------------------------------------------------------------------------

## Code Architecture

### Function Hierarchy

**User-facing:** 1.
[`fit_mediation()`](https://data-wise.github.io/medfit/dev/reference/fit_mediation.md) -
Fit models with formula interface 2.
[`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md) -
Extract from fitted models 3.
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/dev/reference/bootstrap_mediation.md) -
Bootstrap inference

**Internal:** - `.fit_mediation_glm()` - GLM engine -
`.bootstrap_parametric()` - Parametric bootstrap -
`.bootstrap_nonparametric()` - Nonparametric bootstrap -
`.bootstrap_plugin()` - Plugin estimator

### Model Extraction Pattern

All
[`extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md)
methods: 1. Validate inputs (variable names exist) 2. Extract parameters
(a, b, c’) 3. Extract covariance matrix 4. Extract residual variances
(if Gaussian) 5. Get data (if available) 6. Create MediationData object
7. Return

### Bootstrap Methods

| Method        | Samples from         | Speed   | Use case                    |
|---------------|----------------------|---------|-----------------------------|
| Parametric    | N(θ̂, Σ̂)              | Fast    | Default, assumes normality  |
| Nonparametric | Resample data, refit | Slow    | Robust, no normality needed |
| Plugin        | Point estimate only  | Fastest | Quick checks, no CI         |

**Parallel processing:** - Uses
[`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html)
(Unix) - Auto-detects cores - Set seed for reproducibility

------------------------------------------------------------------------

## Ecosystem Coordination

### Central Planning

Location: `/Users/dt/mediation-planning/`

| Document                    | Purpose                                      |
|-----------------------------|----------------------------------------------|
| `ECOSYSTEM-COORDINATION.md` | Version matrix, change propagation, releases |
| `MONTHLY-CHECKLIST.md`      | Health checks                                |

### Change Propagation

When changes affect dependent packages: 1. **Document** - Update NEWS.md
with ecosystem notes 2. **Test** - `revdepcheck::revdep_check()` 3.
**Notify** - Create issue with 2-month notice for breaking changes 4.
**Coordinate** - Schedule updates before release

### Breaking Changes

1.  GitHub issue with `[BREAKING]` prefix
2.  2-month deprecation period minimum
3.  Use
    [`lifecycle::deprecate_warn()`](https://lifecycle.r-lib.org/reference/deprecate_soft.html)
4.  Document migration path
5.  Update ECOSYSTEM-COORDINATION.md

------------------------------------------------------------------------

## Common Pitfalls

1.  **Variable name mismatches** - Ensure treatment/mediator match model
2.  **Ignoring convergence warnings** - Check `converged` property
3.  **Using plugin for inference** - Always bootstrap for CIs
4.  **Skipping validation** - Use checkmate everywhere
5.  **Breaking compatibility** - Coordinate with ecosystem
6.  **Suppressing errors without understanding** - Research first, fix
    properly

------------------------------------------------------------------------

## Important Implementation Details

### Extensible Mediation Architecture

**Design principle**: Separate classes for separate structures

**Current:** - `MediationData` - Simple (product-of-two: a × b) -
`SerialMediationData` - Serial (product-of-k: a × d₁ × … × dₖ × b)

**Future extension (parallel mediation):**

``` r
ParallelMediationData <- S7::new_class(
  properties = list(
    a_paths = numeric,      # c(a1, a2, ...)
    b_paths = numeric,      # c(b1, b2, ...)
    # Indirect = sum(a_paths * b_paths)
  )
)
```

**Why separate classes?** - Clean separation of concerns - No
over-engineering - Easy to extend without breaking existing code - Type
safety via S7 validators

### Treatment-Mediator Interaction (Planned)

**VanderWeele Four-Way Decomposition** [VanderWeele
2014](https://pubmed.ncbi.nlm.nih.gov/25000145/):

When X and M interact: - **CDE** (Controlled Direct Effect) - Neither
mediation nor interaction - **INTref** (Reference Interaction) -
Interaction only - **INTmed** (Mediated Interaction) - Both - **PIE**
(Pure Indirect Effect) - Mediation only

Total Effect = CDE + INTref + INTmed + PIE

**Planned class:**

``` r
InteractionMediationData <- S7::new_class(
  properties = list(
    interaction = S7::class_numeric,  # θ₃: X×M
    cde = S7::class_numeric,
    int_ref = S7::class_numeric,
    int_med = S7::class_numeric,
    pie = S7::class_numeric,
    # ... standard properties
  )
)
```

### Engine Adapter Architecture (Planned)

**Adapter pattern** for external packages: - Wrap validated
implementations (CMAverse, tmle3) - All return standardized
`MediationData` - External packages in `Suggests`

| Engine         | Package    | Method                  | Status  |
|----------------|------------|-------------------------|---------|
| `"regression"` | (internal) | VanderWeele closed-form | MVP ✓   |
| `"gformula"`   | CMAverse   | G-computation           | Planned |
| `"ipw"`        | CMAverse   | IPW                     | Planned |
| `"tmle"`       | tmle3      | Targeted learning       | Future  |

------------------------------------------------------------------------

## Troubleshooting

### S7 “Class has not been registered with S4”

**Fix:** 1. Call `S7::S4_register(ClassName)` in `.onLoad()` 2. Call
`S4_register()` BEFORE `methods_register()` 3. Import full methods:
`@import methods`

### S7 “Overwriting method” Messages

During `devtools::load_all()`: - **Known development-time issue**
(GitHub \#474) - Does NOT affect installed packages - Do NOT suppress
with [`suppressMessages()`](https://rdrr.io/r/base/message.html)

### lavaan Extraction Failures

**Parameter label conflicts:** - When model uses `M ~ a*X`, parameter
already named “a” - Check `names(lavaan::coef(fit))` before adding
aliases

**Data type issues:** - `lavaan::lavInspect(object, "data")` may return
matrix - Convert to data.frame or return NULL

### Bootstrap Not Reproducible

- Set seed before calling
- For parallel: set seed before parallel call
- Verify same `n_boot`

### R File Loading Order

- S7 generics MUST load before methods
- Use prefixes: `aaa-imports.R`, `aab-generics.R`
- Methods in `extract-*.R` need `aab-generics.R` first

------------------------------------------------------------------------

## Additional Resources

### Planning Documents

**Package:** `planning/medfit-roadmap.md` **Ecosystem:**
`/Users/dt/mediation-planning/ECOSYSTEM-COORDINATION.md`

### Related Packages

| Package    | Repository                      | Purpose                           |
|------------|---------------------------------|-----------------------------------|
| probmed    | github.com/data-wise/probmed    | Probabilistic effect size (P_med) |
| RMediation | github.com/data-wise/rmediation | CIs (DOP, MBCO)                   |
| medrobust  | github.com/data-wise/medrobust  | Sensitivity analysis              |
| medsim     | github.com/data-wise/medsim     | Simulation infrastructure         |

------------------------------------------------------------------------

**Last Updated**: 2025-12-19 **Maintained by**: medfit development team
