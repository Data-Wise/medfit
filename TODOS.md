# TODOS.md - medfit

Active tasks, implementation plan, and progress tracking.

---

## 🎯 Current Focus: Test-Driven Development Phase

**Status:** ✅ Test infrastructure complete
**Next:** Implement core functions guided by tests
**Updated:** 2025-12-15

---

## 🔥 Active Tasks (This Sprint)

### High Priority 🔴

- [ ] **Update project documentation** [10 min] ⚡
  - [x] Create IDEAS.md
  - [x] Create TODOS.md
  - [ ] Update .STATUS with test suite milestone
  - [ ] Update PROJECT-HUB.md progress

- [ ] **Commit test infrastructure** [5 min] ⚡
  ```bash
  git add tests/testthat/test-bootstrap.R
  git add tests/testthat/test-fit-glm.R
  git add tests/testthat/helper-test-data.R
  git add IDEAS.md TODOS.md PROJECT-HUB.md
  git commit -m "test: add comprehensive test suite

  - Add test-bootstrap.R (27 tests)
  - Add test-fit-glm.R (30 tests)
  - Add helper-test-data.R (centralized generators)
  - Add project management files
  - Total: 241 tests (184 PASS, 57 SKIP, 0 FAIL)"
  ```

- [ ] **Implement bootstrap_mediation()** [3-4 hr]
  Location: `R/bootstrap.R` (create new file)
  Guided by: `tests/testthat/test-bootstrap.R` (27 tests)

  Steps:
  1. Create `R/bootstrap.R`
  2. Implement parametric bootstrap (6 tests)
  3. Implement nonparametric bootstrap (5 tests)
  4. Implement plugin method (3 tests)
  5. Add parallel processing support (2 tests)
  6. Verify reproducibility (3 tests)
  7. Remove `skip()` calls from test-bootstrap.R
  8. Run tests: `devtools::test()`

- [ ] **Implement fit_mediation()** [2-3 hr]
  Location: `R/fit-glm.R` (create new file)
  Guided by: `tests/testthat/test-fit-glm.R` (30 tests)

  Steps:
  1. Create `R/fit-glm.R`
  2. Implement basic Gaussian GLM (6 tests)
  3. Add family support (4 tests)
  4. Validate formulas (4 tests)
  5. Handle covariates (2 tests)
  6. Add convergence detection (2 tests)
  7. Remove `skip()` calls from test-fit-glm.R
  8. Run tests: `devtools::test()`

### Medium Priority 🟡

- [ ] **Add roxygen2 documentation** [1-2 hr]
  - [ ] Document bootstrap_mediation()
  - [ ] Document fit_mediation()
  - [ ] Add examples to each
  - [ ] Build docs: `devtools::document()`

- [ ] **Create intro vignette** [2 hr]
  Title: "Getting Started with medfit"
  File: `vignettes/intro-medfit.Rmd`

  Sections:
  - Installation
  - Basic workflow
  - Model fitting with fit_mediation()
  - Bootstrap inference
  - Integration with ecosystem packages

- [ ] **Run R CMD check** [10 min]
  ```r
  devtools::check()
  ```
  Fix any NOTEs, WARNINGs, ERRORs

### Low Priority / Quick Wins ⚡

- [ ] **Update DESCRIPTION** [5 min]
  - Add Authors (including contributors)
  - Update URL and BugReports
  - Review Suggests packages

- [ ] **Setup pkgdown** [15 min]
  ```r
  usethis::use_pkgdown()
  pkgdown::build_site()
  ```

- [ ] **Add NEWS.md entry** [5 min]
  Document test infrastructure addition

---

## 📋 Backlog (Future Sprints)

### Core Functionality

- [ ] Implement SerialMediationData extraction from lavaan
- [ ] Add standardized coefficients option
- [ ] Implement interaction detection (X:M in outcome model)
- [ ] Add four-way decomposition (VanderWeele)

### Testing & Quality

- [ ] Increase test coverage to >90%
- [ ] Add integration tests
- [ ] Setup GitHub Actions CI/CD
- [ ] Add code coverage reporting (codecov)

### Documentation

- [ ] Write "Comparison with mediation package" vignette
- [ ] Write "Extending medfit" vignette (for developers)
- [ ] Create pkgdown website
- [ ] Add FAQ section

### Ecosystem Integration

- [ ] Coordinate with probmed on MediationData API
- [ ] Coordinate with RMediation on BootstrapResult
- [ ] Test integration with medrobust
- [ ] Add examples to each package's vignettes

---

## ✅ Recently Completed

### 2025-12-15 (Afternoon)
- [x] Created COORDINATION-BRAINSTORM.md
  - [x] Analyzed three-package-ecosystem-strategy.md findings
  - [x] Mapped generic functions strategy (extract/fit/bootstrap)
  - [x] Designed CMAverse integration as engine adapter pattern
  - [x] Recommended selective loading for mediationverse (Option 2)
  - [x] Created integration timeline (3 phases)
  - [x] Documented 4 open questions needing decisions
