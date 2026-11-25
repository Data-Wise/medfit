# Native SEM engine: the MLR estimator (ML estimates, robust standard errors, Yuan-Bentler scaled chi-square).
#
# Internal. `estimator = "MLR"` keeps the ML point estimates, and reports the Yuan-Bentler test that lavaan's
# `estimator = "MLR"` reports by default (`test = "yuan.bentler.mplus"`): the ML chi-square T divided by the scaling
# factor c = (tr(A1^-1 B1) - tr(E^-1 B0)) / df, where
#   * A1, B1 are the expected information and the cross product of the casewise scores of the saturated (unstructured)
#     mean and covariance model, per case, evaluated at the sample moments;
#   * E is the model information (observed or expected, as `information` asks) and B0 the cross product of the model's
#     casewise scores, per case, so tr(E^-1 B0) = sum(V_model * crossprod(scores)) with V_model the model-based
#     covariance of the estimates (projected on the active set, as every standard error of the engine is).
# With a fixed exogenous block the moments of those variables are not saturated parameters (lavaan drops them from
# A1 and B1); the same rows and columns are dropped here. The Satorra-Bentler (MLM) factor uses the normal-theory
# fourth moments instead and is a different number; it is not reported.

# The saturated trace tr(A1^-1 B1) for the observed data `x` (n x p). `has_mean` adds the mean block, `fixed` is the
# integer index of the fixed exogenous columns, whose mean and mutual covariances are dropped.
.sem_mlr_trace_h1 <- function(x, has_mean, fixed = integer()) {
  n <- nrow(x)
  p <- ncol(x)
  d <- sweep(x, 2L, colMeans(x))
  sigma <- crossprod(d) / n
  sigma_inv <- chol2inv(chol(sigma))
  z <- d %*% sigma_inv
  idx <- which(lower.tri(sigma, diag = TRUE), arr.ind = TRUE)
  # score of sigma_rc for r >= c: (Sigma^-1 d d' Sigma^-1 - Sigma^-1)_rc, halved on the diagonal
  s_cov <- vapply(seq_len(nrow(idx)), function(k) {
    r <- idx[k, 1L]
    cc <- idx[k, 2L]
    (z[, r] * z[, cc] - sigma_inv[r, cc]) * (if (r == cc) 0.5 else 1)
  }, numeric(n))
  # expected information of vech(Sigma): (1/2) D' (Sigma^-1 x Sigma^-1) D, entry by entry
  a_cov <- outer(seq_len(nrow(idx)), seq_len(nrow(idx)), Vectorize(function(k, l) {
    r <- idx[k, 1L]
    cc <- idx[k, 2L]
    u <- idx[l, 1L]
    v <- idx[l, 2L]
    f <- sigma_inv[r, u] * sigma_inv[cc, v] + sigma_inv[r, v] * sigma_inv[cc, u]
    0.5 * f * (if (u == v) 0.5 else 1) * (if (r == cc) 0.5 else 1) * 2
  }))
  scores <- s_cov
  a <- a_cov
  keep_cov <- !(idx[, 1L] %in% fixed & idx[, 2L] %in% fixed)
  if (has_mean) {
    scores <- cbind(z, s_cov)
    a <- rbind(cbind(sigma_inv, matrix(0, p, ncol(a_cov))), cbind(matrix(0, ncol(a_cov), p), a_cov))
    keep <- c(!(seq_len(p) %in% fixed), keep_cov)
  } else {
    keep <- keep_cov
  }
  b <- crossprod(scores) / n
  sum(solve(a[keep, keep, drop = FALSE]) * b[keep, keep, drop = FALSE])
}

# The classed refusal of an MLR request this engine does not define (the reason is in the message).
.sem_mlr_abort <- function(msg, what) {
  rlang::abort(msg, class = c(paste0("medfit_error_mlr_", what), "medfit_error_mlr"), call = NULL)
}

