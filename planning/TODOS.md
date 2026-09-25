# TODOS.md - medfit

Active tasks, implementation plan, and progress tracking.

---

## 🎯 Current Focus: Ext D (multilevel) — plan module 1

**Status:** 0.3.2 on CRAN (2026-07-23); **0.5.0 on main/GitHub/r-universe** (tag `v0.5.0`, 2026-09-25)
**Next:** Write the plan for the approved Ext D module-1 spec (2-1-1); decide the next CRAN trigger
**Updated:** 2026-09-25

> Decided 2026-09-24 (`specs/GRILL-0.5.0-release-2026-09-24.md`): 0.5.0 is **GitHub-only**;
> #81/#82 are correctness fixes, exempt from the deprecation period. CRAN 0.3.2 users are
> pointed to pinned issue #83 (README note). Next CRAN trigger is still open.

---

## 🔥 Active Tasks (This Sprint)

### High Priority 🔴

- [x] **Ext D (multilevel) spec** — module 1 (2-1-1, `ClusterMediationData`) approved 2026-09-25: `specs/SPEC-multilevel-mediation-2-1-1-2026-09-25.md` (decisions D1-D16 in `specs/GRILL-multilevel-mediation-ext-d-2026-09-25.md`)
- [ ] **Ext D module-1 plan** — tasks T0…Tn for PRs A (extract), B (fit engine), C (cluster bootstrap); T0 measures CRAN runtime and simulates the block-diagonal vcov
- [ ] **Next CRAN trigger** — open in `specs/GRILL-0.5.0-release-2026-09-24.md`

- [ ] **probmed Stage 2** (lives in the probmed repo, not here)
  - Unblocked by 0.3.2 on CRAN. probmed's DESCRIPTION already has `Imports: medfit (>= 0.3.0)`
    and no `Remotes:` pin (checked 2026-09-24); its CRAN prep is tracked in probmed
  - medfit side: probmed imports `extract_mediation()` and defines `pmed` methods on medfit classes; it calls neither `te()`/`pm()` nor `confint()`, so #81/#82 do not affect it

### Medium Priority 🟡

- [x] **Delta Method SEs** — done in #70 (`.effect_se()` feeds `confint(parm = "effects")` and
      `tidy()` for all classes; documented in `?tidy.S7_object` and the Methods and Formulas article)

