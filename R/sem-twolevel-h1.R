# The unrestricted (h1, saturated) two-level ICC for the native route.
#
# The within-only identification rule reads an intraclass correlation per variable. The lavaan route takes it from
# `lavaan::lavInspect(fit, "icc")`, lavaan's saturated (h1) estimate; the native route has no lavaan, so this file
# estimates the same quantity from the per-size sufficient statistics the native likelihood uses
# (`.sem_sample_ml2()`). The h1 model puts no structure on the moments: Sigma_W over the within set W, Sigma_B and
# mu_B over W then the between-only set Z, with the same cluster likelihood as `.sem_loglik_ml2()`.
#
# Estimator: EM with the cluster effect b_j = (u_Wj, u_Zj) + mu_B as the latent variable. Given the cluster vector
# c_j = (ybar_j, z_j) = b_j + (e-bar_j, 0), with V_n = Sigma_B + diag(Sigma_W / n, 0) for a cluster of size n:
#   E: m_j = mu_B + Sigma_B V_n^-1 (c_j - mu_B),  C_n = Sigma_B - Sigma_B V_n^-1 Sigma_B
#   M: mu_B = mean_j m_j,  Sigma_B = mean_j [(m_j - mu_B)(m_j - mu_B)' + C_n],
#      Sigma_W = (1 / N) sum_j [SSW_j + n_j ((ybar_j - m_Wj)(ybar_j - m_Wj)' + C_n[W, W])].
# EM keeps Sigma_B and Sigma_W positive definite and raises the log-likelihood every step, so it converges to the
# unrestricted maximum (a boundary maximum, a zero level-2 variance, only in the limit). That is the maximum
# lavaan's EM (`lav_mvn_cl_em_sat()`, identity start) approaches; lavaan stops when its step criterion drops below
# `em.h1.args$tol` (1e-4 by default), so the two ICCs agree to the size of that stopping rule (about 1e-4 in the
# interior, a few 1e-3 or more near a zero level-2 variance), not to machine precision. Tightening lavaan's `tol` to
# 1e-10 brings the gap to about 1e-5.
# The closed form for balanced clusters (Sigma_W = SSW / (N - J), Sigma_B = S_B - Sigma_W / n) is the same maximum
# whenever that Sigma_B is positive definite; it is not used here because it gives an indefinite Sigma_B (a negative
# ICC) exactly where the unrestricted maximum sits on the boundary.

# One EM step from (sigma_w, sigma_b, mu_b) over W then Z; `smp` is a `.sem_sample_ml2()` list. NULL when some
# V_n is not positive definite.
.sem_h1_em_step <- function(smp, sigma_w, sigma_b, mu_b) {
  w_idx <- seq_len(smp$p_w)
  p_b <- nrow(sigma_b)
  sum_m <- numeric(p_b)
  sum_mm <- matrix(0, p_b, p_b)
  sum_w <- matrix(0, smp$p_w, smp$p_w)
  for (s in smp$sizes) {
    v <- .sem_ml2_between_cov(sigma_b, sigma_w, s$n, w_idx)
    v <- (v + t(v)) / 2
    if (!.sem_sigma_pd(v)) return(NULL)
    gain <- sigma_b %*% chol2inv(chol(v))
    post_cov <- sigma_b - gain %*% sigma_b
    post_cov <- (post_cov + t(post_cov)) / 2
    dev <- sweep(s$c, 2L, mu_b)
    m <- sweep(dev %*% t(gain), 2L, mu_b, "+")
    sum_m <- sum_m + colSums(m)
    sum_mm <- sum_mm + crossprod(m) + s$count * post_cov
    resid <- s$c[, w_idx, drop = FALSE] - m[, w_idx, drop = FALSE]
    sum_w <- sum_w + s$ssw + s$n * (crossprod(resid) + s$count * post_cov[w_idx, w_idx, drop = FALSE])
  }
  mu_new <- sum_m / smp$j
  sb_new <- sum_mm / smp$j - tcrossprod(mu_new)
  sw_new <- sum_w / smp$n
  list(sigma_w = (sw_new + t(sw_new)) / 2, sigma_b = (sb_new + t(sb_new)) / 2, mu_b = mu_new)
}

