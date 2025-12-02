# medfit Ecosystem Connections

**Last Updated**: 2025-12-02

This document tracks the connections between medfit and its dependent packages.

---

## Package Locations

All packages are located in the parent `packages/` directory:

```
packages/
├── medfit/           ← THIS PACKAGE (foundation)
├── probmed/          ← Will import medfit
├── rmediation/       ← Will import medfit (RMediation on CRAN)
└── medrobust/        ← Will suggest medfit
```

---

## Dependency Graph

```
medfit (foundation)
├── Provides: MediationData, BootstrapResult classes
├── Provides: fit_mediation(), extract_mediation(), bootstrap_mediation()
└── Engines: GLM (MVP), lmer (future), brms (future)

         ↓ (imports medfit)

probmed (v0.1.0)
├── Uses: medfit extraction, bootstrap
├── Adds: P_med computation
├── Status: ✅ Phase 2 complete, ready for integration
└── Location: ../probmed/

RMediation (v1.4.0)
├── Uses: medfit extraction (lavaan, OpenMx)
├── Adds: DOP, MBCO, MC methods
├── Status: ✅ Stable on CRAN
└── Location: ../rmediation/

medrobust (v0.1.0.9000)
├── Uses: medfit (optional) for naive estimates
├── Adds: Bounds, falsification, sensitivity
├── Status: 🔄 In development
└── Location: ../medrobust/
```

---

## Shared Planning Documents

