# CLAUDE.md for medfit Package

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

------------------------------------------------------------------------

## About This Package

**medfit** is a foundation package providing unified infrastructure for
fitting mediation models, extracting path coefficients, and performing
bootstrap inference. It eliminates redundancy across the mediation
analysis ecosystem (probmed, RMediation, medrobust) by providing shared
S7-based classes and methods.

### Core Mission

Provide clean, efficient, type-safe infrastructure for mediation model
handling that can be shared across multiple effect size computation
packages, reducing code duplication and ensuring consistency.

### Package Ecosystem Context

**medfit is the foundation for**:

1.  **probmed** - P_med (probabilistic effect size)
    - Uses medfit for: model fitting, extraction, bootstrap
    - Adds: P_med computation, visualization
2.  **RMediation** - Confidence intervals (DOP, MBCO)
    - Uses medfit for: model extraction, bootstrap utilities
    - Adds: Distribution of Product, MBCO tests, MC methods
3.  **medrobust** - Sensitivity analysis
    - Uses medfit for: optional naive estimates, bootstrap
    - Adds: Bounds computation, falsification tests

**Key Principle**: medfit provides infrastructure, not effect sizes.
Each dependent package focuses on its unique methodological
contribution.

### Key References

- Tofighi, D. (2025). medfit: Infrastructure for mediation analysis
  in R. (In preparation)
- Related: probmed, RMediation, medrobust package documentation

------------------------------------------------------------------------

## Common Development Commands

**Preferred Tools**: Use `devtools` and `usethis` packages for all R
package development tasks. These provide convenient wrappers and best
practices for package development workflows.

### Package Building and Checking

``` r
# Install package dependencies
remotes::install_deps(dependencies = TRUE)

# Check package (standard R CMD check)
rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "error")

# Build package
devtools::build()

# Install and reload during development
devtools::load_all()
```

### Documentation

``` r
# Generate documentation from roxygen2 comments
devtools::document()

# Build vignettes
devtools::build_vignettes()

# Build pkgdown site
pkgdown::build_site()
```

**pkgdown Website Building:**

The package uses pkgdown to generate a website from package
documentation. Configuration is in `_pkgdown.yml`.

**Workflow:** 1. **Update `_pkgdown.yml`** when adding new exported
functions or classes - Add new classes to the “S7 Classes” section in
`reference:` - Add new functions to appropriate sections - Example:
After adding `SerialMediationData`, must add to reference index

2.  **Build and check site:**

    ``` r
    pkgdown::build_site()
    ```

3.  **Common issues:**

    - **“Topic missing from index”**: Add the topic to `_pkgdown.yml`
      reference section
    - **“URL not ok”**: Ensure DESCRIPTION has correct URL field
    - **Non-ASCII characters**: Replace with ASCII equivalents (-\>
      instead of →, \* instead of ×)

**pkgdown Configuration Essentials:** - Reference index must list ALL
exported topics - Group related functions/classes together for better
organization - Use `starts_with()` patterns for methods (print*,
summary*, etc.) - Website builds to `docs/` directory

**MathJax and LaTeX Equations:**

Equation syntax differs by context. Use the correct format for each file
type:

| Context                | File Format         | Inline Syntax        | Display Syntax        |
|------------------------|---------------------|----------------------|-----------------------|
| **Function Docs**      | `.Rd` / roxygen2    | `\eqn{latex}{ascii}` | `\deqn{latex}{ascii}` |
| **Vignettes/Articles** | `.qmd` (Quarto)     | `$equation$`         | `$$equation$$`        |
| **Vignettes/Articles** | `.Rmd` (R Markdown) | `$equation$`         | `$$equation$$`        |

### 1. Function Documentation (roxygen2 / .Rd files)

Use Rd macros for help pages (`?function`):

``` r
#' The indirect effect is \eqn{a \times b}{a * b}
#'
#' Sampling distribution:
#' \deqn{N(\hat{\theta}, \hat{\Sigma})}{N(theta-hat, Sigma-hat)}
```

**Rules:** - `\eqn{latex}{ascii}` - inline (two arguments: LaTeX + ASCII
fallback) - `\deqn{latex}{ascii}` - display/block math - Single argument
form: `\eqn{latex}` uses same text for both - **No whitespace** between
command and arguments! - R 4.2+ supports MathJax/KaTeX rendering in HTML
help pages

### 2. Quarto Vignettes/Articles (.qmd files)

Use standard LaTeX with dollar signs:

``` markdown
The indirect effect is $a \times b$ where $a$ is the X->M path.

The sampling distribution is:
$$\hat{\theta} \sim N(\theta, \Sigma)$$
```

### 3. pkgdown Configuration

Enable MathJax in `_pkgdown.yml`:

``` yaml
template:
  bootstrap: 5
  math-rendering: mathjax
```

### 4. Common LaTeX Symbols

| Category                | Code                                  | Rendered                                      |
|-------------------------|---------------------------------------|-----------------------------------------------|
| Greek letters           | `\alpha`, `\beta`, `\theta`, `\Sigma` | \\\alpha\\, \\\beta\\, \\\theta\\, \\\Sigma\\ |
| Hats/accents            | `\hat{x}`, `\bar{x}`, `\tilde{x}`     | \\\hat{x}\\, \\\bar{x}\\, \\\tilde{x}\\       |
| Subscripts/superscripts | `x_i`, `x^2`                          | \\x_i\\, \\x^2\\                              |
| Fractions               | `\frac{a}{b}`                         | \\\frac{a}{b}\\                               |
| Operators               | `\times`, `\cdot`, `\sum`, `\prod`    | \\\times\\, \\\cdot\\, \\\sum\\, \\\prod\\    |

### 5. Avoid Unicode Math Characters

In `.Rd` files and roxygen2 comments: - **DON’T use**: `θ`, `Σ`, `θ̂`
(causes LaTeX PDF errors) - **DO use**: `\eqn{\theta}`, `\eqn{\Sigma}`,
`\eqn{\hat{\theta}}`

In `.qmd` files, Unicode is acceptable but LaTeX is preferred for
consistency.

**Quarto Vignettes and pkgdown Workflow:**

To ensure Quarto vignettes pass workflow checks and render correctly on
GitHub:

**Initial Setup:**

``` r
# Initialize pkgdown with GitHub Pages support
usethis::use_pkgdown_github_pages()
```

This automatically:

- Creates `gh-pages` branch for hosting
- Generates `.github/workflows/pkgdown.yaml`
- Updates DESCRIPTION and `_pkgdown.yml` with site URL

**Declare Dependencies:**

- List all vignette dependencies in DESCRIPTION under `Suggests`

- For website-only dependencies, use `Config/Needs/website` field:

      Config/Needs/website: ggplot2, dplyr, tidyr

