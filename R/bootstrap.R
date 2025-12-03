# Bootstrap Infrastructure for medfit
#
# This file implements bootstrap inference methods for mediation statistics:
# - Parametric bootstrap: samples from N(theta-hat, Sigma-hat)
# - Nonparametric bootstrap: resamples data, refits models
# - Plugin estimator: point estimate only (no CI)
#
# All methods return a BootstrapResult S7 object for consistency.

#' Parametric Bootstrap for Mediation Statistics
#'
#' Samples parameter vectors from the asymptotic multivariate normal
#' distribution and computes the statistic of interest for each sample.
#'
#' @param mediation_data MediationData object with estimates and vcov
#' @param statistic_fn Function that takes parameter vector and returns scalar
#' @param n_boot Number of bootstrap samples
#' @param ci_level Confidence level (e.g., 0.95)
#' @param parallel Use parallel processing?
#' @param ncores Number of cores (NULL = auto-detect)
#'
#' @return BootstrapResult object
#' @keywords internal
.bootstrap_parametric <- function(mediation_data,
                                   statistic_fn,
                                   n_boot,
                                   ci_level,
                                   parallel,
                                   ncores) {

  # Check MASS is available
  if (!requireNamespace("MASS", quietly = TRUE)) {
    stop("MASS package required for parametric bootstrap.\n",
         "Install with: install.packages('MASS')",
         call. = FALSE)
  }

  # Extract parameters and vcov from mediation_data
  mu <- mediation_data@estimates
  Sigma <- mediation_data@vcov

  # Check for positive definiteness and handle near-singular matrices
  Sigma_adj <- .ensure_positive_definite(Sigma)

  # Generate bootstrap samples from multivariate normal
  boot_params <- MASS::mvrnorm(n = n_boot, mu = mu, Sigma = Sigma_adj)

  # Compute statistic for each bootstrap sample
  if (parallel && .parallel_available()) {
    ncores <- ncores %||% (parallel::detectCores() - 1L)
    ncores <- max(1L, ncores)

    boot_estimates <- parallel::mclapply(
      seq_len(n_boot),
      function(i) {
        tryCatch(
          statistic_fn(boot_params[i, ]),
          error = function(e) NA_real_
        )
      },
      mc.cores = ncores
    )
    boot_estimates <- unlist(boot_estimates)
  } else {
    boot_estimates <- vapply(
      seq_len(n_boot),
      function(i) {
        tryCatch(
          statistic_fn(boot_params[i, ]),
          error = function(e) NA_real_
        )
      },
      numeric(1)
    )
  }

  # Remove NA values and warn if many failures
  n_failed <- sum(is.na(boot_estimates))
  if (n_failed > 0) {
    warning(n_failed, " of ", n_boot, " bootstrap samples failed to compute",
            call. = FALSE)
    boot_estimates <- boot_estimates[!is.na(boot_estimates)]
  }

  # Compute confidence interval using percentile method
  alpha <- 1 - ci_level
  ci <- stats::quantile(boot_estimates, probs = c(alpha / 2, 1 - alpha / 2),
                        na.rm = TRUE)

  # Point estimate (mean of bootstrap distribution)
  estimate <- mean(boot_estimates, na.rm = TRUE)

  # Return BootstrapResult
  BootstrapResult(
    estimate = estimate,
    ci_lower = unname(ci[1]),
    ci_upper = unname(ci[2]),
    ci_level = ci_level,
    boot_estimates = boot_estimates,
    n_boot = as.integer(length(boot_estimates)),
    method = "parametric",
    call = NULL
  )
}


