# Task U3: three-way oracle agreement for the two-level 1-1-1 observed model X -> M -> Y
# (fixed slopes, within and between levels): the hand-built O8 likelihood
# (helper-twolevel-likelihood.R), lavaan two-level, and OpenMx's relational (joined) model
# (helper-twolevel-openmx.R). OpenMx has no fixed.x, so lavaan runs with fixed.x = FALSE; both
# use observed information (lavaan's two-level default, OpenMx's numerical Hessian).
# Tolerances (planning/specs/ADR-twolevel-oracle-tolerances-2026-11-18.md): estimates
# |diff| <= max(0.01 * SE, 1e-4) (TL-1, TL-5); SEs and the contrast SE 1e-3 relative (TL-2,
# TL-5); logLik 1e-6 relative (TL-4, tl_check_loglik()). Set MEDFIT_O8_VERBOSE=true to print the values.

verbose_u3 <- function(...) {
  if (identical(Sys.getenv("MEDFIT_O8_VERBOSE"), "true")) cat(sprintf(...))
}

tl_mx_fixtures <- function() {
  list(balanced = tl_mx_data_balanced(), unbalanced = tl_mx_data_unbalanced())
}

test_that("U3: the fixtures are J = 100 clusters, balanced n_j = 5 and unbalanced n_j in 2..9", {
  fx <- tl_mx_fixtures()
  sizes <- lapply(fx, function(d) as.vector(table(d$cluster)))
  expect_length(sizes$balanced, 100)
  expect_true(all(sizes$balanced == 5))
  expect_length(sizes$unbalanced, 100)
  expect_setequal(unique(sizes$unbalanced), 2:9)
})

test_that("U3: OpenMx, lavaan and the O8 likelihood agree on estimates, SEs and logLik", {
  skip_if_not_installed("OpenMx")
  skip_if_not_installed("lavaan")
  fx <- tl_mx_fixtures()
  for (case in names(fx)) {
    d <- fx[[case]]
    fit <- tl_fit_lavaan(d)
    expect_true(lavaan::lavInspect(fit, "converged"))
    expect_identical(unique(lavaan::lavInspect(fit, "options")$information), "observed")
    expect_identical(unique(lavaan::lavInspect(fit, "options")$h1.information), "structured")
    mx <- tl_mx_fit(d)
    expect_identical(mx$output$status$code, 0L)
    lav <- tl_mx_lavaan_estimates(fit)
    omx <- tl_mx_estimates(mx)
    verbose_u3(
      "\nU3 %s: max |est diff| / SE %.2e  max SE rel diff %.2e  logLik lavaan %.6f  OpenMx %.6f\n",
      case, max(abs(omx$est - lav$est) / lav$se), max(abs(omx$se - lav$se) / lav$se),
      as.numeric(lavaan::logLik(fit)), omx$loglik
    )
    # all 15 free parameters: within and between paths and variances, level-2 intercepts
    tl_mx_check_est(omx$est, lav)
    tl_mx_check_se(omx$se, lav)
    # the cross-level covariance: Cov(a_w, a_b) is nonzero and the contrast SE agrees
    expect_gt(abs(mx$output$vcov["a_w", "a_b"]), 1e-4)
    tl_mx_check_contrast_se(tl_mx_contrast_se(mx$output$vcov), tl_mx_contrast_se(lavaan::vcov(fit)))
    # absolute logLik (TL-4): OpenMx against lavaan (no cluster-only covariate, so no constant offset)
    tl_check_loglik(omx$loglik, as.numeric(lavaan::logLik(fit)))
    # the hand O8 likelihood at OpenMx's estimates is OpenMx's -2LL / 2
    h <- tl_mx_to_hand(mx)
    tl_check_loglik(tl_loglik(tl_stats(d), h$sw, h$sb, h$mu), omx$loglik)
  }
})

