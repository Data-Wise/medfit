# Extract Mediation Structure from lm/glm Models
#
# This file implements the extract_mediation() method for lm and glm objects.
# It extracts path coefficients, variance-covariance matrices, and metadata
# from fitted linear and generalized linear models.

#' Extract Mediation Structure from lm/glm Models
#'
#' @description
#' Extract mediation structure from fitted lm or glm models. This method
#' requires two models: a mediator model (M ~ X + covariates) and an outcome
#' model (Y ~ X + M + covariates).
#'
#' @param object Fitted lm or glm object for the mediator model (M ~ X + ...)
#' @param model_y Fitted lm or glm object for the outcome model (Y ~ X + M + ...)
#' @param treatment Character string: name of the treatment variable
#' @param mediator Character string: name of the mediator variable
#' @param outcome Character string: name of the outcome variable. If NULL,
#'   extracted from the outcome model formula.
#' @param data Data frame: original data used for fitting. If NULL, attempts
#'   to extract from the model objects.
#' @param ... Additional arguments (currently ignored)
#'
#' @return A [MediationData] object containing:
#'   \itemize{
#'     \item Path coefficients (a, b, c')
#'     \item Combined parameter estimates and variance-covariance matrix
#'     \item Residual standard deviations (for Gaussian models)
#'     \item Variable names and metadata
#'   }
#'
#' @details
#' ## Model Requirements
#'
#' The mediator model (`object`) should have the form:
#' \preformatted{M ~ X + C1 + C2 + ...}
#'
#' The outcome model (`model_y`) should have the form:
#' \preformatted{Y ~ X + M + C1 + C2 + ...}
#'
#' Both models must include the treatment variable. The outcome model must

#' include the mediator variable.
#'
#' ## Path Extraction
#'
#' - **a path**: Coefficient of treatment in mediator model
#' - **b path**: Coefficient of mediator in outcome model
#' - **c' path**: Coefficient of treatment in outcome model (direct effect)
#'
#' ## Variance-Covariance Matrix
#'
#' The combined vcov matrix is constructed by stacking the relevant
#' coefficients from both models. For models with shared covariates,
#' off-diagonal blocks are set to zero (independence assumption).
#'
#' ## Residual Variances
#'
#' For Gaussian models (family = gaussian), residual standard deviations
#' are extracted using `sigma()`. For non-Gaussian GLMs, sigma values
#' are set to NULL.
#'
#' @examples
#' \dontrun{
#' # Simple mediation: X -> M -> Y
#' fit_m <- lm(M ~ X, data = mydata)
#' fit_y <- lm(Y ~ X + M, data = mydata)
#'
#' med_data <- extract_mediation(
#'   fit_m,
#'   model_y = fit_y,
#'   treatment = "X",
#'   mediator = "M"
#' )
#'
#' # With covariates
#' fit_m <- lm(M ~ X + age + gender, data = mydata)
#' fit_y <- lm(Y ~ X + M + age + gender, data = mydata)
#'
#' med_data <- extract_mediation(
#'   fit_m,
#'   model_y = fit_y,
#'   treatment = "X",
#'   mediator = "M"
#' )
#'
#' # GLM models
#' fit_m <- glm(M ~ X, data = mydata, family = gaussian())
#' fit_y <- glm(Y ~ X + M, data = mydata, family = binomial())
#'
#' med_data <- extract_mediation(
#'   fit_m,
#'   model_y = fit_y,
#'   treatment = "X",
#'   mediator = "M"
#' )
#' }
#'
#' @seealso [MediationData], [fit_mediation()], [bootstrap_mediation()]
#' @export
NULL

# Register method for lm class
S7::method(extract_mediation, S7::new_S3_class("lm")) <- function(
    object,
    model_y,
    treatment,
    mediator,
    outcome = NULL,
    data = NULL,
    ...
) {
  .extract_mediation_lm_impl(
    object = object,
    model_y = model_y,
    treatment = treatment,
    mediator = mediator,
    outcome = outcome,
    data = data,
    ...
  )
}

# Register method for glm class
S7::method(extract_mediation, S7::new_S3_class("glm")) <- function(
    object,
    model_y,
    treatment,
    mediator,
    outcome = NULL,
    data = NULL,
    ...
) {
  .extract_mediation_lm_impl(
    object = object,
    model_y = model_y,
    treatment = treatment,
    mediator = mediator,
    outcome = outcome,
    data = data,
    ...
  )
}


