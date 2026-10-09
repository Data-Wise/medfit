# Native SEM engine: RAM core (maximum likelihood discrepancy and analytic gradient)
#
# Internal. The discrepancy is the full ML function
#   F(theta) = log|Sigma| + tr(S Sigma^-1) - log|S| - p,
# with S the divisor-n sample covariance, so F equals 2 * lavaan's `fmin` and,
# with raw data and saturated means, -2 log L differences equal n * (F_null - F_full).
# Sigma = F (I - A)^-1 S_ram (I - A)^-T F' is the model-implied covariance of
# the observed variables in RAM form.
#
# A non-positive-definite Sigma (smallest eigenvalue at most 1e-10) returns the
# finite sentinel 1e10 and a zero gradient, never an error, so nloptr can step
# back from an invalid point.

.sem_sentinel <- 1e10
.sem_pd_floor <- 1e-10

# Build the index vectors for one RAM model.
#
# `a` and `s` are data frames with columns `row`, `col` (variable names),
# `label` ("" for none) and `value` (NA = free parameter). For `a`, `row` is the
# target and `col` the source of a one-headed path; for `s` the pair is a
# symmetric (co)variance and may be given in either order. Free entries with
# the same non-empty label share one parameter.
.sem_ram <- function(vars, obs, a, s) {
  checkmate::assert_character(vars, any.missing = FALSE, unique = TRUE, min.len = 1, .var.name = "vars")
  checkmate::assert_subset(obs, vars, empty.ok = FALSE, .var.name = "obs")
  nv <- length(vars)
  idx <- function(v) {
    i <- match(v, vars)
    if (anyNA(i)) {
      stop("unknown variable ", paste(unique(v[is.na(i)]), collapse = ", "), " in the RAM specification", call. = FALSE)
    }
    i
  }
  a_row <- idx(a$row)
  a_col <- idx(a$col)
  s_row <- idx(s$row)
  s_col <- idx(s$col)
  pos_a <- (a_col - 1L) * nv + a_row
  pos_s <- (s_col - 1L) * nv + s_row
  pos_s2 <- (s_row - 1L) * nv + s_col
  if (anyDuplicated(pos_a)) stop("a path appears twice in the RAM specification", call. = FALSE)
  if (anyDuplicated(pmin(pos_s, pos_s2))) stop("a (co)variance appears twice in the RAM specification", call. = FALSE)

  label <- c(a$label, s$label)
  value <- c(a$value, s$value)
  free <- is.na(value)
  default_name <- c(paste0(a$row, " ~ ", a$col), paste0(s$row, " ~~ ", s$col))
  key <- ifelse(nzchar(label), label, default_name)
  par_names <- unique(key[free])
  k <- ifelse(free, match(key, par_names), NA_integer_)
  q <- length(par_names)
  na <- nrow(a)
  ns <- nrow(s)
  k_a <- k[seq_len(na)]
  k_s <- k[na + seq_len(ns)]
  free_a <- free[seq_len(na)]
  free_s <- free[na + seq_len(ns)]
  v_a <- value[seq_len(na)]
  v_s <- value[na + seq_len(ns)]

  a0 <- matrix(0, nv, nv)
  a0[pos_a[!free_a]] <- v_a[!free_a]
  s0 <- matrix(0, nv, nv)
  s0[pos_s[!free_s]] <- v_s[!free_s]
  s0[pos_s2[!free_s]] <- v_s[!free_s]

  # Gradient map: free entry -> parameter index, so equal labels accumulate.
  n_fa <- sum(free_a)
  n_fs <- sum(free_s)
  gmap <- matrix(0, q, n_fa + n_fs)
  gmap[cbind(k_a[free_a], seq_len(n_fa))] <- 1
  gmap[cbind(k_s[free_s], n_fa + seq_len(n_fs))] <- 1

  list(
    vars = vars, obs = vars[match(obs, vars)], obs_idx = match(obs, vars), nv = nv, q = q,
    par_names = par_names,
    a0 = a0, s0 = s0, eye = diag(nv),
    pos_a = pos_a[free_a], k_a = k_a[free_a],
    pos_s = pos_s[free_s], pos_s2 = pos_s2[free_s], k_s = k_s[free_s],
    s_weight = ifelse(s_row[free_s] == s_col[free_s], 1, 2),
    gmap = gmap
  )
}

