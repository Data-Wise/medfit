# IDEAS.md - medfit

Future ideas, enhancements, and research directions for the medfit
package.

------------------------------------------------------------------------

## 🔬 Research Ideas

### Four-Way Decomposition (VanderWeele 2014)

**Status:** Planned for post-MVP **Priority:** High **Complexity:**
Medium

Add support for treatment-mediator interaction decomposition: - CDE
(Controlled Direct Effect) - INTref (Reference Interaction) - INTmed
(Mediated Interaction) - PIE (Pure Indirect Effect)

**Implementation:** - New S7 class: `InteractionMediationData` - Detect
`X:M` interaction in outcome model - Compute all four components - Add
to decomposition framework

**References:** - VanderWeele TJ (2014). Epidemiology, 25(5):749-61 -
Valeri & VanderWeele (2013). Psychological Methods, 18(2):137-150

------------------------------------------------------------------------

### Parallel Mediation

**Status:** Future consideration **Priority:** Medium **Complexity:**
Medium

Support for multiple mediators operating in parallel (not serial): - X →
M1 → Y - X → M2 → Y - Total indirect = (a1×b1) + (a2×b2)

**Design:** - New S7 class: `ParallelMediationData` - Properties:
`a_paths` (vector), `b_paths` (vector) - Methods for computing total
indirect effect - Variance estimation via delta method or bootstrap

------------------------------------------------------------------------

### Decomposition Framework

**Status:** Planned **Priority:** High **Complexity:** Low

Flexible decomposition system allowing custom effect decompositions:

``` r
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

**Constructors:** - `two_way(nde, nie)` → Standard mediation -
`four_way(cde, int_ref, int_med, pie)` → VanderWeele -
`custom_decomposition(...)` → User-defined

**Storage:** - MediationData gains `@decompositions` property (list) -
Allows multiple decompositions per result - Each decomposition validates
components sum to total

------------------------------------------------------------------------

## 🔧 Technical Enhancements

### Engine Adapters for Advanced Methods

**Status:** Planned (Phase 7c in roadmap) **Priority:** Medium
**Complexity:** High

Wrap validated implementations instead of reimplementing:

**Priority order:** 1. **regression** (internal) - VanderWeele
closed-form \[MVP\] 2. **gformula** (CMAverse) - G-computation \[Phase
2\] 3. **ipw** (CMAverse) - Inverse probability weighting \[Phase 2\] 4.
**tmle** (tmle3) - Targeted learning \[Future\] 5. **dml** (DoubleML) -
Double machine learning \[Future\]

**Design pattern:** - All engines return standardized `MediationData` -
External packages in `Suggests` - Engine-specific options via
`engine_args = list(...)` - Graceful degradation if package unavailable

**Example:**

``` r
estimate_mediation(
  ...,
  engine = "gformula",
  engine_args = list(
    EMint = TRUE,    # Exposure-mediator interaction
    nboot = 500      # CMAverse-specific bootstrap
  )
)
```

------------------------------------------------------------------------

### Mixed Models Support (lme4)

**Status:** Future **Priority:** Medium **Complexity:** High

Support for multilevel/hierarchical mediation: - Random effects in
mediator and/or outcome models - Cluster-level vs individual-level
effects - Cross-level interactions

**Challenges:** - Random effect variance estimation - Bootstrap with
clustering - Defining indirect effect at different levels

**References:** - Preacher et al. (2010). Multivariate Behavioral
Research - Bauer et al. (2006). Psychological Methods

------------------------------------------------------------------------

### Bayesian Support (brms)

**Status:** Future **Priority:** Low **Complexity:** High

Bayesian mediation analysis: - Full posterior distributions for indirect
effects - Credible intervals instead of bootstrap CIs - Prior
sensitivity analysis

**Implementation:** - `extract_mediation.brmsfit` method - Extract
posterior samples from stanfit - Compute posterior of indirect effect -
Return BayesianMediationResult (inherits BootstrapResult)

------------------------------------------------------------------------

### Sensitivity Analysis Integration

**Status:** Coordinated with medrobust **Priority:** Medium
**Complexity:** Low

Allow medfit to optionally compute naive estimates for sensitivity
analysis:

``` r
# medrobust can call medfit for baseline
naive_result <- medfit::fit_mediation(...)
bounds <- medrobust::sensitivity_bounds(
  naive = naive_result,
  rho_range = c(-0.5, 0.5)
)
```

**Requires:** - Stable MediationData API - Clear documentation of
assumptions - Example workflow in vignette

------------------------------------------------------------------------

## 📊 User Experience

### Formula Interface Enhancements

**Status:** Brainstorming **Priority:** Low **Complexity:** Medium

Simplified formula interface for common cases:

``` r
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