# `estimator = "MLR"` entry guards, in order: the route (two-level, FIML), sampling weights, then the constraint
# shapes. The scaled statistic is defined and checked against lavaan for single-level complete-data fits with linear
# equality constraints; every other shape is refused rather than reported without an oracle.
.sem_mlr_guard <- function(model, weights, missing, cluster) {
  if (!is.null(cluster) || .sem_has_level_lines(model)) {
    .sem_mlr_abort(paste0("estimator = \"MLR\" is not defined for a two-level model (`cluster =` or `level:` blocks); ",
                          "the cluster-robust two-level sandwich has no scaled chi-square in the engine"), "twolevel")
  }
  if (identical(missing, "fiml")) {
    .sem_mlr_abort(paste0("estimator = \"MLR\" is not defined with missing = \"fiml\"; the scaled statistic is ",
                          "implemented for complete data (listwise deletion)"), "missing")
  }
  if (!is.null(weights)) {
    .sem_mlr_abort(paste0("estimator = \"MLR\" is not defined with `weights`; the sandwich standard errors are ",
                          "available with se_type = \"sandwich\", but the scaled chi-square is not implemented"),
                   "weights")
  }
  parsed <- tryCatch(.sem_parse(paste(model, collapse = "\n")), error = function(e) NULL)
  if (!is.null(parsed) && nrow(parsed$constraints) &&
        (any(parsed$constraints$op %in% c("<", ">")) || .sem_has_nonlinear_constraint(parsed$constraints))) {
    .sem_mlr_abort(paste0("estimator = \"MLR\" is not defined with inequality or nonlinear constraints; ",
                          "only linear equality constraints are supported (equal labels or `==`)"), "constraints")
  }
  invisible()
}

# The MLR record of a fitted SEMFit: the Yuan-Bentler scaled chi-square, its scaling factor and p-value, stored in
# `@diagnostics$mlr` (read by `glance()`), plus `@diagnostics$estimator`. `refit_model` is the fit's model-based
# counterpart (same data, settings and estimates, `se_type = "model"`) that supplies V_model; it is the fit itself
# when that already is the model-based one. The statistic is NA with the model-test note when a product term makes
# the global test invalid, as `glance()` does for the plain chi-square.
.sem_mlr_record <- function(fit, model_fit) {
  if (length(fit@diagnostics$active_bounds)) {
    bound_msg <- paste0("estimator = \"MLR\" is not defined when an estimate sits on a bound (%s); the scaled ",
                        "statistic would need the bound's projected information, which has no lavaan oracle")
    .sem_mlr_abort(sprintf(bound_msg, paste(fit@diagnostics$active_bounds, collapse = ", ")), "bounds")
  }
  df <- fit@df
  chisq <- .sem_chisq(fit)
  na <- list(test = "yuan.bentler.mplus", chisq = chisq, chisq_scaled = NA_real_, scaling_factor = NA_real_,
             p_value_scaled = NA_real_, trace_h1 = NA_real_, trace_h0 = NA_real_)
  mlr <- na
  if (is.null(.sem_modeltest_reason(fit)) && df > 0) {
    ram <- fit@internals$ram
    smp <- .sem_sample(fit@data[, ram$obs, drop = FALSE], ram)
    fixed <- match(fit@internals$fixed_x, ram$obs)
    fixed <- fixed[!is.na(fixed)]
    h1 <- .sem_mlr_trace_h1(smp$x, isTRUE(ram$has_mean), fixed)
    h0 <- sum(model_fit@vcov * crossprod(.sem_scores(fit@theta, ram, smp)))
    sfac <- (h1 - h0) / df
    mlr$trace_h1 <- h1
    mlr$trace_h0 <- h0
    mlr$scaling_factor <- sfac
    mlr$chisq_scaled <- chisq / sfac
    mlr$p_value_scaled <- stats::pchisq(mlr$chisq_scaled, df = df, lower.tail = FALSE)
  } else if (is.null(.sem_modeltest_reason(fit)) && df == 0) {
    mlr$chisq_scaled <- chisq
  }
  dg <- fit@diagnostics
  dg$estimator <- "MLR"
  dg$mlr <- mlr
  fit@diagnostics <- dg
  fit
}
