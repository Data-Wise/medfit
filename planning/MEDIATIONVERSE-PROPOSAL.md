# Mediationverse: Meta-Package Proposal

**Date**: December 3, 2025
**Status**: Approved
**Implementation**: Q2-Q3 2025

---

## Executive Summary

Create a **mediationverse** meta-package following the tidyverse/easystats pattern to provide unified installation, loading, and branding for the mediation analysis ecosystem.

---

## Motivation

### Current Challenge

Users must install and load 4 separate packages:
```r
install.packages(c("medfit", "probmed", "RMediation", "medrobust"))
library(medfit)
library(probmed)
library(RMediation)
library(medrobust)
```

### Proposed Solution

Single installation and loading:
```r
install.packages("mediationverse")
library(mediationverse)
# All packages loaded with version info displayed
```

---

## Architecture

### Package Structure

```
mediationverse/
├── DESCRIPTION          # Meta-package dependencies
├── R/
│   ├── mediationverse-package.R  # Package documentation
│   ├── attach.R         # Package attachment logic
│   └── conflicts.R      # Conflict management
├── man/
│   └── mediationverse-package.Rd
├── vignettes/
│   ├── mediationverse.Rmd       # Overview
│   ├── getting-started.Rmd      # Quick start
│   └── ecosystem-guide.Rmd      # When to use each package
└── tests/
    └── testthat/
        └── test-package-loading.R
```

### Dependencies

**DESCRIPTION:**
```
Package: mediationverse
Type: Package
Title: Ecosystem for Mediation Analysis in R
Version: 1.0.0
Authors@R: person("Davood", "Tofighi",
    email = "dtofighi@gmail.com",
    role = c("aut", "cre"),
    comment = c(ORCID = "0000-0001-8523-7776"))
Description: A meta-package that loads the core packages in the mediation
    analysis ecosystem: 'medfit' (infrastructure), 'probmed' (probabilistic
    effect sizes), 'RMediation' (confidence intervals), and 'medrobust'
    (sensitivity analysis). This package simplifies installation and provides
    a unified entry point for mediation analysis in R.
License: GPL (>= 3)
URL: https://github.com/data-wise/mediationverse, https://mediationverse.org
BugReports: https://github.com/data-wise/mediationverse/issues
Depends:
    R (>= 4.1.0)
Imports:
    medfit (>= 0.1.0),
    probmed (>= 0.2.0),
    RMediation (>= 1.5.0),
    medrobust (>= 0.2.0),
    cli,
    rlang
Suggests:
    testthat (>= 3.0.0),
    knitr,
    rmarkdown
Encoding: UTF-8
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.3.0
VignetteBuilder: knitr
```

---

## Implementation Plan

### Phase 1: Package Skeleton (Week 1)

**Tasks:**
1. Create package with `usethis::create_package()`
2. Set up basic structure
3. Configure git and GitHub
4. Initialize documentation

**Commands:**
```r
# Create package
usethis::create_package("~/packages/mediationverse")

# Set license
usethis::use_gpl_license(version = 3)

# Set up git
usethis::use_git()
usethis::use_github(organisation = "data-wise")

# Add dependencies
usethis::use_package("medfit", min_version = "0.1.0")
usethis::use_package("probmed", min_version = "0.2.0")
usethis::use_package("RMediation", min_version = "1.5.0")
usethis::use_package("medrobust", min_version = "0.2.0")
usethis::use_package("cli")
usethis::use_package("rlang")

# Set up testing
usethis::use_testthat()

# Set up pkgdown
usethis::use_pkgdown()
usethis::use_pkgdown_github_pages()
```

### Phase 2: Core Functionality (Week 2)

**R/attach.R** - Package attachment logic:
```r
#' Attach core packages from mediationverse
#' @keywords internal
mediationverse_attach <- function() {
  core <- c("medfit", "probmed", "RMediation", "medrobust")
  to_load <- core[!is_attached(core)]

  if (length(to_load) == 0) {
    return(invisible())
  }

  suppressPackageStartupMessages(
    lapply(to_load, library, character.only = TRUE, warn.conflicts = FALSE)
  )

  invisible()
}

#' Check if packages are attached
#' @keywords internal
is_attached <- function(x) {
  paste0("package:", x) %in% search()
}
```

**R/zzz.R** - Startup message:
```r
.onAttach <- function(libname, pkgname) {
  # Attach core packages
  mediationverse_attach()

  # Get version info
  core_versions <- vapply(
    c("medfit", "probmed", "RMediation", "medrobust"),
    function(pkg) as.character(utils::packageVersion(pkg)),
    character(1)
  )

  # Create startup message
  msg <- cli::format_inline("
── {.strong Attaching packages} ────────────────── mediationverse {utils::packageVersion('mediationverse')} ──
{cli::symbol$tick} medfit     {core_versions['medfit']}     {cli::symbol$tick} probmed    {core_versions['probmed']}
{cli::symbol$tick} RMediation {core_versions['RMediation']}     {cli::symbol$tick} medrobust  {core_versions['medrobust']}
───────────────────────────────────────────────────────────────────────
  ")

  packageStartupMessage(msg)
}
```

**R/conflicts.R** - Conflict detection:
```r
#' Check for conflicts with mediationverse packages
#' @export
mediationverse_conflicts <- function() {
  core <- c("medfit", "probmed", "RMediation", "medrobust")

  conflicts <- purrr::map(core, function(pkg) {
    if (!is_attached(pkg)) return(NULL)

    # Get exported functions
    exports <- getNamespaceExports(pkg)

    # Find conflicts
    conflicts <- exports[exports %in% ls(envir = .GlobalEnv)]

    if (length(conflicts) == 0) return(NULL)

    list(package = pkg, conflicts = conflicts)
  })

  purrr::compact(conflicts)
}
```

