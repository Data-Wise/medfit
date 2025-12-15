# Helper Functions for Test Data Generation
#
# This file provides centralized test data generators used across
# multiple test files. All functions are available to all tests
# via testthat's helper file loading mechanism.
#
# Data generators:
# - Simple mediation (X -> M -> Y)
# - Serial mediation (X -> M1 -> M2 -> Y)
# - Mediation with covariates
# - Binary outcomes
# - Count outcomes
# - Binary mediators
#
# Helper functions:
# - Create MediationData from lm fits
# - Create SerialMediationData from lavaan fits
# - Statistic functions for bootstrap testing


# ==============================================================================
# Simple Mediation Data Generators
# ==============================================================================

#' Generate Simple Mediation Data
#'
#' Creates data for basic mediation model: X -> M -> Y
#'
#' @param n Integer: sample size (default: 200)
#' @param a Numeric: X -> M path coefficient (default: 0.5)
#' @param b Numeric: M -> Y path coefficient (default: 0.3)
#' @param c_prime Numeric: X -> Y direct effect (default: 0.2)
#' @param seed Integer: random seed (default: 123)
#' @param error_sd Numeric: standard deviation of error terms (default: 1.0)
#'
#' @return Data frame with columns X, M, Y
#' @examples
#' data <- generate_mediation_data(n = 100, a = 0.5, b = 0.4)
generate_mediation_data <- function(n = 200,
                                    a = 0.5,
                                    b = 0.3,
                                    c_prime = 0.2,
                                    seed = 123,
                                    error_sd = 1.0) {
  set.seed(seed)
  X <- rnorm(n)
  M <- a * X + rnorm(n, sd = error_sd)
  Y <- b * M + c_prime * X + rnorm(n, sd = error_sd)
  data.frame(X = X, M = M, Y = Y)
}


#' Generate Mediation Data with Covariates
#'
#' Creates mediation data with additional covariates
#' Model: M ~ X + C1, Y ~ X + M + C1 + C2
#'
#' @param n Integer: sample size (default: 200)
#' @param seed Integer: random seed (default: 123)
#'
#' @return Data frame with columns X, M, Y, C1, C2
generate_mediation_data_with_covariates <- function(n = 200, seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  C1 <- rnorm(n)
  C2 <- rnorm(n)
  M <- 0.5 * X + 0.3 * C1 + rnorm(n)
  Y <- 0.3 * M + 0.2 * X + 0.1 * C1 + 0.15 * C2 + rnorm(n)
  data.frame(X = X, M = M, Y = Y, C1 = C1, C2 = C2)
}


# ==============================================================================
# Serial Mediation Data Generators
# ==============================================================================

#' Generate Serial Mediation Data (2 mediators)
#'
#' Creates data for serial mediation: X -> M1 -> M2 -> Y
#'
#' @param n Integer: sample size (default: 200)
#' @param a Numeric: X -> M1 path (default: 0.5)
#' @param d Numeric: M1 -> M2 path (default: 0.4)
#' @param b Numeric: M2 -> Y path (default: 0.3)
#' @param c_prime Numeric: X -> Y direct effect (default: 0.1)
#' @param seed Integer: random seed (default: 123)
#'
#' @return Data frame with columns X, M1, M2, Y
generate_serial_mediation_data <- function(n = 200,
                                           a = 0.5,
                                           d = 0.4,
                                           b = 0.3,
                                           c_prime = 0.1,
                                           seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M1 <- a * X + rnorm(n)
  M2 <- d * M1 + rnorm(n)
  Y <- b * M2 + c_prime * X + rnorm(n)
  data.frame(X = X, M1 = M1, M2 = M2, Y = Y)
}


