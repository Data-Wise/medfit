# S7 Class Definitions for medfit
#
# This file defines the core S7 classes:
# - MediationData: Container for simple mediation model structure (X -> M -> Y)
# - SerialMediationData: Container for serial mediation model structure (X -> M1 -> M2 -> ... -> Y)
# - BootstrapResult: Container for bootstrap inference results
#
# Design Philosophy:
# - Separate classes for different mediation structures (simple vs serial vs parallel)
# - Each class optimized for its specific use case
# - Extensible design allowing future addition of ParallelMediationData, ComplexMediationData
# - Consistent interface across all classes (estimates, vcov, metadata)

#' MediationData S7 Class
#'
#' @description
#' S7 class containing standardized mediation model structure, including
#' path coefficients, parameter estimates, variance-covariance matrix,
#' and metadata.
#'
#' @param a_path Numeric scalar: effect of treatment on mediator (a path)
#' @param b_path Numeric scalar: effect of mediator on outcome (b path)
#' @param c_prime Numeric scalar: direct effect of treatment on outcome (c' path)
#' @param estimates Numeric vector: all parameter estimates
#' @param vcov Numeric matrix: variance-covariance matrix of estimates
#' @param sigma_m Numeric scalar or NULL: residual SD for mediator model
#' @param sigma_y Numeric scalar or NULL: residual SD for outcome model
#' @param family_m GLM `family` object (or NULL): family/link for the mediator
#'   model (e.g. `gaussian()`, `binomial()`). Defaults to unset (empty), which
#'   consumers treat as Gaussian.
#' @param family_y GLM `family` object (or NULL): family/link for the outcome
#'   model. Required by scale-free estimands (e.g. probmed) to simulate
#'   non-Gaussian potential outcomes on the correct scale. Defaults to unset
#'   (empty), treated as Gaussian.
#' @param treatment Character scalar: name of treatment variable
#' @param mediator Character scalar: name of mediator variable
#' @param outcome Character scalar: name of outcome variable
#' @param mediator_predictors Character vector: predictor names in mediator model
#' @param outcome_predictors Character vector: predictor names in outcome model
#' @param data Data frame or NULL: original data
#' @param n_obs Integer scalar: number of observations
#' @param converged Logical scalar: whether models converged
#' @param source_package Character scalar: package/engine used for fitting
#'
#' @return A MediationData S7 object
#' @usage
#' MediationData(a_path, b_path, c_prime, estimates, vcov, sigma_m, sigma_y,
#'   family_m, family_y, treatment, mediator, outcome, mediator_predictors,
#'   outcome_predictors, data, n_obs, converged, source_package)
#'
#' @details
#' This class provides a unified container for mediation model information
#' extracted from various model types (lm, glm, lavaan, etc.).
#' It ensures consistency across the mediation analysis ecosystem.
#'
#' The class includes comprehensive validation to ensure data integrity.
#'
#' @examples
#' \donttest{
#' # Create a MediationData object
#' med_data <- MediationData(
#'   a_path = 0.5,
#'   b_path = 0.3,
#'   c_prime = 0.2,
#'   estimates = c(0.5, 0.3, 0.2),
#'   vcov = diag(3) * 0.01,
#'   sigma_m = 1.0,
#'   sigma_y = 1.2,
#'   treatment = "X",
#'   mediator = "M",
#'   outcome = "Y",
#'   mediator_predictors = "X",
#'   outcome_predictors = c("X", "M"),
#'   data = NULL,
#'   n_obs = 100L,
#'   converged = TRUE,
#'   source_package = "stats"
#' )
#' }
#'
#' @export
MediationData <- S7::new_class(
  "MediationData",
  package = "medfit",
  properties = list(
    # Core paths
    a_path = S7::class_numeric,
    b_path = S7::class_numeric,
    c_prime = S7::class_numeric,

    # Parameters
    estimates = S7::class_numeric,
    vcov = S7::new_S3_class("matrix"),

    # Residual variances (for Gaussian models)
    sigma_m = S7::class_numeric | NULL,
    sigma_y = S7::class_numeric | NULL,

    # GLM family/link objects (for non-Gaussian potential-outcome simulation).
    # A stats `family` is an S3 list; we type these as list | NULL and enforce
    # the `family` class in the validator. (`new_S3_class("family")` would
    # require a constructor.) The default is the empty list() prototype, which
    # consumers treat as Gaussian -- we deliberately avoid a rich object such as
    # `gaussian()` as the default, because an S7 property default that embeds
    # functions/environments loses its class under covr instrumentation.
    family_m = S7::class_list | NULL,
    family_y = S7::class_list | NULL,

    # Variable names
    treatment = S7::class_character,
    mediator = S7::class_character,
    outcome = S7::class_character,
    mediator_predictors = S7::class_character,
    outcome_predictors = S7::class_character,

    # Data and metadata
    data = S7::class_data.frame | NULL,
    n_obs = S7::class_integer,
    converged = S7::class_logical,
    source_package = S7::class_character
  ),

  validator = function(self) {
    # Validate paths are scalar
    if (length(self@a_path) != 1) {
      return("a_path must be a scalar numeric value")
    }
    if (length(self@b_path) != 1) {
      return("b_path must be a scalar numeric value")
    }
    if (length(self@c_prime) != 1) {
      return("c_prime must be a scalar numeric value")
    }

    # Validate vcov is square
    if (nrow(self@vcov) != ncol(self@vcov)) {
      return("vcov must be a square matrix")
    }

    # Validate estimates and vcov dimensions match
    if (length(self@estimates) != nrow(self@vcov)) {
      return("Number of estimates must match vcov dimensions")
    }

    # Validate sigma values if provided
    if (!is.null(self@sigma_m)) {
      if (length(self@sigma_m) != 1 || self@sigma_m < 0) {
        return("sigma_m must be a non-negative scalar")
      }
    }
    if (!is.null(self@sigma_y)) {
      if (length(self@sigma_y) != 1 || self@sigma_y < 0) {
        return("sigma_y must be a non-negative scalar")
      }
    }

    # Validate family objects if provided. The empty list() default (and NULL)
    # both mean "unset" and are treated as Gaussian by consumers, so only a
    # non-empty value that is not a `family` object is rejected.
    if (length(self@family_m) > 0 && !inherits(self@family_m, "family")) {
      return("family_m must be a stats 'family' object or NULL")
    }
    if (length(self@family_y) > 0 && !inherits(self@family_y, "family")) {
      return("family_y must be a stats 'family' object or NULL")
    }

    # Validate variable names are scalar
    if (length(self@treatment) != 1) {
      return("treatment must be a single character string")
    }
    if (length(self@mediator) != 1) {
      return("mediator must be a single character string")
    }
    if (length(self@outcome) != 1) {
      return("outcome must be a single character string")
    }

    # Validate n_obs
    if (length(self@n_obs) != 1 || self@n_obs < 1) {
      return("n_obs must be a positive integer")
    }

    # Validate data if provided
    if (!is.null(self@data)) {
      if (nrow(self@data) != self@n_obs) {
        return("Number of rows in data must match n_obs")
      }
    }

    # Validate converged is logical scalar
    if (length(self@converged) != 1) {
      return("converged must be a single logical value")
    }

    # If all checks pass, return NULL
    NULL
  }
)

# Register with S4 for compatibility
S7::S4_register(MediationData)