test_that("U3: maximizing the O8 likelihood reproduces OpenMx's within and between paths", {
  skip_if_not_installed("OpenMx")
  skip_if_not_installed("lavaan")
  skip_on_cran()
  d <- tl_mx_data_unbalanced()
  fit <- tl_fit_lavaan(d)
  omx <- tl_mx_estimates(tl_mx_fit(d))
  hand <- tl_o8_fit(d)
  expect_identical(hand$convergence, 0L)
  hand_est <- c(
    a_w = hand$within[["a"]], b_w = hand$within[["b"]], cp_w = hand$within[["cp"]],
    a_b = hand$between[["a"]], b_b = hand$between[["b"]], cp_b = hand$between[["cp"]]
  )
  paths <- names(hand_est)
  lav <- tl_mx_lavaan_estimates(fit)
  excess <- abs(hand_est - omx$est[paths]) - pmax(0.01 * lav$se[paths], 1e-4)
  expect_lte(max(excess), 0, label = paste("worst path:", paths[which.max(excess)]))
  tl_check_loglik(hand$loglik, omx$loglik)
})

test_that("U3 planted defects: a dropped between a path and the contextual spec are caught", {
  skip_if_not_installed("OpenMx")
  skip_if_not_installed("lavaan")
  d <- tl_mx_data_unbalanced()
  fit <- tl_fit_lavaan(d)
  lav <- tl_mx_lavaan_estimates(fit)
  lav_ll <- as.numeric(lavaan::logLik(fit))

  # a_b fixed at 0: both the estimate check and the logLik check fail
  no_ab <- tl_mx_estimates(tl_mx_fit(d, defect = "no_a_b"))
  verbose_u3("\nU3 defect no_a_b: a_b %.4f (lavaan %.4f)  logLik %.4f (lavaan %.4f)\n",
             no_ab$est[["a_b"]], lav$est[["a_b"]], no_ab$loglik, lav_ll)
  expect_failure(tl_mx_check_est(no_ab$est, lav))
  expect_failure(tl_check_loglik(no_ab$loglik, lav_ll))

  # within paths on the observed variables: the same likelihood (a reparameterization), but
  # the between paths are contextual effects, so only the estimate check catches it
  ctx_fit <- tl_mx_fit(d, defect = "contextual")
  ctx <- tl_mx_estimates(ctx_fit)
  verbose_u3("U3 defect contextual: a_b %.4f (lavaan %.4f, a_b - a_w %.4f)  logLik %.6f (lavaan %.6f)\n",
             ctx$est[["a_b"]], lav$est[["a_b"]], lav$est[["a_b"]] - lav$est[["a_w"]], ctx$loglik, lav_ll)
  expect_identical(ctx_fit$output$status$code, 0L)
  expect_failure(tl_mx_check_est(ctx$est, lav))
  expect_success(tl_check_loglik(ctx$loglik, lav_ll))
  # its between a is the contextual effect a_b - a_w
  expect_lt(abs(ctx$est[["a_b"]] - (lav$est[["a_b"]] - lav$est[["a_w"]])), pmax(0.01 * lav$se[["a_b"]], 1e-4))
})

test_that("U3 planted defects (TL-2, TL-7): a zeroed cross-level block and expected-information SEs are caught", {
  skip_if_not_installed("OpenMx")
  skip_if_not_installed("lavaan")
  d <- tl_mx_data_unbalanced()
  fit <- tl_fit_lavaan(d)
  mx <- tl_mx_fit(d)
  lav_se <- tl_mx_contrast_se(lavaan::vcov(fit))
  # the zeroed cross-level block: marginal SEs unchanged, the contrast SE about 3.5% off
  v0 <- mx$output$vcov
  v0["a_w", "a_b"] <- v0["a_b", "a_w"] <- 0
  verbose_u3("\nU3 defect zeroed block: SE(a_w - a_b) %.6f joint, %.6f zeroed, lavaan %.6f\n",
             tl_mx_contrast_se(mx$output$vcov), tl_mx_contrast_se(v0), lav_se)
  tl_mx_check_contrast_se(tl_mx_contrast_se(mx$output$vcov), lav_se)
  expect_failure(tl_mx_check_contrast_se(tl_mx_contrast_se(v0), lav_se))
  # lavaan with expected information (about 2% off on this unbalanced fixture; on the balanced
  # saturated fixture the two informations coincide, so the defect is planted here only)
  fit_exp <- suppressWarnings(lavaan::sem(tl_lavaan_model, d, cluster = "cluster", fixed.x = FALSE,
                                          information = "expected"))
  expect_failure(tl_mx_check_se(tl_mx_estimates(mx)$se, tl_mx_lavaan_estimates(fit_exp)))
})
