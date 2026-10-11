# Native SEM engine: SEMFit methods (S18). The print and summary snapshots use a
# hand-built object, so they do not depend on the optimizer or the platform.
# Oracles: lavaan's logLik() on the same model and data; the object's own fields
# for the accessors. Planted defect: an unprojected covariance must change the
# summary's standard errors under an active constraint.

hand_semfit <- function() {
  theta <- c(a = 0.5, b = 0.4, `Y ~ X` = 0.2, `M ~~ M` = 0.8, `Y ~~ Y` = 0.7, `X ~~ X` = 1)
  vc <- diag(c(0.0025, 0.0016, 0.0009, 0.01, 0.008, 0.012))
  dimnames(vc) <- list(names(theta), names(theta))
  tab <- data.frame(
    lhs = c("M", "Y", "Y", "M", "Y", "X"), op = c("~", "~", "~", "~~", "~~", "~~"),
    rhs = c("X", "M", "X", "M", "Y", "X"), label = c("a", "b", "", "", "", ""),
    free = TRUE, est = unname(theta), se = sqrt(diag(vc)), stringsAsFactors = FALSE
  )
  dat <- data.frame(X = seq(-1, 1, length.out = 20), M = 0, Y = 0)
  SEMFit(
    theta = theta, vcov = vc, table = tab,
    defined = data.frame(name = "ab", expr = "a*b", est = 0.2, se = 0.0316, stringsAsFactors = FALSE),
    f = 0.0123, n_obs = 20L, n_dropped = 2L, df = 1, information = "observed", converged = TRUE,
    data = dat, model = "M ~ a*X\nY ~ b*M + X\nab := a*b",
    diagnostics = list(status = 4L, decrement = 2.5e-8, retries = 0L, active_bounds = "M ~~ M",
                       active_constraints = character(), improper = character(), sign_check = "ok"),
    internals = list(), call = NULL
  )
}

test_that("print and summary of a hand-built SEMFit are stable", {
  fit <- hand_semfit()
  expect_snapshot(print(fit))
  expect_snapshot(print(summary(fit)))
})

test_that("coef, vcov and nobs read the object", {
  fit <- hand_semfit()
  expect_identical(coef(fit), fit@theta)
  expect_identical(vcov(fit), fit@vcov)
  expect_identical(nobs(fit), 20L)
})

test_that("summary reports z and two-sided p from the estimates and standard errors", {
  s <- summary(hand_semfit())
  expect_s3_class(s, "summary.SEMFit")
  expect_equal(s$coefficients$z, s$coefficients$est / s$coefficients$se)
  expect_equal(s$coefficients$p, 2 * stats::pnorm(-abs(s$coefficients$z)))
  expect_identical(s$coefficients$name[1:2], c("a", "b"))
  expect_identical(s$n_dropped, 2L)
})

test_that("logLik equals lavaan's and counts the free means in df", {
  skip_if_not_installed("lavaan")
  dat <- sem_sim(sem_model_observed(), n = 400, seed = 3)
  syntax <- "M ~ X + C\nY ~ M + X + C"
  fit <- fit_sem(syntax, dat)
  lav <- suppressWarnings(lavaan::sem(syntax, dat, fixed.x = FALSE))
  expect_equal(as.numeric(logLik(fit)), as.numeric(lavaan::logLik(lav)), tolerance = 1e-8)
  expect_identical(attr(logLik(fit), "nobs"), 400L)
  expect_equal(attr(logLik(fit), "df"), length(fit@theta) + 4)
  expect_s3_class(logLik(fit), "logLik")
})

test_that("planted defect: an unprojected covariance changes the standard errors under a constraint", {
  dat <- sem_sim(sem_model_observed(), n = 400, seed = 3)
  fit <- fit_sem("M ~ a*X + C\nY ~ b*M + X + C\na == b", dat)
  smp <- .sem_sample(fit@data, fit@internals$ram)
  plain <- solve(.sem_info_observed(fit@theta, fit@internals$ram, smp))
  se_plain <- sqrt(diag(plain))[["a"]]
  se_summary <- summary(fit)$coefficients$se[summary(fit)$coefficients$name == "a"]
  expect_gt(abs(se_plain / se_summary - 1), 0.05)
  expect_equal(se_summary, sqrt(fit@vcov["a", "a"]))
})

test_that("a fit with a missing-value drop and an active constraint reports both in the summary", {
  dat <- sem_sim(sem_model_observed(), n = 300, seed = 3)
  dat$M[c(2, 9)] <- NA
  expect_message(fit <- fit_sem("M ~ a*X + C\nY ~ b*M + X + C\na == b", dat), "2 of 300 rows dropped")
  expect_identical(fit@n_dropped, 2L)
  expect_identical(fit@diagnostics$active_constraints, "a == b")
  out <- utils::capture.output(print(summary(fit)))
  expect_true(any(grepl("2 dropped for missing values", out)))
  expect_true(any(grepl("Active constraints: a == b", out, fixed = TRUE)))
})
