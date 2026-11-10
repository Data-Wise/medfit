# Oracle O8 (issue #394, SPEC-twolevel-adapter-S2 section 7): a hand-built, pure base-R
# Gaussian ML likelihood for a two-level (random-intercept) 1-1-1 observed mediation model
# X -> M -> Y, written from the multivariate normal density of a cluster. It contains no
# lavaan code, so lavaan's two-level likelihood and estimates are checked against an
# independent computation rather than against the software the adapter wraps.
#
# Model (vector z = (X, M, Y), cluster j with n_j rows):
#   z_ij = mu + u_j + e_ij,  u_j ~ N(0, Sigma_B),  e_ij ~ N(0, Sigma_W)
# Each level's covariance is implied by the recursive paths
#   M <- a X,  Y <- b M + cp X,  independent residuals, free variance for X,
# so each level is a saturated 3 x 3 covariance (6 free parameters per level) and the
# means are free (3). The log-likelihood of cluster j is
#   -1/2 [ n_j p log(2 pi) + (n_j - 1) log|S_W| + log|S_W + n_j S_B|
#          + tr(S_W^-1 SSW_j) + n_j (zbar_j - mu)' (S_W + n_j S_B)^-1 (zbar_j - mu) ]
# with SSW_j the within-cluster centered cross-product matrix.

tl_vars <- c("X", "M", "Y")

# Covariance implied by one level's paths: (I - B)^-1 Psi (I - B)^-T, order X, M, Y.
tl_sigma <- function(a, b, cp, vx, vm, vy) {
  b_mat <- matrix(0, 3, 3, dimnames = list(tl_vars, tl_vars))
  b_mat["M", "X"] <- a
  b_mat["Y", "M"] <- b
  b_mat["Y", "X"] <- cp
  inv <- solve(diag(3) - b_mat)
  out <- inv %*% diag(c(vx, vm, vy)) %*% t(inv)
  dimnames(out) <- list(tl_vars, tl_vars)
  out
}

# Path parameters back from a covariance matrix (the exact inverse of tl_sigma()).
tl_paths <- function(s) {
  a <- s["X", "M"] / s["X", "X"]
  reg_y <- solve(s[c("X", "M"), c("X", "M")], s[c("X", "M"), "Y"])
  out <- c(
    a, unname(reg_y[2]), unname(reg_y[1]),
    s["X", "X"], s["M", "M"] - a^2 * s["X", "X"], s["Y", "Y"] - sum(reg_y * s[c("X", "M"), "Y"])
  )
  stats::setNames(unname(out), c("a", "b", "cp", "vx", "vm", "vy"))
}

# Sufficient statistics per cluster: size, mean vector, within centered cross-products.
tl_stats <- function(data, cluster = "cluster") {
  z <- as.matrix(data[, tl_vars])
  g <- factor(data[[cluster]])
  lapply(split(seq_len(nrow(z)), g), function(i) {
    zc <- z[i, , drop = FALSE]
    zbar <- colMeans(zc)
    list(n = length(i), zbar = zbar, ssw = crossprod(sweep(zc, 2, zbar)))
  })
}

# Cluster-sum log-likelihood. `defect` plants a wrong likelihood for the positive controls:
#   "none"     the correct density
#   "nj_free"  the between term does not scale with the cluster size (S_W + S_B)
#   "no_mean"  the mean structure is dropped (mu fixed at 0)
tl_loglik <- function(stats, sw, sb, mu, defect = c("none", "nj_free", "no_mean")) {
  defect <- match.arg(defect)
  if (defect == "no_mean") mu <- rep(0, length(mu))
  p <- nrow(sw)
  ld_w <- as.numeric(determinant(sw, logarithm = TRUE)$modulus)
  sw_inv <- solve(sw)
  total <- 0
  for (s in stats) {
    v <- if (defect == "nj_free") sw + sb else sw + s$n * sb
    ld_v <- as.numeric(determinant(v, logarithm = TRUE)$modulus)
    d <- s$zbar - mu
    total <- total - 0.5 * (
      s$n * p * log(2 * pi) + (s$n - 1) * ld_w + ld_v +
        sum(sw_inv * s$ssw) + s$n * drop(crossprod(d, solve(v, d)))
    )
  }
  total
}

