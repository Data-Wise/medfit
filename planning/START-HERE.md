# START HERE: medfit Package

**Created**: 2025-12-02
**Status**: 0.3.2 on CRAN; 0.5.0 on main/GitHub/r-universe (released 2026-09-25, tag `v0.5.0`)

---

## 🎯 What is medfit?

**medfit** is the **foundation package** for the mediation analysis ecosystem. It provides shared infrastructure (S7 classes, model fitting, extraction, bootstrap) that eliminates redundancy across three packages:

- **probmed** - P_med (probabilistic effect size)
- **RMediation** - Confidence intervals (DOP, MBCO)
- **medrobust** - Sensitivity analysis

---

## 📁 Package Location

```
~/projects/r-packages/active/
├── medfit/           ← YOU ARE HERE (foundation package; 0.3.2 on CRAN)
├── probmed/          ← Imports medfit (>= 0.3.0)
├── rmediation/       ← Suggests medfit (>= 0.2.0); RMediation on CRAN
├── medrobust/        ← Does not depend on medfit
├── medsim/           ← Suggests medfit (>= 0.2.0)
└── mediationverse/   ← Meta-package; Imports medfit (>= 0.2.0)
```

---

## 📋 Key Documents

### In This Package (medfit/)

1. **CLAUDE.md** ⭐ Start here for AI assistance
   - Package architecture
   - Coding standards
   - Ecosystem context

2. **README.md** - Package overview and quick start

3. **.STATUS** - Current state and per-PR record (source of truth)

4. **planning/TODOS.md** - Active tasks, including the 0.5.0 release checklist

5. **planning/EXTENSIONS-PLAN-2026-06-03.md** - Prioritized extensions board

6. **planning/medfit-roadmap.md** - Original phase plan (all phases complete) and design reference

7. **planning/ECOSYSTEM.md** - Connections to other packages

### In Parent Ecosystem (probmed/planning/)

8. **DECISIONS.md** - All key decisions including:
   - medfit name choice
   - Package ecosystem strategy
   - Model engine decisions

9. **ROADMAP.md** - Overall ecosystem status and timeline

10. **three-package-ecosystem-strategy.md** - Detailed strategic analysis

Ecosystem-wide planning now lives in `~/projects/r-packages/mediation-planning/` (start at `PROJECT-HUB.md`).

---

## 🚀 Implementation Roadmap (Summary)

| Phase | Duration | What Gets Built |
|-------|----------|-----------------|
| 1. Setup | 2-3 days | ✅ DONE - Package skeleton |
| 2. S7 Classes | 2-3 days | ✅ DONE - MediationData, SerialMediationData, BootstrapResult |
| 3. Extraction | 3-4 days | ✅ DONE - extract_mediation() for lm/glm and lavaan |
| 4. Fitting | 2-3 days | ✅ DONE - fit_mediation() with GLM (+ regmedint engine, 0.4.0) |
| 5. Bootstrap | 3-4 days | ✅ DONE - bootstrap_mediation() |
| 6. Testing | 3-4 days | ✅ DONE - tests + vignettes |
| 7. Polish | 2-3 days | ✅ DONE - R CMD check + pkgdown; 0.3.2 on CRAN |

**Total**: MVP shipped. Since then: parallel (Ext A), four-way interaction (Ext B), regmedint engine (Ext C) in 0.4.0; `JointMediationData`, effect SEs for all classes and `mediation_demo` on `dev`.

---

## 🔧 What's Already Set Up

### ✅ Package Skeleton
- DESCRIPTION with dependencies
- LICENSE (GPL-3)
- README.md with overview
- CLAUDE.md with full documentation
- NEWS.md for changelog
- .Rbuildignore, .gitignore

### ✅ Directory Structure
```
medfit/
├── CLAUDE.md              ← AI assistance guide
├── DESCRIPTION            ← Package metadata
├── LICENSE                ← GPL-3
├── README.md              ← User guide
├── NEWS.md                ← Changelog
├── NAMESPACE              ← Auto-generated
├── R/                     ← Source code
│   ├── aaa-imports.R          (imports setup)
│   ├── aab-generics.R         (S7 generics)
│   ├── medfit-package.R       (package docs)
│   ├── classes.R              (S7 classes, incl. Parallel/Interaction/Joint)
│   ├── data.R                 (mediation_demo docs)
│   ├── extract-lm.R           (lm/glm extraction)
│   ├── extract-joint.R        (joint multi-mediator X:M extraction)
│   ├── extract-lavaan.R       (lavaan extraction)
│   ├── fit-glm.R              (fit_mediation(), GLM engine)
│   ├── fit-regmedint.R        (regmedint engine)
│   ├── bootstrap.R            (bootstrap_mediation())
│   ├── effect-se.R            (delta-method effect SEs)
│   ├── generics-effects.R     (nie/nde/te/pm/paths/decompose)
│   ├── methods-base.R         (print/summary/coef/vcov/confint/nobs)
│   ├── methods-tidy.R         (tidy/glance)
│   ├── med.R                  (med(), quick())
│   ├── utils.R
│   └── zzz.R                  (.onLoad registration)
├── data/ + data-raw/      ← mediation_demo and its generating script
├── tests/
│   └── testthat/          ← Test suite
├── man/                   ← Auto-generated docs
├── vignettes/articles/    ← 5 Quarto articles (evaluated at site build)
├── planning/              ← Plans, specs, status docs
│   ├── medfit-roadmap.md      (phase plan + design reference)
│   ├── EXTENSIONS-PLAN-2026-06-03.md (current board)
│   ├── TODOS.md               (active tasks)
│   ├── ECOSYSTEM.md           (connections)
│   └── README.md              (planning guide)
└── .github/workflows/     ← CI/CD (R-CMD-check, coverage, pkgdown)
```

