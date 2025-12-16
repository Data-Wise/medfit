# probmed Integration Plan

**Date**: 2025-12-16
**Status**: Ready for Implementation
**Priority**: High - First ecosystem consumer

---

## Executive Summary

probmed **already imports medfit** and re-exports `extract_mediation()`. The integration is partially complete. This plan focuses on:

1. Validating the current integration works with medfit MVP
2. Identifying opportunities to leverage more medfit infrastructure
3. Ensuring backward compatibility for probmed users

---

## Current State Analysis

### probmed Structure

```
probmed/R/
├── aaa-imports.R          # Imports medfit
├── classes.R              # PmedResult class, uses medfit::MediationData
├── compute-bootstrap.R    # Own bootstrap implementations
├── compute-core.R         # Core P_med computation
├── generics.R             # Re-exports extract_mediation from medfit
├── methods-pmed.R         # pmed() methods
├── methods-print.R        # Print methods
├── probmed-package.R      # Package docs
├── utils.R                # Utilities
└── zzz.R                  # Package init
```

### Current Dependencies

```yaml
# probmed DESCRIPTION
Imports:
  - medfit              # Already depends on medfit!
  - methods
  - S7 (>= 0.2.1)
  - stats

Remotes:
  - data-wise/medfit    # From GitHub
```

### Integration Points Already in Place

| probmed Component | Uses medfit? | Details |
|-------------------|--------------|---------|
| `extract_mediation()` | ✅ Yes | Re-exported from medfit |
| `MediationData` input | ✅ Yes | `pmed()` accepts medfit::MediationData |
| Bootstrap | ❌ No | probmed has own implementations |
| Model fitting | ❌ No | probmed expects pre-fitted models |

---

## Function Mapping

### Already Using medfit

| probmed Function | medfit Equivalent | Status |
|------------------|-------------------|--------|
| `extract_mediation()` | `medfit::extract_mediation()` | ✅ Re-exported |
| `MediationData` class | `medfit::MediationData` | ✅ Used as input |

### Could Use medfit (Future Enhancement)

| probmed Function | medfit Equivalent | Benefit |
|------------------|-------------------|---------|
| `.pmed_parametric_boot()` | `medfit::bootstrap_mediation(method="parametric")` | Code reduction, consistency |
| `.pmed_nonparametric_boot()` | `medfit::bootstrap_mediation(method="nonparametric")` | Code reduction, consistency |
| Formula fitting | `medfit::fit_mediation()` | Direct formula interface |

---

## Integration Tasks

### Phase 1: Validation (Immediate)

**Goal**: Ensure probmed works with medfit MVP

- [ ] **Task 1.1**: Update probmed's medfit dependency to latest version
  ```yaml
  # probmed DESCRIPTION - ensure version constraint
  Imports:
    medfit (>= 0.1.0)
  ```

- [ ] **Task 1.2**: Run probmed test suite against medfit
  ```r
  # In probmed directory
  devtools::test()
  ```

- [ ] **Task 1.3**: Verify extract_mediation() works
  - Test lm/glm extraction
  - Test lavaan extraction
  - Verify MediationData properties match expectations

- [ ] **Task 1.4**: Run R CMD check
  ```r
  devtools::check()
  ```

### Phase 2: Documentation Update

**Goal**: Update probmed docs to reference medfit properly

- [ ] **Task 2.1**: Update probmed vignettes
  - Reference medfit for extraction
  - Show integration workflow

- [ ] **Task 2.2**: Update DESCRIPTION
  - Add proper medfit version constraint
  - Update description to mention ecosystem

- [ ] **Task 2.3**: Update README
  - Mention medfit foundation
  - Link to medfit documentation

### Phase 3: Enhanced Integration (Future)

**Goal**: Leverage more medfit infrastructure

- [ ] **Task 3.1**: Evaluate bootstrap consolidation
  - Compare probmed's bootstrap with medfit's
  - Identify if medfit's bootstrap can serve probmed's needs
  - Consider wrapper approach

- [ ] **Task 3.2**: Add fit_mediation() support
  - Allow `pmed()` to accept formula directly
  - Use `medfit::fit_mediation()` internally

---

## API Compatibility Check

### MediationData Properties Used by probmed

probmed's `.pmed_core_simple()` needs these properties from MediationData:

| Property | probmed Usage | medfit Provides? |
|----------|---------------|------------------|
| `@a_path` | X→M effect | ✅ Yes |
| `@b_path` | M→Y effect | ✅ Yes |
| `@c_prime` | X→Y direct | ✅ Yes |
| `@sigma_m` | Residual SD (mediator) | ✅ Yes |
| `@sigma_y` | Residual SD (outcome) | ✅ Yes |
| `@estimates` | Full parameter vector | ✅ Yes |
| `@vcov` | Variance-covariance | ✅ Yes |
| `@data` | Original data (nonparam boot) | ✅ Yes |
| `@n_obs` | Sample size | ✅ Yes |

**Result**: ✅ All required properties are available in medfit::MediationData

### Bootstrap Compatibility

probmed's parametric bootstrap needs:
- `@estimates`: Parameter vector ✅
- `@vcov`: Covariance matrix ✅
- MASS::mvrnorm() for sampling

probmed's nonparametric bootstrap needs:
- `@data`: Original dataset ✅
- Ability to refit models

**Result**: ✅ medfit provides all required data

---

## Potential API Gaps

### Gap 1: Bootstrap Statistic Customization

**Issue**: medfit's `bootstrap_mediation()` takes a generic `statistic_fn`, while probmed needs P_med computation specifically.

**Solution**: probmed can continue using its own bootstrap loop that calls `.pmed_core_simple()`, OR wrap medfit's bootstrap with a P_med statistic function.

**Recommendation**: Keep probmed's specialized bootstrap for now. Evaluate consolidation in future release.

### Gap 2: Model Refitting in Nonparametric Bootstrap

**Issue**: probmed's nonparametric bootstrap refits models on resampled data. medfit's bootstrap expects a statistic function.

**Solution**:
- Option A: probmed provides refit logic to medfit's bootstrap
- Option B: probmed keeps own nonparametric implementation

**Recommendation**: Keep probmed's implementation for flexibility. The P_med computation is specialized enough to warrant custom code.

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| API breaking changes | Low | High | medfit MVP is stable; version constraints |
| Performance regression | Low | Medium | Benchmark before/after |
| Missing properties | Very Low | High | Compatibility check done above |
| Test failures | Medium | Medium | Run full test suite early |

---

## Implementation Timeline

### Week 1: Validation
- [ ] Update medfit dependency
- [ ] Run test suite
- [ ] Fix any issues
- [ ] R CMD check

### Week 2: Documentation
- [ ] Update vignettes
- [ ] Update README
- [ ] Update DESCRIPTION

### Week 3+: Enhanced Integration (Optional)
- [ ] Evaluate bootstrap consolidation
- [ ] Add formula interface
- [ ] Performance optimization

---

## Success Criteria

### Minimum (Phase 1)
- [ ] probmed installs with medfit >= 0.1.0
- [ ] All probmed tests pass
- [ ] R CMD check: 0 errors, 0 warnings
- [ ] `extract_mediation()` works for lm/glm/lavaan

### Full Integration (Phase 2-3)
- [ ] Documentation references medfit properly
- [ ] Example workflows in vignettes
- [ ] Clear ecosystem positioning

---

## Code Examples

### Current Workflow (Already Works)

```r
library(probmed)  # Loads medfit automatically

# Fit models
model_m <- lm(M ~ X + C1 + C2, data = mydata)
model_y <- lm(Y ~ X + M + C1 + C2, data = mydata)

# Extract (uses medfit::extract_mediation)
med_data <- extract_mediation(
  model_m,
  model_y = model_y,
  treatment = "X",
  mediator = "M"
)

# Compute P_med
result <- pmed(med_data, method = "parametric", n_boot = 1000)
print(result)
```

### Future Enhancement (With fit_mediation)

```r
library(probmed)

# Direct formula interface (future)
result <- pmed(
  formula_m = M ~ X + C1 + C2,
  formula_y = Y ~ X + M + C1 + C2,
  data = mydata,
  treatment = "X",
  mediator = "M",
  method = "parametric",
  n_boot = 1000
)
```

---

## Next Steps

1. **Merge medfit PR to dev** (blocked on user action)
2. **Clone probmed locally** for testing
3. **Update probmed's medfit dependency**
4. **Run test suite**
5. **Document any issues found**

---

**Author**: Claude Code
**Last Updated**: 2025-12-16