# The same likelihood from the unreduced density: stack each cluster's n_j p vector and use
# the full covariance I (x) S_W + J (x) S_B. Checks the reduction inside tl_loglik().
tl_loglik_stacked <- function(data, sw, sb, mu, cluster = "cluster") {
  z <- as.matrix(data[, tl_vars])
  total <- 0
  for (i in split(seq_len(nrow(z)), factor(data[[cluster]]))) {
    n <- length(i)
    full <- kronecker(diag(n), sw) + kronecker(matrix(1, n, n), sb)
    r <- as.vector(t(z[i, , drop = FALSE])) - rep(mu, n)
    ld_full <- as.numeric(determinant(full, logarithm = TRUE)$modulus)
    total <- total - 0.5 * (length(r) * log(2 * pi) + ld_full + drop(crossprod(r, solve(full, r))))
  }
  total
}

# Profile mean: GLS estimate of mu given S_W, S_B (the maximizer of tl_loglik() in mu).
tl_mu_hat <- function(stats, sw, sb) {
  info <- matrix(0, 3, 3)
  rhs <- numeric(3)
  for (s in stats) {
    w <- solve(sw + s$n * sb)
    info <- info + s$n * w
    rhs <- rhs + s$n * drop(w %*% s$zbar)
  }
  drop(solve(info, rhs))
}

# Balanced closed form (saturated model, equal cluster size n, S_B - S_W / n PSD): the ML
# estimates are the pooled within covariance S_PW and (S_B - S_PW) / n, where S_B is the
# between-cluster scatter of the cluster means (times n, divisor J as in ML).
tl_o8_closed_form <- function(data, cluster = "cluster") {
  st <- tl_stats(data, cluster)
  n <- unique(vapply(st, function(s) s$n, numeric(1)))
  stopifnot(length(n) == 1L)
  j <- length(st)
  s_pw <- Reduce(`+`, lapply(st, function(s) s$ssw)) / (j * (n - 1))
  zbar <- do.call(rbind, lapply(st, function(s) s$zbar))
  s_b <- n * stats::cov(zbar) * (j - 1) / j
  list(sw = s_pw, sb = (s_b - s_pw) / n, mu = colMeans(zbar), n = n, j = j)
}

# Maximize the hand likelihood over the 12 path/variance parameters (6 per level), the mean
# profiled out. Start: moment estimates, repaired to be positive definite. `defect` runs the
# same maximizer on a planted wrong likelihood.
tl_o8_fit <- function(data, cluster = "cluster", defect = "none") {
  st <- tl_stats(data, cluster)
  nj <- vapply(st, function(s) s$n, numeric(1))
  s_pw <- Reduce(`+`, lapply(st, function(s) s$ssw)) / (sum(nj) - length(nj))
  zbar <- do.call(rbind, lapply(st, function(s) s$zbar))
  ev <- eigen(stats::cov(zbar) - s_pw / mean(nj), symmetric = TRUE)
  s_b0 <- ev$vectors %*% diag(pmax(ev$values, 0.05)) %*% t(ev$vectors)
  dimnames(s_b0) <- list(tl_vars, tl_vars)
  start <- c(tl_paths(s_pw), tl_paths(s_b0))
  logi <- c(4:6, 10:12)
  start[logi] <- log(start[logi])
  unpack <- function(th) {
    th[logi] <- exp(th[logi])
    list(sw = do.call(tl_sigma, as.list(th[1:6])), sb = do.call(tl_sigma, as.list(th[7:12])))
  }
  mu_of <- function(s) if (defect == "no_mean") rep(0, 3) else tl_mu_hat(st, s$sw, s$sb)
  nll <- function(th) {
    out <- tryCatch(
      {
        s <- unpack(th)
        -tl_loglik(st, s$sw, s$sb, mu_of(s), defect = if (defect == "nj_free") "nj_free" else "none")
      },
      error = function(e) {
        # only a singular covariance (a wandering line search) is a "very bad point"; anything
        # else is a real bug and must surface
        if (!grepl("singular|not positive", conditionMessage(e))) stop(e)
        NA_real_
      }
    )
    if (is.finite(out)) out else 1e10
  }
  ctl <- list(maxit = 5000, reltol = 1e-15)
  opt <- stats::optim(start, nll, method = "BFGS", control = ctl)
  opt <- stats::optim(opt$par, nll, method = "BFGS", control = ctl)
  s <- unpack(opt$par)
  list(
    sw = s$sw, sb = s$sb, mu = mu_of(s), loglik = -opt$value,
    within = tl_paths(s$sw), between = tl_paths(s$sb), convergence = opt$convergence
  )
}

