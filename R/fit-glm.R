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
#' # Generate example data
#' set.seed(123)
#' n <- 100
#' mydata <- data.frame(
#'   X = rnorm(n),
#'   C = rnorm(n)
#' )
#' mydata$M <- 0.5 * mydata$X + 0.2 * mydata$C + rnorm(n)
#' mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + 0.1 * mydata$C + rnorm(n)
#'
#' # Simple mediation with continuous variables
#' med_data <- fit_mediation(
#'   formula_y = Y ~ X + M,
#'   formula_m = M ~ X,
#'   data = mydata,
#'   treatment = "X",
#'   mediator = "M"
#' )
#' print(med_data)
#'
#' # With covariates
#' med_data_cov <- fit_mediation(
#'   formula_y = Y ~ X + M + C,
#'   formula_m = M ~ X + C,
#'   data = mydata,
#'   treatment = "X",
#'   mediator = "M"
#' )
#'
#' \donttest{
#' # Binary outcome (takes longer to fit)
#' mydata$Y_bin <- rbinom(n, 1, plogis(0.3 * mydata$X + 0.4 * mydata$M))
#' med_data_bin <- fit_mediation(
#'   formula_y = Y_bin ~ X + M,
#'   formula_m = M ~ X,
#'   data = mydata,
#'   treatment = "X",
#'   mediator = "M",
#'   family_y = binomial()
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
  # --- Input Validation (using checkmate for fail-fast defensive programming) ---
  checkmate::assert_formula(formula_y, .var.name = "formula_y")
  checkmate::assert_formula(formula_m, .var.name = "formula_m")
  checkmate::assert_data_frame(data, min.rows = 1, .var.name = "data")
  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_string(mediator, .var.name = "mediator")
  checkmate::assert_choice(engine, choices = c("glm"), .var.name = "engine")

  # Validate that treatment and mediator exist in data
  checkmate::assert_choice(treatment, choices = names(data),
                           .var.name = "treatment (must be in data)")
  checkmate::assert_choice(mediator, choices = names(data),
                           .var.name = "mediator (must be in data)")

  # Validate formulas contain required variables
  vars_y <- all.vars(formula_y)
  vars_m <- all.vars(formula_m)

  if (!(treatment %in% vars_y)) {
    stop(sprintf("Treatment variable '%s' must be in formula_y", treatment),
         call. = FALSE)
  }
  if (!(treatment %in% vars_m)) {
    stop(sprintf("Treatment variable '%s' must be in formula_m", treatment),
         call. = FALSE)
  }
  if (!(mediator %in% vars_y)) {
    stop(sprintf("Mediator variable '%s' must be in formula_y", mediator),
         call. = FALSE)
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
    stop(sprintf("Engine '%s' not implemented", engine), call. = FALSE)
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
