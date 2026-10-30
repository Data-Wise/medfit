# Research only: algebra and source-provenance probes, not native SEM tests.
# Run from this worktree; optional argument is an extracted lavaan source tree.
out_dir <- "planning/studies/fiml-feasibility"
vars <- c("X", "M", "Y")
for (e in parse(file.path(out_dir, "study.R"))) {
  if (is.call(e) && identical(e[[1]], as.name("<-")) && is.call(e[[3]]) &&
      identical(e[[3]][[1]], as.name("function"))) eval(e)
}
gradient_pattern <- function(q, groups, direct) {
  m <- moments(q, direct)
  dm <- numDeriv::jacobian(function(q) moments(q, direct)$mu, q)
  ds <- numDeriv::jacobian(function(q) as.vector(moments(q, direct)$sigma), q)
  ans <- numeric(length(q))
  for (g in groups) {
    j <- g$cols
    if (!length(j)) next
    z <- sweep(g$y, 2, m$mu[j])
    W <- solve(m$sigma[j, j, drop = FALSE])
    T <- crossprod(z) / nrow(z)
    B <- W - W %*% T %*% W
    for (k in seq_along(q)) {
      dS <- matrix(ds[, k], 3)[j, j, drop = FALSE]
      ans[k] <- ans[k] + nrow(z) *
        (sum(B * dS) / 2 - sum(dm[j, k] * (W %*% colMeans(z))))
    }
  }
  ans
}
expected_pattern <- function(q, groups, direct) {
  m <- moments(q, direct)
  dm <- numDeriv::jacobian(function(q) moments(q, direct)$mu, q)
  ds <- numDeriv::jacobian(function(q) as.vector(moments(q, direct)$sigma), q)
  ans <- matrix(0, length(q), length(q))
  for (g in groups) {
    j <- g$cols
    if (!length(j)) next
    W <- solve(m$sigma[j, j, drop = FALSE])
    D <- lapply(seq_along(q), function(k) W %*% matrix(ds[, k], 3)[j, j, drop = FALSE])
    mean_part <- crossprod(dm[j, , drop = FALSE], W %*% dm[j, , drop = FALSE])
    for (k in seq_along(q)) for (l in seq_along(q)) {
      ans[k, l] <- ans[k, l] + length(g$ids) *
        (mean_part[k, l] + sum(D[[k]] * t(D[[l]])) / 2)
    }
  }
  ans
}
moment_vector <- function(q, direct) {
  m <- moments(q, direct)
  c(m$mu, m$sigma[lower.tri(m$sigma, diag = TRUE)])
}
moment_nll <- function(s, groups) {
  S <- matrix(0, 3, 3)
  S[lower.tri(S, diag = TRUE)] <- s[-(1:3)]
  S <- S + t(S) - diag(diag(S))
  sum(vapply(groups, function(g) {
    j <- g$cols
    if (!length(j)) return(0)
    z <- sweep(g$y, 2, s[j])
    V <- S[j, j, drop = FALSE]
    (length(g$ids) * (length(j) * log(2 * pi) + as.numeric(determinant(V)$modulus)) +
       sum(z * t(solve(V, t(z))))) / 2
  }, numeric(1)))
}
rows <- list()
for (mask in c("complete", "nonmonotone_mcar", "mar_observed_x")) {
  direct <- FALSE
  dat <- generate(271L, mask, direct)
  r <- reference(dat, direct)
  fit <- lavaan_fit(dat, direct)
  E <- lavaan::lavInspect(fit, "information.expected")
  labs <- names(r$estimates)
  stopifnot(setequal(labs, colnames(E)), !anyDuplicated(colnames(E)))
  J <- numDeriv::jacobian(function(q) structural(q, direct), r$q)
  E_lav <- r$n * crossprod(J, E[labs, labs] %*% J)
  E_own <- expected_pattern(r$q, r$groups, direct)
  expected_gap <- max(abs(E_lav - E_own)) / max(abs(E_own))
  for (at_fit in c(TRUE, FALSE)) {
    q <- r$q + if (at_fit) 0 else .1 * sin(seq_along(r$q))
    g <- gradient_pattern(q, r$groups, direct)
    # Center perturbations at zero so nearly zero means do not induce tiny steps.
    gn <- numDeriv::grad(function(delta) nll(q + delta, r$groups, direct), rep(0, length(q)))
    gradient_gap <- max(abs(g - gn)) / max(1, max(abs(gn)))
    H <- numDeriv::hessian(function(q) nll(q, r$groups, direct), q)
    D <- numDeriv::jacobian(function(q) moment_vector(q, direct), q)
    Hs <- numDeriv::hessian(function(s) moment_nll(s, r$groups), moment_vector(q, direct))
    naive <- crossprod(D, Hs %*% D)
    curvature_gap <- max(abs(H - naive)) / max(abs(H))
    stopifnot(gradient_gap < 1e-6, expected_gap < 1e-5)
    rows[[length(rows) + 1L]] <- data.frame(mask = mask, at_fit = at_fit,
      gradient_relative = gradient_gap, expected_matrix_relative = expected_gap,
      omitted_mapping_curvature_relative = curvature_gap)
  }
}
result <- do.call(rbind, rows)
stopifnot(any(result$omitted_mapping_curvature_relative[!result$at_fit] > 1e-3))
utils::write.csv(result, file.path(out_dir, "numerical-probes.csv"), row.names = FALSE)
print(result, row.names = FALSE)

source_root <- commandArgs(trailingOnly = TRUE)
if (length(source_root)) {
  wanted <- c("lav_mvn_mi_loglik_samp", "lav_samp_mi_patterns",
    "lav_mvn_mi_dlogl_dmu_samp", "lav_mvn_mi_dlogl_dsigma_samp",
    "lav_mvn_mi_info_expected", "lav_mvn_mi_pattern_inv", "lav_model_objective_fiml",
    "lav_model_hessian", "lav_model_info_observed", "lav_model_vcov",
    "lav_data_mi_patterns", "lav_model_est")
  records <- list()
  for (f in list.files(file.path(source_root[1], "R"), full.names = TRUE)) {
    for (e in parse(f, keep.source = FALSE)) {
      if (!is.call(e) || !identical(e[[1]], as.name("<-")) || !is.symbol(e[[2]]) ||
          !as.character(e[[2]]) %in% wanted || !is.call(e[[3]]) ||
          !identical(e[[3]][[1]], as.name("function"))) next
      name <- as.character(e[[2]])
      fun <- eval(e[[3]])
      installed <- get(name, asNamespace("lavaan"))
      records[[name]] <- data.frame(function_name = name, source_file = basename(f),
        installed_match = identical(formals(fun), formals(installed)) &&
          identical(body(fun), body(installed)))
    }
  }
  provenance <- do.call(rbind, records)
  stopifnot(nrow(provenance) == length(wanted), all(provenance$installed_match))
  utils::write.csv(provenance, file.path(out_dir, "source-functions.csv"), row.names = FALSE)
  cat("Installed/source function matches:", nrow(provenance), "\n")
}
