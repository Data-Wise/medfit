# Native SEM engine: sandwich covariance and sampling weights.
#
# Internal. With sampling weights w_i (rescaled to sum to n) the fit minimizes the ML discrepancy on the
# weighted mean and covariance. The robust covariance of the estimates is the sandwich A^-1 B A^-1, with A
# the information (observed or expected) and B the cross product of the casewise scores of the weighted
# pseudo log likelihood. With a mean structure the means are functions of theta, so the scores carry a mean
# part and A is the full information; without one the means are free and unrelated to theta. The sandwich
# is invariant to the scale of the weights.

# Casewise scores, an n x q matrix: row i is w_i * d/dtheta of the normal log likelihood of case i with the
# means at their weighted estimates,
#   s_ik = w_i * (1/2) tr(Sigma^-1 (d_i d_i' - Sigma) Sigma^-1 dSigma_k),  d_i = x_i - mean.
# Unweighted fits use w_i = 1. The scores sum to the gradient of the weighted likelihood, zero at the optimum.
.sem_scores <- function(theta, ram, smp) {
  sigma <- .sem_implied(ram, theta)
  sigma_inv <- chol2inv(chol(sigma))
  w <- if (is.null(smp$w)) rep(1, smp$n) else smp$w
  # (Sigma^-1 d_i d_i' Sigma^-1 - Sigma^-1) contracted with dSigma_k, for every case at once:
  # sum_rc [Sigma^-1 d_i]_r [Sigma^-1 d_i]_c dSigma_k[r, c] - tr(Sigma^-1 dSigma_k)
  # With a mean structure d_i = x_i - mu(theta), and each score gains the mean part w_i dmu_k' Sigma^-1 d_i;
  # the covariance-only case keeps the casewise deviations from the weighted mean.
  d <- if (isTRUE(ram$has_mean)) sweep(smp$x, 2L, .sem_implied_mean(ram, theta)) else smp$xc
  z <- d %*% sigma_inv
  dmu <- if (isTRUE(ram$has_mean)) .sem_dmu(theta, ram)
  dsig <- .sem_dsigma(theta, ram)
  vapply(seq_along(dsig), function(k) {
    sc <- 0.5 * (rowSums((z %*% dsig[[k]]) * z) - sum(sigma_inv * dsig[[k]]))
    if (!is.null(dmu)) sc <- sc + drop(z %*% dmu[, k])
    w * sc
  }, numeric(smp$n))
}

# Validate sampling weights against the rows of `data`: numeric, finite, non-negative, one per row, and at
# least one positive. Returns them as a plain numeric vector.
.sem_check_weights <- function(weights, n_rows) {
  checkmate::assert_numeric(weights, len = n_rows, lower = 0, any.missing = FALSE, finite = TRUE,
                            .var.name = "weights")
  if (!any(weights > 0)) {
    stop("`weights` must have at least one positive value", call. = FALSE)
  }
  as.numeric(weights)
}
