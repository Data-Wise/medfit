# Fit Mediation Models Using GLM Engine
#
# This file implements the fit_mediation() function for fitting mediation
# models using generalized linear models (GLM).

#' Fit Mediation Models
#'
#' @description
#' Fit mediation models using a specified modeling engine. This function
#' provides a convenient formula-based interface for fitting both the
#' mediator and outcome models simultaneously.
#'
#' @param formula_y Formula for outcome model (e.g., `Y ~ X + M + C`)
#' @param formula_m Formula for mediator model (e.g., `M ~ X + C`)
#' @param data Data frame containing all variables
#' @param treatment Character string: name of treatment variable
#' @param mediator Character string: name of mediator variable
#' @param engine Character string: modeling engine to use. Currently supports:
#'   \itemize{
#'     \item `"glm"`: Generalized linear models (default)
#'   }
#' @param family_y Family object for outcome model (default: `gaussian()`)
#' @param family_m Family object for mediator model (default: `gaussian()`)
#' @param ... Additional arguments passed to the fitting function
#'
#' @return A [MediationData] object containing the fitted mediation structure
#'
#' @details
#' ## Model Specification
#'
#' The function fits two models:
#' \enumerate{
#'   \item **Mediator model**: `formula_m` (e.g., `M ~ X + C1 + C2`)
#'   \item **Outcome model**: `formula_y` (e.g., `Y ~ X + M + C1 + C2`)
#' }
#'
#' The treatment variable must appear in both formulas. The mediator variable
#' must appear in the outcome formula but NOT in the mediator formula (as it
#' is the response).
#'
#' ## GLM Engine
#'
#' When `engine = "glm"` (default):
#' \itemize{
#'   \item Models are fit using [stats::glm()]
#'   \item Supports all GLM families (gaussian, binomial, poisson, etc.)
#'   \item For Gaussian models, residual standard deviations are extracted
#'   \item Non-Gaussian outcomes have `sigma_y = NULL`
#' }
#'
#' ## Common Family Specifications
#'
#' \itemize{
#'   \item `gaussian()`: Continuous outcomes (default)
#'   \item `binomial()`: Binary outcomes
#'   \item `poisson()`: Count outcomes
#'   \item `Gamma()`: Positive continuous outcomes
#' }
#'
#' @examples
#' \dontrun{
#' # Simple mediation with continuous variables
#' med_data <- fit_mediation(
#'   formula_y = Y ~ X + M,
#'   formula_m = M ~ X,
#'   data = mydata,
#'   treatment = "X",
#'   mediator = "M"
#' )
#'
#' # With covariates
#' med_data <- fit_mediation(
#'   formula_y = Y ~ X + M + age + gender,
#'   formula_m = M ~ X + age + gender,
#'   data = mydata,
#'   treatment = "X",
#'   mediator = "M"
#' )
#'
#' # Binary outcome
#' med_data <- fit_mediation(
#'   formula_y = Y ~ X + M,
#'   formula_m = M ~ X,
#'   data = mydata,
#'   treatment = "X",
#'   mediator = "M",
#'   family_y = binomial()
#' )
#'
#' # Both mediator and outcome are binary
#' med_data <- fit_mediation(
#'   formula_y = Y ~ X + M,
#'   formula_m = M ~ X,
#'   data = mydata,
#'   treatment = "X",
#'   mediator = "M",
#'   family_y = binomial(),
#'   family_m = binomial()
#' )
#' }
#'
#' @seealso [MediationData], [extract_mediation()], [bootstrap_mediation()]
#' @export
fit_mediation <- function(formula_y,
                          formula_m,
                          data,
                          treatment,
                          mediator,
                          engine = "glm",
                          family_y = stats::gaussian(),
                          family_m = stats::gaussian(),
                          ...) {
  # Validate engine
engine <- match.arg(engine, choices = c("glm"))

  # Validate required arguments
  if (missing(formula_y)) {
    stop("formula_y is required")
  }
  if (missing(formula_m)) {
    stop("formula_m is required")
  }
  if (missing(data)) {
    stop("data is required")
  }
  if (missing(treatment)) {
    stop("treatment variable name is required")
  }
  if (missing(mediator)) {
    stop("mediator variable name is required")
  }

  # Validate that treatment and mediator exist in data
  if (!(treatment %in% names(data))) {
    stop(sprintf("Treatment variable '%s' not found in data", treatment))
  }
  if (!(mediator %in% names(data))) {
    stop(sprintf("Mediator variable '%s' not found in data", mediator))
  }

  # Validate formulas contain required variables
  vars_y <- all.vars(formula_y)
  vars_m <- all.vars(formula_m)

  if (!(treatment %in% vars_y)) {
    stop(sprintf("Treatment variable '%s' must be in formula_y", treatment))
  }
  if (!(treatment %in% vars_m)) {
    stop(sprintf("Treatment variable '%s' must be in formula_m", treatment))
  }
  if (!(mediator %in% vars_y)) {
    stop(sprintf("Mediator variable '%s' must be in formula_y", mediator))
  }

  # Dispatch to engine-specific function
  switch(engine,
    glm = .fit_mediation_glm(
      formula_y = formula_y,
      formula_m = formula_m,
      data = data,
      treatment = treatment,
      mediator = mediator,
      family_y = family_y,
      family_m = family_m,
      ...
    ),
    stop(sprintf("Engine '%s' not implemented", engine))
  )
}


#' GLM Engine for Mediation Fitting
#'
#' @param formula_y Outcome model formula
#' @param formula_m Mediator model formula
#' @param data Data frame
#' @param treatment Treatment variable name
#' @param mediator Mediator variable name
#' @param family_y Family for outcome model
#' @param family_m Family for mediator model
#' @param ... Additional arguments (passed to glm)
#'
#' @return MediationData object
#' @keywords internal
#' @noRd
.fit_mediation_glm <- function(formula_y,
                                formula_m,
                                data,
                                treatment,
                                mediator,
                                family_y,
                                family_m,
                                ...) {
  # Fit mediator model
  fit_m <- stats::glm(
    formula = formula_m,
    data = data,
    family = family_m,
    ...
  )

  # Fit outcome model
  fit_y <- stats::glm(
    formula = formula_y,
    data = data,
    family = family_y,
    ...
  )

  # Extract mediation structure using extract_mediation
  extract_mediation(
    object = fit_m,
    model_y = fit_y,
    treatment = treatment,
    mediator = mediator,
    data = data
  )
}
