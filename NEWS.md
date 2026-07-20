# medfit 0.3.2 (2026-07-20)

CRAN patch release. No new features; CI/lint compatibility and CRAN
compliance fixes only (no non-whitespace change to `R/`).

## CI and lint

* Fixed `lint` job breakage from lintr 3.4.0's tightened `indentation_linter`
  (reindented function signatures 4 -> 2 spaces; whitespace only,
  `git diff -w` empty).
* Re-documented with roxygen2 8.0.0 (`RoxygenNote` -> `Config/roxygen2/version`).

## CRAN compliance

* Fixed a stale `Date` field (CRAN incoming-feasibility check flags dates
  over a month old).
* `.Rbuildignore`d the `.remember` session-memory scratch directory, which
  was leaking into the built source tarball (`.Rbuildignore` is independent
  of `.gitignore`).
* Added `inst/WORDLIST` entries for domain vocabulary (VanderWeele
  decomposition acronyms, S7 class names, DOI journal-code fragments) that
  `spelling::spell_check_package()`/CRAN's `aspell` pass would flag.
* Added `.aspell/defaults.R` to suppress a "possibly misspelled" NOTE on the
  cited author surname "VanderWeele" in the DESCRIPTION field (a separate
  aspell mechanism from `inst/WORDLIST`).

# medfit 0.3.1 (2026-06-11)

## New features

* `fit_mediation()` gains a `weights=` argument and a `se_type=` argument
  (`"model"` default, or `"sandwich"` for robust SEs), enabling IPW-weighted
  estimation. Unweighted calls are byte-identical to 0.3.0. Consumed by
  `missingmed`'s IPW estimator — downstream packages should require
  `medfit (>= 0.3.1)` when they pass `weights=`/`se_type=`.
  * `se_type = "sandwich"` uses the suggested \pkg{sandwich} package
    (`vcovHC`, HC3); it is required only on that opt-in path, so \pkg{sandwich}
    is a `Suggests` dependency, not `Imports`.
  * Supplying `weights=` with the default `se_type = "model"` emits a one-time
    advisory message, since model-based SEs are not valid under IPW.

# medfit 0.3.0 (2026-06-06)

## New features

* `MediationData` now carries the GLM `family`/link of the mediator and outcome
  models in new `family_m` and `family_y` properties (populated by the lm/glm
  and lavaan extractors; default `NULL` is treated as Gaussian). This lets
  scale-free estimands such as `probmed::pmed()` simulate non-Gaussian
  potential outcomes on the correct (e.g. logit) scale rather than discarding
  the link. Backward compatible: existing constructors that omit the families
  continue to work.

* New S7 class `InteractionMediationData` for simple mediation **with a
  treatment-by-mediator interaction** (`X:M` in the outcome model), carrying
  VanderWeele's (2014) four-way decomposition of the total effect into
  controlled direct effect (CDE), reference interaction (INTref), mediated
  interaction (INTmed), and pure indirect effect (PIE), with
  `NDE = CDE + INTref` and `NIE = INTmed + PIE`. The class validator enforces
  both the aggregate identities and the path ties (`INTmed = theta3 * beta1`,
  `PIE = theta2 * beta1`, `CDE = theta1 + theta3 * m*`), so an inconsistent
  decomposition is rejected at construction. Effect extractors (`nie`, `nde`,
  `te`, `pm`) have methods for the new class, plus a new `decompose()` generic
  returning all four components and the derived effects.

* `extract_mediation()` now builds `InteractionMediationData` from **lm/glm**
  fits whose outcome model contains an `X:M` term. A new `decomposition`
  argument (`"auto"` default / `"four_way"` / `"two_way"`) controls detection,
  and `m_star` sets the reference mediator level. Continuous (Gaussian) mediator
  and outcome are supported (non-Gaussian models error with a clear message);
  the no-interaction path is unchanged. The companion `confint()` method gives
  delta-method intervals for `parm = "paths"`, `"components"` (the four-way
  CDE/INTref/INTmed/PIE), and `"effects"` (NDE/NIE/TE).

* `extract_mediation()` also builds `InteractionMediationData` from a **lavaan**
  fit. The interaction enters as a product variable named via the `interaction`
  argument, and the model must be fit with `meanstructure = TRUE` (the mediator
  intercept is needed for INTref). Because the SEM is estimated jointly, the
  extracted `@vcov` carries the full joint covariance of the paths. A
  "treatment-mediator interaction" section was added to the extraction article.

* New S7 class `ParallelMediationData` for **parallel mediation**
  (`X -> M_j -> Y` for independent mediators `j = 1..k`). The total indirect
  effect is the sum of per-mediator products, `sum(a_j * b_j)`. Completes the
  structural trio alongside `MediationData` (simple) and `SerialMediationData`
  (serial). Effect extractors (`nie`, `nde`, `te`, `pm`, `paths`) have methods
  for the new class; `paths()` returns interleaved `a1, b1, a2, b2, ..., c_prime`.

