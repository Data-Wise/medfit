# Function Naming Deep Dive: `med()` and `paths()`

**Purpose**: Detailed explanation and alternatives for core workflow functions
**Date**: 2025-12-15
**Context**: ADHD-friendly API design with clear, memorable function names

---

## The `med()` Function

### What It Does

**Current proposal**: `med()` is a convenience wrapper that:

1. **Fits mediation models** (mediator + outcome models)
2. **Extracts mediation structure** (path coefficients a, b, c')
3. **Returns MediationData object** (ready for bootstrap/analysis)

**Two usage modes**:

```r
# Mode 1: From formulas (fits models)
med(
  outcome = Y ~ X + M + C,
  mediator = M ~ X + C,
  data = mydata,
  treatment = "X"
)

# Mode 2: From fitted models (extraction)
fit_m <- lm(M ~ X + C, data = mydata)
fit_y <- lm(Y ~ X + M + C, data = mydata)
med(fit_m, fit_y, treatment = "X", mediator = "M")
```

**Essentially combines**:
- `fit_mediation()` - fit both models
- `extract_mediation()` - extract structure

**Returns**: `MediationData` S7 object with:
- Path coefficients (a, b, c')
- Full parameter vector and covariance matrix
- Residual variances
- Sample size, variable names

---

### Why "med"?

**Intended meaning**: Short for "**mediate**" (verb)

**Pronunciation**: "med" (rhymes with "bed")

**Mental model**: "Fit/extract mediation structure"

**Usage in sentence**: "I mediated the relationship between X and Y through M"

---

### Problems with `med()`

#### 1. Ambiguity of Meaning

"med" could stand for:
- ✅ "mediate" (verb - what we want)
- ⚠️ "mediation" (noun - the concept)
- ⚠️ "mediator" (noun - the variable)
- ⚠️ "medicine" (in medical contexts!)

**Confusion risk**: Users might not immediately know what `med()` does.

#### 2. Function Overloading

The function has two different behaviors based on argument types:

```r
# Fits models (first arg is formula)
med(Y ~ X + M, M ~ X, data = mydata, "X")

# Extracts from models (first arg is lm object)
med(fit_m, fit_y, treatment = "X", mediator = "M")
```

**Cognitive load**: Users must remember which signature to use when.

#### 3. Not Immediately Clear

```r
# What does this do?
med(Y ~ X + M, M ~ X, data, "X")

# vs more explicit
fit_mediation(Y ~ X + M, M ~ X, data, "X")
```

**Trade-off**: Brevity vs clarity

---

### Alternatives to `med()`

#### Option 1: `mediate()` (Full Verb)

**Pros**:
- ✅ Clear verb form
- ✅ Natural language ("I mediate X → Y")
- ✅ Matches mediation::mediate() (familiar)
- ✅ Unambiguous meaning

**Cons**:
- ⚠️ Longer to type (but not much)
- ⚠️ Similar to existing mediation::mediate() (could cause confusion if both loaded)

**Usage**:
```r
mydata %>%
  mediate(Y ~ X + M, M ~ X, treatment = "X") %>%
  boot() %>%
  confint()
```

**Verdict**: ✅ **RECOMMENDED** - Clearest option

---

#### Option 2: `fit_med()` (Abbreviated)

**Pros**:
- ✅ Clear purpose (fit)
- ✅ Shorter than fit_mediation()
- ✅ Follows R naming pattern (fit_*)

**Cons**:
- ⚠️ Not a verb (less natural in pipeline)
- ⚠️ "fit" implies model fitting, but also does extraction

**Usage**:
```r
mydata %>%
  fit_med(Y ~ X + M, M ~ X, treatment = "X") %>%
  boot() %>%
  confint()
```

**Verdict**: ✅ Acceptable alternative

---

#### Option 3: `medfit()` (Package Name)

**Pros**:
- ✅ Package name as function (mediation::mediate pattern)
- ✅ Short, memorable
- ✅ Clear association with package

**Cons**:
- ⚠️ Noun, not verb (less natural)
- ⚠️ Could be confused with package name itself

**Usage**:
```r
mydata %>%
  medfit(Y ~ X + M, M ~ X, treatment = "X") %>%
  boot() %>%
  confint()
```

**Verdict**: ✅ Good option, clear package association

---

#### Option 4: `estimate()` (Statistical Term)

**Pros**:
- ✅ Clear verb
- ✅ Statistical language (estimate mediation effects)
- ✅ Natural in pipeline

**Cons**:
- ⚠️ Generic (could mean many things)
- ⚠️ Doesn't clearly indicate mediation

**Usage**:
```r
mydata %>%
  estimate(Y ~ X + M, M ~ X, treatment = "X", type = "mediation") %>%
  boot() %>%
  confint()
```

**Verdict**: ⚠️ Too generic, not recommended

---

#### Option 5: Keep Current Names (Verbose)

**Use existing**:
- `fit_mediation()` - when fitting from formulas
- `extract_mediation()` - when extracting from models

**Pros**:
- ✅ Crystal clear what each does
- ✅ No ambiguity
- ✅ Self-documenting

**Cons**:
- ❌ Long to type
- ❌ Breaks flow state (more typing = more friction)
- ❌ Less ADHD-friendly

**Usage**:
```r
mydata %>%
  fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    treatment = "X"
  ) %>%
  bootstrap_mediation() %>%
  confint()
```

**Verdict**: ⚠️ Clear but verbose, not ADHD-optimal

---

#### Option 6: Separate Short Names

**Split into two functions**:
- `fit()` - fit models (from formulas)
- `extract()` - extract structure (from fitted models)

**Pros**:
- ✅ Very short
- ✅ Clear separation of concerns
- ✅ No overloading

**Cons**:
- ⚠️ `fit()` and `extract()` are very generic names
- ⚠️ Potential namespace conflicts

**Usage**:
```r
# From formulas
mydata %>%
  fit(Y ~ X + M, M ~ X, treatment = "X") %>%
  boot() %>%
  confint()

# From models
extract(fit_m, fit_y, treatment = "X", mediator = "M") %>%
  boot() %>%
  confint()
```

**Verdict**: ⚠️ Too generic, risky

---

### Recommendation for `med()`

**Primary recommendation**: **`mediate()`**

**Rationale**:
1. ✅ Clear, unambiguous verb
2. ✅ Natural language ("mediate the relationship")
3. ✅ Familiar to R users (matches mediation::mediate pattern)
4. ✅ Only 3 more characters than `med()` (minimal typing cost)
5. ✅ Pipeline-friendly

**Secondary recommendation**: **`medfit()`**

**Rationale**:
1. ✅ Package name as function (clear association)
2. ✅ Short and memorable
3. ✅ Less likely to conflict (unique package name)

**Avoid**: `med()` - too ambiguous, `estimate()` - too generic

---

## The `paths()` Function

### What It Does

**Purpose**: Extract path coefficients from mediation object

**Input**: MediationData or SerialMediationData object

**Output**: Named list with path coefficients

```r
# Example usage
result <- mediate(Y ~ X + M, M ~ X, mydata, "X")

paths(result)
# Returns:
# $a
# [1] 0.5
#
# $b
# [1] 0.3
#
# $c_prime
# [1] 0.2
#
# $indirect
# [1] 0.15
```

---

### What Information Does `paths()` Return?

#### For Simple Mediation (MediationData)

```r
paths(med_obj)

# Returns list with:
# - a: X → M path coefficient
# - b: M → Y path coefficient (controlling for X)
# - c_prime: X → Y direct effect (controlling for M)
# - indirect: a * b (indirect effect)
# - total: c_prime + indirect (total effect)
```

**Mental model**: The "skeleton" of the mediation structure.

#### For Serial Mediation (SerialMediationData)

```r
paths(serial_med_obj)

# Returns list with:
# - a: X → M1 path
# - d: M1 → M2 path (or vector for 3+ mediators)
# - b: M_k → Y path (last mediator to outcome)
# - c_prime: X → Y direct effect
# - indirect: a * d * b (product-of-three or more)
# - total: c_prime + indirect
```

---

### How `paths()` Differs from `coef()`

| Function | Returns | Purpose |
|----------|---------|---------|
| **`coef()`** | ALL model parameters | Standard R generic, ecosystem integration |
| **`paths()`** | Just mediation paths (a, b, c') | Mediation-specific, focused information |

**Example**:

```r
result <- mediate(mpg ~ hp + disp + wt, disp ~ hp + wt, mtcars, "hp")

# coef() returns EVERYTHING
coef(result)
# $a_hp
# [1] 0.50
#
# $b_disp
# [1] -0.03
#
# $c_prime_hp
# [1] 0.02
#
# $wt_M          # Covariate in mediator model
# [1] 100.5
#
# $wt_Y          # Covariate in outcome model
# [1] -3.2
#
# ... (all parameters)

# paths() returns JUST mediation structure
paths(result)
# $a
# [1] 0.50
#
# $b
# [1] -0.03
#
# $c_prime
# [1] 0.02
#
# $indirect
# [1] -0.015
#
# $total
# [1] 0.005
```

**Use case**:
- `coef()`: When you need all model parameters (for vcov(), confint(), broom, etc.)
- `paths()`: When you want just the mediation "story" (a → b → c')

---

### Alternatives to `paths()`

#### Option 1: Keep `paths()` (Current Proposal)

**Pros**:
- ✅ Short, memorable
- ✅ Clear in mediation context (paths are central concept)
- ✅ Verb-like (extract paths)
- ✅ No conflicts with existing R functions

**Cons**:
- ⚠️ Could be confused with file paths in other contexts

**Verdict**: ✅ **RECOMMENDED** - Clear and concise

---

#### Option 2: `mediation_paths()`

**Pros**:
- ✅ Explicit and unambiguous
- ✅ Self-documenting

**Cons**:
- ❌ Long (15 characters!)
- ❌ Breaks ADHD-friendly flow

**Verdict**: ⚠️ Too verbose for ADHD-friendly API

---

#### Option 3: `structure()`

**Pros**:
- ✅ Captures idea of mediation structure

**Cons**:
- ❌ Conflicts with base R `structure()` function
- ❌ Too generic

**Verdict**: ❌ Not recommended (conflict)

---

#### Option 4: `coefficients()` or `med_coef()`

**Pros**:
- ✅ Statistical language

**Cons**:
- ⚠️ Confusing with `coef()` (different purpose)
- ⚠️ Not clear it's mediation-specific

**Verdict**: ⚠️ Potential confusion

---

#### Option 5: `effects()`

**Pros**:
- ✅ Short
- ✅ Describes what it returns (effects)

**Cons**:
- ⚠️ Conflicts with stats::effects()
- ⚠️ Could mean total/direct/indirect (ambiguous)

**Verdict**: ⚠️ Conflict + ambiguity

---

#### Option 6: Just use `coef()` with argument

**Use standard generic with argument**:

```r
coef(med_obj, type = "paths")
# Returns just a, b, c'

coef(med_obj, type = "all")
# Returns all parameters
```

**Pros**:
- ✅ Uses standard generic
- ✅ Single interface

**Cons**:
- ⚠️ More typing
- ⚠️ Extra argument to remember

**Verdict**: ⚠️ Acceptable but less convenient

---

### Recommendation for `paths()`

**Recommendation**: **Keep `paths()`**

**Rationale**:
1. ✅ Short (5 characters) - ADHD-friendly
2. ✅ Clear in mediation context
3. ✅ No conflicts with important R functions
4. ✅ Focused purpose (just mediation structure)
5. ✅ Natural complement to `coef()` (paths vs all parameters)

---

## Complete API Comparison

### Option A: Current Proposal
```r
library(medfit)

mtcars %>%
  med(mpg ~ hp + disp, disp ~ hp, treatment = "hp") %>%
  boot() %>%
  confint()

paths(result)  # Just mediation paths
coef(result)   # All parameters
```

**ADHD score**: ⚠️ Moderate (med is ambiguous)

---

### Option B: Recommended Revision
```r
library(medfit)

mtcars %>%
  mediate(mpg ~ hp + disp, disp ~ hp, treatment = "hp") %>%
  boot() %>%
  confint()

paths(result)  # Just mediation paths
coef(result)   # All parameters
```

**ADHD score**: ✅✅ Very Good (clear verb, short enough)

---

### Option C: Package Name Pattern
```r
library(medfit)

mtcars %>%
  medfit(mpg ~ hp + disp, disp ~ hp, treatment = "hp") %>%
  boot() %>%
  confint()

paths(result)  # Just mediation paths
coef(result)   # All parameters
```

**ADHD score**: ✅✅ Very Good (clear package association)

---

### Option D: Explicit Names
```r
library(medfit)

mtcars %>%
  fit_mediation(
    formula_y = mpg ~ hp + disp,
    formula_m = disp ~ hp,
    treatment = "hp"
  ) %>%
  bootstrap_mediation() %>%
  confint()

mediation_paths(result)  # Mediation paths
coef(result)             # All parameters
```

**ADHD score**: ⚠️ Moderate (verbose, more decisions, longer to type)

---

## Final Recommendations

### Core Workflow Function

**Recommendation**: **`mediate()`** (Option B)

**Alternative**: **`medfit()`** (Option C)

**Rationale**:
- Clear, unambiguous verb
- Natural in pipeline
- Only slightly longer than `med()`
- Familiar pattern (matches mediation::mediate)

**Implementation**:
```r
#' Fit or Extract Mediation Structure
#'
#' @param outcome Outcome formula (Y ~ X + M + C) or fitted model
#' @param mediator Mediator formula (M ~ X + C) or fitted model
#' @param data Data frame (when using formulas)
#' @param treatment Character: treatment variable name
#' @param ... Additional arguments
#' @return MediationData or SerialMediationData object
#' @export
mediate <- function(outcome, ...) {
  UseMethod("mediate")
}

# S7 method for data frames (fit models)
S7::method(mediate, new_S3_class("data.frame")) <- function(outcome, mediator,
                                                             data = outcome,
                                                             treatment, ...) {
  fit_mediation(formula_y = outcome, formula_m = mediator,
               data = data, treatment = treatment, ...)
}

# S7 method for lm objects (extract from models)
S7::method(mediate, new_S3_class("lm")) <- function(outcome, mediator,
                                                     treatment, ...) {
  extract_mediation(object = outcome, model_y = mediator,
                   treatment = treatment, ...)
}
```

---

### Path Extraction Function

**Recommendation**: **Keep `paths()`**

**Rationale**:
- Short, memorable
- Clear in mediation context
- No major conflicts
- Natural complement to `coef()`

**Implementation**:
```r
#' Extract Path Coefficients
#'
#' @param object MediationData or SerialMediationData object
#' @param ... Additional arguments
#' @return Named list with path coefficients (a, b, c_prime, indirect, total)
#' @export
paths <- function(object, ...) {
  UseMethod("paths")
}

# S7 method for MediationData
S7::method(paths, MediationData) <- function(object, ...) {
  list(
    a = object@a_path,
    b = object@b_path,
    c_prime = object@c_prime,
    indirect = object@a_path * object@b_path,
    total = object@c_prime + (object@a_path * object@b_path)
  )
}

# S7 method for SerialMediationData
S7::method(paths, SerialMediationData) <- function(object, ...) {
  # Product of all paths in chain
  indirect <- object@a_path * prod(object@d_path) * object@b_path

  list(
    a = object@a_path,
    d = object@d_path,
    b = object@b_path,
    c_prime = object@c_prime,
    indirect = indirect,
    total = object@c_prime + indirect
  )
}
```

---

## Summary: Revised ADHD-Friendly API

```r
library(medfit)

# Workflow function: mediate() (clear verb)
result <- mtcars %>%
  mediate(mpg ~ hp + disp, disp ~ hp, treatment = "hp") %>%
  boot() %>%
  confint()

# Standard generics (ecosystem)
coef(result)      # All parameters
vcov(result)      # Variance-covariance
confint(result)   # Confidence intervals
summary(result)   # Model summary

# Custom generics (mediation-specific)
paths(result)           # Just mediation paths (a, b, c', indirect)
indirect_effect(result) # Indirect effect (scalar)
direct_effect(result)   # Direct effect (scalar)
total_effect(result)    # Total effect (scalar)
```

**ADHD-friendly score**: ✅✅✅ Excellent
- Clear function names
- Pipeline friendly
- Minimal typing
- No ambiguity
- Standard generics for ecosystem
- Custom generics for mediation-specific

---

## Next Steps

1. **User feedback**: Does `mediate()` feel right, or prefer `medfit()`?
2. **Confirm `paths()`**: Is this name clear?
3. **Implementation**: Create `mediate()` and `paths()` generics with S7 methods
4. **Documentation**: Update vignettes with new workflow

**Question for user**: Do you prefer `mediate()` or `medfit()` for the main workflow function?
