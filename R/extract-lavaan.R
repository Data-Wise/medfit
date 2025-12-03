# S7 Method for Extracting Mediation Structure from lavaan Models
#
# This file implements extract_mediation() method for lavaan SEM models.
#
# The extraction supports simple mediation patterns:
#   X -> M -> Y
# where the lavaan model typically specifies:
#   M ~ a*X
#   Y ~ b*M + cp*X
#
# Note: This method is registered dynamically in zzz.R when lavaan is available

#' Extract Mediation Structure from lavaan Model
#'
#' Internal function for extracting mediation structure from lavaan models.
#' This function is registered as an S7 method in `.onLoad()` when lavaan
#' is available.
#'
#' @param object Fitted lavaan model object
#' @param treatment Character: name of the treatment variable
#' @param mediator Character: name of the mediator variable
#' @param outcome Character: name of the outcome variable (optional, auto-detected)
#' @param a_label Character: label for the a path in lavaan model (default: "a")
#' @param b_label Character: label for the b path in lavaan model (default: "b")
#' @param cp_label Character: label for the c' path in lavaan model (default: "cp")
#' @param standardized Logical: extract standardized coefficients? (default: FALSE)
#' @param ... Additional arguments (ignored)
#'
#' @return A [MediationData] object
#'
#' @details
#' This method extracts mediation structure from a fitted lavaan SEM model.
#' The lavaan model should specify labeled paths for the mediation structure.
#'
#' ## Typical lavaan Model Specification
#'
#' ```
#' model <- "
#'   # Mediator model
#'   M ~ a*X
#'
#'   # Outcome model
#'   Y ~ b*M + cp*X
#'
#'   # Indirect and total effects (optional)
#'   indirect := a*b
#'   total := cp + a*b
#' "
#' ```
#'
#' ## Path Labels
#'
#' By default, the function looks for paths labeled:
#' - `a`: Treatment -> Mediator path
#' - `b`: Mediator -> Outcome path
#' - `cp`: Treatment -> Outcome (direct effect) path
#'
#' You can customize these labels using the `a_label`, `b_label`, and
#' `cp_label` arguments.
#'
#' ## Alternative: Unlabeled Paths
#'
#' If paths are not labeled, the function will attempt to identify them
#' by variable names. This requires specifying `treatment`, `mediator`,
#' and `outcome` arguments.
#'
#' @examples
#' \dontrun{
#' library(lavaan)
#'
#' # Define mediation model
#' model <- "
#'   M ~ a*X
#'   Y ~ b*M + cp*X
#' "
#'
#' # Fit model
#' fit <- sem(model, data = mydata)
#'
#' # Extract mediation structure
#' med_data <- extract_mediation(
#'   fit,
#'   treatment = "X",
#'   mediator = "M",
#'   outcome = "Y"
#' )
#' }
#'
#' @keywords internal
extract_mediation_lavaan <- function(object,
                                      treatment,
                                      mediator,
                                      outcome = NULL,
                                      a_label = "a",
                                      b_label = "b",
                                      cp_label = "cp",
                                      standardized = FALSE,
                                      ...) {

 # --- Check lavaan is available ---
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    stop("Package 'lavaan' is required for this method but is not installed.",
         call. = FALSE)
  }

  # --- Input Validation (using checkmate for fail-fast defensive programming) ---

  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_string(mediator, .var.name = "mediator")
  checkmate::assert_string(outcome, null.ok = TRUE, .var.name = "outcome")
  checkmate::assert_string(a_label, .var.name = "a_label")
  checkmate::assert_string(b_label, .var.name = "b_label")
  checkmate::assert_string(cp_label, .var.name = "cp_label")
  checkmate::assert_flag(standardized, .var.name = "standardized")

  # --- Extract Parameter Estimates ---

  # Get parameter estimates table
  if (standardized) {
    param_table <- lavaan::standardizedSolution(object)
    est_col <- "est.std"
  } else {
    param_table <- lavaan::parameterEstimates(object)
    est_col <- "est"
  }

  # --- Try to Extract Paths by Label First ---

  # Look for labeled paths
  a_row <- param_table[param_table$label == a_label, ]
  b_row <- param_table[param_table$label == b_label, ]
  cp_row <- param_table[param_table$label == cp_label, ]

  paths_found_by_label <- nrow(a_row) == 1 && nrow(b_row) == 1 && nrow(cp_row) == 1

  if (paths_found_by_label) {
    # Extract from labeled paths
    a_path <- a_row[[est_col]]
    b_path <- b_row[[est_col]]
    c_prime <- cp_row[[est_col]]

    # Auto-detect outcome if not provided
    if (is.null(outcome)) {
      outcome <- b_row$lhs[1]
    }
  } else {
    # Fall back to extracting by variable names
    # Find a path: mediator ~ treatment
    a_row <- param_table[param_table$lhs == mediator &
                          param_table$op == "~" &
                          param_table$rhs == treatment, ]

    if (nrow(a_row) == 0) {
      stop(sprintf(
        "Could not find a path (treatment -> mediator). Expected '%s ~ %s'",
        mediator, treatment
      ), call. = FALSE)
    }

    a_path <- a_row[[est_col]][1]

    # Auto-detect outcome if not provided
    if (is.null(outcome)) {
      # Find equations where mediator is a predictor
      mediator_effects <- param_table[param_table$op == "~" &
                                        param_table$rhs == mediator, ]
      if (nrow(mediator_effects) > 0) {
        outcome <- mediator_effects$lhs[1]
      } else {
        stop("Could not auto-detect outcome variable. Please specify 'outcome' argument.",
             call. = FALSE)
      }
    }

    # Find b path: outcome ~ mediator
    b_row <- param_table[param_table$lhs == outcome &
                          param_table$op == "~" &
                          param_table$rhs == mediator, ]

    if (nrow(b_row) == 0) {
      stop(sprintf(
        "Could not find b path (mediator -> outcome). Expected '%s ~ %s'",
        outcome, mediator
      ), call. = FALSE)
    }

    b_path <- b_row[[est_col]][1]

    # Find c' path: outcome ~ treatment
    cp_row <- param_table[param_table$lhs == outcome &
                           param_table$op == "~" &
                           param_table$rhs == treatment, ]

    if (nrow(cp_row) == 0) {
      # c' might be zero (full mediation) or not in model
      # Set to 0 if not found
      c_prime <- 0
      warning("Direct effect (c' path) not found in model. Setting to 0.",
              call. = FALSE)
    } else {
      c_prime <- cp_row[[est_col]][1]
    }
  }

  # --- Extract All Parameters and Variance-Covariance Matrix ---

  # Get all free parameter estimates
  all_coef <- lavaan::coef(object)

  # Get variance-covariance matrix
  vcov_mat <- lavaan::vcov(object)

  # Create estimates vector with named elements
  estimates <- all_coef

  # Add convenient aliases for key paths (only if not already present)
  # Track which aliases we're adding (not overwriting)
  aliases_to_add <- character(0)
  if (!("a" %in% names(estimates))) {
    aliases_to_add <- c(aliases_to_add, "a")
  }
  if (!("b" %in% names(estimates))) {
    aliases_to_add <- c(aliases_to_add, "b")
  }
  if (!("c_prime" %in% names(estimates))) {
    aliases_to_add <- c(aliases_to_add, "c_prime")
  }

  # Add aliases
  estimates["a"] <- a_path
  estimates["b"] <- b_path
  estimates["c_prime"] <- c_prime

  # Expand vcov to include only NEW aliases
  n_orig <- length(all_coef)
  n_aliases <- length(aliases_to_add)
  n_total <- n_orig + n_aliases

  vcov_expanded <- matrix(0, nrow = n_total, ncol = n_total)

  # Build names for expanded vcov
  vcov_names <- c(names(all_coef), aliases_to_add)
  rownames(vcov_expanded) <- vcov_names
  colnames(vcov_expanded) <- vcov_names

  # Fill in original vcov
  vcov_expanded[1:n_orig, 1:n_orig] <- vcov_mat

  # For aliases, we need to find the corresponding original parameter
  # and copy its variance. Only do this for aliases that were actually added.

  # Helper function to copy variance for an alias
  copy_alias_variance <- function(alias_name, param_names_to_try) {
    if (!(alias_name %in% aliases_to_add)) {
      # Alias already exists in original coefficients, no need to copy
      return()
    }
    alias_idx <- which(vcov_names == alias_name)
    if (length(alias_idx) == 0) return()

    for (param_name in param_names_to_try) {
      if (param_name %in% names(all_coef)) {
        orig_idx <- which(names(all_coef) == param_name)
        vcov_expanded[alias_idx, alias_idx] <<- vcov_mat[orig_idx, orig_idx]
        return()
      }
    }
  }

  # Find and copy variance for "a" path
  a_param_name <- paste0(mediator, "~", treatment)
  copy_alias_variance("a", a_param_name)

  # Find and copy variance for "b" path
  b_param_name <- paste0(outcome, "~", mediator)
  copy_alias_variance("b", b_param_name)

  # Find and copy variance for "c_prime" path
  cp_param_name <- paste0(outcome, "~", treatment)
  copy_alias_variance("c_prime", cp_param_name)

  # --- Extract Residual Variances ---

  # In lavaan, error variances are estimated parameters
  # Look for variance of mediator and outcome residuals

  sigma_m <- NULL
  sigma_y <- NULL

  # Mediator residual variance
  m_var_row <- param_table[param_table$lhs == mediator &
                            param_table$op == "~~" &
                            param_table$rhs == mediator, ]
  if (nrow(m_var_row) > 0) {
    m_var <- m_var_row[[est_col]][1]
    if (m_var > 0) {
      sigma_m <- sqrt(m_var)
    }
  }

  # Outcome residual variance
  y_var_row <- param_table[param_table$lhs == outcome &
                            param_table$op == "~~" &
                            param_table$rhs == outcome, ]
  if (nrow(y_var_row) > 0) {
    y_var <- y_var_row[[est_col]][1]
    if (y_var > 0) {
      sigma_y <- sqrt(y_var)
    }
  }

  # --- Get Data ---

  # Try to get data from lavaan object
  data <- tryCatch({
    d <- lavaan::lavInspect(object, "data")
    # lavaan may return a matrix; convert to data.frame if possible
    if (is.matrix(d)) {
      as.data.frame(d)
    } else if (is.data.frame(d)) {
      d
    } else {
      # If it's something else (like numeric), return NULL
      NULL
    }
  }, error = function(e) {
    NULL
  })

  # Get sample size
  n_obs <- lavaan::lavInspect(object, "nobs")
  if (length(n_obs) > 1) {
    # Multiple groups - use total
    n_obs <- sum(n_obs)
  }

  # --- Get Predictor Names ---

  # Mediator predictors: variables that predict the mediator
  m_predictors <- param_table[param_table$lhs == mediator &
                               param_table$op == "~", "rhs"]

  # Outcome predictors: variables that predict the outcome
  y_predictors <- param_table[param_table$lhs == outcome &
                               param_table$op == "~", "rhs"]

  # --- Check Convergence ---

  converged <- lavaan::lavInspect(object, "converged")

  # --- Create MediationData Object ---

  MediationData(
    a_path = a_path,
    b_path = b_path,
    c_prime = c_prime,
    estimates = estimates,
    vcov = vcov_expanded,
    sigma_m = sigma_m,
    sigma_y = sigma_y,
    treatment = treatment,
    mediator = mediator,
    outcome = outcome,
    mediator_predictors = m_predictors,
    outcome_predictors = y_predictors,
    data = data,
    n_obs = as.integer(n_obs),
    converged = converged,
    source_package = "lavaan"
  )
}


#' Register lavaan Method for extract_mediation
#'
#' This function is called from `.onLoad()` to register the S7 method
#' for lavaan objects when the lavaan package is available.
#'
#' @keywords internal
.register_lavaan_method <- function() {
  if (requireNamespace("lavaan", quietly = TRUE)) {
    # Get the lavaan S4 class
    lavaan_class <- tryCatch({
      S7::as_class(methods::getClass("lavaan", where = asNamespace("lavaan")))
    }, error = function(e) {
      NULL
    })

    if (!is.null(lavaan_class)) {
      # Register the method
      S7::method(extract_mediation, lavaan_class) <- extract_mediation_lavaan
    }
  }
}