#' SerialMediationData S7 Class
#'
#' @description
#' S7 class for serial mediation models where the effect flows through
#' multiple mediators in sequence: X -> M1 -> M2 -> ... -> Mk -> Y.
#'
#' This class supports serial mediation chains of any length, from simple
#' two-mediator models (product-of-three: a * d * b) to complex chains
#' with many mediators (product-of-k).
#'
#' @param a_path Numeric scalar: effect of treatment on first mediator (X -> M1)
#' @param d_path Numeric vector: sequential mediator-to-mediator effects
#'   - For 2 mediators (X -> M1 -> M2 -> Y): scalar d21 (M1 -> M2)
#'   - For 3 mediators (X -> M1 -> M2 -> M3 -> Y): c(d21, d32)
#'   - For k mediators: vector of length (k-1)
#' @param b_path Numeric scalar: effect of last mediator on outcome (Mk -> Y)
#' @param c_prime Numeric scalar: direct effect of treatment on outcome (X -> Y)
#' @param estimates Numeric vector: all parameter estimates
#' @param vcov Numeric matrix: variance-covariance matrix of estimates
#' @param sigma_mediators Numeric vector or NULL: residual SDs for mediator models.
#'   Length should match number of mediators. First element is residual SD for M1 model,
#'   second element for M2 model, etc.
#' @param sigma_y Numeric scalar or NULL: residual SD for outcome model
#' @param treatment Character scalar: name of treatment variable
#' @param mediators Character vector: names of mediators in sequential order.
#'   First element is M1, second element is M2, etc.
#' @param outcome Character scalar: name of outcome variable
#' @param mediator_predictors List of character vectors: predictor names for each mediator model.
#'   First list element contains predictors for M1 (typically just "X"),
#'   second element contains predictors for M2 (typically c("X", "M1")), etc.
#' @param outcome_predictors Character vector: predictor names in outcome model
#' @param data Data frame or NULL: original data
#' @param n_obs Integer scalar: number of observations
#' @param converged Logical scalar: whether all models converged
#' @param source_package Character scalar: package/engine used for fitting
#'
#' @return A SerialMediationData S7 object
#' @usage
#' SerialMediationData(a_path, d_path, b_path, c_prime, estimates, vcov,
#'   sigma_mediators, sigma_y, treatment, mediators, outcome,
#'   mediator_predictors, outcome_predictors, data, n_obs, converged,
#'   source_package)
#'
#' @details
#' ## Serial Mediation Structure
#'
#' Serial mediation models the indirect effect flowing through a sequence of
#' mediators. The indirect effect through the full chain is the product of the
#' chain's path coefficients:
#'
#' - **2 mediators (product-of-three)**: Indirect = a * d * b
#' - **3 mediators (product-of-four)**: Indirect = a * d21 * d32 * b
#' - **k mediators (product-of-k+1)**: Indirect = a * d21 * d32 * ... * d(k,k-1) * b
#'
#' This is the effect through the chain only, and what [nie()] returns by
#' default. Paths that skip a mediator (`X -> M2`, `M1 -> Y`, ...) are not part
#' of it; `nie(x, type = "total")` adds them, and [te()] is the full total
#' effect over every path, so `pm()` is the total indirect share of it. With
#' treatment-by-mediator products in the outcome model, [extract_mediation()]
#' returns a [JointMediationData] object with the effect through all the
#' mediators together.
#'
#' ## Path Notation
#'
#' - `a`: Treatment -> First mediator (X -> M1)
#' - `d21`: First -> Second mediator (M1 -> M2)
#' - `d32`: Second -> Third mediator (M2 -> M3)
#' - `dji`: Previous mediator -> Current mediator
#' - `b`: Last mediator -> Outcome (Mk -> Y)
#' - `c'`: Direct effect (X -> Y, controlling for all mediators)
#'
#' ## Extensibility
#'
#' This class is designed to handle serial chains of any length:
#' - Minimal case: 2 mediators (length(d_path) = 1)
#' - No upper limit on chain length
#' - Validator ensures consistency between mediators and paths
#'
#' @examples
#' \donttest{
#' # Two-mediator serial mediation (X -> M1 -> M2 -> Y)
#' # Product-of-three: a * d * b
#' serial_data <- SerialMediationData(
#'   a_path = 0.5,       # X -> M1
#'   d_path = 0.4,       # M1 -> M2 (scalar for 2 mediators)
#'   b_path = 0.3,       # M2 -> Y
#'   c_prime = 0.1,      # X -> Y (direct)
#'   estimates = c(0.5, 0.4, 0.3, 0.1),
#'   vcov = diag(4) * 0.01,
#'   sigma_mediators = c(1.0, 1.1),  # SD for M1, M2 models
#'   sigma_y = 1.2,
#'   treatment = "X",
#'   mediators = c("M1", "M2"),
#'   outcome = "Y",
#'   mediator_predictors = list(
#'     c("X"),           # M1 ~ X
#'     c("X", "M1")      # M2 ~ X + M1
#'   ),
#'   outcome_predictors = c("X", "M1", "M2"),  # Y ~ X + M1 + M2
#'   data = NULL,
#'   n_obs = 100L,
#'   converged = TRUE,
#'   source_package = "lavaan"
#' )
#'
#' # Three-mediator serial mediation (X -> M1 -> M2 -> M3 -> Y)
#' # Product-of-four: a * d21 * d32 * b
#' serial_data_3 <- SerialMediationData(
#'   a_path = 0.5,           # X -> M1
#'   d_path = c(0.4, 0.35),  # M1 -> M2, M2 -> M3 (vector for 3 mediators)
#'   b_path = 0.3,           # M3 -> Y
#'   c_prime = 0.1,
#'   estimates = c(0.5, 0.4, 0.35, 0.3, 0.1),
#'   vcov = diag(5) * 0.01,
#'   sigma_mediators = c(1.0, 1.1, 1.05),  # SD for M1, M2, M3 models
#'   sigma_y = 1.2,
#'   treatment = "X",
#'   mediators = c("M1", "M2", "M3"),
#'   outcome = "Y",
#'   mediator_predictors = list(
#'     c("X"),              # M1 ~ X
#'     c("X", "M1"),        # M2 ~ X + M1
#'     c("X", "M1", "M2")   # M3 ~ X + M1 + M2
#'   ),
#'   outcome_predictors = c("X", "M1", "M2", "M3"),
#'   data = NULL,
#'   n_obs = 100L,
#'   converged = TRUE,
#'   source_package = "lavaan"
#' )
#' }
#'
#' @export
SerialMediationData <- S7::new_class(
  "SerialMediationData",
  package = "medfit",
  properties = list(
    # Core paths (serial chain)
    a_path = S7::class_numeric,       # nolint: commented_code_linter.
    d_path = S7::class_numeric,       # nolint: commented_code_linter.
    b_path = S7::class_numeric,       # nolint: commented_code_linter.
    c_prime = S7::class_numeric,      # nolint: commented_code_linter.

    # Parameters (all models)
    estimates = S7::class_numeric,
    vcov = S7::new_S3_class("matrix"),

    # Residual variances (for Gaussian models)
    sigma_mediators = S7::class_numeric | NULL,  # Vector for each mediator
    sigma_y = S7::class_numeric | NULL,

    # Variable names
    treatment = S7::class_character,
    mediators = S7::class_character,   # Vector of mediator names (in order)
    outcome = S7::class_character,
    mediator_predictors = S7::class_list,  # List of predictor vectors
    outcome_predictors = S7::class_character,

    # Data and metadata
    data = S7::class_data.frame | NULL,
    n_obs = S7::class_integer,
    converged = S7::class_logical,
    source_package = S7::class_character
  ),

  validator = function(self) {
    # Get number of mediators
    n_mediators <- length(self@mediators)

    # Must have at least 2 mediators for serial mediation
    if (n_mediators < 2) {
      return("Serial mediation requires at least 2 mediators")
    }

    # Validate path scalars
    if (length(self@a_path) != 1) {
      return("a_path must be a scalar (X -> M1)")
    }
    if (length(self@b_path) != 1) {
      return("b_path must be a scalar (Mk -> Y)")
    }
    if (length(self@c_prime) != 1) {
      return("c_prime must be a scalar (X -> Y)")
    }

    # Validate d_path length matches number of mediators
    # For k mediators, need (k-1) d paths: M1->M2, M2->M3, ..., M(k-1)->Mk
    expected_d_length <- n_mediators - 1
    if (length(self@d_path) != expected_d_length) {
      return(sprintf(
        "d_path must have length %d for %d mediators (found length %d)",
        expected_d_length, n_mediators, length(self@d_path)
      ))
    }

    # Validate vcov is square
    if (nrow(self@vcov) != ncol(self@vcov)) {
      return("vcov must be a square matrix")
    }

    # Validate estimates and vcov dimensions match
    if (length(self@estimates) != nrow(self@vcov)) {
      return("Number of estimates must match vcov dimensions")
    }

    # Validate sigma_mediators if provided
    if (!is.null(self@sigma_mediators)) {
      if (length(self@sigma_mediators) != n_mediators) {
        return(sprintf(
          "sigma_mediators must have length %d (one for each mediator), found %d",
          n_mediators, length(self@sigma_mediators)
        ))
      }
      if (any(self@sigma_mediators < 0, na.rm = TRUE)) {
        return("All sigma_mediators values must be non-negative")
      }
    }

    # Validate sigma_y if provided
    if (!is.null(self@sigma_y)) {
      if (length(self@sigma_y) != 1 || self@sigma_y < 0) {
        return("sigma_y must be a non-negative scalar")
      }
    }

    # Validate variable names
    if (length(self@treatment) != 1) {
      return("treatment must be a single character string")
    }
    if (length(self@outcome) != 1) {
      return("outcome must be a single character string")
    }

    # Validate mediators are all unique
    if (length(unique(self@mediators)) != n_mediators) {
      return("All mediator names must be unique")
    }

    # Validate mediator_predictors is a list with correct length
    if (!is.list(self@mediator_predictors)) {
      return("mediator_predictors must be a list")
    }
    if (length(self@mediator_predictors) != n_mediators) {
      return(sprintf(
        "mediator_predictors must have length %d (one for each mediator), found %d",
        n_mediators, length(self@mediator_predictors)
      ))
    }

    # Validate n_obs
    if (length(self@n_obs) != 1 || self@n_obs < 1) {
      return("n_obs must be a positive integer")
    }

    # Validate data if provided
    if (!is.null(self@data)) {
      if (nrow(self@data) != self@n_obs) {
        return("Number of rows in data must match n_obs")
      }
    }

    # Validate converged is logical scalar
    if (length(self@converged) != 1) {
      return("converged must be a single logical value")
    }

    # If all checks pass, return NULL
    NULL
  }
)

# Register with S4 for compatibility
S7::S4_register(SerialMediationData)


#' BootstrapResult S7 Class
#'
#' @description
#' S7 class containing results from bootstrap inference, including
#' point estimates, confidence intervals, and bootstrap distribution.
#'
#' @param estimate Numeric scalar: point estimate of the statistic
#' @param ci_lower Numeric scalar: lower bound of confidence interval
#' @param ci_upper Numeric scalar: upper bound of confidence interval
#' @param ci_level Numeric scalar: confidence level (e.g., 0.95 for 95% CI)
#' @param boot_estimates Numeric vector: bootstrap distribution of estimates
#' @param n_boot Integer scalar: number of bootstrap samples
#' @param method Character scalar: bootstrap method
#'   ("parametric", "nonparametric", or "plugin")
#' @param call Call object or NULL: original function call
#'
#' @return A BootstrapResult S7 object
#' @usage
#' BootstrapResult(estimate, ci_lower, ci_upper, ci_level, boot_estimates,
#'   n_boot, method, call)
#'
#' @details
#' This class standardizes bootstrap inference results across different
#' bootstrap methods (parametric, nonparametric, plugin).
#'
#' The class includes validation to ensure consistency between
#' method type and required fields.
#'
#' @examples
#' \donttest{
#' # Parametric bootstrap result
#' result <- BootstrapResult(
#'   estimate = 0.15,
#'   ci_lower = 0.10,
#'   ci_upper = 0.20,
#'   ci_level = 0.95,
#'   boot_estimates = rnorm(1000, 0.15, 0.02),
#'   n_boot = 1000L,
#'   method = "parametric",
#'   call = NULL
#' )
#' }
#'
#' @export
BootstrapResult <- S7::new_class(
  "BootstrapResult",
  package = "medfit",
  properties = list(
    # Point estimates
    estimate = S7::class_numeric,

    # Confidence intervals
    ci_lower = S7::class_numeric,
    ci_upper = S7::class_numeric,
    ci_level = S7::class_numeric,

    # Bootstrap distribution
    boot_estimates = S7::class_numeric,
    n_boot = S7::class_integer,

    # Method
    method = S7::class_character,

    # Metadata
    call = S7::class_call | NULL
  ),

  validator = function(self) {
    # Validate estimate is scalar
    if (length(self@estimate) != 1) {
      return("estimate must be a scalar numeric value")
    }

    # Validate CI bounds
    if (length(self@ci_lower) != 1) {
      return("ci_lower must be a scalar numeric value")
    }
    if (length(self@ci_upper) != 1) {
      return("ci_upper must be a scalar numeric value")
    }

    # Validate method BEFORE any `self@method != ...` branch below: a non-scalar
    # method would make those `if` conditions length > 1, which is an R error
    # rather than this validator's own message.
    if (length(self@method) != 1) {
      return("method must be a single character string")
    }
    if (!(self@method %in% c("parametric", "nonparametric", "plugin"))) {
      return("method must be 'parametric', 'nonparametric', or 'plugin'")
    }

    # For non-plugin methods, check CI ordering
    if (self@method != "plugin") {
      if (!is.na(self@ci_lower) && !is.na(self@ci_upper)) {
        if (self@ci_lower > self@ci_upper) {
          return("ci_lower must be less than or equal to ci_upper")
        }
      }
    }

    # Validate ci_level
    if (length(self@ci_level) != 1) {
      return("ci_level must be a scalar numeric value")
    }
    if (self@method != "plugin") {
      if (!is.na(self@ci_level)) {
        if (self@ci_level <= 0 || self@ci_level >= 1) {
          return("ci_level must be between 0 and 1 (exclusive)")
        }
      }
    }

    # Validate n_boot
    if (length(self@n_boot) != 1) {
      return("n_boot must be a single integer")
    }
    if (self@method != "plugin" && self@n_boot < 1) {
      return("n_boot must be positive for parametric and nonparametric methods")
    }

    # Validate boot_estimates length matches n_boot (except for plugin)
    if (self@method != "plugin") {
      if (length(self@boot_estimates) != self@n_boot) {
        return("Length of boot_estimates must match n_boot")
      }
    }

    # If all checks pass, return NULL
    NULL
  }
)

# Register with S4 for compatibility
S7::S4_register(BootstrapResult)