#' Generate Serial Mediation Data (3 mediators)
#'
#' Creates data for serial mediation: X -> M1 -> M2 -> M3 -> Y
#'
#' @param n Integer: sample size (default: 200)
#' @param a Numeric: X -> M1 path (default: 0.5)
#' @param d21 Numeric: M1 -> M2 path (default: 0.4)
#' @param d32 Numeric: M2 -> M3 path (default: 0.35)
#' @param b Numeric: M3 -> Y path (default: 0.3)
#' @param c_prime Numeric: X -> Y direct effect (default: 0.1)
#' @param seed Integer: random seed (default: 123)
#'
#' @return Data frame with columns X, M1, M2, M3, Y
generate_serial_mediation_data_3med <- function(n = 200,
                                                 a = 0.5,
                                                 d21 = 0.4,
                                                 d32 = 0.35,
                                                 b = 0.3,
                                                 c_prime = 0.1,
                                                 seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M1 <- a * X + rnorm(n)
  M2 <- d21 * M1 + rnorm(n)
  M3 <- d32 * M2 + rnorm(n)
  Y <- b * M3 + c_prime * X + rnorm(n)
  data.frame(X = X, M1 = M1, M2 = M2, M3 = M3, Y = Y)
}


# ==============================================================================
# Binary and Count Outcome Data Generators
# ==============================================================================

#' Generate Binary Outcome Mediation Data
#'
#' Creates mediation data with binary (0/1) outcome using logistic model
#'
#' @param n Integer: sample size (default: 300, larger for binary)
#' @param a Numeric: X -> M path (default: 0.5)
#' @param b Numeric: M -> Y path on logit scale (default: 0.5)
#' @param c_prime Numeric: X -> Y path on logit scale (default: 0.3)
#' @param seed Integer: random seed (default: 123)
#'
#' @return Data frame with columns X, M, Y (Y is binary)
generate_binary_outcome_data <- function(n = 300,
                                         a = 0.5,
                                         b = 0.5,
                                         c_prime = 0.3,
                                         seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M <- a * X + rnorm(n)
  Y_logit <- b * M + c_prime * X
  Y_prob <- plogis(Y_logit)
  Y <- rbinom(n, 1, Y_prob)
  data.frame(X = X, M = M, Y = Y)
}


#' Generate Count Outcome Mediation Data
#'
#' Creates mediation data with count outcome using Poisson model
#'
#' @param n Integer: sample size (default: 300)
#' @param a Numeric: X -> M path (default: 0.5)
#' @param b Numeric: M -> Y path on log scale (default: 0.3)
#' @param c_prime Numeric: X -> Y path on log scale (default: 0.2)
#' @param intercept Numeric: log-scale intercept (default: 1)
#' @param seed Integer: random seed (default: 123)
#'
#' @return Data frame with columns X, M, Y (Y is count)
generate_count_outcome_data <- function(n = 300,
                                        a = 0.5,
                                        b = 0.3,
                                        c_prime = 0.2,
                                        intercept = 1,
                                        seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M <- a * X + rnorm(n)
  Y_log <- intercept + b * M + c_prime * X
  Y_lambda <- exp(Y_log)
  Y <- rpois(n, Y_lambda)
  data.frame(X = X, M = M, Y = Y)
}


# ==============================================================================
# Binary Mediator Data Generators
# ==============================================================================

#' Generate Binary Mediator Data
#'
#' Creates mediation data with binary mediator using logistic model
#'
#' @param n Integer: sample size (default: 300)
#' @param a Numeric: X -> M path on logit scale (default: 0.5)
#' @param b Numeric: M -> Y path (default: 0.3)
#' @param c_prime Numeric: X -> Y path (default: 0.2)
#' @param seed Integer: random seed (default: 123)
#'
#' @return Data frame with columns X, M (binary), Y
generate_binary_mediator_data <- function(n = 300,
                                          a = 0.5,
                                          b = 0.3,
                                          c_prime = 0.2,
                                          seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M_logit <- a * X
  M_prob <- plogis(M_logit)
  M <- rbinom(n, 1, M_prob)
  Y <- b * M + c_prime * X + rnorm(n)
  data.frame(X = X, M = M, Y = Y)
}


