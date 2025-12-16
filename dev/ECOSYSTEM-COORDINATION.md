# Ecosystem Coordination Brainstorming

**Date**: 2025-12-15 **Context**: medfit test suite complete (241
tests), ready for implementation **Goal**: Coordinate medfit development
with mediationverse ecosystem

------------------------------------------------------------------------

## 📊 Current Ecosystem Status

### Package Status Matrix

| Package            | Progress | Status                            | Blocks                          | Blocked By                   |
|--------------------|----------|-----------------------------------|---------------------------------|------------------------------|
| **medfit**         | 75%      | 🚧 Test suite done, awaiting impl | probmed, RMediation integration | \-                           |
| **mediationverse** | 40%      | ⏸️ Meta-package skeleton          | All packages                    | medfit, probmed stability    |
| **probmed**        | Stable   | ✅ Ready for integration          | \-                              | medfit completion            |
| **RMediation**     | Stable   | ✅ On CRAN, can integrate         | \-                              | medfit completion (optional) |
| **medrobust**      | In Dev   | 🚧 Active development             | \-                              | medfit completion (optional) |
| **medsim**         | Complete | ✅ Core features done             | \-                              | \-                           |

### medfit Current State

✅ **Completed:** - S7 classes (MediationData, SerialMediationData,
BootstrapResult) - extract_mediation() for lm/glm and lavaan - Print and
summary methods - **241 comprehensive tests** (184 PASS, 57 SKIP)

⏳ **Pending:** - fit_mediation() implementation (30 tests ready) -
bootstrap_mediation() implementation (27 tests ready) - Documentation
(roxygen2 + vignettes) - R CMD check passing - CRAN submission

### Dependency Flow

    mediationverse (meta-package)
        ↓ Imports all
        ├── medfit (foundation) ← WE ARE HERE
        │   ↓ Imported by
        ├── probmed (uses medfit extraction & bootstrap)
        ├── RMediation (can use medfit extraction)
        ├── medrobust (optional, uses medfit for naive estimates)
        └── medsim (simulation infrastructure)

------------------------------------------------------------------------

## 🎯 Coordination Options: What to Do Next?

### Option A: 🚀 Complete medfit MVP First (RECOMMENDED)

**Timeline**: 1-2 weeks **Priority**: High **Impact**: Unblocks entire
ecosystem

**Rationale:** - medfit is the **foundation** - everything else depends
on it - Test suite is complete (57 tests ready to guide
implementation) - probmed and RMediation are stable and ready to
integrate - Completing medfit unblocks integration work across ecosystem

**Action Items:** 1. ✅ Test suite committed (DONE TODAY) 2. Implement
bootstrap_mediation() (3-4 hr, 27 tests activate) 3. Implement
fit_mediation() (2-3 hr, 30 tests activate) 4. Add roxygen2
documentation (1-2 hr) 5. R CMD check –as-cran (fix any issues) 6.
Create intro vignette (2 hr) 7. Tag v0.1.0 release

**Benefits:** - Clear milestone (MVP complete) - Unblocks probmed
integration - Provides stable foundation for ecosystem - Can test
integration points immediately

**Risks:** - Delays coordination work slightly - But: Foundation quality
more important than speed

------------------------------------------------------------------------

### Option B: 🔄 Coordinate mediationverse Loading Now

**Timeline**: 2-3 days **Priority**: Medium **Impact**: Sets up
meta-package infrastructure

**Rationale:** - mediationverse needs to know what packages it will
load - Loading logic depends on what medfit exports - Could design
loading mechanism in parallel

**Action Items:** 1. Design mediationverse attachment strategy - Which
packages load by default? - Conflict detection (functions with same
names) - Startup message format 2. Update mediationverse DESCRIPTION -
Imports: medfit, probmed, RMediation, medrobust, medsim - Minimum
version constraints 3. Implement attach.R (similar to tidyverse) 4. Test
loading with current package states

**Benefits:** - Defines ecosystem structure clearly - Identifies
integration issues early - Can mock medfit exports for testing

**Risks:** - Working with incomplete medfit API - May need to revise
when medfit changes - Less urgent than completing medfit

------------------------------------------------------------------------

### Option C: 🤝 probmed Integration Planning

**Timeline**: 1 day **Priority**: Medium-High **Impact**: Validates
medfit API design

**Rationale:** - probmed is first consumer of medfit - Integration tests
medfit’s API choices - Can identify missing features early

**Action Items:** 1. Read probmed’s current extraction code 2. Map
probmed functions → medfit equivalents - probmed::extract_mediation() →
medfit::extract_mediation() - probmed bootstrap →
medfit::bootstrap_mediation() 3. Identify API gaps - What does probmed
need that medfit doesn’t provide? - What changes would make integration
easier? 4. Draft probmed migration plan - DESCRIPTION changes - Code
changes - Test updates 5. Create integration test suite

