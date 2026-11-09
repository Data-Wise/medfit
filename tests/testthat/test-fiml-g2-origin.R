# FI-G2: exact-origin guard for FIML mediation objects. At an exact origin (every a and b path equal to 0) the NIE delta
# gradient is zero, so tidy() and confint(parm = "effects") withhold the NIE interval (NA plus a note) for the
# single-mediator AND the parallel FIML object. A real fit never reaches exactly 0 and the public constructors refuse a
# forged object because the context hash binds the parameters, so the origin is forged by rebuilding that hash.
# Helpers are prefixed og_.

og_note <- "NIE inference unavailable: zero delta gradient"
og_res <- function(v, ...) {
  X <- cbind(1, ...)
  v - X %*% solve(crossprod(X), crossprod(X, v))
}
og_data <- function(n = 200L) {
  set.seed(5)
  x <- stats::rnorm(n)
  m1 <- drop(og_res(stats::rnorm(n), x))
  m2 <- drop(og_res(stats::rnorm(n), x, m1))
  list(
    single = data.frame(X = x, M = m1, Y = drop(og_res(stats::rnorm(n), x, m1)) + 0.4 * x),
    parallel = data.frame(X = x, M1 = m1, M2 = m2, Y = drop(og_res(stats::rnorm(n), x, m1, m2)))
  )
}
og_single <- function() {
  d <- og_data()$single
  extract_mediation(fit_sem("M ~ X\nY ~ M + X", d, missing = "fiml", fixed_x = FALSE),
                    treatment = "X", mediator = "M")
}
og_parallel <- function() {
  d <- og_data()$parallel
  f <- fit_sem("M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2", d, missing = "fiml", fixed_x = FALSE)
  extract_mediation(f, treatment = "X", mediator = c("M1", "M2"))
}
# Set the named estimates and the path slots to `vals` and rebind the parameter hash
og_forge <- function(z, vals) {
  ctx <- z@fit_context
  est <- z@estimates
  est[names(vals)] <- unlist(vals)
  if (S7::S7_inherits(z, FIMLParallelMediationData)) {
    a <- unname(est[c("a1", "a2")])
    b <- unname(est[c("b1", "b2")])
    ctx$parameter_hash <- rlang::hash(list(est, z@vcov, a, b, z@c_prime))
    S7::set_props(z, a_paths = a, b_paths = b, estimates = est, fit_context = ctx)
  } else {
    ctx$parameter_hash <- rlang::hash(list(est, z@vcov, unname(est[["a"]]), unname(est[["b"]]), z@c_prime))
    S7::set_props(z, a_path = unname(est[["a"]]), b_path = unname(est[["b"]]), estimates = est, fit_context = ctx)
  }
}
og_nie_row <- function(z) {
  tb <- suppressWarnings(generics::tidy(z, type = "effects", conf.int = TRUE))
  list(tb = tb, nie = tb[tb$term == "nie", ])
}
og_confint <- function(z) suppressWarnings(confint(z, parm = "effects"))
og_ci_nie <- function(z) og_confint(z)[if (S7::S7_inherits(z, FIMLParallelMediationData)) "indirect" else "nie", ]

og_zero1 <- function() og_forge(og_single(), list(a = 0, b = 0))
og_zero2 <- function() og_forge(og_parallel(), list(a1 = 0, a2 = 0, b1 = 0, b2 = 0))

test_that("single-mediator exact origin withholds the NIE interval (unchanged behavior)", {
  skip_if_not_installed("lavaan")
  z <- og_zero1()
  expect_true(.sem_fiml_origin(z))
  r <- og_nie_row(z)
  expect_true(is.na(r$nie$std_error))
  expect_true(is.na(r$nie$conf_low) && is.na(r$nie$conf_high))
  expect_identical(attr(r$tb, "note"), og_note)
  ci <- og_confint(z)
  expect_true(all(is.na(og_ci_nie(z))))
  expect_identical(attr(ci, "note"), og_note)
})

test_that("parallel exact origin withholds the NIE interval like the single-mediator object", {
  z <- og_zero2()
  expect_s3_class(z, "medfit::FIMLParallelMediationData")
  expect_equal(c(z@a_paths, z@b_paths), rep(0, 4))
  expect_true(.sem_fiml_origin(z))
  r <- og_nie_row(z)
  expect_true(is.na(r$nie$std_error))
  expect_true(is.na(r$nie$conf_low) && is.na(r$nie$conf_high))
  expect_identical(attr(r$tb, "note"), og_note)
  ci <- og_confint(z)
  expect_true(all(is.na(og_ci_nie(z))))
  expect_identical(attr(ci, "note"), og_note)
  # the other effect rows keep finite SEs
  expect_true(all(is.finite(r$tb$std_error[r$tb$term %in% c("nde", "te")])))
})

test_that("non-zero and partly zero parallel objects keep finite NIE SEs and no note", {
  z <- og_parallel()
  expect_false(.sem_fiml_origin(z))
  expect_true(is.finite(og_nie_row(z)$nie$std_error))
  expect_null(attr(og_nie_row(z)$tb, "note"))
  expect_null(attr(og_confint(z), "note"))
  # only some paths exactly 0: the delta gradient of the sum is not zero
  for (vals in list(list(a1 = 0, a2 = 0), list(b1 = 0, b2 = 0), list(a1 = 0, b2 = 0), list(a1 = 0, b1 = 0, a2 = 0))) {
    zp <- og_forge(z, vals)
    expect_false(.sem_fiml_origin(zp), info = paste(names(vals), collapse = ","))
    r <- og_nie_row(zp)
    expect_true(is.finite(r$nie$std_error), info = paste(names(vals), collapse = ","))
    expect_null(attr(r$tb, "note"))
    expect_true(all(is.finite(og_ci_nie(zp))))
  }
})

test_that("a partly zero single-mediator object keeps a finite NIE SE", {
  skip_if_not_installed("lavaan")
  z <- og_single()
  expect_false(.sem_fiml_origin(z))
  for (vals in list(list(a = 0), list(b = 0))) {
    zp <- og_forge(z, vals)
    expect_false(.sem_fiml_origin(zp))
    expect_true(is.finite(og_nie_row(zp)$nie$std_error))
  }
})

test_that("the origin predicate is FALSE for non-FIML objects", {
  d <- data.frame(X = c(1, 2, 3, 4), M = c(1, 2, 3, 5), Y = c(2, 1, 4, 3))
  z <- MediationData(a_path = 0, b_path = 0, c_prime = 0.1, estimates = c(a = 0, b = 0, c_prime = 0.1),
                     vcov = diag(3) * 0.01, sigma_m = 1, sigma_y = 1, treatment = "X", mediator = "M", outcome = "Y",
                     mediator_predictors = "X", outcome_predictors = c("X", "M"), data = d, n_obs = 4L,
                     converged = TRUE, source_package = "medfit")
  expect_false(.sem_fiml_origin(z))
})