#' Generate Binary Mediator and Binary Outcome Data
#'
#' Creates mediation data with both binary mediator and outcome
#'
#' @param n Integer: sample size (default: 300)
#' @param a Numeric: X -> M path on logit scale (default: 0.5)
#' @param b Numeric: M -> Y path on logit scale (default: 0.3)
#' @param c_prime Numeric: X -> Y path on logit scale (default: 0.2)
#' @param seed Integer: random seed (default: 123)
#'
#' @return Data frame with columns X, M (binary), Y (binary)
generate_binary_both_data <- function(n = 300,
                                      a = 0.5,
                                      b = 0.3,
                                      c_prime = 0.2,
                                      seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M_logit <- a * X
  M_prob <- plogis(M_logit)
  M <- rbinom(n, 1, M_prob)
  Y_logit <- b * M + c_prime * X
  Y_prob <- plogis(Y_logit)
  Y <- rbinom(n, 1, Y_prob)
  data.frame(X = X, M = M, Y = Y)
}


# ==============================================================================
# Helper Functions for Creating MediationData Objects
# ==============================================================================

#' Create MediationData from Simple Mediation Data
#'
#' Fits lm models and extracts MediationData object for testing
#'
#' @param data Data frame with columns X, M, Y
#'
#' @return MediationData object
create_test_mediation_data <- function(data) {
  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )
}


#' Create MediationData with Covariates
#'
#' Fits lm models with covariates and extracts MediationData
#'
#' @param data Data frame with columns X, M, Y, C1, C2
#'
#' @return MediationData object
create_test_mediation_data_with_covariates <- function(data) {
  fit_m <- lm(M ~ X + C1, data = data)
  fit_y <- lm(Y ~ X + M + C1 + C2, data = data)

  extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )
}


# ==============================================================================
# Statistic Functions for Bootstrap Testing
# ==============================================================================

#' Simple Indirect Effect Function
#'
#' Computes indirect effect (a * b) from parameter vector
#'
#' @param theta Named numeric vector with elements "a" and "b"
#'
#' @return Numeric: indirect effect
indirect_effect <- function(theta) {
  theta["a"] * theta["b"]
}


#' Total Effect Function
#'
#' Computes total effect (a * b + c_prime) from parameter vector
#'
#' @param theta Named numeric vector with "a", "b", "c_prime"
#'
#' @return Numeric: total effect
total_effect <- function(theta) {
  theta["a"] * theta["b"] + theta["c_prime"]
}


#' Proportion Mediated Function
#'
#' Computes proportion of total effect mediated: (a*b) / (a*b + c')
#'
#' @param theta Named numeric vector with "a", "b", "c_prime"
#'
#' @return Numeric: proportion mediated
proportion_mediated <- function(theta) {
  indirect <- theta["a"] * theta["b"]
  total <- indirect + theta["c_prime"]
  if (abs(total) < 1e-10) return(NA_real_)  # Avoid division by zero
  indirect / total
}


#' Serial Indirect Effect Function (Product-of-Three)
#'
#' Computes serial indirect effect (a * d * b) from parameter vector
#'
#' @param theta Named numeric vector with "a", "d", "b"
#'
#' @return Numeric: serial indirect effect
serial_indirect_effect <- function(theta) {
  theta["a"] * theta["d"] * theta["b"]
}


#' Statistic Function for Nonparametric Bootstrap
#'
#' Refits models on resampled data and computes indirect effect
#'
#' @param boot_data Data frame with resampled observations
#'
#' @return Numeric: indirect effect from refitted models
statistic_fn_refit <- function(boot_data) {
  med_data <- create_test_mediation_data(boot_data)
  med_data@a_path * med_data@b_path
}


# ==============================================================================
# Data Validation Helpers
# ==============================================================================

