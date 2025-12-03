# Test Helper Functions for medfit
#
# This file contains:
# - Test data generators
# - Common test utilities
# - Helper functions for creating test objects
#
# Note: Files starting with "helper-" are automatically sourced by testthat

# ==============================================================================
# Data Generators
# ==============================================================================

#' Generate Simple Mediation Data
#'
#' Creates a data frame with X -> M -> Y mediation structure
#' where true effects are known.
#'
#' @param n Sample size
#' @param a True a path (X -> M)
#' @param b True b path (M -> Y)
#' @param c_prime True c' path (X -> Y direct)
#' @param sigma_m Residual SD for M model
#' @param sigma_y Residual SD for Y model
#' @param seed Random seed
#'
#' @return Data frame with columns X, M, Y
#' @examples
#' data <- generate_simple_mediation_data()
generate_simple_mediation_data <- function(n = 200,
                                            a = 0.5,
                                            b = 0.3,
                                            c_prime = 0.2,
                                            sigma_m = 1,
                                            sigma_y = 1,
                                            seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M <- a * X + rnorm(n, sd = sigma_m)
  Y <- b * M + c_prime * X + rnorm(n, sd = sigma_y)
  data.frame(X = X, M = M, Y = Y)
}


#' Generate Mediation Data with Covariates
#'
#' Creates mediation data with additional covariates Z1 and Z2.
#'
#' @param n Sample size
#' @param seed Random seed
#'
#' @return Data frame with columns X, M, Y, Z1, Z2
generate_covariate_mediation_data <- function(n = 200, seed = 123) {
  set.seed(seed)
  Z1 <- rnorm(n)
  Z2 <- rnorm(n)
  X <- rnorm(n)
  M <- 0.5 * X + 0.3 * Z1 + rnorm(n)
  Y <- 0.3 * M + 0.2 * X + 0.15 * Z1 + 0.1 * Z2 + rnorm(n)
  data.frame(X = X, M = M, Y = Y, Z1 = Z1, Z2 = Z2)
}


#' Generate Binary Outcome Mediation Data
#'
#' Creates mediation data with binary outcome (for logistic regression).
#'
#' @param n Sample size
#' @param seed Random seed
#'
#' @return Data frame with columns X, M, Y (binary)
generate_binary_outcome_data <- function(n = 300, seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  logit_p <- 0.5 * M + 0.3 * X
  Y <- rbinom(n, 1, plogis(logit_p))
  data.frame(X = X, M = M, Y = Y)
}


#' Generate Binary Mediator Data
#'
#' Creates mediation data with binary mediator.
#'
#' @param n Sample size
#' @param seed Random seed
#'
#' @return Data frame with columns X, M (binary), Y
generate_binary_mediator_data <- function(n = 300, seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  logit_m <- 0.5 * X
  M <- rbinom(n, 1, plogis(logit_m))
  Y <- 0.4 * M + 0.2 * X + rnorm(n)
  data.frame(X = X, M = M, Y = Y)
}


#' Generate Serial Mediation Data
#'
#' Creates data for serial mediation: X -> M1 -> M2 -> Y
#'
#' @param n Sample size
#' @param seed Random seed
#'
#' @return Data frame with columns X, M1, M2, Y
generate_serial_mediation_data <- function(n = 200, seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M1 <- 0.5 * X + rnorm(n)
  M2 <- 0.4 * M1 + 0.1 * X + rnorm(n)
  Y <- 0.3 * M2 + 0.15 * M1 + 0.1 * X + rnorm(n)
  data.frame(X = X, M1 = M1, M2 = M2, Y = Y)
}


# ==============================================================================
# Test Object Creators
# ==============================================================================

#' Create a Test MediationData Object
#'
#' Fits models and extracts mediation data for testing.
#'
#' @param n Sample size
#' @param seed Random seed
#'
#' @return MediationData object
create_test_mediation_data <- function(n = 200, seed = 123) {
  data <- generate_simple_mediation_data(n = n, seed = seed)

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )
}


#' Create a Fitted MediationData Object
#'
#' Uses fit_mediation() to create MediationData for testing.
#'
#' @param n Sample size
#' @param seed Random seed
#'
#' @return MediationData object
create_fitted_mediation_data <- function(n = 200, seed = 123) {
  data <- generate_simple_mediation_data(n = n, seed = seed)

  fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )
}


# ==============================================================================
# Common Statistic Functions
# ==============================================================================

#' Indirect Effect (Product of Coefficients)
#'
#' Computes a * b from named parameter vector.
#'
#' @param theta Named numeric vector with "a" and "b" elements
#' @return Scalar: a * b
indirect_effect_fn <- function(theta) {
  theta["a"] * theta["b"]
}


#' Total Effect (c = c' + a*b)
#'
#' Computes total effect from named parameter vector.
#'
#' @param theta Named numeric vector with "a", "b", "c_prime" elements
#' @return Scalar: c' + a*b
total_effect_fn <- function(theta) {
  theta["c_prime"] + theta["a"] * theta["b"]
}


#' Proportion Mediated
#'
#' Computes (a*b) / (c' + a*b) from named parameter vector.
#'
#' @param theta Named numeric vector with "a", "b", "c_prime" elements
#' @return Scalar: proportion mediated
proportion_mediated_fn <- function(theta) {
  indirect <- theta["a"] * theta["b"]
  total <- theta["c_prime"] + indirect
  indirect / total
}


# ==============================================================================
# Utility Functions
# ==============================================================================

#' Check if MASS Package is Available
#'
#' @return TRUE if MASS is installed
has_mass <- function() {
  requireNamespace("MASS", quietly = TRUE)
}


#' Check if lavaan Package is Available
#'
#' @return TRUE if lavaan is installed
has_lavaan <- function() {
  requireNamespace("lavaan", quietly = TRUE)
}


#' Skip Test if MASS Not Available
skip_without_mass <- function() {
  skip_if_not_installed("MASS")
}


#' Skip Test if lavaan Not Available
skip_without_lavaan <- function() {
  skip_if_not_installed("lavaan")
}
