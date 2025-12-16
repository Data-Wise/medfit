# Bootstrap Inference for Mediation Statistics
#
# This file implements bootstrap_mediation() and related helper functions
# for computing confidence intervals using parametric, nonparametric,
# and plugin methods.

#' Perform Bootstrap Inference for Mediation Statistics
#'
#' @description
#' Conduct bootstrap inference to compute confidence intervals for
#' mediation statistics. Supports parametric, nonparametric, and
#' plugin methods.
#'
#' @param statistic_fn Function that computes the statistic of interest.
#'   - For parametric bootstrap: receives named parameter vector, returns scalar
#'   - For nonparametric bootstrap: receives data frame, returns scalar
#'   - For plugin: receives named parameter vector, returns scalar
#' @param method Character string: bootstrap method. Options:
#'   - `"parametric"`: Sample from multivariate normal (fast, assumes normality)
#'   - `"nonparametric"`: Resample data and refit (robust, slower)
#'   - `"plugin"`: Point estimate only, no CI (fastest)
#' @param mediation_data [MediationData] object (required for parametric/plugin)
#' @param data Data frame (required for nonparametric bootstrap)
#' @param n_boot Integer: number of bootstrap samples (default: 1000)
#' @param ci_level Numeric: confidence level between 0 and 1 (default: 0.95)
#' @param parallel Logical: use parallel processing? (default: FALSE)
#' @param ncores Integer: number of cores for parallel processing.
#'   If NULL, uses `parallel::detectCores() - 1`
#' @param seed Integer: random seed for reproducibility (optional but recommended)
#' @param ... Additional arguments (reserved for future use)
#'
#' @return A [BootstrapResult] object containing:
#'   - Point estimate
#'   - Confidence interval bounds
#'   - Bootstrap distribution (for parametric and nonparametric)
#'   - Method used
#'
#' @details
#' ## Bootstrap Methods
#'
#' **Parametric Bootstrap** (`method = "parametric"`):
#' - Samples parameter vectors from \eqn{N(\hat{\theta}, \hat{\Sigma})}{N(theta-hat, Sigma-hat)}
#' - Fast and efficient
#' - Assumes asymptotic normality of parameters
#' - Recommended for most applications with n > 50
#' - Requires `mediation_data` argument
#'
#' **Nonparametric Bootstrap** (`method = "nonparametric"`):
#' - Resamples observations with replacement
#' - Refits models for each bootstrap sample
#' - More robust, no normality assumption
#' - Computationally intensive
#' - Use when normality is questionable or n is small
#' - Requires `data` argument
#'
#' **Plugin Estimator** (`method = "plugin"`):
#' - Computes point estimate only
#' - No confidence interval
#' - Fastest method
#' - Use for quick checks or when CI not needed
#' - Requires `mediation_data` argument
#'
#' ## Statistic Function
#'
#' The `statistic_fn` should be a function that:
#' - For parametric/plugin: Takes a named numeric vector of parameters
#' - For nonparametric: Takes a data frame
#' - Returns a single numeric value
#'
#' Common statistic functions for indirect effect:
#' ```r
#' # Using parameter names from MediationData
#' indirect_fn <- function(theta) {
#'   theta["m_X"] * theta["y_M"]  # a * b
#' }
#' ```
#'
#' ## Parallel Processing
#'
#' Set `parallel = TRUE` to use multiple cores:
#' - Uses `parallel::mclapply()` on Unix systems
#' - Falls back to sequential on Windows
#' - Automatically detects available cores
#'
#' ## Reproducibility
#'
#' Always set a seed for reproducible results:
#' ```r
#' bootstrap_mediation(..., seed = 12345)
#' ```
#'
#' @examples
#' \dontrun{
#' # First, fit mediation model
#' med_data <- fit_mediation(
#'   formula_y = Y ~ X + M,
#'   formula_m = M ~ X,
#'   data = mydata,
#'   treatment = "X",
#'   mediator = "M"
#' )
#'
#' # Define indirect effect function
#' indirect_fn <- function(theta) theta["m_X"] * theta["y_M"]
#'
#' # Parametric bootstrap for indirect effect
#' result <- bootstrap_mediation(
#'   statistic_fn = indirect_fn,
#'   method = "parametric",
#'   mediation_data = med_data,
#'   n_boot = 5000,
#'   ci_level = 0.95,
#'   seed = 12345
#' )
#'
#' # Print results
#' print(result)
#'
#' # Nonparametric bootstrap (slower but more robust)
#' # Note: statistic_fn must refit models when using nonparametric
#' refit_fn <- function(boot_data) {
#'   fit_m <- lm(M ~ X, data = boot_data)
#'   fit_y <- lm(Y ~ X + M, data = boot_data)
#'   coef(fit_m)["X"] * coef(fit_y)["M"]
#' }
#'
#' result_np <- bootstrap_mediation(
#'   statistic_fn = refit_fn,
#'   method = "nonparametric",
#'   data = mydata,
#'   n_boot = 1000,
#'   seed = 12345
#' )
#'
#' # Plugin estimator (point estimate only)
#' result_plugin <- bootstrap_mediation(
#'   statistic_fn = indirect_fn,
#'   method = "plugin",
#'   mediation_data = med_data
#' )
#' }
#'
#' @seealso [BootstrapResult], [MediationData], [fit_mediation()]
#' @export
bootstrap_mediation <- function(statistic_fn,
                                method = c("parametric", "nonparametric", "plugin"),
                                mediation_data = NULL,
                                data = NULL,
                                n_boot = 1000L,
                                ci_level = 0.95,
                                parallel = FALSE,
                                ncores = NULL,
                                seed = NULL,
                                ...) {
  # Match method argument
  method <- match.arg(method)

  # Validate statistic_fn
  if (missing(statistic_fn) || !is.function(statistic_fn)) {
    stop("statistic_fn must be a function")
  }

  # Validate ci_level
  if (ci_level <= 0 || ci_level >= 1) {
    stop("ci_level must be between 0 and 1 (exclusive)")
  }

  # Set seed if provided
  if (!is.null(seed)) {
    set.seed(seed)
  }

  # Dispatch to appropriate method
  result <- switch(method,
    parametric = .bootstrap_parametric(
      mediation_data = mediation_data,
      statistic_fn = statistic_fn,
      n_boot = n_boot,
      ci_level = ci_level,
      parallel = parallel,
      ncores = ncores
    ),
    nonparametric = .bootstrap_nonparametric(
      data = data,
      statistic_fn = statistic_fn,
      n_boot = n_boot,
      ci_level = ci_level,
      parallel = parallel,
      ncores = ncores
    ),
    plugin = .bootstrap_plugin(
      mediation_data = mediation_data,
      statistic_fn = statistic_fn
    )
  )

  result
}