- This ensures CI installs them without cluttering package dependencies

**Quarto Support:**

- pkgdown automatically detects and renders Quarto vignettes
- Vignettes appear in the `articles/` section of the website
- No special configuration needed for basic Quarto files

**Quarto Code Chunk Format (PREFERRED):**

Use Quarto’s hash-pipe (`#|`) syntax for chunk options, NOT R Markdown
inline syntax:

**CORRECT (Quarto format):**

```` markdown
```{r}
#| label: my-chunk
#| eval: false
#| echo: true
x <- 1 + 1
```
````

**INCORRECT (R Markdown format):**

```` markdown
```{r my-chunk, eval=FALSE, echo=TRUE}
x <- 1 + 1
```
````

**Key differences:**

- Chunk label: `#| label: chunk-name` (not `{r chunk-name}`)
- Options on separate lines with `#|` prefix
- Boolean values: `true`/`false` (not `TRUE`/`FALSE`)
- Use hyphens in labels: `my-chunk` (not `my_chunk`)

**Common chunk options:**

``` yaml
#| label: chunk-name
#| eval: false
#| echo: true
#| warning: false
#| message: false
#| fig-width: 8
#| fig-height: 6
```

**Computationally Expensive Vignettes:**

- If vignette code is slow or requires credentials, use **Articles**
  instead:

  ``` r
  usethis::use_article("article-name")
  ```

- Articles are rendered by pkgdown but NOT included in `R CMD check`

- Prevents timeouts and failures on CI servers

- Use for: heavy simulations, API examples requiring keys, large data
  processing

**Common Workflow Failures:**

- **Missing system libraries**: Ensure system dependencies are available
  on CI runner
- **Malformed markdown**: Use consistent header levels (`#`, `##`) in
  NEWS.md
- **Branch permissions**: Workflow needs write access to `gh-pages`
  branch
- **Missing dependencies**: Check that all packages used in vignettes
  are in DESCRIPTION

**Workflow Checklist:**

Run `usethis::use_pkgdown_github_pages()` for initial setup

Add vignette dependencies to DESCRIPTION `Suggests` or
`Config/Needs/website`

Convert heavy vignettes to Articles with `usethis::use_article()`

Test locally with
[`pkgdown::build_site()`](https://pkgdown.r-lib.org/reference/build_site.html)
before pushing

Verify GitHub Actions has permission to deploy to `gh-pages`

### Testing

``` r
# Run all tests
devtools::test()

# Run specific test file
testthat::test_file("tests/testthat/test-classes.R")

# Check coverage
covr::package_coverage()
```

------------------------------------------------------------------------

## Coding Standards

### R Version and Style

- **Minimum R version**: 4.1.0 (native pipe `|>` support)
- **OOP Framework**: S7 (modern object system)
- **Style**: tidyverse style guide with native pipe
- **Roxygen2**: Use roxygen2 for documentation (\>= 7.3.0)
- **Clarity priority**: Code must be readable and maintainable

### Naming Conventions

The package uses **snake_case** consistently:

**Functions:** - Main exports:
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md),
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md),
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md) -
Internal functions prefix with dot: `.fit_mediation_glm()`,
`.bootstrap_parametric()`

**Arguments:** - `formula_y`, `formula_m` for model specifications -
`treatment`, `mediator`, `outcome` for variable names - `engine` for
modeling engine: “glm”, “lmer”, “brms” - `method` for inference method:
“parametric”, “nonparametric”, “plugin” - `n_boot` for number of
bootstrap samples - `ci_level` for confidence level (default: 0.95)

**S7 Classes:** - CamelCase: `MediationData`, `BootstrapResult` -
Properties use snake_case: `@a_path`, `@boot_estimates`

### Code Documentation Style

**General Principles:** - **Comment the “why”, not the “what”** -
explain reasoning, not obvious operations - **More explanatory comments
for tricky code** - shortcuts, clever tricks, non-obvious logic deserve
explanation - **Inline citations for statistical methods** - e.g.,
`# Per VanderWeele (2014), four-way decomposition...` -
**Self-documenting code first** - use clear variable names, then add
comments for context

**In-line Comment Examples:**

``` r
# BAD - explains what (obvious)
x <- x + 1  # add 1 to x

# GOOD - explains why
x <- x + 1  # Adjust for 1-based indexing expected by lavaan

# GOOD - explains tricky shortcut
# Use outer product for efficient pairwise computation (O(n²) memory but O(1) loops)
pairwise_diff <- outer(x, x, `-`)

# GOOD - inline citation
# Per VanderWeele (2014), the four-way decomposition requires: TE = CDE + INTref + INTmed + PIE
```

**Section Headers in Functions:** Use `# --- Section Name ---` for
functions longer than ~30 lines:

``` r
my_function <- function(...) {
  # --- Validate Inputs ---
  ...

  # --- Extract Parameters ---
  ...

  # --- Compute Results ---
  ...

  # --- Return ---
  ...
}
```

**roxygen2 Documentation:** Prefer BOTH concise `@description` AND
detailed `@details`:

``` r
#' Extract Mediation Structure from Fitted Models
#'
#' @description
#' Generic function to extract mediation paths (a, b, c') and
#' variance-covariance matrices from fitted models.
#'
#' @param object Fitted model object (lm, glm, lavaan)
#' @param treatment Character: treatment variable name
#'
#' @return A [MediationData] object
#'
#' @details
#' ## Supported Model Types
#'
#' - **lm/glm**: Requires separate mediator and outcome models
#' - **lavaan**: Extracts from SEM; auto-detects paths if labeled
#'
#' ## Mathematical Background
#'
#' The indirect effect is \eqn{a \times b}{a * b} where:
#' - \eqn{a} = effect of X on M (from mediator model)
#' - \eqn{b} = effect of M on Y controlling for X (from outcome model)
#'
#' Per Baron & Kenny (1986), mediation requires significant a and b paths.
#'
#' @references
#' Baron RM, Kenny DA (1986). The moderator-mediator variable distinction.
#' *Journal of Personality and Social Psychology*, 51(6), 1173-1182.
#'
#' @examples
#' \dontrun{
#' fit_m <- lm(M ~ X + C, data = mydata)
#' fit_y <- lm(Y ~ X + M + C, data = mydata)
#' med_data <- extract_mediation(fit_m, model_y = fit_y,
#'                               treatment = "X", mediator = "M")
#' }
#'
#' @seealso [MediationData], [fit_mediation()]
#' @export
```

**TODO/FIXME Conventions:**

``` r
# TODO: Add support for multiple mediators (issue #42)
# FIXME: Breaks when n < 10, needs better error handling
# HACK: Workaround for lavaan bug, remove when fixed upstream
# NOTE: Assumes Gaussian residuals for variance computation
```

