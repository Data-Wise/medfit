# START HERE: medfit Package

**Created**: 2025-12-02 **Status**: Package skeleton ready,
implementation starting

------------------------------------------------------------------------

## 🎯 What is medfit?

**medfit** is the **foundation package** for the mediation analysis
ecosystem. It provides shared infrastructure (S7 classes, model fitting,
extraction, bootstrap) that eliminates redundancy across three packages:

- **probmed** - P_med (probabilistic effect size)
- **RMediation** - Confidence intervals (DOP, MBCO)
- **medrobust** - Sensitivity analysis

------------------------------------------------------------------------

## 📁 Package Location

    packages/
    ├── medfit/           ← YOU ARE HERE (new foundation package)
    ├── probmed/          ← Will use medfit (phase 2 complete)
    ├── rmediation/       ← Will use medfit (RMediation on CRAN)
    └── medrobust/        ← May use medfit (in development)

------------------------------------------------------------------------

## 📋 Key Documents

### In This Package (medfit/)

1.  **CLAUDE.md** ⭐ Start here for AI assistance

    - Package architecture
    - Coding standards
    - Ecosystem context

2.  **README.md** - Package overview and quick start

3.  **planning/medfit-roadmap.md** - Implementation plan (7 phases, 4-6
    weeks)

4.  **planning/ECOSYSTEM.md** - Connections to other packages

### In Parent Ecosystem (probmed/planning/)

5.  **DECISIONS.md** - All key decisions including:

    - medfit name choice
    - Package ecosystem strategy
    - Model engine decisions

6.  **ROADMAP.md** - Overall ecosystem status and timeline

7.  **three-package-ecosystem-strategy.md** - Detailed strategic
    analysis

------------------------------------------------------------------------

## 🚀 Implementation Roadmap (Summary)

| Phase          | Duration | What Gets Built                |
|----------------|----------|--------------------------------|
| 1\. Setup      | 2-3 days | ✅ DONE - Package skeleton     |
| 2\. S7 Classes | 2-3 days | MediationData, BootstrapResult |
| 3\. Extraction | 3-4 days | extract_mediation() + methods  |
| 4\. Fitting    | 2-3 days | fit_mediation() with GLM       |
| 5\. Bootstrap  | 3-4 days | bootstrap_mediation()          |
| 6\. Testing    | 3-4 days | \>90% coverage + vignettes     |
| 7\. Polish     | 2-3 days | R CMD check + pkgdown          |

**Total**: 4-6 weeks for MVP

------------------------------------------------------------------------

## 🔧 What’s Already Set Up

### ✅ Package Skeleton

- DESCRIPTION with dependencies
- LICENSE (GPL-3)
- README.md with overview
- CLAUDE.md with full documentation
- NEWS.md for changelog
- .Rbuildignore, .gitignore

### ✅ Directory Structure

    medfit/
    ├── CLAUDE.md              ← AI assistance guide
    ├── DESCRIPTION            ← Package metadata
    ├── LICENSE                ← GPL-3
    ├── README.md              ← User guide
    ├── NEWS.md                ← Changelog
    ├── NAMESPACE              ← Auto-generated
    ├── R/                     ← Source code
    │   ├── aaa-imports.R          (imports setup)
    │   ├── medfit-package.R       (package docs)
    │   ├── classes.R              (placeholder)
    │   ├── generics.R             (placeholder)
    │   ├── utils.R                (placeholder)
    │   └── zzz.R                  (placeholder)
    ├── tests/
    │   └── testthat/          ← Test files go here
    ├── man/                   ← Auto-generated docs
    ├── vignettes/             ← User guides
    ├── planning/              ← Implementation plans
    │   ├── medfit-roadmap.md      (7-phase plan)
    │   ├── ECOSYSTEM.md           (connections)
    │   └── README.md              (planning guide)
    └── .github/workflows/     ← CI/CD (to be added)

### ✅ Planning Documents

- Detailed roadmap (7 phases)
- Ecosystem connections documented
- Links to parent ecosystem decisions

------------------------------------------------------------------------

## 🎬 Next Steps

### Immediate (Starting Now)

1.  **Review planning documents**
    - Read `planning/medfit-roadmap.md`
    - Read `planning/ECOSYSTEM.md`
    - Check `../probmed/planning/DECISIONS.md`
