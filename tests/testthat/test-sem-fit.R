# Native SEM engine: syntax-to-fit pipeline (S12).
# Oracles: the PR 1 internal-builder fits for the four structures, lm() for a
# saturated path model, and the pinned error rows. Planted defect: the sample
# covariance builder refuses missing values, so a pipeline that skipped the
# listwise deletion would fail.

sem_syntax <- c(
  observed = "M ~ X + C\nY ~ M + X + C",
  latent = "eta =~ m1 + m2 + m3\neta ~ X\nY ~ eta + X",
  parallel = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ M2",
  serial = "M1 ~ X\nM2 ~ M1 + X\nY ~ M2 + M1 + X"
)

test_that("the four structures fitted from syntax equal the internal-builder fits", {
  mods <- sem_models()
  # The syntax route lists the parameters in a different order from the builders, so SLSQP takes different
  # iterates and the estimates agree to its convergence tolerance, not to rounding: measured 1.9e-15, 5.6e-16,
  # 1.3e-10 and 3.6e-9 locally, about 1e-9 relative on the CI Linux build. The objective agrees to 1e-8.
  tol <- c(observed = 1e-6, latent = 1e-6, parallel = 1e-6, serial = 1e-6)
  for (nm in names(sem_syntax)) {
    mod <- mods[[nm]]
    dat <- sem_sim(mod, n = 500, seed = 3)
    fit <- .sem_fit_syntax(sem_syntax[[nm]], dat)
    smp <- .sem_sample(dat, mod$ram)
    ref <- .sem_optimize(mod$ram, smp, .sem_default_start(mod$ram, smp))
    expect_setequal(names(fit$theta), names(ref$theta))
    expect_equal(fit$theta[names(ref$theta)], ref$theta, tolerance = tol[[nm]], info = nm)
    expect_equal(fit$f, ref$f, tolerance = 1e-8, info = nm)
    expect_true(fit$converged, info = nm)
  }
})

test_that("the fit list carries the estimates, covariance, table and bookkeeping", {
  dat <- sem_sim(sem_model_observed(), n = 400, seed = 5)
  fit <- .sem_fit_syntax(sem_syntax[["observed"]], dat)
  expect_named(fit$theta, fit$ram$par_names)
  expect_identical(dim(fit$vcov), rep(length(fit$theta), 2L))
  expect_identical(rownames(fit$vcov), names(fit$theta))
  expect_true(all(is.finite(fit$vcov)))
  expect_identical(fit$n_obs, 400L)
  expect_identical(nrow(fit$data), fit$n_obs)
  expect_identical(fit$n_dropped, 0L)
  expect_identical(fit$df, 0)
  expect_identical(fit$information, "observed")
  expect_identical(.sem_fit_syntax(sem_syntax[["observed"]], dat, information = "expected")$information, "expected")
  expect_identical(nrow(fit$partable), nrow(fit$table))
  # the saturated path model reproduces lm()
  ols <- stats::coef(stats::lm(Y ~ M + X + C, data = dat))
  expect_equal(unname(fit$theta[c("Y ~ M", "Y ~ X", "Y ~ C")]), unname(ols[c("M", "X", "C")]), tolerance = 1e-6)
})

test_that("incomplete rows are dropped once, counted, reported in one message, and only on model variables", {
  dat <- sem_sim(sem_model_observed(), n = 300, seed = 7)
  dat$unused <- NA_real_
  dat$M[c(3, 10)] <- NA
  dat$Y[10] <- NA
  expect_message(fit <- .sem_fit_syntax(sem_syntax[["observed"]], dat), "2 of 300 rows dropped", fixed = FALSE)
  expect_identical(fit$n_dropped, 2L)
  expect_identical(fit$n_obs, 298L)
  expect_identical(nrow(fit$data), 298L)
  msgs <- testthat::capture_messages(.sem_fit_syntax(sem_syntax[["observed"]], dat))
  expect_length(msgs, 1L)
  expect_match(msgs, "listwise deletion")
  # a column outside the model, even all-NA, does not drop rows
  clean <- sem_sim(sem_model_observed(), n = 300, seed = 7)
  clean$unused <- NA_real_
  expect_no_message(.sem_fit_syntax(sem_syntax[["observed"]], clean))
})

test_that("planted defect: without the listwise deletion the sample builder refuses missing values", {
  dat <- sem_sim(sem_model_observed(), n = 100, seed = 7)
  dat$M[3] <- NA
  ram <- .sem_to_ram(.sem_complete(.sem_parse(sem_syntax[["observed"]])$parameters))$ram
  expect_error(.sem_sample(dat, ram), "missing values")
})

test_that("every error row names its cause", {
  dat <- sem_sim(sem_model_observed(), n = 200, seed = 9)
  fit_err <- function(m, d = dat) .sem_fit_syntax(m, d)
  expect_error(fit_err("level: 1\nY ~ X\nlevel: 2\nY ~ M"), "two-level estimation is not implemented")
  expect_error(fit_err("level: 2\nY ~ X"), "two-level estimation is not implemented")
  expect_error(fit_err("M ~ 1\nY ~ M + X"), "mean structure is not supported.*free")
  expect_error(fit_err("M ~ a*X\nY ~ b*M\nab := a*b"), "constraints.*not supported by the native engine yet.*:=")
  expect_error(fit_err("M ~ a*X\nY ~ b*M\na == b"), "constraints.*not supported.*==")
  expect_error(fit_err("Y ~ X\nY ~ X"), "a path appears twice")
  expect_error(fit_err("Y ~ X + Zzz"), "not columns of `data`: Zzz")
  expect_error(fit_err("Y ~ X", transform(dat, X = as.character(X))), "must be numeric: X")
  expect_error(fit_err("Y ~ X\nX ~ Y", dat), "more free parameters \\(4\\) than observed moments \\(3\\): df = -1")
  expect_error(fit_err("Y ~ X", dat[0, ]), "at least 1 rows")
  expect_error(fit_err("Y ~ X", dat[1:2, c("X", "Y")]), "singular")
})

test_that("a start, bound or fixed value in the syntax reaches the optimizer", {
  dat <- sem_sim(sem_model_observed(), n = 400, seed = 5)
  fit <- .sem_fit_syntax("M ~ X + C\nY ~ lower(0.6)*M + X + C", dat)
  expect_equal(fit$theta[["Y ~ M"]], 0.6, tolerance = 1e-8)
  expect_true("Y ~ M" %in% fit$active_bounds)
  fixed <- .sem_fit_syntax("M ~ 0.3*X + C\nY ~ M + X + C", dat)
  expect_false("M ~ X" %in% names(fixed$theta))
  expect_identical(fixed$df, 1)
})