**Benefits:** - Validates medfit design before finalizing - Identifies
missing features early - Smooth integration when medfit ready

**Risks:** - Premature optimization (medfit not complete) - May discover
medfit needs changes - Time spent on planning vs implementation

------------------------------------------------------------------------

### Option D: 📚 Update Cross-Package Documentation

**Timeline**: 1-2 days **Priority**: Low-Medium **Impact**: Improves
coordination clarity

**Rationale:** - Documentation helps coordinate across packages -
Current state is clear but could be more detailed - Good reference for
future work

**Action Items:** 1. Update medfit/planning/ECOSYSTEM.md - Current
medfit progress (75%) - Test suite completion - Implementation timeline
2. Update mediationverse README - Reflect medfit test completion -
Update roadmap timeline 3. Create INTEGRATION-GUIDE.md - Step-by-step
for each package - API mapping tables - Migration examples 4. Update
STATUS.md in mediationverse - Reflect current package states - Update
badges

**Benefits:** - Clear reference for coordination - Helps onboard
collaborators - Documents current state

**Risks:** - Documentation work != progress on code - May become
outdated quickly - Low priority vs implementation

------------------------------------------------------------------------

### Option E: 🔬 Test Integration Points Now

**Timeline**: 2-3 days **Priority**: Medium **Impact**: Validates
architecture early

**Rationale:** - Even without complete implementation, can test
interfaces - Mock implementations let us test integration - Catch design
issues early

**Action Items:** 1. Create mock implementations - bootstrap_mediation()
stub - fit_mediation() stub 2. Test probmed integration - Can probmed
use medfit::extract_mediation()? - Does MediationData work for probmed?
3. Test RMediation integration - Can RMediation use medfit extraction? -
Any missing features? 4. Document findings 5. Adjust medfit design if
needed

**Benefits:** - Early validation of API design - Catch integration
issues before completion - May save rework later

**Risks:** - Mock implementations may not match real behavior - Time
spent on mocks vs real implementation - May create false confidence

------------------------------------------------------------------------

## 🎲 Decision Matrix

| Option                     | Time   | Priority    | Blocks Others | Risk | Reward        |
|----------------------------|--------|-------------|---------------|------|---------------|
| **A: Complete medfit MVP** | 1-2 wk | 🔴 High     | Yes           | Low  | **Very High** |
| B: mediationverse loading  | 2-3 d  | 🟡 Med      | No            | Med  | Medium        |
| C: probmed planning        | 1 d    | 🟡 Med-High | No            | Low  | High          |
| D: Update docs             | 1-2 d  | 🟢 Low-Med  | No            | Low  | Low           |
| E: Test integration        | 2-3 d  | 🟡 Med      | No            | Med  | Medium        |

------------------------------------------------------------------------

## 💡 Recommended Path Forward

### **Phase 1: Complete medfit MVP (This Week)**

**Priority**: 🔴 CRITICAL PATH

1.  ✅ Test suite committed (DONE)
2.  Implement bootstrap_mediation() (3-4 hr)
    - Remove skip() from test-bootstrap.R
    - 27 tests activate immediately
3.  Implement fit_mediation() (2-3 hr)
    - Remove skip() from test-fit-glm.R
    - 30 tests activate immediately
4.  Documentation (2 hr)
    - Roxygen2 for both functions
    - Examples
5.  R CMD check (1 hr)
    - Fix any issues
    - All tests passing

**Milestone**: medfit v0.1.0 ready for integration

------------------------------------------------------------------------

### **Phase 2: Integration Testing (Next Week)**

**Priority**: 🟡 HIGH

1.  **probmed integration** (1-2 days)
    - Replace probmed extraction with medfit
    - Test backward compatibility
    - Update probmed tests
    - Document migration
2.  **mediationverse loading** (1 day)
    - Implement attach.R
    - Test with all packages
    - Create conflicts() function
    - Startup message
3.  **RMediation integration** (1 day, optional)
    - Test if RMediation can use medfit
    - Document optional integration
    - Keep RMediation independent (it’s on CRAN)

**Milestone**: Integration points validated

------------------------------------------------------------------------

### **Phase 3: Ecosystem Polish (Following Week)**

**Priority**: 🟢 MEDIUM

1.  Documentation updates
    - Update ECOSYSTEM.md
    - Update STATUS.md
    - Create INTEGRATION-GUIDE.md
2.  Cross-package testing
    - Integration test suite
    - CI/CD coordination
    - Version compatibility matrix
