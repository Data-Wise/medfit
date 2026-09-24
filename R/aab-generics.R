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
#' @return An S7 object whose class depends on the mediation structure (see
#'   Details): [MediationData], [InteractionMediationData],
#'   [SerialMediationData], [ParallelMediationData], or [JointMediationData].
#'   Each carries the path coefficients, the full parameter vector and its
#'   variance-covariance matrix, residual standard deviations (for Gaussian
#'   models), variable names, and the original data when available.
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
#' The returned objects share one interface ([nie()], [nde()], [te()],
#' [confint()], [bootstrap_mediation()], ...) for use by other medfit functions
#' and dependent packages (probmed, RMediation, medrobust).
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
#' ## Arguments for lm and glm models
#'
#' With `object` the fitted mediator model (the first mediator's model for
#' several mediators), the lm/glm method takes:
#'
#' - `model_y`: the fitted outcome model. With several mediators include every
#'   mediator, not only the last: omitting one that also affects the outcome
#'   biases the others' coefficients.
#' - `treatment`: name of the treatment variable.
#' - `mediator`: name of the mediator, or an ordered character vector of two or
#'   more mediator names.
#' - `mediator_models`: list of the fitted models for mediators 2 to k, in
#'   order; required whenever `mediator` has length two or more.
#' - `structure`: `"auto"` (default), `"serial"`, or `"parallel"`; `"auto"`
#'   classifies the mediators from the mediator models.
#' - `decomposition`: `"auto"` (default) uses the four-way decomposition when
#'   a single mediator's outcome model has a treatment-by-mediator term;
#'   `"four_way"` requires that term; `"two_way"` ignores it and returns a
#'   [MediationData] object.
#' - `m_star`: the reference mediator level for the controlled direct effect
#'   (default 0; for [JointMediationData] a scalar or a vector named by the
#'   interacting mediators).
#' - `vcov_fun`: function returning each model's covariance matrix (default
#'   [stats::vcov()]; for example `sandwich::vcovHC`). Not supported for
#'   [JointMediationData].
#' - `outcome`, `data`: optional; detected from the models when omitted.
#'
#' The lavaan method takes a fitted lavaan model and the variable names; see
#' `?extract_mediation_lavaan` for its arguments.
#'
#' ## Covariance of the estimates
#'
#' For lm/glm fits, each equation's block of `@vcov` is that model's own
#' covariance. The blocks for different equations are stored as zero. This is
#' exact for simple mediation, serial chains, and the four-way model, whose
#' later equations contain every regressor of the earlier ones, but for
#' parallel mediators it leaves out the covariance between their `a` paths.
#' [JointMediationData] stores the full stacked least-squares covariance, and a
#' lavaan fit estimates all equations jointly, so for the same data the
#' intervals can differ between engines.
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