#' Print Method for MediationData
#'
#' @param x A MediationData object
#' @param ... Additional arguments (ignored)
#' @noRd
S7::method(print, MediationData) <- function(x, ...) {
  cat("MediationData object\n")
  cat("====================\n\n")

  cat("Path coefficients:\n")
  cat(sprintf("  a (X -> M):      %8.4f\n", x@a_path))
  cat(sprintf("  b (M -> Y|X):    %8.4f\n", x@b_path))
  cat(sprintf("  c' (X -> Y|M):   %8.4f\n", x@c_prime))
  cat(sprintf("  Indirect (a*b):  %8.4f\n", x@a_path * x@b_path))
  cat("\n")

  cat("Variables:\n")
  cat(sprintf("  Treatment: %s\n", x@treatment))
  cat(sprintf("  Mediator:  %s\n", x@mediator))
  cat(sprintf("  Outcome:   %s\n", x@outcome))
  cat("\n")

  cat("Model info:\n")
  cat(sprintf("  N observations: %d\n", x@n_obs))
  cat(sprintf("  Converged:      %s\n", ifelse(x@converged, "Yes", "No")))
  cat(sprintf("  Source:         %s\n", x@source_package))

  if (!is.null(x@sigma_m) || !is.null(x@sigma_y)) {
    cat("\n")
    cat("Residual SDs:\n")
    if (!is.null(x@sigma_m)) {
      cat(sprintf("  Mediator model: %8.4f\n", x@sigma_m))
    }
    if (!is.null(x@sigma_y)) {
      cat(sprintf("  Outcome model:  %8.4f\n", x@sigma_y))
    }
  }

  invisible(x)
}


#' Print Method for BootstrapResult
#'
#' @param x A BootstrapResult object
#' @param ... Additional arguments (ignored)
#' @noRd
S7::method(print, BootstrapResult) <- function(x, ...) {
  cat("BootstrapResult object\n")
  cat("======================\n\n")

  cat(sprintf("Method:   %s\n", x@method))
  cat(sprintf("Estimate: %8.4f\n", x@estimate))

  if (x@method != "plugin") {
    cat(sprintf("N bootstrap samples: %d\n", x@n_boot))
    cat("\n")
    cat(sprintf("%g%% Confidence Interval:\n", x@ci_level * 100))
    cat(sprintf("  Lower: %8.4f\n", x@ci_lower))
    cat(sprintf("  Upper: %8.4f\n", x@ci_upper))
  } else {
    cat("\n")
    cat("(No confidence interval for plugin method)\n")
  }

  invisible(x)
}


#' Summary Method for MediationData
#'
#' @param object A MediationData object
#' @param ... Additional arguments (ignored)
#' @noRd
S7::method(summary, MediationData) <- function(object, ...) {
  structure(
    list(
      paths = c(
        a = object@a_path,
        b = object@b_path,
        c_prime = object@c_prime,
        indirect = object@a_path * object@b_path
      ),
      variables = c(
        treatment = object@treatment,
        mediator = object@mediator,
        outcome = object@outcome
      ),
      n_obs = object@n_obs,
      converged = object@converged,
      source_package = object@source_package,
      estimates = object@estimates,
      vcov = object@vcov,
      sigma_m = object@sigma_m,
      sigma_y = object@sigma_y
    ),
    class = "summary.MediationData"
  )
}


#' Print Summary for MediationData
#'
#' @param x A summary.MediationData object
#' @param ... Additional arguments (ignored)
#' @return Invisibly returns `x` (the `summary.MediationData` object). Called
#'   for its side effect of printing the formatted summary to the console.
#' @export
print.summary.MediationData <- function(x, ...) {
  cat("Summary of MediationData\n")
  cat("========================\n\n")

  cat("Path Coefficients:\n")
  print(x$paths)
  cat("\n")

  cat("Variables:\n")
  print(x$variables)
  cat("\n")

  cat("Sample Size: ", x$n_obs, "\n")
  cat("Converged:   ", ifelse(x$converged, "Yes", "No"), "\n")
  cat("Source:      ", x$source_package, "\n")

  if (!is.null(x$sigma_m) || !is.null(x$sigma_y)) {
    cat("\nResidual Standard Deviations:\n")
    if (!is.null(x$sigma_m)) {
      cat("  Mediator model:", x$sigma_m, "\n")
    }
    if (!is.null(x$sigma_y)) {
      cat("  Outcome model: ", x$sigma_y, "\n")
    }
  }

  cat("\nParameter Estimates:\n")
  print(x$estimates)

  cat("\nVariance-Covariance Matrix:\n")
  print(x$vcov)

  invisible(x)
}


#' Summary Method for BootstrapResult
#'
#' @param object A BootstrapResult object
#' @param ... Additional arguments (ignored)
#' @noRd
S7::method(summary, BootstrapResult) <- function(object, ...) {
  boot_summary <- list(
    method = object@method,
    estimate = object@estimate,
    n_boot = object@n_boot
  )

  if (object@method != "plugin") {
    boot_summary$ci <- c(
      lower = object@ci_lower,
      upper = object@ci_upper
    )
    boot_summary$ci_level <- object@ci_level

    # Add bootstrap distribution summary statistics
    boot_summary$boot_dist <- summary(object@boot_estimates)
  }

  structure(boot_summary, class = "summary.BootstrapResult")
}


#' Print Summary for BootstrapResult
#'
#' @param x A summary.BootstrapResult object
#' @param ... Additional arguments (ignored)
#' @return Invisibly returns `x` (the `summary.BootstrapResult` object). Called
#'   for its side effect of printing the formatted summary to the console.
#' @export
print.summary.BootstrapResult <- function(x, ...) {
  cat("Summary of BootstrapResult\n")
  cat("==========================\n\n")

  cat("Method:   ", x$method, "\n")
  cat("Estimate: ", x$estimate, "\n")

  if (x$method != "plugin") {
    cat("N bootstrap samples:", x$n_boot, "\n\n")

    cat(sprintf("%g%% Confidence Interval:\n", x$ci_level * 100))
    cat("  Lower:", x$ci[1], "\n")
    cat("  Upper:", x$ci[2], "\n\n")

    cat("Bootstrap Distribution Summary:\n")
    print(x$boot_dist)
  }

  invisible(x)
}


#' Show Method for MediationData
#'
#' @param object A MediationData object
#' @noRd
S7::method(show, MediationData) <- function(object) {
  print(object)
}


#' Show Method for BootstrapResult
#'
#' @param object A BootstrapResult object
#' @noRd
S7::method(show, BootstrapResult) <- function(object) {
  print(object)
}


#' Print Method for SerialMediationData
#'
#' @param x A SerialMediationData object
#' @param ... Additional arguments (ignored)
#' @noRd
S7::method(print, SerialMediationData) <- function(x, ...) {
  cat("SerialMediationData object\n")
  cat("==========================\n\n")

  n_mediators <- length(x@mediators)

  # Compute indirect effect (product of all paths)
  indirect <- x@a_path * prod(x@d_path) * x@b_path

  cat("Serial mediation chain:\n")
  cat(sprintf("  %s -> %s -> %s\n",
              x@treatment,
              paste(x@mediators, collapse = " -> "),
              x@outcome))
  cat("\n")

  cat("Path coefficients:\n")
  cat(sprintf("  a  (%s -> %s):       %8.4f\n", x@treatment, x@mediators[1], x@a_path))

  # Print d paths
  if (n_mediators == 2) {
    cat(sprintf("  d  (%s -> %s):       %8.4f\n",
                x@mediators[1], x@mediators[2], x@d_path))
  } else {
    for (i in seq_along(x@d_path)) {
      path_label <- sprintf("d%d%d", i + 1, i)
      cat(sprintf("  %-3s (%s -> %s):  %8.4f\n",
                  path_label,
                  x@mediators[i], x@mediators[i + 1],
                  x@d_path[i]))
    }
  }

  cat(sprintf("  b  (%s -> %s):       %8.4f\n",
              x@mediators[n_mediators], x@outcome, x@b_path))
  cat(sprintf("  c' (%s -> %s|M):     %8.4f\n", x@treatment, x@outcome, x@c_prime))
  cat("\n")

  cat("Indirect effect:\n")
  if (n_mediators == 2) {
    cat(sprintf("  a * d * b = %8.4f\n", indirect))
  } else {
    d_str <- paste0("d", seq(2, n_mediators), seq(1, n_mediators - 1), collapse = " * ")
    cat(sprintf("  a * %s * b = %8.4f\n", d_str, indirect))
  }
  cat("\n")

  cat("Model info:\n")
  cat(sprintf("  N mediators:    %d\n", n_mediators))
  cat(sprintf("  N observations: %d\n", x@n_obs))
  cat(sprintf("  Converged:      %s\n", ifelse(x@converged, "Yes", "No")))
  cat(sprintf("  Source:         %s\n", x@source_package))

  if (!is.null(x@sigma_mediators) || !is.null(x@sigma_y)) {
    cat("\n")
    cat("Residual SDs:\n")
    if (!is.null(x@sigma_mediators)) {
      for (i in seq_along(x@sigma_mediators)) {
        cat(sprintf("  %s model: %8.4f\n", x@mediators[i], x@sigma_mediators[i]))
      }
    }
    if (!is.null(x@sigma_y)) {
      cat(sprintf("  Outcome model:  %8.4f\n", x@sigma_y))
    }
  }

  invisible(x)
}


#' Summary Method for SerialMediationData
#'
#' @param object A SerialMediationData object
#' @param ... Additional arguments (ignored)
#' @noRd
S7::method(summary, SerialMediationData) <- function(object, ...) {
  n_mediators <- length(object@mediators)
  indirect <- object@a_path * prod(object@d_path) * object@b_path

  # Create named paths vector
  paths <- c(a = object@a_path)

  # Add d paths with appropriate names
  if (n_mediators == 2) {
    paths <- c(paths, d = object@d_path)
  } else {
    d_names <- paste0("d", seq(2, n_mediators), seq(1, n_mediators - 1))
    names(object@d_path) <- d_names
    paths <- c(paths, object@d_path)
  }

  paths <- c(paths,
             b = object@b_path,
             c_prime = object@c_prime,
             indirect = indirect)

  structure(
    list(
      paths = paths,
      mediators = object@mediators,
      variables = c(
        treatment = object@treatment,
        outcome = object@outcome
      ),
      n_mediators = n_mediators,
      n_obs = object@n_obs,
      converged = object@converged,
      source_package = object@source_package,
      estimates = object@estimates,
      vcov = object@vcov,
      sigma_mediators = object@sigma_mediators,
      sigma_y = object@sigma_y
    ),
    class = "summary.SerialMediationData"
  )
}


#' Print Summary for SerialMediationData
#'
#' @param x A summary.SerialMediationData object
#' @param ... Additional arguments (ignored)
#' @return Invisibly returns `x` (the `summary.SerialMediationData` object).
#'   Called for its side effect of printing the formatted summary to the console.
#' @export
print.summary.SerialMediationData <- function(x, ...) {
  cat("Summary of SerialMediationData\n")
  cat("==============================\n\n")

  cat("Serial Chain:\n")
  cat(sprintf("  %s -> %s -> %s\n",
              x$variables["treatment"],
              paste(x$mediators, collapse = " -> "),
              x$variables["outcome"]))
  cat("\n")

  cat("Path Coefficients:\n")
  print(x$paths)
  cat("\n")

  cat("Mediators: ", paste(x$mediators, collapse = ", "), "\n")
  cat("N mediators:", x$n_mediators, "\n")
  cat("Sample Size:", x$n_obs, "\n")
  cat("Converged:  ", ifelse(x$converged, "Yes", "No"), "\n")
  cat("Source:     ", x$source_package, "\n")

  if (!is.null(x$sigma_mediators) || !is.null(x$sigma_y)) {
    cat("\nResidual Standard Deviations:\n")
    if (!is.null(x$sigma_mediators)) {
      for (i in seq_along(x$sigma_mediators)) {
        cat(sprintf("  %s model: %8.4f\n", x$mediators[i], x$sigma_mediators[i]))
      }
    }
    if (!is.null(x$sigma_y)) {
      cat("  Outcome model:", x$sigma_y, "\n")
    }
  }

  cat("\nParameter Estimates:\n")
  print(x$estimates)

  cat("\nVariance-Covariance Matrix:\n")
  print(x$vcov)

  invisible(x)
}


