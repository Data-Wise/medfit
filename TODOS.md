# TODOS.md - medfit

Active tasks, implementation plan, and progress tracking.

---

## 🎯 Current Focus: Phase 7 (Polish & Release)

**Status:** Phase 6 Complete - Phase 7 In Progress
**Next:** CI verification, probmed integration
**Updated:** 2025-12-16

---

## 🔥 Active Tasks (This Sprint)

### High Priority (Pending CI/External)

- [ ] **Verify CI passes after merge** [5 min]
  - Wait for GitHub Actions to complete
  - Verify R CMD check passes on all platforms
  - Verify pkgdown site deploys successfully

- [ ] **Merge feature branch to dev** [5 min]
  - PR created: `claude/resume-session-01Gv8VrWzxR1LaUvoyy8pqR5` -> `dev`
  - Review and merge

- [ ] **Merge dev to main** [10 min]
  - After CI passes on dev
  - Triggers pkgdown deployment

### Medium Priority (After Merge)

- [ ] **Start probmed integration** [2-3 hr]
  - Update probmed to depend on medfit
  - Replace duplicate code with medfit functions
  - Test integration

- [ ] **Run final CRAN checks** [30 min]
  - `devtools::check(cran = TRUE)`
  - Address any final notes

### Low Priority / Future

- [ ] **Submit to CRAN** [1 hr]
  - After probmed integration confirmed working
  - Final review of cran-comments.md
  - Submit via devtools::submit_cran()

---

## ✅ Phase 7 Completed Tasks

### 2025-12-16

- [x] **Vignettes updated with working code**
  - [x] getting-started.qmd - `eval: true` with live examples
  - [x] introduction.qmd - Updated S7 class examples
  - [x] extraction.qmd - Working lm/glm/lavaan examples
  - [x] bootstrap.qmd - All three methods demonstrated

- [x] **Documentation updates**
  - [x] NEWS.md - Phase status updated
  - [x] README.md - Development status to Phase 7
  - [x] planning/medfit-roadmap.md - Phase 6 marked complete

- [x] **CRAN preparation**
  - [x] cran-comments.md created
  - [x] DESCRIPTION Date updated
  - [x] All examples use minimal data
  - [x] Tests skip appropriately (lavaan optional)

- [x] **CI/CD configured**
  - [x] R-CMD-check workflow (5 platforms)
  - [x] test-coverage workflow (Codecov)
  - [x] pkgdown workflow (with Quarto support)
  - [x] README badges added

---

## ✅ Phase 6 Completed Tasks (Extended Testing)

### Test Suite (78 tests)
- [x] test-classes.R (33 tests) - S7 class validation
- [x] test-extract-lm.R (12 tests) - lm/glm extraction
- [x] test-extract-lavaan.R (10 tests) - lavaan extraction
- [x] test-fit-glm.R (9 tests) - GLM fitting
- [x] test-bootstrap.R (14 tests) - Bootstrap methods
- [x] helper-test-data.R - Centralized test generators

### Documentation (4 Quarto vignettes)
- [x] Getting Started - Quick start examples
- [x] Introduction - S7 class architecture
- [x] Model Extraction - lm/glm/lavaan methods
- [x] Bootstrap Inference - All three methods

---

## ✅ Phase 5 Completed Tasks (Bootstrap Infrastructure)

- [x] **bootstrap_mediation() implemented**
  - [x] Parametric bootstrap (MVN sampling)
  - [x] Nonparametric bootstrap (data resampling)
  - [x] Plugin method (point estimate only)
  - [x] Parallel processing support (Unix)
  - [x] Seed-based reproducibility

---

## ✅ Phase 4 Completed Tasks (Model Fitting)

- [x] **fit_mediation() implemented**
  - [x] GLM engine with formula interface
  - [x] Gaussian and non-Gaussian families
  - [x] Covariate support
  - [x] Returns MediationData object

---

## ✅ Phase 3 Completed Tasks (Model Extraction)

- [x] **extract_mediation() generic**
- [x] **lm/glm method** - Full implementation with validation
- [x] **lavaan method** - SEM model extraction

---

## ✅ Phase 2 Completed Tasks (S7 Classes)

- [x] **MediationData** - Simple mediation (X -> M -> Y)
- [x] **SerialMediationData** - Serial mediation (X -> M1 -> M2 -> ... -> Y)
- [x] **BootstrapResult** - Bootstrap inference results
- [x] Comprehensive validators
- [x] Print, summary, show methods

---

## ✅ Phase 1 Completed Tasks (Package Setup)

- [x] Package skeleton
- [x] DESCRIPTION with proper fields
- [x] GitHub repository with dev branch workflow
- [x] CI/CD workflows configured
- [x] CLAUDE.md and roadmap documentation

---

## 📊 Progress Summary

### Implementation: 100% Complete (MVP)
- [x] S7 classes (MediationData, SerialMediationData, BootstrapResult)
- [x] extract_mediation() (lm/glm, lavaan)
- [x] fit_mediation() (GLM engine)
- [x] bootstrap_mediation() (parametric, nonparametric, plugin)

### Testing: 100% Complete
- 78 tests across 5 test files
- Full coverage of all core functionality
- Edge cases and error conditions tested

### Documentation: 100% Complete
- 4 Quarto vignettes with working code
- All exported functions documented
- pkgdown website configured

### CI/CD: Configured (Pending Verification)
- R-CMD-check on 5 platforms
- Test coverage reporting (Codecov)
- pkgdown deployment

### CRAN: Ready for Submission
- cran-comments.md prepared
- All checks configured
- Pending final CI verification

---

## 📋 Backlog (Post-MVP)

### Future Enhancements
- [ ] lmer engine (mixed models)
- [ ] brms engine (Bayesian)
- [ ] OpenMx extraction method
- [ ] Standardized coefficients option
- [ ] Four-way decomposition (VanderWeele)

### Ecosystem Integration
- [ ] probmed integration (immediate priority)
- [ ] RMediation integration
- [ ] medrobust integration
- [ ] CMAverse adapter

---

## 💡 Notes

### Next Steps After CI Passes
1. Merge PR to dev
2. Merge dev to main (triggers pkgdown deployment)
3. Begin probmed integration
4. Final CRAN preparation

### Strategic Documents Available
See `planning/` directory for:
- API-DESIGN-DECISIONS.md - Finalized API design
- ADHD-FRIENDLY-WORKFLOW.md - Workflow alternatives
- GENERIC-NAMING-STRATEGY.md - Generic function strategy
- MEDIATIONVERSE-PROPOSAL.md - Ecosystem proposal

---

**Last Updated:** 2025-12-16
**Phase:** 7 (Polish & Release)
**Next Review:** After CI verification and merge to main