# Sample covariance object: divisor-n covariance of the observed variables, in
# the order of `ram$obs`, with its log determinant.
.sem_sample <- function(data, ram) {
  checkmate::assert_data_frame(data, min.rows = 1, .var.name = "data")
  checkmate::assert_subset(ram$obs, names(data), .var.name = "obs")
  x <- as.matrix(data[, ram$obs, drop = FALSE])
  if (anyNA(x)) {
    stop("data has missing values in the observed variables; remove incomplete rows first", call. = FALSE)
  }
  n <- nrow(x)
  p <- ncol(x)
  s_mat <- stats::cov(x) * (n - 1) / n
  ld <- if (n > p) .sem_logdet(s_mat) else NA_real_
  if (is.na(ld)) {
    stop(sprintf("sample covariance matrix is singular (n = %d, p = %d)", n, p), call. = FALSE)
  }
  list(s = s_mat, n = n, p = p, logdet = ld)
}

# log|M| for a symmetric positive-definite matrix, NA if not positive definite.
.sem_logdet <- function(m) {
  ch <- tryCatch(chol(m), error = function(e) NULL)
  if (is.null(ch)) NA_real_ else 2 * sum(log(diag(ch)))
}

# A and S_ram for a parameter vector.
.sem_ram_mats <- function(ram, theta) {
  a <- ram$a0
  a[ram$pos_a] <- theta[ram$k_a]
  s <- ram$s0
  s[ram$pos_s] <- theta[ram$k_s]
  s[ram$pos_s2] <- theta[ram$k_s]
  list(a = a, s = s)
}

# Model-implied covariance of the observed variables.
.sem_implied <- function(ram, theta) {
  m <- .sem_ram_mats(ram, theta)
  b <- solve(ram$eye - m$a)
  sigma <- (b %*% m$s %*% t(b))[ram$obs_idx, ram$obs_idx, drop = FALSE]
  sigma <- (sigma + t(sigma)) / 2
  dimnames(sigma) <- list(ram$obs, ram$obs)
  sigma
}

# Shared worker: discrepancy and, when asked, the gradient. Returns NULL when
# the implied covariance is not usable (singular I - A, non-finite, or not
# positive definite), which the wrappers turn into the sentinel.
.sem_eval <- function(theta, ram, smp, deriv) {
  m <- .sem_ram_mats(ram, theta)
  b <- tryCatch(solve(ram$eye - m$a), error = function(e) NULL)
  if (is.null(b)) return(NULL)
  bs <- b %*% m$s
  sigma <- (bs %*% t(b))[ram$obs_idx, ram$obs_idx, drop = FALSE]
  sigma <- (sigma + t(sigma)) / 2
  if (!all(is.finite(sigma))) return(NULL)
  if (min(eigen(sigma, symmetric = TRUE, only.values = TRUE)$values) <= .sem_pd_floor) return(NULL)
  ch <- chol(sigma)
  sigma_inv <- chol2inv(ch)
  f <- 2 * sum(log(diag(ch))) + sum(smp$s * sigma_inv) - smp$logdet - smp$p
  out <- list(f = f)
  if (deriv) {
    w <- sigma_inv - sigma_inv %*% smp$s %*% sigma_inv
    pm <- matrix(0, ram$nv, ram$nv)
    pm[ram$obs_idx, ram$obs_idx] <- w
    g_a <- 2 * t(bs %*% t(b) %*% pm %*% b)
    g_s <- crossprod(b, pm %*% b)
    vals <- c(g_a[ram$pos_a], ram$s_weight * g_s[ram$pos_s])
    out$g <- as.vector(ram$gmap %*% vals)
  }
  out
}

# ML discrepancy F(theta); the sentinel 1e10 for an unusable implied covariance.
.sem_fml <- function(theta, ram, smp) {
  r <- .sem_eval(theta, ram, smp, deriv = FALSE)
  if (is.null(r)) .sem_sentinel else r$f
}

# Analytic gradient of F; zeros (finite) where F is the sentinel, never an error.
.sem_grad <- function(theta, ram, smp) {
  r <- .sem_eval(theta, ram, smp, deriv = TRUE)
  if (is.null(r)) numeric(ram$q) else r$g
}