#' Show Method for SerialMediationData
#'
#' @param object A SerialMediationData object
#' @noRd
S7::method(show, SerialMediationData) <- function(object) {
  print(object)
}


#' ParallelMediationData: Parallel (Multiple-Mediator) Mediation Structure
#'
#' @description
#' S7 class for **parallel** mediation, where a treatment affects an outcome
#' through two or more *independent* mediators operating in parallel
#' (\eqn{X \rightarrow M_j \rightarrow Y}{X -> M_j -> Y} for
#' \eqn{j = 1, \dots, k}{j = 1, ..., k}). The total indirect effect is the sum
#' of the per-mediator products, \eqn{\sum_{j=1}^{k} a_j b_j}{sum(a_j * b_j)}.
#' This complements [MediationData] (simple) and [SerialMediationData]
#' (serial chains).
#'
#' @param a_paths Numeric vector: treatment -> mediator effects
#'   \eqn{(a_1, \dots, a_k)}{(a_1, ..., a_k)}.
#' @param b_paths Numeric vector: mediator -> outcome effects
#'   \eqn{(b_1, \dots, b_k)}{(b_1, ..., b_k)}; must be the same length as `a_paths`.
#' @param c_prime Numeric scalar: direct effect \eqn{X \rightarrow Y}{X -> Y}.
#' @param estimates Numeric vector of all parameter estimates.
#' @param vcov Square variance-covariance matrix of `estimates`.
#' @param sigma_mediators Optional numeric vector of mediator residual SDs (length k), or NULL.
#' @param sigma_y Optional numeric scalar outcome residual SD, or NULL.
#' @param treatment,outcome Single character strings naming the treatment / outcome.
#' @param mediators Character vector of mediator names (length k, unique).
#' @param mediator_predictors List of predictor-name vectors, one per mediator.
#' @param outcome_predictors Character vector of outcome-model predictor names.
#' @param data Optional data frame, or NULL.
#' @param n_obs Integer number of observations.
#' @param converged Logical convergence flag.
#' @param source_package Character name of the originating package.
#'
#' @return A `ParallelMediationData` S7 object.
#' @usage
#' ParallelMediationData(a_paths, b_paths, c_prime, estimates, vcov,
#'   sigma_mediators, sigma_y, treatment, mediators, outcome,
#'   mediator_predictors, outcome_predictors, data, n_obs, converged,
#'   source_package)
#'
#' @examples
#' pmd <- ParallelMediationData(
#'   a_paths = c(0.5, 0.4),
#'   b_paths = c(0.6, 0.3),
#'   c_prime = 0.2,
#'   estimates = c(0.5, 0.4, 0.6, 0.3, 0.2),
#'   vcov = diag(0.01, 5),
#'   treatment = "X",
#'   mediators = c("M1", "M2"),
#'   outcome = "Y",
#'   mediator_predictors = list("X", "X"),
#'   outcome_predictors = c("X", "M1", "M2"),
#'   n_obs = 200L,
#'   converged = TRUE,
#'   source_package = "medfit"
#' )
#'
#' nie(pmd)   # total indirect effect: sum(a_j * b_j) = 0.42
#' paths(pmd) # a1, b1, a2, b2, c_prime
#'
#' @export
ParallelMediationData <- S7::new_class(
  "ParallelMediationData",
  package = "medfit",
  properties = list(
    # Core paths (parallel mediators)
    a_paths = S7::class_numeric,      # nolint: commented_code_linter.
    b_paths = S7::class_numeric,      # nolint: commented_code_linter.
    c_prime = S7::class_numeric,      # nolint: commented_code_linter.

    # Parameters (all models)
    estimates = S7::class_numeric,
    vcov = S7::new_S3_class("matrix"),

    # Residual variances (for Gaussian models). An S7 `class_numeric | NULL`
    # union defaults to numeric(0) (not NULL), so the validator treats a
    # length-0 value as "not supplied" (see guards below).
    sigma_mediators = S7::class_numeric | NULL,
    sigma_y = S7::class_numeric | NULL,

    # Variable names
    treatment = S7::class_character,
    mediators = S7::class_character,
    outcome = S7::class_character,
    mediator_predictors = S7::class_list,
    outcome_predictors = S7::class_character,

    # Data and metadata
    data = S7::class_data.frame | NULL,
    n_obs = S7::class_integer,
    converged = S7::class_logical,
    source_package = S7::class_character
  ),

  validator = function(self) {
    n_mediators <- length(self@mediators)

    # Parallel mediation requires at least 2 mediators (1 is simple mediation)
    if (n_mediators < 2) {
      return("Parallel mediation requires at least 2 mediators (use MediationData for 1)")
    }

    # a_paths and b_paths must be equal length and match the mediator count
    if (length(self@a_paths) != n_mediators) {
      return(sprintf(
        "a_paths must have length %d (one per mediator), found %d",
        n_mediators, length(self@a_paths)
      ))
    }
    if (length(self@b_paths) != n_mediators) {
      return(sprintf(
        "b_paths must have length %d (one per mediator), found %d",
        n_mediators, length(self@b_paths)
      ))
    }

    # c_prime must be scalar
    if (length(self@c_prime) != 1) {
      return("c_prime must be a scalar (X -> Y)")
    }

    # vcov must be square and consistent with estimates
    if (nrow(self@vcov) != ncol(self@vcov)) {
      return("vcov must be a square matrix")
    }
    if (length(self@estimates) != nrow(self@vcov)) {
      return("Number of estimates must match vcov dimensions")
    }

    # sigma_mediators (optional; length-0 means not supplied)
    if (!is.null(self@sigma_mediators) && length(self@sigma_mediators) > 0) {
      if (length(self@sigma_mediators) != n_mediators) {
        return(sprintf(
          "sigma_mediators must have length %d (one per mediator), found %d",
          n_mediators, length(self@sigma_mediators)
        ))
      }
      if (any(self@sigma_mediators < 0, na.rm = TRUE)) {
        return("All sigma_mediators values must be non-negative")
      }
    }

    # sigma_y (optional; length-0 means not supplied)
    if (!is.null(self@sigma_y) && length(self@sigma_y) > 0) {
      if (length(self@sigma_y) != 1 || self@sigma_y < 0) {
        return("sigma_y must be a non-negative scalar")
      }
    }

    # Variable names
    if (length(self@treatment) != 1) {
      return("treatment must be a single character string")
    }
    if (length(self@outcome) != 1) {
      return("outcome must be a single character string")
    }
    if (length(unique(self@mediators)) != n_mediators) {
      return("All mediator names must be unique")
    }

    # mediator_predictors must be a list with one entry per mediator
    if (!is.list(self@mediator_predictors)) {
      return("mediator_predictors must be a list")
    }
    if (length(self@mediator_predictors) != n_mediators) {
      return(sprintf(
        "mediator_predictors must have length %d (one per mediator), found %d",
        n_mediators, length(self@mediator_predictors)
      ))
    }

    NULL
  }
)


#' Print Method for ParallelMediationData
#'
#' @param x A ParallelMediationData object
#' @param ... Additional arguments (unused)
#' @noRd
S7::method(print, ParallelMediationData) <- function(x, ...) {
  k <- length(x@mediators)
  indirect <- sum(x@a_paths * x@b_paths)
  cat("<ParallelMediationData>\n")
  cat(sprintf("  %s -> {%s} -> %s  (%d parallel mediators)\n",
              x@treatment, paste(x@mediators, collapse = ", "), x@outcome, k))
  for (j in seq_len(k)) {
    cat(sprintf("    %-8s a%d = %+.4f   b%d = %+.4f\n",
                x@mediators[j], j, x@a_paths[j], j, x@b_paths[j]))
  }
  cat(sprintf("  Direct (c'): %+.4f\n", x@c_prime))
  cat(sprintf("  Indirect (sum a_j*b_j): %+.4f\n", indirect))
  cat(sprintf("  Total: %+.4f   |   n = %d\n", indirect + x@c_prime, x@n_obs))
  invisible(x)
}


