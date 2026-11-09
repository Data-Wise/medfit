# FI-G0c/G0d: the generic internals (.sem_fiml_prepare_core, evaluation, geometry, Hessian, solve) on a four-variable
# recursive model, checked against from-scratch references. This is an INTERNAL test of dimension-genericity only:
# no public entry accepts these tables, and the refusal boundary is tested in test-fiml-generic-kernel-oracle.R.

gk4_tables <- function() {
  a <- data.frame(
    row = c("M1", "M2", "Y", "Y"), col = c("X", "M1", "M2", "X"),
    label = c("a", "d", "b", "cp"), value = NA_real_
  )
  vars <- c("X", "M1", "M2", "Y")
  list(
    vars = vars, a = a,
    s = data.frame(row = vars, col = vars, label = paste0("v", 1:4), value = NA_real_),
    m = data.frame(row = vars, label = paste0("i", 1:4), value = NA_real_)
  )
}
gk4_data <- function(seed = 31L, n = 90L) {
  set.seed(seed)
  x <- .5 + stats::rnorm(n)
  m1 <- .2 + .6 * x + stats::rnorm(n, sd = .8)
  m2 <- -.3 + .5 * m1 + stats::rnorm(n, sd = .9)
  y <- .4 + .5 * m2 + .3 * x + stats::rnorm(n, sd = .7)
  d <- cbind(X = x, M1 = m1, M2 = m2, Y = y)
  d[stats::runif(n * 4) < .15] <- NA_real_
  d[c(7L, 50L), ] <- NA_real_
  d
}
gk4_theta <- function(seed) {
  set.seed(seed)
  base <- c(a = .4, d = .3, b = .5, cp = .2, v1 = 1.1, v2 = .8, v3 = .9, v4 = 1.2, i1 = .1, i2 = -.1, i3 = .05,
            i4 = .0)
  base + stats::runif(12, -.1, .1) * c(rep(1, 4), .5, .5, .5, .5, 1, 1, 1, 1)
}
gk4_moments <- function(theta, tables = gk4_tables()) {
  B <- matrix(0, 4, 4)
  B[cbind(match(tables$a$row, tables$vars), match(tables$a$col, tables$vars))] <- theta[tables$a$label]
  gk_implied(B, theta[tables$s$label], theta[tables$m$label])
}
gk4_original_nll <- function(d, theta) {
  m <- gk4_moments(theta)
  s <- gk_scale(d)
  gk_row_nll(d, list(mu = gk_center(d) + s * m$mu, sigma = diag(s) %*% m$sigma %*% diag(s)))
}
gk4_std_nll <- function(d, theta) gk_row_nll(gk_standardize(d), gk4_moments(theta))
# Recursive-regression inverse for any acyclic path table.
gk4_recover <- function(mom, tables = gk4_tables()) {
  out <- c()
  for (r in unique(tables$a$row)) {
    rows <- tables$a[tables$a$row == r, ]
    P <- match(rows$col, tables$vars)
    ri <- match(r, tables$vars)
    coef <- solve(mom$sigma[P, P, drop = FALSE], mom$sigma[P, ri])
    names(coef) <- rows$label
    out <- c(out, coef, stats::setNames(mom$sigma[ri, ri] - sum(coef * mom$sigma[P, ri]),
                                        tables$s$label[ri]))
    out <- c(out, stats::setNames(mom$mu[ri] - sum(coef * mom$mu[P]), tables$m$label[ri]))
  }
  roots <- setdiff(tables$vars, tables$a$row)
  for (r in roots) {
    ri <- match(r, tables$vars)
    out <- c(out, stats::setNames(mom$sigma[ri, ri], tables$s$label[ri]),
             stats::setNames(mom$mu[ri], tables$m$label[ri]))
  }
  out
}
gk_jac <- function(f, x) {
  do.call(cbind, lapply(seq_along(x), function(k) {
    fo_richardson(lapply(.02 / 2^(0:3), function(h) {
      e <- x * 0
      e[k] <- h
      (f(x + e) - f(x - e)) / (2 * h)
    }))
  }))
}
gk4_geometry <- function(d, theta) {
  z <- gk_standardize(d)
  nm <- names(theta)
  mom <- function(x) gk4_moments(stats::setNames(x, nm))
  dm <- gk_jac(function(x) mom(x)$mu, theta)
  ds <- gk_jac(function(x) as.vector(mom(x)$sigma), theta)
  S <- mom(theta)$sigma
  G <- matrix(0, length(theta), length(theta))
  for (ids in split(seq_len(nrow(z)), apply(!is.na(z), 1, paste0, collapse = ""))) {
    j <- which(!is.na(z[ids[1L], ]))
    if (!length(j)) next
    W <- solve(S[j, j, drop = FALSE])
    D <- lapply(seq_along(theta), function(k) matrix(ds[, k], 4L, 4L)[j, j, drop = FALSE])
    for (k in seq_along(theta)) for (l in seq_along(theta)) {
      G[k, l] <- G[k, l] + length(ids) * (sum(dm[j, k] * (W %*% dm[j, l])) + sum((W %*% D[[k]]) * t(W %*% D[[l]])) / 2)
    }
  }
  G
}

