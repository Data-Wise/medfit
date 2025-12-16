#' medfit: Infrastructure for Mediation Model Fitting and Extraction
#'
#' @description
#' Provides S7-based infrastructure for fitting mediation models,
#' extracting path coefficients, and performing bootstrap inference.
#' Designed as a foundation package for probmed, RMediation, and medrobust.
#'
#' @details
#' The medfit package provides a unified infrastructure for mediation analysis
#' in R. It supports:
#'
#' \itemize{
#'   \item Simple mediation (X -> M -> Y)
#'   \item Serial mediation (X -> M1 -> M2 -> ... -> Y)
#'   \item Multiple model types (lm, glm, lavaan)
#'   \item Three bootstrap methods (parametric, nonparametric, plugin)
#' }
#'
#' @section Main Functions:
#' \describe{
#'   \item{\code{\link{fit_mediation}}}{Fit mediation models using formula interface}
#'   \item{\code{\link{extract_mediation}}}{Extract mediation structure from fitted models}
#'   \item{\code{\link{bootstrap_mediation}}}{Perform bootstrap inference for mediation statistics}
#' }
#'
#' @section S7 Classes:
#' \describe{
#'   \item{\code{\link{MediationData}}}{Container for simple mediation (X -> M -> Y)}
#'   \item{\code{\link{SerialMediationData}}}{Container for serial mediation (X -> M1 -> M2 -> ... -> Y)}
#'   \item{\code{\link{BootstrapResult}}}{Container for bootstrap inference results}
#' }
#'
#' @section Package Ecosystem:
#' medfit serves as the foundation for three specialized mediation packages:
#' \itemize{
#'   \item \strong{probmed}: Probabilistic effect size (P_med)
#'   \item \strong{RMediation}: Confidence intervals via Distribution of Product
#'   \item \strong{medrobust}: Sensitivity analysis for unmeasured confounding
#' }
#'
#' @seealso
#' Useful links:
#' \itemize{
#'   \item \url{https://data-wise.github.io/medfit/}
#'   \item \url{https://github.com/data-wise/medfit}
#' }
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