#' InteractionMediationData: Mediation with Treatment-Mediator Interaction
#'
#' @description
#' S7 class for simple mediation **with a treatment-by-mediator interaction**
#' (\eqn{X \rightarrow M \rightarrow Y}{X -> M -> Y} where the outcome model
#' contains an \eqn{X \times M}{X*M} term). It carries VanderWeele's (2014)
#' four-way decomposition of the total effect into controlled direct effect
#' (CDE), reference interaction (INTref), mediated interaction (INTmed), and
#' pure indirect effect (PIE):
#' \deqn{TE = CDE + INTref + INTmed + PIE}{TE = CDE + INTref + INTmed + PIE}
#' with \eqn{NDE = CDE + INTref}{NDE = CDE + INTref} and
#' \eqn{NIE = INTmed + PIE}{NIE = INTmed + PIE}. medfit computes the
#' decomposition; causal interpretation is the user's responsibility (it requires
#' the four no-unmeasured-confounding assumptions of VanderWeele 2014).
#'
#' @details
#' Path coefficients follow the outcome model
#' \eqn{Y = \theta_0 + \theta_1 X + \theta_2 M + \theta_3 XM + \dots}{Y = t0 + t1*X + t2*M + t3*X:M + ...}
#' and mediator model \eqn{M = \beta_0 + \beta_1 X + \dots}{M = b0 + b1*X + ...}:
#' `a_path` = \eqn{\beta_1}{b1}, `b_path` = \eqn{\theta_2}{t2},
#' `c_prime` = \eqn{\theta_1}{t1}, `interaction` = \eqn{\theta_3}{t3}. With
#' reference level `m_star` (\eqn{m^*}{m*}) the components are
#' \eqn{CDE = \theta_1 + \theta_3 m^*}{CDE = t1 + t3*m*},
#' \eqn{INTref = \theta_3 (E[M \mid X = 0, \bar c] - m^*)}{INTref = t3*(E[M | X = 0, cbar] - m*)},
#' \eqn{INTmed = \theta_3 \beta_1}{INTmed = t3*b1}, and
#' \eqn{PIE = \theta_2 \beta_1}{PIE = t2*b1}. When \eqn{\theta_3 = 0}{t3 = 0} the
#' decomposition collapses to standard simple mediation (CDE = NDE = \eqn{\theta_1}{t1};
#' INTref = INTmed = 0; NIE = PIE = \eqn{\theta_2\beta_1}{t2*b1}).
#'
#' \eqn{E[M \mid X = 0, \bar c] = \beta_0 + \gamma^\top \bar c}{E[M | X = 0, cbar] = b0 + g'cbar}
#' is the mediator model's prediction at no treatment and the covariate means
#' \eqn{\bar c}{cbar}. The effects are for the treatment contrast 0 to 1, and
#' the lm/glm extractor requires Gaussian identity-link models. From
#' `fit_mediation(engine = "regmedint")`, `@estimates` and `@vcov` also carry
#' regmedint's own delta-method covariance of the four components and the
#' derived effects.
#'
#' @param a_path Numeric scalar: treatment -> mediator effect (\eqn{\beta_1}{b1}).
#' @param b_path Numeric scalar: mediator -> outcome main effect (\eqn{\theta_2}{t2}).
#' @param c_prime Numeric scalar: treatment -> outcome main effect (\eqn{\theta_1}{t1}).
#' @param interaction Numeric scalar: treatment x mediator coefficient (\eqn{\theta_3}{t3}).
#' @param cde,int_ref,int_med,pie Numeric scalars: the four-way components
#'   (controlled direct, reference interaction, mediated interaction, pure indirect).
#' @param nde,nie,total_effect Numeric scalars: derived natural direct effect
#'   (CDE + INTref), natural indirect effect (INTmed + PIE), and total effect (the
#'   sum of all four components).
#' @param m_star Numeric scalar: reference mediator level for the decomposition
#'   (default 0).
#' @param estimates Numeric vector of all parameter estimates.
#' @param vcov Square variance-covariance matrix of `estimates`.
#' @param sigma_m Optional numeric scalar mediator residual SD, or NULL.
#' @param sigma_y Optional numeric scalar outcome residual SD, or NULL.
#' @param treatment,mediator,outcome Single character strings naming the
#'   treatment / mediator / outcome.
#' @param mediator_predictors,outcome_predictors Character vectors of predictor
#'   names for the mediator and outcome models.
#' @param data Optional data frame, or NULL.
#' @param n_obs Integer number of observations.
#' @param converged Logical convergence flag.
#' @param source_package Character name of the originating package.
#'
#' @return An `InteractionMediationData` S7 object.
#' @usage
#' InteractionMediationData(a_path, b_path, c_prime, interaction, cde,
#'   int_ref, int_med, pie, nde, nie, total_effect, m_star, estimates, vcov,
#'   sigma_m, sigma_y, treatment, mediator, outcome, mediator_predictors,
#'   outcome_predictors, data, n_obs, converged, source_package)
#'
#' @references
#' VanderWeele, T. J. (2014). A unification of mediation and interaction: A
#' 4-way decomposition. *Epidemiology*, 25(5), 749--761.
#'
#' @examples
#' # Hand-built object (theta3 = 0.2 interaction, m* = 0)
#' imd <- InteractionMediationData(
#'   a_path = 0.5, b_path = 0.3, c_prime = 0.1, interaction = 0.2,
#'   cde = 0.1, int_ref = 0.04, int_med = 0.10, pie = 0.15,
#'   nde = 0.14, nie = 0.25, total_effect = 0.39, m_star = 0,
#'   estimates = c(a = 0.5, b = 0.3, c_prime = 0.1, theta3 = 0.2),
#'   vcov = diag(0.01, 4),
#'   treatment = "X", mediator = "M", outcome = "Y",
#'   mediator_predictors = "X", outcome_predictors = c("X", "M", "X:M"),
#'   n_obs = 200L, converged = TRUE, source_package = "medfit"
#' )
#'
#' nie(imd)       # INTmed + PIE = 0.25
#' decompose(imd) # all four components + derived effects
#'
#' @export
InteractionMediationData <- S7::new_class(
  "InteractionMediationData",
  package = "medfit",
  properties = list(
    # Core path coefficients (all scalar)
    a_path = S7::class_numeric,        # beta_1: treatment effect on mediator
    b_path = S7::class_numeric,        # theta_2: mediator main effect on outcome
    c_prime = S7::class_numeric,       # theta_1: treatment main effect on outcome
    interaction = S7::class_numeric,   # theta_3: treatment-by-mediator product

    # Four-way decomposition components (scalar)
    cde = S7::class_numeric,
    int_ref = S7::class_numeric,
    int_med = S7::class_numeric,
    pie = S7::class_numeric,

    # Derived effects (scalar)
    nde = S7::class_numeric,
    nie = S7::class_numeric,
    total_effect = S7::class_numeric,

    # Reference mediator level for the decomposition
    m_star = S7::class_numeric,

    # Parameters
    estimates = S7::class_numeric,
    vcov = S7::new_S3_class("matrix"),

    # Residual SDs (Gaussian). class_numeric | NULL defaults to numeric(0),
    # so validators treat length-0 as "not supplied" (see ParallelMediationData).
    sigma_m = S7::class_numeric | NULL,
    sigma_y = S7::class_numeric | NULL,

    # Variable names
    treatment = S7::class_character,
    mediator = S7::class_character,
    outcome = S7::class_character,
    mediator_predictors = S7::class_character,
    outcome_predictors = S7::class_character,

    # Data and metadata
    data = S7::class_data.frame | NULL,
    n_obs = S7::class_integer,
    converged = S7::class_logical,
    source_package = S7::class_character
  ),

  validator = function(self) {
    tol <- 1e-8 * max(1, abs(self@total_effect))

    # --- Structural checks (shape; implemented) ---
    scalars <- list(
      a_path = self@a_path, b_path = self@b_path, c_prime = self@c_prime,
      interaction = self@interaction, cde = self@cde, int_ref = self@int_ref,
      int_med = self@int_med, pie = self@pie, nde = self@nde, nie = self@nie,
      total_effect = self@total_effect, m_star = self@m_star
    )
    for (nm in names(scalars)) {
      if (length(scalars[[nm]]) != 1) return(sprintf("%s must be a scalar", nm))
    }
    if (nrow(self@vcov) != ncol(self@vcov)) {
      return("vcov must be a square matrix")
    }
    if (length(self@estimates) != nrow(self@vcov)) {
      return("Number of estimates must match vcov dimensions")
    }
    if (length(self@treatment) != 1 || length(self@mediator) != 1 ||
          length(self@outcome) != 1) {
      return("treatment, mediator, and outcome must each be a single string")
    }
    if (!is.null(self@sigma_m) && length(self@sigma_m) > 0 &&
          (length(self@sigma_m) != 1 || self@sigma_m < 0)) {
      return("sigma_m must be a non-negative scalar")
    }
    if (!is.null(self@sigma_y) && length(self@sigma_y) > 0 &&
          (length(self@sigma_y) != 1 || self@sigma_y < 0)) {
      return("sigma_y must be a non-negative scalar")
    }

    # --- Algebraic invariants (the VALUE-ADD of this class) ---
    # Two families of consistency checks, both enforced. They make the class a
    # tripwire on a buggy extractor: bad numbers are rejected at construction.
    #
    # (i) Aggregate identities -- the decomposition must add up: the four
    #     components sum to total_effect; NDE is CDE plus INTref; NIE is
    #     INTmed plus PIE.
    if (abs((self@cde + self@int_ref + self@int_med + self@pie) -
              self@total_effect) > tol) {
      return("Four-way components must sum to total_effect (CDE+INTref+INTmed+PIE)")
    }
    if (abs((self@cde + self@int_ref) - self@nde) > tol) {
      return("nde must equal cde + int_ref (NDE = CDE + INTref)")
    }
    if (abs((self@int_med + self@pie) - self@nie) > tol) {
      return("nie must equal int_med + pie (NIE = INTmed + PIE)")
    }
    #
    # (ii) Path ties -- the stronger checks: tie each component back to the raw
    # coefficients (VanderWeele 2014, continuous Y/M). These catch extractor math
    # errors that the aggregate identities alone (tautological if the extractor
    # defines nde/nie as sums) would miss. INTref also depends on beta_0, which
    # is not a slot, so it is checked only via the aggregate identity above.
    if (abs(self@cde - (self@c_prime + self@interaction * self@m_star)) > tol) {
      return("cde must equal c_prime + interaction * m_star (CDE = theta1 + theta3 * m*)")
    }
    if (abs(self@int_med - self@interaction * self@a_path) > tol) {
      return("int_med must equal interaction * a_path (INTmed = theta3 * beta1)")
    }
    if (abs(self@pie - self@b_path * self@a_path) > tol) {
      return("pie must equal b_path * a_path (PIE = theta2 * beta1)")
    }

    NULL
  }
)


#' Print Method for InteractionMediationData
#'
#' @param x An InteractionMediationData object
#' @param ... Additional arguments (unused)
#' @noRd
S7::method(print, InteractionMediationData) <- function(x, ...) {
  cat("<InteractionMediationData>\n")
  cat(sprintf("  %s -> %s -> %s   (with %s x %s interaction)\n",
              x@treatment, x@mediator, x@outcome, x@treatment, x@mediator))
  cat(sprintf("  Paths:  a (b1) = %+.4f   b (t2) = %+.4f   c' (t1) = %+.4f   t3 = %+.4f\n",
              x@a_path, x@b_path, x@c_prime, x@interaction))
  cat(sprintf("  Four-way (m* = %g):\n", x@m_star))
  cat(sprintf("    CDE = %+.4f   INTref = %+.4f   INTmed = %+.4f   PIE = %+.4f\n",
              x@cde, x@int_ref, x@int_med, x@pie))
  cat(sprintf("  NDE = %+.4f   NIE = %+.4f   Total = %+.4f   |   n = %d\n",
              x@nde, x@nie, x@total_effect, x@n_obs))
  invisible(x)
}


