# 🎯 medfit - Project Control Hub

> **Quick Status:** 🟢 Feature-complete | **CRAN:** 0.3.2 accepted (2026-07-23) | **main:** 0.5.0 (GitHub + r-universe, 2026-09-25)

**Last Updated:** 2026-09-25  
**Current Phase:** 0.5.0 released on main/GitHub/r-universe (tag `v0.5.0`, #84); CRAN still 0.3.2 (known bugs in pinned #83)  
**Next Action:** Plan Ext D module 1 (2-1-1 multilevel; spec approved 2026-09-25). Next CRAN trigger is open. probmed Stage 2 lives in probmed

> **Ecosystem-wide planning** (roadmap, coordination, API/naming design, manifest)
> lives in the hub: `~/projects/r-packages/mediation-planning/` (start at
> `PROJECT-HUB.md`). This file tracks **medfit only**. Live ecosystem status:
> `cd ~/projects/r-packages && /rforge:status`.

---

## 🎯 Quick Reference

| What | Status | Link/Location |
|------|--------|---------------|
| **Package Files** | 🟢 | ~/projects/r-packages/active/medfit/ |
| **Documentation** | 🟢 | man/, vignettes/articles/ (5 articles, evaluated at site build) |
| **Tests** | 🟢 | tests/testthat/ (1546 expectations at the 0.5.0 release gate) |
| **Repository** | 🟢 | github.com/Data-Wise/medfit |

---

## 📊 Overall Progress

```
Phase 1: Core API                ████████████████████ 100% 🟢
Phase 2: Bootstrap & Tests       ████████████████████ 100% 🟢
Phase 3: CRAN Preparation        ████████████████████ 100% 🟢
Phase 4: Extensions (A/B/C, 0.4.0) ████████████████████ 100% 🟢
Phase 5: D8(b) + fixes           ████████████████████ 100% 🟢
Phase 6: 0.5.0 release           ████████████████████ 100% 🟢
──────────────────────────────────────────────────────────
Features (Phases 1-5):            ████████████████████ 100% 🟢
```

**Status:** 🟢 0.5.0 released (GitHub-only) | **Priority:** P1 (next: Ext D module-1 plan)

---

## ✅ Completed Recently

### Since 0.4.0 (released in 0.5.0; merged 2026-09-23/24)
- [x] ✅ `mediation_demo` dataset; examples and articles moved to it (#62-#65, #67)
- [x] ✅ Delta-method effect SEs in `tidy()`/`confint()` for all classes; lavaan alias, wrapped-product, `vcov_fun`, identity-link and `m_star` fixes (#69-#75)
- [x] ✅ D8(b) `JointMediationData` + `joint_effects()` (#76, #77)
- [x] ✅ Methods and Formulas article + doc gap fixes (#79)
- [x] ✅ Four-way factor covariates (#78); joint SEs with `data =` (#80)
- [x] ✅ Behavior changes: serial total effect (#81); `confint()` path alias lookup (#82)

### Releases
- [x] ✅ 0.2.1 accepted on CRAN (2026-06-18)
- [x] ✅ 0.3.2 accepted + published on CRAN (2026-07-23)
- [x] ✅ 0.4.0 tagged + GitHub release (2026-08-23): Ext A/B/C

### Package Recovery
- [x] ✅ Recovered from Google Drive trash (2025-12-12)
- [x] ✅ Git history preserved
- [x] ✅ Package loads without errors
- [x] ✅ Organized in active/ directory

### Planning
- [x] ✅ Generic Functions Strategy documented
- [x] ✅ API contracts defined
- [x] ✅ S7 class structure planned

---

## 🎯 Active Tasks (This Week)

### High Priority 🔴
- [x] 0.5.0 release — GitHub + r-universe, 2026-09-25 (#84, tag `v0.5.0`; checklist in `TODOS.md`)
- [x] Ext D (multilevel) module-1 spec — approved 2026-09-25, `specs/SPEC-multilevel-mediation-2-1-1-2026-09-25.md`
- [ ] Ext D module-1 plan (PRs A extract, B fit engine, C cluster bootstrap)

### Medium Priority 🟡
- [ ] Decide the next CRAN trigger (open in `specs/GRILL-0.5.0-release-2026-09-24.md`)

### Done (original skeleton tasks)
- [x] fit_mediation() with GLM engine, validation, S7 return
- [x] S7 class structure with print/summary/coef methods
- [x] Unit tests and documentation for fit_mediation()
- [x] DESCRIPTION and pkgdown site

---

## 🚀 Quick Commands

### Development
```bash
$ cd ~/projects/r-packages/active/medfit
$ ccload          # Load package with devtools
$ cccheck         # Run R CMD check
$ cctest          # Run tests
```

### Documentation
```bash
$ ccrdoc          # Build documentation
$ ccman           # View manual
$ ccvignette      # Preview vignettes
```

### Testing
```bash
$ ccrtest         # Run all tests
$ ccrtest file    # Run specific test file
$ ccrcov          # Check test coverage
```

---

## 🎯 Decision Point: What's Next?

**Choose your focus:**

### Option A: Plan and build Ext D module 1 (2-1-1 multilevel mediation) ⭐ Recommended
```
Goal: ClusterMediationData from cluster-mean-centered lmer fits (cluster-level treatment)
Spec: specs/SPEC-multilevel-mediation-2-1-1-2026-09-25.md (approved; decisions D1-D16)
```
**Why:** Spec approved and adversarially reviewed; 1-1-1 designs are module 2

---

### Option B: Plan the next CRAN release
```
Goal: Carry 0.5.0's fixes to CRAN (0.3.2 still has the serial te()/pm() and confint() bugs, #83)
```
**Why:** Only when a trigger fires (probmed needing >= 0.4.0 on CRAN, or a user report)

---

**Your choice:** ___

---

## 🔴 Blockers & Dependencies

### Current Blockers
- None for medfit. Ext C.1 (CMAverse) is blocked: not on CRAN, and its simulation-based effects have no slot

### Dependencies (on medfit)
- probmed - Imports medfit (>= 0.3.0)
- RMediation - Suggests medfit (>= 0.2.0)
- medsim - Suggests medfit (>= 0.2.0)
- mediationverse - Imports medfit (>= 0.2.0)
- medrobust - does not depend on medfit
- A CRAN dependent that needs the regmedint engine or `m_star` needs medfit >= 0.4.0 on CRAN

---

## 📋 Phase Details

### Phase 1: Core API Implementation 🟢 COMPLETE
**Goal:** Working fit_mediation() with basic functionality  
**Duration:** 2-3 weeks  
**Status:** 100% complete

**Critical Path Tasks:**
- [x] fit_mediation() skeleton
- [x] GLM engine implementation
- [x] S7 class structure
- [x] Parameter validation
- [x] Basic tests
- [x] Documentation

---

### Phase 2: Bootstrap & Testing 🟢 COMPLETE
**Goal:** Robust bootstrap_mediation() + comprehensive tests  
**Duration:** 2-3 weeks  
**Status:** 100% complete

**Tasks:**
- [x] bootstrap_mediation() implementation (parametric, nonparametric, plugin; all classes for parametric/plugin)
- [x] Comprehensive test suite
- [x] Edge case handling
- [x] Performance optimization (parallel bootstrap)

---

### Phase 3: CRAN Preparation 🟢 COMPLETE
**Goal:** CRAN-ready package  
**Duration:** 1-2 weeks  
**Status:** 0.3.2 on CRAN (2026-07-23)

**Tasks:**
- [x] R CMD check --as-cran passes
- [x] Vignettes complete
- [x] NEWS.md updated
- [x] Submit to CRAN

---

### Phase 4: Extensions A/B/C 🟢 COMPLETE
**Status:** Parallel (Ext A), four-way interaction (Ext B), regmedint engine (Ext C); released as 0.4.0 on GitHub (2026-08-23)

---

### Phase 5: D8(b) + post-0.4.0 fixes 🟢 COMPLETE (released in 0.5.0)
**Status:** #62-#82 merged to dev; see "Completed Recently"

---

### Phase 6: 0.5.0 Release 🟢 COMPLETE (2026-09-25)
**Goal:** Release the dev work since 0.4.0  
**Status:** GitHub-only by decision (`specs/GRILL-0.5.0-release-2026-09-24.md`); #84 → `4cb0550`, tag `v0.5.0`, r-universe 0.5.0

---

## 🎉 Celebration Checklist

**Package recovery complete!**
- [x] ✅ All files recovered from trash
- [x] ✅ Git history intact
- [x] ✅ Package structure valid
- [x] ✅ Ready for development

**Planning complete!**
- [x] ✅ Generic Functions Strategy documented
- [x] ✅ API contracts defined
- [x] ✅ Dependencies mapped

**That's solid foundation work! 🎉**

**On CRAN!**
- [x] ✅ 0.2.1 accepted (2026-06-18)
- [x] ✅ 0.3.2 accepted + published (2026-07-23)

---

## 📊 Metrics & Stats

### Package Stats
- **R Files:** 18
- **Exports:** 18 in NAMESPACE (6 classes + 12 functions), plus S3/S7 methods
- **Tests:** 1546 expectations (recorded at the 0.5.0 release gate)
- **Documentation:** all exports documented; 5 articles

### Dependencies
- **Depends:** R (>= 4.1.0)
- **Imports:** S7, stats, methods, checkmate, generics, MASS
- **Suggests:** lavaan, regmedint, sandwich, testthat, tibble

---

## 📞 Quick Links

| Resource | Link |
|----------|------|
| **GitHub Repo** | [Data-Wise/medfit](https://github.com/Data-Wise/medfit) |
| **Generic Functions Strategy** | ~/projects/r-packages/mediation-planning/specs/GENERIC-FUNCTIONS-STRATEGY.md |
| **API Contracts** | ~/projects/r-packages/mediation-planning/specs/API-CONTRACTS.md |
| **PROJECT-BOARD** | ~/projects/r-packages/PROJECT-BOARD.md |

---

## 🗂️ File Directory

| Path | Purpose | Status |
|------|---------|--------|
| `R/fit-glm.R`, `R/fit-regmedint.R` | Fitting (GLM and regmedint engines) | 🟢 Done |
| `R/extract-lm.R`, `R/extract-joint.R`, `R/extract-lavaan.R` | Extraction | 🟢 Done |
| `R/bootstrap.R` | Bootstrap implementation | 🟢 Done |
| `R/classes.R` | S7 class definitions | 🟢 Done |
| `R/methods-base.R`, `R/methods-tidy.R`, `R/generics-effects.R`, `R/effect-se.R` | S7 methods, effects, delta-method SEs | 🟢 Done |
| `R/utils.R` | Utility functions | 🟢 Done |
| `tests/testthat/` | Test suite | 🟢 Done |
| `vignettes/articles/` | Package articles | 🟢 Done |

---

## 🐛 Troubleshooting

| Problem | Quick Fix | Command |
|---------|-----------|---------|
| Package won't load | Check NAMESPACE | `$ cccheck` |
| Tests failing | Run individual tests | `$ ccrtest file` |
| Documentation outdated | Rebuild docs | `$ ccrdoc` |
| R CMD check errors | See check output | `$ cccheck` |

---

## 🔄 Update Log

### 2026-09-24 - D8(b) and post-0.4.0 fixes on dev
- `JointMediationData`, effect SEs for all classes, `mediation_demo`, Methods and Formulas article (#62-#82)
- Two behavior changes (#81, #82); released in 0.5.0 (2026-09-25)

### 2026-08-23 - 0.4.0 on GitHub
- Ext C (regmedint engine) + `m_star` argument; tag `v0.4.0`

### 2026-07-23 - 0.3.2 on CRAN

### 2025-12-12 - Package Recovered
- Recovered all files from Google Drive trash
- Verified package structure
- Added to active/ directory
- Ready for development

### 2025-12-12 - Planning Complete
- Generic Functions Strategy documented
- API contracts defined
- Dependencies mapped

---

## 🎯 Long-Term Vision

### Goals
1. **Foundation for ecosystem** - medfit powers all mediation packages
2. **Modern R practices** - S7 classes, tidyverse-compatible, native pipe
3. **Publication quality** - Companion to methodology papers

### Success Criteria
- [x] On CRAN with 0 ERRORs, 0 WARNINGs
- [ ] Used by probmed, medrobust, medsim (probmed and medsim yes; medrobust no)
- [ ] Downloaded >1000 times/month
- [ ] Cited in research papers

---

**Status:** 🟢 0.5.0 released (GitHub-only)  
**Last Updated:** 2026-09-25  
**Next Review:** After the Ext D module-1 plan