#' Check if MediationData Object is Valid
#'
#' Performs basic validation checks on MediationData object
#'
#' @param med_data MediationData object
#'
#' @return Logical: TRUE if valid, FALSE otherwise
is_valid_mediation_data <- function(med_data) {
  if (!inherits(med_data, "medfit::MediationData")) return(FALSE)
  if (!is.numeric(med_data@a_path)) return(FALSE)
  if (!is.numeric(med_data@b_path)) return(FALSE)
  if (!is.numeric(med_data@c_prime)) return(FALSE)
  if (length(med_data@a_path) != 1) return(FALSE)
  if (length(med_data@b_path) != 1) return(FALSE)
  if (length(med_data@c_prime) != 1) return(FALSE)
  if (nrow(med_data@vcov) != ncol(med_data@vcov)) return(FALSE)
  if (nrow(med_data@vcov) != length(med_data@estimates)) return(FALSE)
  TRUE
}


#' Check if BootstrapResult Object is Valid
#'
#' Performs basic validation checks on BootstrapResult object
#'
#' @param boot_result BootstrapResult object
#'
#' @return Logical: TRUE if valid, FALSE otherwise
is_valid_bootstrap_result <- function(boot_result) {
  if (!inherits(boot_result, "medfit::BootstrapResult")) return(FALSE)
  if (!is.numeric(boot_result@estimate)) return(FALSE)
  if (length(boot_result@estimate) != 1) return(FALSE)

  # Plugin method has NA CIs
  if (boot_result@method == "plugin") {
    if (!is.na(boot_result@ci_lower)) return(FALSE)
    if (!is.na(boot_result@ci_upper)) return(FALSE)
    if (length(boot_result@boot_estimates) != 0) return(FALSE)
  } else {
    # Parametric/nonparametric should have valid CIs
    if (!is.numeric(boot_result@ci_lower)) return(FALSE)
    if (!is.numeric(boot_result@ci_upper)) return(FALSE)
    if (boot_result@ci_lower >= boot_result@ci_upper) return(FALSE)
    if (length(boot_result@boot_estimates) != boot_result@n_boot) return(FALSE)
  }

  TRUE
}


# ==============================================================================
# Test Data with Known Properties
# ==============================================================================

#' Generate Perfect Mediation Data (c' = 0)
#'
#' Creates data where all effect goes through mediator (no direct effect)
#'
#' @param n Integer: sample size (default: 200)
#' @param a Numeric: X -> M path (default: 0.5)
#' @param b Numeric: M -> Y path (default: 0.3)
#' @param seed Integer: random seed (default: 123)
#'
#' @return Data frame with columns X, M, Y
generate_perfect_mediation_data <- function(n = 200,
                                            a = 0.5,
                                            b = 0.3,
                                            seed = 123) {
  generate_mediation_data(n = n, a = a, b = b, c_prime = 0, seed = seed)
}


#' Generate No Mediation Data (a = 0)
#'
#' Creates data with no mediation (treatment doesn't affect mediator)
#'
#' @param n Integer: sample size (default: 200)
#' @param c_prime Numeric: X -> Y direct effect (default: 0.5)
#' @param seed Integer: random seed (default: 123)
#'
#' @return Data frame with columns X, M, Y
generate_no_mediation_data <- function(n = 200,
                                       c_prime = 0.5,
                                       seed = 123) {
  generate_mediation_data(n = n, a = 0, b = 0.3, c_prime = c_prime, seed = seed)
}


#' Generate Suppression Data (c' and a*b opposite signs)
#'
#' Creates data with inconsistent mediation (suppression effect)
#'
#' @param n Integer: sample size (default: 200)
#' @param seed Integer: random seed (default: 123)
#'
#' @return Data frame with columns X, M, Y
generate_suppression_data <- function(n = 200, seed = 123) {
  # Direct effect positive, indirect effect negative
  generate_mediation_data(n = n, a = 0.5, b = -0.3, c_prime = 0.4, seed = seed)
}