#' JointMediationData: Joint Natural Effects of Multiple Mediators
#'
#' @description
#' S7 class for the **joint** natural effects of two or more mediators, serial
#' or parallel, when the outcome model may contain treatment-by-mediator product
#' terms (VanderWeele and Vansteelandt 2014). The mediators are treated as one
#' block: the natural indirect effect (NIE) runs through every mediator and every
#' path among them, and the natural direct effect (NDE) is the remainder.
#' medfit computes the effects; causal interpretation is the user's
#' responsibility.
#'
#' @details
#' With outcome model
#' \eqn{Y = \theta_1 X + \sum_i (\theta_{2i} + \theta_{3i} X) M_i + \dots}{Y = t1*X + sum((t2i + t3i*X)*Mi) + ...}
#' and \eqn{\beta^*_{1i}}{b1i*} the total (propagated) effect of the treatment on
#' mediator \eqn{i} (for a serial chain this includes the paths through earlier
#' mediators), the unit-contrast effects are
#' \deqn{NIE = \sum_i (\theta_{2i} + \theta_{3i}) \beta^*_{1i}}{NIE = sum((t2i + t3i) * b1i*)}
#' \deqn{NDE = \theta_1 + \sum_i \theta_{3i} \mu^*_{0i}}{NDE = t1 + sum(t3i * mu0i*)}
#' \deqn{CDE = \theta_1 + \sum_i \theta_{3i} m^*_i}{CDE = t1 + sum(t3i * mi*)}
#' and \eqn{TE = NDE + NIE}{TE = NDE + NIE}. \eqn{\theta_{3i}}{t3i} is zero for a
#' mediator without a product term, and \eqn{\mu^*_{0i}}{mu0i*} is the mean of
#' mediator \eqn{i} under no treatment at the covariate means (propagated down a
#' serial chain like \eqn{\beta^*_{1i}}{b1i*}). The validator enforces the NIE and CDE
#' identities, so an object with inconsistent numbers cannot be built.
#'
#' ## What the joint NIE is, and is not
#'
#' The NIE is the effect through the mediators **as a block**: every path from
#' the treatment through any mediator, including paths among the mediators. It
#' is not split into per-mediator or per-path pieces, and none of its parts
#' should be reported as the effect "through M1". For a serial chain it
#' therefore differs from the default `nie()` of a [SerialMediationData]
#' (`a * d * b`, the effect through the full chain only): with no product term, the
#' joint NIE of `M1 -> M2` is \eqn{a_1 b_1 + (a_2 + d a_1) b_2}{a1*b1 + (a2 + d*a1)*b2},
#' not \eqn{a_1 d b_2}{a1*d*b2}. The effects use the unit contrast of a 0/1
#' treatment (0 to 1).
#'
#' ## Assumptions
#'
#' The joint effects are identified under no-unmeasured-confounding assumptions
#' stated for the whole mediator vector: none for the treatment and outcome,
#' none for the mediators and the outcome, none for the treatment and the
#' mediators, and no mediator-outcome confounder affected by the treatment
#' **outside the mediator vector** (VanderWeele and Vansteelandt 2014). In a
#' serial chain the earlier mediators are affected by the treatment and
#' confound the later ones; that is allowed precisely because they are part of
#' the vector. Mediator-outcome and treatment-mediator confounders must be
#' controlled for **every** mediator.
#'
#' ## medfit's requirements
#'
#' - Every model (each mediator model and the outcome model) must carry the
#'   **same covariates**. This is a medfit limitation that keeps the
#'   serial-chain algebra and the covariance exact, not a requirement of the
#'   method; differing sets error, naming the terms.
#' - The models must be Gaussian with the identity link, unweighted, with an
#'   intercept, fit to the same rows; every mediator must appear in the outcome
#'   model; `mediator` lists the mediators in causal order.
#' - A product must be written in the outcome formula with `:` or `*`. A product
#'   **precomputed as a data column** (for example `XM <- X * M1` added to the
#'   data and then used as `Y ~ X + M1 + M2 + XM`) cannot be recognized from the
#'   formula: medfit treats it as an ordinary covariate and the effects ignore
#'   the interaction, with no error. Write `X * M1` in the formula instead.
#'
#' ## Covariates and standard errors
#'
#' The NDE depends on the covariates; it is evaluated at their sample means.
#' The effects are linear in the covariates, so this equals the sample average
#' of the per-observation effects. Standard errors use the delta method with
#' analytic gradients over a stacked-OLS covariance that includes the
#' correlation between parallel mediator equations. They treat the covariate
#' means as fixed, so they are conditional on the observed covariates and
#' slightly understate the uncertainty of a population-average effect. For a
#' parametric bootstrap use [joint_effects()] as the statistic.
#'
#' @param structure Single string, `"serial"` or `"parallel"`.
#' @param mediators Character vector of mediator names, in causal order.
#' @param treatment,outcome Single character strings.
#' @param interactions Character vector naming the mediators that carry a
#'   treatment-by-mediator product in the outcome model (may be empty).
#' @param a_total Numeric vector named by `mediators`: total effect of the
#'   treatment on each mediator (\eqn{\beta^*_{1i}}{b1i*}).
#' @param b_paths Numeric vector named by `mediators`: outcome main effect of each
#'   mediator (\eqn{\theta_{2i}}{t2i}).
#' @param theta3 Numeric vector named by `interactions`: product coefficients
#'   (\eqn{\theta_{3i}}{t3i}).
#' @param c_prime Numeric scalar: treatment main effect on the outcome
#'   (\eqn{\theta_1}{t1}).
#' @param cde,nde,nie,total_effect Numeric scalars: controlled direct, natural
#'   direct, natural indirect and total effects.
#' @param m_star Numeric vector named by `interactions`: reference mediator levels
#'   for the CDE.
#' @param estimates Named numeric vector of parameter estimates.
#' @param vcov Square variance-covariance matrix of `estimates`.
#' @param data Optional data frame, or NULL.
#' @param n_obs Integer number of observations.
#' @param converged Logical convergence flag.
#' @param source_package Character name of the originating package.
#'
#' @return A `JointMediationData` S7 object.
#' @usage
#' JointMediationData(structure, mediators, treatment, outcome, interactions,
#'   a_total, b_paths, theta3, c_prime, cde, nde, nie, total_effect, m_star,
#'   estimates, vcov, data, n_obs, converged, source_package)
#'
#' @references
#' VanderWeele, T. J., & Vansteelandt, S. (2014). Mediation analysis with
#' multiple mediators. *Epidemiologic Methods*, 2(1), 95--115.
#' \doi{10.1515/em-2012-0010}
#'
#' @examples
#' # Hand-built parallel object with an X x M2 product (m2* = 0)
#' jmd <- JointMediationData(
#'   structure = "parallel", mediators = c("M1", "M2"),
#'   treatment = "X", outcome = "Y", interactions = "M2",
#'   a_total = c(M1 = 0.5, M2 = 0.3), b_paths = c(M1 = 0.3, M2 = 0.4),
#'   theta3 = c(M2 = 0.2), c_prime = 0.1,
#'   cde = 0.1, nde = 0.12, nie = 0.33, total_effect = 0.45,
#'   m_star = c(M2 = 0),
#'   estimates = c(a1 = 0.5, a2 = 0.3, b1 = 0.3, b2 = 0.4,
#'                 theta3_M2 = 0.2, c_prime = 0.1),
#'   vcov = diag(0.01, 6),
#'   n_obs = 200L, converged = TRUE, source_package = "medfit"
#' )
#' jmd@nie  # (0.3 + 0) * 0.5 + (0.4 + 0.2) * 0.3 = 0.33
#'
#' @export
JointMediationData <- S7::new_class(
  "JointMediationData",
  package = "medfit",
  properties = list(
    structure = S7::class_character,
    mediators = S7::class_character,
    treatment = S7::class_character,
    outcome = S7::class_character,
    interactions = S7::class_character,  # mediators carrying an X x M product

    # Path slots: propagated treatment effects and outcome coefficients
    a_total = S7::class_numeric,         # beta1*(i), named by mediator
    b_paths = S7::class_numeric,         # theta2(i), named by mediator
    theta3 = S7::class_numeric,          # theta3(i), named by interacting mediator
    c_prime = S7::class_numeric,         # theta1

    # Effects (scalar)
    cde = S7::class_numeric,
    nde = S7::class_numeric,
    nie = S7::class_numeric,
    total_effect = S7::class_numeric,

    # Reference levels for the CDE, named by interacting mediator
    m_star = S7::class_numeric,

    # Parameters
    estimates = S7::class_numeric,
    vcov = S7::new_S3_class("matrix"),

    # Data and metadata
    data = S7::class_data.frame | NULL,
    n_obs = S7::class_integer,
    converged = S7::class_logical,
    source_package = S7::class_character
  ),

  validator = function(self) {
    tol <- 1e-8 * max(1, abs(self@total_effect))

    # --- Structural checks ---
    if (length(self@structure) != 1 ||
          !self@structure %in% c("serial", "parallel")) {
      return("structure must be \"serial\" or \"parallel\"")
    }
    if (length(self@treatment) != 1 || length(self@outcome) != 1) {
      return("treatment and outcome must each be a single string")
    }
    k <- length(self@mediators)
    if (k < 1 || anyDuplicated(self@mediators)) {
      return("mediators must be a non-empty vector of unique names")
    }
    for (nm in c("a_total", "b_paths")) {
      v <- S7::prop(self, nm)
      if (length(v) != k || !identical(names(v), self@mediators)) {
        return(sprintf("%s must be named by mediators, in order", nm))
      }
    }
    if (!all(self@interactions %in% self@mediators)) {
      return("interactions must be a subset of mediators")
    }
    if (!setequal(names(self@theta3), self@interactions) ||
          length(self@theta3) != length(self@interactions)) {
      return("theta3 must be named by exactly the interacting mediators")
    }
    if (!setequal(names(self@m_star), self@interactions) ||
          length(self@m_star) != length(self@interactions)) {
      return("m_star must be named by exactly the interacting mediators")
    }
    scalars <- list(c_prime = self@c_prime, cde = self@cde, nde = self@nde,
                    nie = self@nie, total_effect = self@total_effect)
    for (nm in names(scalars)) {
      if (length(scalars[[nm]]) != 1) return(sprintf("%s must be a scalar", nm))
    }
    if (nrow(self@vcov) != ncol(self@vcov)) {
      return("vcov must be a square matrix")
    }
    if (length(self@estimates) != nrow(self@vcov)) {
      return("Number of estimates must match vcov dimensions")
    }

    # --- Algebraic invariants: tie the effects back to the path slots ---
    if (abs(self@total_effect - (self@nde + self@nie)) > tol) {
      return("total_effect must equal nde + nie")
    }
    th3 <- stats::setNames(numeric(k), self@mediators)
    th3[names(self@theta3)] <- self@theta3
    if (abs(self@nie - sum((self@b_paths + th3) * self@a_total)) > tol) {
      return("nie must equal sum((theta2 + theta3) * beta1*)")
    }
    cde_path <- self@c_prime +
      sum(self@theta3 * self@m_star[names(self@theta3)])
    if (abs(self@cde - cde_path) > tol) {
      return("cde must equal theta1 + sum(theta3 * m_star)")
    }

    NULL
  }
)


#' Print Method for JointMediationData
#'
#' @param x A JointMediationData object
#' @param ... Additional arguments (unused)
#' @noRd
S7::method(print, JointMediationData) <- function(x, ...) {
  sep <- if (x@structure == "serial") " -> " else ", "
  cat("<JointMediationData>\n")
  cat(sprintf("  %s -> {%s} -> %s  (%s mediators, joint effects)\n",
              x@treatment, paste(x@mediators, collapse = sep), x@outcome,
              x@structure))
  prods <- if (length(x@interactions)) {
    paste(sprintf("%s x %s (m* = %g)", x@treatment, x@interactions,
                  x@m_star[x@interactions]), collapse = ", ")
  } else {
    "none"
  }
  cat(sprintf("  Products: %s\n", prods))
  for (m in x@mediators) {
    t3 <- if (m %in% x@interactions) sprintf("   t3 = %+.4f", x@theta3[[m]]) else ""
    cat(sprintf("    %-8s a* = %+.4f   b = %+.4f%s\n",
                m, x@a_total[[m]], x@b_paths[[m]], t3))
  }
  cat(sprintf("  c' (t1) = %+.4f   CDE = %+.4f   NDE = %+.4f\n",
              x@c_prime, x@cde, x@nde))
  cat(sprintf("  Joint NIE (all paths through %s) = %+.4f\n",
              paste(x@mediators, collapse = ", "), x@nie))
  cat(sprintf("  Total = %+.4f   |   n = %d\n", x@total_effect, x@n_obs))
  invisible(x)
}


#' Summary Method for JointMediationData
#'
#' @param object A JointMediationData object
#' @param level Confidence level for the normal-approximation intervals.
#' @param ... Additional arguments (ignored)
#' @noRd
S7::method(summary, JointMediationData) <- function(object, level = 0.95, ...) {
  checkmate::assert_number(level, lower = 0, upper = 1, .var.name = "level")
  keys <- c("cde", "nde", "nie", "te")
  est <- c(object@cde, object@nde, object@nie, object@total_effect)
  se <- .effect_se_or_na(object, keys)
  z <- stats::qnorm(1 - (1 - level) / 2)
  effects <- data.frame(estimate = est, std.error = unname(se),
                        conf.low = est - z * unname(se),
                        conf.high = est + z * unname(se),
                        row.names = c("CDE", "NDE", "NIE (joint)", "Total"))
  structure(
    list(
      effects = effects,
      level = level,
      paths = paths(object),
      a_total = object@a_total,
      structure = object@structure,
      mediators = object@mediators,
      interactions = object@interactions,
      m_star = object@m_star,
      variables = c(treatment = object@treatment, outcome = object@outcome),
      n_obs = object@n_obs,
      converged = object@converged,
      source_package = object@source_package
    ),
    class = "summary.JointMediationData"
  )
}


