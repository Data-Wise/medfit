# R-hub Badge Research: Tidyverse Best Practices

**Date**: 2025-12-20 **Research Question**: Should we include an R-hub
badge in medfit’s README?

------------------------------------------------------------------------

## Summary: R-hub Badge NOT Recommended

Based on research of tidyverse best practices and actual tidyverse
packages, **R-hub badges are NOT standard practice** for CRAN packages.

------------------------------------------------------------------------

## Research Findings

### 1. R-hub v2 Architecture

**Key Source**: [R-hub v2 Blog
Post](https://blog.r-hub.io/2024/04/11/rhub2/)

- R-hub v2 runs checks via **GitHub Actions** (`workflow_dispatch`
  trigger)
- It’s a **manual, on-demand** service, not continuous integration
- Used for **pre-CRAN testing** on multiple platforms
- **No guidance** in official docs about README badges

**Setup workflow**:

``` r
# 1. Install
install.packages("rhub")

# 2. Setup (adds .github/workflows/rhub.yaml)
rhub::rhub_setup()

# 3. Verify
rhub::rhub_doctor()

# 4. Run checks (manually)
rhub::rhub_check()
```

### 2. Tidyverse Package Analysis

Examined actual tidyverse packages to see what badges they use:

#### dplyr

**Source**: [tidyverse/dplyr](https://github.com/tidyverse/dplyr)

Badges shown: 1. CRAN status 2. R-CMD-check 3. Codecov

❌ **No R-hub badge**

#### ggplot2

**Source**: [tidyverse/ggplot2](https://github.com/tidyverse/ggplot2)

Badges shown: 1. R-CMD-check 2. CRAN status 3. Codecov

❌ **No R-hub badge**

#### usethis

**Source**: [r-lib/usethis](https://github.com/r-lib/usethis)

Badges shown: 1. R-CMD-check 2. CRAN status 3. Lifecycle: stable 4.
Codecov 5. R-universe version

❌ **No R-hub badge**

### 3. usethis Package Guidance

**Source**: [usethis GitHub Actions
Documentation](https://usethis.r-lib.org/reference/github_actions.html)

**Badge function**: `use_github_actions_badge()` - Purpose: Generate
badge markdown for workflow - Use case: Internal use, called by other
setup functions - **Not specifically recommended for R-hub**

**Recommended workflows**: 1. `use_github_action_check_standard()` - For
CRAN packages 2. `use_github_action_check_release()` - Basic checks 3.
`use_github_action_pr_commands()` - PR automation

**Badge best practice**: “Stick to 2-4 key badges” **Source**: [README
Badges Best
Practices](https://daily.dev/blog/readme-badges-github-best-practices)

### 4. GitHub Actions v2 for R

**Source**: [GitHub Actions for R developers,
v2](https://tidyverse.org/blog/2022/06/actions-2-0-0/)

- Modern R packages use **GitHub Actions** for CI/CD
- Standard workflows: R-CMD-check, test-coverage, pkgdown
- Focus on **continuous** integration, not manual checks

------------------------------------------------------------------------

## Why NO R-hub Badge?

### Technical Reasons

1.  **Manual trigger only** (`workflow_dispatch`)
    - Badge would show “no status” most of the time
    - Only runs when explicitly triggered
    - Not a continuous integration check
2.  **Pre-submission tool**, not CI
    - Used **before** CRAN submission to test platforms
    - Not meant for ongoing quality monitoring
    - GitHub Actions R-CMD-check serves that purpose
3.  **No standard badge pattern**
    - R-hub v2 doesn’t provide badge guidance
    - No `.svg` endpoint like other GitHub Actions
    - Would require custom badge setup

### Best Practice Reasons

1.  **Tidyverse doesn’t use it**
    - None of the major tidyverse packages show R-hub badges
    - If it were standard, dplyr/ggplot2/usethis would have it
2.  **Clutters README**
    - Best practice: 2-4 key badges
    - R-hub doesn’t provide unique value vs R-CMD-check
3.  **Confusing for users**
    - Users care about: CRAN status, CI passing, test coverage
    - R-hub status is internal/developer concern

------------------------------------------------------------------------

## Recommended Badge Setup for medfit

Based on tidyverse best practices:

``` markdown
<!-- badges: start -->
[![CRAN status](https://www.r-pkg.org/badges/version/medfit)](https://CRAN.R-project.org/package=medfit)
[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![R-CMD-check](https://github.com/data-wise/medfit/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/data-wise/medfit/actions/workflows/R-CMD-check.yaml)
[![Codecov](https://codecov.io/gh/data-wise/medfit/graph/badge.svg)](https://codecov.io/gh/data-wise/medfit)
[![pkgdown](https://github.com/data-wise/medfit/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/data-wise/medfit/actions/workflows/pkgdown.yaml)
<!-- badges: end -->
```

**Rationale**: 1. **CRAN status** - Primary indicator for R users 2.
**Lifecycle** - Shows package maturity 3. **R-CMD-check** - Continuous
CI (covers what R-hub would) 4. **Codecov** - Test quality metric 5.
**pkgdown** - Documentation availability

------------------------------------------------------------------------

## When to Use R-hub

R-hub is still valuable, just **not for badges**:

### Use R-hub for:

1.  **Pre-CRAN submission testing**

    ``` r
    rhub::rhub_check()  # Before submitting to CRAN
    ```

2.  **Platform-specific issues**

    - Test on Windows if you’re on macOS
    - Test on Solaris, older R versions
    - Test with specific compiler configurations

3.  **Major releases**

    - Before v1.0.0, v2.0.0, etc.
    - When adding platform-specific code
    - After significant refactoring

### Don’t use R-hub for:

- Continuous integration (use GitHub Actions R-CMD-check)
- README badges (no standard pattern)
- Every commit (too heavyweight, manual trigger)

------------------------------------------------------------------------

## Conclusion

✅ **Current medfit badges are correct** - aligned with tidyverse best
practices

❌ **Do NOT add R-hub badge** - not used by tidyverse, would clutter
README

✅ **Keep R-hub workflow** (`.github/workflows/rhub.yaml`) - useful
tool, just don’t badge it

✅ **Use R-hub before CRAN submission** - via `rhub::rhub_check()` or
GitHub Actions UI

------------------------------------------------------------------------

## Sources

1.  [R-hub v2 Blog Post](https://blog.r-hub.io/2024/04/11/rhub2/)
2.  [usethis GitHub Actions
    Documentation](https://usethis.r-lib.org/reference/github_actions.html)
3.  [GitHub Actions for R developers,
    v2](https://tidyverse.org/blog/2022/06/actions-2-0-0/)
4.  [r-lib/actions Repository](https://github.com/r-lib/actions)
5.  [README Badges Best
    Practices](https://daily.dev/blog/readme-badges-github-best-practices)
6.  [dplyr Repository](https://github.com/tidyverse/dplyr)
7.  [ggplot2 Repository](https://github.com/tidyverse/ggplot2)
8.  [usethis Repository](https://github.com/r-lib/usethis)

------------------------------------------------------------------------

**Recommendation**: Keep current badges, use R-hub manually before CRAN
submission.