3.  Release coordination
    - Version bumps across packages
    - NEWS.md updates
    - Coordinated CRAN submissions

**Milestone**: Ecosystem ready for beta release

------------------------------------------------------------------------

## 🔍 Integration Testing Strategy

### When medfit MVP Complete

#### Test 1: probmed Integration

``` r
# In probmed directory
library(medfit)

# Test extraction
fit_m <- lm(M ~ X, data = test_data)
fit_y <- lm(Y ~ X + M, data = test_data)
med_data <- medfit::extract_mediation(fit_m, model_y = fit_y,
                                       treatment = "X", mediator = "M")

# Test with probmed functions
pmed_result <- compute_pmed(med_data)  # Should work seamlessly
```

**Expected**: probmed uses medfit extraction without modifications

#### Test 2: mediationverse Loading

``` r
# In mediationverse directory
library(mediationverse)
# Should attach: medfit, probmed, RMediation, medrobust, medsim
# Should show: startup message, version info, conflicts

mediationverse_conflicts()
# Should list any function name conflicts
```

**Expected**: All packages load cleanly

#### Test 3: Cross-Package Workflow

``` r
library(mediationverse)

# Full workflow using all packages
fit <- medfit::fit_mediation(...)
pmed <- probmed::compute_pmed(fit)
ci <- RMediation::ci(fit, type = "dop")
robust <- medrobust::sensitivity_analysis(fit)
```

**Expected**: Seamless integration across packages

------------------------------------------------------------------------

## 📋 Immediate Action Items

### This Week (Dec 15-21)

Implement bootstrap_mediation() \[3-4 hr\]

Implement fit_mediation() \[2-3 hr\]

Add documentation \[2 hr\]

R CMD check passing \[1 hr\]

Create intro vignette \[2 hr\]

Tag medfit v0.1.0

### Next Week (Dec 22-28)

Test probmed integration

Implement mediationverse loading

Test RMediation integration (optional)

Update ecosystem documentation

Integration test suite

### Following Week (Dec 29 - Jan 4)

Cross-package CI/CD

Version compatibility matrix

Release coordination plan

Beta release announcement

------------------------------------------------------------------------

## 🤔 Open Questions

1.  **mediationverse package priority?**
    - Should mediationverse wait for all packages to stabilize?
    - Or implement loading mechanism now with current states?
    - **Recommendation**: Wait for medfit v0.1.0, then implement
2.  **RMediation integration timing?**
    - RMediation is stable on CRAN
    - Integration is optional (medfit adds capability but not required)
    - **Recommendation**: Document optional integration, don’t force
3.  **Version numbering coordination?**
    - Should all packages bump to v0.1.0 together?
    - Or version independently?
    - **Recommendation**: medfit v0.1.0, then probmed v0.2.0 (with
      medfit), etc.
4.  **CRAN submission order?**
    - What order to submit to CRAN?
    - **Recommendation**: medfit → probmed → mediationverse (if ready)
5.  **Breaking changes policy?**
    - How to handle breaking changes in medfit?
    - **Recommendation**: Semantic versioning, major version bumps,
      deprecation warnings

------------------------------------------------------------------------

## 📞 Coordination Checklist

Before making changes to medfit: - \[ \] Check impact on probmed
(ECOSYSTEM.md) - \[ \] Check impact on RMediation (if integrated) - \[
\] Check impact on medrobust (if used) - \[ \] Update ECOSYSTEM.md - \[
\] Update NEWS.md - \[ \] Test integration points - \[ \] Document
changes clearly

Before releasing medfit: - \[ \] All tests passing (241/241) - \[ \] R
CMD check clean - \[ \] Documentation complete - \[ \] probmed
integration tested - \[ \] Version bumped appropriately - \[ \] NEWS.md
updated - \[ \] Coordinate with dependent packages

------------------------------------------------------------------------

## 🎯 Success Metrics

**Short-term** (This Sprint): - \[x\] medfit test suite complete (241
tests) - \[ \] medfit MVP implementation complete - \[ \] All 241 tests
passing - \[ \] R CMD check passing

**Medium-term** (Next Month): - \[ \] probmed integrated with medfit -
\[ \] mediationverse loading mechanism working - \[ \] Integration tests
passing - \[ \] Documentation updated

**Long-term** (Q1 2026): - \[ \] medfit v0.1.0 on CRAN - \[ \] probmed
v0.2.0 on CRAN - \[ \] mediationverse v0.1.0 ready - \[ \] Full
ecosystem functional

------------------------------------------------------------------------

**Next Steps**: Review options and decide priority order
**Recommendation**: **Option A** (Complete medfit MVP) is the critical
path
