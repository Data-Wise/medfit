# TODOS.md - medfit

Active tasks, implementation plan, and progress tracking.

------------------------------------------------------------------------

## 🎯 Current Focus: Test-Driven Development Phase

**Status:** ✅ Test infrastructure complete **Next:** Implement core
functions guided by tests **Updated:** 2025-12-15

------------------------------------------------------------------------

## 🔥 Active Tasks (This Sprint)

### High Priority 🔴

**Update project documentation** \[10 min\] ⚡

Create IDEAS.md

Create TODOS.md

Update .STATUS with test suite milestone

Update PROJECT-HUB.md progress

**Commit test infrastructure** \[5 min\] ⚡

``` bash
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

**Implement bootstrap_mediation()** \[3-4 hr\] Location: `R/bootstrap.R`
(create new file) Guided by: `tests/testthat/test-bootstrap.R` (27
tests)

Steps:

1.  Create `R/bootstrap.R`
2.  Implement parametric bootstrap (6 tests)
3.  Implement nonparametric bootstrap (5 tests)
4.  Implement plugin method (3 tests)
5.  Add parallel processing support (2 tests)
6.  Verify reproducibility (3 tests)
7.  Remove `skip()` calls from test-bootstrap.R
8.  Run tests: `devtools::test()`

**Implement fit_mediation()** \[2-3 hr\] Location: `R/fit-glm.R` (create
new file) Guided by: `tests/testthat/test-fit-glm.R` (30 tests)

Steps:

1.  Create `R/fit-glm.R`
2.  Implement basic Gaussian GLM (6 tests)
3.  Add family support (4 tests)
4.  Validate formulas (4 tests)
5.  Handle covariates (2 tests)
6.  Add convergence detection (2 tests)
7.  Remove `skip()` calls from test-fit-glm.R
8.  Run tests: `devtools::test()`

### Medium Priority 🟡

**Add roxygen2 documentation** \[1-2 hr\]

Document bootstrap_mediation()

Document fit_mediation()

Add examples to each

Build docs: `devtools::document()`

**Create intro vignette** \[2 hr\] Title: “Getting Started with medfit”
File: `vignettes/intro-medfit.Rmd`

Sections:

- Installation
- Basic workflow
- Model fitting with fit_mediation()
- Bootstrap inference
- Integration with ecosystem packages

**Run R CMD check** \[10 min\]

``` r
devtools::check()
```

Fix any NOTEs, WARNINGs, ERRORs

### Low Priority / Quick Wins ⚡

**Update DESCRIPTION** \[5 min\]

- Add Authors (including contributors)
- Update URL and BugReports
- Review Suggests packages

**Setup pkgdown** \[15 min\]

``` r
usethis::use_pkgdown()
pkgdown::build_site()
```

**Add NEWS.md entry** \[5 min\] Document test infrastructure addition

------------------------------------------------------------------------

## 📋 Backlog (Future Sprints)

### Core Functionality

Implement SerialMediationData extraction from lavaan

Add standardized coefficients option

Implement interaction detection (X:M in outcome model)

Add four-way decomposition (VanderWeele)

### Testing & Quality

Increase test coverage to \>90%

Add integration tests

Setup GitHub Actions CI/CD

Add code coverage reporting (codecov)

### Documentation

Write “Comparison with mediation package” vignette

Write “Extending medfit” vignette (for developers)

Create pkgdown website

Add FAQ section

### Ecosystem Integration

Coordinate with probmed on MediationData API

Coordinate with RMediation on BootstrapResult

Test integration with medrobust

Add examples to each package’s vignettes

------------------------------------------------------------------------

## ✅ Recently Completed

### 2025-12-15 (Afternoon)

**Created API-DESIGN-DECISIONS.md** - Consolidated all strategic
planning

Summarized all 8 major decisions (S7, hybrid generics, function naming,
workflow, etc.)

Complete API reference (custom S3 generics + standard R generics +
broom)

Implementation roadmap (6 phases: Core API, Bootstrap, Fit, Broom, Docs,
CMAverse)

Testing strategy (unit tests, integration tests, coverage targets)

Documentation standards (roxygen2, vignettes, pkgdown)

**Strategic planning phase COMPLETE** - ready for implementation

Created COORDINATION-BRAINSTORM.md

Analyzed three-package-ecosystem-strategy.md findings

Mapped generic functions strategy (extract/fit/bootstrap)

Designed CMAverse integration as engine adapter pattern

Recommended selective loading for mediationverse (Option 2)

Created integration timeline (3 phases)

Documented 4 open questions needing decisions

Created GENERIC-FUNCTIONS-RESEARCH.md

Comprehensive comparison of S3, S4, S7, R6, R7 systems

Performance benchmarks (S3: 2.59μs, S7: 7.29μs - negligible for medfit)

Mixing S7 classes + S3 generics analysis (possible but loses features)

Real-world adoption: ggplot2 4.0.0 migrated to S7

**DECISION: KEEP S7 generics** (optimal for foundation package)

Flexibility for dependent packages documented (all work with S7 classes)

Created GENERIC-NAMING-STRATEGY.md

Researched base R standard generics (confint, coef, vcov, etc.)

Analyzed lavaan (hybrid approach), CMAverse (custom only), broom
patterns

Compared 4 strategic options (standard only, custom only, hybrid,
prefixed)

**DECISION: Use confint() not ci()** (hybrid approach recommended)

Standard generics for standard ops + custom S7 for mediation-specific

4-phase implementation roadmap with code examples

Ecosystem integration benefits (broom, sandwich, car, lmtest, emmeans)

Created ADHD-FRIENDLY-WORKFLOW.md

Analyzed ADHD challenges (working memory, decision fatigue, flow state)

Compared 6 workflow alternatives (pipe-first, single-function, builder,
etc.)

**RECOMMENDATION: Alternative 6 (Hybrid)** - short verbs + pipes +
standard generics

Proposed mediate() + boot() + confint() pattern (revised from med())

Smart defaults minimize decisions (parametric, 1000, 95% CI)

Pipeline maintains flow state (no context switching)

Complete examples and migration strategy

Clarified S7+S3 generics pattern (NO namespace conflicts)

Created FUNCTION-NAMING-DEEP-DIVE.md

Detailed explanation of med() function (fits + extracts)

Compared 6 alternatives (mediate, fit_med, medfit, estimate, etc.)

**RECOMMENDATION: mediate()** instead of med() (clearer verb, no
ambiguity)

Explained paths() function (mediation structure extraction)

Compared to coef() (all params vs just paths)

**RECOMMENDATION: Keep paths()** (short, clear, no conflicts)

### 2025-12-15 (Morning)

Created comprehensive test suite (241 tests)

test-bootstrap.R (27 tests for bootstrap_mediation)

test-fit-glm.R (30 tests for fit_mediation)

helper-test-data.R (11 generators, 7 statistic functions)

All existing tests pass (184 PASS, 0 FAIL)

Created IDEAS.md

Created TODOS.md

Created ECOSYSTEM-COORDINATION.md

### 2025-12-14

Added .STATUS file for project tracking

Organized test structure per CLAUDE.md guidelines

Documented defensive programming patterns

### 2025-12-12

Created PROJECT-HUB.md for task coordination

Defined phases in medfit-roadmap.md

### Earlier

Implemented S7 class system

MediationData class

SerialMediationData class

BootstrapResult class

Implemented extract_mediation() methods

Method for lm/glm

Method for lavaan

Created comprehensive test suite for classes

Setup package structure

Recovered package from Google Drive

------------------------------------------------------------------------

## 🚫 Blocked / Waiting

Currently no blockers! 🎉

------------------------------------------------------------------------

## 📊 Progress Metrics

### Test Coverage

- **Current:** 184 tests passing
- **Target MVP:** 241 tests passing (57 currently skipped)
- **Target CRAN:** \>90% code coverage

### Implementation Progress

**Phase 1 (Core API):** 40% complete

S7 classes

extract_mediation (lm/glm, lavaan)

fit_mediation (GLM engine)

bootstrap_mediation (3 methods)

**Phase 2 (Bootstrap & Tests):** 60% complete

Test infrastructure

Implementation

Documentation

**Phase 3 (CRAN Prep):** 0% complete

Vignettes

pkgdown site

R CMD check passing

Submit to CRAN

### Documentation Progress

- **Function docs:** 60% (classes done, generics need work)
- **Vignettes:** 0% (none written yet)
- **pkgdown site:** 0% (not setup)
- **Examples:** 30% (classes have examples)

------------------------------------------------------------------------

## 🎯 Sprint Planning

### Current Sprint (Week of Dec 15)

**Goal:** Complete core implementation (fit_mediation +
bootstrap_mediation)

**Capacity:** ~10-15 hours **Committed:** - Commit test suite (5 min) -
Implement bootstrap_mediation (3-4 hr) - Implement fit_mediation (2-3
hr) - Documentation (1-2 hr) - Testing & fixes (2-3 hr)

**Stretch:** - Intro vignette (2 hr) - pkgdown site (15 min)

### Next Sprint (Week of Dec 22)

**Goal:** Documentation and CRAN readiness

**Planned:** - Complete all vignettes - Setup pkgdown - R CMD check
–as-cran (pass all checks) - Integration testing with ecosystem packages

------------------------------------------------------------------------

## 💡 Notes & Reminders

### Code Style Reminders

- Use snake_case for functions/arguments
- Use CamelCase for S7 classes
- Prefix internal functions with `.`
- Always use checkmate for input validation
- Never use [`library()`](https://rdrr.io/r/base/library.html) inside
  package functions

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
- Aim for \>90% coverage

### Documentation Checklist

All exported functions have @export

All parameters documented with @param

Return values documented with @return

Examples provided with @examples

Mathematical notation uses or

References cited with @references

------------------------------------------------------------------------

**Last Updated:** 2025-12-15 **Next Review:** After implementing
bootstrap_mediation() and fit_mediation()
