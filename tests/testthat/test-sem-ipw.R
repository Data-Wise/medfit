# Native SEM engine: sampling weights and the sandwich covariance (S21).
# Oracles: the glm route's weighted estimates, its per-equation HC0 sandwich
# (`sandwich::vcovHC(type = "HC0")`, the type the casewise-score sandwich equals),
# and lavaan's robust standard errors with `sampling.weights`. The glm route's own
# default is HC3, which is wider by a leverage factor; that gap is asserted as
# the documented difference, not hidden. Planted defect: scores computed with the
# weights dropped must miss the HC0 oracle.

ipw_data <- function(n = 400, seed = 4) {
  set.seed(seed)
  # helper-defined functions are looked up by name: CI lint does not source the helper files
  d <- match.fun("sem_sim")(match.fun("sem_model_observed")(), n, 3)[, c("X", "M", "Y")]
  d$w <- stats::rexp(n) + 0.3
  d
}

ipw_syntax <- "M ~ X\nY ~ M + X"

# per-equation HC0 standard errors of the three paths from weighted least squares
ipw_hc0 <- function(d, type = "HC0") {
  lm_m <- stats::lm(M ~ X, d, weights = d$w)
  lm_y <- stats::lm(Y ~ M + X, d, weights = d$w)
  se <- function(m, term) sqrt(diag(sandwich::vcovHC(m, type = type)))[[term]]
  c(`M ~ X` = se(lm_m, "X"), `Y ~ M` = se(lm_y, "M"), `Y ~ X` = se(lm_y, "X"))
}

test_that("weighted estimates equal the glm route's and the sandwich equals per-equation HC0", {
  skip_if_not_installed("sandwich")
  d <- ipw_data()
  fit <- fit_sem(ipw_syntax, d, sampling_weights = d$w, se_type = "sandwich")
  glm <- fit_mediation(Y ~ X + M, M ~ X, d, "X", "M", weights = d$w)
  paths <- c("M ~ X", "Y ~ M", "Y ~ X")
  expect_equal(unname(fit@theta[paths]), c(glm@a_path, glm@b_path, glm@c_prime), tolerance = 1e-6)
  se <- sqrt(diag(fit@vcov))[paths]
  expect_equal(se, ipw_hc0(d), tolerance = 1e-6)
  expect_identical(fit@diagnostics$se_type, "sandwich")
  expect_equal(fit@internals$weights, d$w * nrow(d) / sum(d$w))
})

test_that("the sandwich equals lavaan's robust standard errors with sampling weights", {
  skip_if_not_installed("lavaan")
  d <- ipw_data()
  fit <- fit_sem(ipw_syntax, d, sampling_weights = d$w, se_type = "sandwich")
  lav <- suppressWarnings(lavaan::sem(ipw_syntax, d, fixed.x = FALSE, sampling.weights = "w"))
  pe <- lavaan::parameterEstimates(lav)
  key <- paste(pe$lhs, pe$op, pe$rhs)
  paths <- c("M ~ X", "Y ~ M", "Y ~ X")
  expect_equal(unname(sqrt(diag(fit@vcov))[paths]), pe$se[match(paths, key)], tolerance = 1e-5)
  expect_equal(unname(fit@theta[paths]), pe$est[match(paths, key)], tolerance = 1e-6)
})

test_that("unweighted sandwich equals HC0 and lavaan's huber-white standard errors", {
  skip_if_not_installed("sandwich")
  d <- ipw_data()
  d$w <- 1
  fit <- fit_sem(ipw_syntax, d[c("X", "M", "Y")], se_type = "sandwich")
  paths <- c("M ~ X", "Y ~ M", "Y ~ X")
  expect_equal(sqrt(diag(fit@vcov))[paths], ipw_hc0(d), tolerance = 1e-6)
  skip_if_not_installed("lavaan")
  lav <- suppressWarnings(lavaan::sem(ipw_syntax, d, fixed.x = FALSE, se = "robust.huber.white"))
  pe <- lavaan::parameterEstimates(lav)
  expect_equal(unname(sqrt(diag(fit@vcov))[paths]), pe$se[match(paths, paste(pe$lhs, pe$op, pe$rhs))],
               tolerance = 1e-5)
})

test_that("the sandwich is invariant to the scale of the weights", {
  d <- ipw_data()
  a <- fit_sem(ipw_syntax, d, sampling_weights = d$w, se_type = "sandwich")
  b <- fit_sem(ipw_syntax, d, sampling_weights = 7.3 * d$w, se_type = "sandwich")
  expect_equal(a@vcov, b@vcov, tolerance = 1e-8)
  expect_equal(a@theta, b@theta, tolerance = 1e-8)
})

test_that("planted defect: scores computed without the weights miss the HC0 oracle", {
  skip_if_not_installed("sandwich")
  d <- ipw_data()
  fit <- fit_sem(ipw_syntax, d, sampling_weights = d$w, se_type = "sandwich")
  ram <- fit@internals$ram
  smp <- .sem_sample(fit@data, ram, weights = d$w)
  bread <- solve(.sem_info_observed(fit@theta, ram, smp))
  good <- bread %*% crossprod(.sem_scores(fit@theta, ram, smp)) %*% bread
  smp_unweighted <- smp
  smp_unweighted$w <- NULL
  bad <- bread %*% crossprod(.sem_scores(fit@theta, ram, smp_unweighted)) %*% bread
  paths <- c("M ~ X", "Y ~ M", "Y ~ X")
  expect_equal(sqrt(diag(good))[paths], ipw_hc0(d), tolerance = 1e-6, ignore_attr = TRUE)
  expect_gt(max(abs(sqrt(diag(bad))[paths] / ipw_hc0(d) - 1)), 1e-2)
})