2.  **Set up Git repository**
    - Initialize: `git init`
    - Add remote:
      `git remote add origin https://github.com/data-wise/medfit.git`
    - Initial commit
    - Push to GitHub
3.  **Begin Phase 2 (S7 Classes)**
    - Implement `MediationData` class in `R/classes.R`
    - Implement `BootstrapResult` class in `R/classes.R`
    - Add print/summary methods
    - Write tests

### This Week (Phase 1-2)

Git repository set up

GitHub Actions CI/CD configured

S7 classes implemented

Basic tests passing

R CMD check clean

### Next Week (Phase 3-4)

Extraction methods implemented

Fitting API implemented

Tests comprehensive

------------------------------------------------------------------------

## 🔗 Ecosystem Connections

### probmed (Will Import medfit)

**Location**: `../probmed/`

**Current status**: Phase 2 complete (lavaan + mediation integration)

**Will change**: - Replace `probmed::extract_mediation()` with
[`medfit::extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md) -
Replace bootstrap code with
[`medfit::bootstrap_mediation()`](https://data-wise.github.io/medfit/dev/reference/bootstrap_mediation.md) -
Keep P_med computation (unique to probmed)

**Migration**: Planned for Week 6-7 after medfit MVP

### RMediation (Will Import medfit)

**Location**: `../rmediation/`

**Current status**: Stable v1.4.0 on CRAN

**Will change**: - Replace extraction code with
[`medfit::extract_mediation()`](https://data-wise.github.io/medfit/dev/reference/extract_mediation.md) -
Optionally use
[`medfit::bootstrap_mediation()`](https://data-wise.github.io/medfit/dev/reference/bootstrap_mediation.md) -
Keep unique methods (DOP, MBCO, MC)

**Migration**: Planned for Week 8-9 after probmed

### medrobust (May Suggest medfit)

**Location**: `../medrobust/`

**Current status**: v0.1.0.9000 in development

**May change**: - Optionally use medfit for naive estimates - Optionally
use bootstrap utilities

**Migration**: Optional, Week 10

------------------------------------------------------------------------

## 💡 Key Design Decisions (Already Made)

From `../probmed/planning/DECISIONS.md`:

1.  **Package name**: medfit ✅
2.  **Three-package ecosystem**: Foundation + 3 dependents ✅
3.  **S7 everywhere**: Type-safe OOP ✅
4.  **R \>= 4.1.0**: Native pipe support ✅
5.  **GLM first**: Incremental engine support ✅
6.  **\>90% test coverage**: Quality standard ✅

------------------------------------------------------------------------

## 📞 Getting Help

### Documentation

- **This package**: Read CLAUDE.md
- **Ecosystem**: Read `../probmed/planning/DECISIONS.md`
- **Implementation**: Read `planning/medfit-roadmap.md`

### Questions?

- **Strategic**: Review
  `../probmed/planning/three-package-ecosystem-strategy.md`
- **Technical**: Review `planning/medfit-roadmap.md`
- **Connections**: Review `planning/ECOSYSTEM.md`

------------------------------------------------------------------------

## ✅ Checklist for New Session

When starting a new session in medfit:

Read this file (START-HERE.md)

Check current phase in `planning/medfit-roadmap.md`

Review `planning/ECOSYSTEM.md` for package connections

Check `../probmed/planning/ROADMAP.md` for ecosystem status

Review recent decisions in `../probmed/planning/DECISIONS.md`

------------------------------------------------------------------------

## 🎓 Quick Reference

| Need to…                    | Look here                        |
|-----------------------------|----------------------------------|
| Understand medfit           | README.md, CLAUDE.md             |
| See implementation plan     | planning/medfit-roadmap.md       |
| Check ecosystem connections | planning/ECOSYSTEM.md            |
| Review decisions            | ../probmed/planning/DECISIONS.md |
| Check overall status        | ../probmed/planning/ROADMAP.md   |

------------------------------------------------------------------------

**Status**: 📦 Package skeleton complete, ready for Phase 2 (S7 classes)

**Next session**: Start in this directory (`packages/medfit/`), review
CLAUDE.md, begin S7 class implementation

**Remember**: This is the foundation package - focus on clean, efficient
infrastructure. Effect size computation stays in dependent packages.

------------------------------------------------------------------------

**Created**: 2025-12-02 **Last Updated**: 2025-12-02