### Code Organization

    R/
    ├── aaa-imports.R           # Package imports and setup
    ├── aab-generics.R          # S7 generic functions (must load before methods)
    ├── medfit-package.R        # Package documentation
    ├── classes.R               # S7 class definitions
    ├── fit-glm.R              # GLM engine implementation
    ├── extract-lm.R           # lm/glm extraction
    ├── extract-lavaan.R       # lavaan extraction
    ├── bootstrap.R            # Bootstrap infrastructure
    ├── utils.R                # Utility functions
    └── zzz.R                  # .onLoad() for dynamic dispatch

------------------------------------------------------------------------

## Defensive Programming

Defensive programming employs a multi-layered approach: strict input
validation, formal object definitions, automated testing, and continuous
integration.

### 1. Input Validation with checkmate

**ALWAYS use checkmate** for function argument validation. It provides
fast (C-based), memory-efficient assertions with informative error
messages.

**Required import** in `R/aaa-imports.R`:

``` r
#' @import checkmate
```

**Common assertion patterns:**

``` r
my_function <- function(x, n, method, data, optional_arg = NULL) {
  # --- Input Validation (using checkmate for fail-fast defensive programming) ---

  # Type assertions
  checkmate::assert_numeric(x, .var.name = "x")
  checkmate::assert_count(n, positive = TRUE, .var.name = "n")
  checkmate::assert_string(method, .var.name = "method")
  checkmate::assert_data_frame(data, .var.name = "data")

  # Optional arguments (allow NULL)
  checkmate::assert_string(optional_arg, null.ok = TRUE, .var.name = "optional_arg")

  # Choice from options
  checkmate::assert_choice(method, choices = c("parametric", "nonparametric", "plugin"),
                           .var.name = "method")

  # Class checks (multiple allowed classes)
  checkmate::assert_multi_class(model, classes = c("lm", "glm"), .var.name = "model")

  # Logical flags

  checkmate::assert_flag(verbose, .var.name = "verbose")

  # Variable exists in data
  checkmate::assert_choice(treatment, choices = names(data),
                           .var.name = "treatment in data")

  # ... rest of function
}
```

**Key checkmate functions:**

| Function               | Purpose                 | Example                                   |
|------------------------|-------------------------|-------------------------------------------|
| `assert_string()`      | Single character string | `assert_string(x)`                        |
| `assert_character()`   | Character vector        | `assert_character(x, min.len = 1)`        |
| `assert_numeric()`     | Numeric vector          | `assert_numeric(x, lower = 0)`            |
| `assert_count()`       | Single positive integer | `assert_count(n, positive = TRUE)`        |
| `assert_int()`         | Single integer          | `assert_int(n, lower = 1)`                |
| `assert_flag()`        | Single logical          | `assert_flag(verbose)`                    |
| `assert_choice()`      | Value from set          | `assert_choice(x, c("a", "b"))`           |
| `assert_subset()`      | Subset of set           | `assert_subset(x, c("a", "b", "c"))`      |
| `assert_data_frame()`  | Data frame              | `assert_data_frame(df, min.rows = 1)`     |
| `assert_matrix()`      | Matrix                  | `assert_matrix(m, nrows = 3)`             |
| `assert_list()`        | List                    | `assert_list(x, types = "numeric")`       |
| `assert_class()`       | Single class            | `assert_class(obj, "lm")`                 |
| `assert_multi_class()` | Any of classes          | `assert_multi_class(obj, c("lm", "glm"))` |
| `assert_function()`    | Function                | `assert_function(f, nargs = 2)`           |

**Options for all assertions:** - `.var.name = "name"`: Custom variable
name in error message - `null.ok = TRUE`: Allow NULL values -
`add = collection`: Add to assertion collection for batch checking

**Quick assertions with qassert:**

``` r
# Compact type checking
checkmate::qassert(x, "N1")   # Numeric, length 1
checkmate::qassert(x, "S1")   # String, length 1
checkmate::qassert(x, "B1")   # Boolean/logical, length 1
checkmate::qassert(x, "X")    # NULL
checkmate::qassert(x, "N+")   # Numeric, length >= 1
```

### 2. Handling Ellipsis (`...`)

When using `...` in function arguments, validate that passed arguments
are actually used:

``` r
my_function <- function(x, ...) {
  # Check that all ... arguments are used
  rlang::check_dots_used()

  # Or for stricter checking (error on unused dots)
  rlang::check_dots_empty()

  # ... rest of function
}
```

**Why this matters**: Without checking, misspelled arguments are
silently ignored:

``` r
# User typo: "treamtent" instead of "treatment"
extract_mediation(fit, treamtent = "X")  # Silently ignored without check!
```

### 3. S7 Class Validation (Already in Use)

S7 provides automatic type validation through property declarations and
custom validators:

``` r
MyClass <- S7::new_class(
  "MyClass",
  properties = list(
    # Automatic type checking
    x = S7::class_numeric,
    name = S7::class_character
  ),
  validator = function(self) {
    # Custom validation for cross-property constraints
    if (length(self@x) != 1) {
      return("x must be scalar")
    }
    if (any(self@x < 0)) {
      return("x must be non-negative")
    }
    NULL  # Return NULL if valid
  }
)
```

**S7 + checkmate complement each other:** - S7 validators: Class-level
constraints, cross-property validation - checkmate: Function argument
validation (fail-fast at entry point)

### 4. Testing Strategy

**Four-layer testing approach:**

1.  **Unit Testing** (testthat)

    ``` r
    test_that("function handles edge cases", {
      expect_error(my_func(NULL), "must not be NULL")
      expect_equal(my_func(0), expected_value)
    })
    ```

2.  **Acceptance Testing**: Validate user workflows end-to-end

3.  **Code Coverage** (covr)

    ``` r
    # Target: >80% coverage, 100% for critical paths
    covr::package_coverage()
    ```

4.  **Snapshot Testing**: For complex outputs

    ``` r
    test_that("print output is stable", {
      expect_snapshot(print(my_object))
    })
    ```

### 5. Dependency Management

**CRITICAL rules:**