#' Parametric Bootstrap
#'
#' @description
#' Performs parametric bootstrap by sampling from the multivariate normal
#' distribution of parameter estimates.
#'
#' @param mediation_data MediationData object
#' @param statistic_fn Function to compute statistic
#' @param n_boot Number of bootstrap samples
#' @param ci_level Confidence level
#' @param parallel Use parallel processing?
#' @param ncores Number of cores
#'
#' @return BootstrapResult object
#' @keywords internal
#' @noRd
.bootstrap_parametric <- function(mediation_data,
                                   statistic_fn,
                                   n_boot,
                                   ci_level,
                                   parallel,
                                   ncores) {
  # Validate mediation_data
  if (is.null(mediation_data)) {
    stop("mediation_data is required for parametric bootstrap")
  }
  if (!S7::S7_inherits(mediation_data, MediationData)) {
    stop("mediation_data must be a MediationData object")
  }

  # Check for MASS package
  if (!requireNamespace("MASS", quietly = TRUE)) {
    stop("MASS package is required for parametric bootstrap. ",
         "Install with: install.packages('MASS')")
  }

  # Extract parameters and vcov
  mu <- mediation_data@estimates
  Sigma <- mediation_data@vcov

  # Generate bootstrap parameter samples
  boot_params <- MASS::mvrnorm(n = n_boot, mu = mu, Sigma = Sigma)

  # Ensure boot_params is a matrix (even for single sample)
  if (!is.matrix(boot_params)) {
    boot_params <- matrix(boot_params, nrow = 1)
  }

  # Preserve column names
  colnames(boot_params) <- names(mu)

  # Compute statistic for each bootstrap sample
  if (parallel && .Platform$OS.type != "windows") {
    # Parallel processing (Unix only)
    n_cores <- ncores %||% max(1, parallel::detectCores() - 1)

    boot_estimates <- unlist(parallel::mclapply(
      seq_len(n_boot),
      function(i) statistic_fn(boot_params[i, ]),
      mc.cores = n_cores
    ))
  } else {
    # Sequential processing
    boot_estimates <- vapply(
      seq_len(n_boot),
      function(i) statistic_fn(boot_params[i, ]),
      numeric(1)
    )
  }

  # Compute point estimate and CI
  estimate <- statistic_fn(mu)
  alpha <- 1 - ci_level
  ci <- stats::quantile(boot_estimates, probs = c(alpha / 2, 1 - alpha / 2),
                        names = FALSE)

  # Create BootstrapResult
  BootstrapResult(
    estimate = estimate,
    ci_lower = ci[1],
    ci_upper = ci[2],
    ci_level = ci_level,
    boot_estimates = boot_estimates,
    n_boot = as.integer(n_boot),
    method = "parametric",
    call = NULL
  )
}


