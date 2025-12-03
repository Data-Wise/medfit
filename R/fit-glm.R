# GLM Engine Implementation for fit_mediation()
#
# This file implements the GLM (generalized linear model) engine for fitting
# mediation models. The GLM engine supports:
# - Gaussian (continuous) mediators and outcomes
# - Binary mediators and outcomes via binomial family
# - Other GLM families (Poisson, etc.)
#
# Pattern: fit_mediation() dispatches to .fit_mediation_glm(), which:
# 1. Validates inputs
# 2. Fits mediator model with stats::glm()
# 3. Fits outcome model with stats::glm()
# 4. Calls extract_mediation() to return MediationData

#' Fit Mediation Models with GLM Engine
#'
#' Internal function that implements the GLM engine for fit_mediation().
#' Fits both mediator and outcome models using generalized linear models.
#'
#' @param formula_y Formula for outcome model (e.g., `Y ~ X + M + C`)
#' @param formula_m Formula for mediator model (e.g., `M ~ X + C`)
#' @param data Data frame containing all variables
#' @param treatment Character string: name of treatment variable
#' @param mediator Character string: name of mediator variable
#' @param family_y Family object for outcome model (default: gaussian())
#' @param family_m Family object for mediator model (default: gaussian())
#' @param ... Additional arguments passed to stats::glm()
#'
#' @return A [MediationData] object
#'
#' @details
#' This function:
#' 1. Validates that treatment and mediator appear in the correct formulas
#' 2. Fits the mediator model: `M ~ X + covariates`
#' 3. Fits the outcome model: `Y ~ X + M + covariates`
#' 4. Extracts mediation structure using `extract_mediation()`
#'
#' ## Formula Requirements
#'
#' - `formula_m` (mediator model): Must include treatment (X) as predictor
#' - `formula_y` (outcome model): Must include both treatment (X) and mediator (M)
#'
#' ## Supported Families
#'
#' - `gaussian()`: For continuous variables (default)
#' - `binomial()`: For binary variables
#' - Other GLM families are supported but may have limited interpretation
#'
#' @keywords internal
.fit_mediation_glm <- function(formula_y,
                                formula_m,
                                data,
                                treatment,
                                mediator,
                                family_y = stats::gaussian(),
                                family_m = stats::gaussian(),
                                ...) {

  # --- Input Validation ---

  # Validate formulas
  checkmate::assert_formula(formula_y, .var.name = "formula_y")
  checkmate::assert_formula(formula_m, .var.name = "formula_m")

  # Validate data
  checkmate::assert_data_frame(data, min.rows = 1, .var.name = "data")

  # Validate treatment and mediator names
  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_string(mediator, .var.name = "mediator")

  # Check treatment exists in data
  if (!treatment %in% names(data)) {
    stop("Treatment variable '", treatment, "' not found in data",
         call. = FALSE)
  }

  # Check mediator exists in data
  if (!mediator %in% names(data)) {
    stop("Mediator variable '", mediator, "' not found in data",
         call. = FALSE)
  }

  # --- Validate Formula Structure ---

  # Get variables from formulas
  vars_m <- all.vars(formula_m)
  vars_y <- all.vars(formula_y)

  # The mediator should be the response in formula_m
  mediator_response <- .get_response_var_from_formula(formula_m)
  if (mediator_response != mediator) {
    stop("Mediator model response '", mediator_response,
         "' does not match specified mediator '", mediator, "'",
         call. = FALSE)
  }

  # Treatment should appear in mediator model (as predictor)
  predictors_m <- vars_m[-1]  # Exclude response
  if (!treatment %in% predictors_m) {
    stop("Treatment '", treatment, "' must appear as predictor in formula_m",
         call. = FALSE)
  }

  # Both treatment and mediator should appear in outcome model (as predictors)
  predictors_y <- vars_y[-1]  # Exclude response
  if (!treatment %in% predictors_y) {
    stop("Treatment '", treatment, "' must appear as predictor in formula_y",
         call. = FALSE)
  }
  if (!mediator %in% predictors_y) {
    stop("Mediator '", mediator, "' must appear as predictor in formula_y",
         call. = FALSE)
  }

  # --- Check for Complete Cases ---

  # Get all variables needed for both models
  all_vars <- unique(c(vars_m, vars_y))

  # Check that all variables exist in data
  missing_vars <- setdiff(all_vars, names(data))
  if (length(missing_vars) > 0) {
    stop("Variables not found in data: ",
         paste(missing_vars, collapse = ", "),
         call. = FALSE)
  }

  # --- Fit Models ---

  # Fit mediator model
  fit_m <- tryCatch(
    stats::glm(formula_m, data = data, family = family_m, ...),
    error = function(e) {
      stop("Error fitting mediator model: ", e$message, call. = FALSE)
    }
  )

  # Fit outcome model
  fit_y <- tryCatch(
    stats::glm(formula_y, data = data, family = family_y, ...),
    error = function(e) {
      stop("Error fitting outcome model: ", e$message, call. = FALSE)
    }
  )

  # --- Check Convergence ---

  if (!fit_m$converged) {
    warning("Mediator model did not converge", call. = FALSE)
  }
  if (!fit_y$converged) {
    warning("Outcome model did not converge", call. = FALSE)
  }

  # --- Extract Mediation Structure ---

  # Use extract_mediation() to create standardized MediationData
  med_data <- extract_mediation(
    object = fit_m,
    model_y = fit_y,
    treatment = treatment,
    mediator = mediator,
    data = data
  )

  # Update source_package to reflect fitting method
  # Note: We access and modify the property directly
  med_data@source_package <- "medfit::fit_mediation(engine='glm')"

  return(med_data)
}


#' Get Response Variable Name from Formula
#'
#' Extracts the response variable name from a formula object.
#'
#' @param formula A formula object
#' @return Character string: response variable name
#' @keywords internal
.get_response_var_from_formula <- function(formula) {
  all.vars(formula)[1]
}


#' Validate Family Object
#'
#' Checks if a family object is valid for GLM fitting.
#'
#' @param family A family object or function
#' @param name Name of the parameter for error messages
#' @return A validated family object
#' @keywords internal
.validate_family <- function(family, name = "family") {
  # If it's a function, call it to get family object
  if (is.function(family)) {
    family <- family()
  }


  # Check it's a valid family object
  if (!inherits(family, "family")) {
    stop(name, " must be a family object (e.g., gaussian(), binomial())",
         call. = FALSE)
  }

  return(family)
}