- [ ] **Additional Vignette Ideas**
  - [x] "Mediation Analysis Workflow" (end-to-end example) — covered by Getting Started on
        `mediation_demo` (#63, #67)
  - [ ] "Comparing medfit with other packages"
  - [ ] "Extending medfit" (for developers)

### Low Priority / Future ⚪

- [ ] **BCa Confidence Intervals**
  - Bias-corrected and accelerated bootstrap
  - Better coverage than percentile method (bootstrap is percentile-only today)

- [ ] **Mixed Models Support (lme4)** — Ext D; module 1 (2-1-1) specced in
      `specs/SPEC-multilevel-mediation-2-1-1-2026-09-25.md`, module 2 (1-1-1) needs its own grill
  - `extract_mediation.lmerMod` method
  - Multilevel mediation analysis

- [ ] **Bayesian Support (brms)**
  - `extract_mediation.brmsfit` method
  - Posterior distributions for indirect effects

- [ ] **CMAverse adapter (Ext C.1)** — blocked: CMAverse is not on CRAN; simulation-based effects
      have no slot in the live-computed effect contract. See `EXTENSIONS-PLAN-2026-06-03.md`

---

## ✅ Recently Completed

### 2026-09-25 — 0.5.0 released (GitHub-only)

- [x] Pinned known-issues issue #83 for CRAN 0.3.2 + README pointer (2026-09-24)
- [x] **0.5.0 release — GitHub only** (released 2026-09-25, #84 → `4cb0550`, tag `v0.5.0`)
  - [x] Bump DESCRIPTION 0.4.0 → 0.5.0 (Date 2026-09-24); NEWS heading; README citation
  - [x] NEWS: both behavior changes marked, plus a 0.5.0 lead paragraph with the ecosystem
        note and #83 pointer
  - [x] `devtools::check()` clean + full test suite (cran-prep gate 2026-09-24: 0 errors, 0 warnings; 1546 tests pass; strict CRAN flavors not required for a
        GitHub-only release, but cheap; run them if time allows)
  - [x] Dependents vs dev 0.5.0 (scratch library, 2026-09-24): probmed `64f37cf` 465 passed /
        0 failed / 20 skipped (probmed's own incremental/rg-flow/Wasserstein skips); RMediation
        `7c588d4` 426 passed / 0 failed / 0 skipped
  - [x] dev → main PR #84 (merge commit, 17/17 checks), main CI green, tag `v0.5.0`, GitHub release
  - [x] Site serves 0.5.0; `articles/methods.html` returns 200
  - [x] r-universe `/api/packages` lists medfit 0.5.0
  - [x] #83 updated with the release link (stays open until a CRAN release)

### 2026-09-23 / 2026-09-24 (released in 0.5.0)

- [x] **Bundled `mediation_demo` dataset** (#62-#65, #67) — examples and articles moved to it;
      multi-mediator extraction errors on product terms (D8 guard, #62)
- [x] **Effect SEs** — `tidy()`/`confint()` delta-method effect SEs for all classes (#70); lavaan
      alias fixes (#69, #71, #73); wrapped-product detection (#74); `sandwich`/`vcov_fun` reach
      all workers, identity-link and unused `m_star` guards (#75); dead stubs removed (#72)
- [x] **D8(b) `JointMediationData`** (#76, #77) — joint natural effects for multi-mediator fits
      with X:M products (VanderWeele & Vansteelandt 2014), plus `joint_effects()`
- [x] **Methods and Formulas article** + documentation gap fixes (#79)
- [x] **Four-way E[M | X = 0]** uses design-column means (factor covariates, case-weighted) (#78)
- [x] **BEHAVIOR CHANGE:** serial `te()`/`pm()` sum every path; `nie(type = "total")` (#81)
- [x] **Joint SEs with caller-supplied `data =`** (#80)
- [x] **BEHAVIOR CHANGE:** `confint(parm = "paths")` finds rows by alias, errors instead of
      position-guessing; fixed wrong lavaan path SEs (#82)
- [x] Articles evaluate their code at site build (`b888ffe`); pkgdown CI runs on PRs to dev

### 2026-06 to 2026-08

- [x] Ext A: `ParallelMediationData` (#34, #36, #37)
- [x] Ext B: `InteractionMediationData`, VanderWeele four-way (#38, #39, #40)
- [x] Ext C: `fit_mediation(engine = "regmedint")` + `m_star` argument (#59) → 0.4.0
- [x] CRAN: 0.2.1 accepted (2026-06-18); 0.3.2 accepted + published (2026-07-23)
- [x] Phase 7: Polish & Release (R CMD check --as-cran, NOTEs, spelling, URLs, DESCRIPTION)

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
| 7 | Polish & release | ✅ Complete (0.3.2 on CRAN) |
| Ext A/B/C | Parallel, four-way, regmedint | ✅ Complete (0.4.0) |
| D8(b) | Joint multi-mediator interactions | ✅ Complete (0.5.0) |
| 0.5.0 | Release | ✅ Released 2026-09-25 (GitHub + r-universe) |

### Code Quality
- **Tests:** 1546 expectations (recorded at the 0.5.0 release gate)
- **Coverage:** Tracked via Codecov
- **R CMD check:** strict 0/0/1 (Date NOTE only) at last recorded run
- **Linting:** GitHub Actions CI

### Documentation
- **README:** ✅ Updated (#79)
- **NEWS:** ✅ 0.5.0 section current through #82
- **Vignettes:** 5 articles (getting-started, introduction, extraction, bootstrap, methods),
  evaluated at site build
- **pkgdown:** ✅ Live at https://data-wise.github.io/medfit/ (deploys from main)

---

## 📋 Backlog (Future Releases)

### Core Functionality
- [x] Four-way decomposition (VanderWeele 2014) — Ext B
- [x] Parallel mediation support — Ext A
- [ ] Standardized coefficients option — lavaan extractor only (`standardized = TRUE`); none for lm/glm
- [x] Treatment-mediator interaction detection — Ext B (single mediator), D8(b) (multiple mediators)
- [ ] Multilevel mediation (Ext D; module-1 spec approved 2026-09-25) and longitudinal mediation (Ext E) — see the 2026-08-22 brainstorm

### Model Support
- [ ] lmer/lme4 extraction
- [ ] brms extraction
- [ ] OpenMx extraction (postponed)

### Inference
- [ ] BCa bootstrap confidence intervals
- [x] Delta method SEs for derived effects — #70
- [ ] Studentized bootstrap

### Ecosystem
- [ ] probmed integration testing — probmed Stage 2, in the probmed repo
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

**Last Updated:** 2026-09-25
**Next Review:** After the Ext D module-1 plan