test_that("the generic kernel evaluates a four-variable recursive model against the rowwise reference", {
  d <- gk4_data()
  p <- .sem_fiml_prepare_core(d, gk4_tables())
  nm <- p$ram$par_names
  expect_identical(nm, c("a", "d", "b", "cp", paste0("v", 1:4), paste0("i", 1:4)))
  expect_identical(nm[.sem_fiml_variance_index(p$layout, nm)], paste0("v", 1:4))
  expect_identical(p$n, 88L)
  expect_identical(p$rows$empty, c(7L, 50L))
  expect_equal(p$jacobian, sum(colSums(!is.na(d)) * log(gk_scale(d))), tolerance = 1e-12)
  for (seed in 1:3) {
    th <- gk4_theta(seed)[nm]
    value <- .sem_fiml_eval(th, p)$value + p$jacobian
    expect_lt(abs(value - gk4_original_nll(d, th)), 1e-8)
    # transport against the moment-recovered original-scale parameters
    mom <- gk4_moments(th)
    s <- gk_scale(d)
    orig <- gk4_recover(list(mu = gk_center(d) + s * mom$mu, sigma = diag(s) %*% mom$sigma %*% diag(s)))
    expect_lt(max(abs(p$offset + as.vector(p$transport %*% th) - orig[nm])), 1e-9)
  }
  th <- gk4_theta(5L)[nm]
  reference <- gk_gradient(function(x) gk4_std_nll(d, stats::setNames(x, nm)), th)
  expect_lt(max(abs(.sem_fiml_eval(th, p)$gradient - reference)) / max(1, max(abs(reference))), 1e-6)
})

test_that("the generic geometry and Hessian match from-scratch references on four variables", {
  d <- gk4_data()
  p <- .sem_fiml_prepare_core(d, gk4_tables())
  th <- gk4_theta(6L)[p$ram$par_names]
  G <- .sem_fiml_geometry(th, p)
  Gref <- gk4_geometry(d, th)
  expect_lt(max(abs(G - Gref)) / max(abs(Gref)), 1e-6)
  H <- .sem_fiml_hessian(th, p)
  f <- function(x) gk4_std_nll(d, stats::setNames(x, names(th)))
  Href <- fo_hessian(function(q) f(q), th, .01)
  expect_lt(max(abs(H - Href)) / max(abs(Href)), 1e-3)
  expect_equal(H, t(H), tolerance = 1e-12)
})

test_that("the generic solver recovers the four-variable FIML estimates, matching lavaan where installed", {
  skip_if_not_installed("lavaan")
  d <- gk4_data()
  p <- .sem_fiml_prepare_core(d, gk4_tables())
  fit <- .sem_fiml_solve(p)
  expect_true(all(c("slsqp", "nlminb") %in% fit$attempts$solver[fit$attempts$accepted]))
  expect_equal(nrow(fit$attempts), 6L)
  ref <- suppressWarnings(lavaan::sem("M1 ~ X\nM2 ~ M1\nY ~ M2 + X", as.data.frame(d), missing = "ml",
                                      fixed.x = FALSE, meanstructure = TRUE, information = "observed",
                                      control = list(rel.tol = 1e-10)))
  q <- lavaan::coef(ref)
  map <- c(a = "M1~X", d = "M2~M1", b = "Y~M2", cp = "Y~X", v1 = "X~~X", v2 = "M1~~M1", v3 = "M2~~M2",
           v4 = "Y~~Y", i1 = "X~1", i2 = "M1~1", i3 = "M2~1", i4 = "Y~1")
  expect_setequal(names(q), unname(map))
  expect_lt(max(abs(fit$estimate[names(map)] - q[unname(map)])), 1e-5)
  expect_lt(abs(-fit$nll - as.numeric(lavaan::logLik(ref))), 1e-6)
  rv <- lavaan::vcov(ref)[unname(map), unname(map)]
  V <- fit$covariance[names(map), names(map)]
  expect_lt(max(abs(V - rv) / sqrt(outer(diag(rv), diag(rv)))), 1e-3)
})

test_that("the same-solver likelihood difference matches the reference, and four-variable defects are caught", {
  fx_skip_covr()
  d <- gk4_data()
  p <- .sem_fiml_prepare_core(d, gk4_tables())
  nm <- p$ram$par_names
  th <- gk4_theta(6L)[nm]
  anchor <- gk4_theta(7L)[nm]
  expect_equal(.sem_fiml_difference(th, anchor, p), gk4_std_nll(d, th) - gk4_std_nll(d, anchor), tolerance = 1e-9)
  diff_bad <- sem_mutate(.sem_fiml_difference, "g$n/2 * (logratio", "g$n * (logratio")
  expect_gt(abs(diff_bad(th, anchor, p) - (gk4_std_nll(d, th) - gk4_std_nll(d, anchor))), 1e-6)
  geo_bad <- sem_mutate(.sem_fiml_geometry, "g$n/2 * sum(D[[k]] * t(D[[l]]))", "g$n * sum(D[[k]] * t(D[[l]]))")
  expect_gt(max(abs(geo_bad(th, p) - gk4_geometry(d, th))) / max(abs(gk4_geometry(d, th))), 1e-3)
  # a dropped intercept transport (G0c step T) is visible on four variables too
  tr_bad <- sem_mutate(.sem_fiml_transport, "offset[i$par] <- center[i$var]", "offset[i$par] <- 0")
  pb <- testthat::with_mocked_bindings(.sem_fiml_prepare_core(d, gk4_tables()), .sem_fiml_transport = tr_bad)
  mom <- gk4_moments(th)
  s <- gk_scale(d)
  orig <- gk4_recover(list(mu = gk_center(d) + s * mom$mu, sigma = diag(s) %*% mom$sigma %*% diag(s)))
  expect_gt(max(abs(pb$offset + as.vector(pb$transport %*% th) - orig[nm])), 1e-3)
})