#' Internal Implementation for lm/glm Extraction
#'
#' @param object Fitted mediator model
#' @param model_y Fitted outcome model
#' @param treatment Treatment variable name
#' @param mediator Mediator variable name
#' @param outcome Outcome variable name (or NULL to auto-detect)
#' @param data Original data (or NULL to extract from models)
#' @param ... Additional arguments (ignored)
#'
#' @return MediationData object
#' @keywords internal
#' @noRd
.extract_mediation_lm_impl <- function(
    object,
    model_y,
    treatment,
    mediator,
    outcome = NULL,
    data = NULL,
    ...
) {
  # Validate inputs
  if (missing(model_y) || is.null(model_y)) {
    stop("model_y (outcome model) is required for lm/glm extraction")
  }

  if (missing(treatment) || is.null(treatment)) {
    stop("treatment variable name is required")
  }


  if (missing(mediator) || is.null(mediator)) {
    stop("mediator variable name is required")
  }

  # Extract outcome variable name if not provided
  if (is.null(outcome)) {
    outcome <- .get_response_var(model_y)
  }

  # Validate that treatment and mediator are in the models
  coef_m <- stats::coef(object)
  coef_y <- stats::coef(model_y)

  if (!(treatment %in% names(coef_m))) {
    stop(sprintf("Treatment variable '%s' not found in mediator model", treatment))
  }
  if (!(treatment %in% names(coef_y))) {
    stop(sprintf("Treatment variable '%s' not found in outcome model", treatment))
  }
  if (!(mediator %in% names(coef_y))) {
    stop(sprintf("Mediator variable '%s' not found in outcome model", mediator))
  }

  # Extract path coefficients
  a_path <- unname(coef_m[treatment])
  b_path <- unname(coef_y[mediator])
  c_prime <- unname(coef_y[treatment])

  # Extract variance-covariance matrices
  vcov_m <- stats::vcov(object)
  vcov_y <- stats::vcov(model_y)

  # Build combined estimates vector
  # Order: mediator model coefficients, then outcome model coefficients
  estimates <- c(coef_m, coef_y)

  # Add prefixes to distinguish coefficients from different models
  names(estimates) <- c(
    paste0("m_", names(coef_m)),
    paste0("y_", names(coef_y))
  )

  # Build block-diagonal combined vcov matrix
  # Assumes independence between M and Y model estimates
  n_m <- length(coef_m)
  n_y <- length(coef_y)
  n_total <- n_m + n_y

  vcov_combined <- matrix(0, nrow = n_total, ncol = n_total)
  vcov_combined[1:n_m, 1:n_m] <- vcov_m
  vcov_combined[(n_m + 1):n_total, (n_m + 1):n_total] <- vcov_y

  rownames(vcov_combined) <- names(estimates)
  colnames(vcov_combined) <- names(estimates)

  # Extract residual SDs (for Gaussian models)
  sigma_m <- .extract_sigma(object)
  sigma_y <- .extract_sigma(model_y)

  # Get predictor names
  mediator_predictors <- names(coef_m)[-1]  # Exclude intercept
  outcome_predictors <- names(coef_y)[-1]   # Exclude intercept

  # Get data
  if (is.null(data)) {
    # Try to extract from model
    data <- tryCatch(
      stats::model.frame(object),
      error = function(e) NULL
    )
  }

  # Get number of observations
  n_obs <- stats::nobs(object)

  # Check convergence (always TRUE for lm, check for glm)
  converged <- .check_convergence(object) && .check_convergence(model_y)

  # Determine source package
  source_package <- if (inherits(object, "glm")) "stats::glm" else "stats::lm"

  # Create and return MediationData object
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
#' @noRd
.get_response_var <- function(model) {
  formula <- stats::formula(model)
  response <- all.vars(formula)[1]
  return(response)
}


#' Extract Residual Standard Deviation
#'
#' @param model Fitted model object
#' @return Numeric scalar or NULL: residual SD for Gaussian models
#' @keywords internal
#' @noRd
.extract_sigma <- function(model) {
  # For lm objects
  if (inherits(model, "lm") && !inherits(model, "glm")) {
    return(stats::sigma(model))
  }

  # For glm objects
  if (inherits(model, "glm")) {
    # Only return sigma for Gaussian family
    fam <- stats::family(model)
    if (fam$family == "gaussian") {
      return(stats::sigma(model))
    } else {
      return(NULL)
    }
  }

  # Default: return NULL
  NULL
}


#' Check Model Convergence
#'
#' @param model Fitted model object
#' @return Logical: TRUE if converged or not applicable
#' @keywords internal
#' @noRd
.check_convergence <- function(model) {
  # lm models always "converge"
  if (inherits(model, "lm") && !inherits(model, "glm")) {
    return(TRUE)
  }

  # For glm, check the converged flag
  if (inherits(model, "glm")) {
    return(isTRUE(model$converged))
  }

  # Default: assume converged
  TRUE
}
