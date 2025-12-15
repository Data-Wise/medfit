# ADHD-Friendly Workflow Design for medfit

**Purpose**: Propose alternative interfaces that minimize cognitive load and decision fatigue
**Date**: 2025-12-15
**Context**: The user has ADHD and values simple, consistent, context-aware workflows

---

## Understanding ADHD-Friendly Design

### Core Principles

Based on the user's existing workflow patterns (`work`, `pb`, `pv` - context does the rest):

1. **Minimal Cognitive Load**: Less to remember, less to decide
2. **Consistent Patterns**: Predictable, one obvious way to do things
3. **Smart Defaults**: Good choices built-in, override only when needed
4. **Fast Feedback**: Quick to see results, maintain flow state
5. **Error-Resistant**: Hard to make mistakes, clear error messages
6. **Discoverable**: Tab completion, clear naming, easy to remember
7. **Pipeable**: Chain operations naturally, don't break mental state
8. **Progressive Disclosure**: Simple things simple, complex things possible

### ADHD Challenges Addressed

| Challenge | Design Solution |
|-----------|----------------|
| **Working memory limits** | Fewer intermediate objects, chainable operations |
| **Decision fatigue** | Smart defaults, minimal required arguments |
| **Task switching cost** | Complete workflows in one pipeline, no interruptions |
| **Hyperfocus support** | Flow-state friendly, don't force context switches |
| **Name recall** | Short, consistent verbs; tab completion friendly |
| **Pattern learning** | One clear pattern, not 5 equivalent ways |

---

## Current medfit Workflow (Baseline)

### Standard Approach
```r
# Step 1: Fit models separately
fit_m <- lm(M ~ X + C, data = mydata)
fit_y <- lm(Y ~ X + M + C, data = mydata)

# Step 2: Extract mediation structure
med_data <- extract_mediation(
  fit_m,
  model_y = fit_y,
  treatment = "X",
  mediator = "M"
)

# Step 3: Bootstrap
boot_result <- bootstrap_mediation(
  med_data,
  statistic = indirect_effect,
  method = "parametric",
  n_boot = 1000,
  ci_level = 0.95
)

# Step 4: Get results
confint(boot_result)
summary(med_data)
```

### Cognitive Load Analysis

**Mental overhead**:
- 4 separate steps (multiple context switches)
- 6 intermediate objects (fit_m, fit_y, med_data, boot_result, plus results)
- 8 function arguments to remember
- 3 different function names to recall
- Need to know: which model goes where, which argument is which

**Decisions required**:
1. What to name intermediate objects?
2. Which model is model_m vs model_y?
3. What statistic function to use?
4. Which bootstrap method?
5. How many bootstrap samples?
6. What CI level?

**Good parts**:
- Explicit and clear
- Full control
- Works well for complex cases

**ADHD friction points**:
- Too many steps (easy to lose track)
- Too many decisions (decision fatigue)
- Too many intermediate objects (working memory load)
- Function names are long (hard to remember/type)

---

## Alternative 1: Pipe-First Design (tidyverse style)

### Philosophy
"Chain operations naturally, maintain flow state"

### Implementation
```r
# Single pipeline, no intermediate objects
mydata %>%
  mediate(
    outcome = Y ~ X + M + C,
    mediator = M ~ X + C,
    treatment = "X"
  ) %>%
  bootstrap(n = 1000) %>%  # Smart defaults: parametric, 95% CI
  confint()

# Or even shorter with formula shorthand
mydata %>%
  mediate(Y ~ X + M + C | M ~ X + C, treatment = "X") %>%
  bootstrap() %>%
  summary()
```

### Key Features

**Reduced cognitive load**:
- 1 pipeline (no context switching)
- 0 intermediate objects to name
- 3 function calls (mediate → bootstrap → confint)
- Works left-to-right, top-to-bottom (natural reading)

**Smart defaults**:
- `bootstrap()` defaults: parametric, 1000 samples, 95% CI
- `mediate()` auto-detects mediator from formulas
- Data flows through pipe (no repeating `data = `)

**Discoverable**:
- Tab completion: `mydata %>% med<TAB>` → `mediate()`
- Verb names: mediate, bootstrap (short, memorable)
- Pipeline pattern (familiar to tidyverse users)