### Phase 3: Documentation (Week 3)

**Vignettes:**

1. **`vignettes/mediationverse.Rmd`** - Overview
   - What is mediationverse?
   - Package ecosystem diagram
   - Quick installation guide

2. **`vignettes/getting-started.Rmd`** - Quick start
   - Installation
   - Basic workflow examples
   - When to use each package

3. **`vignettes/ecosystem-guide.Rmd`** - Detailed guide
   - Package descriptions
   - Use case matrix
   - Integration patterns

**README.md:**
```markdown
# mediationverse <img src="man/figures/logo.png" align="right" height="139" />

> Unified ecosystem for mediation analysis in R

[![R-CMD-check](https://github.com/data-wise/mediationverse/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/data-wise/mediationverse/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/mediationverse)](https://CRAN.R-project.org/package=mediationverse)

## Overview

The **mediationverse** is a collection of R packages for mediation analysis:

- **[medfit](https://data-wise.github.io/medfit/)** - Infrastructure for model fitting and extraction
- **[probmed](https://data-wise.github.io/probmed/)** - Probabilistic effect size (P_med)
- **[RMediation](https://cran.r-project.org/package=RMediation)** - Confidence intervals (DOP, MBCO)
- **[medrobust](https://data-wise.github.io/medrobust/)** - Sensitivity analysis

## Installation

Install all packages at once:

```r
# From CRAN
install.packages("mediationverse")

# Development version
pak::pak("data-wise/mediationverse")
```

## Usage

```r
library(mediationverse)
# ── Attaching packages ──────────────── mediationverse 1.0.0 ──
# ✔ medfit     0.1.0     ✔ probmed    0.2.0
# ✔ RMediation 1.5.0     ✔ medrobust  0.2.0

# Example workflow
fit_m <- lm(M ~ X + C, data = mydata)
fit_y <- lm(Y ~ X + M + C, data = mydata)

# Extract mediation structure (medfit)
med_data <- extract_mediation(fit_m, model_y = fit_y,
                               treatment = "X", mediator = "M")

# Compute P_med (probmed)
pmed_result <- compute_pmed(med_data)

# Get confidence intervals (RMediation)
ci_result <- ci(med_data, type = "dop")

# Sensitivity analysis (medrobust)
robust_result <- sensitivity_analysis(med_data)
```

## Learn more

- [Getting Started](https://mediationverse.org/articles/getting-started.html)
- [Ecosystem Guide](https://mediationverse.org/articles/ecosystem-guide.html)
- [Package Websites](https://mediationverse.org/#packages)
```

### Phase 4: Testing & CI/CD (Week 4)

**tests/testthat/test-attach.R:**
```r
test_that("mediationverse attaches core packages", {
  library(mediationverse)

  expect_true("package:medfit" %in% search())
  expect_true("package:probmed" %in% search())
  expect_true("package:RMediation" %in% search())
  expect_true("package:medrobust" %in% search())
})

test_that("package versions are correct", {
  library(mediationverse)

  expect_true(utils::packageVersion("medfit") >= "0.1.0")
  expect_true(utils::packageVersion("probmed") >= "0.2.0")
  expect_true(utils::packageVersion("RMediation") >= "1.5.0")
  expect_true(utils::packageVersion("medrobust") >= "0.2.0")
})
```

**GitHub Actions:**
- R-CMD-check (multi-platform)
- pkgdown deployment
- Test coverage

---

## Timeline

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| 1. Skeleton | Week 1 | Package structure, GitHub repo |
| 2. Core | Week 2 | Attachment logic, conflicts |
| 3. Docs | Week 3 | Vignettes, README, pkgdown site |
| 4. Testing | Week 4 | Tests, CI/CD |
| 5. Release | Week 5 | CRAN submission |

**Total**: 4-5 weeks

---

## Benefits

### For Users
✅ One-command installation
✅ Consistent loading and version checking
✅ Clear ecosystem branding
✅ Unified documentation

### For Developers
✅ Coordinated releases
✅ Version compatibility enforcement
✅ Shared CI/CD patterns
✅ Ecosystem-wide visibility

### For the Ecosystem
✅ Professional presentation
✅ Easier discoverability
✅ Community building
✅ Citation consistency

---

## Success Metrics

- Downloads: Track CRAN downloads
- Citations: Monitor academic citations
- Issues: Track GitHub issues and engagement
- Ecosystem growth: New packages joining

---

## Future Enhancements

### Version 1.1
- [ ] `mediationverse_update()` function to update all packages
- [ ] `mediationverse_sitrep()` for system report
- [ ] Better conflict management

### Version 2.0
- [ ] Support for additional packages (community contributions)
- [ ] Integration with workflow packages (targets, drake)
- [ ] Enhanced visualization utilities

---

## References

**Inspiration:**
- [tidyverse](https://www.tidyverse.org/)
- [easystats](https://easystats.github.io/easystats/)
- [mlr3](https://mlr3.mlr-org.com/)

**Best Practices:**
- [Creating Your Own Package 'verse'](https://www.jdtrat.com/blog/creating-your-own-package-verse/)
- [Tidyverse Design Principles](https://design.tidyverse.org/)

---

**Approved by**: Davood Tofighi
**Implementation Start**: Q2 2025
**Expected Release**: Q3 2025
