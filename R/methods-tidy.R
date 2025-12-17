# Tidyverse Methods (tidy, glance)
#
# This file provides tidyverse-compatible methods for mediation objects:
# - tidy(): Convert to tidy tibble of effects/paths
# - glance(): Single-row summary of model
#
# Note: S7 objects need explicit dispatch handling since S3 method dispatch
# looks for "medfit::MediationData" as the class name, which can't be
# used in a function name directly. We use wrapper functions instead.

# Register S3 methods for S7 classes by adding explicit class attribute
# Since S7 class names contain "::", we use .onLoad to register methods

#' @export
tidy.S7_object <- function(x, ...) {
  if (S7::S7_inherits(x, MediationData)) {
    return(.tidy_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, SerialMediationData)) {
    return(.tidy_serial_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, BootstrapResult)) {
    return(.tidy_bootstrap_result(x, ...))
  }

  stop("tidy() not implemented for this S7 object type.", call. = FALSE)
}


#' @export
glance.S7_object <- function(x, ...) {
  if (S7::S7_inherits(x, MediationData)) {
    return(.glance_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, SerialMediationData)) {
    return(.glance_serial_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, BootstrapResult)) {
    return(.glance_bootstrap_result(x, ...))
  }

  stop("glance() not implemented for this S7 object type.", call. = FALSE)
}

#' Tidy a MediationData Object
#'
#' @description
#' Convert a MediationData object to a tidy tibble containing
#' path coefficients and mediation effects.
#'
#' @param x A MediationData object
#' @param type Character: what to include in output
#'   \itemize{
#'     \item `"all"`: Both paths and effects (default)
#'     \item `"paths"`: Only path coefficients (a, b, c')
#'     \item `"effects"`: Only mediation effects (NIE, NDE, TE)
#'   }
#' @param conf.int Logical: include confidence intervals? (default: FALSE)
#' @param conf.level Confidence level for intervals (default: 0.95)
#' @param ... Additional arguments (ignored)
#'
#' @return A tibble with columns:
#'   \itemize{
#'     \item `term`: Name of the coefficient or effect
#'     \item `estimate`: Point estimate
#'     \item `std.error`: Standard error (if available)
#'     \item `conf.low`: Lower CI bound (if conf.int = TRUE)
#'     \item `conf.high`: Upper CI bound (if conf.int = TRUE)
#'   }
#'
#' @examples
#' # Generate example data
#' set.seed(123)
#' n <- 100
#' mydata <- data.frame(X = rnorm(n))
#' mydata$M <- 0.5 * mydata$X + rnorm(n)
#' mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)
#'
#' result <- med(
#'   data = mydata,
#'   treatment = "X",
#'   mediator = "M",
#'   outcome = "Y"
#' )
#'
#' # Get tidy output
#' tidy(result)
#'
#' # Only effects
#' tidy(result, type = "effects")
#'
#' # With confidence intervals
#' tidy(result, conf.int = TRUE)
#'
#' @noRd
.tidy_mediation_data <- function(x, type = c("all", "paths", "effects"),
                                  conf.int = FALSE, conf.level = 0.95, ...) {
  type <- match.arg(type)

  # Extract effects and paths
  paths_vec <- paths(x)
  nie_val <- as.numeric(nie(x))
  nde_val <- as.numeric(nde(x))
  te_val <- as.numeric(te(x))

  # Build tibble based on type
  if (type == "paths") {
    result <- data.frame(
      term = names(paths_vec),
      estimate = unname(paths_vec),
      stringsAsFactors = FALSE
    )
  } else if (type == "effects") {
    result <- data.frame(
      term = c("nie", "nde", "te"),
      estimate = c(nie_val, nde_val, te_val),
      stringsAsFactors = FALSE
    )
  } else {
    # "all" - combine both
    result <- data.frame(
      term = c(names(paths_vec), "nie", "nde", "te"),
      estimate = c(unname(paths_vec), nie_val, nde_val, te_val),
      stringsAsFactors = FALSE
    )
  }

  # Add standard errors if we can compute them
  if (type %in% c("paths", "all")) {
    vcov_mat <- x@vcov
    param_names <- names(x@estimates)

    # Try to get SEs for paths
    a_idx <- grep(paste0("^m_", x@treatment, "$"), param_names)
    b_idx <- grep(paste0("^y_", x@mediator, "$"), param_names)
    cp_idx <- grep(paste0("^y_", x@treatment, "$"), param_names)

    if (length(a_idx) > 0 && length(b_idx) > 0 && length(cp_idx) > 0) {
      se_a <- sqrt(vcov_mat[a_idx[1], a_idx[1]])
      se_b <- sqrt(vcov_mat[b_idx[1], b_idx[1]])
      se_cp <- sqrt(vcov_mat[cp_idx[1], cp_idx[1]])

      if (type == "paths") {
        result$std.error <- c(se_a, se_b, se_cp)
      } else {
        # For "all", add SEs for paths and NA for effects (need delta method)
        result$std.error <- c(se_a, se_b, se_cp, NA, NA, NA)
      }
    }
  }

  # Add confidence intervals
  if (conf.int) {
    if (!"std.error" %in% names(result)) {
      result$std.error <- NA_real_
    }

    z <- stats::qnorm(1 - (1 - conf.level) / 2)
    result$conf.low <- result$estimate - z * result$std.error
    result$conf.high <- result$estimate + z * result$std.error
  }

  # Convert to tibble if available, otherwise data.frame
  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  result
}


