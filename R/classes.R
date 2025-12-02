# S7 Class Definitions for medfit
#
# This file defines the core S7 classes:
# - MediationData: Container for mediation model structure
# - BootstrapResult: Container for bootstrap inference results

#' MediationData Class
#'
#' @description
#' S7 class containing standardized mediation model structure, including
#' path coefficients, parameter estimates, variance-covariance matrix,
#' and metadata.
#'
#' @details
#' This class provides a unified container for mediation model information
#' extracted from various model types (lm, glm, lavaan, OpenMx, etc.).
#' It ensures consistency across the mediation analysis ecosystem.
#'
#' ## Properties
#'
#' **Core paths**:
#' - `a_path`: Effect of treatment on mediator (X → M)
#' - `b_path`: Effect of mediator on outcome controlling for treatment (M → Y|X)
#' - `c_prime`: Direct effect of treatment on outcome (X → Y|M)
#'
#' **Parameters**:
#' - `estimates`: Vector of all parameter estimates
#' - `vcov`: Variance-covariance matrix of estimates
#'
#' **Residual variances** (for Gaussian models):
#' - `sigma_m`: Residual standard deviation for mediator model
#' - `sigma_y`: Residual standard deviation for outcome model
#'
#' **Variable names**:
#' - `treatment`: Name of treatment variable
#' - `mediator`: Name of mediator variable
#' - `outcome`: Name of outcome variable
#' - `mediator_predictors`: Character vector of predictors in mediator model
#' - `outcome_predictors`: Character vector of predictors in outcome model
#'
#' **Data and metadata**:
#' - `data`: Original data frame (optional)
#' - `n_obs`: Number of observations
#' - `converged`: Logical indicating model convergence
#' - `source_package`: Name of package/engine used for fitting
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


#' BootstrapResult Class
#'
#' @description
#' S7 class containing results from bootstrap inference, including
#' point estimates, confidence intervals, and bootstrap distribution.
#'
#' @details
#' This class standardizes bootstrap inference results across different
#' bootstrap methods (parametric, nonparametric, plugin).
#'
#' ## Properties
#'
#' **Point estimates**:
#' - `estimate`: Point estimate of the statistic
#'
#' **Confidence intervals**:
#' - `ci_lower`: Lower bound of confidence interval
#' - `ci_upper`: Upper bound of confidence interval
#' - `ci_level`: Confidence level (e.g., 0.95 for 95% CI)
#'
#' **Bootstrap distribution**:
#' - `boot_estimates`: Vector of bootstrap estimates
#' - `n_boot`: Number of bootstrap samples
#'
#' **Method**:
#' - `method`: Bootstrap method ("parametric", "nonparametric", or "plugin")
#'
#' **Metadata**:
#' - `call`: Original function call (optional)
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
#' @export
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
#' @export
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
#' @export
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
#' @export
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
#' @export
S7::method(show, MediationData) <- function(object) {
  print(object)
}


#' Show Method for BootstrapResult
#'
#' @param object A BootstrapResult object
#' @export
S7::method(show, BootstrapResult) <- function(object) {
  print(object)
}