# The unrestricted two-level moments by EM (SQUAREM-accelerated): `sigma_w` (W x W), `sigma_b` and `mu_b` (W then Z),
# named by variable, plus `converged` and `iter`. Convergence: the largest change of a plain EM step in any moment is
# below `tol` relative to the largest variance. Start: the pooled within covariance and half the covariance of the
# cluster vectors (a diagonal one when there are not more clusters than between-level variables). NULL when the start
# or an EM step is not positive definite (a perfectly collinear pair, or a Sigma_B that collapses).
.sem_twolevel_h1_moments <- function(smp, tol = 1e-9, max_iter = 20000L) {
  checkmate::assert_number(tol, lower = 0, finite = TRUE, .var.name = "tol")
  checkmate::assert_count(max_iter, positive = TRUE, .var.name = "max_iter")
  b <- c(smp$within, smp$between)
  p_b <- length(b)
  cm <- do.call(rbind, lapply(smp$sizes, `[[`, "c"))
  ssw <- Reduce(`+`, lapply(smp$sizes, `[[`, "ssw"))
  sigma_w <- ssw / max(smp$n - smp$j, 1)
  sigma_b <- if (nrow(cm) > p_b) {
    stats::cov(cm) * (nrow(cm) - 1) / nrow(cm)
  } else {
    diag(apply(cm, 2L, stats::var), p_b)
  }
  sigma_b <- sigma_b / 2
  mu_b <- colMeans(cm)
  if (!.sem_sigma_pd(sigma_w) || !.sem_sigma_pd(sigma_b)) return(NULL)
  scale <- max(diag(sigma_w), diag(sigma_b))
  p_w <- smp$p_w
  n_w <- p_w * p_w
  n_b <- p_b * p_b
  pack <- function(sw, sb, mu) c(sw, sb, mu)
  unpack <- function(th) {
    list(sigma_w = matrix(th[seq_len(n_w)], p_w, p_w), sigma_b = matrix(th[n_w + seq_len(n_b)], p_b, p_b),
         mu_b = th[n_w + n_b + seq_len(p_b)])
  }
  # One EM map on the packed vector; NULL when the point or its image is not positive definite.
  em_map <- function(th) {
    u <- unpack(th)
    nxt <- .sem_h1_em_step(smp, u$sigma_w, u$sigma_b, u$mu_b)
    if (is.null(nxt) || !.sem_sigma_pd(nxt$sigma_w) || !.sem_sigma_pd(nxt$sigma_b)) return(NULL)
    pack(nxt$sigma_w, nxt$sigma_b, nxt$mu_b)
  }
  loglik <- function(th) {
    u <- unpack(th)
    .sem_loglik_ml2(smp, u$sigma_w, u$sigma_b, u$mu_b)
  }
  # SQUAREM (Varadhan and Roland 2008, scheme S3) around the EM map: extrapolate along the two plain steps and keep
  # the extrapolated point only when it is positive definite and does not lower the log-likelihood; otherwise the
  # second plain step is used, so every iterate is an EM iterate or a safeguarded improvement. Plain EM crawls near a
  # zero level-2 variance (the boundary maximum), where the within-only call is decided.
  theta <- pack(sigma_w, sigma_b, mu_b)
  converged <- FALSE
  iter <- 0L
  while (iter < max_iter) {
    iter <- iter + 1L
    th1 <- em_map(theta)
    if (is.null(th1)) return(NULL)
    th2 <- em_map(th1)
    if (is.null(th2)) return(NULL)
    r <- th1 - theta
    v <- th2 - th1 - r
    nxt <- th2
    if (sqrt(sum(v^2)) > 0) {
      alpha <- -max(sqrt(sum(r^2)) / sqrt(sum(v^2)), 1)
      cand <- em_map(theta - 2 * alpha * r + alpha^2 * v)
      if (!is.null(cand)) {
        ll_cand <- loglik(cand)
        ll_plain <- loglik(th2)
        if (!is.null(ll_cand) && !is.null(ll_plain) && ll_cand >= ll_plain) nxt <- cand
      }
    }
    change <- max(abs(th2 - th1)) / scale
    theta <- nxt
    if (change < tol) {
      converged <- TRUE
      break
    }
  }
  u <- unpack(theta)
  sigma_w <- (u$sigma_w + t(u$sigma_w)) / 2
  sigma_b <- (u$sigma_b + t(u$sigma_b)) / 2
  mu_b <- u$mu_b
  dimnames(sigma_w) <- list(smp$within, smp$within)
  dimnames(sigma_b) <- list(b, b)
  list(sigma_w = sigma_w, sigma_b = sigma_b, mu_b = stats::setNames(mu_b, b), converged = converged, iter = iter)
}

# ICC per variable of a native two-level `SEMFit` from the unrestricted (h1) moments of its own data: the rows the
# fit used (`@data`, the model variables) and their cluster ids, the same summaries the likelihood reads. A variable
# only at level 2 (Z) has ICC 1. When EM cannot produce a positive definite estimate, the model-implied ICC is used
# with a warning (the lavaan route's fallback when lavaan has no h1 estimate).
.sem_twolevel_h1_icc <- function(object) {
  ram <- object@internals$ram
  cluster <- object@internals$cluster
  dat <- object@data
  dat[[cluster]] <- object@internals$cluster_ids
  smp <- .sem_sample_ml2(dat, list(within = ram$within, between = ram$between), cluster)
  h1 <- .sem_twolevel_h1_moments(smp)
  if (is.null(h1)) {
    .twolevel_warn(
      paste0("The unrestricted (h1) ICC could not be estimated from these data (too few clusters for the ",
             "between-level variables, or collinear variables); the within-only rule uses the model-implied ",
             "ICC instead."),
      "medfit_warning_twolevel_icc_h1_unavailable"
    )
    mom <- .sem_twolevel_implied(ram, unname(object@theta))
    return(.sem_twolevel_icc(mom$sigma_w, mom$sigma_b))
  }
  .sem_twolevel_icc(h1$sigma_w, h1$sigma_b)
}