test_that("the scores sum to the gradient, which is zero at the optimum", {
  d <- ipw_data()
  fit <- fit_sem(ipw_syntax, d, sampling_weights = d$w, se_type = "sandwich")
  smp <- .sem_sample(fit@data, fit@internals$ram, weights = d$w)
  expect_lt(max(abs(colSums(.sem_scores(fit@theta, fit@internals$ram, smp)))), 1e-4)
})

test_that("the documented gap to the glm route's HC3 is a leverage factor of a few percent", {
  skip_if_not_installed("sandwich")
  d <- ipw_data()
  nat <- fit_mediation(model = ipw_syntax, data = d, treatment = "X", mediator = "M", engine = "native",
                       weights = d$w, se_type = "sandwich")
  glm <- fit_mediation(Y ~ X + M, M ~ X, d, "X", "M", weights = d$w, se_type = "sandwich")
  ratio <- sqrt(nat@vcov["a", "a"] / glm@vcov["a", "a"])
  expect_lt(ratio, 1)
  expect_gt(ratio, 0.9)
  hc3 <- ipw_hc0(d, "HC3")
  expect_equal(unname(sqrt(glm@vcov["a", "a"])), unname(hc3[["M ~ X"]]), tolerance = 1e-6)
})

test_that("rows dropped for missing values drop their weights, and a constraint is projected in the sandwich", {
  skip_if_not_installed("sandwich")
  d <- ipw_data()
  dm <- d
  dm$M[c(5, 17)] <- NA
  expect_message(fit <- fit_sem(ipw_syntax, dm, sampling_weights = dm$w, se_type = "sandwich"), "2 of 400 rows")
  ref <- fit_sem(ipw_syntax, d[-c(5, 17), ], sampling_weights = d$w[-c(5, 17)], se_type = "sandwich")
  expect_equal(fit@theta, ref@theta, tolerance = 1e-8)
  expect_equal(fit@vcov, ref@vcov, tolerance = 1e-8)
  # a == b under weights equals the collapsed shared-label model, covariance included
  con <- fit_sem("M ~ a*X\nY ~ b*M + X\na == b", d, sampling_weights = d$w, se_type = "sandwich")
  col <- fit_sem("M ~ a*X\nY ~ a*M + X", d, sampling_weights = d$w, se_type = "sandwich")
  expect_equal(con@vcov["a", "a"], col@vcov["a", "a"], tolerance = 1e-5)
  expect_equal(con@vcov["a", "b"], col@vcov["a", "a"], tolerance = 1e-5)
})

test_that("weights are validated, and model-based standard errors under weights nudge once", {
  d <- ipw_data()
  expect_error(fit_sem(ipw_syntax, d, sampling_weights = d$w[-1]), "sampling_weights")
  expect_error(fit_sem(ipw_syntax, d, sampling_weights = replace(d$w, 3, -1)), "sampling_weights")
  expect_error(fit_sem(ipw_syntax, d, sampling_weights = replace(d$w, 3, NA)), "sampling_weights")
  expect_error(fit_sem(ipw_syntax, d, sampling_weights = rep(0, nrow(d))), "at least one positive")
  expect_error(fit_sem(ipw_syntax, d, se_type = "hc3"), "should be one of")
  assign("ipw_model_se", NULL, envir = .medfit_state)
  expect_message(fit_sem(ipw_syntax, d, sampling_weights = d$w), "not valid under inverse-probability")
  expect_no_message(fit_sem(ipw_syntax, d, sampling_weights = d$w))
})

test_that("fit_mediation(engine = 'native') takes weights and se_type through to the weighted sandwich fit", {
  d <- ipw_data()
  nat <- fit_mediation(model = ipw_syntax, data = d, treatment = "X", mediator = "M", engine = "native",
                       weights = d$w, se_type = "sandwich")
  fit <- fit_sem(ipw_syntax, d, sampling_weights = d$w, se_type = "sandwich")
  expect_equal(nat@a_path, fit@theta[["M ~ X"]], ignore_attr = TRUE)
  expect_equal(sqrt(nat@vcov["a", "a"]), sqrt(fit@vcov["M ~ X", "M ~ X"]), tolerance = 1e-8)
  expect_error(
    fit_mediation(model = ipw_syntax, data = d, treatment = "X", mediator = "M", engine = "native",
                  weights = d$w[-1]),
    "weights"
  )
})

test_that("logLik refuses a weighted fit, and print and summary name the standard-error type", {
  d <- ipw_data()
  fit <- fit_sem(ipw_syntax, d, sampling_weights = d$w, se_type = "sandwich")
  expect_error(logLik(fit), "not defined for a fit with sampling weights")
  out <- utils::capture.output(print(fit))
  expect_true(any(grepl("sandwich (robust), sampling weights", out, fixed = TRUE)))
  expect_true(any(grepl("Standard errors: sandwich (robust)", utils::capture.output(print(summary(fit))),
                        fixed = TRUE)))
})