#' Nonparametric Bootstrap for Mediation Statistics
#'
#' Resamples data with replacement, refits models (via statistic_fn),
#' and computes confidence intervals from the bootstrap distribution.
#'
#' @param data Data frame to resample
#' @param statistic_fn Function that takes data frame and returns scalar
#' @param n_boot Number of bootstrap samples
#' @param ci_level Confidence level (e.g., 0.95)
#' @param parallel Use parallel processing?
#' @param ncores Number of cores (NULL = auto-detect)
#'
#' @return BootstrapResult object
#' @keywords internal
.bootstrap_nonparametric <- function(data,
                                      statistic_fn,
                                      n_boot,
                                      ci_level,
                                      parallel,
                                      ncores) {

  n <- nrow(data)

  # Bootstrap function: resample data and compute statistic
  boot_fn <- function(i) {
    # Resample rows with replacement
    boot_indices <- sample(n, replace = TRUE)
    boot_data <- data[boot_indices, , drop = FALSE]

    # Compute statistic (usually: fit models, extract paths, compute effect)
    tryCatch(
      statistic_fn(boot_data),
      error = function(e) NA_real_
    )
  }

  # Generate bootstrap estimates
  if (parallel && .parallel_available()) {
    ncores <- ncores %||% (parallel::detectCores() - 1L)
    ncores <- max(1L, ncores)

    boot_estimates <- parallel::mclapply(
      seq_len(n_boot),
      boot_fn,
      mc.cores = ncores
    )
    boot_estimates <- unlist(boot_estimates)
  } else {
    boot_estimates <- vapply(
      seq_len(n_boot),
      boot_fn,
      numeric(1)
    )
  }

  # Remove NA values and warn if many failures
  n_failed <- sum(is.na(boot_estimates))
  if (n_failed > 0) {
    warning(n_failed, " of ", n_boot, " bootstrap samples failed to compute",
            call. = FALSE)
    boot_estimates <- boot_estimates[!is.na(boot_estimates)]
  }

  if (length(boot_estimates) == 0) {
    stop("All bootstrap samples failed. Check statistic_fn for errors.",
         call. = FALSE)
  }

  # Compute confidence interval using percentile method
  alpha <- 1 - ci_level
  ci <- stats::quantile(boot_estimates, probs = c(alpha / 2, 1 - alpha / 2),
                        na.rm = TRUE)

  # Point estimate (mean of bootstrap distribution)
  estimate <- mean(boot_estimates, na.rm = TRUE)

  # Return BootstrapResult
  BootstrapResult(
    estimate = estimate,
    ci_lower = unname(ci[1]),
    ci_upper = unname(ci[2]),
    ci_level = ci_level,
    boot_estimates = boot_estimates,
    n_boot = as.integer(length(boot_estimates)),
    method = "nonparametric",
    call = NULL
  )
}


#' Plugin Estimator (No Bootstrap)
#'
#' Computes point estimate only, without confidence interval.
#' Fastest method, useful for quick checks or when CI is not needed.
#'
#' @param mediation_data MediationData object with estimates
#' @param statistic_fn Function that takes parameter vector and returns scalar
#'
#' @return BootstrapResult object with NA confidence bounds
#' @keywords internal
.bootstrap_plugin <- function(mediation_data, statistic_fn) {

  # Compute point estimate directly from MLE
  estimate <- statistic_fn(mediation_data@estimates)

  # Return BootstrapResult with NA CI
  BootstrapResult(
    estimate = estimate,
    ci_lower = NA_real_,
    ci_upper = NA_real_,
    ci_level = NA_real_,
    boot_estimates = numeric(0),
    n_boot = 0L,
    method = "plugin",
    call = NULL
  )
}


#' Check if Parallel Processing is Available
#'
#' @return TRUE if parallel package is available and we're not on Windows
#' @keywords internal
.parallel_available <- function() {
  # mclapply is not available on Windows
  if (.Platform$OS.type == "windows") {
    return(FALSE)
  }
  requireNamespace("parallel", quietly = TRUE)
}


#' Ensure Covariance Matrix is Positive Definite
#'
#' Adjusts near-singular covariance matrices to be positive definite
#' for multivariate normal sampling.
#'
#' @param Sigma Covariance matrix
#' @param tol Tolerance for eigenvalue adjustment
#'
#' @return Adjusted positive definite matrix
#' @keywords internal
.ensure_positive_definite <- function(Sigma, tol = 1e-8) {
  # Get eigendecomposition
  eig <- eigen(Sigma, symmetric = TRUE)

  # Check for negative or zero eigenvalues
  if (any(eig$values < tol)) {
    # Adjust small/negative eigenvalues
    eig$values <- pmax(eig$values, tol)
    # Reconstruct matrix
    Sigma <- eig$vectors %*% diag(eig$values) %*% t(eig$vectors)
    # Ensure symmetry
    Sigma <- (Sigma + t(Sigma)) / 2
    # Preserve names
    rownames(Sigma) <- colnames(Sigma)
  }

  Sigma
}


#' Null-Coalescing Operator
#'
#' Returns lhs if not NULL, otherwise rhs.
#'
#' @param lhs Left-hand side value
#' @param rhs Right-hand side value (default)
#' @return lhs if not NULL, otherwise rhs
#' @keywords internal
`%||%` <- function(lhs, rhs) {
  if (is.null(lhs)) rhs else lhs
}