- [x] Created GENERIC-FUNCTIONS-RESEARCH.md
  - [x] Comprehensive comparison of S3, S4, S7, R6, R7 systems
  - [x] Performance benchmarks (S3: 2.59μs, S7: 7.29μs - negligible for medfit)
  - [x] Mixing S7 classes + S3 generics analysis (possible but loses features)
  - [x] Real-world adoption: ggplot2 4.0.0 migrated to S7
  - [x] **DECISION: KEEP S7 generics** (optimal for foundation package)
  - [x] Flexibility for dependent packages documented (all work with S7 classes)

### 2025-12-15 (Morning)
- [x] Created comprehensive test suite (241 tests)
  - [x] test-bootstrap.R (27 tests for bootstrap_mediation)
  - [x] test-fit-glm.R (30 tests for fit_mediation)
  - [x] helper-test-data.R (11 generators, 7 statistic functions)
- [x] All existing tests pass (184 PASS, 0 FAIL)
- [x] Created IDEAS.md
- [x] Created TODOS.md
- [x] Created ECOSYSTEM-COORDINATION.md

### 2025-12-14
- [x] Added .STATUS file for project tracking
- [x] Organized test structure per CLAUDE.md guidelines
- [x] Documented defensive programming patterns

### 2025-12-12
- [x] Created PROJECT-HUB.md for task coordination
- [x] Defined phases in medfit-roadmap.md

### Earlier
- [x] Implemented S7 class system
  - [x] MediationData class
  - [x] SerialMediationData class
  - [x] BootstrapResult class
- [x] Implemented extract_mediation() methods
  - [x] Method for lm/glm
  - [x] Method for lavaan
- [x] Created comprehensive test suite for classes
- [x] Setup package structure
- [x] Recovered package from Google Drive

---

## 🚫 Blocked / Waiting

Currently no blockers! 🎉

---

## 📊 Progress Metrics

### Test Coverage
- **Current:** 184 tests passing
- **Target MVP:** 241 tests passing (57 currently skipped)
- **Target CRAN:** >90% code coverage

### Implementation Progress
- **Phase 1 (Core API):** 40% complete
  - [x] S7 classes
  - [x] extract_mediation (lm/glm, lavaan)
  - [ ] fit_mediation (GLM engine)
  - [ ] bootstrap_mediation (3 methods)

- **Phase 2 (Bootstrap & Tests):** 60% complete
  - [x] Test infrastructure
  - [ ] Implementation
  - [ ] Documentation

- **Phase 3 (CRAN Prep):** 0% complete
  - [ ] Vignettes
  - [ ] pkgdown site
  - [ ] R CMD check passing
  - [ ] Submit to CRAN

### Documentation Progress
- **Function docs:** 60% (classes done, generics need work)
- **Vignettes:** 0% (none written yet)
- **pkgdown site:** 0% (not setup)
- **Examples:** 30% (classes have examples)

---

## 🎯 Sprint Planning

### Current Sprint (Week of Dec 15)
**Goal:** Complete core implementation (fit_mediation + bootstrap_mediation)

**Capacity:** ~10-15 hours
**Committed:**
- Commit test suite (5 min)
- Implement bootstrap_mediation (3-4 hr)
- Implement fit_mediation (2-3 hr)
- Documentation (1-2 hr)
- Testing & fixes (2-3 hr)

**Stretch:**
- Intro vignette (2 hr)
- pkgdown site (15 min)

### Next Sprint (Week of Dec 22)
**Goal:** Documentation and CRAN readiness

**Planned:**
- Complete all vignettes
- Setup pkgdown
- R CMD check --as-cran (pass all checks)
- Integration testing with ecosystem packages

---

## 💡 Notes & Reminders

### Code Style Reminders
- Use snake_case for functions/arguments
- Use CamelCase for S7 classes
- Prefix internal functions with `.`
- Always use checkmate for input validation
- Never use `library()` inside package functions

### Git Workflow
- Commit frequently (small, logical chunks)
- Write descriptive commit messages
- Use conventional commits format:
  - `feat:` new features
  - `fix:` bug fixes
  - `test:` test additions/changes
  - `docs:` documentation
  - `refactor:` code refactoring
  - `chore:` maintenance

### Testing Guidelines
- Test edge cases (NULL, empty, NA)
- Test error conditions
- Use descriptive test names
- Group related tests with comments
- Aim for >90% coverage

### Documentation Checklist
- [ ] All exported functions have @export
- [ ] All parameters documented with @param
- [ ] Return values documented with @return
- [ ] Examples provided with @examples
- [ ] Mathematical notation uses \eqn{} or \deqn{}
- [ ] References cited with @references

---

**Last Updated:** 2025-12-15
**Next Review:** After implementing bootstrap_mediation() and fit_mediation()