# Simulated clustered data from known within and between paths; `sizes` may be unbalanced.
tl_simulate <- function(sizes, seed, mu = c(1.5, -0.8, 2.2)) {
  withr::local_seed(seed) # restores the caller's RNG state, so later test files are unaffected
  sw <- tl_sigma(0.5, 0.4, 0.2, 1.0, 0.8, 0.9)
  sb <- tl_sigma(0.3, 0.6, 0.1, 0.7, 0.5, 0.6)
  cl <- rep(seq_along(sizes), sizes)
  u <- matrix(stats::rnorm(length(sizes) * 3), ncol = 3) %*% chol(sb)
  e <- matrix(stats::rnorm(length(cl) * 3), ncol = 3) %*% chol(sw)
  out <- data.frame(cluster = cl, sweep(u[cl, , drop = FALSE] + e, 2, mu, `+`))
  names(out)[2:4] <- tl_vars
  out
}

tl_data_balanced <- function() tl_simulate(rep(6, 40), seed = 11)
tl_data_unbalanced <- function() tl_simulate(rep(c(3, 5, 8, 12), 10), seed = 11)

tl_sym <- function(m) (m + t(m)) / 2

# --- lavaan side (used only by the test file; the likelihood above never calls lavaan) ---

tl_lavaan_model <- "
level: 1
  M ~ a_w*X
  Y ~ b_w*M + cp_w*X
level: 2
  M ~ a_b*X
  Y ~ b_b*M + cp_b*X
"
tl_path_names <- c("a_w", "b_w", "cp_w", "a_b", "b_b", "cp_b")

tl_fit_lavaan <- function(data) {
  suppressWarnings(lavaan::sem(tl_lavaan_model, data, cluster = "cluster", fixed.x = FALSE))
}

# lavaan's estimates unpacked to within and between covariance matrices and the mean vector.
# E[z] = (I - B_between)^-1 alpha_between, because every intercept lives at level 2.
tl_lavaan_to_hand <- function(fit) {
  pt <- lavaan::parameterEstimates(fit)
  get <- function(lhs, op, rhs, level) {
    pt$est[pt$lhs == lhs & pt$op == op & pt$rhs == rhs & pt$level == level]
  }
  sig <- function(level) {
    tl_sigma(
      get("M", "~", "X", level), get("Y", "~", "M", level), get("Y", "~", "X", level),
      vx = get("X", "~~", "X", level), vm = get("M", "~~", "M", level), vy = get("Y", "~~", "Y", level)
    )
  }
  b_mat <- matrix(0, 3, 3)
  b_mat[2, 1] <- get("M", "~", "X", 2)
  b_mat[3, 2] <- get("Y", "~", "M", 2)
  b_mat[3, 1] <- get("Y", "~", "X", 2)
  alpha <- c(get("X", "~1", "", 2), get("M", "~1", "", 2), get("Y", "~1", "", 2))
  list(sw = sig(1), sb = sig(2), mu = drop(solve(diag(3) - b_mat, alpha)))
}

# One expectation each, so a planted defect can be run through the same check with expect_failure().
tl_check_loglik <- function(hand, lav, tol = 1e-6) {
  testthat::expect_lt(abs(hand - lav) / abs(lav), tol)
}
tl_check_paths <- function(hand_fit, lav_fit) {
  pt <- lavaan::parameterEstimates(lav_fit)
  lab <- pt[pt$label %in% tl_path_names, ]
  lav_est <- stats::setNames(lab$est, lab$label)[tl_path_names]
  lav_se <- stats::setNames(lab$se, lab$label)[tl_path_names]
  hand_est <- c(
    a_w = hand_fit$within[["a"]], b_w = hand_fit$within[["b"]], cp_w = hand_fit$within[["cp"]],
    a_b = hand_fit$between[["a"]], b_b = hand_fit$between[["b"]], cp_b = hand_fit$between[["cp"]]
  )
  excess <- abs(hand_est - lav_est) - pmax(0.01 * lav_se, 1e-4)
  testthat::expect_lte(max(excess), 0, label = paste("worst path:", tl_path_names[which.max(excess)]))
}
