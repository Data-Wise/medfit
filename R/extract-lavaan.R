# Extract Mediation Structure from lavaan Models
#
# This file implements the extract_mediation() method for lavaan objects.
# The method is registered dynamically in .onLoad() because lavaan is a
# suggested package.

#' Extract Mediation Structure from lavaan Models
#'
#' @description
#' Extract mediation structure from fitted lavaan models. This method
#' works with structural equation models that include mediation paths.
#'
#' @param object Fitted lavaan object
#' @param treatment Character string: name of the treatment variable (X)
#' @param mediator Character string: name of the mediator variable (M)
#' @param outcome Character string: name of the outcome variable (Y).
#'   If NULL, attempts to auto-detect from model.
#' @param standardized Logical: if TRUE, extract standardized coefficients
#'   (default: FALSE)
#' @param ... Additional arguments (currently ignored)
#'
#' @return A [MediationData] object containing:
#'   \itemize{
#'     \item Path coefficients (a, b, c')
#'     \item Full parameter estimates and variance-covariance matrix
#'     \item Variable names and metadata
#'   }
#'
#' @details
#' ## Model Specification
#'
#' The lavaan model should include the standard mediation paths:
#' \preformatted{
#' model <- "
#'   M ~ a*X        # a path
#'   Y ~ b*M + c*X  # b and c' paths
#' "
#' }
#'
#' The function will search for coefficients matching the treatment and
#' mediator variable names in the appropriate regression equations.
#'
#' ## Path Labels
#'
#' While labels (like `a*X`) are helpful for clarity, they are not required.
#' The function identifies paths by variable names in the model structure.
#'
#' ## Standardized vs Unstandardized
#'
#' By default, unstandardized coefficients are extracted. Set
#' `standardized = TRUE` to extract standardized coefficients instead.
#'
#' ## Note on Residual Variances
#'
#' Unlike lm/glm extraction, lavaan provides residual variances directly
#' from the model. However, these are currently set to NULL in the
#' returned MediationData object for consistency. Future versions may
#' extract these values.
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
#'
#' # With covariates
#' model2 <- "
#'   M ~ X + age + gender
#'   Y ~ M + X + age + gender
#' "
#' fit2 <- sem(model2, data = mydata)
#'
#' med_data2 <- extract_mediation(
#'   fit2,
#'   treatment = "X",
#'   mediator = "M"
#' )
#' }
#'
#' @seealso [MediationData], [fit_mediation()], [bootstrap_mediation()]
#' @export
NULL


#' Internal Implementation for lavaan Extraction
#'
#' @description
#' This function is registered as an S7 method for lavaan objects
#' dynamically in .onLoad().
#'
#' @param object Fitted lavaan object
#' @param treatment Treatment variable name
#' @param mediator Mediator variable name
#' @param outcome Outcome variable name (or NULL to auto-detect)
#' @param standardized Use standardized coefficients?
#' @param ... Additional arguments (ignored)
#'
#' @return MediationData object
#' @keywords internal
#' @noRd
.extract_mediation_lavaan <- function(object,
                                       treatment,
                                       mediator,
                                       outcome = NULL,
                                       standardized = FALSE,
                                       ...) {
  # Validate inputs
  if (missing(treatment) || is.null(treatment)) {
    stop("treatment variable name is required")
  }
  if (missing(mediator) || is.null(mediator)) {
    stop("mediator variable name is required")
  }

  # Get parameter estimates
  if (standardized) {
    param_table <- lavaan::standardizedSolution(object)
  } else {
    param_table <- lavaan::parameterEstimates(object)
  }

  # Filter to regression parameters only
  reg_params <- param_table[param_table$op == "~", ]

  # Find outcome variable if not specified
  if (is.null(outcome)) {
    # Get all dependent variables (lhs of ~)
    dep_vars <- unique(reg_params$lhs)
    # Outcome is the one that has mediator as predictor
    outcome_candidates <- reg_params[reg_params$rhs == mediator, "lhs"]
    if (length(outcome_candidates) == 0) {
      stop("Could not auto-detect outcome variable. Please specify 'outcome' argument.")
    }
    outcome <- outcome_candidates[1]
  }

  # Extract a path: M ~ X (mediator regressed on treatment)
  a_row <- reg_params[reg_params$lhs == mediator & reg_params$rhs == treatment, ]
  if (nrow(a_row) == 0) {
    stop(sprintf("a path not found: %s ~ %s", mediator, treatment))
  }
  a_path <- a_row$est[1]

  # Extract b path: Y ~ M (outcome regressed on mediator)
  b_row <- reg_params[reg_params$lhs == outcome & reg_params$rhs == mediator, ]
  if (nrow(b_row) == 0) {
    stop(sprintf("b path not found: %s ~ %s", outcome, mediator))
  }
  b_path <- b_row$est[1]

  # Extract c' path: Y ~ X (direct effect)
  cp_row <- reg_params[reg_params$lhs == outcome & reg_params$rhs == treatment, ]
  if (nrow(cp_row) == 0) {
    # c' might be zero (full mediation) or not included
    c_prime <- 0
    warning("c' path (direct effect) not found in model. Setting to 0.")
  } else {
    c_prime <- cp_row$est[1]
  }

  # Build estimates vector
  # Use full parameter estimates from lavaan
  all_params <- lavaan::coef(object)
  estimates <- all_params

  # Get variance-covariance matrix
  vcov_matrix <- lavaan::vcov(object)

  # Get predictor names
  mediator_predictors <- reg_params[reg_params$lhs == mediator, "rhs"]
  outcome_predictors <- reg_params[reg_params$lhs == outcome, "rhs"]

  # Get sample size
  n_obs <- lavaan::nobs(object)

  # Check convergence
  converged <- lavaan::lavInspect(object, "converged")

  # Get data if available
  data <- tryCatch(
    lavaan::lavInspect(object, "data"),
    error = function(e) NULL
  )

  # Convert to data frame if matrix
  if (!is.null(data) && is.matrix(data)) {
    data <- as.data.frame(data)
  }

  # Create MediationData object
  MediationData(
    a_path = unname(a_path),
    b_path = unname(b_path),
    c_prime = unname(c_prime),
    estimates = estimates,
    vcov = vcov_matrix,
    sigma_m = NULL,  # lavaan models don't provide sigma in same way
    sigma_y = NULL,
    treatment = treatment,
    mediator = mediator,
    outcome = outcome,
    mediator_predictors = mediator_predictors,
    outcome_predictors = outcome_predictors,
    data = data,
    n_obs = as.integer(n_obs),
    converged = converged,
    source_package = "lavaan"
  )
}
