#' medfit: Infrastructure for Mediation Model Fitting and Extraction
#'
#' @description
#' Provides S7-based infrastructure for fitting mediation models,
#' extracting path coefficients, and performing bootstrap inference.
#' Designed as a foundation package for probmed, RMediation, and medrobust.
#'
#' @details
#' Key functions:
#' \itemize{
#'   \item \code{\link{fit_mediation}}: Fit mediation models
#'   \item \code{\link{extract_mediation}}: Extract from fitted models
#'   \item \code{\link{bootstrap_mediation}}: Bootstrap inference
#'   \item \code{\link{nie}}, \code{\link{nde}}, \code{\link{te}},
#'     \code{\link{pm}}, \code{\link{decompose}}: Effects
#'   \item \code{\link{joint_effects}}: Joint effects at a parameter vector
#' }
#'
#' Key classes:
#' \itemize{
#'   \item \code{\link{MediationData}}: Simple mediation
#'   \item \code{\link{InteractionMediationData}}: Simple mediation with a
#'     treatment-by-mediator interaction (four-way decomposition)
#'   \item \code{\link{SerialMediationData}}: Serial chain of mediators
#'   \item \code{\link{ParallelMediationData}}: Parallel mediators
#'   \item \code{\link{JointMediationData}}: Joint natural effects of several
#'     mediators with treatment-by-mediator products
#'   \item \code{\link{BootstrapResult}}: Bootstrap results
#' }
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
