# S7 Method for Extracting Mediation Structure from lm/glm Models
#
# This file implements extract_mediation() methods for:
# - lm (linear models)
# - glm (generalized linear models)
#
# The extraction follows the simple mediation pattern:
#   X -> M -> Y  # nolint: commented_code_linter.
# where:
#   - Mediator model: M ~ X + covariates
#   - Outcome model: Y ~ X + M + covariates

# Define S7 class wrappers for lm and glm
# These are needed for S7 method dispatch on S3 classes
lm_class <- S7::new_S3_class("lm")
glm_class <- S7::new_S3_class("glm")


#' Extract Mediation Structure from lm Model
#'
#' @param object Fitted lm model for the mediator (M ~ X + covariates)
#' @param model_y Fitted lm or glm model for the outcome (Y ~ X + M + covariates)
#' @param treatment Character: name of the treatment variable
#' @param mediator Character: name of the mediator variable
#' @param outcome Character: name of the outcome variable (optional, auto-detected)
#' @param data Data frame: original data (optional, extracted from model if available)
#' @param ... Additional arguments (ignored)
#'
#' @return A [MediationData] object
#'
#' @details
#' This method extracts mediation structure from two fitted linear models:
#' 1. Mediator model: `M ~ X + covariates`
#' 2. Outcome model: `Y ~ X + M + covariates`
#'
#' The method extracts:
#' - Path coefficients (a, b, c')
#' - Combined parameter vector and variance-covariance matrix
#' - Residual standard deviations (for Gaussian models)
#' - Variable names and metadata
#'
#' @examples
#' \dontrun{
#' # Simulate data
#' set.seed(123)
#' n <- 200
#' X <- rnorm(n)
#' M <- 0.5 * X + rnorm(n)
#' Y <- 0.3 * M + 0.2 * X + rnorm(n)
#' data <- data.frame(X = X, M = M, Y = Y)
#'
#' # Fit models
#' fit_m <- lm(M ~ X, data = data)
#' fit_y <- lm(Y ~ X + M, data = data)
#'
#' # Extract mediation structure
#' med_data <- extract_mediation(
#'   fit_m,
#'   model_y = fit_y,
#'   treatment = "X",
#'   mediator = "M"
#' )
#' }
#'
#' @noRd
S7::method(extract_mediation, lm_class) <- function(object,
                                                     model_y,
                                                     treatment,
                                                     mediator,
                                                     outcome = NULL,
                                                     data = NULL,
                                                     ...) {
  # Call internal extraction function
  .extract_mediation_lm_impl(
    model_m = object,
    model_y = model_y,
    treatment = treatment,
    mediator = mediator,
    outcome = outcome,
    data = data
  )
}


#' Extract Mediation Structure from glm Model
#'
#' @inheritParams extract_mediation
#' @noRd
S7::method(extract_mediation, glm_class) <- function(object,
                                                      model_y,
                                                      treatment,
                                                      mediator,
                                                      outcome = NULL,
                                                      data = NULL,
                                                      ...) {
  # Call internal extraction function
  .extract_mediation_lm_impl(
    model_m = object,
    model_y = model_y,
    treatment = treatment,
    mediator = mediator,
    outcome = outcome,
    data = data
  )
}