Key strategic documents are in **probmed/planning/**:

- **DECISIONS.md** - All major decisions (medfit name, architecture, etc.)
- **ROADMAP.md** - Overall ecosystem roadmap
- **three-package-ecosystem-strategy.md** - Detailed strategic analysis
- **model-engines-brainstorm.md** - Model engine decisions

**medfit-specific**:
- **planning/medfit-roadmap.md** - This package's implementation plan
- **planning/ECOSYSTEM.md** - This file (connections to other packages)

---

## Integration Timeline

### Phase 1: medfit Creation (Weeks 1-5)
**Status**: 🔄 In Progress
- [ ] Package skeleton (Week 1)
- [ ] S7 classes (Week 1-2)
- [ ] Extraction methods (Week 2)
- [ ] Fitting API (Week 2-3)
- [ ] Bootstrap (Week 3-4)
- [ ] Testing & docs (Week 4)
- [ ] Polish (Week 5)

### Phase 2: probmed Integration (Week 6-7)
**Status**: ⏳ Pending medfit completion
- [ ] Add medfit to DESCRIPTION (Imports)
- [ ] Replace extraction code
- [ ] Replace bootstrap code
- [ ] Verify backward compatibility
- [ ] Update tests
- [ ] Update documentation

### Phase 3: RMediation Integration (Week 8-9)
**Status**: ⏳ Pending probmed integration
- [ ] Add medfit to DESCRIPTION (Imports)
- [ ] Replace extraction code
- [ ] Use bootstrap utilities where appropriate
- [ ] Update tests
- [ ] Update documentation

### Phase 4: medrobust Integration (Week 10)
**Status**: ⏳ Optional
- [ ] Add medfit to DESCRIPTION (Suggests)
- [ ] Use for naive estimates if beneficial
- [ ] Update documentation

---

## API Compatibility

### What medfit Provides

**Classes**:
```r
MediationData       # Replaces probmed's MediationExtract
BootstrapResult     # New, standardized bootstrap results
```

**Functions**:
```r
fit_mediation()         # New, GLM fitting
extract_mediation()     # Replaces probmed's extract_mediation()
bootstrap_mediation()   # New, unified bootstrap
```

### Migration Guide for probmed

**Before** (probmed v0.1.0):
```r
# probmed code
extract <- extract_mediation(fit, ...)  # probmed's version
result <- .pmed_parametric_boot(...)     # internal function
```

**After** (probmed v0.2.0 with medfit):
```r
# medfit provides infrastructure
library(medfit)
extract <- medfit::extract_mediation(fit, ...)  # medfit's version
boot <- medfit::bootstrap_mediation(...)         # medfit's version

# probmed focuses on P_med
pmed_value <- compute_pmed(extract)  # probmed-specific
```

### Migration Guide for RMediation

**Before** (RMediation v1.4.0):
```r
# RMediation extracts from lavaan internally
ci(lavaan_fit, ...)  # custom extraction code
```

**After** (RMediation v1.5.0 with medfit):
```r
# medfit handles extraction
library(medfit)
extract <- medfit::extract_mediation(lavaan_fit, ...)
ci(extract, type = "dop", ...)  # RMediation-specific
```

---

## Coordination Points

### When Changing S7 Classes

**If changing MediationData**:
1. Check probmed uses (affects MediationExtract subclass)
2. Check RMediation uses (if any)
3. Update all three packages simultaneously
4. Bump major version (breaking change)

**If changing BootstrapResult**:
1. Check all uses in probmed
2. Update simultaneously
3. Bump major version if breaking

### When Changing APIs

**If changing extract_mediation()**:
1. Check probmed's formula interface
2. Check RMediation's uses
3. Maintain backward compatibility if possible
4. Document changes in NEWS.md

**If changing bootstrap_mediation()**:
1. Check probmed's bootstrap methods
2. Check medrobust's uses (if any)
3. Maintain backward compatibility
4. Document changes

### When Adding Features

**New model engines** (lmer, brms):
- Announce in all packages
- Update documentation in all packages
- Consider if dependent packages need updates

**New extraction methods**:
- Announce in all packages
- Document in medfit and dependent packages
- Provide migration guide if needed

---

## Testing Coordination

### Cross-Package Tests

**When developing medfit**:
- Test with probmed's existing code
- Test with RMediation's patterns
- Ensure no breaking changes

**Integration tests**:
- Located in each package's test suite
- Test medfit → probmed interface
- Test medfit → RMediation interface

### Continuous Integration

**medfit CI/CD**:
- Tests run on push
- Coverage reporting
- R CMD check multi-platform

**Dependent packages**:
- Watch for medfit changes
- Re-run tests when medfit updates
- Coordinate releases

---

## Version Compatibility Matrix

| medfit | probmed | RMediation | medrobust | Notes |
|--------|---------|------------|-----------|-------|
| 0.1.0  | 0.2.0+  | 1.5.0+     | 0.2.0+    | First integration |
| 0.2.0  | 0.3.0+  | 1.6.0+     | 0.3.0+    | lmer engine added |
| 1.0.0  | 1.0.0+  | 2.0.0+     | 1.0.0+    | Stable API |

**Versioning policy**:
- **medfit** changes trigger version bumps in dependent packages
- **Major** medfit changes → Major version bumps in dependents
- **Minor** medfit changes → Minor version bumps in dependents
- **Patch** medfit changes → Optional updates in dependents

---

## Communication Channels

### During Development

**Discuss changes**:
- Via planning documents (DECISIONS.md, ROADMAP.md)
- Update ECOSYSTEM.md when architecture changes
- Document breaking changes prominently

**Coordinate releases**:
- Announce medfit releases early
- Give dependent packages time to update
- Coordinate CRAN submissions

### Documentation

**medfit changes**:
- Document in medfit NEWS.md
- Update dependent packages' CLAUDE.md files
- Update ecosystem strategy document

**Dependent package changes**:
- Note if they require specific medfit version
- Document in their NEWS.md
- Update ECOSYSTEM.md if architecture changes

---

## File System Connections

### Shared Documentation

**Planning documents** (in probmed/planning/):
- DECISIONS.md
- ROADMAP.md
- three-package-ecosystem-strategy.md
- model-engines-brainstorm.md

**Package-specific** (in each package):
- CLAUDE.md (references ecosystem)
- planning/ directory (package-specific plans)

### Cross-References

**In medfit**:
- CLAUDE.md → References probmed, RMediation, medrobust
- README.md → Links to dependent packages
- planning/ECOSYSTEM.md → This file

**In probmed**:
- CLAUDE.md → References medfit as dependency
- planning/DECISIONS.md → Documents medfit decision
- planning/ROADMAP.md → Tracks medfit integration

**In RMediation**:
- CLAUDE.md → References medfit integration plans

**In medrobust**:
- CLAUDE.md → References optional medfit use

---

## Quick Reference

### Starting Work on medfit
1. Read `medfit/CLAUDE.md`
2. Read `medfit/planning/medfit-roadmap.md`
3. Check `probmed/planning/DECISIONS.md` for key decisions

### Checking Impact on Other Packages
1. Read this file (ECOSYSTEM.md)
2. Check "Coordination Points" section
3. Review "Migration Guide" sections

### Making Breaking Changes
1. Document in DECISIONS.md
2. Update ECOSYSTEM.md
3. Announce in all packages' CLAUDE.md
4. Plan coordinated release

---

## Contact Information

**Package Maintainer**: Davood Tofighi (dtofighi@gmail.com)

**GitHub Repositories**:
- medfit: https://github.com/data-wise/medfit
- probmed: https://github.com/data-wise/probmed
- RMediation: https://github.com/data-wise/rmediation
- medrobust: https://github.com/data-wise/medrobust

**Issues**:
- Report medfit issues: https://github.com/data-wise/medfit/issues
- Integration issues: Discuss in relevant package's issues

---

**Last Updated**: 2025-12-02
**Next Review**: After medfit MVP completion