### ✅ Planning Documents
- Detailed roadmap (7 phases, all complete)
- Extensions board, specs and grill ledgers in `planning/specs/`
- Ecosystem connections documented
- Links to parent ecosystem decisions

---

## 🎬 Next Steps

### Immediate

1. **Ext D (multilevel) spec** — see `planning/specs/BRAINSTORM-medfit-mediationverse-next-features-2026-08-22.md`.
   0.5.0 shipped 2026-09-25 (GitHub-only); the next CRAN trigger is open
   (`planning/specs/GRILL-0.5.0-release-2026-09-24.md`)

2. **After 0.5.0**
   - Ext D (multilevel) spec — see `planning/specs/BRAINSTORM-medfit-mediationverse-next-features-2026-08-22.md`
   - Ext C.1 (CMAverse) stays blocked

### Done (Phases 1-4)

- [x] Git repository set up
- [x] GitHub Actions CI/CD configured
- [x] S7 classes implemented
- [x] Basic tests passing
- [x] R CMD check clean
- [x] Extraction methods implemented
- [x] Fitting API implemented
- [x] Tests comprehensive

---

## 🔗 Ecosystem Connections

### probmed (Imports medfit)

**Location**: `../probmed/`

**Current status**: `Imports: medfit (>= 0.3.0)`; its CRAN prep (Stage 2) is tracked in probmed

**Changes planned at the start**:
- Replace `probmed::extract_mediation()` with `medfit::extract_mediation()`
- Replace bootstrap code with `medfit::bootstrap_mediation()`
- Keep P_med computation (unique to probmed)

**Migration**: Done on the medfit side; probmed calls `extract_mediation()`

### RMediation (Suggests medfit)

**Location**: `../rmediation/`

**Current status**: 1.6.1 on CRAN (2026-07-21); `Suggests: medfit (>= 0.2.0)`

**Changes planned at the start**:
- Replace extraction code with `medfit::extract_mediation()`
- Optionally use `medfit::bootstrap_mediation()`
- Keep unique methods (DOP, MBCO, MC)

**Migration**: Suggests-level; its serial `ci()` reads `@a_path`, `@d_path`, `@b_path`

### medrobust (May Suggest medfit)

**Location**: `../medrobust/`

**Current status**: 0.4.2; does not list medfit in DESCRIPTION. CRAN prep on hold pending its manuscript

**May change**:
- Optionally use medfit for naive estimates
- Optionally use bootstrap utilities

**Migration**: Optional, Week 10

---

## 💡 Key Design Decisions (Already Made)

From `../probmed/planning/DECISIONS.md`:

1. **Package name**: medfit ✅
2. **Three-package ecosystem**: Foundation + 3 dependents ✅
3. **S7 everywhere**: Type-safe OOP ✅
4. **R >= 4.1.0**: Native pipe support ✅
5. **GLM first**: Incremental engine support ✅
6. **>90% test coverage**: Quality standard ✅

---

## 📞 Getting Help

### Documentation
- **This package**: Read CLAUDE.md
- **Ecosystem**: Read `../probmed/planning/DECISIONS.md`
- **Implementation**: Read `planning/medfit-roadmap.md`

### Questions?
- **Strategic**: Review `../probmed/planning/three-package-ecosystem-strategy.md`
- **Technical**: Review `planning/medfit-roadmap.md`
- **Connections**: Review `planning/ECOSYSTEM.md`

---

## ✅ Checklist for New Session

When starting a new session in medfit:

- [ ] Read this file (START-HERE.md)
- [ ] Read `.STATUS` (`next:` line) and `planning/TODOS.md`
- [ ] Check the board in `planning/EXTENSIONS-PLAN-2026-06-03.md`
- [ ] Review `planning/ECOSYSTEM.md` for package connections
- [ ] Check `../probmed/planning/ROADMAP.md` for ecosystem status
- [ ] Review recent decisions in `../probmed/planning/DECISIONS.md`

---

## 🎓 Quick Reference

| Need to... | Look here |
|------------|-----------|
| Understand medfit | README.md, CLAUDE.md |
| See current tasks | .STATUS, planning/TODOS.md |
| See implementation plan | planning/medfit-roadmap.md |
| Check ecosystem connections | planning/ECOSYSTEM.md |
| Review decisions | ../probmed/planning/DECISIONS.md |
| Check overall status | ../probmed/planning/ROADMAP.md |

---

**Status**: 📦 0.3.2 on CRAN, 0.4.0 on GitHub, `dev` ready for the proposed 0.5.0 release

**Next session**: Start in this directory (`~/projects/r-packages/active/medfit/`), read `.STATUS` and `planning/TODOS.md`

**Remember**: This is the foundation package - focus on clean, efficient infrastructure. Effect size computation stays in dependent packages.

---

**Created**: 2025-12-02
**Last Updated**: 2026-09-24
