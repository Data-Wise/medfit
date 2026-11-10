# Oracle O8 (issue #394): lavaan's two-level likelihood and estimates against a hand-built
# base-R likelihood (helper-twolevel-likelihood.R). Model: observed 1-1-1 mediation
# X -> M -> Y with the paths free at both levels, X variance free (fixed.x = FALSE), so each
# level is a saturated 3 x 3 covariance and the means are free. Set MEDFIT_O8_VERBOSE=true
# to print the hand-versus-lavaan values.

verbose_o8 <- function(...) {
  if (identical(Sys.getenv("MEDFIT_O8_VERBOSE"), "true")) cat(sprintf(...))
}

test_that("O8: the reduced cluster density equals the stacked multivariate normal density", {
  d <- tl_data_unbalanced()
  sw <- tl_sigma(0.5, 0.4, 0.2, 1.0, 0.8, 0.9)
  sb <- tl_sigma(0.3, 0.6, 0.1, 0.7, 0.5, 0.6)
  mu <- c(1.5, -0.8, 2.2)
  expect_equal(tl_loglik(tl_stats(d), sw, sb, mu), tl_loglik_stacked(d, sw, sb, mu), tolerance = 1e-10)
})

test_that("O8 (a): at lavaan's estimates the hand log-likelihood equals lavaan logLik", {
  skip_if_not_installed("lavaan")
  for (case in c("balanced", "unbalanced")) {
    d <- if (case == "balanced") tl_data_balanced() else tl_data_unbalanced()
    fit <- tl_fit_lavaan(d)
    expect_true(lavaan::lavInspect(fit, "converged"))
    h <- tl_lavaan_to_hand(fit)
    hand <- tl_loglik(tl_stats(d), h$sw, h$sb, h$mu)
    lav <- as.numeric(lavaan::logLik(fit))
    verbose_o8("\nO8 (a) %s: hand %.6f  lavaan %.6f  rel.diff %.2e\n", case, hand, lav, abs(hand - lav) / abs(lav))
    tl_check_loglik(hand, lav)
  }
})

test_that("O8 (b): maximizing the hand likelihood reproduces lavaan's within and between paths", {
  skip_if_not_installed("lavaan")
  skip_on_cran()
  for (d in list(tl_data_balanced(), tl_data_unbalanced())) {
    fit <- tl_fit_lavaan(d)
    hand <- tl_o8_fit(d)
    tl_check_paths(hand, fit)
    tl_check_loglik(hand$loglik, as.numeric(lavaan::logLik(fit)))
    # the hand maximum is not below the likelihood at lavaan's converged point (to its tolerance)
    h <- tl_lavaan_to_hand(fit)
    expect_gte(hand$loglik, tl_loglik(tl_stats(d), h$sw, h$sb, h$mu) - 1e-6)
  }
})

test_that("O8 (c): the balanced closed form Sigma_W = S_PW, Sigma_B = (S_B - S_PW) / n agrees", {
  skip_if_not_installed("lavaan")
  d <- tl_data_balanced()
  cf <- tl_o8_closed_form(d)
  expect_equal(cf$n, 6)
  # the closed form is the MLE only when the between estimate is positive definite
  skip_if_not(all(eigen(cf$sb, symmetric = TRUE)$values > 0), "closed-form Sigma_B is not positive definite")
  fit <- tl_fit_lavaan(d)
  lav <- tl_lavaan_to_hand(fit)
  expect_equal(unname(cf$sw), unname(lav$sw), tolerance = 1e-4)
  expect_equal(unname(cf$sb), unname(lav$sb), tolerance = 1e-4)
  expect_equal(unname(cf$mu), unname(lav$mu), tolerance = 1e-5)
  # the hand likelihood at the closed form is lavaan's logLik
  st <- tl_stats(d)
  tl_check_loglik(tl_loglik(st, cf$sw, cf$sb, cf$mu), as.numeric(lavaan::logLik(fit)))
  # and it is a stationary point: central-difference gradient in every free element of Sigma_W,
  # Sigma_B and mu vanishes (the log-likelihood is of order 1e3, an off-optimum gradient is O(1+))
  ll <- function(sw, sb, mu) tl_loglik(st, sw, sb, mu)
  h <- 1e-5
  grads <- c(
    unlist(lapply(which(upper.tri(cf$sw, diag = TRUE)), function(k) {
      up <- dn <- cf$sw
      up[k] <- up[k] + h
      dn[k] <- dn[k] - h
      (ll(tl_sym(up), cf$sb, cf$mu) - ll(tl_sym(dn), cf$sb, cf$mu)) / (2 * h)
    })),
    unlist(lapply(which(upper.tri(cf$sb, diag = TRUE)), function(k) {
      up <- dn <- cf$sb
      up[k] <- up[k] + h
      dn[k] <- dn[k] - h
      (ll(cf$sw, tl_sym(up), cf$mu) - ll(cf$sw, tl_sym(dn), cf$mu)) / (2 * h)
    })),
    vapply(1:3, function(k) {
      up <- dn <- cf$mu
      up[k] <- up[k] + h
      dn[k] <- dn[k] - h
      (ll(cf$sw, cf$sb, up) - ll(cf$sw, cf$sb, dn)) / (2 * h)
    }, numeric(1))
  )
  expect_lt(max(abs(grads)), 1e-3)
  # positive control for this check: a perturbed Sigma_B has a clearly non-zero gradient
  d22 <- function(sb) {
    up <- dn <- sb
    up[2, 2] <- up[2, 2] + h
    dn[2, 2] <- dn[2, 2] - h
    (ll(cf$sw, up, cf$mu) - ll(cf$sw, dn, cf$mu)) / (2 * h)
  }
  bump <- cf$sb
  bump[2, 2] <- bump[2, 2] + 0.05
  expect_gt(abs(d22(bump)), 1)
})

test_that("O8 (d): planted defects in the hand likelihood are caught", {
  skip_if_not_installed("lavaan")
  skip_on_cran()
  d <- tl_data_unbalanced()
  fit <- tl_fit_lavaan(d)
  h <- tl_lavaan_to_hand(fit)
  lav_ll <- as.numeric(lavaan::logLik(fit))
  st <- tl_stats(d)
  for (defect in c("nj_free", "no_mean")) {
    # (a) fails: the defective density at lavaan's estimates is not lavaan's logLik
    bad <- tl_loglik(st, h$sw, h$sb, h$mu, defect = defect)
    verbose_o8("\nO8 (d) defect %s: hand %.4f  lavaan %.4f\n", defect, bad, lav_ll)
    expect_failure(tl_check_loglik(bad, lav_ll))
    # (b) fails: maximizing the defective density does not reproduce lavaan's paths
    bad_fit <- tl_o8_fit(d, defect = defect)
    pt <- lavaan::parameterEstimates(fit)
    verbose_o8(
      "O8 (d) defect %s paths: a_b %.4f (lavaan %.4f, se %.4f)  b_b %.4f (lavaan %.4f)  cp_b %.4f (lavaan %.4f)\n",
      defect, bad_fit$between[["a"]], pt$est[pt$label == "a_b"], pt$se[pt$label == "a_b"],
      bad_fit$between[["b"]], pt$est[pt$label == "b_b"], bad_fit$between[["cp"]], pt$est[pt$label == "cp_b"]
    )
    expect_failure(tl_check_paths(bad_fit, fit))
  }
})
