# Oracle for IG3 T-B (twolevel_equal_indirect()): the hand O8 likelihood of helper-twolevel-likelihood.R maximized
# under `a_w * b_w == a_b * b_b`, written without the package's nonlinear gate and without lavaan (lavaan's nonlinear
# two-level fit returned an inadmissible optimum with a spurious LR of 68.7 on a fixture of this family, so it is not
# the statistic oracle). The 12 path/variance parameters are `th = (a, b, cp, log vx, log vm, log vy)` per level,
# variances on the log scale so no point of the search can be inadmissible. The constraint is solved for one of the four
# product paths (indices 1, 2, 7, 8) and the other 11 are optimized; every elimination is tried and the best
# log-likelihood kept, so a divisor near 0 cannot hide the optimum. `sign` = -1 plants the sign-flipped null
# `a_w * b_w == -a_b * b_b`.
tl_o8_fit_equal <- function(data, cluster = "cluster", sign = 1, start_from = NULL) {
  st <- tl_stats(data, cluster)
  free <- if (is.null(start_from)) tl_o8_fit(data, cluster) else start_from
  logi <- c(4:6, 10:12)
  th0 <- c(free$within, free$between)
  th0[logi] <- log(th0[logi])
  unpack <- function(th) {
    th[logi] <- exp(th[logi])
    list(sw = do.call(tl_sigma, as.list(th[1:6])), sb = do.call(tl_sigma, as.list(th[7:12])))
  }
  nll_full <- function(th) {
    out <- tryCatch(
      {
        s <- unpack(th)
        -tl_loglik(st, s$sw, s$sb, tl_mu_hat(st, s$sw, s$sb))
      },
      error = function(e) {
        if (!grepl("singular|not positive", conditionMessage(e))) stop(e)
        NA_real_
      }
    )
    if (is.finite(out)) out else 1e10
  }
  # theta with the eliminated coordinate `k` solved from the other three product paths
  solve_k <- function(th, k) {
    th[k] <- switch(as.character(k),
      "7" = th[1] * th[2] / (sign * th[8]),
      "8" = th[1] * th[2] / (sign * th[7]),
      "1" = sign * th[7] * th[8] / th[2],
      "2" = sign * th[7] * th[8] / th[1]
    )
    th
  }
  best <- NULL
  for (k in c(7L, 8L, 1L, 2L)) {
    keep <- setdiff(seq_along(th0), k)
    start <- th0[keep]
    # a sign-flipped null starts from a point on its surface: only the eliminated coordinate is moved
    full <- function(x) {
      th <- numeric(12)
      th[keep] <- x
      solve_k(th, k)
    }
    nll <- function(x) nll_full(full(x))
    ctl <- list(maxit = 5000, reltol = 1e-15)
    opt <- stats::optim(start, nll, method = "BFGS", control = ctl)
    opt <- stats::optim(opt$par, nll, method = "BFGS", control = ctl)
    if (is.null(best) || opt$value < best$value) best <- list(value = opt$value, th = full(opt$par))
  }
  th <- best$th
  th[logi] <- exp(th[logi])
  list(
    loglik = -best$value, within = th[1:6], between = th[7:12],
    indirect = c(within = th[1] * th[2], between = th[7] * th[8])
  )
}
