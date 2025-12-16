# S7 Generic Functions for medfit
#
# This file defines the core S7 generics:
# - extract_mediation(): Extract mediation structure from fitted models
# - fit_mediation(): Fit mediation models
# - bootstrap_mediation(): Perform bootstrap inference

#' Extract Mediation Structure from Fitted Models
#'
#' @description
#' Generic function to extract mediation structure (a, b, c' paths and
#' variance-covariance matrices) from fitted models. This function provides
#' a unified interface for extracting mediation information from various
#' model types (lm, glm, lavaan, OpenMx, lmer, brms, etc.).
#'
#' @param object Fitted model object (lm, glm, lavaan, OpenMx, etc.)
#' @param ... Additional arguments passed to methods. Common arguments include:
#'   - `treatment`: Character string specifying treatment variable name
#'   - `mediator`: Character string specifying mediator variable name
#'   - Method-specific arguments (see individual method documentation)
#'
#' @return A [MediationData] object containing:
#'   - Path coefficients (a, b, c')
#'   - Full parameter vector and variance-covariance matrix
#'   - Residual variances (for Gaussian models)
#'   - Variable names and metadata
#'   - Original data (if available)
#'
#' @details
#' The `extract_mediation()` generic provides methods for different model types:
#'
#' - **lm/glm**: Extract from linear and generalized linear models
#' - **lavaan**: Extract from structural equation models
#' - **OpenMx**: Extract from OpenMx models
#' - **lmerMod**: Extract from mixed-effects models (future)
#' - **brmsfit**: Extract from Bayesian models (future)
#'
#' All methods return a standardized [MediationData] object that can be used
#' with other medfit functions and dependent packages (probmed, RMediation,
#' medrobust).
#'
#' @examples
#' \dontrun{
#' # Extract from lm models
#' fit_m <- lm(M ~ X + C, data = mydata)
#' fit_y <- lm(Y ~ X + M + C, data = mydata)
#' med_data <- extract_mediation(fit_m, model_y = fit_y,
#'                               treatment = "X", mediator = "M")
#'
#' # Extract from lavaan model
#' library(lavaan)
#' model <- "
#'   M ~ a*X
#'   Y ~ b*M + cp*X
#' "
#' fit <- sem(model, data = mydata)
#' med_data <- extract_mediation(fit, treatment = "X", mediator = "M")
#' }
#'
#' @seealso [MediationData], [fit_mediation()], [bootstrap_mediation()]
#' @export
extract_mediation <- S7::new_generic(
  "extract_mediation",
  dispatch_args = "object"
)


# Note: fit_mediation() is implemented in R/fit-glm.R
# Note: bootstrap_mediation() is implemented in R/bootstrap.R