#' Nonparametric Bootstrap
#'
#' @description
#' Performs nonparametric bootstrap by resampling data with replacement.
#'
#' @param data Data frame
#' @param statistic_fn Function to compute statistic (receives data frame)
#' @param n_boot Number of bootstrap samples
#' @param ci_level Confidence level
#' @param parallel Use parallel processing?
#' @param ncores Number of cores
#'
#' @return BootstrapResult object
#' @keywords internal
#' @noRd
.bootstrap_nonparametric <- function(data,
                                      statistic_fn,
                                      n_boot,
                                      ci_level,
                                      parallel,
                                      ncores) {
  # Validate data
  if (is.null(data)) {
    stop("data is required for nonparametric bootstrap")
  }
  if (!is.data.frame(data)) {
    stop("data must be a data frame")
  }

  n <- nrow(data)

  # Bootstrap function
  boot_fn <- function(i) {
    # Resample with replacement
    boot_indices <- sample.int(n, size = n, replace = TRUE)
    boot_data <- data[boot_indices, , drop = FALSE]

    # Compute statistic
    tryCatch(
      statistic_fn(boot_data),
      error = function(e) NA_real_
    )
  }

  # Generate bootstrap samples
  if (parallel && .Platform$OS.type != "windows") {
    # Parallel processing (Unix only)
    n_cores <- ncores %||% max(1, parallel::detectCores() - 1)

    boot_estimates <- unlist(parallel::mclapply(
      seq_len(n_boot),
      boot_fn,
      mc.cores = n_cores
    ))
  } else {
    # Sequential processing
    boot_estimates <- vapply(seq_len(n_boot), boot_fn, numeric(1))
  }

  # Remove NA values (failed bootstrap samples)
  n_failed <- sum(is.na(boot_estimates))
  if (n_failed > 0) {
    warning(sprintf("%d bootstrap samples failed and were excluded", n_failed))
    boot_estimates <- boot_estimates[!is.na(boot_estimates)]
  }

  # Check if we have enough samples
  if (length(boot_estimates) < 10) {
    stop("Too many bootstrap samples failed. Check your statistic_fn.")
  }

  # Compute point estimate (from original data)
  estimate <- statistic_fn(data)

  # Compute CI
  alpha <- 1 - ci_level
  ci <- stats::quantile(boot_estimates, probs = c(alpha / 2, 1 - alpha / 2),
                        names = FALSE)

  # Create BootstrapResult
  BootstrapResult(
    estimate = estimate,
    ci_lower = ci[1],
    ci_upper = ci[2],
    ci_level = ci_level,
    boot_estimates = boot_estimates,
    n_boot = as.integer(length(boot_estimates)),
    method = "nonparametric",
    call = NULL
  )
}


#' Plugin Estimator
#'
#' @description
#' Computes point estimate only (no confidence interval).
#'
#' @param mediation_data MediationData object
#' @param statistic_fn Function to compute statistic
#'
#' @return BootstrapResult object
#' @keywords internal
#' @noRd
.bootstrap_plugin <- function(mediation_data, statistic_fn) {
  # Validate mediation_data
  if (is.null(mediation_data)) {
    stop("mediation_data is required for plugin method")
  }
  if (!S7::S7_inherits(mediation_data, MediationData)) {
    stop("mediation_data must be a MediationData object")
  }

  # Compute point estimate
  estimate <- statistic_fn(mediation_data@estimates)

  # Create BootstrapResult with NA for CI values
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


#' Null Coalescing Operator
#'
#' @description
#' Returns the left-hand side if not NULL, otherwise the right-hand side.
#'
#' @param x Left-hand side value
#' @param y Right-hand side value (default)
#'
#' @return x if not NULL, otherwise y
#' @keywords internal
#' @noRd
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
