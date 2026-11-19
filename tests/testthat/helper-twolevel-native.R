# Oracles for the native two-level likelihood (S4a.2, planning/PLAN-S4a-native-twolevel-core-2026-11-18.md). Each is
# written from the density directly, not through the per-size code in R/sem-ml.R:
#   - tln_stacked(): the unreduced multivariate normal density of each cluster's stacked vector
#     (y_j1, ..., y_jn, z_j), covariance written out entry by entry; handles a between-only covariate Z (the O8
#     stacked check in helper-twolevel-likelihood.R has no Z).
#   - tln_balanced_closed(): the balanced closed form from the pooled-within / between decomposition (one cluster
#     size, the within cross-products of the data centered at the cluster means, the between cross-products of the
#     cluster mean vectors about mu).
# Moments are given as sw (over W), sb and mu (over W then Z), named by variable.

# A cluster-only covariate Z on the O8 data: Z is the cluster mean of X (centered) plus noise, so its between
# covariance with X is clearly nonzero.
tln_add_z <- function(data, seed = 5) {
  withr::local_seed(seed)
  cl <- data$cluster
  xbar <- tapply(data$X, cl, mean)
  zb <- 0.8 * (xbar - mean(data$X)) + stats::rnorm(length(xbar), sd = 0.6)
  data$Z <- unname(zb[as.character(cl)])
  data
}
tln_data_z <- function() tln_add_z(tl_data_unbalanced())
tln_data_z_balanced <- function() tln_add_z(tl_data_balanced())

tln_model_z <- function(mz = "M ~ X + Z") {
  paste0("level: 1\n  M ~ X\n  Y ~ M + X\nlevel: 2\n  ", mz, "\n  Y ~ M + X\n")
}

# lavaan with the TL-3 convention (fixed.x = FALSE, observed information, structured h1 information).
tln_fit_lavaan <- function(model, data) {
  suppressWarnings(lavaan::sem(model, data, cluster = "cluster", fixed.x = FALSE, information = "observed",
                               h1.information = "structured"))
}

# lavaan's implied moments, keyed by name: sw over W, sb and mu over W then Z.
tln_lavaan_moments <- function(fit, w, z = character()) {
  imp <- lavaan::lavInspect(fit, "implied")
  b <- c(w, z)
  list(sw = imp[[1]]$cov[w, w, drop = FALSE], sb = imp[[2]]$cov[b, b, drop = FALSE], mu = imp[[2]]$mean[b])
}

# Unreduced density: per cluster the stacked vector (y_j1', ..., y_jn', z_j') with
#   Cov(y_ji, y_jk) = Sigma_B,WW + [i == k] Sigma_W,  Cov(y_ji, z_j) = Sigma_B,WZ,  Var(z_j) = Sigma_B,ZZ.
tln_stacked <- function(data, w, z, sw, sb, mu, cluster = "cluster") {
  pw <- length(w)
  pz <- length(z)
  total <- 0
  for (i in split(seq_len(nrow(data)), factor(data[[cluster]]))) {
    n <- length(i)
    dim_j <- n * pw + pz
    full <- matrix(0, dim_j, dim_j)
    for (r in seq_len(n)) {
      for (s in seq_len(n)) {
        blk <- sb[w, w, drop = FALSE] + (if (r == s) sw else 0)
        full[(r - 1) * pw + seq_len(pw), (s - 1) * pw + seq_len(pw)] <- blk
      }
      if (pz) {
        full[(r - 1) * pw + seq_len(pw), n * pw + seq_len(pz)] <- sb[w, z, drop = FALSE]
        full[n * pw + seq_len(pz), (r - 1) * pw + seq_len(pw)] <- sb[z, w, drop = FALSE]
      }
    }
    if (pz) full[n * pw + seq_len(pz), n * pw + seq_len(pz)] <- sb[z, z, drop = FALSE]
    obs <- c(as.vector(t(as.matrix(data[i, w, drop = FALSE]))), if (pz) unlist(data[i[1], z]))
    r_vec <- obs - c(rep(mu[w], n), mu[z])
    ld <- as.numeric(determinant(full, logarithm = TRUE)$modulus)
    total <- total - 0.5 * (dim_j * log(2 * pi) + ld + drop(crossprod(r_vec, solve(full, r_vec))))
  }
  total
}

# Balanced closed form (every cluster of size n): with SPW the pooled within cross-products and SSB the between
# cross-products of the cluster vectors (ybar_j, z_j) about mu, and V = Sigma_B + diag(Sigma_W / n, 0),
#   log L = -1/2 [ J (n p_w + p_z) log 2 pi + J (n - 1) log|Sigma_W| + tr(Sigma_W^-1 SPW)
#                  + J p_w log n + J log|V| + tr(V^-1 SSB) ].
tln_balanced_closed <- function(data, w, z, sw, sb, mu, cluster = "cluster") {
  g <- data[[cluster]]
  sizes <- table(g)
  stopifnot(length(unique(sizes)) == 1L)
  n <- as.numeric(sizes[1])
  big_j <- length(sizes)
  pw <- length(w)
  pz <- length(z)
  y <- as.matrix(data[, w, drop = FALSE])
  ybar <- apply(y, 2, function(col) stats::ave(col, g))
  spw <- crossprod(y - ybar)
  first <- !duplicated(g)
  cvec <- cbind(ybar[first, , drop = FALSE], as.matrix(data[first, z, drop = FALSE]))
  dev <- sweep(cvec, 2, mu[c(w, z)])
  ssb <- crossprod(dev)
  v <- sb[c(w, z), c(w, z)]
  v[w, w] <- v[w, w] + sw / n
  ld <- function(m) as.numeric(determinant(m, logarithm = TRUE)$modulus)
  -0.5 * (big_j * (n * pw + pz) * log(2 * pi) + big_j * (n - 1) * ld(sw) + sum(solve(sw) * spw) +
            big_j * pw * log(n) + big_j * ld(v) + sum(solve(v) * ssb))
}

# One expectation each, so a planted defect runs through the same check under expect_failure().
tln_check_rel <- function(native, ref, tol) testthat::expect_lt(abs(native - ref) / abs(ref), tol)
tln_check_abs <- function(native, ref, tol) testthat::expect_lt(abs(native - ref), tol)

# The parsed model, its W/Z sets, the theta map and the per-size statistics, as fit_sem() will build them.
tln_setup <- function(model, data) {
  parsed <- .sem_resolve_levels(.sem_parse(model), "cluster") # nolint: object_usage_linter.
  sets <- .sem_twolevel_sets(parsed, data, "cluster") # nolint: object_usage_linter.
  list(sets = sets, tl = .sem_twolevel_ram(parsed, sets), # nolint: object_usage_linter.
       smp = .sem_sample_ml2(data, sets, "cluster")) # nolint: object_usage_linter.
}

# Native log-likelihood at given moments.
tln_native <- function(smp, m) .sem_loglik_ml2(smp, m$sw, m$sb, m$mu) # nolint: object_usage_linter.
