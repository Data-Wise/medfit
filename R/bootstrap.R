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
#' @param mediation_data A mediation data object (required for parametric/plugin):
#'   [MediationData], [SerialMediationData], [ParallelMediationData],
#'   [InteractionMediationData], or [JointMediationData]. `statistic_fn`
#'   receives its named `@estimates` vector, which includes path aliases (e.g.
#'   `a`, `d1`, `b`, `c_prime` for a serial chain; `a1`, `b1`, `a2`, `b2` for
#'   parallel mediators). For a [JointMediationData] the aliases alone cannot
#'   reproduce the NDE, which also needs the prefixed intercept and covariate
#'   rows (`m1_`, ..., `y_`) and the sample covariate means.
#' @param data Data frame (required for nonparametric bootstrap)
#' @param cluster Character string: name of a cluster variable in `data`, for
#'   `method = "nonparametric"` only (an error with the other methods). The
#'   resampling then draws whole clusters with replacement and gives each draw
#'   a fresh cluster id before `statistic_fn` sees the data, so a cluster drawn
#'   twice is refit as two clusters, not one bigger one. Singular fits and
#'   convergence warnings from a refit count as failures: they are excluded,
#'   their messages are suppressed, and their number is added to the warning.
#'   `NULL` (default) resamples rows as before.
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
#'   - Percentile confidence interval bounds (the \eqn{\alpha/2}{alpha/2} and
#'     \eqn{1 - \alpha/2}{1 - alpha/2} quantiles of the bootstrap distribution)
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
#'   theta["m_X"] * theta["y_M"]
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
#' # Fit mediation model
#' med_data <- fit_mediation(
#'   formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
#'   formula_m = mediator1 ~ treatment + covariate1 + covariate2,
#'   data = mediation_demo,
#'   treatment = "treatment",
#'   mediator = "mediator1"
#' )
#'
#' # Define indirect effect function
#' indirect_fn <- function(theta) theta["m_treatment"] * theta["y_mediator1"]
#'
#' # Plugin estimator (point estimate only, fastest)
#' result_plugin <- bootstrap_mediation(
#'   statistic_fn = indirect_fn,
#'   method = "plugin",
#'   mediation_data = med_data
#' )
#' print(result_plugin)
#'
#' \donttest{
#' # Parametric bootstrap (recommended for most applications)
#' result <- bootstrap_mediation(
#'   statistic_fn = indirect_fn,
#'   method = "parametric",
#'   mediation_data = med_data,
#'   n_boot = 1000,
#'   ci_level = 0.95,
#'   seed = 12345
#' )
#' print(result)
#'
#' # Nonparametric bootstrap (slower but more robust)
#' refit_fn <- function(boot_data) {
#'   fit_m <- lm(mediator1 ~ treatment + covariate1 + covariate2,
#'               data = boot_data)
#'   fit_y <- lm(outcome ~ treatment + mediator1 + covariate1 + covariate2,
#'               data = boot_data)
#'   unname(coef(fit_m)["treatment"] * coef(fit_y)["mediator1"])
#' }
#'
#' result_np <- bootstrap_mediation(
#'   statistic_fn = refit_fn,
#'   method = "nonparametric",
#'   data = mediation_demo,
#'   n_boot = 500,
#'   seed = 12345
#' )
#' print(result_np)
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
                                cluster = NULL,
                                ...) {
  # --- Input Validation (using checkmate for fail-fast defensive programming) ---
  checkmate::assert_function(statistic_fn, .var.name = "statistic_fn")
  method <- match.arg(method)
  checkmate::assert_count(n_boot, positive = TRUE, .var.name = "n_boot")
  checkmate::assert_number(ci_level, lower = 0, upper = 1,
                           .var.name = "ci_level")
  checkmate::assert_flag(parallel, .var.name = "parallel")
  checkmate::assert_count(
    ncores, positive = TRUE, null.ok = TRUE,
    .var.name = "ncores"
  )
  checkmate::assert_int(seed, null.ok = TRUE, .var.name = "seed")
  checkmate::assert_string(cluster, null.ok = TRUE, .var.name = "cluster")
  if (!is.null(cluster) && method != "nonparametric") {
    stop("`cluster` resamples whole clusters and needs method = \"nonparametric\"; ",
         "the \"", method, "\" method does not resample data.", call. = FALSE)
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
      ncores = ncores,
      cluster = cluster
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
.bootstrap_parametric <- function(
  mediation_data,
  statistic_fn,
  n_boot,
  ci_level,
  parallel,
  ncores
) {
  # Validate mediation_data
  if (is.null(mediation_data)) {
    stop("mediation_data is required for parametric bootstrap", call. = FALSE)
  }
  .assert_param_mediation_data(mediation_data)

  # Check for MASS package
  if (!requireNamespace("MASS", quietly = TRUE)) {
    stop("MASS package is required for parametric bootstrap. ",
         "Install with: install.packages('MASS')", call. = FALSE)
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
#' @param cluster Name of a cluster variable in `data`, or `NULL` for the row
#'   bootstrap.
#'
#' @return BootstrapResult object
#' @keywords internal
#' @noRd
.bootstrap_nonparametric <- function(
  data,
  statistic_fn,
  n_boot,
  ci_level,
  parallel,
  ncores,
  cluster = NULL
) {
  # Validate data
  checkmate::assert_data_frame(data, min.rows = 1, .var.name = "data")
  if (!is.null(cluster)) {
    checkmate::assert_choice(cluster, choices = names(data),
                             .var.name = "cluster (must be in data)")
    return(.bootstrap_nonparametric_cluster(
      data, statistic_fn, n_boot, ci_level, parallel, ncores, cluster
    ))
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
    stop("Too many bootstrap samples failed. Check your statistic_fn.",
         call. = FALSE)
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


#' Give Each Drawn Cluster a Fresh Id
#'
#' @description
#' Stacks the rows of the drawn clusters, in draw order, and replaces the
#' cluster variable by one new id per *draw*, so a cluster drawn twice becomes
#' two clusters. Without this, a refit would see the repeated cluster as one
#' bigger cluster. A separately named function so a test can plant the
#' no-relabeling defect.
#'
#' @param data Data frame.
#' @param cluster Name of the cluster variable.
#' @param ids The drawn cluster values (length J, with repeats).
#' @return `data` restricted to the drawn rows, with a new `cluster` column of
#'   the original type holding the draw number.
#' @keywords internal
#' @noRd
.relabel_clusters <- function(data, cluster, ids) {
  rows <- split(seq_len(nrow(data)), as.character(data[[cluster]]))
  picked <- rows[as.character(ids)]
  out <- data[unlist(picked, use.names = FALSE), , drop = FALSE]
  draw <- rep(seq_along(picked), lengths(picked))
  out[[cluster]] <- if (is.factor(data[[cluster]])) {
    factor(draw, levels = seq_along(picked))
  } else if (is.numeric(data[[cluster]])) {
    draw
  } else {
    as.character(draw)
  }
  rownames(out) <- NULL
  out
}


#' Cluster Bootstrap
#'
#' @description
#' Resamples whole clusters with replacement (Field and Welsh 2007 is cited
#' only for resampling whole clusters), relabels them, and refits. A refit
#' that is singular or warns about convergence counts as a failure (D14): it is
#' excluded, its messages are suppressed, and the count goes into the warning.
#'
#' @inheritParams .bootstrap_nonparametric
#' @return BootstrapResult object
#' @keywords internal
#' @noRd
.bootstrap_nonparametric_cluster <- function(data, statistic_fn, n_boot, ci_level,
                                             parallel, ncores, cluster) {
  values <- unique(data[[cluster]])
  J <- length(values)

  boot_fn <- function(i) {
    ids <- sample(values, J, replace = TRUE)
    boot_data <- .relabel_clusters(data, cluster, ids)
    flagged <- FALSE
    est <- withCallingHandlers(
      tryCatch(statistic_fn(boot_data), error = function(e) NA_real_),
      warning = function(w) {
        flagged <<- TRUE
        invokeRestart("muffleWarning")
      },
      message = function(m) {
        if (grepl("singular", conditionMessage(m), fixed = TRUE)) flagged <<- TRUE
        invokeRestart("muffleMessage")
      }
    )
    c(estimate = if (flagged) NA_real_ else est, flagged = flagged)
  }

  if (parallel && .Platform$OS.type != "windows") {
    n_cores <- ncores %||% max(1, parallel::detectCores() - 1)
    res <- do.call(rbind, parallel::mclapply(seq_len(n_boot), boot_fn,
                                             mc.cores = n_cores))
  } else {
    res <- t(vapply(seq_len(n_boot), boot_fn, numeric(2)))
  }
  boot_estimates <- res[, "estimate"]
  n_flagged <- sum(res[, "flagged"] == 1)
  n_failed <- sum(is.na(boot_estimates))
  if (n_failed > 0) {
    warning(sprintf(paste0("%d bootstrap samples failed and were excluded ",
                           "(%d of them singular or non-convergent refits)"),
                    n_failed, n_flagged))
    boot_estimates <- boot_estimates[!is.na(boot_estimates)]
  }
  if (length(boot_estimates) < 10) {
    stop("Too many bootstrap samples failed. Check your statistic_fn.",
         call. = FALSE)
  }

  estimate <- statistic_fn(data)
  alpha <- 1 - ci_level
  ci <- stats::quantile(boot_estimates, probs = c(alpha / 2, 1 - alpha / 2),
                        names = FALSE)
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
    stop("mediation_data is required for plugin method", call. = FALSE)
  }
  .assert_param_mediation_data(mediation_data)

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


#' Validate a Mediation Data Object for Parameter-Based Bootstrap
#'
#' @description
#' The parametric and plugin methods only read `@estimates` and `@vcov`, which
#' every mediation data class carries with matching names (including the path
#' aliases such as `a`, `d1`, `b1`, `c_prime`). Accept any of them rather than
#' only `MediationData`, which the other classes do not inherit from.
#'
#' @param x Object to check
#'
#' @return `x`, invisibly; errors if `x` is not a supported class
#' @keywords internal
#' @noRd
.assert_param_mediation_data <- function(x) {
  supported <- list(
    MediationData, SerialMediationData,
    ParallelMediationData, InteractionMediationData, JointMediationData,
    ClusterMediationData
  )
  ok <- any(vapply(supported, function(cls) S7::S7_inherits(x, cls), logical(1)))
  if (!ok) {
    stop("mediation_data must be a MediationData, SerialMediationData, ",
         "ParallelMediationData, InteractionMediationData, ",
         "JointMediationData, or ClusterMediationData object",
         call. = FALSE)
  }
  invisible(x)
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
`%||%` <- function(x, y) {  # nolint: object_name_linter.
  if (is.null(x)) y else x
}
