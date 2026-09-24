# S7 Generic Functions for medfit
#
# This file defines the core S7 generics:
# - extract_mediation(): Extract mediation structure from fitted models

#' Extract Mediation Structure from Fitted Models
#'
#' @description
#' Generic function to extract mediation structure (a, b, c' paths and
#' variance-covariance matrices) from fitted models. This function provides
#' a unified interface for extracting mediation information from various
#' model types (lm, glm, lavaan, lmer, brms, etc.).
#'
#' @param object Fitted model object (lm, glm, lavaan, etc.)
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
#' - **lmerMod**: Extract from mixed-effects models (future)
#' - **brmsfit**: Extract from Bayesian models (future)
#'
#' Note: OpenMx extraction is planned for a future release.
#'
#' All methods return a standardized [MediationData] object that can be used
#' with other medfit functions and dependent packages (probmed, RMediation,
#' medrobust).
#'
#' The class returned depends on the structure. A single mediator gives a
#' [MediationData] object, or an [InteractionMediationData] object when the
#' outcome model has a treatment-by-mediator term. A `mediator` vector of
#' length two or more gives a [SerialMediationData] or [ParallelMediationData]
#' object; for lm/glm fits whose outcome model has a treatment-by-mediator term
#' written with `:` or `*`, it gives a [JointMediationData] object with the
#' joint natural effects of the mediators. Any other product term in a
#' multi-mediator fit errors.
#'
#' @examples
#' \donttest{
#' # Extract the mediation structure from fitted lm models, using the
#' # simulated mediation_demo data bundled with medfit
#' fit_m <- lm(mediator1 ~ treatment + covariate1 + covariate2,
#'             data = mediation_demo)
#' fit_y <- lm(outcome ~ treatment + mediator1 + covariate1 + covariate2,
#'             data = mediation_demo)
#' med_data <- extract_mediation(fit_m, model_y = fit_y,
#'                               treatment = "treatment", mediator = "mediator1")
#' }
#'
#' @seealso [MediationData], [fit_mediation()], [bootstrap_mediation()]
#' @export
extract_mediation <- S7::new_generic(
  "extract_mediation",
  dispatch_args = "object"
)
