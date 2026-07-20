# IDEAS.md - medfit

Future ideas, enhancements, and research directions for the medfit package.

**Last Updated:** 2025-12-17

---

## ✅ Recently Implemented (moved from ideas to features)

### ADHD-Friendly API (Phase 6.5) ✅
- `med()` - One-function mediation analysis
- `quick()` - One-line summary output
- Smart defaults minimize decision fatigue

### Generic Functions (Phase 6) ✅
- Effect extractors: `nie()`, `nde()`, `te()`, `pm()`, `paths()`
- Tidyverse integration: `tidy()`, `glance()`
- Base R generics: `coef()`, `vcov()`, `confint()`, `nobs()`

---

## 🔬 Research Ideas

### Four-Way Decomposition (VanderWeele 2014)
**Status:** Planned for post-MVP
**Priority:** High
**Complexity:** Medium

Add support for treatment-mediator interaction decomposition:
- CDE (Controlled Direct Effect)
- INTref (Reference Interaction)
- INTmed (Mediated Interaction)
- PIE (Pure Indirect Effect)

**Implementation:**
- New S7 class: `InteractionMediationData`
- Detect `X:M` interaction in outcome model
- Compute all four components
- Add to decomposition framework

**References:**
- VanderWeele TJ (2014). Epidemiology, 25(5):749-61
- Valeri & VanderWeele (2013). Psychological Methods, 18(2):137-150

---

### Parallel Mediation
**Status:** Future consideration
**Priority:** Medium
**Complexity:** Medium

Support for multiple mediators operating in parallel (not serial):
- X → M1 → Y
- X → M2 → Y
- Total indirect = (a1×b1) + (a2×b2)

**Design:**
- New S7 class: `ParallelMediationData`
- Properties: `a_paths` (vector), `b_paths` (vector)
- Methods for computing total indirect effect
- Variance estimation via delta method or bootstrap

---

### Decomposition Framework
**Status:** Planned
**Priority:** High
**Complexity:** Low

Flexible decomposition system allowing custom effect decompositions:

```r
Decomposition <- S7::new_class(
  "Decomposition",
  properties = list(
    type = character,           # "two_way", "four_way", "custom"
    components = list,          # Named list of components
    total = numeric,            # Total effect
    formula = character         # "NDE + NIE"
  )
)
```

**Constructors:**
- `two_way(nde, nie)` → Standard mediation
- `four_way(cde, int_ref, int_med, pie)` → VanderWeele
- `custom_decomposition(...)` → User-defined

---

## 🔧 Technical Enhancements

### Delta Method SEs for Derived Effects
**Status:** Planned (next release)
**Priority:** High
**Complexity:** Low

Add standard errors for NIE, NDE, TE using delta method:
- `confint(result, type = "effects")` already exists
- Need to compute delta method SEs
- Display in `tidy()` output

**Implementation:**
```r
# Delta method for indirect effect
se_nie <- sqrt(b^2 * var_a + a^2 * var_b + 2*a*b*cov_ab)
```

---

### BCa Bootstrap Confidence Intervals
**Status:** Future
**Priority:** Medium
**Complexity:** Medium

Bias-corrected and accelerated bootstrap:
- Better coverage than percentile method
- Adjusts for bias and skewness in bootstrap distribution

**References:**
- Efron & Tibshirani (1993). An Introduction to the Bootstrap

---

### Engine Adapters for Advanced Methods
**Status:** Planned (Phase 7c in roadmap)
**Priority:** Medium
**Complexity:** High

Wrap validated implementations instead of reimplementing:

**Priority order:**
1. **regression** (internal) - VanderWeele closed-form [Complete]
2. **gformula** (CMAverse) - G-computation [Future]
3. **ipw** (CMAverse) - Inverse probability weighting [Future]
4. **tmle** (tmle3) - Targeted learning [Future]
5. **dml** (DoubleML) - Double machine learning [Future]

---

### Mixed Models Support (lme4)
**Status:** Future
**Priority:** Medium
**Complexity:** High

Support for multilevel/hierarchical mediation:
- Random effects in mediator and/or outcome models
- Cluster-level vs individual-level effects
- Cross-level interactions