#' Glance at a MediationData Object
#'
#' @description
#' Get a one-row summary of a MediationData object containing
#' key model statistics.
#'
#' @param x A MediationData object
#' @param ... Additional arguments (ignored)
#'
#' @return A one-row tibble with columns:
#'   \itemize{
#'     \item `nie`: Natural indirect effect
#'     \item `nde`: Natural direct effect
#'     \item `te`: Total effect
#'     \item `pm`: Proportion mediated
#'     \item `nobs`: Number of observations
#'     \item `converged`: Whether model converged
#'   }
#'
#' @examples
#' # Generate example data
#' set.seed(123)
#' n <- 100
#' mydata <- data.frame(X = rnorm(n))
#' mydata$M <- 0.5 * mydata$X + rnorm(n)
#' mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)
#'
#' result <- med(
#'   data = mydata,
#'   treatment = "X",
#'   mediator = "M",
#'   outcome = "Y"
#' )
#'
#' glance(result)
#'
#' @noRd
.glance_mediation_data <- function(x, ...) {
  result <- data.frame(
    nie = as.numeric(nie(x)),
    nde = as.numeric(nde(x)),
    te = as.numeric(te(x)),
    pm = as.numeric(pm(x)),
    nobs = nobs(x),
    converged = x@converged,
    stringsAsFactors = FALSE
  )

  # Convert to tibble if available
  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  result
}


#' Tidy a SerialMediationData Object
#'
#' @inheritParams tidy.MediationData
#' @param x A SerialMediationData object
#'
#' @noRd
.tidy_serial_mediation_data <- function(x, type = c("all", "paths", "effects"),
                                         conf.int = FALSE, conf.level = 0.95, ...) {
  type <- match.arg(type)

  # Extract effects and paths
  paths_vec <- paths(x)
  nie_val <- as.numeric(nie(x))
  nde_val <- as.numeric(nde(x))
  te_val <- as.numeric(te(x))

  # Build result based on type
  if (type == "paths") {
    result <- data.frame(
      term = names(paths_vec),
      estimate = unname(paths_vec),
      stringsAsFactors = FALSE
    )
  } else if (type == "effects") {
    result <- data.frame(
      term = c("nie", "nde", "te"),
      estimate = c(nie_val, nde_val, te_val),
      stringsAsFactors = FALSE
    )
  } else {
    result <- data.frame(
      term = c(names(paths_vec), "nie", "nde", "te"),
      estimate = c(unname(paths_vec), nie_val, nde_val, te_val),
      stringsAsFactors = FALSE
    )
  }

  # Add CI if requested (without SEs for serial - need full delta method)
  if (conf.int) {
    result$conf.low <- NA_real_
    result$conf.high <- NA_real_
    warning("Confidence intervals for serial mediation require bootstrap. ",
            "Use bootstrap_mediation() for robust inference.", call. = FALSE)
  }

  # Convert to tibble if available
  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  result
}


#' Glance at a SerialMediationData Object
#'
#' @inheritParams glance.MediationData
#' @param x A SerialMediationData object
#'
#' @noRd
.glance_serial_mediation_data <- function(x, ...) {
  result <- data.frame(
    nie = as.numeric(nie(x)),
    nde = as.numeric(nde(x)),
    te = as.numeric(te(x)),
    pm = as.numeric(pm(x)),
    n_mediators = length(x@mediators),
    nobs = nobs(x),
    converged = x@converged,
    stringsAsFactors = FALSE
  )

  # Convert to tibble if available
  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  result
}


#' Tidy a BootstrapResult Object
#'
#' @param x A BootstrapResult object
#' @param ... Additional arguments (ignored)
#'
#' @return A tibble with bootstrap estimate and CI
#'
#' @noRd
.tidy_bootstrap_result <- function(x, ...) {
  result <- data.frame(
    term = "estimate",
    estimate = x@estimate,
    std.error = if (x@method != "plugin") stats::sd(x@boot_estimates) else NA_real_,
    conf.low = x@ci_lower,
    conf.high = x@ci_upper,
    stringsAsFactors = FALSE
  )

  # Convert to tibble if available
  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  result
}


#' Glance at a BootstrapResult Object
#'
#' @param x A BootstrapResult object
#' @param ... Additional arguments (ignored)
#'
#' @return A one-row tibble with bootstrap summary
#'
#' @noRd
.glance_bootstrap_result <- function(x, ...) {
  result <- data.frame(
    estimate = x@estimate,
    ci_level = x@ci_level,
    method = x@method,
    n_boot = x@n_boot,
    stringsAsFactors = FALSE
  )

  # Convert to tibble if available
  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  result
}