**Challenges:** - Non-standard evaluation - Backward compatibility -
Clear documentation

------------------------------------------------------------------------

### Effect Size Summaries

**Status:** Brainstorming **Priority:** Low **Complexity:** Low

Rich summary output with multiple effect sizes:

``` r
summary(med_result, effects = "all")
# Shows:
# - Indirect effect (a×b)
# - Direct effect (c')
# - Total effect (a×b + c')
# - Proportion mediated
# - Ratio of indirect to direct
# - Standardized effects (if requested)
```

------------------------------------------------------------------------

### Plotting Methods

**Status:** Future **Priority:** Low **Complexity:** Medium

Built-in visualization: - Path diagrams (via DiagrammeR or igraph) -
Bootstrap distributions - Confidence interval plots - Sensitivity plots
(coordinate with medrobust)

**Design:**

``` r
plot(med_result, type = "paths")       # Path diagram
plot(boot_result, type = "bootstrap")  # Distribution
plot(boot_result, type = "ci")         # Interval plot
```

------------------------------------------------------------------------

## 🌐 Ecosystem Integration

### lavaan Bidirectional Integration

**Status:** Partially implemented **Priority:** Medium **Complexity:**
Low

**Current:** medfit can extract from lavaan **Future:** lavaan users can
bootstrap with medfit

Coordinate with lavaan team: - Ensure `extract_mediation.lavaan` stays
current - Contribute examples to lavaan documentation - Handle edge
cases (latent variables, multiple groups)

------------------------------------------------------------------------

### OpenMx Support

**Status:** Postponed **Priority:** Low **Complexity:** Medium

Extraction from OpenMx models (postponed from MVP): - Similar to lavaan
extraction - Handle matrix specification - Extract parameter covariances

**Blocked by:** - OpenMx API stability - Team capacity - User demand
(assess after CRAN release)

------------------------------------------------------------------------

### probmed/RMediation/medrobust Coordination

**Status:** Ongoing **Priority:** High **Complexity:** Low

Maintain clean API contracts: - Stable MediationData structure -
Backward-compatible changes - Coordinated version bumps - Shared test
infrastructure

**Communication:** - Document breaking changes in NEWS - Deprecation
warnings (1 version ahead) - Example migration code

------------------------------------------------------------------------

## 📚 Documentation Ideas

### Vignette: “Mediation Analysis Workflow”

End-to-end example: 1. Data preparation 2. Model fitting 3. Bootstrap
inference 4. Sensitivity analysis (via medrobust) 5. Reporting results

------------------------------------------------------------------------

### Vignette: “Extending medfit”

For package developers: - Creating custom engine adapters - Adding new
S7 classes - Implementing extraction methods - Contributing to ecosystem

------------------------------------------------------------------------

### Comparison Guide

“medfit vs Other Packages”: - lavaan: When to use SEM vs regression
approach - mediation: Feature comparison, migration guide - mma:
Multiple mediator scenarios - Advantages of S7-based infrastructure

------------------------------------------------------------------------

## 🔮 Long-Term Vision

### Causal Inference Toolchain

Position medfit as foundation for broader causal mediation ecosystem: -
**medfit**: Infrastructure (model fitting, extraction) - **probmed**:
Effect sizes (P_med) - **RMediation**: Inference (DOP, MBCO) -
**medrobust**: Sensitivity (bounds, falsification) - **Future
packages**: Time-varying mediation, spatial mediation, etc.

### Cross-Disciplinary Applications

Expand beyond psychology/epidemiology: - Economics (instrumental
variables mediation) - Machine learning (causal ML + mediation) -
Climate science (pathway analysis) - Social networks (network mediation)

Each field has unique challenges → modular ecosystem can adapt.

------------------------------------------------------------------------

## 💡 Community Ideas

**Add user-contributed ideas here after CRAN release:**

Idea from Issue \#XX: \[Description\]

Feature request: \[Description\]

Research collaboration: \[Description\]

------------------------------------------------------------------------

**Last Updated:** 2025-12-15 **Review Cycle:** Quarterly (reassess
priorities)
