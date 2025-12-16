# Test Data Generators for medfit
#
# This file provides helper functions for generating test data
# used across multiple test files.

#' Generate Simple Mediation Data
#'
#' Creates a data frame with X -> M -> Y mediation structure.
#'
#' @param n Sample size
#' @param a True a path coefficient (X -> M)
#' @param b True b path coefficient (M -> Y)
#' @param cp True c' path coefficient (X -> Y direct)
#' @param sigma_m Residual SD for M
#' @param sigma_y Residual SD for Y
#' @param seed Random seed
#'
#' @return Data frame with columns X, M, Y
generate_mediation_data <- function(n = 100,
                                     a = 0.5,
                                     b = 0.4,
                                     cp = 0.3,
                                     sigma_m = 1,
                                     sigma_y = 1,
                                     seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X <- rnorm(n)
  M <- a * X + rnorm(n, sd = sigma_m)
  Y <- cp * X + b * M + rnorm(n, sd = sigma_y)

  data.frame(X = X, M = M, Y = Y)
}


#' Generate Mediation Data with Covariates
#'
#' Creates a data frame with X -> M -> Y and covariates.
#'
#' @param n Sample size
#' @param a True a path coefficient
#' @param b True b path coefficient
#' @param cp True c' path coefficient
#' @param n_covariates Number of covariates to include
#' @param seed Random seed
#'
#' @return Data frame with columns X, M, Y, C1, C2, ...
generate_mediation_data_with_covariates <- function(n = 100,
                                                     a = 0.5,
                                                     b = 0.4,
                                                     cp = 0.3,
                                                     n_covariates = 2,
                                                     seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X <- rnorm(n)

  # Generate covariates
  covariates <- matrix(rnorm(n * n_covariates), nrow = n)
  colnames(covariates) <- paste0("C", seq_len(n_covariates))

  # Generate M with covariate effects
  coef_m <- runif(n_covariates, 0.1, 0.3)
  M <- a * X + covariates %*% coef_m + rnorm(n)

  # Generate Y with covariate effects
  coef_y <- runif(n_covariates, 0.1, 0.3)
  Y <- cp * X + b * M + covariates %*% coef_y + rnorm(n)

  data.frame(X = X, M = as.vector(M), Y = as.vector(Y), as.data.frame(covariates))
}


#' Generate Binary Outcome Mediation Data
#'
#' Creates mediation data where Y is binary.
#'
#' @param n Sample size
#' @param a True a path coefficient
#' @param b True b path coefficient (on log-odds scale)
#' @param cp True c' path coefficient (on log-odds scale)
#' @param seed Random seed
#'
#' @return Data frame with columns X, M, Y (binary)
generate_binary_outcome_data <- function(n = 200,
                                          a = 0.5,
                                          b = 0.4,
                                          cp = 0.3,
                                          seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X <- rnorm(n)
  M <- a * X + rnorm(n)

  # Generate binary Y
  prob_Y <- stats::plogis(cp * X + b * M)
  Y <- stats::rbinom(n, 1, prob_Y)

  data.frame(X = X, M = M, Y = Y)
}


#' Generate Serial Mediation Data
#'
#' Creates a data frame with X -> M1 -> M2 -> Y serial mediation.
#'
#' @param n Sample size
#' @param a True a path (X -> M1)
#' @param d True d path (M1 -> M2)
#' @param b True b path (M2 -> Y)
#' @param cp True c' path (X -> Y direct)
#' @param seed Random seed
#'
#' @return Data frame with columns X, M1, M2, Y
generate_serial_mediation_data <- function(n = 100,
                                            a = 0.5,
                                            d = 0.4,
                                            b = 0.3,
                                            cp = 0.2,
                                            seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X <- rnorm(n)
  M1 <- a * X + rnorm(n)
  M2 <- d * M1 + 0.2 * X + rnorm(n)  # M2 also affected by X

  Y <- cp * X + b * M2 + 0.1 * M1 + rnorm(n)  # Y affected by both mediators

  data.frame(X = X, M1 = M1, M2 = M2, Y = Y)
}


#' Fit Standard Mediation Models
#'
#' Convenience function to fit mediator and outcome models.
#'
#' @param data Data frame with X, M, Y columns
#' @param treatment Name of treatment variable (default "X")
#' @param mediator Name of mediator variable (default "M")
#' @param outcome Name of outcome variable (default "Y")
#' @param covariates Character vector of covariate names (optional)
#'
#' @return List with fit_m and fit_y model objects
fit_standard_models <- function(data,
                                 treatment = "X",
                                 mediator = "M",
                                 outcome = "Y",
                                 covariates = NULL) {
  # Build formulas
  if (is.null(covariates)) {
    formula_m <- stats::as.formula(paste(mediator, "~", treatment))
    formula_y <- stats::as.formula(paste(outcome, "~", treatment, "+", mediator))
  } else {
    cov_str <- paste(covariates, collapse = " + ")
    formula_m <- stats::as.formula(paste(mediator, "~", treatment, "+", cov_str))
    formula_y <- stats::as.formula(paste(outcome, "~", treatment, "+", mediator, "+", cov_str))
  }

  list(
    fit_m = stats::lm(formula_m, data = data),
    fit_y = stats::lm(formula_y, data = data)
  )
}


#' Create a Simple MediationData Object for Testing
#'
#' Creates a valid MediationData object with default values.
#'
#' @param a_path a path coefficient
#' @param b_path b path coefficient
#' @param c_prime c' path coefficient
#'
#' @return MediationData object
create_test_mediation_data <- function(a_path = 0.5,
                                        b_path = 0.4,
                                        c_prime = 0.3) {
  # Create minimal valid MediationData
  estimates <- c(
    m_intercept = 0, m_X = a_path,
    y_intercept = 0, y_X = c_prime, y_M = b_path
  )

  vcov_mat <- diag(0.01, length(estimates))
  rownames(vcov_mat) <- names(estimates)
  colnames(vcov_mat) <- names(estimates)

  MediationData(
    a_path = a_path,
    b_path = b_path,
    c_prime = c_prime,
    estimates = estimates,
    vcov = vcov_mat,
    sigma_m = 1.0,
    sigma_y = 1.0,
    treatment = "X",
    mediator = "M",
    outcome = "Y",
    mediator_predictors = "X",
    outcome_predictors = c("X", "M"),
    data = NULL,
    n_obs = 100L,
    converged = TRUE,
    source_package = "test"
  )
}
