# medfit Planning Documents

This directory contains implementation planning for the medfit package.

---

## 📋 Active Documents

### **medfit-roadmap.md** ⭐ Implementation Plan
Detailed multi-phase implementation plan for creating medfit MVP and post-MVP features.

**MVP Phases** (Weeks 1-5):
1. Package Setup ✅
2. S7 Classes ✅
3. Extraction API ✅
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
