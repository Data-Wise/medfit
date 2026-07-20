# TODOS.md - medfit

Active tasks, implementation plan, and progress tracking.

---

## 🎯 Current Focus: Phase 7 - Polish & Release

**Status:** Feature Complete (97%)
**Next:** Polish, testing, CRAN prep
**Updated:** 2025-12-17

---

## 🔥 Active Tasks (This Sprint)

### High Priority 🔴

- [ ] **Phase 7: Polish & Release** [2-3 days]
  - [ ] Run comprehensive R CMD check --as-cran
  - [ ] Fix any remaining NOTEs/WARNINGs
  - [ ] Spell check all documentation
  - [ ] URL validation for all links
  - [ ] Update DESCRIPTION for CRAN submission

- [ ] **probmed Integration** [1 day]
  - [ ] Test `med()` output with P_med computation
  - [ ] Ensure `nie()`, `nde()` work in probmed workflows
  - [ ] Update probmed vignettes with medfit examples

### Medium Priority 🟡

- [ ] **Delta Method SEs** [2-3 hr]
  - [ ] Add standard errors for NIE, NDE, TE
  - [ ] Implement `confint()` for derived effects
  - [ ] Document delta method assumptions

- [ ] **Additional Vignette Ideas**
  - [ ] "Mediation Analysis Workflow" (end-to-end example)
  - [ ] "Comparing medfit with other packages"
  - [ ] "Extending medfit" (for developers)

### Low Priority / Future ⚪

- [ ] **BCa Confidence Intervals**
  - Bias-corrected and accelerated bootstrap
  - Better coverage than percentile method

- [ ] **Mixed Models Support (lme4)**
  - `extract_mediation.lmerMod` method
  - Multilevel mediation analysis

- [ ] **Bayesian Support (brms)**
  - `extract_mediation.brmsfit` method
  - Posterior distributions for indirect effects

---

## ✅ Recently Completed

### 2025-12-17

#### Phase 6.5: ADHD-Friendly API ✅
- [x] **`med()` function** - One-function mediation analysis
  - Fits mediator and outcome models automatically
  - Optional bootstrap with `boot = TRUE`
  - Supports covariates
  - Returns MediationData object

- [x] **`quick()` function** - One-line summary
  - Works with MediationData, SerialMediationData
  - Shows NIE, NDE, PM in compact format
  - Includes bootstrap CI when available

#### Phase 6: Generic Functions ✅
- [x] **Effect Extractors**
  - `nie()` - Natural Indirect Effect
  - `nde()` - Natural Direct Effect
  - `te()` - Total Effect
  - `pm()` - Proportion Mediated
  - `paths()` - All path coefficients

- [x] **Tidyverse Integration**
  - `tidy()` - Convert to tibble
  - `glance()` - One-row model summary
  - Support for `type = "paths"` / `type = "effects"`
  - Support for `conf.int = TRUE`

- [x] **Base R Generics**
  - `coef()` - Extract coefficients
  - `vcov()` - Variance-covariance matrix
  - `confint()` - Confidence intervals
  - `nobs()` - Number of observations

#### Documentation Update ✅
- [x] README.md - Complete rewrite with new API
- [x] getting-started.qmd - Full vignette rewrite
- [x] introduction.qmd - Updated all sections
- [x] NEWS.md - Phase 6/6.5 documented
- [x] pkgdown reference - Reorganized by category

### 2025-12-16

- [x] Branch cleanup: Removed worktrees and merged branches
- [x] Merged dev → main: All Phase 4-5 work
- [x] Fixed pkgdown deployment with clean deploys
- [x] Comprehensive docs check passed

### Earlier (Phase 1-5)

- [x] Phase 1: Package setup (CI/CD, Dependabot)
- [x] Phase 2: S7 classes (MediationData, SerialMediationData, BootstrapResult)
- [x] Phase 2.5: Quarto vignettes (4 articles)
- [x] Phase 3: Model extraction (lm/glm, lavaan)
- [x] Phase 4: `fit_mediation()` with GLM engine
- [x] Phase 5: `bootstrap_mediation()` (parametric, nonparametric, plugin)

---

## 📊 Progress Metrics

### Implementation Progress
| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Package setup | ✅ Complete |
| 2 | S7 classes | ✅ Complete |
| 2.5 | Documentation | ✅ Complete |
| 3 | Model extraction | ✅ Complete |
| 4 | Model fitting | ✅ Complete |
| 5 | Bootstrap | ✅ Complete |
| 6 | Generics | ✅ Complete |
| 6.5 | ADHD API | ✅ Complete |
| 7 | Polish & release | 🚧 In Progress |

### Code Quality
- **Tests:** 427 passing
- **Coverage:** Tracked via Codecov
- **R CMD check:** Clean (1 NOTE - dev version)
- **Linting:** GitHub Actions CI

### Documentation
- **README:** ✅ Updated
- **NEWS:** ✅ Updated
- **Vignettes:** 4 articles (getting-started, introduction, extraction, bootstrap)
- **pkgdown:** ✅ Live at https://data-wise.github.io/medfit/

---

## 📋 Backlog (Future Releases)

### Core Functionality
- [ ] Four-way decomposition (VanderWeele 2014)
- [ ] Parallel mediation support
- [ ] Standardized coefficients option
- [ ] Treatment-mediator interaction detection

### Model Support
- [ ] lmer/lme4 extraction
- [ ] brms extraction
- [ ] OpenMx extraction (postponed)

### Inference
- [ ] BCa bootstrap confidence intervals
- [ ] Delta method SEs for derived effects
- [ ] Studentized bootstrap

### Ecosystem
- [ ] probmed integration testing
- [ ] RMediation coordination
- [ ] medrobust sensitivity analysis workflow

---

## 💡 Notes & Reminders

### API Design (Finalized)
- **Entry points:** `med()` (simple) or `fit_mediation()` (advanced)
- **Extractors:** `nie()`, `nde()`, `te()`, `pm()`, `paths()`
- **Tidyverse:** `tidy()`, `glance()`
- **Base R:** `coef()`, `vcov()`, `confint()`, `nobs()`
- **Summary:** `quick()` for one-line output

### Code Style
- snake_case for functions/arguments
- CamelCase for S7 classes
- Prefix internal functions with `.`
- Always use checkmate for input validation

### Git Workflow
- Main branch for releases
- Dev branch for development
- Feature branches for major changes

---

**Last Updated:** 2025-12-17
**Next Review:** After Phase 7 completion