#' Print Summary for JointMediationData
#'
#' @param x A summary.JointMediationData object
#' @param ... Additional arguments (ignored)
#' @return Invisibly returns `x` (the `summary.JointMediationData` object).
#'   Called for its side effect of printing the formatted summary to the console.
#' @export
print.summary.JointMediationData <- function(x, ...) {
  sep <- if (x$structure == "serial") " -> " else ", "
  cat("Summary of JointMediationData\n")
  cat("=============================\n\n")
  cat(sprintf("%s mediators: %s -> {%s} -> %s\n",
              if (x$structure == "serial") "Serial" else "Parallel",
              x$variables["treatment"], paste(x$mediators, collapse = sep),
              x$variables["outcome"]))
  if (length(x$interactions)) {
    cat(sprintf("Treatment-by-mediator products: %s\n",
                paste(sprintf("%s (m* = %g)", x$interactions,
                              x$m_star[x$interactions]), collapse = ", ")))
  } else {
    cat("Treatment-by-mediator products: none\n")
  }
  cat("\nEffects (unit contrast 0 -> 1, covariates at their means):\n")
  print(round(x$effects, 4))
  cat(sprintf(paste0("  %g%% normal-approximation intervals; SEs are conditional ",
                     "on the observed covariates.\n"), 100 * x$level))
  cat(sprintf("  The joint NIE runs through all paths via %s; it has no ",
              paste(x$mediators, collapse = ", ")),
      "per-mediator split.\n", sep = "")
  cat("\nTotal treatment effect on each mediator (a*):\n")
  print(round(x$a_total, 4))
  cat("\nPath coefficients:\n")
  print(round(x$paths, 4))
  cat("\nSample Size:", x$n_obs, "\n")
  cat("Converged:  ", ifelse(x$converged, "Yes", "No"), "\n")
  cat("Source:     ", x$source_package, "\n")
  invisible(x)
}


#' ClusterMediationData: Cluster-Level Treatment Mediation (2-1-1)
#'
#' @description
#' S7 class for mediation with a treatment assigned to whole clusters (such as
#' schools) and a mediator and outcome measured on the individuals in them. It
#' holds the paths of a two-level linear mixed model pair: the mediator model
#' `M ~ X + ... + (1 | cluster)` and the outcome model with the mediator split
#' into its within-cluster deviation and the observed cluster mean. medfit
#' computes the effects; causal interpretation is the user's responsibility.
#'
#' @details
#' With the within parameterization
#' \eqn{Y_{ij} = \theta_0 + c' X_j + b_W (M_{ij} - \bar M_j) + b_B \bar M_j + \dots}{
#' Y = t0 + c'*X + bW*(M - Mbar) + bB*Mbar + ...}
#' and \eqn{a}{a} the effect of the treatment on the mediator, the natural
#' indirect effect is \eqn{a b_B}{a*bB}. It splits into an own-mediator part
#' \eqn{a b_W}{a*bW} and a spillover part \eqn{a (b_B - b_W)}{a*(bB - bW)}.
#'
#' The split is the large-cluster, cluster-average approximation. With the
#' observed cluster mean, moving only member \eqn{i}'s mediator by \eqn{a}
#' also moves the mean by \eqn{a / n_j}, so the exact own-mediator effect is
#' \eqn{a [b_W + (b_B - b_W) / n_j]}{a*(bW + (bB - bW)/nj)} and the exact
#' spillover is \eqn{a (b_B - b_W)(n_j - 1) / n_j}{a*(bB - bW)*(nj - 1)/nj};
#' they still sum to \eqn{a b_B}{a*bB}. `decompose()` warns when the
#' approximation error exceeds half the own effect's standard error.
#'
#' The estimand assumes randomized treatment, intact clusters, no interference
#' between clusters, linear models without mediator-by-treatment or
#' mediator-by-covariate products, and interference through the observed
#' cluster mean only; all members of a cluster must be in the analysis rows.
#' The own effect also needs no unmeasured lower-level mediator-outcome
#' confounding. The spillover, NIE and NDE need no unmeasured upper-level
#' mediator-outcome confounding either; under it only the sum of the direct
#' effect and \eqn{a (b_B - b_W)}{a*(bB - bW)} is identified. `print()` and
#' `summary()` print this block. The validator ties the alias rows `a`, `c_prime`, `b_within` and
#' `b_between` of `estimates` and `vcov` to the path properties, so an object
#' with inconsistent numbers cannot be built.
#'
#' `kr_df` holds the Kenward-Roger degrees of freedom of each path when
#' `se_type = "kr"`, and is empty otherwise.
#'
#' @param a_path Numeric scalar: effect of the treatment on the mediator.
#' @param b_within Numeric scalar: within-cluster mediator effect on the outcome.
#' @param b_between Numeric scalar: between-cluster (cluster-mean) mediator
#'   effect on the outcome.
#' @param c_prime Numeric scalar: direct effect of the treatment.
#' @param estimates Named numeric vector of parameter estimates: the four alias
#'   rows plus each model's fixed effects.
#' @param vcov Square variance-covariance matrix of `estimates`, with matching
#'   dimnames.
#' @param kr_df Named numeric vector of Kenward-Roger degrees of freedom, one
#'   per path, when `se_type = "kr"`; `NULL` otherwise.
#' @param treatment,mediator,outcome Character names of the variables.
#' @param cluster Character name of the cluster variable.
#' @param n_obs Integer number of observations.
#' @param n_clusters Integer number of clusters.
#' @param cluster_sizes Integer vector with one size per cluster.
#' @param parameterization `"within"` or `"raw"`: how the outcome model was
#'   fitted.
#' @param covariates_centered Logical: whether every level-1 covariate in the
#'   outcome model has a cluster-mean companion.
#' @param se_type `"model"` or `"kr"`.
#' @param reml Logical: whether the models were fitted by REML.
#' @param converged Logical convergence flag.
#' @param sigma_m,sigma_y Numeric scalars: residual standard deviations of the
#'   mediator and outcome models.
#' @param tau_m,tau_y Numeric scalars: random-intercept standard deviations of
#'   the mediator and outcome models.
#' @param data Optional data frame, or NULL.
#' @param source_package Character name of the originating package.
#'
#' @return A `ClusterMediationData` S7 object.
#' @usage
#' ClusterMediationData(a_path, b_within, b_between, c_prime, estimates, vcov,
#'   kr_df, treatment, mediator, outcome, cluster, n_obs, n_clusters,
#'   cluster_sizes, parameterization, covariates_centered, se_type, reml,
#'   converged, sigma_m, sigma_y, tau_m, tau_y, data, source_package)
#'
#' @references
#' Talloen, W., Moerkerke, B., Loeys, T., De Naeghel, J., Van Keer, H., &
#' Vansteelandt, S. (2016). Estimation of indirect effects in the presence of
#' unmeasured confounding for the mediator-outcome relationship in a multilevel
#' 2-1-1 mediation model. *Journal of Educational and Behavioral Statistics*,
#' 41(4), 359-391. \doi{10.3102/1076998616636855}
#'
#' VanderWeele, T. J. (2010). Direct and indirect effects for neighborhood-based
#' clustered and longitudinal data. *Sociological Methods & Research*, 38(4),
#' 515-544. \doi{10.1177/0049124110366236}
#'
#' @examples
#' # Hand-built object (the paths and their alias rows must agree)
#' est <- c(a = 0.5, c_prime = 0.2, b_within = 0.3, b_between = 0.6)
#' vc <- diag(0.01, 4)
#' dimnames(vc) <- list(names(est), names(est))
#' cmd <- ClusterMediationData(
#'   a_path = 0.5, b_within = 0.3, b_between = 0.6, c_prime = 0.2,
#'   estimates = est, vcov = vc,
#'   treatment = "X", mediator = "M", outcome = "Y", cluster = "school",
#'   n_obs = 400L, n_clusters = 40L, cluster_sizes = rep(10L, 40),
#'   parameterization = "within", covariates_centered = TRUE, se_type = "model",
#'   reml = TRUE, converged = TRUE, sigma_m = 1, sigma_y = 1, tau_m = 0.5,
#'   tau_y = 0.5, source_package = "medfit"
#' )
#' cmd@a_path * cmd@b_between  # the NIE, 0.5 * 0.6
#'
#' @export
ClusterMediationData <- S7::new_class(
  "ClusterMediationData",
  package = "medfit",
  properties = list(
    # Paths (scalars); also stored as alias rows of `estimates` and `vcov`
    a_path = S7::class_numeric,
    b_within = S7::class_numeric,
    b_between = S7::class_numeric,
    c_prime = S7::class_numeric,

    # Parameters
    estimates = S7::class_numeric,
    vcov = S7::new_S3_class("matrix"),
    # `class_numeric | NULL` defaults to numeric(0); state the NULL default
    kr_df = S7::new_property(S7::class_numeric | NULL, default = NULL),

    # Variables
    treatment = S7::class_character,
    mediator = S7::class_character,
    outcome = S7::class_character,
    cluster = S7::class_character,

    # Design
    n_obs = S7::class_integer,
    n_clusters = S7::class_integer,
    cluster_sizes = S7::class_integer,

    # How the models were fitted
    parameterization = S7::class_character,
    covariates_centered = S7::class_logical,
    se_type = S7::class_character,
    reml = S7::class_logical,
    converged = S7::class_logical,

    # Variance components
    sigma_m = S7::class_numeric,
    sigma_y = S7::class_numeric,
    tau_m = S7::class_numeric,
    tau_y = S7::class_numeric,

    # Data and metadata
    data = S7::class_data.frame | NULL,
    source_package = S7::class_character
  ),

  validator = function(self) {
    aliases <- c("a", "c_prime", "b_within", "b_between")

    # --- Scalars ---
    scalars <- list(
      a_path = self@a_path, b_within = self@b_within,
      b_between = self@b_between, c_prime = self@c_prime,
      sigma_m = self@sigma_m, sigma_y = self@sigma_y,
      tau_m = self@tau_m, tau_y = self@tau_y, n_obs = self@n_obs,
      n_clusters = self@n_clusters, treatment = self@treatment,
      mediator = self@mediator, outcome = self@outcome,
      cluster = self@cluster, parameterization = self@parameterization,
      covariates_centered = self@covariates_centered,
      se_type = self@se_type, reml = self@reml, converged = self@converged
    )
    for (nm in names(scalars)) {
      if (length(scalars[[nm]]) != 1 || is.na(scalars[[nm]])) {
        return(sprintf("%s must be a single non-missing value", nm))
      }
    }
    for (nm in c("sigma_m", "sigma_y", "tau_m", "tau_y")) {
      if (!is.finite(scalars[[nm]]) || scalars[[nm]] < 0) {
        return(sprintf("%s must be finite and non-negative", nm))
      }
    }
    if (!self@parameterization %in% c("within", "raw")) {
      return("parameterization must be \"within\" or \"raw\"")
    }
    if (!self@se_type %in% c("model", "kr")) {
      return("se_type must be \"model\" or \"kr\"")
    }

    # --- Design ---
    if (self@n_clusters != length(self@cluster_sizes)) {
      return("n_clusters must equal length(cluster_sizes)")
    }
    if (self@n_clusters < 2L) {
      return("a cluster design needs at least 2 clusters")
    }
    if (anyNA(self@cluster_sizes) || any(self@cluster_sizes < 1L)) {
      return("cluster_sizes must all be at least 1")
    }
    if (sum(self@cluster_sizes) != self@n_obs) {
      return("sum(cluster_sizes) must equal n_obs")
    }

    # --- Estimates, vcov and the alias rows ---
    if (nrow(self@vcov) != ncol(self@vcov)) {
      return("vcov must be a square matrix")
    }
    if (length(self@estimates) != nrow(self@vcov)) {
      return("Number of estimates must match vcov dimensions")
    }
    nms <- names(self@estimates)
    if (is.null(nms) || anyNA(nms) || anyDuplicated(nms)) {
      return("estimates must have unique names")
    }
    if (!identical(rownames(self@vcov), nms) ||
          !identical(colnames(self@vcov), nms)) {
      return("vcov dimnames must equal names(estimates)")
    }
    if (!all(aliases %in% nms)) {
      return("estimates and vcov must carry the alias rows a, c_prime, b_within and b_between")
    }
    paths <- c(a = self@a_path, c_prime = self@c_prime,
               b_within = self@b_within, b_between = self@b_between)
    if (!isTRUE(all.equal(unname(self@estimates[aliases]), unname(paths[aliases]),
                          tolerance = 1e-12))) {
      return("alias rows of estimates must equal the path properties")
    }

    # --- Kenward-Roger df: present iff se_type is "kr" ---
    if (self@se_type == "kr") {
      if (!isTRUE(self@reml)) {
        return("se_type = \"kr\" requires REML fits")
      }
      if (length(self@kr_df) != length(aliases) ||
            !setequal(names(self@kr_df), aliases) ||
            any(!is.finite(self@kr_df)) || any(self@kr_df <= 0)) {
        return("kr_df must hold a positive df for each of a, c_prime, b_within and b_between when se_type is \"kr\"")
      }
    } else if (length(self@kr_df) > 0L) {
      return("kr_df must be empty unless se_type is \"kr\"")
    }

    NULL
  }
)


