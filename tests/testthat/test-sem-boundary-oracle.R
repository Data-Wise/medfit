# Fixed measurement errors make the GLS indicator score sufficient for the
# structural likelihood. The remaining indicator contrasts have a known,
# parameter-independent density. This finite reference search certifies only
# these fixtures, not global convergence for arbitrary latent models.
boundary_model <- "
  xi =~ 1*x1 + 0.8*x2 + 1.2*x3
  x1 ~~ 0.4*x1
  x2 ~~ 0.5*x2
  x3 ~~ 0.6*x3
  M ~ a*xi
  Y ~ b*M + cp*xi
  xi ~~ s*xi
  M ~~ u*M
  Y ~~ lower(0)*Y
"
boundary_loading <- c(1, 0.8, 1.2)
boundary_noise <- c(0.4, 0.5, 0.6)
boundary_tau <- 1 / sum(boundary_loading^2 / boundary_noise)

boundary_data <- function(seed, variance) {
  withr::with_seed(seed, {
    z <- matrix(stats::rnorm(400 * 6), 400, 6)
    xi <- z[, 1]
    mediator <- 0.6 * xi + sqrt(0.7) * z[, 2]
    outcome <- 0.5 * mediator + 0.2 * xi + sqrt(variance) * z[, 3]
    indicators <- outer(xi, boundary_loading) + sweep(z[, 4:6], 2, sqrt(boundary_noise), "*")
    data.frame(x1 = indicators[, 1], x2 = indicators[, 2], x3 = indicators[, 3], M = mediator, Y = outcome)
  })
}

boundary_covariance <- function(theta) {
  s <- theta[["s"]]
  a <- theta[["a"]]
  b <- theta[["b"]]
  total <- theta[["cp"]] + a * b
  u <- theta[["u"]]
  v <- theta[["Y~~Y"]]
  matrix(c(s + boundary_tau, a * s, total * s,
           a * s, a^2 * s + u, a * total * s + b * u,
           total * s, a * total * s + b * u, total^2 * s + b^2 * u + v), 3)
}

boundary_loss <- function(theta, sample_cov) {
  root <- tryCatch(chol(boundary_covariance(theta)), error = function(e) NULL)
  if (is.null(root)) return(1e10)
  2 * sum(log(diag(root))) + sum(sample_cov * t(chol2inv(root))) -
    as.numeric(determinant(sample_cov, logarithm = TRUE)$modulus) - 3
}

boundary_full_loss <- function(theta, sample_cov) {
  s <- theta[["s"]]
  a <- theta[["a"]]
  total <- theta[["cp"]] + a * theta[["b"]]
  reduced <- boundary_covariance(theta)
  sigma <- rbind(cbind(s * outer(boundary_loading, boundary_loading) + diag(boundary_noise),
                       boundary_loading * a * s, boundary_loading * total * s),
                 c(boundary_loading * a * s, reduced[2, 2:3]),
                 c(boundary_loading * total * s, reduced[3, 2:3]))
  root <- chol(sigma)
  2 * sum(log(diag(root))) + sum(sample_cov * t(chol2inv(root))) -
    as.numeric(determinant(sample_cov, logarithm = TRUE)$modulus) - 5
}

boundary_unrestricted <- function(sample_cov) {
  s <- sample_cov[1, 1] - boundary_tau
  a <- sample_cov[1, 2] / s
  total <- sample_cov[1, 3] / s
  u <- sample_cov[2, 2] - a^2 * s
  b <- (sample_cov[2, 3] - a * total * s) / u
  c(s = s, a = a, b = b, cp = total - a * b, u = u,
    "Y~~Y" = sample_cov[3, 3] - total^2 * s - b^2 * u)
}

