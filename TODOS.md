# TODOS.md - medfit

Active tasks, implementation plan, and progress tracking.

------------------------------------------------------------------------

## 🎯 Current Focus: Phase 7 - Polish & Release

**Status:** Feature Complete (97%) **Next:** Polish, testing, CRAN prep
**Updated:** 2025-12-17

------------------------------------------------------------------------

## 🔥 Active Tasks (This Sprint)

### High Priority 🔴

**Phase 7: Polish & Release** \[2-3 days\]

Run comprehensive R CMD check –as-cran

Fix any remaining NOTEs/WARNINGs

Spell check all documentation

URL validation for all links

Update DESCRIPTION for CRAN submission

**probmed Integration** \[1 day\]

Test [`med()`](https://data-wise.github.io/medfit/reference/med.md)
output with P_med computation

Ensure [`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
[`nde()`](https://data-wise.github.io/medfit/reference/nde.md) work in
probmed workflows

Update probmed vignettes with medfit examples

### Medium Priority 🟡

**Delta Method SEs** \[2-3 hr\]

Add standard errors for NIE, NDE, TE

Implement [`confint()`](https://rdrr.io/r/stats/confint.html) for
derived effects

Document delta method assumptions

**Additional Vignette Ideas**

“Mediation Analysis Workflow” (end-to-end example)

“Comparing medfit with other packages”

“Extending medfit” (for developers)

### Low Priority / Future ⚪

**BCa Confidence Intervals**

- Bias-corrected and accelerated bootstrap
- Better coverage than percentile method

**Mixed Models Support (lme4)**

- `extract_mediation.lmerMod` method
- Multilevel mediation analysis

**Bayesian Support (brms)**

- `extract_mediation.brmsfit` method
- Posterior distributions for indirect effects

------------------------------------------------------------------------

## ✅ Recently Completed

### 2025-12-17

#### Phase 6.5: ADHD-Friendly API ✅

**[`med()`](https://data-wise.github.io/medfit/reference/med.md)
function** - One-function mediation analysis

- Fits mediator and outcome models automatically
- Optional bootstrap with `boot = TRUE`
- Supports covariates
- Returns MediationData object

**[`quick()`](https://data-wise.github.io/medfit/reference/quick.md)
function** - One-line summary

- Works with MediationData, SerialMediationData
- Shows NIE, NDE, PM in compact format
- Includes bootstrap CI when available

#### Phase 6: Generic Functions ✅

**Effect Extractors**

- [`nie()`](https://data-wise.github.io/medfit/reference/nie.md) -
  Natural Indirect Effect
- [`nde()`](https://data-wise.github.io/medfit/reference/nde.md) -
  Natural Direct Effect
- [`te()`](https://data-wise.github.io/medfit/reference/te.md) - Total
  Effect
- [`pm()`](https://data-wise.github.io/medfit/reference/pm.md) -
  Proportion Mediated
- [`paths()`](https://data-wise.github.io/medfit/reference/paths.md) -
  All path coefficients

**Tidyverse Integration**

- `tidy()` - Convert to tibble
- `glance()` - One-row model summary
- Support for `type = "paths"` / `type = "effects"`
- Support for `conf.int = TRUE`

**Base R Generics**

- [`coef()`](https://rdrr.io/r/stats/coef.html) - Extract coefficients
- [`vcov()`](https://rdrr.io/r/stats/vcov.html) - Variance-covariance
  matrix
- [`confint()`](https://rdrr.io/r/stats/confint.html) - Confidence
  intervals
- [`nobs()`](https://rdrr.io/r/stats/nobs.html) - Number of observations

#### Documentation Update ✅

README.md - Complete rewrite with new API

getting-started.qmd - Full vignette rewrite

introduction.qmd - Updated all sections

NEWS.md - Phase 6/6.5 documented

pkgdown reference - Reorganized by category

### 2025-12-16

Branch cleanup: Removed worktrees and merged branches

Merged dev → main: All Phase 4-5 work

Fixed pkgdown deployment with clean deploys

Comprehensive docs check passed

### Earlier (Phase 1-5)

Phase 1: Package setup (CI/CD, Dependabot)

Phase 2: S7 classes (MediationData, SerialMediationData,
BootstrapResult)

Phase 2.5: Quarto vignettes (4 articles)

Phase 3: Model extraction (lm/glm, lavaan)

Phase 4:
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
with GLM engine

Phase 5:
[`bootstrap_mediation()`](https://data-wise.github.io/medfit/reference/bootstrap_mediation.md)
(parametric, nonparametric, plugin)

------------------------------------------------------------------------

## 📊 Progress Metrics

### Implementation Progress

| Phase | Description      | Status         |
|-------|------------------|----------------|
| 1     | Package setup    | ✅ Complete    |
| 2     | S7 classes       | ✅ Complete    |
| 2.5   | Documentation    | ✅ Complete    |
| 3     | Model extraction | ✅ Complete    |
| 4     | Model fitting    | ✅ Complete    |
| 5     | Bootstrap        | ✅ Complete    |
| 6     | Generics         | ✅ Complete    |
| 6.5   | ADHD API         | ✅ Complete    |
| 7     | Polish & release | 🚧 In Progress |

### Code Quality

- **Tests:** 427 passing
- **Coverage:** Tracked via Codecov
- **R CMD check:** Clean (1 NOTE - dev version)
- **Linting:** GitHub Actions CI

### Documentation

- **README:** ✅ Updated
- **NEWS:** ✅ Updated
- **Vignettes:** 4 articles (getting-started, introduction, extraction,
  bootstrap)
- **pkgdown:** ✅ Live at <https://data-wise.github.io/medfit/>

------------------------------------------------------------------------

## 📋 Backlog (Future Releases)

### Core Functionality

Four-way decomposition (VanderWeele 2014)

Parallel mediation support

Standardized coefficients option

Treatment-mediator interaction detection

### Model Support

lmer/lme4 extraction

brms extraction

OpenMx extraction (postponed)

### Inference

BCa bootstrap confidence intervals

Delta method SEs for derived effects

Studentized bootstrap

### Ecosystem

probmed integration testing

RMediation coordination

medrobust sensitivity analysis workflow

------------------------------------------------------------------------

## 💡 Notes & Reminders

### API Design (Finalized)

- **Entry points:**
  [`med()`](https://data-wise.github.io/medfit/reference/med.md)
  (simple) or
  [`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md)
  (advanced)
- **Extractors:**
  [`nie()`](https://data-wise.github.io/medfit/reference/nie.md),
  [`nde()`](https://data-wise.github.io/medfit/reference/nde.md),
  [`te()`](https://data-wise.github.io/medfit/reference/te.md),
  [`pm()`](https://data-wise.github.io/medfit/reference/pm.md),
  [`paths()`](https://data-wise.github.io/medfit/reference/paths.md)
- **Tidyverse:** `tidy()`, `glance()`
- **Base R:** [`coef()`](https://rdrr.io/r/stats/coef.html),
  [`vcov()`](https://rdrr.io/r/stats/vcov.html),
  [`confint()`](https://rdrr.io/r/stats/confint.html),
  [`nobs()`](https://rdrr.io/r/stats/nobs.html)
- **Summary:**
  [`quick()`](https://data-wise.github.io/medfit/reference/quick.md) for
  one-line output

### Code Style

- snake_case for functions/arguments
- CamelCase for S7 classes
- Prefix internal functions with `.`
- Always use checkmate for input validation

### Git Workflow

- Main branch for releases
- Dev branch for development
- Feature branches for major changes

------------------------------------------------------------------------

**Last Updated:** 2025-12-17 **Next Review:** After Phase 7 completion