# Effects reported with standard errors (tidy, confint, summary): estimate
# vector in canonical order. own and spillover are the cluster-average,
# large-cluster approximation of the NIE split.
.cluster_effect_vec <- function(x) {
  a <- x@a_path
  c(nie = a * x@b_between, nde = x@c_prime, te = a * x@b_between + x@c_prime,
    own = a * x@b_within, spillover = a * (x@b_between - x@b_within))
}

# The "Estimand and assumptions" block shared by print() and summary(): the
# design, the cluster count and size range, and one line per row of the
# assumptions table (D9), adjusted by `covariates_centered` (Behavior 8).
.cluster_assumptions_block <- function(x) {
  sizes <- x@cluster_sizes
  upper <- if (isTRUE(x@covariates_centered)) {
    paste0("Own (a * b_within): no unmeasured lower-level M-Y confounding; ",
           "additive upper-level confounders are allowed because level-1 ",
           "covariates are cluster-mean centered.")
  } else {
    paste0("Own (a * b_within): no unmeasured lower-level M-Y confounding. ",
           "Level-1 covariates in the outcome model have no cluster-mean ",
           "companion, so robustness to upper-level confounding does NOT hold.")
  }
  items <- c(
    sprintf(paste0("Design: treatment `%s` assigned to %d clusters (`%s`, ",
                   "sizes %d to %d); linear mixed models with a random ",
                   "cluster intercept, mediator entering through the ",
                   "observed cluster mean."),
            x@treatment, x@n_clusters, x@cluster, min(sizes), max(sizes)),
    paste0("All rows: linear models with no mediator-by-treatment or ",
           "mediator-by-covariate products; treatment randomized; clusters ",
           "intact."),
    upper,
    paste0("Spillover, NIE and NDE: also no unmeasured upper-level M-Y ",
           "confounding."),
    "TE: no assumption beyond randomization of the treatment.",
    paste0("Own/spillover split: a cross-world assumption across ",
           "individuals in a cluster; no treatment-induced M-Y confounding."),
    paste0("Interference only through the observed cluster mean of the ",
           "mediator and none between clusters; members missing from the ",
           "analysis rows are assumed not to drive their peers' outcomes.")
  )
  wrap <- function(txt, first) {
    strwrap(txt, width = 88, initial = first, prefix = "", exdent = 4)
  }
  c("Estimand and assumptions:",
    wrap(items[1], "  "),
    unlist(lapply(items[-1], wrap, first = "  - ")))
}

#' Print Method for ClusterMediationData
#'
#' @param x A ClusterMediationData object
#' @param ... Additional arguments (unused)
#' @noRd
S7::method(print, ClusterMediationData) <- function(x, ...) {
  cat("<ClusterMediationData>\n")
  cat(sprintf("  %s -> %s -> %s  (clusters: %s)\n",
              x@treatment, x@mediator, x@outcome, x@cluster))
  cat(sprintf("  a = %+.4f   b_within = %+.4f   b_between = %+.4f   c' = %+.4f\n",
              x@a_path, x@b_within, x@b_between, x@c_prime))
  cat(sprintf("  NIE (a * b_between) = %+.4f\n", x@a_path * x@b_between))
  cat(sprintf("  n = %d in %d clusters (sizes %d to %d)   |   %s outcome model, %s SEs\n",
              x@n_obs, x@n_clusters, min(x@cluster_sizes), max(x@cluster_sizes),
              x@parameterization, x@se_type))
  cat(paste0(.cluster_assumptions_block(x), "\n"), sep = "")
  invisible(x)
}


#' Summary Method for ClusterMediationData
#'
#' @param object A ClusterMediationData object
#' @param level Confidence level for the normal-approximation intervals.
#' @param ... Additional arguments (ignored)
#' @noRd
S7::method(summary, ClusterMediationData) <- function(object, level = 0.95, ...) {
  checkmate::assert_number(level, lower = 0, upper = 1, .var.name = "level")
  keys <- c("nie", "nde", "te", "own", "spillover")
  est <- .cluster_effect_vec(object)[keys]
  se <- .effect_se_or_na(object, keys)
  z <- stats::qnorm(1 - (1 - level) / 2)
  effects <- data.frame(estimate = unname(est), std.error = unname(se),
                        conf.low = unname(est - z * se),
                        conf.high = unname(est + z * se),
                        row.names = c("NIE", "NDE", "Total", "Own (a*b_within)",
                                      "Spillover"))
  structure(
    list(
      effects = effects,
      level = level,
      paths = paths(object),
      own_gap = .cluster_own_gap(object),
      own_se = unname(se["own"]),
      block = .cluster_assumptions_block(object),
      variables = c(treatment = object@treatment, mediator = object@mediator,
                    outcome = object@outcome, cluster = object@cluster),
      n_obs = object@n_obs,
      n_clusters = object@n_clusters,
      converged = object@converged,
      se_type = object@se_type,
      source_package = object@source_package
    ),
    class = "summary.ClusterMediationData"
  )
}


#' Print Summary for ClusterMediationData
#'
#' @param x A summary.ClusterMediationData object
#' @param ... Additional arguments (ignored)
#' @return Invisibly returns `x` (the `summary.ClusterMediationData` object).
#'   Called for its side effect of printing the formatted summary to the console.
#' @export
print.summary.ClusterMediationData <- function(x, ...) {
  cat("Summary of ClusterMediationData\n")
  cat("===============================\n\n")
  cat(sprintf("%s -> %s -> %s, clusters `%s`\n", x$variables["treatment"],
              x$variables["mediator"], x$variables["outcome"],
              x$variables["cluster"]))
  cat("\nEffects (unit contrast 0 -> 1):\n")
  print(round(x$effects, 4))
  cat(sprintf("  %g%% normal-approximation intervals (%s SEs).\n",
              100 * x$level, x$se_type))
  cat("  Own and spillover are the cluster-average, large-cluster approximation.\n")
  cat(sprintf(paste0("  D-own gap |a (b_between - b_within)| / H = %.4g ",
                     "(own SE %.4g)%s\n"), x$own_gap, x$own_se,
              if (!is.na(x$own_se) && x$own_gap > 0.5 * x$own_se) {
                "; larger than half the SE, so read the split with care"
              } else {
                ""
              }))
  cat("\nPath coefficients:\n")
  print(round(x$paths, 4))
  cat("\n")
  cat(paste0(x$block, "\n"), sep = "")
  cat("\nSample Size:", x$n_obs, "in", x$n_clusters, "clusters\n")
  cat("Converged:  ", ifelse(x$converged, "Yes", "No"), "\n")
  cat("Source:     ", x$source_package, "\n")
  invisible(x)
}

#' SEMFit S7 Class
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' S7 class holding a structural equation model fitted by the native
#' maximum-likelihood engine (see [fit_sem()]): estimates, their covariance,
#' the parameter table, defined parameters (`:=`) with delta-method standard
#' errors, and the diagnostics of the optimizer.
#'
#' @param theta Named numeric vector: free-parameter estimates
#' @param vcov Numeric matrix: covariance of `theta` (projected onto the active
#'   constraints and bounds; `NA` when the model is not identified)
#' @param table Data frame: one row per parameter-table row with `lhs`, `op`,
#'   `rhs`, `label`, `free`, `est` and `se`
#' @param defined Data frame of `:=` parameters: `name`, `expr`, `est`, `se`
#' @param f Numeric scalar: minimized maximum-likelihood discrepancy
#' @param n_obs,n_dropped Integer scalars: rows used and rows dropped for
#'   missing values (listwise deletion)
#' @param df Numeric scalar: degrees of freedom
#' @param information Character scalar: `"observed"` or `"expected"`
#' @param converged Logical scalar: the acceptance gate passed
#' @param data Data frame: the rows used, on the model's observed variables
#' @param model Character scalar: the model syntax
#' @param diagnostics List: optimizer diagnostics (`status`, `decrement`,
#'   `retries`, `active_bounds`, `active_constraints`, `improper`,
#'   `sign_check`)
#' @param internals List: the internal index objects the engine needs
#'   (`ram`, `par_map`, `constraints`); not part of the interface
#' @param call Call object or NULL: the call that produced the fit
#'
#' @return A SEMFit S7 object
#' @usage
#' SEMFit(theta, vcov, table, defined, f, n_obs, n_dropped, df, information,
#'   converged, data, model, diagnostics, internals, call)
#'
#' @seealso [fit_sem()]
#' @export
SEMFit <- S7::new_class(
  "SEMFit",
  package = "medfit",
  properties = list(
    theta = S7::class_numeric,
    vcov = S7::new_S3_class("matrix"),
    table = S7::class_data.frame,
    defined = S7::class_data.frame,
    f = S7::class_numeric,
    n_obs = S7::class_integer,
    n_dropped = S7::class_integer,
    df = S7::class_numeric,
    information = S7::class_character,
    converged = S7::class_logical,
    data = S7::class_data.frame,
    model = S7::class_character,
    diagnostics = S7::class_list,
    internals = S7::class_list,
    call = S7::class_call | NULL
  ),
  validator = function(self) {
    q <- length(self@theta)
    if (is.null(names(self@theta)) || anyNA(names(self@theta))) {
      return("theta must be named")
    }
    if (!identical(dim(self@vcov), c(q, q))) {
      return("vcov must be a square matrix with one row per element of theta")
    }
    if (!identical(rownames(self@vcov), names(self@theta))) {
      return("vcov must be named like theta")
    }
    if (length(self@information) != 1L || !(self@information %in% c("observed", "expected"))) {
      return("information must be 'observed' or 'expected'")
    }
    if (length(self@n_obs) != 1L || self@n_obs < 1L) {
      return("n_obs must be a positive integer")
    }
    if (nrow(self@data) != self@n_obs) {
      return("data must have n_obs rows")
    }
    if (!all(c("lhs", "op", "rhs", "est", "se") %in% names(self@table))) {
      return("table must have columns lhs, op, rhs, est and se")
    }
    if (!all(c("name", "expr", "est", "se") %in% names(self@defined))) {
      return("defined must have columns name, expr, est and se")
    }
    NULL
  }
)