**Implementation:**
- `extract_mediation.lmerMod` method
- Handle random effect variance estimation
- Bootstrap with clustering

---

### Bayesian Support (brms)
**Status:** Future
**Priority:** Low
**Complexity:** High

Bayesian mediation analysis:
- Full posterior distributions for indirect effects
- Credible intervals instead of bootstrap CIs
- Prior sensitivity analysis

**Implementation:**
- `extract_mediation.brmsfit` method
- Extract posterior samples
- Compute posterior of indirect effect
- Return BayesianMediationResult

---

## 📊 User Experience

### Plotting Methods
**Status:** Future
**Priority:** Low
**Complexity:** Medium

Built-in visualization:
- Path diagrams (via DiagrammeR or igraph)
- Bootstrap distributions
- Confidence interval plots
- Sensitivity plots (coordinate with medrobust)

**Design:**
```r
plot(med_result, type = "paths")       # Path diagram
plot(boot_result, type = "bootstrap")  # Distribution
plot(boot_result, type = "ci")         # Interval plot
```

---

### Formula Interface Enhancements
**Status:** Brainstorming
**Priority:** Low
**Complexity:** Medium

Simplified formula interface for common cases:

```r
# Instead of separate formulas:
fit_mediation(
  formula_y = Y ~ X + M + C,
  formula_m = M ~ X + C,
  ...
)

# Allow combined syntax (R-style):
fit_mediation(
  mediation = M ~ X + C | Y ~ X + M + C,
  data = data,
  treatment = "X",
  mediator = "M"
)
```

---

## 🌐 Ecosystem Integration

### probmed Integration
**Status:** Next priority
**Priority:** High
**Complexity:** Low

Test medfit output with P_med computation:
- Ensure `nie()`, `nde()` work in probmed workflows
- Update probmed vignettes with medfit examples
- Test `med()` → P_med workflow

---

### lavaan Bidirectional Integration
**Status:** Partially implemented
**Priority:** Medium
**Complexity:** Low

**Current:** medfit can extract from lavaan ✅
**Future:** lavaan users can bootstrap with medfit

Coordinate with lavaan team:
- Ensure `extract_mediation.lavaan` stays current
- Handle edge cases (latent variables, multiple groups)

---

### RMediation/medrobust Coordination
**Status:** Ongoing
**Priority:** High
**Complexity:** Low

Maintain clean API contracts:
- Stable MediationData structure
- Backward-compatible changes
- Coordinated version bumps

---

## 📚 Documentation Ideas

### Vignette: "Mediation Analysis Workflow"
End-to-end example:
1. Data preparation
2. Model fitting with `med()`
3. Effect extraction with `nie()`, `nde()`
4. Bootstrap inference
5. Sensitivity analysis (via medrobust)
6. Reporting results

---

### Vignette: "Extending medfit"
For package developers:
- Creating custom engine adapters
- Adding new S7 classes
- Implementing extraction methods
- Contributing to ecosystem

---

### Comparison Guide
"medfit vs Other Packages":
- lavaan: When to use SEM vs regression approach
- mediation: Feature comparison, migration guide
- mma: Multiple mediator scenarios
- Advantages of S7-based infrastructure

---

## 🔮 Long-Term Vision

### Causal Inference Toolchain
Position medfit as foundation for broader causal mediation ecosystem:
- **medfit**: Infrastructure (model fitting, extraction)
- **probmed**: Effect sizes (P_med)
- **RMediation**: Inference (DOP, MBCO)
- **medrobust**: Sensitivity (bounds, falsification)
- **Future packages**: Time-varying mediation, spatial mediation, etc.

### Cross-Disciplinary Applications
Expand beyond psychology/epidemiology:
- Economics (instrumental variables mediation)
- Machine learning (causal ML + mediation)
- Climate science (pathway analysis)
- Social networks (network mediation)

---

## 💡 Community Ideas

**Add user-contributed ideas here after CRAN release:**

- [ ] Idea from Issue #XX: [Description]
- [ ] Feature request: [Description]
- [ ] Research collaboration: [Description]

---

**Review Cycle:** Quarterly (reassess priorities)