* `extract_mediation()` now builds `ParallelMediationData` from **lm/glm** fits:
  pass the per-mediator models via `mediator_models` and the new
  `structure = "parallel"` argument. `structure = "auto"` (default) infers serial
  vs parallel from the mediator models' predictors, defaulting to serial unless
  there is positive evidence of a parallel structure.
  The returned `@vcov` is named `a1, b1, ..., c_prime`; the `b_j` (jointly fit in
  the outcome model) keep their mutual covariances and `cov(b_j, c')`, while the
  `a_j` (separate mediator regressions) are independent.

* `extract_mediation()` also builds `ParallelMediationData` from a single
  **lavaan** `sem()` fit: pass a `mediator` vector and (optionally)
  `structure = "parallel"`. `structure = "auto"` infers parallel vs serial from
  the SEM's regression rows. Because the system is estimated jointly, the
  extracted `@vcov` preserves **all** off-diagonals — including `cov(a_j, b_j)`
  and `cov(a_j, a_{j'})` — so SEs reflect the full joint covariance (and differ
  from the block-diagonal lm/glm engine for identical data).

* New `confint()` method for `ParallelMediationData` (`parm = "paths"` or
  `"effects"`). The indirect-effect variance uses the delta method over the full
  `{a1, b1, ..., ak, bk}` covariance block, so correlated `b_j` are handled
  correctly; `method = "boot"` directs to `bootstrap_mediation()`.

## Bug Fixes

* `print(summary(x))` now shows the formatted summary for `MediationData`,
  `BootstrapResult`, and `SerialMediationData` instead of dumping the raw list.
  The `print.summary.*` S3 methods exist and are correct, but their
  `S3method()` NAMESPACE directives are not activated once `print` participates
  in S7 dispatch, so `print()` silently fell back to `print.default`. They are
  now registered explicitly in `.onLoad()` (the same fix already used for
  `print.mediation_effect`), so dispatch works whether the package is installed
  or loaded via `load_all()`.

## Internal

* `R CMD check` is clean again (0 errors / 0 warnings / 0 notes). Added
  `@usage NULL` to the `BootstrapResult`, `ParallelMediationData`, and
  `InteractionMediationData` class docs (matching `MediationData` /
  `SerialMediationData`), which removes spurious codoc mismatches from the S7
  constructors' complex property defaults. The `show` method bodies registered
  in `.onLoad()` now delegate to a top-level helper (`.show_via_print()`) so no
  literal `print()` call sits in `.onLoad`, clearing the "startup functions
  should use packageStartupMessage" note.

## CRAN compliance and dependencies