boundary_reference <- function(unrestricted, sample_cov) {
  if (unrestricted[["Y~~Y"]] > 0) return(list(theta = unrestricted, spread = 0))
  # Log variances keep s and u positive; v is fixed at the active boundary.
  unpack <- function(q) {
    stats::setNames(c(exp(q[1]), q[2:4], exp(q[5]), 0), names(unrestricted))
  }
  initial <- c(log(unrestricted[1]), unrestricted[2:4], log(unrestricted[5]))
  offsets <- list(rep(0, 5), c(0.2, -0.1, 0.1, -0.1, -0.2), c(-0.2, 0.1, -0.1, 0.1, 0.2))
  objective <- function(q) boundary_loss(unpack(q), sample_cov)
  solutions <- lapply(offsets, function(offset) {
    nm <- stats::optim(initial + offset, objective, method = "Nelder-Mead",
                       control = list(maxit = 4000, reltol = 1e-13))
    polish <- stats::optim(nm$par, objective, method = "BFGS", control = list(maxit = 1000, reltol = 1e-14))
    list(theta = unpack(polish$par), value = polish$value, convergence = polish$convergence)
  })
  expect_true(all(vapply(solutions, function(x) x$convergence == 0L, logical(1))))
  values <- vapply(solutions, function(x) x$value, numeric(1))
  list(theta = solutions[[which.min(values)]]$theta, spread = diff(range(values)))
}

boundary_agrees <- function(candidate, reference, sample_cov) {
  identical(sort(names(candidate)), sort(names(reference))) &&
    all(is.finite(candidate)) && candidate[["s"]] > 0 && candidate[["u"]] > 0 &&
    candidate[["Y~~Y"]] >= 0 && max(abs(candidate[names(reference)] - reference)) <= 1e-3 &&
    abs(boundary_loss(candidate, sample_cov) - boundary_loss(reference, sample_cov)) <= 1e-7
}

test_that("bounded latent fits match independent active and interior likelihood references", {
  fixtures <- list(list(seed = 2, variance = 0), list(seed = 3, variance = 0), list(seed = 1, variance = 0.3))
  for (fixture in fixtures) {
    data <- boundary_data(fixture$seed, fixture$variance)
    score <- as.matrix(data[, 1:3]) %*% (boundary_loading / boundary_noise) * boundary_tau
    sample_cov <- stats::cov(cbind(score, data$M, data$Y)) * (nrow(data) - 1) / nrow(data)
    unrestricted <- boundary_unrestricted(sample_cov)
    expect_equal(boundary_covariance(unrestricted), unname(sample_cov), tolerance = 1e-12)
    reference <- boundary_reference(unrestricted, sample_cov)
    expect_lt(reference$spread, 1e-9)
    if (fixture$variance == 0) {
      expect_lt(unrestricted[["Y~~Y"]], -1e-5)
      expect_identical(reference$theta[["Y~~Y"]], 0)
      # Ignoring the bound improves the likelihood, so loss alone is insufficient.
      expect_lt(boundary_loss(unrestricted, sample_cov), boundary_loss(reference$theta, sample_cov))
      expect_false(boundary_agrees(unrestricted, reference$theta, sample_cov))
    } else {
      expect_gt(reference$theta[["Y~~Y"]], 0.1)
    }
    wrong_candidate <- reference$theta
    wrong_candidate[["cp"]] <- wrong_candidate[["cp"]] + 0.05
    expect_false(boundary_agrees(wrong_candidate, reference$theta, sample_cov))
    full_cov <- stats::cov(data) * (nrow(data) - 1) / nrow(data)
    expect_equal(boundary_full_loss(wrong_candidate, full_cov) - boundary_full_loss(reference$theta, full_cov),
                 boundary_loss(wrong_candidate, sample_cov) - boundary_loss(reference$theta, sample_cov),
                 tolerance = 1e-10)
    for (starts in list(1L, NULL)) {
      fit <- fit_sem(boundary_model, data, fixed_x = FALSE, meanstructure = FALSE, n_starts = starts)
      theta <- stats::coef(fit)
      expect_true(fit@converged)
      expect_length(theta, 6L)
      expect_named(theta, names(reference$theta), ignore.order = TRUE)
      expect_true(boundary_agrees(theta, reference$theta, sample_cov))
      expect_lt(abs(boundary_loss(theta, sample_cov) - boundary_loss(reference$theta, sample_cov)), 1e-7)
      expect_lt(max(abs(theta[names(reference$theta)] - reference$theta)), 1e-3)
      if (fixture$variance == 0) {
        # SLSQP can retain a positive floating-point remainder (about 1e-21).
        expect_gte(theta[["Y~~Y"]], 0)
        expect_lt(theta[["Y~~Y"]], 1e-10)
      } else {
        expect_gt(theta[["Y~~Y"]], 0.1)
      }
    }
  }
})