1.  **Never use [`library()`](https://rdrr.io/r/base/library.html) or
    [`require()`](https://rdrr.io/r/base/library.html) inside package
    functions**

    - These alter the global search path
    - Use explicit namespacing: `package::function()`

2.  **Imports vs Suggests:**

    - **Imports**: Required packages (always available)
    - **Suggests**: Optional packages (check availability)

    ``` r
    # For Suggested packages, check availability
    if (!requireNamespace("lavaan", quietly = TRUE)) {
      stop("Package 'lavaan' is required but not installed.", call. = FALSE)
    }
    lavaan::sem(model, data = data)
    ```

3.  **Version pinning** in DESCRIPTION:

        Imports:
            S7 (>= 0.1.0),
            checkmate
        Suggests:
            lavaan (>= 0.6-0)

### 6. Managing State and Side Effects

**Clean up side effects with
[`on.exit()`](https://rdrr.io/r/base/on.exit.html):**

``` r
my_function <- function(...) {
  # Save current state
  old_opts <- options(warn = 2)
  old_wd <- getwd()

  # Ensure cleanup even if function errors
  on.exit({
    options(old_opts)
    setwd(old_wd)
  }, add = TRUE)

  # ... function body
}
```

**File system hygiene:** - Never write to user’s home directory - Use
[`tempdir()`](https://rdrr.io/r/base/tempfile.html) for temporary
files - Use `tools::R_user_dir("medfit", "cache")` for persistent cache

**Prefer pure functions:** - Return values instead of modifying in
place - Avoid global state modifications

### 7. Continuous Integration (CI)

**GitHub Actions workflow** (`.github/workflows/R-CMD-check.yaml`):

``` yaml
on:
  push:
    branches: [main, dev]
  pull_request:
    branches: [main]

name: R-CMD-check

jobs:
  R-CMD-check:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        r-version: ['release']

    steps:
      - uses: actions/checkout@v4

      - uses: r-lib/actions/setup-r@v2
        with:
          r-version: ${{ matrix.r-version }}

      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: any::rcmdcheck

      - uses: r-lib/actions/check-r-package@v2
```

**Static code analysis** with lintr:

``` r
# .lintr file in package root
linters: linters_with_defaults(
  line_length_linter(120),
  object_name_linter(styles = c("snake_case", "CamelCase"))
)
```

### 8. Defensive Programming Checklist

For every new function:

Add checkmate assertions for all arguments at function entry

Use `.var.name` parameter for clear error messages

Allow NULL where appropriate with `null.ok = TRUE`

Check `...` arguments with
[`rlang::check_dots_used()`](https://rlang.r-lib.org/reference/check_dots_used.html)
if applicable

Use explicit namespacing for all non-base functions

Clean up side effects with
[`on.exit()`](https://rdrr.io/r/base/on.exit.html)

Write tests for error conditions

Verify function works with edge cases (NULL, empty, NA)

------------------------------------------------------------------------

## Code Architecture

### S7 Object System

The package uses S7 for type-safe, modern object-oriented programming.

**Key S7 Classes:**

1.  **`MediationData`** - Simple mediation (X -\> M -\> Y)
    - Properties: `a_path`, `b_path`, `c_prime`, `estimates`, `vcov`,
      `data`, etc.
    - Validator ensures internal consistency
    - For product-of-two indirect effects (a \* b)
2.  **`SerialMediationData`** - Serial mediation (X -\> M1 -\> M2 -\> …
    -\> Y)
    - Properties: `a_path`, `d_path` (vector), `b_path`, `c_prime`,
      `mediators` (vector), etc.
    - Supports product-of-three (a \* d \* b) and product-of-k
    - Flexible `d_path`: scalar for 2 mediators, vector for 3+
    - Extensible to chains of any length
3.  **`BootstrapResult`** - Bootstrap inference results
    - Properties: `estimate`, `ci_lower`, `ci_upper`, `boot_estimates`,
      `method`
    - Validator checks consistency
    - Used by all packages for inference

**S7 Generics:**

1.  **[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)** -
    Extract mediation structure from models
    - Methods: `lm`, `glm`, `lavaan`, (future: `lmerMod`, `brmsfit`)
    - Returns: `MediationData` object
2.  **[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)** -
    Fit mediation models
    - Dispatcher to engine-specific functions
    - Returns: `MediationData` object
3.  **[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)** -
    Perform bootstrap inference
    - Methods: parametric, nonparametric, plugin
    - Returns: `BootstrapResult` object

**S7 Documentation Patterns:**

When documenting S7 classes and methods with roxygen2:

1.  **S7 Class Constructors**: Use explicit `@param` tags for all
    properties

    ``` r
    #' MediationData S7 Class
    #'
    #' @description
    #' S7 class containing standardized mediation model structure
    #'
    #' @param a_path Numeric scalar: effect of treatment on mediator
    #' @param b_path Numeric scalar: effect of mediator on outcome
    #' # ... document ALL properties explicitly
    #'
    #' @return A MediationData S7 object
    #' @export
    MediationData <- S7::new_class(...)
    ```

2.  **S7 Methods**: Use `@noRd` to prevent namespace export issues

    ``` r
    #' Print Method for MediationData
    #'
    #' @param x A MediationData object
    #' @param ... Additional arguments (ignored)
    #' @noRd
    S7::method(print, MediationData) <- function(x, ...) { ... }
    ```

    **Important**:

    - Do NOT use `@export` for S7 methods (causes namespace errors)
    - Do NOT use `@name` tag (causes duplicate .Rd files)
    - Use `@noRd` to document internally without generating .Rd files
    - S7 methods work via automatic dispatch, not namespace exports

3.  **S7 Generics**: Only document generic parameters, not
    method-specific ones

    ``` r
    #' Extract Mediation Structure
    #'
    #' @param object Fitted model object
    #' @param ... Additional arguments passed to methods. Common arguments include:
    #'   - `treatment`: Character string (document in prose, not as @param)
    #'   - `mediator`: Character string (document in prose, not as @param)
    #' @export
    extract_mediation <- S7::new_generic("extract_mediation", dispatch_args = "object")
    ```

4.  **Testing S7 Methods**: Method dispatch may not work in installed
    package context

    ``` r
    test_that("MediationData print method works", {
      skip_if_not(interactive(), "S7 method dispatch issue in non-interactive mode")
      # ... test code
    })
    ```

5.  **S7 Method Registration in .onLoad()**: REQUIRED per official S7
    documentation

    ``` r
    # CORRECT - per https://rconsortium.github.io/S7/articles/packages.html
    .onLoad <- function(libname, pkgname) {
      # 1. First register S7 classes with S4 system
      S7::S4_register(MediationData)
      S7::S4_register(SerialMediationData)
      S7::S4_register(BootstrapResult)

      # 2. Then register S7 methods for dispatch
      S7::methods_register()

      # 3. Register methods for Suggested packages (if available)
      if (requireNamespace("lavaan", quietly = TRUE)) {
        tryCatch(.register_lavaan_method(), error = function(e) invisible(NULL))
      }
    }
    ```

    **Key points**:

    - `S4_register()` MUST be called for each S7 class BEFORE
      `methods_register()`
    - `methods_register()` MUST be in `.onLoad()`, NOT `.onAttach()`
    - Import full `methods` package: `@import methods` (not just
      `@importFrom methods is`)
    - The “Overwriting method” message during `devtools::load_all()` is
      a known development-time issue (GitHub \#474) - does NOT affect
      installed packages
    - See: <https://rconsortium.github.io/S7/articles/packages.html>
    - See: <https://github.com/RConsortium/S7/issues/474>

**S7 and S3 Class Integration:**

When working with S3 classes in S7 packages, follow this guide:

1.  **Mandatory Package Setup**: Call
    [`S7::methods_register()`](https://rconsortium.github.io/S7/reference/methods_register.html)
    in `.onLoad()`

    - Required for dynamic method registration
    - Especially important for methods on generics from other packages
    - Must call `S4_register()` for each class BEFORE
      `methods_register()`

2.  **Formalizing S3 Classes**: Use `new_S3_class()` to wrap S3 classes

    ``` r
    # Register method for S3 class
    method(my_generic, new_S3_class("data.frame")) <- function(x) {...}

    # Use in property definitions
    MyClass <- new_class("MyClass",
      properties = list(
        data = new_S3_class("data.frame")
      )
    )

    # Use in unions
    my_union <- new_union(class_numeric, new_S3_class("Date"))
    ```

    **Built-in S3 wrappers**: S7 provides `class_data.frame`,
    `class_Date`, `class_factor`, etc.

3.  **Inheriting from S3 Classes**: Requires custom constructor

    ``` r
    # When inheriting from S3 via parent argument
    MyS7Class <- new_class("MyS7Class",
      parent = new_S3_class("integer",
        constructor = function(.data, ...) {
          # .data must be first argument
          # Add S3 class attributes
        }
      )
    )
    ```

4.  **Calling Parent S3 Methods**: Use `S7_data()`, not `super()`

    ``` r
    # INCORRECT - S3 generics don't understand super()
    method(print, MyClass) <- function(x) {
      super(x, print)  # FAILS
    }

    # CORRECT - Extract underlying S3 object
    method(print, MyClass) <- function(x) {
      print(S7_data(x))  # Dispatches to S3 print method
    }
    ```

5.  **Migrating S3 Packages to S7**: Incremental approach

    - Add
      [`S7::methods_register()`](https://rconsortium.github.io/S7/reference/methods_register.html)
      to `.onLoad()`
    - Wrap existing S3 classes with `new_S3_class()`
    - Gradually replace informal S3 with formal `new_class()`
      definitions
    - Existing S3 code continues to work because S7 objects retain S3
      class attribute

**S7 and S4 Class Integration:**

While S7 and S3 are fully compatible, S7 and S4 have specific
interoperability features and limitations:

1.  **Registration with `S4_register()`**: CRITICAL for S4 compatibility

    ``` r
    # Define S7 class
    Foo <- new_class("Foo", package = "mypackage")

    # REQUIRED: Register with S4 system
    S4_register(Foo)

    # Now can use with S4 generics
    method(S4_generic, Foo) <- function(x) "Hello"
    ```

    **Why required**:

    - S7 classes are created at runtime, not visible to S4 by default
    - Without registration, S4 dispatch won’t recognize the class
    - **In medfit**: We call
      [`S7::S4_register()`](https://rconsortium.github.io/S7/reference/S4_register.html)
      immediately after each class definition

2.  **Bidirectional Method Dispatch**: S7 supports multiple combinations

    ``` r
    # S7 method on S4 generic (requires S4_register)
    method(S4_generic, S7_class) <- function(x) {...}

    # S4 class on S7 generic
    method(S7_generic, S4_class) <- function(x) {...}

    # Mixed signatures work
    method(my_generic, list(S7_class, S4_class)) <- function(x, y) {...}
    ```

3.  **Inheritance Limitations - The “Firewall”**:

    **CRITICAL RESTRICTION**: S7 cannot extend S4 classes

    ``` r
    # INVALID - Will fail
    MyClass <- new_class("MyClass", parent = SomeS4Class)
    ```

    **Why this matters**:

    - S7 cannot inherit from S4 (opposite direction may work)
    - Major barrier for Bioconductor ecosystem (S4-based)
    - Cannot subclass core S4 structures like `SummarizedExperiment`
    - Must use composition instead of inheritance

    **Workaround**: Use composition

    ``` r
    # Instead of inheriting, wrap
    MyClass <- new_class("MyClass",
      properties = list(
        s4_object = S4_class  # Contain, don't extend
      )
    )
    ```

4.  **Properties and Slots**: Equivalent concepts

    - S7 properties ≈ S4 slots (with added dynamics)
    - Can use S4 class as property type
    - S4 class unions auto-convert to `new_union()`
    - Union handling differs: S4 at dispatch time, S7 at registration
      time

5.  **Migration Strategy - Bottom-Up Approach**:

    Because S7 cannot inherit from S4, migration requires careful
    planning:

    **Step-by-step process**:

    1.  Identify S4 classes at bottom of hierarchy (no children)
    2.  Re-implement using `new_class()`
    3.  Convert S4 slots → S7 properties
    4.  Convert S4 validity methods → S7 validator functions
    5.  Call `S4_register()` for backward compatibility
    6.  Move up hierarchy, replacing parents only after children
        converted

    **Example**:

    ``` r
    # Old S4 class
    setClass("Foo", slots = list(x = "numeric"))
    setValidity("Foo", function(object) {
      if (length(object@x) == 0) "x must have length > 0"
    })

    # New S7 equivalent
    Foo <- new_class("Foo",
      properties = list(
        x = class_numeric
      ),
      validator = function(self) {
        if (length(self@x) == 0) {
          "x must have length > 0"
        }
      }
    )
    S4_register(Foo)  # Maintain S4 compatibility
    ```

### Core Function Hierarchy

**User-Facing Functions:**

1.  **[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)** -
    Fit models with formula interface
    - Most convenient for users
    - Internally uses engine-specific functions
    - Currently supports GLM engine
2.  **[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)** -
    Extract from fitted models
    - Generic with methods for different model types
    - Standardizes across packages
    - Returns `MediationData`
3.  **[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)** -
    Bootstrap inference
    - Three methods: parametric, nonparametric, plugin
    - Parallel processing support
    - Returns `BootstrapResult`

**Internal Functions:**

- `.fit_mediation_glm()`: GLM engine implementation
- `.bootstrap_parametric()`: Parametric bootstrap
- `.bootstrap_nonparametric()`: Nonparametric bootstrap
- `.bootstrap_plugin()`: Plugin estimator
- Utility functions for validation, formatting, etc.

### Key Dependencies

**Required:** - **S7**: Modern object system - **stats**: GLM fitting,
statistical functions - **methods**: S4 compatibility

**Suggested:** - **MASS**: `mvrnorm()` for parametric bootstrap -
**lavaan**: SEM model extraction - **lme4**: Mixed models (future)

**Future Consideration:** - **OpenMx**: SEM model extraction (postponed
to future release)

### Explicit Namespacing

**CRITICAL**: All non-base functions MUST use explicit namespacing:

``` r
# CORRECT
stats::glm(formula, data = data)
MASS::mvrnorm(n, mu, Sigma)
lavaan::sem(model, data = data)

# INCORRECT
glm(formula, data = data)
mvrnorm(n, mu, Sigma)
sem(model, data = data)
```

------------------------------------------------------------------------

## Important Implementation Details

### S7 Class Design

**MediationData** (Simple Mediation): - Contains all information about
simple mediation model (X -\> M -\> Y) - Path coefficients (a, b, c’) -
Full parameter vector and covariance matrix - Residual variances (for
Gaussian models) - Variable names and metadata - Data and sample size

**SerialMediationData** (Serial Mediation): - Contains all information
about serial mediation (X -\> M1 -\> M2 -\> … -\> Y) - Path
coefficients: `a_path` (scalar), `d_path` (vector), `b_path` (scalar),
`c_prime` (scalar) - Flexible design: `d_path` is scalar for 2
mediators, vector for 3+ - Vector properties: `mediators` (names),
`sigma_mediators` (residual SDs) - List property: `mediator_predictors`
(predictors for each mediator model) - Full parameter vector and
covariance matrix (like MediationData)

**Design principle**: Complete information for downstream packages

### Extensible Architecture for Multiple Mediator Types

The package uses a **modular class design** that allows clean extension
to different mediation structures:

**Current Classes:** - `MediationData`: Simple mediation
(product-of-two: a \* b) - `SerialMediationData`: Serial mediation
(product-of-three and beyond: a \* d \* b, a \* d21 \* d32 \* b, etc.)

**Design Principles:** 1. **Separate classes for separate structures**:
Each mediation type gets its own class, optimized for its use case 2.
**Consistent interface**: All classes share common properties
(`estimates`, `vcov`, metadata) 3. **No hard limits**: Serial mediation
supports chains of any length (2, 3, k mediators) 4. **Extensible
validators**: Each class has comprehensive validation tailored to its
structure

**Future Extension Path:**

For parallel mediation (X -\> M1 -\> Y, X -\> M2 -\> Y simultaneously):

``` r
ParallelMediationData <- S7::new_class(
  properties = list(
    a_paths = numeric,      # Vector: c(a1, a2, ...)
    b_paths = numeric,      # Vector: c(b1, b2, ...)
    c_prime = numeric,      # Scalar: X -> Y direct effect
    mediators = character,  # Vector: c("M1", "M2", ...)
    # ... common properties (estimates, vcov, etc.)
  )
)
# Indirect effect = sum(a_paths * b_paths)
```

For complex mediation (combinations of serial and parallel): - Could use
graph representation or nested structure - Keep it simple: start with
separate classes, add complexity only when needed

### Treatment-Mediator Interaction (VanderWeele Four-Way Decomposition)

**Planned for post-MVP release** based on [VanderWeele
(2014)](https://pubmed.ncbi.nlm.nih.gov/25000145/).

**Theoretical Foundation**:

When treatment (X) and mediator (M) interact in their effect on outcome
(Y), the total effect decomposes into four components:

| Component  | Meaning                  | Due to                            |
|------------|--------------------------|-----------------------------------|
| **CDE**    | Controlled Direct Effect | Neither mediation nor interaction |
| **INTref** | Reference Interaction    | Interaction only                  |
| **INTmed** | Mediated Interaction     | Both mediation and interaction    |
| **PIE**    | Pure Indirect Effect     | Mediation only                    |

**Decomposition**: TE = CDE + INTref + INTmed + PIE

**Relationships**: - NDE (Natural Direct Effect) = CDE + INTref - NIE
(Natural Indirect Effect) = INTmed + PIE

**Regression Models**:

    Mediator:  M = β₀ + β₁X + β₂'C + εₘ
    Outcome:   Y = θ₀ + θ₁X + θ₂M + θ₃(X×M) + θ₄'C + εᵧ

\*\*Formulas (continuous Y/M, binary X: 0→1, m\*=0)\*\*: - CDE = θ₁
(effect of X when M=0) - INTref = θ₃(β₀ + β₂’c) (interaction at
reference) - INTmed = θ₃β₁ (mediated interaction) - PIE = θ₂β₁ (pure
indirect effect)

**When θ₃=0** (no interaction): reduces to standard mediation where
CDE=NDE=θ₁ and NIE=PIE=θ₂β₁.

**InteractionMediationData Class** (planned):

``` r
InteractionMediationData <- S7::new_class(
  "InteractionMediationData",
  package = "medfit",
  properties = list(
    # Core paths
    a_path = S7::class_numeric,           # β₁: X → M
    b_path = S7::class_numeric,           # θ₂: M → Y (main effect)
    c_prime = S7::class_numeric,          # θ₁: X → Y (main effect)
    interaction = S7::class_numeric,      # θ₃: X×M interaction

    # Four-way components
    cde = S7::class_numeric,              # Controlled Direct Effect
    int_ref = S7::class_numeric,          # Reference Interaction
    int_med = S7::class_numeric,          # Mediated Interaction
    pie = S7::class_numeric,              # Pure Indirect Effect

    # Derived effects
    nde = S7::class_numeric,              # Natural Direct Effect
    nie = S7::class_numeric,              # Natural Indirect Effect
    total_effect = S7::class_numeric,

    # Reference value
    m_star = S7::class_numeric,           # Reference mediator level

    # Standard properties (estimates, vcov, metadata, etc.)
    ...
  )
)
```

**Usage Pattern** (planned):

``` r
# Model with interaction
fit_m <- lm(M ~ X + C, data = data)
fit_y <- lm(Y ~ X + M + X:M + C, data = data)

# Extraction detects interaction, returns InteractionMediationData
med_int <- extract_mediation(
  fit_m, model_y = fit_y,
  treatment = "X", mediator = "M",
  m_star = 0  # Reference mediator level
)

# Access four-way components
med_int@cde; med_int@int_ref; med_int@int_med; med_int@pie
```

**Key References**: - VanderWeele TJ (2014). A unification of mediation
and interaction. *Epidemiology*, 25(5):749-61. - Valeri L, VanderWeele
TJ (2013). Mediation analysis allowing for exposure-mediator
interactions. *Psychological Methods*, 18(2):137-150.

### Decomposition S7 Class (Planned)

**Design Decision**: Decomposition as separate S7 class for flexibility
and custom decompositions.

``` r
Decomposition <- S7::new_class(
  "Decomposition",
  package = "medfit",
  properties = list(
    type = S7::class_character,        # "two_way", "four_way", "custom"
    components = S7::class_list,       # Named list: list(nde = 0.3, nie = 0.2)
    total = S7::class_numeric,         # Total effect
    formula = S7::class_character      # "NDE + NIE" or "CDE + INTref + INTmed + PIE"
  ),
  validator = function(self) {
    comp_sum <- sum(unlist(self@components))
    if (abs(comp_sum - self@total) > 1e-10) {
      "Components must sum to total effect"
    }
  }
)
```

**Built-in constructors**: - `two_way(nde, nie)` → NDE + NIE
decomposition - `four_way(cde, int_ref, int_med, pie)` → VanderWeele
4-way - `custom_decomposition(...)` → User-defined

**MediationData** stores decompositions in a list, allowing multiple:

``` r
result@decompositions$two_way   # Decomposition object
result@decompositions$four_way  # Decomposition object (when interaction present)
```

### User Interface Design

**Hybrid approach**: Simple strings for common cases, helper functions
for advanced.

``` r
# Simple (default)
estimate_mediation(..., effects = "natural")  # NDE + NIE

# Effect options
effects = "natural"        # NDE, NIE (default)
effects = "interventional" # IDE, IIE
effects = "controlled"     # CDE

# Advanced (helper functions)
effects = natural_effects(variant = "total")  # TDE, TNIE
effects = controlled_effects(m = 5)           # CDE at m=5
```

**Interaction handling**: When `X:M` detected → compute BOTH two-way and
four-way.

**Why this design?** - **Clean separation**: Each class handles one
mediation type well - **No over-engineering**: Don’t add complexity for
hypothetical future needs - **Easy to extend**: Adding new classes
doesn’t break existing ones - **Type safety**: S7 validators ensure each
class is used correctly

### Engine Adapter Architecture (Planned)

medfit uses an **adapter pattern** to integrate with external packages
for advanced estimation methods.

**Design principles**: - Wrap validated implementations (CMAverse,
tmle3) instead of reimplementing - All engines return standardized
`MediationData` objects - External packages in `Suggests` (load on
demand) - Engine-specific options via `engine_args = list(...)`

**Engine priority**:

| Engine         | Package    | Method                        | Status        |
|----------------|------------|-------------------------------|---------------|
| `"regression"` | (internal) | VanderWeele closed-form       | MVP (default) |
| `"gformula"`   | CMAverse   | G-computation                 | Planned       |
| `"ipw"`        | CMAverse   | Inverse probability weighting | Planned       |
| `"tmle"`       | tmle3      | Targeted learning             | Future        |
| `"dml"`        | DoubleML   | Double machine learning       | Future        |

**Usage example**:

``` r
# Default regression engine
estimate_mediation(
  formula_y = Y ~ X + M + C,
  formula_m = M ~ X + C,
  data = df,
  treatment = "X",
  mediator = "M",
  effects = "natural",     # NDE + NIE
  engine = "regression"    # Default
)

# CMAverse g-formula engine
estimate_mediation(
  ...,
  engine = "gformula",
  engine_args = list(
    EMint = TRUE,          # Exposure-mediator interaction
    nboot = 500            # CMAverse-specific bootstrap
  )
)
```

See `planning/medfit-roadmap.md` Phase 7c for detailed adapter
implementation.

### Model Extraction Pattern

All
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
methods follow this pattern:

1.  **Validate inputs** (check variable names exist)
2.  **Extract parameters** (a, b, c’ paths)
3.  **Extract covariance matrix** (for inference)
4.  **Extract residual variances** (if Gaussian)
5.  **Get data** (if available)
6.  **Create MediationData** object
7.  **Return**

### Bootstrap Implementation

**Three methods with different trade-offs**:

1.  **Parametric** (`method = "parametric"`):
    - Samples from N(θ̂, Σ̂)
    - Fast, requires normality
    - Default for most applications
2.  **Nonparametric** (`method = "nonparametric"`):
    - Resamples data, refits models
    - Robust, computationally intensive
    - Use when normality questionable
3.  **Plugin** (`method = "plugin"`):
    - Point estimate only, no CI
    - Fastest, for quick checks

**Parallel processing**: - Uses
[`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html)
(Unix) or similar - Auto-detects cores if not specified - Set seed for
reproducibility

### Dynamic S7/S4 Dispatch

For S4 classes from suggested packages (e.g., lavaan):

``` r
# In R/zzz.R
.onLoad <- function(libname, pkgname) {
  # Register lavaan method if available
  if (requireNamespace("lavaan", quietly = TRUE)) {
    lavaan_class <- S7::as_class(methods::getClass("lavaan", where = "lavaan"))
    S7::method(extract_mediation, lavaan_class) <- extract_mediation_lavaan
  }

  # Note: OpenMx integration postponed to future release
}
```

This allows methods to work without hard dependencies.

------------------------------------------------------------------------

## Testing Strategy

### Unit Tests Should Cover

1.  **S7 Class Validation**
    - Property type checking
    - Validators catch invalid inputs
    - Edge cases (empty, NA, wrong dimensions)
2.  **Model Extraction**
    - lm/glm extraction accuracy
    - lavaan extraction consistency
    - Identical results to manual extraction
    - Proper handling of different model types
3.  **Model Fitting**
    - GLM engine produces valid MediationData
    - Formula parsing correct
    - Family specifications work
    - Error handling for convergence failures
4.  **Bootstrap Methods**
    - Parametric bootstrap reproducible with seed
    - Nonparametric bootstrap reproducible with seed
    - Plugin method fast and accurate
    - CI coverage in simulations (~95% for 95% CI)
    - Parallel and sequential give same results (with seed)
5.  **Edge Cases**
    - Small sample sizes (n \< 50)
    - Non-convergent models
    - Singular covariance matrices
    - Missing data
    - Zero effects

### Test Organization

    tests/testthat/
    ├── helper-test-data.R      # Test data generators
    ├── test-classes.R          # S7 class validation
    ├── test-extract-lm.R       # lm/glm extraction
    ├── test-extract-lavaan.R   # lavaan extraction
    ├── test-fit-glm.R          # GLM fitting
    ├── test-bootstrap.R        # Bootstrap methods
    └── test-utils.R            # Utility functions

### Coverage Expectations

- **Target**: \>90% overall coverage
- **Critical paths**: 100% coverage
  - S7 class definitions
  - Core extraction functions
  - Bootstrap methods

------------------------------------------------------------------------

## Integration with Dependent Packages

### probmed Integration

**probmed will**: - Import medfit - Replace extraction code with
[`medfit::extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) -
Replace bootstrap code with
[`medfit::bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md) -
Keep its formula interface as wrapper around medfit - Add P_med-specific
computation

**Backward compatibility critical**: probmed users should see no changes

### RMediation Integration

**RMediation will**: - Import medfit - Replace extraction code with
[`medfit::extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md) -
Optionally use bootstrap utilities - Keep its unique methods (DOP, MBCO,
MC)

### medrobust Integration

**medrobust will**: - Suggest medfit (optional) - Optionally use for
naive estimates - Keep its unique methods (bounds, falsification)

### Coordination

**When making changes that affect**: - S7 class structure → Coordinate
with all packages - Extraction API → Coordinate with probmed and
RMediation - Bootstrap API → Coordinate with all packages

**Versioning**: - Use semantic versioning - Breaking changes → major
version bump - New features → minor version bump - Bug fixes → patch
version bump

------------------------------------------------------------------------

## Development Roadmap

See `planning/medfit-roadmap.md` for detailed implementation plan.

### Current Phase: MVP Development

Package skeleton

S7 classes implemented

Extraction methods (lm/glm, lavaan)

Fitting API (GLM engine)

Bootstrap infrastructure

Comprehensive tests

Documentation and vignettes

### Future Enhancements

lmer engine (mixed models)

brms engine (Bayesian)

Additional extraction methods

Performance optimizations

Extended documentation

------------------------------------------------------------------------

## Statistical Assumptions

### Key Assumptions for Inference

1.  **Correct model specification**
    - Mediator model correctly specified
    - Outcome model correctly specified
    - Appropriate family/link functions
2.  **Parameter normality** (for parametric bootstrap)
    - (θ̂) ~ N(θ, Σ)
    - Generally holds for large n (CLT)
    - Check with Q-Q plots
3.  **No unmeasured confounding** (for causal interpretation)
    - Standard causal mediation assumptions
    - Not testable, requires subject-matter knowledge
    - **Note**: medfit computes statistics; causal interpretation is
      user’s responsibility

### Diagnostics

Users should: - Check bootstrap distributions (histograms, Q-Q plots) -
Verify model convergence - Assess residual plots - Consider sensitivity
analyses

------------------------------------------------------------------------

## Common Pitfalls to Avoid

1.  **Don’t mix up variable names**: Ensure treatment/mediator names
    match model
2.  **Don’t ignore convergence warnings**: Check `converged` property
3.  **Don’t use plugin for inference**: Always bootstrap for CIs
4.  **Don’t skip input validation**: Use validators rigorously
5.  **Don’t break backward compatibility**: Coordinate with dependent
    packages
6.  **Don’t suppress errors/warnings without understanding them**: When
    encountering R CMD check NOTEs, warnings, or errors during package
    development:
    - **FIRST**: Research the issue to understand the root cause
    - **THEN**: Fix the underlying problem properly
    - **NEVER**: Use
      [`suppressMessages()`](https://rdrr.io/r/base/message.html),
      [`suppressWarnings()`](https://rdrr.io/r/base/warning.html), or
      [`tryCatch()`](https://rdrr.io/r/base/conditions.html) to hide
      issues without understanding them
    - Example: The “Overwriting method” S7 message was initially
      suppressed, but the real fix was proper `.onLoad()` registration
      order

------------------------------------------------------------------------

## Key Mathematical Formulas

### Indirect Effect

For simple mediation (X → M → Y):

    Indirect effect = a × b

where: - a = effect of X on M - b = effect of M on Y (controlling for X)

### Parametric Bootstrap

Sample from:

    θ* ~ N(θ̂, Σ̂)

Compute statistic for each θ\*, extract quantiles for CI.

### Nonparametric Bootstrap

1.  Resample data: D\* ~ D (with replacement)
2.  Refit models on D\*
3.  Extract θ\*
4.  Compute statistic
5.  Repeat, extract quantiles for CI

------------------------------------------------------------------------

## Additional Resources

### Package Ecosystem Documentation

- **probmed**: `probmed/CLAUDE.md`, `probmed/planning/`
- **RMediation**: `rmediation/CLAUDE.md`
- **medrobust**: `medrobust/CLAUDE.md`
- **Ecosystem strategy**:
  `probmed/planning/three-package-ecosystem-strategy.md`

### Key Planning Documents

Located in `planning/`: - **medfit-roadmap.md**: Detailed implementation
plan - **ECOSYSTEM.md**: Connection to dependent packages

### Related Packages

- probmed: <https://github.com/data-wise/probmed>
- RMediation: <https://github.com/data-wise/rmediation>
- medrobust: <https://github.com/data-wise/medrobust>

------------------------------------------------------------------------

## Troubleshooting

### lavaan Dispatch Issues

If
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
doesn’t work with lavaan objects: - Check that lavaan is installed -
Verify `.onLoad()` is registering the method - Test with
`methods(extract_mediation)` to see registered methods

### Bootstrap Reproducibility

If bootstrap results not reproducible: - Ensure seed is set before
calling - Check that parallel=FALSE or seed is set before parallel
call - Verify n_boot is the same

### Performance Issues

If bootstrap is slow: - Use `parallel=TRUE` - Consider parametric
instead of nonparametric - Reduce `n_boot` for testing (use 1000+ for
production)

### R File Loading Order Issues

If you get “object not found” errors during package load: - S7 generics
MUST be defined before methods that use them - R files load
alphabetically, so use prefixes: `aaa-imports.R`, `aab-generics.R` -
Methods in `extract-*.R` require generics from `aab-generics.R` to load
first

### lavaan Extraction Issues

If lavaan extraction fails with dimension errors: - **Parameter label
conflicts**: When lavaan model uses labels like `M ~ a*X`, the parameter
is already named “a” - Don’t add duplicate aliases that conflict with
existing parameter names - Check `names(lavaan::coef(fit))` to see
existing names - **Data type issues**:
`lavaan::lavInspect(object, "data")` may return matrix or numeric, not
data.frame - Convert to data.frame or return NULL if not convertible

### S7 “Class has not been registered with S4” Error

If you see this error during package installation: 1. Ensure
`S7::S4_register(ClassName)` is called in `.onLoad()` for each S7 class
2. Call `S4_register()` BEFORE `methods_register()` 3. Import full
`methods` package: `@import methods`

### S7 “Overwriting method” Messages

During `devtools::load_all()`, you may see “Overwriting method”
messages: - This is a **known development-time issue** (GitHub \#474) -
Does NOT affect installed packages - Caused by methods being registered
twice: during sourcing and in `.onLoad()` - Do NOT suppress with
[`suppressMessages()`](https://rdrr.io/r/base/message.html) - the
behavior is correct

------------------------------------------------------------------------

**Last Updated**: 2025-12-03 **Maintained by**: medfit development team

**Workflow Keywords:** - `doc` - Update planning documentation, README,
and NEWS - `check` - Run R CMD check –as-cran, build/preview website,
and check GitHub Actions status - `sync` - Commit and push changes to
remote