* Moved **MASS** from `Suggests` to `Imports`: the default parametric bootstrap
  (`bootstrap_mediation(method = "parametric")`) calls `MASS::mvrnorm()`
  unconditionally, so MASS must always be available (it previously failed under
  CRAN's "noSuggests" check flavor).
* Documentation/CRAN fixes (forward-ported from the 0.2.1 CRAN resubmission):
  added `\value` to the exported `print`/`print.summary.*` methods; converted
  `\dontrun{}` examples to self-contained `\donttest{}` (the lavaan example
  guarded with `requireNamespace()`); spelled out the "GLM" acronym and added
  method references (`<doi:...>`) to the Description; enriched `inst/CITATION`.

# medfit 0.2.1 (2026-06-18)

CRAN patch release. No new features; documentation and compliance fixes only
(all changes forward-ported to 0.3.0).

## CRAN compliance and documentation

* Explained the "GLM" acronym in the package Description.
* Added method references (`<doi:...>`) to the Description field
  (MacKinnon, Lockwood & Williams 2004; Tofighi & MacKinnon 2011).
* Added `\value` sections to the four exported `print` / `print.summary.*`
  methods.
* Converted `\dontrun{}` examples to self-contained `\donttest{}` (lavaan
  example guarded with `requireNamespace()`).
* Enriched `inst/CITATION` with method references and ORCID.
* Moved **MASS** from `Suggests` to `Imports`: the default parametric bootstrap
  calls `MASS::mvrnorm()` unconditionally, so MASS must always be available.

# medfit 0.2.0 (2026-05-31)

## New features

* `extract_mediation()` now supports **serial mediation**
  (`X -> M1 -> M2 -> ... -> Mk -> Y`), returning a `SerialMediationData` object.
  For **lavaan** fits, pass an ordered vector of mediator names
  (`mediator = c("M1", "M2")`); for **lm/glm** sequential regressions, pass the
  per-mediator models via the new `mediator_models` argument. The returned
  `@vcov` is named with the path aliases `a`, `d1`, ..., `b`, `c_prime` and
  preserves the full covariance structure (single-equation lavaan SEM keeps the
  off-diagonals; the separately-fitted lm equations are block-diagonal among
  chain paths with `cov(b, c')` preserved), so downstream serial
  indirect-effect confidence intervals are correct.

## Bug Fixes

* `extract_mediation()` for lavaan models now preserves the **off-diagonal**
  covariances among the `a`, `b`, and `c_prime` path aliases in the returned
  `@vcov`. Previously only the diagonal variances were copied, so
  `vcov[c("a", "b"), c("a", "b")]` reported `cov(a, b) = 0` even when the
  underlying lavaan fit had a genuinely non-zero covariance (e.g. single-equation
  SEM with correlated residuals, or the within-equation `cov(b, c')`). This
  silently biased downstream indirect-effect confidence intervals; the alias
  block now reproduces the true `lavaan::vcov()` covariances exactly.

* `print()` on the effect objects returned by `nie()`, `nde()`, `te()`, and
  `pm()` (class `mediation_effect`) now reliably shows the formatted label
  (e.g. `Natural Indirect Effect (NIE): 0.1897`). Because `mediation_effect`
  is layered on the base `numeric` type, S3 dispatch could miss
  `print.mediation_effect` and fall back to the bare numeric value plus raw
  attributes. The method is now explicitly registered in `.onLoad()` so
  dispatch works whether the package is installed or loaded via `load_all()`.

* The **lm/glm** extractor now copies the full within-equation covariance onto
  the `a`/`b`/`c_prime` aliases, so `cov(b, c_prime)` is preserved (previously
  only the diagonal variance was copied). The indirect effect `a * b` is
  unchanged; `cov(a, b)` remains `0` (separate equations).

## Internal

* Overall test coverage raised to >90% (enforced via `codecov`), and all
  repo-wide `lintr` warnings cleared. A shared alias-vcov helper
  (`.expand_vcov_with_aliases()`) now backs both the lm/glm and lavaan
  extractors so the two engines cannot drift.


# medfit 0.1.0 (2025-12-20)

**Initial CRAN release**

## Overview

medfit provides S7-based infrastructure for fitting mediation models, extracting path coefficients, and performing bootstrap inference. It serves as the foundation package for the mediationverse ecosystem.

## Major Features

### User-Friendly API

* **`med()` function** - Recommended entry point for most users
  - Fits mediator and outcome models automatically
  - Optional bootstrap inference with `boot = TRUE`
  - Supports covariates and different model families
  - Example: `med(data, treatment = "X", mediator = "M", outcome = "Y")`

* **`quick()` function** - One-line summary of results
  - Compact display: `NIE = 0.19 [0.08, 0.32] | NDE = 0.16 | PM = 55%`
  - Works with all medfit objects

### Effect Extractors

* **Dedicated functions for mediation effects**
  - `nie()`: Natural Indirect Effect (a × b)
  - `nde()`: Natural Direct Effect (c')
  - `te()`: Total Effect
  - `pm()`: Proportion Mediated
  - `paths()`: Path coefficients (a, b, c')

### Model Fitting and Extraction

* **`fit_mediation()` function** - Fit mediation models with formula interface
  - GLM engine for linear and generalized linear models
  - Support for continuous and binary outcomes
  - Covariates in both mediator and outcome models
  - Returns `MediationData` object

* **`extract_mediation()` generic** - Extract from fitted models
  - Methods for lm, glm objects
  - Optional lavaan support (when installed)
  - Extracts path coefficients and variance-covariance matrices

### Bootstrap Inference

* **`bootstrap_mediation()` function** - Three bootstrap methods
  - **Parametric**: Fast, assumes multivariate normality
  - **Nonparametric**: Robust, resamples data and refits models
  - **Plugin**: Point estimate only
  - Parallel processing support
  - Returns `BootstrapResult` with confidence intervals

### Tidyverse and Base R Integration

* **`tidy()` and `glance()` methods** for broom compatibility
  - `tidy()`: Convert to tibble (paths, effects, or both)
  - `tidy(conf.int = TRUE)`: Include confidence intervals
  - `glance()`: One-row model summary

* **Base R generics**: `coef()`, `vcov()`, `confint()`, `nobs()`

### S7 Class Architecture

* **Modern S7 object system** for type safety and extensibility
  - `MediationData`: Simple mediation (X → M → Y)
  - `SerialMediationData`: Serial mediation (X → M1 → M2 → ... → Y)
  - `BootstrapResult`: Bootstrap inference results
  - All classes include validators, print, summary, and show methods

### Input Validation

* **Defensive programming** with `checkmate` package
  - Fast, informative error messages
  - All user-facing functions validate inputs
  - Complements S7 class validators

## Documentation

* **Four comprehensive articles** (on the package website)
  - Getting Started: Quick introduction with examples
  - Introduction: Detailed package overview
  - Model Extraction: Extract from lm, glm, lavaan objects
  - Bootstrap Inference: Parametric and nonparametric methods

* **pkgdown website**: https://data-wise.github.io/medfit/

## Testing and Quality

* **427 comprehensive tests** (0 errors, 0 warnings)
  - Full coverage of S7 classes and methods
  - Validation tests for data integrity
  - Edge case handling

* **CI/CD**: GitHub Actions workflows
  - R CMD check on Ubuntu, macOS, Windows
  - Test coverage tracking with Codecov
  - Automated pkgdown deployment

## Ecosystem

* Foundation package for the **mediationverse** ecosystem
* Supports future integration with probmed, RMediation, medrobust
* Tested with R >= 4.1.0, S7 >= 0.1.0
