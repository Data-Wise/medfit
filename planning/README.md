# medfit Planning Documents

This directory contains implementation planning for the medfit package.

---

## 📋 Active Documents

### **medfit-roadmap.md** - Implementation Plan
Detailed multi-phase implementation plan for creating medfit MVP and post-MVP features.

**MVP Phases**:
1. Package Setup - COMPLETE
2. S7 Classes - COMPLETE
3. Extraction API - COMPLETE (lm/glm, lavaan)
4. Fitting API (in progress)
5. Bootstrap
6. Testing & Docs
8. Polish & Release

**Post-MVP Phases**:
7. Interaction Support - VanderWeele four-way decomposition
7b. Estimation Engine - User interface, Decomposition class
7c. Engine Adapters - CMAverse integration, external package wrapping

**Use this to**:
- Track implementation progress
- See specific tasks for each phase
- Check success criteria
- Understand architecture decisions

---

### **Code Quality Infrastructure**

The package implements defensive programming best practices:

**Input Validation**:
- **checkmate** package for fast, informative argument assertions
- S7 validators for class-level type safety

**Testing**:
- testthat with 184 tests (0 errors, 0 warnings, 1 skip)
- covr for code coverage tracking
- Snapshot testing for complex outputs

**CI/CD** (GitHub Actions):
- `R-CMD-check.yaml` - Multi-platform R CMD check (r-lib/actions standard)
- `test-coverage.yaml` - Code coverage reporting to Codecov
- `lint.yaml` - Static code analysis with lintr
- `pkgdown.yaml` - Website deployment
- `dependabot.yml` - Automated GitHub Actions updates

**Code Style**:
- `.lintr` configuration for consistent style enforcement
- tidyverse style guide with snake_case naming

---

### **ECOSYSTEM.md** 🔗 Package Connections
Documents connections to probmed, RMediation, and medrobust.

**Use this to**:
- Understand how medfit fits in ecosystem
- Check impact of changes on other packages
- See migration guides for dependent packages
- Coordinate releases

---

## 🗂️ Related Planning Documents

These are in the **probmed/planning/** directory (parent ecosystem):

- **DECISIONS.md** - Key architectural decisions (including medfit)
- **ROADMAP.md** - Overall ecosystem roadmap
- **three-package-ecosystem-strategy.md** - Strategic analysis
- **model-engines-brainstorm.md** - Model engine decisions

---

## 🎯 Quick Start

**Starting medfit development?**
1. Read `medfit-roadmap.md` for implementation plan
2. Read `ECOSYSTEM.md` for ecosystem context
3. Read `../probmed/planning/DECISIONS.md` for key decisions

**Checking impact on other packages?**
1. Read `ECOSYSTEM.md` → "Coordination Points"
2. Check version compatibility matrix
3. Review migration guides

---

**Last Updated**: 2025-12-03
