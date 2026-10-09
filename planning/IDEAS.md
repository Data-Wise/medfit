# IDEAS.md - medfit

Future ideas, enhancements, and research directions for the medfit package.

**Last Updated:** 2026-09-25 (status of each idea checked against the 0.5.0 release)

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

### Four-Way Decomposition (VanderWeele 2014) ✅
- `InteractionMediationData`, lm/glm + lavaan extraction, `decompose()` (#38/#39/#40)

### Parallel Mediation ✅
- `ParallelMediationData`, lm/glm + lavaan extraction (#34/#36/#37)

### Delta-Method SEs for Derived Effects ✅
- Effect SEs in `tidy()` and `confint(parm = "effects")` for every class (#70)

### Engine Adapter: regmedint ✅
- `fit_mediation(engine = "regmedint")` plus the `m_star` argument (#59, 0.4.0)

### Joint Effects with Exposure-Mediator Products ✅
- `JointMediationData`, `joint_effects()` (#76/#77, 0.5.0)

### "Mediation Analysis Workflow" vignette ✅
- Covered by Getting Started on `mediation_demo` (#63, #67)

---

## 🔬 Research Ideas

### Decomposition Framework
**Status:** Decided against (for now) — `decompose()` shipped as a function returning named
components; no `Decomposition` class (roadmap Phase 7b note, Ext C grill)

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
**Status:** regmedint adapter shipped (#59, 0.4.0); CMAverse (C.1) blocked
**Priority:** Medium
**Complexity:** High

Wrap validated implementations instead of reimplementing:

**Engines:**
1. **glm** (internal) - fit, then `extract_mediation()` [Complete]
2. **regmedint** (regmedint) - VanderWeele closed-form [Complete]
3. **gformula** (CMAverse) - G-computation [Blocked: CMAverse not on CRAN]
4. **ipw** (CMAverse) - Inverse probability weighting [Blocked]
5. **tmle** (tmle3) - Targeted learning [Future]
6. **dml** (DoubleML) - Double machine learning [Future]

---

### Mixed Models Support (lme4)
**Status:** Next — Ext D (multilevel) spec, from `specs/BRAINSTORM-medfit-mediationverse-next-features-2026-08-22.md`
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
**Status:** Done on the medfit side — probmed `Imports: medfit (>= 0.3.0)`, uses
`extract_mediation()` and defines `pmed` methods on medfit classes; its tests pass against 0.5.0
**Priority:** —
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