**Code example**:
```r
# Complete mediation analysis in one flow
results <- mtcars %>%
  mediate(mpg ~ hp + disp | disp ~ hp, treatment = "hp") %>%
  bootstrap() %>%
  tidy()  # Returns tidy data frame

# Print results
results

# Advanced: override defaults when needed
mtcars %>%
  mediate(mpg ~ hp + disp | disp ~ hp, treatment = "hp") %>%
  bootstrap(n = 5000, method = "nonparametric") %>%
  confint(level = 0.99)
```

### Pros
✅ Minimal intermediate objects (flow state friendly)
✅ Natural left-to-right reading
✅ Familiar pattern (tidyverse users)
✅ Tab completion friendly
✅ Smart defaults reduce decisions

### Cons
⚠️ Requires piping (not all R users know pipes)
⚠️ Less explicit (hidden intermediate steps)
⚠️ Harder to inspect intermediate results (but can with `%T>%`)

---

## Alternative 2: Single-Function Interface

### Philosophy
"One function to rule them all - minimal decisions"

### Implementation
```r
# Everything in one call
results <- medfit(
  outcome = Y ~ X + M + C,
  mediator = M ~ X + C,
  data = mydata,
  treatment = "X",
  bootstrap = TRUE  # Smart default: 1000 reps, parametric, 95% CI
)

# That's it! Results include everything
summary(results)
confint(results)
paths(results)
```

### Key Features

**Absolute minimum**:
- 1 function call (medfit)
- 4 required arguments (outcome, mediator, data, treatment)
- 1 optional argument (bootstrap = TRUE/FALSE)
- Everything computed automatically

**Smart defaults**:
```r
# Defaults handle 90% of use cases
medfit(
  Y ~ X + M,
  M ~ X,
  data = mydata,
  treatment = "X"
  # Defaults:
  # - bootstrap = TRUE
  # - n_boot = 1000
  # - method = "parametric"
  # - ci_level = 0.95
  # - engine = "glm"
)
```

**Progressive disclosure**:
```r
# Simple case (4 args)
medfit(Y ~ X + M, M ~ X, mydata, "X")

# Override defaults when needed
medfit(
  Y ~ X + M, M ~ X, mydata, "X",
  bootstrap = FALSE  # Skip bootstrap for speed
)

# Advanced: full control
medfit(
  Y ~ X + M, M ~ X, mydata, "X",
  bootstrap = TRUE,
  n_boot = 5000,
  method = "nonparametric",
  ci_level = 0.99,
  engine = "gformula",
  engine_args = list(EMint = TRUE)
)
```

### Pros
✅ Minimal function to remember (just `medfit()`)
✅ Fewest decisions (4 required args)
✅ No intermediate objects
✅ Fast for common cases
✅ Beginner friendly