#' Internal Implementation for lm/glm Extraction
#'
#' @param model_m Fitted model for mediator
#' @param model_y Fitted model for outcome
#' @param treatment Treatment variable name
#' @param mediator Mediator variable name
#' @param outcome Outcome variable name (auto-detected if NULL)
#' @param data Original data (extracted from model if NULL)
#'
#' @return MediationData object
#' @keywords internal
.extract_mediation_lm_impl <- function(model_m,
                                        model_y,
                                        treatment,
                                        mediator,
                                        outcome = NULL,
                                        data = NULL) {


  # --- Input Validation (using checkmate for fail-fast defensive programming) ---

  # Validate model_y is provided and is correct type
  checkmate::assert_multi_class(
    model_y,
    classes = c("lm", "glm"),
    .var.name = "model_y"
  )

  # Validate treatment and mediator are single character strings
  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_string(mediator, .var.name = "mediator")

  # Validate outcome if provided
  checkmate::assert_string(outcome, null.ok = TRUE, .var.name = "outcome")

  # Validate data if provided
  checkmate::assert_data_frame(data, null.ok = TRUE, .var.name = "data")

  # Get coefficient names from models
  coef_m <- stats::coef(model_m)
  coef_y <- stats::coef(model_y)

  # Check treatment exists in mediator model
  checkmate::assert_choice(
    treatment,
    choices = names(coef_m),
    .var.name = "treatment in mediator model"
  )

  # Check treatment exists in outcome model
  checkmate::assert_choice(
    treatment,
    choices = names(coef_y),
    .var.name = "treatment in outcome model"
  )

  # Check mediator exists in outcome model
  checkmate::assert_choice(
    mediator,
    choices = names(coef_y),
    .var.name = "mediator in outcome model"
  )

  # --- Extract Path Coefficients ---

  # a path: effect of X on M
  a_path <- unname(coef_m[treatment])

  # b path: effect of M on Y (controlling for X)
  b_path <- unname(coef_y[mediator])

  # c' path: direct effect of X on Y (controlling for M)
  c_prime <- unname(coef_y[treatment])

  # --- Determine Outcome Variable Name ---

  if (is.null(outcome)) {
    # Extract from model formula
    outcome <- .get_response_var(model_y)
  }

  # --- Extract Variance-Covariance Matrices ---

  vcov_m <- stats::vcov(model_m)
  vcov_y <- stats::vcov(model_y)

  # Create combined parameter vector with named elements
  # Structure: mediator model params, then outcome model params
  # Use prefixes to avoid name collisions
  names_m <- paste0("m_", names(coef_m))
  names_y <- paste0("y_", names(coef_y))

  estimates <- c(coef_m, coef_y)
  names(estimates) <- c(names_m, names_y)

  # Add convenient aliases for key paths
  estimates["a"] <- a_path
  estimates["b"] <- b_path
  estimates["c_prime"] <- c_prime

  # Create block-diagonal combined vcov matrix
  # This assumes independence between mediator and outcome model estimates
  n_m <- length(coef_m)
  n_y <- length(coef_y)
  n_total <- n_m + n_y + 3  # +3 for a, b, c_prime aliases

  vcov_combined <- matrix(0, nrow = n_total, ncol = n_total)
  rownames(vcov_combined) <- names(estimates)
  colnames(vcov_combined) <- names(estimates)

  # Fill in blocks
  vcov_combined[1:n_m, 1:n_m] <- vcov_m
  vcov_combined[(n_m + 1):(n_m + n_y), (n_m + 1):(n_m + n_y)] <- vcov_y

  # Copy variances for aliases
  # a is the same as m_treatment
  a_idx <- which(names(estimates) == "a")
  m_treatment_idx <- which(names_m == paste0("m_", treatment))
  vcov_combined[a_idx, a_idx] <- vcov_m[treatment, treatment]

  # b is the same as y_mediator
  b_idx <- which(names(estimates) == "b")
  y_mediator_idx <- which(names_y == paste0("y_", mediator))
  vcov_combined[b_idx, b_idx] <- vcov_y[mediator, mediator]

  # c_prime is the same as y_treatment
  cp_idx <- which(names(estimates) == "c_prime")
  vcov_combined[cp_idx, cp_idx] <- vcov_y[treatment, treatment]

  # --- Extract Residual Standard Deviations ---

  sigma_m <- .extract_sigma(model_m)
  sigma_y <- .extract_sigma(model_y)

  # --- Extract Data ---

  if (is.null(data)) {
    # Try to get data from model
    data <- tryCatch(
      stats::model.frame(model_m),
      error = function(e) NULL
    )
  }

  # Get sample size
  n_obs <- if (!is.null(data)) {
    nrow(data)
  } else {
    # Fall back to number of observations used in fitting
    length(stats::residuals(model_m))
  }

  # --- Get Predictor Names ---

  mediator_predictors <- names(coef_m)[-1]  # Exclude intercept
  outcome_predictors <- names(coef_y)[-1]   # Exclude intercept

  # --- Determine Source Package ---

  source_package <- if (inherits(model_m, "glm")) {
    "stats::glm"
  } else {
    "stats::lm"
  }

  # --- Check Convergence ---

  # For lm, always converged; for glm, check convergence
  converged <- if (inherits(model_m, "glm")) {
    model_m$converged && model_y$converged
  } else {
    TRUE
  }

  # --- Create MediationData Object ---

  MediationData(
    a_path = a_path,
    b_path = b_path,
    c_prime = c_prime,
    estimates = estimates,
    vcov = vcov_combined,
    sigma_m = sigma_m,
    sigma_y = sigma_y,
    treatment = treatment,
    mediator = mediator,
    outcome = outcome,
    mediator_predictors = mediator_predictors,
    outcome_predictors = outcome_predictors,
    data = data,
    n_obs = as.integer(n_obs),
    converged = converged,
    source_package = source_package
  )
}


#' Extract Response Variable Name from Model
#'
#' @param model Fitted model object
#' @return Character string: response variable name
#' @keywords internal
.get_response_var <- function(model) {
  formula_obj <- stats::formula(model)
  response <- all.vars(formula_obj)[1]
  return(response)
}


#' Extract Residual Standard Deviation from Model
#'
#' @param model Fitted model object
#' @return Numeric scalar or NULL
#' @keywords internal
.extract_sigma <- function(model) {
  if (inherits(model, "lm") && !inherits(model, "glm")) {
    # For lm, use sigma() or summary()$sigma
    return(stats::sigma(model))
  } else if (inherits(model, "glm")) {
    # For glm, check if Gaussian family
    if (model$family$family == "gaussian") {
      # For Gaussian GLM, sigma can be extracted
      return(sqrt(sum(stats::residuals(model, type = "pearson")^2) / model$df.residual))
    } else {
      # For non-Gaussian GLMs, sigma doesn't apply in the same way
      return(NULL)
    }
  }
  return(NULL)
}
