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
#' @usage NULL
#'
#' @details
#' This class provides a unified container for mediation model information
#' extracted from various model types (lm, glm, lavaan, etc.).
#' It ensures consistency across the mediation analysis ecosystem.
#'
#' The class includes comprehensive validation to ensure data integrity.
#'
#' @examples
#' \dontrun{
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
#' @usage NULL
#'
#' @details
#' ## Serial Mediation Structure
#'
#' Serial mediation models the indirect effect flowing through a sequence of
#' mediators. The total indirect effect is the product of all path coefficients:
#'
#' - **2 mediators (product-of-three)**: Indirect = a * d * b
#' - **3 mediators (product-of-four)**: Indirect = a * d21 * d32 * b
#' - **k mediators (product-of-k+1)**: Indirect = a * d21 * d32 * ... * d(k,k-1) * b
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
#' \dontrun{
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
#'
#' @details
#' This class standardizes bootstrap inference results across different
#' bootstrap methods (parametric, nonparametric, plugin).
#'
#' The class includes validation to ensure consistency between
#' method type and required fields.
#'
#' @examples
#' \dontrun{
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

    # Validate method
    if (length(self@method) != 1) {
      return("method must be a single character string")
    }
    if (!(self@method %in% c("parametric", "nonparametric", "plugin"))) {
      return("method must be 'parametric', 'nonparametric', or 'plugin'")
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
#' \eqn{INTmed = \theta_3 \beta_1}{INTmed = t3*b1}, and
#' \eqn{PIE = \theta_2 \beta_1}{PIE = t2*b1}. When \eqn{\theta_3 = 0}{t3 = 0} the
#' decomposition collapses to standard simple mediation (CDE = NDE = \eqn{\theta_1}{t1};
#' INTref = INTmed = 0; NIE = PIE = \eqn{\theta_2\beta_1}{t2*b1}).
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