### Cons
⚠️ Less composable (can't easily swap parts)
⚠️ One big function (more complex internally)
⚠️ Less flexible for workflows

---

## Alternative 3: Builder Pattern (Method Chaining)

### Philosophy
"Build up the analysis step by step, self-documenting"

### Implementation
```r
# Create mediation object, add pieces
med <- mediation()  # Start with empty builder

med %>%
  outcome(Y ~ X + M + C) %>%
  mediator(M ~ X + C) %>%
  data(mydata) %>%
  treatment("X") %>%
  fit() %>%            # Fit models
  bootstrap() %>%      # Bootstrap inference
  summary()            # Get results
```

### Key Features

**Self-documenting**:
- Each step is explicit: `outcome()`, `mediator()`, `treatment()`
- Easy to read what's happening
- Natural language flow

**Flexible**:
```r
# Can build incrementally
med <- mediation()
med <- med %>% outcome(Y ~ X + M)
med <- med %>% mediator(M ~ X)
med <- med %>% data(mydata)

# Or inspect before fitting
med %>% check()  # Validate before fitting
med %>% fit()
```

**Progressive**:
```r
# Minimal version
mediation() %>%
  outcome(Y ~ X + M) %>%
  mediator(M ~ X) %>%
  data(mydata) %>%
  treatment("X") %>%
  go()  # fit + bootstrap + results

# Detailed version
mediation() %>%
  outcome(Y ~ X + M) %>%
  mediator(M ~ X) %>%
  data(mydata) %>%
  treatment("X") %>%
  fit() %>%
  bootstrap(n = 5000) %>%
  confint()
```

### Pros
✅ Self-documenting (readable)
✅ Flexible (compose as needed)
✅ Can inspect before executing
✅ Natural language flow

### Cons
⚠️ More verbose than alternatives
⚠️ Many small functions to remember
⚠️ Requires understanding builder pattern

---

## Alternative 4: Formula Interface (mediation package style)

### Philosophy
"R users know formulas - use that mental model"

### Implementation
```r
# Single call, formula-centric
results <- mediate(
  model.m = M ~ X + C,
  model.y = Y ~ X + M + C,
  treat = "X",
  mediator = "M",
  data = mydata,
  boot = TRUE
)

# Or with combined formula syntax
results <- mediate(
  Y ~ X + M + C | M ~ X + C,  # outcome | mediator
  treat = "X",
  data = mydata
)
```

### Key Features

**Familiar**:
- R users already know formula syntax
- Similar to `lm()`, `glm()`, etc.
- Natural model specification

**Concise**:
```r
# Combined formula: outcome | mediator
mediate(Y ~ X + M | M ~ X, treat = "X", data = mydata)
```

### Pros
✅ Familiar to R users (formula interface)
✅ Concise with combined formula
✅ Similar to existing mediation packages

### Cons
⚠️ Formula syntax can be complex
⚠️ Combined formula (|) is less standard

---

## Alternative 5: Short Verbs with Context (User's Preferred Pattern)

### Philosophy
"Like the user's zsh workflow: `work`, `pb`, `pv` - context does the rest"

### Implementation
```r
# Step 1: Fit (context: mediation analysis)
med <- fit(
  Y ~ X + M,
  M ~ X,
  data = mydata,
  treatment = "X"
)

# Step 2: Bootstrap (context: med object)
med %>% boot()  # Smart defaults

# Step 3: Results (context: bootstrapped med)
med %>% ci()    # Confidence intervals
med %>% paths() # Path coefficients
```

### Key Features

**Minimal names**:
- `fit()` - not `fit_mediation()`
- `boot()` - not `bootstrap_mediation()`
- `ci()` - not `confint()` (BUT: conflicts with ecosystem!)

**Context-aware**:
- `fit()` knows it's mediation from arguments
- `boot()` knows what to bootstrap from object type
- `ci()` knows what CIs to compute from object type

**Pipeline friendly**:
```r
# Complete workflow
fit(Y ~ X + M, M ~ X, mydata, "X") %>%
  boot() %>%
  summary()
```

### Problem: Namespace Conflicts!

**Issue**: Short names conflict with existing R functions or package generics.

| Short Name | Conflict |
|------------|----------|
| `fit()` | stats::fit (rarely used, but exists) |
| `boot()` | boot::boot() (popular package!) |
| `ci()` | Conflicts with ecosystem expectation of `confint()` |

**Solution**: Package-prefixed versions
```r
# Unambiguous: prefix with med*
medfit(Y ~ X + M, M ~ X, mydata, "X") %>%
  medboot() %>%
  summary()

# Or use : to be explicit
medfit::fit(Y ~ X + M, M ~ X, mydata, "X") %>%
  medfit::boot()
```

### Revised Version
```r
# Short verbs, med* prefix
med(Y ~ X + M, M ~ X, mydata, "X") %>%  # or medfit()
  boot() %>%  # or medboot()
  ci()        # or use standard confint()
```

### Pros
✅ Short, memorable verbs
✅ Context does the work
✅ Pipeline friendly
✅ Matches user's workflow preferences

### Cons
⚠️ Namespace conflicts (need prefixing)
⚠️ `ci()` conflicts with `confint()` standard (hybrid approach needed)

---

## Alternative 6: Hybrid - Best of All Worlds

### Philosophy
"Combine best aspects: short names, pipes, smart defaults, standard generics"

### Implementation
```r
# Core workflow: short verbs + pipes
library(medfit)

# Simple case (smart defaults)
mydata %>%
  med(Y ~ X + M, M ~ X, treatment = "X") %>%
  boot() %>%
  confint()  # Standard generic ✅

# Advanced case (override defaults)
mydata %>%
  med(Y ~ X + M, M ~ X, treatment = "X") %>%
  boot(n = 5000, method = "nonparametric") %>%
  tidy()  # Broom integration ✅
```

### Key Features

**Short core functions**:
- `med()` - fit mediation models (short for mediate)
- `boot()` - bootstrap (context-aware)
- Standard generics for extraction: `confint()`, `coef()`, `vcov()`, `summary()`

**Smart defaults**:
```r
# Minimal arguments
med(Y ~ X + M, M ~ X, data, "X")

# Defaults:
# - Fits GLM models
# - Extracts mediation structure
# - Returns MediationData object

# Bootstrap defaults
boot(med_obj)

# Defaults:
# - method = "parametric"
# - n = 1000
# - ci_level = 0.95
# - parallel = FALSE
```

**Standard generics maintained**:
```r
med_result <- med(Y ~ X + M, M ~ X, mydata, "X")

# Standard R generics work (ecosystem integration)
confint(med_result)   # Not ci()
coef(med_result)
vcov(med_result)
summary(med_result)

# Mediation-specific generics
paths(med_result)
indirect_effect(med_result)
```

**Complete example**:
```r
library(medfit)

# Analysis 1: Simple (defaults)
mtcars %>%
  med(mpg ~ hp + disp, disp ~ hp, treatment = "hp") %>%
  boot() %>%
  confint()

# Analysis 2: Advanced
mtcars %>%
  med(mpg ~ hp + disp + wt, disp ~ hp + wt, treatment = "hp") %>%
  boot(n = 5000, method = "nonparametric") %>%
  tidy() %>%  # Broom integration
  filter(term %in% c("indirect", "direct"))

# Analysis 3: No bootstrap (fast exploration)
mtcars %>%
  med(mpg ~ hp + disp, disp ~ hp, treatment = "hp") %>%
  summary()  # Delta method CIs
```

### Pros
✅ Short names (med, boot) - easy to remember
✅ Pipeline friendly (flow state)
✅ Smart defaults (minimal decisions)
✅ Standard generics (ecosystem integration)
✅ Tab completion friendly
✅ Beginner to advanced (progressive disclosure)

### Cons
⚠️ `boot()` conflicts with boot package (can use medfit::boot or import selectively)
⚠️ Slightly less explicit than full names

---

## Comparison Matrix

| Feature | Current | Alt 1: Pipe | Alt 2: Single | Alt 3: Builder | Alt 4: Formula | Alt 5: Short | Alt 6: Hybrid ⭐ |
|---------|---------|-------------|---------------|----------------|----------------|--------------|-----------------|
| **Steps to remember** | 4 | 3 | 1 | Many | 1 | 3 | 3 |
| **Intermediate objects** | 4-6 | 0-1 | 0-1 | 0-1 | 0-1 | 1-2 | 0-1 |
| **Function names** | Long | Medium | Long | Short | Medium | Short | Short |
| **Decisions required** | Many | Few | Minimal | Medium | Few | Few | Few |
| **Pipeline friendly** | ⚠️ | ✅✅✅ | ❌ | ✅✅ | ❌ | ✅✅ | ✅✅✅ |
| **Tab completion** | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅✅ | ✅✅✅ |
| **Ecosystem generics** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ Conflicts | ✅ |
| **Beginner friendly** | ⚠️ | ✅✅ | ✅✅✅ | ⚠️ | ✅ | ✅✅ | ✅✅✅ |
| **ADHD friendly** | ⚠️ | ✅✅ | ✅✅✅ | ⚠️ | ✅ | ✅✅ | ✅✅✅ |
| **Working memory load** | High | Low | Lowest | Medium | Low | Low | Low |
| **Flow state support** | ⚠️ | ✅✅ | ✅ | ✅ | ⚠️ | ✅✅ | ✅✅✅ |

**Legend**: ✅✅✅ Excellent, ✅✅ Very Good, ✅ Good, ⚠️ Moderate, ❌ Poor

---

## Recommendation: Alternative 6 (Hybrid Approach)

### Why This is Optimal for ADHD

1. **Short verbs** (`med()`, `boot()`) - easy to remember, fast to type
2. **Pipeline pattern** - maintain flow state, no context switching
3. **Smart defaults** - minimal decisions (parametric, 1000, 95% CI)
4. **Standard generics** - ecosystem integration (`confint()`, not `ci()`)
5. **Progressive disclosure** - simple things simple, complex things possible
6. **Tab completion friendly** - `med<TAB>`, `boot<TAB>`
7. **Minimal objects** - 0-1 intermediate objects in pipeline

### Implementation Plan

#### Core Functions (Short Names)
```r
#' Fit Mediation Models
#'
#' @param outcome_formula Outcome model formula (Y ~ X + M + covariates)
#' @param mediator_formula Mediator model formula (M ~ X + covariates)
#' @param data Data frame
#' @param treatment Character: treatment variable name
#' @param ... Additional arguments
#' @return MediationData object
#' @export
med <- function(outcome_formula, mediator_formula, data, treatment, ...) {
  # Wrapper around fit_mediation() or extract_mediation()
  # Smart detection: if data is a data frame, fit models
  # If first arg is a model, extract from models

  if (inherits(data, "data.frame")) {
    # Fit both models
    fit_mediation(
      formula_y = outcome_formula,
      formula_m = mediator_formula,
      data = data,
      treatment = treatment,
      ...
    )
  } else {
    # Assume outcome_formula is fit_m, mediator_formula is fit_y
    extract_mediation(
      object = outcome_formula,
      model_y = mediator_formula,
      treatment = data,  # Actually treatment in this case
      mediator = treatment,  # Actually mediator in this case
      ...
    )
  }
}

#' Bootstrap Mediation Inference
#'
#' @param object MediationData object (from med())
#' @param n Number of bootstrap samples (default: 1000)
#' @param method Bootstrap method: "parametric", "nonparametric", "plugin"
#' @param ci_level Confidence level (default: 0.95)
#' @param parallel Use parallel processing? (default: FALSE)
#' @param seed Random seed for reproducibility
#' @param ... Additional arguments
#' @return BootstrapResult object
#' @export
boot <- function(object, n = 1000, method = "parametric",
                 ci_level = 0.95, parallel = FALSE,
                 seed = NULL, ...) {
  # Wrapper around bootstrap_mediation()
  bootstrap_mediation(
    object = object,
    statistic = indirect_effect,  # Default statistic
    method = method,
    n_boot = n,
    ci_level = ci_level,
    parallel = parallel,
    seed = seed,
    ...
  )
}
```

#### Standard Generics (Maintained)
```r
# These remain as-is (ecosystem integration)
confint(object)    # Not ci()
coef(object)
vcov(object)
summary(object)
print(object)
```

#### Mediation-Specific Generics
```r
paths(object)              # Path coefficients
indirect_effect(object)    # Indirect effect
direct_effect(object)      # Direct effect
total_effect(object)       # Total effect
```

### Complete Workflow Examples

#### Example 1: Simple Analysis
```r
library(medfit)

# One pipeline, minimal args
mtcars %>%
  med(mpg ~ hp + disp, disp ~ hp, treatment = "hp") %>%
  boot() %>%
  confint()

# Output:
#         effect estimate ci_lower ci_upper
# 1     indirect    -0.15    -0.25    -0.05
# 2       direct     0.02    -0.01     0.05
# 3        total    -0.13    -0.22    -0.04
```

#### Example 2: Advanced Control
```r
mtcars %>%
  med(mpg ~ hp + disp + wt, disp ~ hp + wt, treatment = "hp") %>%
  boot(n = 5000, method = "nonparametric", seed = 123) %>%
  tidy()  # Broom integration
```

#### Example 3: Exploration (No Bootstrap)
```r
# Fast exploration without bootstrap
mtcars %>%
  med(mpg ~ hp + disp, disp ~ hp, treatment = "hp") %>%
  summary()  # Uses delta method for CIs
```

#### Example 4: From Pre-Fit Models
```r
# Already have models fit
fit_m <- lm(disp ~ hp, data = mtcars)
fit_y <- lm(mpg ~ hp + disp, data = mtcars)

# Use med() as extraction wrapper
med(fit_m, fit_y, treatment = "hp", mediator = "disp") %>%
  boot() %>%
  confint()
```

---

## Additional ADHD-Friendly Features

### 1. Clear Error Messages
```r
# Instead of cryptic error
# Error: object 'X' not found

# Provide helpful error
mtcars %>%
  med(mpg ~ hp + TYPO, disp ~ hp, treatment = "hp")
# Error in med():
# ✖ Variable 'TYPO' not found in data
# ℹ Did you mean: 'drat' or 'qsec'?
# ℹ Available variables: mpg, cyl, disp, hp, drat, wt, qsec, vs, am, gear, carb
```

### 2. Smart Autocomplete Hints
```r
# RStudio autocomplete shows smart hints
med(  # Autocomplete suggests:
#   outcome_formula = Y ~ X + M,
#   mediator_formula = M ~ X,
#   data = <data.frame>,
#   treatment = "<variable>",
#   ...
```

### 3. Progressive Disclosure in Help
```r
?med
# Help page structured:
# 1. Quick Start (minimal args)
# 2. Common Use Cases (examples)
# 3. Advanced Options (details)
# 4. Theory (background)
```

### 4. Workflow Presets
```r
# Quick presets for common workflows
mtcars %>%
  med_quick(mpg ~ hp + disp, disp ~ hp, "hp")
  # Equivalent to: med() %>% boot() %>% confint()
  # One function, complete analysis

# Custom presets
mtcars %>%
  med_robust(mpg ~ hp + disp, disp ~ hp, "hp")
  # Equivalent to: med() %>% boot(n=5000, method="nonparametric")
```

### 5. Visual Feedback
```r
# Progress bars for long operations
mtcars %>%
  med(mpg ~ hp + disp, disp ~ hp, treatment = "hp") %>%
  boot(n = 10000)

# Bootstrap: 10000/10000 [====================================] 100% eta: 0s
```

---

## Migration Strategy

### Phase 1: Add Short Names as Aliases
```r
# Add new short names alongside existing
med <- fit_mediation  # Alias
boot <- bootstrap_mediation  # Alias

# Both work
med(Y ~ X + M, M ~ X, data, "X")  # New
fit_mediation(...)                 # Old (still works)
```

### Phase 2: Document New Workflow
- Update vignettes with pipeline examples
- Add "Quick Start" vignette using short names
- Show both workflows in CLAUDE.md

### Phase 3: Gradual Adoption
- Existing code still works (backwards compatible)
- New users learn short names
- Advanced users can choose

---

## Namespace Conflict Resolution

### Problem: `boot()` conflicts with boot package

**Solutions**:

1. **Package namespacing** (user specifies)
   ```r
   medfit::boot(med_obj)  # Explicit
   ```

2. **Selective import** (package handles)
   ```r
   # In NAMESPACE
   export(boot)
   importFrom(boot, boot.ci, boot.array)  # Import specific functions from boot pkg
   ```

3. **Different name** (avoid conflict entirely)
   ```r
   # Use medboot() instead
   medboot <- function(...) bootstrap_mediation(...)
   ```

**Recommendation**: Use `boot()` as primary name, document conflict, suggest `medfit::boot()` if boot package loaded.

---

## Conclusion

**Primary Recommendation**: **Alternative 6 (Hybrid Approach)**

**Why**:
1. ✅ **Minimal cognitive load** - short names, smart defaults, pipeable
2. ✅ **Flow state friendly** - one continuous pipeline, no interruptions
3. ✅ **Decision minimization** - good defaults, override only when needed
4. ✅ **Ecosystem compatible** - uses `confint()`, `coef()`, standard generics
5. ✅ **Tab completion** - `med<TAB>` → `med()`, easy discovery
6. ✅ **Progressive disclosure** - simple default, advanced possible
7. ✅ **Pattern consistency** - pipe all the way, like user's zsh workflow

**Core API**:
```r
# Short, memorable, pipeable
data %>%
  med(outcome ~ predictors, mediator ~ predictors, treatment = "X") %>%
  boot() %>%
  confint()
```

**This matches the user's preferred pattern**: Simple verbs, context does the rest, pipeline-friendly, minimal decisions!

---

## Next Steps

1. **Prototype**: Create `med()` and `boot()` wrappers in separate branch
2. **User testing**: Test with actual ADHD workflow
3. **Documentation**: Update vignettes with new workflow
4. **Decide**: Keep alongside existing or make primary

**Question for user**: Which alternative resonates most with your workflow preferences?

---

**Document Status**: Ready for discussion
**Next**: User feedback on preferred alternative
